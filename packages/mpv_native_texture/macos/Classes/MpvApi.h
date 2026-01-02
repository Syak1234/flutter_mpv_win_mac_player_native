#pragma once

#import <Foundation/Foundation.h>
#include <dlfcn.h>

// MPV type definitions (from mpv headers)
typedef struct mpv_handle mpv_handle;
typedef struct mpv_render_context mpv_render_context;

typedef enum mpv_format {
  MPV_FORMAT_NONE = 0,
  MPV_FORMAT_STRING = 1,
  MPV_FORMAT_OSD_STRING = 2,
  MPV_FORMAT_FLAG = 3,
  MPV_FORMAT_INT64 = 4,
  MPV_FORMAT_DOUBLE = 5,
  MPV_FORMAT_NODE = 6,
  MPV_FORMAT_NODE_ARRAY = 7,
  MPV_FORMAT_NODE_MAP = 8,
  MPV_FORMAT_BYTE_ARRAY = 9
} mpv_format;

typedef enum mpv_render_param_type {
  MPV_RENDER_PARAM_INVALID = 0,
  MPV_RENDER_PARAM_API_TYPE = 1,
  MPV_RENDER_PARAM_OPENGL_INIT_PARAMS = 2,
  MPV_RENDER_PARAM_OPENGL_FBO = 3,
  MPV_RENDER_PARAM_FLIP_Y = 4,
  MPV_RENDER_PARAM_DEPTH = 5,
  MPV_RENDER_PARAM_ICC_PROFILE = 6,
  MPV_RENDER_PARAM_AMBIENT_LIGHT = 7,
  MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME = 10,
  MPV_RENDER_PARAM_SKIP_RENDERING = 11,
  MPV_RENDER_PARAM_DRM_DISPLAY = 12,
  MPV_RENDER_PARAM_DRM_DRAW_SURFACE_SIZE = 13,
  MPV_RENDER_PARAM_DRM_DISPLAY_V2 = 15,
  MPV_RENDER_PARAM_SW_SIZE = 16,
  MPV_RENDER_PARAM_SW_FORMAT = 17,
  MPV_RENDER_PARAM_SW_STRIDE = 18,
  MPV_RENDER_PARAM_SW_POINTER = 19,
  MPV_RENDER_PARAM_NEXT_FRAME_INFO = 20,
  MPV_RENDER_PARAM_TARGET_TIME = 21
} mpv_render_param_type;

typedef struct mpv_render_param {
  mpv_render_param_type type;
  void *data;
} mpv_render_param;

typedef struct mpv_opengl_init_params {
  void *(*get_proc_address)(void *ctx, const char *name);
  void *get_proc_address_ctx;
} mpv_opengl_init_params;

typedef struct mpv_opengl_fbo {
  int fbo;
  int w;
  int h;
  int internal_format;
} mpv_opengl_fbo;

#define MPV_RENDER_API_TYPE_OPENGL "opengl"

typedef void (*mpv_render_update_fn)(void *cb_ctx);

// MpvApi class - dynamic library loader
@interface MpvApi : NSObject

@property(nonatomic, assign) void *handle;

// client.h functions
@property(nonatomic, assign) unsigned long (*mpv_client_api_version)(void);
@property(nonatomic, assign) const char *(*mpv_error_string)(int);
@property(nonatomic, assign) mpv_handle *(*mpv_create)(void);
@property(nonatomic, assign) int (*mpv_initialize)(mpv_handle *);
@property(nonatomic, assign) void (*mpv_destroy)(mpv_handle *);
@property(nonatomic, assign) int (*mpv_set_option_string)
    (mpv_handle *, const char *, const char *);
@property(nonatomic, assign) int (*mpv_set_property)
    (mpv_handle *, const char *, mpv_format, void *);
@property(nonatomic, assign) int (*mpv_get_property)
    (mpv_handle *, const char *, mpv_format, void *);
@property(nonatomic, assign) int (*mpv_command)
    (mpv_handle *, const char *const *);

// render.h functions
@property(nonatomic, assign) int (*mpv_render_context_create)
    (mpv_render_context **, mpv_handle *, mpv_render_param *);
@property(nonatomic, assign) void (*mpv_render_context_free)
    (mpv_render_context *);
@property(nonatomic, assign) void (*mpv_render_context_set_update_callback)
    (mpv_render_context *, mpv_render_update_fn, void *);
@property(nonatomic, assign) int (*mpv_render_context_render)
    (mpv_render_context *, mpv_render_param *);

- (BOOL)load;
- (void)unload;

@end
