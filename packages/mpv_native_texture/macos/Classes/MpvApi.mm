#import "MpvApi.h"

@implementation MpvApi

- (instancetype)init {
  self = [super init];
  if (self) {
    _handle = NULL;
  }
  return self;
}

- (void)dealloc {
  [self unload];
}

- (BOOL)load {
  if (_handle)
    return YES;

  // First try to load from the app bundle
  NSBundle *mainBundle = [NSBundle mainBundle];
  // Try with .2 suffix first as requested by user
  NSString *bundlePath = [mainBundle pathForResource:@"libmpv.2"
                                              ofType:@"dylib"];
  if (!bundlePath) {
    bundlePath = [mainBundle pathForResource:@"libmpv" ofType:@"dylib"];
  }

  if (bundlePath) {
    _handle = dlopen(bundlePath.UTF8String, RTLD_NOW | RTLD_LOCAL);
    if (_handle) {
      NSLog(@"[MpvApi] Loaded mpv from bundle: %@", bundlePath);
    }
  }

  // Try framework path (for vendored libraries)
  if (!_handle) {
    NSString *frameworkPath = [[mainBundle privateFrameworksPath]
        stringByAppendingPathComponent:@"libmpv.2.dylib"];
    _handle = dlopen(frameworkPath.UTF8String, RTLD_NOW | RTLD_LOCAL);
    if (!_handle) {
      frameworkPath = [[mainBundle privateFrameworksPath]
          stringByAppendingPathComponent:@"libmpv.dylib"];
      _handle = dlopen(frameworkPath.UTF8String, RTLD_NOW | RTLD_LOCAL);
    }

    if (_handle) {
      NSLog(@"[MpvApi] Loaded mpv from frameworks: %@", frameworkPath);
    }
  }

  // Fallback to system paths (REMOVED: Only use bundled library)
  /*
  if (!_handle) {
    const char *paths[] = {"libmpv.dylib", "/opt/homebrew/lib/libmpv.dylib",
                           "/usr/local/lib/libmpv.dylib",
                           "/opt/local/lib/libmpv.dylib", NULL};

    for (int i = 0; paths[i] != NULL; i++) {
      _handle = dlopen(paths[i], RTLD_NOW | RTLD_LOCAL);
      if (_handle) {
        NSLog(@"[MpvApi] Loaded mpv from: %s", paths[i]);
        break;
      }
    }
  }
  */

  if (!_handle) {
    NSLog(@"[MpvApi] Failed to load bundled libmpv.dylib.");
    return NO;
  }

  // Load all symbols
  _mpv_client_api_version =
      (unsigned long (*)(void))dlsym(_handle, "mpv_client_api_version");
  _mpv_error_string = (const char *(*)(int))dlsym(_handle, "mpv_error_string");
  _mpv_create = (mpv_handle * (*)(void)) dlsym(_handle, "mpv_create");
  _mpv_initialize = (int (*)(mpv_handle *))dlsym(_handle, "mpv_initialize");
  _mpv_destroy = (void (*)(mpv_handle *))dlsym(_handle, "mpv_destroy");
  _mpv_set_option_string =
      (int (*)(mpv_handle *, const char *, const char *))dlsym(
          _handle, "mpv_set_option_string");
  _mpv_set_property = (int (*)(mpv_handle *, const char *, mpv_format,
                               void *))dlsym(_handle, "mpv_set_property");
  _mpv_get_property = (int (*)(mpv_handle *, const char *, mpv_format,
                               void *))dlsym(_handle, "mpv_get_property");
  _mpv_command =
      (int (*)(mpv_handle *, const char *const *))dlsym(_handle, "mpv_command");
  _mpv_render_context_create =
      (int (*)(mpv_render_context **, mpv_handle *, mpv_render_param *))dlsym(
          _handle, "mpv_render_context_create");
  _mpv_render_context_free =
      (void (*)(mpv_render_context *))dlsym(_handle, "mpv_render_context_free");
  _mpv_render_context_set_update_callback =
      (void (*)(mpv_render_context *, mpv_render_update_fn, void *))dlsym(
          _handle, "mpv_render_context_set_update_callback");
  _mpv_render_context_render =
      (int (*)(mpv_render_context *, mpv_render_param *))dlsym(
          _handle, "mpv_render_context_render");

  // Verify all critical symbols loaded
  BOOL ok = _mpv_client_api_version && _mpv_error_string && _mpv_create &&
            _mpv_initialize && _mpv_destroy && _mpv_set_option_string &&
            _mpv_set_property && _mpv_get_property && _mpv_command &&
            _mpv_render_context_create && _mpv_render_context_free &&
            _mpv_render_context_set_update_callback &&
            _mpv_render_context_render;

  if (!ok) {
    NSLog(@"[MpvApi] Failed to load all required mpv symbols");
    [self unload];
    return NO;
  }

  unsigned long version = _mpv_client_api_version();
  NSLog(@"[MpvApi] mpv API version: 0x%lx (major=%lu, minor=%lu)", version,
        version >> 16, version & 0xFFFF);

  return YES;
}

- (void)unload {
  _mpv_client_api_version = NULL;
  _mpv_error_string = NULL;
  _mpv_create = NULL;
  _mpv_initialize = NULL;
  _mpv_destroy = NULL;
  _mpv_set_option_string = NULL;
  _mpv_set_property = NULL;
  _mpv_get_property = NULL;
  _mpv_command = NULL;
  _mpv_render_context_create = NULL;
  _mpv_render_context_free = NULL;
  _mpv_render_context_set_update_callback = NULL;
  _mpv_render_context_render = NULL;

  if (_handle) {
    dlclose(_handle);
    _handle = NULL;
  }
}

@end
