#import "CglOffscreenContext.h"

@implementation CglOffscreenContext

- (instancetype)init {
  self = [super init];
  if (self) {
    _context = NULL;
    _pixelFormat = NULL;
  }
  return self;
}

- (void)dealloc {
  [self shutdown];
}

- (BOOL)initialize {
  if (_context)
    return YES;

  CGLPixelFormatAttribute attrs[] = {
      kCGLPFAOpenGLProfile,
      (CGLPixelFormatAttribute)kCGLOGLPVersion_3_2_Core,
      kCGLPFAColorSize,
      (CGLPixelFormatAttribute)24,
      kCGLPFAAlphaSize,
      (CGLPixelFormatAttribute)8,
      kCGLPFADepthSize,
      (CGLPixelFormatAttribute)24,
      kCGLPFADoubleBuffer,
      kCGLPFAAccelerated,
      kCGLPFAAllowOfflineRenderers,
      (CGLPixelFormatAttribute)0};

  GLint numPixelFormats = 0;
  CGLError err = CGLChoosePixelFormat(attrs, &_pixelFormat, &numPixelFormats);
  if (err != kCGLNoError || !_pixelFormat) {
    NSLog(@"[CglOffscreenContext] Failed to choose pixel format: %d", err);
    return NO;
  }

  err = CGLCreateContext(_pixelFormat, NULL, &_context);
  if (err != kCGLNoError || !_context) {
    NSLog(@"[CglOffscreenContext] Failed to create context: %d", err);
    CGLDestroyPixelFormat(_pixelFormat);
    _pixelFormat = NULL;
    return NO;
  }

  NSLog(@"[CglOffscreenContext] OpenGL context created successfully");
  return YES;
}

- (void)shutdown {
  if (_context) {
    CGLSetCurrentContext(NULL);
    CGLDestroyContext(_context);
    _context = NULL;
  }
  if (_pixelFormat) {
    CGLDestroyPixelFormat(_pixelFormat);
    _pixelFormat = NULL;
  }
}

- (BOOL)makeCurrent {
  if (!_context)
    return NO;
  CGLError err = CGLSetCurrentContext(_context);
  return err == kCGLNoError;
}

- (void)doneCurrent {
  CGLSetCurrentContext(NULL);
}

@end
