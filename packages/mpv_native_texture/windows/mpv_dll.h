#pragma once

#include <Windows.h>
#include <string>

// mpv headers (ISC licensed client/render API headers)
#include "third_party/mpv/include/mpv/client.h"
#include "third_party/mpv/include/mpv/render.h"
#include "third_party/mpv/include/mpv/render_gl.h"

namespace mpv_native_texture {

struct MpvApi {
  HMODULE dll = nullptr;

  // --- client.h
  unsigned long (*mpv_client_api_version)(void) = nullptr;
  const char* (*mpv_error_string)(int) = nullptr;
  mpv_handle* (*mpv_create)(void) = nullptr;
  int (*mpv_initialize)(mpv_handle*) = nullptr;
  void (*mpv_destroy)(mpv_handle*) = nullptr;
  int (*mpv_set_option_string)(mpv_handle*, const char*, const char*) = nullptr;
  int (*mpv_set_property)(mpv_handle*, const char*, mpv_format, void*) = nullptr;
  int (*mpv_get_property)(mpv_handle*, const char*, mpv_format, void*) = nullptr;
  int (*mpv_command)(mpv_handle*, const char* const*) = nullptr;

  // --- render.h
  int (*mpv_render_context_create)(mpv_render_context**, mpv_handle*, mpv_render_param*) = nullptr;
  void (*mpv_render_context_free)(mpv_render_context*) = nullptr;
  void (*mpv_render_context_set_update_callback)(mpv_render_context*, void (*)(void*), void*) = nullptr;
  int (*mpv_render_context_render)(mpv_render_context*, mpv_render_param*) = nullptr;

  bool Load();
  void Unload();

 private:
  FARPROC Get(const char* name);
  static std::wstring ResolveDllPath();
};

}  // namespace mpv_native_texture
