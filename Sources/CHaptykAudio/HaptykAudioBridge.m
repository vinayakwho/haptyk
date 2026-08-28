#import "HaptykAudioBridge.h"
#include "HaptykAudioCore.h"

@interface HaptykAudioBridge () {
    HaptykEngineContext _engineCtx;
    BOOL _initialized;
}
@property (nonatomic, readwrite, copy, nullable) NSString *currentPackId;
@end

@implementation HaptykAudioBridge

+ (instancetype)sharedBridge {
    static HaptykAudioBridge *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[HaptykAudioBridge alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        int res = haptyk_engine_init(&_engineCtx, 48000.0, 128);
        if (res == 0) {
            _initialized = YES;
            haptyk_engine_start(&_engineCtx);
            NSLog(@"[HaptykAudioBridge] Audio engine initialized & started successfully.");
        } else {
            NSLog(@"[HaptykAudioBridge] Failed to init audio engine: %d", res);
        }
    }
    return self;
}

- (void)dealloc {
    if (_initialized) {
        haptyk_engine_destroy(&_engineCtx);
    }
}

- (BOOL)isRunning {
    return _initialized;
}

- (BOOL)startEngine {
    if (!_initialized) {
        int res = haptyk_engine_init(&_engineCtx, 48000.0, 128);
        if (res != 0) return NO;
        _initialized = YES;
    }
    return haptyk_engine_start(&_engineCtx) == 0;
}

- (void)stopEngine {
    if (_initialized) {
        haptyk_engine_stop(&_engineCtx);
    }
}

- (void)setMasterVolume:(float)masterVolume {
    if (_initialized) {
        haptyk_engine_set_master_volume(&_engineCtx, masterVolume);
    }
}

- (float)masterVolume {
    return _engineCtx.master_volume;
}

- (void)setReleaseVolume:(float)releaseVolume {
    if (_initialized) {
        haptyk_engine_set_release_volume(&_engineCtx, releaseVolume);
    }
}

- (float)releaseVolume {
    return _engineCtx.release_volume;
}

- (void)setReleaseEnabled:(BOOL)releaseEnabled {
    if (_initialized) {
        haptyk_engine_set_release_enabled(&_engineCtx, releaseEnabled);
    }
}

- (BOOL)releaseEnabled {
    return _engineCtx.release_enabled;
}

- (void)setIsMuted:(BOOL)isMuted {
    if (_initialized) {
        haptyk_engine_set_muted(&_engineCtx, isMuted);
    }
}

- (BOOL)isMuted {
    return _engineCtx.muted;
}

- (uint64_t)totalKeystrokes {
    return _engineCtx.total_keystrokes_played;
}

- (BOOL)loadSoundPackFromDirectory:(NSString *)directoryPath packId:(NSString *)packId name:(NSString *)name {
    if (!_initialized) return NO;
    
    HaptykSoundPack newPack;
    memset(&newPack, 0, sizeof(HaptykSoundPack));
    strncpy(newPack.pack_id, [packId UTF8String], sizeof(newPack.pack_id) - 1);
    strncpy(newPack.pack_name, [name UTF8String], sizeof(newPack.pack_name) - 1);
    
    NSArray *groups = @[@"standard", @"spacebar", @"enter", @"backspace", @"modifier"];
    NSArray *tiers = @[@"soft", @"medium", @"hard", @"slam"];
    
    int loadedCount = 0;
    for (NSUInteger g = 0; g < groups.count; g++) {
        for (NSUInteger t = 0; t < tiers.count; t++) {
            NSString *filename = [NSString stringWithFormat:@"%@_%@.wav", groups[g], tiers[t]];
            NSString *fullPath = [directoryPath stringByAppendingPathComponent:filename];
            
            if (![[NSFileManager defaultManager] fileExistsAtPath:fullPath]) {
                fullPath = [directoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"standard_%@.wav", tiers[t]]];
            }
            
            int rc = haptyk_sound_pack_load_wav(&newPack.samples[g][t], [fullPath UTF8String]);
            if (rc == 0) loadedCount++;
        }
    }
    
    NSString *releasePath = [directoryPath stringByAppendingPathComponent:@"release.wav"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:releasePath]) {
        haptyk_sound_pack_load_wav(&newPack.release_sample, [releasePath UTF8String]);
        newPack.has_release = YES;
    }
    
    // Atomically swap pack in engine
    haptyk_sound_pack_free(&_engineCtx.current_pack);
    _engineCtx.current_pack = newPack;
    _engineCtx.pack_loaded = YES;
    self.currentPackId = packId;
    
    NSLog(@"[HaptykAudioBridge] SoundPack '%@' loaded with %d WAV files.", name, loadedCount);
    return YES;
}

- (void)playKeyWithGroup:(HaptykBridgeKeyGroup)keyGroup velocity:(float)velocity {
    if (!_initialized) return;
    haptyk_engine_play_key(&_engineCtx, (HaptykKeyGroup)keyGroup, velocity);
}

- (void)playRelease {
    if (!_initialized) return;
    haptyk_engine_play_release(&_engineCtx);
}

@end
