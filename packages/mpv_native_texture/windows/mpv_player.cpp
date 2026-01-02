// Prevent Windows macros from interfering with std::min/std::max
#define NOMINMAX

#include "mpv_player.h"

#include <flutter/texture_registrar.h>

#include <algorithm>
#include <clocale>
#include <cstdio>
#include <sstream>

// Debug output helper - writes to both OutputDebugString and a file
static void DebugLog(const char* msg) {
  OutputDebugStringA(msg);
  // Also write to a file for crash debugging
  FILE* f = nullptr;
  if (fopen_s(&f, "C:\\Users\\User\\Documents\\a\\mpv_debug.log", "a") == 0 && f) {
    fputs(msg, f);
    fflush(f);
    fclose(f);
  }
}

namespace mpv_native_texture {

static int ClampInt(int v, int lo, int hi) { return std::max(lo, std::min(v, hi)); }

#ifndef GL_FRAMEBUFFER
#define GL_FRAMEBUFFER 0x8D40
#endif
#ifndef GL_COLOR_ATTACHMENT0
#define GL_COLOR_ATTACHMENT0 0x8CE0
#endif
#ifndef GL_FRAMEBUFFER_COMPLETE
#define GL_FRAMEBUFFER_COMPLETE 0x8CD5
#endif
#ifndef GL_RGBA8
#define GL_RGBA8 0x8058
#endif

static void FormatMpvError(const MpvApi& api, int code, std::string* out) {
  if (!out) return;
  const char* s = api.mpv_error_string ? api.mpv_error_string(code) : "unknown";
  *out = std::string("libmpv error ") + std::to_string(code) + ": " + s;
}

void MpvPlayer::OnMpvRenderUpdate(void* ctx) {
  auto* self = reinterpret_cast<MpvPlayer*>(ctx);
  self->RequestRender();
}

void* MpvPlayer::GetProcAddress(void* /*ctx*/, const char* name) {
  void* p = reinterpret_cast<void*>(wglGetProcAddress(name));
  if (p) return p;
  static HMODULE ogl = LoadLibraryW(L"opengl32.dll");
  if (!ogl) return nullptr;
  return reinterpret_cast<void*>(::GetProcAddress(ogl, name));
}

MpvPlayer::MpvPlayer(flutter::TextureRegistrar* registrar, int width, int height)
    : registrar_(registrar), frame_w_(std::max(16, width)), frame_h_(std::max(16, height)) {
  DebugLog("[MpvPlayer] Constructor started\n");

  // Allocate texture + pixel buffers.
  front_rgba_.resize(static_cast<size_t>(frame_w_) * static_cast<size_t>(frame_h_) * 4u, 0);
  back_rgba_.resize(front_rgba_.size(), 0);

  {
    std::lock_guard<std::mutex> lock(pixel_mutex_);
    pixel_buffer_.width = frame_w_;
    pixel_buffer_.height = frame_h_;
    pixel_buffer_.buffer = front_rgba_.data();
  }

  DebugLog("[MpvPlayer] Creating PixelBufferTexture\n");

  // Create PixelBufferTexture and wrap it in a TextureVariant for the new Flutter API
  // CopyBufferCallback signature: std::function<const FlutterDesktopPixelBuffer*(size_t, size_t)>
  flutter::PixelBufferTexture::CopyBufferCallback copy_callback =
      [this](size_t w, size_t h) -> const FlutterDesktopPixelBuffer* {
        return this->CopyPixelBuffer(w, h);
      };

  DebugLog("[MpvPlayer] Creating TextureVariant\n");

  // Create texture variant with in-place construction of PixelBufferTexture
  texture_variant_ = std::unique_ptr<flutter::TextureVariant>(
      new flutter::TextureVariant(std::in_place_type<flutter::PixelBufferTexture>, copy_callback));

  DebugLog("[MpvPlayer] Registering texture\n");

  texture_id_ = registrar_->RegisterTexture(texture_variant_.get());

  DebugLog("[MpvPlayer] Texture registered, initializing OpenGL\n");

  // Initialize OpenGL (offscreen) + mpv render API.
  DebugLog("[MpvPlayer] Calling gl_.Initialize()...\n");
  if (!gl_.Initialize()) {
    init_error_ = "Failed to initialize WGL offscreen context";
    DebugLog("[MpvPlayer] ERROR: gl_.Initialize() failed\n");
    return;
  }
  DebugLog("[MpvPlayer] gl_.Initialize() succeeded\n");
  
  DebugLog("[MpvPlayer] Calling gl_.MakeCurrent()...\n");
  if (!gl_.MakeCurrent()) {
    init_error_ = "Failed to make WGL context current";
    DebugLog("[MpvPlayer] ERROR: gl_.MakeCurrent() failed\n");
    return;
  }
  DebugLog("[MpvPlayer] gl_.MakeCurrent() succeeded\n");

  DebugLog("[MpvPlayer] Calling glx_.Load()...\n");
  if (!glx_.Load()) {
    init_error_ = "Failed to load required OpenGL function pointers";
    DebugLog("[MpvPlayer] ERROR: glx_.Load() failed\n");
    gl_.DoneCurrent();
    return;
  }
  DebugLog("[MpvPlayer] glx_.Load() succeeded\n");

  if (!api_.Load()) {
    init_error_ = "Failed to load mpv-2.dll. Put mpv-2.dll next to Runner.exe or in PATH.";
    gl_.DoneCurrent();
    return;
  }

  DebugLog("[MpvPlayer] mpv-2.dll loaded successfully\n");

  // Check API version for compatibility
  if (api_.mpv_client_api_version) {
    unsigned long api_version = api_.mpv_client_api_version();
    char buf[256];
    snprintf(buf, sizeof(buf), "[MpvPlayer] mpv API version: 0x%lx (major=%lu, minor=%lu)\n", 
             api_version, api_version >> 16, api_version & 0xFFFF);
    DebugLog(buf);
  } else {
    DebugLog("[MpvPlayer] WARNING: mpv_client_api_version is null!\n");
  }

  DebugLog("[MpvPlayer] Calling mpv_create()...\n");
  
  if (!api_.mpv_create) {
    init_error_ = "mpv_create function pointer is null";
    gl_.DoneCurrent();
    return;
  }

  // CRITICAL: mpv requires LC_NUMERIC to be set to "C" otherwise it may crash
  // See: https://mpv.io/manual/master/#embedding-into-other-programs-prerequisites
  const char* prev_locale = std::setlocale(LC_NUMERIC, nullptr);
  DebugLog("[MpvPlayer] Previous LC_NUMERIC locale: ");
  DebugLog(prev_locale ? prev_locale : "(null)");
  DebugLog("\n");
  
  std::setlocale(LC_NUMERIC, "C");
  DebugLog("[MpvPlayer] Set LC_NUMERIC to 'C'\n");

  mpv_ = api_.mpv_create();
  DebugLog("[MpvPlayer] mpv_create() returned\n");
  
  if (!mpv_) {
    init_error_ = "mpv_create() failed - returned null";
    DebugLog("[MpvPlayer] ERROR: mpv_create() returned null\n");
    gl_.DoneCurrent();
    return;
  }

  DebugLog("[MpvPlayer] mpv_create() succeeded\n");

  // Required for libmpv rendering path.
  api_.mpv_set_option_string(mpv_, "vo", "libmpv");

  // Performance optimizations - hardware acceleration and smooth playback
  api_.mpv_set_option_string(mpv_, "hwdec", "auto-safe");  // Enable hardware video decoding (GPU)
  api_.mpv_set_option_string(mpv_, "profile", "fast");      // Use fast/efficient settings
  api_.mpv_set_option_string(mpv_, "video-sync", "display-resample");  // Smooth playback synced to display
  api_.mpv_set_option_string(mpv_, "interpolation", "yes"); // Frame interpolation for smoother motion
  api_.mpv_set_option_string(mpv_, "opengl-swapinterval", "1");  // Enable VSync to prevent tearing

  // Sensible defaults.
  api_.mpv_set_option_string(mpv_, "keep-open", "yes");
  api_.mpv_set_option_string(mpv_, "terminal", "no");
  api_.mpv_set_option_string(mpv_, "msg-level", "all=warn");

  int rc = api_.mpv_initialize(mpv_);
  if (rc < 0) {
    FormatMpvError(api_, rc, &init_error_);
    gl_.DoneCurrent();
    return;
  }

  mpv_opengl_init_params gl_init{};
  gl_init.get_proc_address = &MpvPlayer::GetProcAddress;
  gl_init.get_proc_address_ctx = nullptr;

  const char* api_type = MPV_RENDER_API_TYPE_OPENGL;
  mpv_render_param params[] = {
      {MPV_RENDER_PARAM_API_TYPE, const_cast<char*>(api_type)},
      {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl_init},
      {MPV_RENDER_PARAM_INVALID, nullptr},
  };

  rc = api_.mpv_render_context_create(&mpv_gl_, mpv_, params);
  if (rc < 0 || !mpv_gl_) {
    FormatMpvError(api_, rc, &init_error_);
    gl_.DoneCurrent();
    return;
  }

  api_.mpv_render_context_set_update_callback(mpv_gl_, &MpvPlayer::OnMpvRenderUpdate, this);

  if (!EnsureFbo(frame_w_, frame_h_, &init_error_)) {
    gl_.DoneCurrent();
    return;
  }

  gl_.DoneCurrent();

  ok_ = true;
  render_thread_ = std::thread(&MpvPlayer::RenderThreadMain, this);
}

MpvPlayer::~MpvPlayer() {
  DebugLog("[MpvPlayer] Destructor starting\n");
  destroying_.store(true);

  running_.store(false);
  {
    std::lock_guard<std::mutex> lk(render_mutex_);
    needs_render_.store(true);
  }
  render_cv_.notify_all();
  if (render_thread_.joinable()) render_thread_.join();
  DebugLog("[MpvPlayer] Render thread joined\n");

  if (registrar_ && texture_id_ >= 0) {
    registrar_->UnregisterTexture(texture_id_);
  }

  if (gl_.MakeCurrent()) {
    DestroyFbo();
    gl_.DoneCurrent();
  }

  if (mpv_gl_) {
    api_.mpv_render_context_free(mpv_gl_);
    mpv_gl_ = nullptr;
  }

  if (mpv_) {
    api_.mpv_destroy(mpv_);
    mpv_ = nullptr;
  }

  api_.Unload();
  gl_.Shutdown();
}

const FlutterDesktopPixelBuffer* MpvPlayer::CopyPixelBuffer(size_t /*width*/, size_t /*height*/) {
  if (destroying_.load()) {
    DebugLog("[MpvPlayer] CopyPixelBuffer called during destruction, returning nullptr\n");
    return nullptr;
  }
  std::lock_guard<std::mutex> lock(pixel_mutex_);
  return &pixel_buffer_;
}

void MpvPlayer::RequestRender() {
  {
    std::lock_guard<std::mutex> lk(render_mutex_);
    needs_render_.store(true);
  }
  render_cv_.notify_one();
}

bool MpvPlayer::EnsureFbo(int w, int h, std::string* err_out) {
  w = ClampInt(w, 16, 4096);
  h = ClampInt(h, 16, 4096);

  if (fbo_ && tex_ && frame_w_ == w && frame_h_ == h) return true;

  DestroyFbo();

  frame_w_ = w;
  frame_h_ = h;

  glx_.glGenTextures(1, &tex_);
  glx_.glBindTexture(GL_TEXTURE_2D, tex_);
  glx_.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glx_.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glx_.glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, frame_w_, frame_h_, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);

