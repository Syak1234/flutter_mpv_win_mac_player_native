#include "mpv_native_texture_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <memory>
#include <optional>

#include "mpv_player.h"

namespace mpv_native_texture {

// Utility: extract int/double/string from EncodableValue map.
static std::optional<flutter::EncodableValue> GetArg(const flutter::EncodableMap& m, const char* key) {
  auto it = m.find(flutter::EncodableValue(key));
  if (it == m.end()) return std::nullopt;
  return it->second;
}

MpvNativeTexturePlugin::MpvNativeTexturePlugin(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar), texture_registrar_(registrar->texture_registrar()) {}

MpvNativeTexturePlugin::~MpvNativeTexturePlugin() = default;

void MpvNativeTexturePlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
  {
    FILE* f = nullptr;
    if (fopen_s(&f, "C:\\Users\\User\\Documents\\a\\mpv_debug.log", "a") == 0 && f) {
      fputs("[Plugin] RegisterWithRegistrar called\n", f);
      fflush(f);
      fclose(f);
    }
  }
  
  auto plugin = std::make_unique<MpvNativeTexturePlugin>(registrar);

  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "mpv_native_texture", &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [plugin_ptr = plugin.get()](const auto& call, auto result) { plugin_ptr->HandleMethodCall(call, std::move(result)); });

  registrar->AddPlugin(std::move(plugin));
  
  {
    FILE* f = nullptr;
    if (fopen_s(&f, "C:\\Users\\User\\Documents\\a\\mpv_debug.log", "a") == 0 && f) {
      fputs("[Plugin] RegisterWithRegistrar completed\n", f);
      fflush(f);
      fclose(f);
    }
  }
}

void MpvNativeTexturePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  {
    FILE* f = nullptr;
    if (fopen_s(&f, "C:\\Users\\User\\Documents\\a\\mpv_debug.log", "a") == 0 && f) {
      fputs("[Plugin] HandleMethodCall: ENTERED\n", f);
      fputs("[Plugin] HandleMethodCall: method=", f);
      fputs(method_call.method_name().c_str(), f);
      fputs("\n", f);
      fflush(f);
      fclose(f);
    }
  }
  const std::string& method = method_call.method_name();

  const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
  flutter::EncodableMap empty;
  const flutter::EncodableMap& a = args ? *args : empty;

  if (method == "create") {
    int width = 1280;
    int height = 720;

    if (auto v = GetArg(a, "width")) {
      if (const auto* p = std::get_if<int32_t>(&*v)) width = *p;
      if (const auto* p64 = std::get_if<int64_t>(&*v)) width = static_cast<int>(*p64);
    }
    if (auto v = GetArg(a, "height")) {
      if (const auto* p = std::get_if<int32_t>(&*v)) height = *p;
      if (const auto* p64 = std::get_if<int64_t>(&*v)) height = static_cast<int>(*p64);
    }

    try {
      OutputDebugStringA("[Plugin] Creating MpvPlayer...\n");
      {
        FILE* f = nullptr;
        if (fopen_s(&f, "C:\\Users\\User\\Documents\\a\\mpv_debug.log", "a") == 0 && f) {
          fputs("[Plugin] About to create MpvPlayer\n", f);
          fflush(f);
          fclose(f);
        }
      }
      auto player = std::make_unique<MpvPlayer>(texture_registrar_, width, height);
      OutputDebugStringA("[Plugin] MpvPlayer constructor returned\n");
      {
        FILE* f = nullptr;
        if (fopen_s(&f, "C:\\Users\\User\\Documents\\a\\mpv_debug.log", "a") == 0 && f) {
          fputs("[Plugin] MpvPlayer constructor returned\n", f);
          fflush(f);
          fclose(f);
        }
      }
      if (!player->ok()) {
        result->Error("init_failed", player->init_error());
        return;
      }

      const int64_t id = player->texture_id();
      players_[id] = std::move(player);
      result->Success(flutter::EncodableValue(id));
      return;
    } catch (const std::exception& e) {
      result->Error("exception", e.what());
      return;
    } catch (...) {
      result->Error("unknown_exception", "Unknown exception during create");
      return;
    }
  }

  // All other methods require a textureId.
  int64_t tid = -1;
  if (auto v = GetArg(a, "textureId")) {
    if (const auto* p = std::get_if<int64_t>(&*v)) tid = *p;
    if (const auto* p32 = std::get_if<int32_t>(&*v)) tid = static_cast<int64_t>(*p32);
  }
  if (tid < 0) {
    result->Error("bad_args", "Missing textureId");
    return;
  }

  auto it = players_.find(tid);
  if (it == players_.end()) {
    result->Error("not_found", "Unknown textureId");
    return;
  }
  MpvPlayer* player = it->second.get();

  if (method == "dispose") {
    players_.erase(it);
    result->Success();
    return;
  }

  if (method == "open") {
    std::string path;
    if (auto v = GetArg(a, "path")) {
      if (const auto* s = std::get_if<std::string>(&*v)) path = *s;
    }
    if (path.empty()) {
      result->Error("bad_args", "Missing path");
      return;
    }
    try {
      std::string err;
      if (!player->Open(path, &err)) {
        result->Error("open_failed", err);
        return;
      }
      result->Success();
      return;
    } catch (const std::exception& e) {
      result->Error("exception", e.what());
      return;
    } catch (...) {
      result->Error("unknown_exception", "Unknown exception during open");
      return;
    }
  }

  if (method == "play") {
    player->Play();
    result->Success();
    return;
  }

  if (method == "pause") {
    player->Pause();
    result->Success();
    return;
  }

  if (method == "seekRelative") {
    double seconds = 0.0;
    if (auto v = GetArg(a, "seconds")) {
      if (const auto* d = std::get_if<double>(&*v)) seconds = *d;
      if (const auto* i = std::get_if<int32_t>(&*v)) seconds = static_cast<double>(*i);
      if (const auto* i64 = std::get_if<int64_t>(&*v)) seconds = static_cast<double>(*i64);
    }
    player->SeekRelative(seconds);
    result->Success();
    return;
  }

  if (method == "setVolume") {
    double volume01 = 1.0;
    if (auto v = GetArg(a, "volume")) {
      if (const auto* d = std::get_if<double>(&*v)) volume01 = *d;
      if (const auto* i = std::get_if<int32_t>(&*v)) volume01 = static_cast<double>(*i);
    }
    player->SetVolume01(volume01);
    result->Success();
    return;
  }

  if (method == "toggleMute") {
    player->ToggleMute();
    result->Success();
    return;
  }

  if (method == "getPosition") {
    double pos = player->GetPosition();
    result->Success(flutter::EncodableValue(pos));
    return;
  }

  if (method == "getDuration") {
    double dur = player->GetDuration();
    result->Success(flutter::EncodableValue(dur));
    return;
  }

  if (method == "seekAbsolute") {
    double seconds = 0.0;
    if (auto v = GetArg(a, "seconds")) {
      if (const auto* d = std::get_if<double>(&*v)) seconds = *d;
      if (const auto* i = std::get_if<int32_t>(&*v)) seconds = static_cast<double>(*i);
      if (const auto* i64 = std::get_if<int64_t>(&*v)) seconds = static_cast<double>(*i64);
    }
    player->SeekAbsolute(seconds);
    result->Success();
    return;
  }

  if (method == "setSpeed") {
    double speed = 1.0;
    if (auto v = GetArg(a, "speed")) {
      if (const auto* d = std::get_if<double>(&*v)) speed = *d;
      if (const auto* i = std::get_if<int32_t>(&*v)) speed = static_cast<double>(*i);
      if (const auto* i64 = std::get_if<int64_t>(&*v)) speed = static_cast<double>(*i64);
    }
    player->SetSpeed(speed);
    result->Success();
    return;
  }

  result->NotImplemented();
}

}  // namespace mpv_native_texture
