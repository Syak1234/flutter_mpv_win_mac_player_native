#include "wgl_offscreen.h"

#include <string>

namespace mpv_native_texture {

static const wchar_t kWndClassName[] = L"MpvNativeTextureDummy";

static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
  return DefWindowProc(hwnd, msg, wParam, lParam);
}

WglOffscreenContext::WglOffscreenContext() = default;
WglOffscreenContext::~WglOffscreenContext() { Shutdown(); }

bool WglOffscreenContext::Initialize() {
  if (glrc_) return true;

  WNDCLASSW wc = {};
  wc.lpfnWndProc = WndProc;
  wc.hInstance = GetModuleHandleW(nullptr);
  wc.lpszClassName = kWndClassName;
  RegisterClassW(&wc);

  wnd_ = CreateWindowExW(0, kWndClassName, L"", WS_OVERLAPPEDWINDOW,
                         0, 0, 16, 16, nullptr, nullptr, wc.hInstance, nullptr);
  if (!wnd_) return false;

  dc_ = GetDC(wnd_);
  if (!dc_) return false;

  PIXELFORMATDESCRIPTOR pfd = {};
  pfd.nSize = sizeof(PIXELFORMATDESCRIPTOR);
  pfd.nVersion = 1;
  pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
  pfd.iPixelType = PFD_TYPE_RGBA;
  pfd.cColorBits = 24;
  pfd.cAlphaBits = 8;
  pfd.cDepthBits = 24;
  pfd.iLayerType = PFD_MAIN_PLANE;

  const int pf = ChoosePixelFormat(dc_, &pfd);
  if (pf == 0) return false;
  if (!SetPixelFormat(dc_, pf, &pfd)) return false;

  glrc_ = wglCreateContext(dc_);
  if (!glrc_) return false;

  return true;
}

bool WglOffscreenContext::MakeCurrent() {
  if (!dc_ || !glrc_) return false;
  return wglMakeCurrent(dc_, glrc_) == TRUE;
}

void WglOffscreenContext::DoneCurrent() {
  wglMakeCurrent(nullptr, nullptr);
}

void WglOffscreenContext::Shutdown() {
  if (glrc_) {
    wglMakeCurrent(nullptr, nullptr);
    wglDeleteContext(glrc_);
    glrc_ = nullptr;
  }
  if (dc_ && wnd_) {
    ReleaseDC(wnd_, dc_);
    dc_ = nullptr;
  }
  if (wnd_) {
    DestroyWindow(wnd_);
    wnd_ = nullptr;
  }
}

}  // namespace mpv_native_texture