  glx_.glGenFramebuffers(1, &fbo_);
  glx_.glBindFramebuffer(GL_FRAMEBUFFER, fbo_);
  glx_.glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex_, 0);

  const GLenum status = glx_.glCheckFramebufferStatus(GL_FRAMEBUFFER);
  if (status != GL_FRAMEBUFFER_COMPLETE) {
    if (err_out) {
      std::ostringstream oss;
      oss << "OpenGL framebuffer incomplete: 0x" << std::hex << status;
      *err_out = oss.str();
    }
    DestroyFbo();
    return false;
  }

  // Resize buffers.
  front_rgba_.assign(static_cast<size_t>(frame_w_) * static_cast<size_t>(frame_h_) * 4u, 0);
  back_rgba_.assign(front_rgba_.size(), 0);

  {
    std::lock_guard<std::mutex> lock(pixel_mutex_);
    pixel_buffer_.width = frame_w_;
    pixel_buffer_.height = frame_h_;
    pixel_buffer_.buffer = front_rgba_.data();
  }

  return true;
}

void MpvPlayer::DestroyFbo() {
  if (fbo_) {
    glx_.glDeleteFramebuffers(1, &fbo_);
    fbo_ = 0;
  }
  if (tex_) {
    glx_.glDeleteTextures(1, &tex_);
    tex_ = 0;
  }
}

