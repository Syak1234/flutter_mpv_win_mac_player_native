#import "MpvNativeTexturePlugin.h"
#import "MpvPlayer.h"

@interface MpvNativeTexturePlugin ()
@property(nonatomic, strong)
    NSMutableDictionary<NSNumber *, MpvPlayer *> *players;
@property(nonatomic, weak) id<FlutterTextureRegistry> textureRegistry;
@end

@implementation MpvNativeTexturePlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:@"mpv_native_texture"
                                  binaryMessenger:[registrar messenger]];
  MpvNativeTexturePlugin *instance = [[MpvNativeTexturePlugin alloc] init];
  instance.textureRegistry = [registrar textures];
  instance.players = [NSMutableDictionary dictionary];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall *)call
                  result:(FlutterResult)result {
  if ([@"create" isEqualToString:call.method]) {
    NSNumber *width = call.arguments[@"width"] ?: @1280;
    NSNumber *height = call.arguments[@"height"] ?: @720;

    MpvPlayer *player =
        [[MpvPlayer alloc] initWithTextureRegistry:self.textureRegistry
                                             width:[width intValue]
                                            height:[height intValue]];

    if (!player.isInitialized) {
      result([FlutterError errorWithCode:@"init_failed"
                                 message:@"Failed to initialize MPV player"
                                 details:player.initializationError]);
      return;
    }

    NSNumber *textureId = @(player.textureId);
    self.players[textureId] = player;
    result(textureId);

  } else if ([@"dispose" isEqualToString:call.method]) {
    NSNumber *textureId = call.arguments[@"textureId"];
    [self.players removeObjectForKey:textureId];
    result(nil);

  } else {
    NSNumber *textureId = call.arguments[@"textureId"];
    MpvPlayer *player = self.players[textureId];

    if (!player) {
      result([FlutterError errorWithCode:@"not_found"
                                 message:@"Player not found"
                                 details:nil]);
      return;
    }

    if ([@"open" isEqualToString:call.method]) {
      NSString *path = call.arguments[@"path"];
      NSError *error;
      if ([player openFile:path error:&error]) {
        result(nil);
      } else {
        result([FlutterError errorWithCode:@"open_failed"
                                   message:error.localizedDescription
                                   details:nil]);
      }

    } else if ([@"play" isEqualToString:call.method]) {
      [player play];
      result(nil);

    } else if ([@"pause" isEqualToString:call.method]) {
      [player pause];
      result(nil);

    } else if ([@"seekRelative" isEqualToString:call.method]) {
      NSNumber *seconds = call.arguments[@"seconds"];
      [player seekRelative:[seconds doubleValue]];
      result(nil);

    } else if ([@"seekAbsolute" isEqualToString:call.method]) {
      NSNumber *seconds = call.arguments[@"seconds"];
      [player seekAbsolute:[seconds doubleValue]];
      result(nil);

    } else if ([@"getPosition" isEqualToString:call.method]) {
      result(@([player getPosition]));

    } else if ([@"getDuration" isEqualToString:call.method]) {
      result(@([player getDuration]));

    } else if ([@"setVolume" isEqualToString:call.method]) {
      NSNumber *volume = call.arguments[@"volume"];
      [player setVolume:[volume doubleValue]];
      result(nil);

    } else if ([@"setSpeed" isEqualToString:call.method]) {
      NSNumber *speed = call.arguments[@"speed"];
      [player setSpeed:[speed doubleValue]];
      result(nil);

    } else if ([@"toggleMute" isEqualToString:call.method]) {
      [player toggleMute];
      result(nil);

    } else {
      result(FlutterMethodNotImplemented);
    }
  }
}

@end
