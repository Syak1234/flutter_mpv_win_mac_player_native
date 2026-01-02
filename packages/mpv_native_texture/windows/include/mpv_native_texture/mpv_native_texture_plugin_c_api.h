#ifndef FLUTTER_PLUGIN_MPV_NATIVE_TEXTURE_PLUGIN_C_API_H_
#define FLUTTER_PLUGIN_MPV_NATIVE_TEXTURE_PLUGIN_C_API_H_

#include <flutter/plugin_registrar_windows.h>

#ifdef __cplusplus
extern "C" {
#endif

__declspec(dllexport) void MpvNativeTexturePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // FLUTTER_PLUGIN_MPV_NATIVE_TEXTURE_PLUGIN_C_API_H_
