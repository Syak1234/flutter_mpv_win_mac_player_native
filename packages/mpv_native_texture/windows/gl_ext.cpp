#include "gl_ext.h"

#include <Windows.h>

namespace mpv_native_texture {

static void* GetGLProc(const char* name) {
  void* p = reinterpret_cast<void*>(wglGetProcAddress(name));
  if (p) return p;
  static HMODULE ogl = LoadLibraryW(L"opengl32.dll");
  if (!ogl) return nullptr;
  return reinterpret_cast<void*>(GetProcAddress(ogl, name));
}

bool GlExt::Load() {
  glGenFramebuffers = reinterpret_cast<PFNGLGENFRAMEBUFFERSPROC>(GetGLProc("glGenFramebuffers"));
  glBindFramebuffer = reinterpret_cast<PFNGLBINDFRAMEBUFFERPROC>(GetGLProc("glBindFramebuffer"));
  glDeleteFramebuffers = reinterpret_cast<PFNGLDELETEFRAMEBUFFERSPROC>(GetGLProc("glDeleteFramebuffers"));
  glCheckFramebufferStatus = reinterpret_cast<PFNGLCHECKFRAMEBUFFERSTATUSPROC>(GetGLProc("glCheckFramebufferStatus"));
  glFramebufferTexture2D = reinterpret_cast<PFNGLFRAMEBUFFERTEXTURE2DPROC>(GetGLProc("glFramebufferTexture2D"));

  glGenTextures = reinterpret_cast<PFNGLGENTEXTURESPROC>(GetGLProc("glGenTextures"));
  glBindTexture = reinterpret_cast<PFNGLBINDTEXTUREPROC>(GetGLProc("glBindTexture"));
  glDeleteTextures = reinterpret_cast<PFNGLDELETETEXTURESPROC>(GetGLProc("glDeleteTextures"));
  glTexImage2D = reinterpret_cast<PFNGLTEXIMAGE2DPROC>(GetGLProc("glTexImage2D"));
  glTexParameteri = reinterpret_cast<PFNGLTEXPARAMETERIPROC>(GetGLProc("glTexParameteri"));

  glGenRenderbuffers = reinterpret_cast<PFNGLGENRENDERBUFFERSPROC>(GetGLProc("glGenRenderbuffers"));
  glBindRenderbuffer = reinterpret_cast<PFNGLBINDRENDERBUFFERPROC>(GetGLProc("glBindRenderbuffer"));
  glRenderbufferStorage = reinterpret_cast<PFNGLRENDERBUFFERSTORAGEPROC>(GetGLProc("glRenderbufferStorage"));
  glFramebufferRenderbuffer = reinterpret_cast<PFNGLFRAMEBUFFERRENDERBUFFERPROC>(GetGLProc("glFramebufferRenderbuffer"));
  glDeleteRenderbuffers = reinterpret_cast<PFNGLDELETERENDERBUFFERSPROC>(GetGLProc("glDeleteRenderbuffers"));

  return glGenFramebuffers && glBindFramebuffer && glDeleteFramebuffers && glCheckFramebufferStatus && glFramebufferTexture2D &&
         glGenTextures && glBindTexture && glDeleteTextures && glTexImage2D && glTexParameteri &&
         glGenRenderbuffers && glBindRenderbuffer && glRenderbufferStorage && glFramebufferRenderbuffer && glDeleteRenderbuffers;
}

}  // namespace mpv_native_texture
