#include "HaptykAudioCore.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>
#include <mach/mach_time.h>
#include <AudioToolbox/AudioToolbox.h>

static OSStatus haptyk_render_callback(
    void *inRefCon,
    AudioUnitRenderActionFlags *ioActionFlags,
    const AudioTimeStamp *inTimeStamp,
    UInt32 inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList *ioData
) {
    HaptykEngineContext *ctx = (HaptykEngineContext *)inRefCon;
    if (!ctx || ctx->muted) {
        for (UInt32 b = 0; b < ioData->mNumberBuffers; b++) {
            memset(ioData->mBuffers[b].mData, 0, ioData->mBuffers[b].mDataByteSize);
        }
        return noErr;
    }

    float *out_l = (float *)ioData->mBuffers[0].mData;
    float *out_r = (ioData->mNumberBuffers > 1) ? (float *)ioData->mBuffers[1].mData : out_l;
    
    memset(out_l, 0, inNumberFrames * sizeof(float));
    if (out_r != out_l) {
        memset(out_r, 0, inNumberFrames * sizeof(float));
    }
    
    float master_vol = ctx->master_volume;
    
    for (int v = 0; v < HAPTYK_MAX_VOICES; v++) {
        HaptykVoice *voice = &ctx->voices[v];
        if (!voice->active || !voice->pcm_l) continue;
        
        const float *pcm_l = voice->pcm_l;
        const float *pcm_r = voice->pcm_r ? voice->pcm_r : voice->pcm_l;
        uint32_t total = voice->total_frames;
        double frame_pos = voice->current_frame;
        double step = voice->pitch_ratio;
        float vl = voice->volume_l * master_vol;
        float vr = voice->volume_r * master_vol;
        
        for (UInt32 f = 0; f < inNumberFrames; f++) {
            uint32_t idx = (uint32_t)frame_pos;
            if (idx + 1 >= total) {
                voice->active = false;
                break;
            }
            
            double frac = frame_pos - idx;
            float s_l = (float)((1.0 - frac) * pcm_l[idx] + frac * pcm_l[idx + 1]);
            float s_r = (float)((1.0 - frac) * pcm_r[idx] + frac * pcm_r[idx + 1]);
            
            out_l[f] += s_l * vl;
            if (out_r != out_l) {
                out_r[f] += s_r * vr;
            }
            
            frame_pos += step;
        }
        voice->current_frame = frame_pos;
    }
    
    // Soft saturation limiter to prevent digital clipping
    for (UInt32 f = 0; f < inNumberFrames; f++) {
        float l = out_l[f];
        out_l[f] = tanhf(l);
        if (out_r != out_l) {
            float r = out_r[f];
            out_r[f] = tanhf(r);
        }
    }
    
    return noErr;
}

int haptyk_engine_init(HaptykEngineContext *ctx, double sample_rate, uint32_t buffer_frames) {
    if (!ctx) return -1;
    memset(ctx, 0, sizeof(HaptykEngineContext));
    
    ctx->sample_rate = (sample_rate > 0) ? sample_rate : 48000.0;
    ctx->buffer_size_frames = (buffer_frames > 0) ? buffer_frames : 128;
    ctx->master_volume = 1.0f;
    ctx->release_volume = 0.65f;
    ctx->release_enabled = true;
    ctx->muted = false;
    
    AudioComponentDescription desc = {
        .componentType = kAudioUnitType_Output,
        .componentSubType = kAudioUnitSubType_DefaultOutput,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0
    };
    
    AudioComponent comp = AudioComponentFindNext(NULL, &desc);
    if (!comp) return -2;
    
    OSStatus status = AudioComponentInstanceNew(comp, &ctx->output_unit);
    if (status != noErr) return (int)status;
    
    AudioStreamBasicDescription stream_desc = {
        .mSampleRate = ctx->sample_rate,
        .mFormatID = kAudioFormatLinearPCM,
        .mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked,
        .mBytesPerPacket = sizeof(float),
        .mFramesPerPacket = 1,
        .mBytesPerFrame = sizeof(float),
        .mChannelsPerFrame = 2,
        .mBitsPerChannel = 32
    };
    
    status = AudioUnitSetProperty(
        ctx->output_unit,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Input,
        0,
        &stream_desc,
        sizeof(stream_desc)
    );
    if (status != noErr) return (int)status;
    
    AURenderCallbackStruct callback_struct = {
        .inputProc = haptyk_render_callback,
        .inputProcRefCon = ctx
    };
    
    status = AudioUnitSetProperty(
        ctx->output_unit,
        kAudioUnitProperty_SetRenderCallback,
        kAudioUnitScope_Input,
        0,
        &callback_struct,
        sizeof(callback_struct)
    );
    if (status != noErr) return (int)status;
    
    status = AudioUnitInitialize(ctx->output_unit);
    if (status != noErr) return (int)status;
    
    return 0;
}

int haptyk_engine_start(HaptykEngineContext *ctx) {
    if (!ctx || !ctx->output_unit) return -1;
    OSStatus status = AudioOutputUnitStart(ctx->output_unit);
    return (int)status;
}