bool MpvPlayer::Open(const std::string& path_or_url, std::string* err_out) {
  DebugLog("[MpvPlayer::Open] Called\n");

  if (!ok_ || !mpv_) {
    if (err_out) *err_out = init_error_.empty() ? "Player not initialized" : init_error_;
    return false;
  }

  DebugLog("[MpvPlayer::Open] Sending loadfile command\n");

  const char* cmd[] = {"loadfile", path_or_url.c_str(), nullptr};
  const int rc = api_.mpv_command(mpv_, cmd);
  if (rc < 0) {
    FormatMpvError(api_, rc, err_out);
    return false;
  }

  RequestRender();
  return true;
}

void MpvPlayer::Play() {
  if (!ok_ || !mpv_) return;
  int flag = 0;
  api_.mpv_set_property(mpv_, "pause", MPV_FORMAT_FLAG, &flag);
  RequestRender();
}

void MpvPlayer::Pause() {
  if (!ok_ || !mpv_) return;
  int flag = 1;
  api_.mpv_set_property(mpv_, "pause", MPV_FORMAT_FLAG, &flag);
  RequestRender();
}

void MpvPlayer::SeekRelative(double seconds) {
  if (!ok_ || !mpv_) return;
  char buf[64] = {0};
  std::snprintf(buf, sizeof(buf), "%0.3f", seconds);
  const char* cmd[] = {"seek", buf, "relative", nullptr};
  api_.mpv_command(mpv_, cmd);
  RequestRender();
}

