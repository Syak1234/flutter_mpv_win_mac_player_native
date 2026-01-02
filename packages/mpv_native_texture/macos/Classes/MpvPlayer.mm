#define GL_SILENCE_DEPRECATION
#import "MpvPlayer.h"
#import "CglOffscreenContext.h"
#import "MpvApi.h"
#import <CoreVideo/CoreVideo.h>
#import <FlutterMacOS/FlutterMacOS.h>
#import <IOSurface/IOSurface.h>
#import <OpenGL/CGLIOSurface.h>
#import <OpenGL/gl3.h>

// GL constants if not defined
#ifndef GL_FRAMEBUFFER
#define GL_FRAMEBUFFER 0x8D40
#endif
#ifndef GL_COLOR_ATTACHMENT0
#define GL_COLOR_ATTACHMENT0 0x8CE0
#endif
#ifndef GL_FRAMEBUFFER_COMPLETE
#define GL_FRAMEBUFFER_COMPLETE 0x8CD5
#endif
#ifndef GL_RGBA8
#define GL_RGBA8 0x8058
#endif

typedef struct {
  CVPixelBufferRef pixelBuffer;
  GLuint texture;
  GLuint fbo;
} MpvFrameBuffer;

@interface MpvPlayer () {
  MpvFrameBuffer _buffers[2];
}

@property(nonatomic, assign) int64_t textureId;
@property(nonatomic, assign) BOOL isInitialized;
@property(nonatomic, copy) NSString *initializationError;
@property(nonatomic, assign) id<FlutterTextureRegistry> textureRegistry;

@property(nonatomic, strong) MpvApi *api;
@property(nonatomic, strong) CglOffscreenContext *glContext;
@property(nonatomic, assign) mpv_handle *mpv;
@property(nonatomic, assign) mpv_render_context *mpvGL;

@property(nonatomic, assign) int frameWidth;
@property(nonatomic, assign) int frameHeight;

@property(nonatomic, assign) int currentWriteBuffer;
@property(nonatomic, assign) int currentReadBuffer;
@property(nonatomic, assign) BOOL hasNewFrame;
@property(nonatomic, strong) NSLock *bufferLock;

@property(nonatomic, assign) BOOL running;
@property(nonatomic, assign) BOOL destroying;
@property(nonatomic, assign) BOOL needsRender;
@property(nonatomic, strong) NSCondition *renderCondition;
@property(nonatomic, strong) NSThread *renderThread;

- (void)requestRender;

@end

static void *mpv_get_proc_address(void *ctx, const char *name) {
  CFStringRef symbolName = CFStringCreateWithCString(kCFAllocatorDefault, name,
                                                     kCFStringEncodingASCII);
  CFBundleRef bundle =
      CFBundleGetBundleWithIdentifier(CFSTR("com.apple.opengl"));
  void *addr = NULL;
  if (bundle) {
    addr = CFBundleGetFunctionPointerForName(bundle, symbolName);
  }
  CFRelease(symbolName);
  return addr;
}

static void on_mpv_render_update(void *ctx) {
  MpvPlayer *player = (__bridge MpvPlayer *)ctx;
  [player requestRender];
}

@implementation MpvPlayer

