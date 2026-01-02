#ifndef FLUTTER_PLUGIN_MPV_NATIVE_TEXTURE_PLUGIN_H_
#define FLUTTER_PLUGIN_MPV_NATIVE_TEXTURE_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/texture_registrar.h>

#include <map>
#include <memory>

namespace mpv_native_texture {

class MpvPlayer;

class MpvNativeTexturePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  explicit MpvNativeTexturePlugin(flutter::PluginRegistrarWindows *registrar);
  ~MpvNativeTexturePlugin() override;

  MpvNativeTexturePlugin(const MpvNativeTexturePlugin &) = delete;
  MpvNativeTexturePlugin &operator=(const MpvNativeTexturePlugin &) = delete;

 private:
  void HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue> &method_call,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::PluginRegistrarWindows *registrar_ = nullptr;
  flutter::TextureRegistrar *texture_registrar_ = nullptr;

  std::map<int64_t, std::unique_ptr<MpvPlayer>> players_;
};

}  // namespace mpv_native_texture

#endif  // FLUTTER_PLUGIN_MPV_NATIVE_TEXTURE_PLUGIN_H_
