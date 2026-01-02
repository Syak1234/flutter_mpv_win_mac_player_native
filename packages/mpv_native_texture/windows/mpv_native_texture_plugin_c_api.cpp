#include "include/mpv_native_texture/mpv_native_texture_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "mpv_native_texture_plugin.h"

extern "C" __declspec(dllexport) void MpvNativeTexturePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  // NOTE: The plugin registrar must remain valid for the lifetime of the plugin.
  // Flutter's AddPlugin takes ownership and manages the plugin lifecycle.
  mpv_native_texture::MpvNativeTexturePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
