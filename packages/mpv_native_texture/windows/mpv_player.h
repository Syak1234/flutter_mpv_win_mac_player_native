#pragma once

#include <flutter/texture_registrar.h>

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "gl_ext.h"
#include "mpv_dll.h"
#include "wgl_offscreen.h"

namespace mpv_native_texture {

class MpvPlayer {
 public:
  MpvPlayer(flutter::TextureRegistrar* registrar, int width, int height);
  ~MpvPlayer();

  bool ok() const { return ok_; }
  const std::string& init_error() const { return init_error_; }
  int64_t texture_id() const { return texture_id_; }

  // Control thread safe (called from method channel thread).
  bool Open(const std::string& path_or_url, std::string* err_out = nullptr);
  void Play();
  void Pause();
  void SeekRelative(double seconds);
  void SeekAbsolute(double seconds);
  double GetPosition();  // Current playback position in seconds
  double GetDuration();  // Total duration in seconds
  void SetVolume01(double volume01);
  void SetSpeed(double speed);  // Set playback speed (0.1 to 4.0)
  void ToggleMute();

 private:
  static void OnMpvRenderUpdate(void* ctx);
  static void* GetProcAddress(void* ctx, const char* name);

  // Render thread entry point.
  void RenderThreadMain();
  void RequestRender();

  // Texture callback (called by Flutter raster thread).
  const FlutterDesktopPixelBuffer* CopyPixelBuffer(size_t width, size_t height);

  // Helpers (render thread only).
  bool EnsureFbo(int w, int h, std::string* err_out);
  void DestroyFbo();

  std::string init_error_;
  bool ok_ = false;

  flutter::TextureRegistrar* registrar_ = nullptr;
  int64_t texture_id_ = -1;
  std::unique_ptr<flutter::TextureVariant> texture_variant_;

  // Shared pixel buffer (double-buffered).
  std::mutex pixel_mutex_;
  FlutterDesktopPixelBuffer pixel_buffer_{};
  std::vector<uint8_t> front_rgba_;
  std::vector<uint8_t> back_rgba_;
  int frame_w_ = 0;
  int frame_h_ = 0;

  // MPV + GL (render thread owned).
  MpvApi api_;
  mpv_handle* mpv_ = nullptr;
  mpv_render_context* mpv_gl_ = nullptr;
  WglOffscreenContext gl_;
  GlExt glx_;
  GLuint fbo_ = 0;
  GLuint tex_ = 0;
  GLuint rbo_depth_ = 0;

  // State.
  std::atomic<bool> running_{true};
  std::atomic<bool> needs_render_{false};
  std::atomic<bool> destroying_{false};
  std::mutex render_mutex_;
  std::condition_variable render_cv_;
  std::thread render_thread_;

  // Pending open request (consumed by render thread to avoid gl/mpv races).
  std::mutex cmd_mutex_;
  std::string pending_open_;
  std::atomic<bool> has_pending_open_{false};
};

}  // namespace mpv_native_texture