void MpvPlayer::SetVolume01(double volume01) {
  if (!ok_ || !mpv_) return;
  volume01 = std::max(0.0, std::min(1.0, volume01));
  double vol = volume01 * 100.0;
  api_.mpv_set_property(mpv_, "volume", MPV_FORMAT_DOUBLE, &vol);
}

void MpvPlayer::ToggleMute() {
  if (!ok_ || !mpv_) return;
  int mute = 0;
  if (api_.mpv_get_property(mpv_, "mute", MPV_FORMAT_FLAG, &mute) < 0) {
    mute = 0;
  }
  mute = !mute;
  api_.mpv_set_property(mpv_, "mute", MPV_FORMAT_FLAG, &mute);
}

double MpvPlayer::GetPosition() {
  if (!ok_ || !mpv_) return 0.0;
  double pos = 0.0;
  if (api_.mpv_get_property(mpv_, "time-pos", MPV_FORMAT_DOUBLE, &pos) < 0) {
    return 0.0;
  }
  return pos;
}

double MpvPlayer::GetDuration() {
  if (!ok_ || !mpv_) return 0.0;
  double dur = 0.0;
  if (api_.mpv_get_property(mpv_, "duration", MPV_FORMAT_DOUBLE, &dur) < 0) {
    return 0.0;
  }
  return dur;
}

void MpvPlayer::SeekAbsolute(double seconds) {
  if (!ok_ || !mpv_) return;
  api_.mpv_set_property(mpv_, "time-pos", MPV_FORMAT_DOUBLE, &seconds);
  RequestRender();
}

void MpvPlayer::SetSpeed(double speed) {
  if (!ok_ || !mpv_) return;
  speed = std::max(0.1, std::min(4.0, speed));
  api_.mpv_set_property(mpv_, "speed", MPV_FORMAT_DOUBLE, &speed);
}

