#pragma once

#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl3.h>

// CGL Offscreen Context - macOS equivalent of WglOffscreenContext
@interface CglOffscreenContext : NSObject

@property(nonatomic, readonly) CGLContextObj context;
@property(nonatomic, readonly) CGLPixelFormatObj pixelFormat;

- (BOOL)initialize;
- (void)shutdown;
- (BOOL)makeCurrent;
- (void)doneCurrent;

@end
