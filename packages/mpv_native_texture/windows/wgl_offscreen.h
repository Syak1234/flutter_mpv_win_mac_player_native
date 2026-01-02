#pragma once

#include <Windows.h>

namespace mpv_native_texture {

class WglOffscreenContext {
 public:
  WglOffscreenContext();
  ~WglOffscreenContext();

  bool Initialize();
  void Shutdown();

  bool MakeCurrent();
  void DoneCurrent();

  HGLRC glrc() const { return glrc_; }

 private:
  HWND wnd_ = nullptr;
  HDC dc_ = nullptr;
  HGLRC glrc_ = nullptr;
};

}  // namespace mpv_native_texture