- (instancetype)initWithTextureRegistry:(id<FlutterTextureRegistry>)registry
                                  width:(int)width
                                 height:(int)height {
  self = [super init];
  if (self) {
    _textureRegistry = registry;
    _frameWidth = MAX(16, width);
    _frameHeight = MAX(16, height);
    _destroying = NO;
    _running = YES;
    _needsRender = NO;
    _currentWriteBuffer = 0;
    _currentReadBuffer = -1;
    _hasNewFrame = NO;

    _bufferLock = [[NSLock alloc] init];
    _renderCondition = [[NSCondition alloc] init];

    // Register texture
    _textureId = [registry registerTexture:self];
    NSLog(@"[MpvPlayer] Registered texture ID: %lld", _textureId);

    // Initialize OpenGL context
    _glContext = [[CglOffscreenContext alloc] init];
    if (![_glContext initialize]) {
      _initializationError = @"Failed to create OpenGL context";
      return self;
    }

    if (![_glContext makeCurrent]) {
      _initializationError = @"Failed to make OpenGL context current";
      return self;
    }

    // Load MPV library
    _api = [[MpvApi alloc] init];
    if (![_api load]) {
      _initializationError = @"Failed to load libmpv";
      [_glContext doneCurrent];
      return self;
    }

    // Create MPV instance
    _mpv = _api.mpv_create();
    if (!_mpv) {
      _initializationError = @"mpv_create() failed";
      [_glContext doneCurrent];
      return self;
    }

    // Optimize MPV options for performance
    _api.mpv_set_option_string(_mpv, "vo", "libmpv");
    _api.mpv_set_option_string(_mpv, "hwdec",
                               "videotoolbox"); // Hardware acceleration
    _api.mpv_set_option_string(_mpv, "profile", "fast");
    _api.mpv_set_option_string(_mpv, "video-sync", "display-resample");
    _api.mpv_set_option_string(_mpv, "keep-open", "yes");
    _api.mpv_set_option_string(_mpv, "terminal", "no");
    _api.mpv_set_option_string(_mpv, "video-rotate", "0");
    _api.mpv_set_option_string(_mpv, "msg-level", "all=warn");
    _api.mpv_set_option_string(_mpv, "vd-lavc-threads",
                               "4"); // Parallel decoding
    _api.mpv_set_option_string(_mpv, "cache-secs",
                               "10"); // Increase cache for smooth playback

    // Initialize MPV
    int rc = _api.mpv_initialize(_mpv);
    if (rc < 0) {
      _initializationError =
          [NSString stringWithFormat:@"mpv_initialize failed: %s",
                                     _api.mpv_error_string(rc)];
      [_glContext doneCurrent];
      return self;
    }

    // Create IOSurface backed FBOs (Zero-Copy)
    if (![self createBuffers]) {
      _initializationError = @"Failed to create zero-copy buffers";
      [_glContext doneCurrent];
      return self;
    }

    // Initialize MPV OpenGL render context
    mpv_opengl_init_params gl_init = {
        .get_proc_address = mpv_get_proc_address,
        .get_proc_address_ctx = NULL,
    };

    mpv_render_param params[] = {
        {MPV_RENDER_PARAM_API_TYPE, (void *)MPV_RENDER_API_TYPE_OPENGL},
        {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl_init},
        {MPV_RENDER_PARAM_INVALID, NULL}};

    rc = _api.mpv_render_context_create(&_mpvGL, _mpv, params);
    if (rc < 0 || !_mpvGL) {
      _initializationError =
          [NSString stringWithFormat:@"mpv_render_context_create failed: %s",
                                     _api.mpv_error_string(rc)];
      [_glContext doneCurrent];
      return self;
    }

    // Set render callback
    _api.mpv_render_context_set_update_callback(_mpvGL, on_mpv_render_update,
                                                (__bridge void *)self);

    [_glContext doneCurrent];

    _isInitialized = YES;
    NSLog(@"[MpvPlayer] Optimization: Zero-copy rendering initialized (Width: "
          @"%d, Height: %d)",
          _frameWidth, _frameHeight);

    // Start render thread
    _renderThread = [[NSThread alloc] initWithTarget:self
                                            selector:@selector(renderThreadMain)
                                              object:nil];
    _renderThread.name = @"MpvRenderThread";
    _renderThread.threadPriority = 1.0; // Higher priority for smoothness
    [_renderThread start];
  }
  return self;
}

- (void)dealloc {
  NSLog(@"[MpvPlayer] Destructor starting");
  _destroying = YES;
  _running = NO;

  [_renderCondition lock];
  _needsRender = YES;
  [_renderCondition signal];
  [_renderCondition unlock];

  // Wait for render thread
  while (_renderThread && ![_renderThread isFinished]) {
    [NSThread sleepForTimeInterval:0.01];
  }

  if (_textureRegistry && _textureId >= 0) {
    [_textureRegistry unregisterTexture:_textureId];
  }

  if ([_glContext makeCurrent]) {
    [self destroyBuffers];
    [_glContext doneCurrent];
  }

  if (_mpvGL) {
    _api.mpv_render_context_free(_mpvGL);
    _mpvGL = NULL;
  }

  if (_mpv) {
    _api.mpv_destroy(_mpv);
    _mpv = NULL;
  }

  [_api unload];
  [_glContext shutdown];

  NSLog(@"[MpvPlayer] Destructor complete");
}