void MpvPlayer::RenderThreadMain() {
  DebugLog("[MpvPlayer] Render thread started\n");

  try {
    if (!ok_ || !mpv_gl_) {
      DebugLog("[MpvPlayer] Render thread exiting: not ok or no mpv_gl\n");
      return;
    }

    DebugLog("[MpvPlayer] Render thread entering loop\n");

    while (running_.load() && !destroying_.load()) {
      std::unique_lock<std::mutex> lk(render_mutex_);
      render_cv_.wait(lk, [&] { return !running_.load() || needs_render_.load(); });
      if (!running_.load() || destroying_.load()) break;
      needs_render_.store(false);
      lk.unlock();

      DebugLog("[MpvPlayer] Render thread processing frame\n");

      if (!gl_.MakeCurrent()) {
        DebugLog("[MpvPlayer] Render thread: MakeCurrent failed\n");
        continue;
      }

      // Safety checks before rendering
      if (fbo_ == 0) {
        DebugLog("[MpvPlayer] Render thread: FBO not initialized\n");
        gl_.DoneCurrent();
        continue;
      }

      if (!mpv_gl_ || !api_.mpv_render_context_render) {
        DebugLog("[MpvPlayer] Render thread: mpv render context not available\n");
        gl_.DoneCurrent();
        continue;
      }

      DebugLog("[MpvPlayer] Render thread: Setting up FBO struct\n");

      // Render into the offscreen FBO.
      mpv_opengl_fbo fbo{};
      fbo.fbo = static_cast<int>(fbo_);
      fbo.w = frame_w_;
      fbo.h = frame_h_;
      fbo.internal_format = GL_RGBA8;

      int flip_y = 0;  // Don't flip - glReadPixels will handle the orientation
      mpv_render_param rparams[] = {
          {MPV_RENDER_PARAM_OPENGL_FBO, &fbo},
          {MPV_RENDER_PARAM_FLIP_Y, &flip_y},
          {MPV_RENDER_PARAM_INVALID, nullptr},
      };

      DebugLog("[MpvPlayer] Render thread: Calling glViewport\n");
      glViewport(0, 0, frame_w_, frame_h_);
      
      // Wrap render call in try-catch
      DebugLog("[MpvPlayer] Render thread: Calling mpv_render_context_render\n");
      try {
        api_.mpv_render_context_render(mpv_gl_, rparams);
      } catch (...) {
        DebugLog("[MpvPlayer] Render thread: Exception during mpv_render_context_render\n");
        gl_.DoneCurrent();
        continue;
      }
      DebugLog("[MpvPlayer] Render thread: mpv_render_context_render completed\n");

      // Ensure our FBO is bound for reading
      glx_.glBindFramebuffer(GL_FRAMEBUFFER, fbo_);
      
      // Read back RGBA.
      DebugLog("[MpvPlayer] Render thread: Calling glReadPixels\n");
      glReadPixels(0, 0, frame_w_, frame_h_, GL_RGBA, GL_UNSIGNED_BYTE, back_rgba_.data());
      DebugLog("[MpvPlayer] Render thread: glReadPixels completed\n");

      gl_.DoneCurrent();

      // Swap buffers.
      {
        std::lock_guard<std::mutex> lock(pixel_mutex_);
        front_rgba_.swap(back_rgba_);
        pixel_buffer_.buffer = front_rgba_.data();
        pixel_buffer_.width = frame_w_;
        pixel_buffer_.height = frame_h_;
      }

      // Notify Flutter a new frame is available.
      registrar_->MarkTextureFrameAvailable(texture_id_);
    }
  } catch (const std::exception& e) {
    char buf[512];
    snprintf(buf, sizeof(buf), "[MpvPlayer] Render thread exception: %s\n", e.what());
    DebugLog(buf);
  } catch (...) {
    DebugLog("[MpvPlayer] Render thread unknown exception\n");
  }

  DebugLog("[MpvPlayer] Render thread exiting\n");
}

}  // namespace mpv_native_texture

