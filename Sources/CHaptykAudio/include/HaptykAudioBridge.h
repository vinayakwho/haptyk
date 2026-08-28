#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HaptykBridgeKeyGroup) {
    HaptykBridgeKeyGroupStandard = 0,
    HaptykBridgeKeyGroupSpacebar = 1,
    HaptykBridgeKeyGroupEnter = 2,
    HaptykBridgeKeyGroupBackspace = 3,
    HaptykBridgeKeyGroupModifier = 4
};

@interface HaptykAudioBridge : NSObject

@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, assign) float masterVolume;
@property (nonatomic, assign) float releaseVolume;
@property (nonatomic, assign) BOOL releaseEnabled;
@property (nonatomic, assign) BOOL isMuted;
@property (nonatomic, readonly) uint64_t totalKeystrokes;
@property (nonatomic, readonly, copy, nullable) NSString *currentPackId;

+ (instancetype)sharedBridge;

- (BOOL)startEngine;
- (void)stopEngine;

- (BOOL)loadSoundPackFromDirectory:(NSString *)directoryPath packId:(NSString *)packId name:(NSString *)name;

- (void)playKeyWithGroup:(HaptykBridgeKeyGroup)keyGroup velocity:(float)velocity;
- (void)playRelease;

@end

NS_ASSUME_NONNULL_END