void haptyk_engine_stop(HaptykEngineContext *ctx) {
    if (!ctx || !ctx->output_unit) return;
    AudioOutputUnitStop(ctx->output_unit);
}

void haptyk_engine_destroy(HaptykEngineContext *ctx) {
    if (!ctx) return;
    if (ctx->output_unit) {
        AudioOutputUnitStop(ctx->output_unit);
        AudioUnitUninitialize(ctx->output_unit);
        AudioComponentInstanceDispose(ctx->output_unit);
        ctx->output_unit = NULL;
    }
    haptyk_sound_pack_free(&ctx->current_pack);
    ctx->pack_loaded = false;
}

static int alloc_voice(HaptykEngineContext *ctx) {
    for (int i = 0; i < HAPTYK_MAX_VOICES; i++) {
        if (!ctx->voices[i].active) return i;
    }
    double max_progress = -1.0;
    int oldest_idx = 0;
    for (int i = 0; i < HAPTYK_MAX_VOICES; i++) {
        if (ctx->voices[i].total_frames > 0) {
            double prog = ctx->voices[i].current_frame / (double)ctx->voices[i].total_frames;
            if (prog > max_progress) {
                max_progress = prog;
                oldest_idx = i;
            }
        }
    }
    return oldest_idx;
}

void haptyk_engine_play_key(HaptykEngineContext *ctx, HaptykKeyGroup key_group, float velocity) {
    if (!ctx || !ctx->pack_loaded || ctx->muted) return;
    if (key_group >= HAPTYK_NUM_KEY_GROUPS) key_group = HAPTYK_KEY_STANDARD;
    
    if (velocity < 0.15f) velocity = 0.15f;
    if (velocity > 1.0f) velocity = 1.0f;
    
    float pos = velocity * 3.0f;
    int tier_idx1 = (int)pos;
    if (tier_idx1 > 3) tier_idx1 = 3;
    int tier_idx2 = (tier_idx1 < 3) ? tier_idx1 + 1 : 3;
    float mix2 = pos - tier_idx1;
    float mix1 = 1.0f - mix2;
    
    HaptykAudioSample *s1 = &ctx->current_pack.samples[key_group][tier_idx1];
    HaptykAudioSample *s2 = &ctx->current_pack.samples[key_group][tier_idx2];
    
    double micro_detune = 1.0 + (((double)rand() / (double)RAND_MAX) - 0.5) * 0.025;
    float base_gain = 0.55f + 0.45f * velocity;
    
    if (s1->samples_l && s1->num_frames > 0 && mix1 > 0.05f) {
        int v_idx = alloc_voice(ctx);
        HaptykVoice *v = &ctx->voices[v_idx];
        v->pcm_l = s1->samples_l;
        v->pcm_r = s1->samples_r;
        v->total_frames = s1->num_frames;
        v->current_frame = 0.0;
        v->pitch_ratio = micro_detune * ((double)s1->sample_rate / ctx->sample_rate);
        v->volume_l = mix1 * base_gain;
        v->volume_r = mix1 * base_gain;
        v->active = true;
    }
    
    if (tier_idx1 != tier_idx2 && s2->samples_l && s2->num_frames > 0 && mix2 > 0.05f) {
        int v_idx = alloc_voice(ctx);
        HaptykVoice *v = &ctx->voices[v_idx];
        v->pcm_l = s2->samples_l;
        v->pcm_r = s2->samples_r;
        v->total_frames = s2->num_frames;
        v->current_frame = 0.0;
        v->pitch_ratio = micro_detune * ((double)s2->sample_rate / ctx->sample_rate);
        v->volume_l = mix2 * base_gain;
        v->volume_r = mix2 * base_gain;
        v->active = true;
    }
    
    ctx->total_keystrokes_played++;
}

void haptyk_engine_play_release(HaptykEngineContext *ctx) {
    if (!ctx || !ctx->pack_loaded || ctx->muted || !ctx->release_enabled) return;
    HaptykAudioSample *rel = &ctx->current_pack.release_sample;
    if (!rel->samples_l || rel->num_frames == 0) return;
    
    int v_idx = alloc_voice(ctx);
    HaptykVoice *v = &ctx->voices[v_idx];
    v->pcm_l = rel->samples_l;
    v->pcm_r = rel->samples_r;
    v->total_frames = rel->num_frames;
    v->current_frame = 0.0;
    
    double micro_detune = 1.0 + (((double)rand() / (double)RAND_MAX) - 0.5) * 0.03;
    v->pitch_ratio = micro_detune * ((double)rel->sample_rate / ctx->sample_rate);
    v->volume_l = ctx->release_volume * 0.75f;
    v->volume_r = ctx->release_volume * 0.75f;
    v->active = true;
}

void haptyk_engine_set_master_volume(HaptykEngineContext *ctx, float volume) {
    if (ctx) ctx->master_volume = volume;
}

void haptyk_engine_set_release_volume(HaptykEngineContext *ctx, float volume) {
    if (ctx) ctx->release_volume = volume;
}