#pragma mark - Buffer Management (Zero-Copy)

- (BOOL)createBuffers {
  for (int i = 0; i < 2; i++) {
    NSDictionary *options = @{
      (NSString *)kCVPixelBufferCGImageCompatibilityKey : @YES,
      (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES,
      (NSString *)kCVPixelBufferIOSurfacePropertiesKey : @{}
    };

    CVReturn status = CVPixelBufferCreate(
        kCFAllocatorDefault, _frameWidth, _frameHeight,
        kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)options,
        &_buffers[i].pixelBuffer);

    if (status != kCVReturnSuccess) {
      NSLog(@"[MpvPlayer] Failed to create CVPixelBuffer %d", i);
      return NO;
    }

    IOSurfaceRef surface = CVPixelBufferGetIOSurface(_buffers[i].pixelBuffer);
    if (!surface) {
      NSLog(@"[MpvPlayer] Failed to get IOSurface from CVPixelBuffer %d", i);
      return NO;
    }

    glGenTextures(1, &_buffers[i].texture);
    glBindTexture(GL_TEXTURE_RECTANGLE, _buffers[i].texture);

    CGLError err = CGLTexImageIOSurface2D(
        _glContext.context, GL_TEXTURE_RECTANGLE, GL_RGBA, _frameWidth,
        _frameHeight, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, surface, 0);

    if (err != kCGLNoError) {
      NSLog(@"[MpvPlayer] CGLTexImageIOSurface2D failed: %d", err);
      return NO;
    }

    glGenFramebuffers(1, &_buffers[i].fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, _buffers[i].fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_RECTANGLE, _buffers[i].texture, 0);

    GLenum glStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (glStatus != GL_FRAMEBUFFER_COMPLETE) {
      NSLog(@"[MpvPlayer] Framebuffer %d incomplete: 0x%x", i, glStatus);
      return NO;
    }
  }

  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  glBindTexture(GL_TEXTURE_RECTANGLE, 0);
  return YES;
}

- (void)destroyBuffers {
  for (int i = 0; i < 2; i++) {
    if (_buffers[i].fbo) {
      glDeleteFramebuffers(1, &_buffers[i].fbo);
      _buffers[i].fbo = 0;
    }
    if (_buffers[i].texture) {
      glDeleteTextures(1, &_buffers[i].texture);
      _buffers[i].texture = 0;
    }
    if (_buffers[i].pixelBuffer) {
      CFRelease(_buffers[i].pixelBuffer);
      _buffers[i].pixelBuffer = NULL;
    }
  }
}

#pragma mark - Render Thread

- (void)requestRender {
  [_renderCondition lock];
  _needsRender = YES;
  [_renderCondition signal];
  [_renderCondition unlock];
}

- (void)renderThreadMain {
  NSLog(@"[MpvPlayer] Optimized render thread started");

  @try {
    while (_running && !_destroying) {
      [_renderCondition lock];
      while (!_needsRender && _running && !_destroying) {
        [_renderCondition wait];
      }
      if (!_running || _destroying) {
        [_renderCondition unlock];
        break;
      }
      _needsRender = NO;
      [_renderCondition unlock];

      if (![_glContext makeCurrent]) {
        continue;
      }

      int writeIdx = _currentWriteBuffer;
      GLuint fboHandle = _buffers[writeIdx].fbo;

      if (fboHandle == 0 || !_mpvGL) {
        [_glContext doneCurrent];
        continue;
      }

      // Render directly into IOSurface texture
      mpv_opengl_fbo fbo = {.fbo = (int)fboHandle,
                            .w = _frameWidth,
                            .h = _frameHeight,
                            .internal_format = GL_RGBA8};

      int flip_y = 0;
      mpv_render_param rparams[] = {{MPV_RENDER_PARAM_OPENGL_FBO, &fbo},
                                    {MPV_RENDER_PARAM_FLIP_Y, &flip_y},
                                    {MPV_RENDER_PARAM_INVALID, NULL}};

      glViewport(0, 0, _frameWidth, _frameHeight);
      _api.mpv_render_context_render(_mpvGL, rparams);

      // Critical for ensuring GPU has finished rendering before Flutter reads
      // it
      glFlush();

      [_glContext doneCurrent];

      // Swap buffers safely
      [_bufferLock lock];
      _currentReadBuffer = writeIdx;
      _currentWriteBuffer = (writeIdx + 1) % 2;
      _hasNewFrame = YES;
      [_bufferLock unlock];

      // Notify Flutter
      [_textureRegistry textureFrameAvailable:_textureId];
    }
  } @catch (NSException *e) {
    NSLog(@"[MpvPlayer] Render thread exception: %@", e);
  }

  NSLog(@"[MpvPlayer] Optimized render thread exiting");
}

