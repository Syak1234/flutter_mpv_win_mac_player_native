#include "mpv_dll.h"

#include <Shlwapi.h>

#pragma comment(lib, "Shlwapi.lib")

namespace mpv_native_texture {

FARPROC MpvApi::Get(const char* name) {
  if (!dll) return nullptr;
  return GetProcAddress(dll, name);
}

std::wstring MpvApi::ResolveDllPath() {
  // Prefer mpv-2.dll next to the executable.
  wchar_t exe_path[MAX_PATH] = {0};
  GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
  PathRemoveFileSpecW(exe_path);
  std::wstring candidate = std::wstring(exe_path) + L"\\mpv-2.dll";
  if (PathFileExistsW(candidate.c_str())) {
    return candidate;
  }

  // Fallback: rely on Windows DLL search order (PATH, current dir, etc.).
  return L"mpv-2.dll";
}

bool MpvApi::Load() {
  if (dll) return true;

  const std::wstring path = ResolveDllPath();
  dll = LoadLibraryW(path.c_str());
  if (!dll) {
    return false;
  }

  // Resolve required symbols.
  mpv_client_api_version = reinterpret_cast<decltype(mpv_client_api_version)>(Get("mpv_client_api_version"));
  mpv_error_string = reinterpret_cast<decltype(mpv_error_string)>(Get("mpv_error_string"));
  mpv_create = reinterpret_cast<decltype(mpv_create)>(Get("mpv_create"));
  mpv_initialize = reinterpret_cast<decltype(mpv_initialize)>(Get("mpv_initialize"));
  mpv_destroy = reinterpret_cast<decltype(mpv_destroy)>(Get("mpv_destroy"));
  mpv_set_option_string = reinterpret_cast<decltype(mpv_set_option_string)>(Get("mpv_set_option_string"));
  mpv_set_property = reinterpret_cast<decltype(mpv_set_property)>(Get("mpv_set_property"));
  mpv_get_property = reinterpret_cast<decltype(mpv_get_property)>(Get("mpv_get_property"));
  mpv_command = reinterpret_cast<decltype(mpv_command)>(Get("mpv_command"));
  mpv_render_context_create = reinterpret_cast<decltype(mpv_render_context_create)>(Get("mpv_render_context_create"));
  mpv_render_context_free = reinterpret_cast<decltype(mpv_render_context_free)>(Get("mpv_render_context_free"));
  mpv_render_context_set_update_callback = reinterpret_cast<decltype(mpv_render_context_set_update_callback)>(Get("mpv_render_context_set_update_callback"));
  mpv_render_context_render = reinterpret_cast<decltype(mpv_render_context_render)>(Get("mpv_render_context_render"));

  const bool ok = mpv_client_api_version && mpv_error_string && mpv_create && mpv_initialize && mpv_destroy &&
                  mpv_set_option_string && mpv_set_property && mpv_get_property && mpv_command &&
                  mpv_render_context_create && mpv_render_context_free && mpv_render_context_set_update_callback &&
                  mpv_render_context_render;

  if (!ok) {
    Unload();
    return false;
  }

  return true;
}

void MpvApi::Unload() {
  mpv_client_api_version = nullptr;
  mpv_error_string = nullptr;
  mpv_create = nullptr;
  mpv_initialize = nullptr;
  mpv_destroy = nullptr;
  mpv_set_option_string = nullptr;
  mpv_set_property = nullptr;
  mpv_get_property = nullptr;
  mpv_command = nullptr;
  mpv_render_context_create = nullptr;
  mpv_render_context_free = nullptr;
  mpv_render_context_set_update_callback = nullptr;
  mpv_render_context_render = nullptr;

  if (dll) {
    FreeLibrary(dll);
    dll = nullptr;
  }
}

}  // namespace mpv_native_texture