void haptyk_engine_set_release_enabled(HaptykEngineContext *ctx, bool enabled) {
    if (ctx) ctx->release_enabled = enabled;
}

void haptyk_engine_set_muted(HaptykEngineContext *ctx, bool muted) {
    if (ctx) ctx->muted = muted;
}

void haptyk_sound_pack_free(HaptykSoundPack *pack) {
    if (!pack) return;
    for (int g = 0; g < HAPTYK_NUM_KEY_GROUPS; g++) {
        for (int t = 0; t < HAPTYK_NUM_TIERS; t++) {
            if (pack->samples[g][t].samples_l) {
                free(pack->samples[g][t].samples_l);
                pack->samples[g][t].samples_l = NULL;
            }
            if (pack->samples[g][t].samples_r) {
                free(pack->samples[g][t].samples_r);
                pack->samples[g][t].samples_r = NULL;
            }
            pack->samples[g][t].num_frames = 0;
        }
    }
    if (pack->release_sample.samples_l) {
        free(pack->release_sample.samples_l);
        pack->release_sample.samples_l = NULL;
    }
    if (pack->release_sample.samples_r) {
        free(pack->release_sample.samples_r);
        pack->release_sample.samples_r = NULL;
    }
    pack->release_sample.num_frames = 0;
}

int haptyk_sound_pack_load_wav(HaptykAudioSample *out_sample, const char *filepath) {
    if (!out_sample || !filepath) return -1;
    out_sample->samples_l = NULL;
    out_sample->samples_r = NULL;
    out_sample->num_frames = 0;
    out_sample->sample_rate = 48000;
    
    FILE *f = fopen(filepath, "rb");
    if (!f) return -2;
    
    char chunk_id[4];
    uint32_t chunk_size = 0;
    
    if (fread(chunk_id, 1, 4, f) != 4 || memcmp(chunk_id, "RIFF", 4) != 0) {
        fclose(f);
        return -3;
    }
    fseek(f, 4, SEEK_CUR);
    if (fread(chunk_id, 1, 4, f) != 4 || memcmp(chunk_id, "WAVE", 4) != 0) {
        fclose(f);
        return -4;
    }
    
    uint16_t num_channels = 2;
    uint32_t sample_rate = 48000;
    uint16_t bits_per_sample = 16;
    uint16_t audio_format = 1;
    uint32_t data_size = 0;
    long data_offset = 0;
    
    while (fread(chunk_id, 1, 4, f) == 4 && fread(&chunk_size, 4, 1, f) == 1) {
        if (memcmp(chunk_id, "fmt ", 4) == 0) {
            fread(&audio_format, 2, 1, f);
            fread(&num_channels, 2, 1, f);
            fread(&sample_rate, 4, 1, f);
            fseek(f, 6, SEEK_CUR);
            fread(&bits_per_sample, 2, 1, f);
            if (chunk_size > 16) {
                fseek(f, chunk_size - 16, SEEK_CUR);
            }
        } else if (memcmp(chunk_id, "data", 4) == 0) {
            data_size = chunk_size;
            data_offset = ftell(f);
            break;
        } else {
            fseek(f, chunk_size, SEEK_CUR);
        }
    }
    
    if (data_size == 0 || data_offset == 0) {
        fclose(f);
        return -5;
    }
    
    fseek(f, data_offset, SEEK_SET);
    
    uint32_t bytes_per_frame = (bits_per_sample / 8) * num_channels;
    uint32_t total_frames = data_size / bytes_per_frame;
    
    float *l = (float *)malloc(total_frames * sizeof(float));
    float *r = (float *)malloc(total_frames * sizeof(float));
    if (!l || !r) {
        if (l) free(l);
        if (r) free(r);
        fclose(f);
        return -6;
    }
    
    if (bits_per_sample == 16) {
        int16_t *raw_buf = (int16_t *)malloc(data_size);
        fread(raw_buf, 1, data_size, f);
        for (uint32_t i = 0; i < total_frames; i++) {
            if (num_channels == 2) {
                l[i] = (float)raw_buf[i * 2] / 32768.0f;
                r[i] = (float)raw_buf[i * 2 + 1] / 32768.0f;
            } else {
                float val = (float)raw_buf[i] / 32768.0f;
                l[i] = val;
                r[i] = val;
            }
        }
        free(raw_buf);
    } else if (bits_per_sample == 32 && audio_format == 3) {
        float *raw_buf = (float *)malloc(data_size);
        fread(raw_buf, 1, data_size, f);
        for (uint32_t i = 0; i < total_frames; i++) {
            if (num_channels == 2) {
                l[i] = raw_buf[i * 2];
                r[i] = raw_buf[i * 2 + 1];
            } else {
                l[i] = raw_buf[i];
                r[i] = raw_buf[i];
            }
        }
        free(raw_buf);
    } else {
        memset(l, 0, total_frames * sizeof(float));
        memset(r, 0, total_frames * sizeof(float));
    }
    
    fclose(f);
    
    out_sample->samples_l = l;
    out_sample->samples_r = r;
    out_sample->num_frames = total_frames;
    out_sample->sample_rate = sample_rate;
    return 0;
}
