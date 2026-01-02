#import <FlutterMacOS/FlutterMacOS.h>
#import <Foundation/Foundation.h>


@interface MpvPlayer : NSObject <FlutterTexture>

- (instancetype)initWithTextureRegistry:(id<FlutterTextureRegistry>)registry
                                  width:(int)width
                                 height:(int)height;

- (BOOL)openFile:(NSString *)path error:(NSError **)error;
- (void)play;
- (void)pause;
- (void)seekRelative:(double)seconds;
- (void)seekAbsolute:(double)seconds;
- (double)getPosition;
- (double)getDuration;
- (void)setVolume:(double)volume;
- (void)setSpeed:(double)speed;
- (void)toggleMute;

@property(nonatomic, readonly) int64_t textureId;
@property(nonatomic, readonly) BOOL isInitialized;
@property(nonatomic, readonly) NSString *initializationError;

@end
