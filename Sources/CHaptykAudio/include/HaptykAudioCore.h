#ifndef HAPTYK_AUDIO_CORE_H
#define HAPTYK_AUDIO_CORE_H

#include <stdint.h>
#include <stdbool.h>
#include <AudioUnit/AudioUnit.h>

#ifdef __cplusplus
extern "C" {
#endif

#define HAPTYK_MAX_VOICES 32
#define HAPTYK_NUM_KEY_GROUPS 5 // standard=0, spacebar=1, enter=2, backspace=3, modifier=4
#define HAPTYK_NUM_TIERS 4      // soft=0, medium=1, hard=2, slam=3

typedef enum {
    HAPTYK_KEY_STANDARD = 0,
    HAPTYK_KEY_SPACEBAR = 1,
    HAPTYK_KEY_ENTER = 2,
    HAPTYK_KEY_BACKSPACE = 3,
    HAPTYK_KEY_MODIFIER = 4
} HaptykKeyGroup;

typedef struct {
    float *samples_l;
    float *samples_r;
    uint32_t num_frames;
    uint32_t sample_rate;
} HaptykAudioSample;

typedef struct {
    HaptykAudioSample samples[HAPTYK_NUM_KEY_GROUPS][HAPTYK_NUM_TIERS];
    HaptykAudioSample release_sample;
    bool has_release;
    char pack_id[64];
    char pack_name[64];
} HaptykSoundPack;

typedef struct {
    bool active;
    const float *pcm_l;
    const float *pcm_r;
    uint32_t total_frames;
    double current_frame;
    double pitch_ratio;
    float volume_l;
    float volume_r;
} HaptykVoice;

typedef struct {
    AudioUnit output_unit;
    double sample_rate;
    uint32_t buffer_size_frames;
    
    HaptykSoundPack current_pack;
    bool pack_loaded;
    
    HaptykVoice voices[HAPTYK_MAX_VOICES];
    
    float master_volume;
    float release_volume;
    bool release_enabled;
    bool muted;
    
    // Performance stats
    uint64_t total_keystrokes_played;
    double last_render_time_us;
} HaptykEngineContext;

// Core Engine API
int haptyk_engine_init(HaptykEngineContext *ctx, double sample_rate, uint32_t buffer_frames);
void haptyk_engine_destroy(HaptykEngineContext *ctx);

int haptyk_engine_start(HaptykEngineContext *ctx);
void haptyk_engine_stop(HaptykEngineContext *ctx);

void haptyk_engine_play_key(HaptykEngineContext *ctx, HaptykKeyGroup key_group, float velocity);
void haptyk_engine_play_release(HaptykEngineContext *ctx);

void haptyk_engine_set_master_volume(HaptykEngineContext *ctx, float volume);
void haptyk_engine_set_release_volume(HaptykEngineContext *ctx, float volume);
void haptyk_engine_set_release_enabled(HaptykEngineContext *ctx, bool enabled);
void haptyk_engine_set_muted(HaptykEngineContext *ctx, bool muted);

// Sample management
void haptyk_sound_pack_free(HaptykSoundPack *pack);
int haptyk_sound_pack_load_wav(HaptykAudioSample *out_sample, const char *filepath);

#ifdef __cplusplus
}
#endif

#endif /* HAPTYK_AUDIO_CORE_H */