#pragma mark - FlutterTexture

- (CVPixelBufferRef)copyPixelBuffer {
  if (_destroying)
    return NULL;

  [_bufferLock lock];
  if (_currentReadBuffer < 0) {
    [_bufferLock unlock];
    return NULL;
  }

  CVPixelBufferRef buffer = _buffers[_currentReadBuffer].pixelBuffer;
  if (buffer) {
    CFRetain(buffer); // Flutter will release it
  }
  _hasNewFrame = NO;
  [_bufferLock unlock];

  return buffer;
}

#pragma mark - Control Methods

- (BOOL)openFile:(NSString *)path error:(NSError **)error {
  if (!_mpv || !_isInitialized) {
    if (error) {
      *error =
          [NSError errorWithDomain:@"MpvPlayer"
                              code:-1
                          userInfo:@{
                            NSLocalizedDescriptionKey : _initializationError
                                ?: @"Player not initialized"
                          }];
    }
    return NO;
  }

  const char *cmd[] = {"loadfile", path.UTF8String, NULL};
  int rc = _api.mpv_command(_mpv, cmd);

  if (rc < 0) {
    if (error) {
      *error = [NSError
          errorWithDomain:@"MpvPlayer"
                     code:rc
                 userInfo:@{
                   NSLocalizedDescriptionKey :
                       [NSString stringWithUTF8String:_api.mpv_error_string(rc)]
                 }];
    }
    return NO;
  }

  [self requestRender];
  return YES;
}

- (void)play {
  if (!_mpv)
    return;
  int flag = 0;
  _api.mpv_set_property(_mpv, "pause", MPV_FORMAT_FLAG, &flag);
  [self requestRender];
}

- (void)pause {
  if (!_mpv)
    return;
  int flag = 1;
  _api.mpv_set_property(_mpv, "pause", MPV_FORMAT_FLAG, &flag);
  [self requestRender];
}

- (void)seekRelative:(double)seconds {
  if (!_mpv)
    return;
  NSString *seekStr = [NSString stringWithFormat:@"%.3f", seconds];
  const char *cmd[] = {"seek", seekStr.UTF8String, "relative", NULL};
  _api.mpv_command(_mpv, cmd);
  [self requestRender];
}

- (void)seekAbsolute:(double)seconds {
  if (!_mpv)
    return;
  _api.mpv_set_property(_mpv, "time-pos", MPV_FORMAT_DOUBLE, &seconds);
  [self requestRender];
}

- (double)getPosition {
  if (!_mpv)
    return 0.0;
  double pos = 0.0;
  _api.mpv_get_property(_mpv, "time-pos", MPV_FORMAT_DOUBLE, &pos);
  return pos;
}

- (double)getDuration {
  if (!_mpv)
    return 0.0;
  double dur = 0.0;
  _api.mpv_get_property(_mpv, "duration", MPV_FORMAT_DOUBLE, &dur);
  return dur;
}

- (void)setVolume:(double)volume {
  if (!_mpv)
    return;
  double vol = (volume < 0.0 ? 0.0 : (volume > 1.0 ? 1.0 : volume)) * 100.0;
  _api.mpv_set_property(_mpv, "volume", MPV_FORMAT_DOUBLE, &vol);
}

- (void)setSpeed:(double)speed {
  if (!_mpv)
    return;
  speed = (speed < 0.1 ? 0.1 : (speed > 4.0 ? 4.0 : speed));
  _api.mpv_set_property(_mpv, "speed", MPV_FORMAT_DOUBLE, &speed);
}

- (void)toggleMute {
  if (!_mpv)
    return;
  int mute = 0;
  _api.mpv_get_property(_mpv, "mute", MPV_FORMAT_FLAG, &mute);
  mute = !mute;
  _api.mpv_set_property(_mpv, "mute", MPV_FORMAT_FLAG, &mute);
}

@end
