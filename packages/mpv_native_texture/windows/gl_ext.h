#pragma once

#include <Windows.h>
#include <gl/GL.h>

namespace mpv_native_texture {

#ifndef APIENTRY
#define APIENTRY __stdcall
#endif

typedef void (APIENTRY *PFNGLGENFRAMEBUFFERSPROC)(GLsizei n, GLuint* ids);
typedef void (APIENTRY *PFNGLBINDFRAMEBUFFERPROC)(GLenum target, GLuint framebuffer);
typedef void (APIENTRY *PFNGLDELETEFRAMEBUFFERSPROC)(GLsizei n, const GLuint* framebuffers);
typedef GLenum(APIENTRY *PFNGLCHECKFRAMEBUFFERSTATUSPROC)(GLenum target);
typedef void (APIENTRY *PFNGLFRAMEBUFFERTEXTURE2DPROC)(GLenum target, GLenum attachment, GLenum textarget, GLuint texture, GLint level);

typedef void (APIENTRY *PFNGLGENTEXTURESPROC)(GLsizei n, GLuint* textures);
typedef void (APIENTRY *PFNGLBINDTEXTUREPROC)(GLenum target, GLuint texture);
typedef void (APIENTRY *PFNGLDELETETEXTURESPROC)(GLsizei n, const GLuint* textures);
typedef void (APIENTRY *PFNGLTEXIMAGE2DPROC)(GLenum target, GLint level, GLint internalformat, GLsizei width, GLsizei height, GLint border,
                                             GLenum format, GLenum type, const void* pixels);
typedef void (APIENTRY *PFNGLTEXPARAMETERIPROC)(GLenum target, GLenum pname, GLint param);

typedef void (APIENTRY *PFNGLGENRENDERBUFFERSPROC)(GLsizei n, GLuint* renderbuffers);
typedef void (APIENTRY *PFNGLBINDRENDERBUFFERPROC)(GLenum target, GLuint renderbuffer);
typedef void (APIENTRY *PFNGLRENDERBUFFERSTORAGEPROC)(GLenum target, GLenum internalformat, GLsizei width, GLsizei height);
typedef void (APIENTRY *PFNGLFRAMEBUFFERRENDERBUFFERPROC)(GLenum target, GLenum attachment, GLenum renderbuffertarget, GLuint renderbuffer);
typedef void (APIENTRY *PFNGLDELETERENDERBUFFERSPROC)(GLsizei n, const GLuint* renderbuffers);

struct GlExt {
  PFNGLGENFRAMEBUFFERSPROC glGenFramebuffers = nullptr;
  PFNGLBINDFRAMEBUFFERPROC glBindFramebuffer = nullptr;
  PFNGLDELETEFRAMEBUFFERSPROC glDeleteFramebuffers = nullptr;
  PFNGLCHECKFRAMEBUFFERSTATUSPROC glCheckFramebufferStatus = nullptr;
  PFNGLFRAMEBUFFERTEXTURE2DPROC glFramebufferTexture2D = nullptr;

  PFNGLGENTEXTURESPROC glGenTextures = nullptr;
  PFNGLBINDTEXTUREPROC glBindTexture = nullptr;
  PFNGLDELETETEXTURESPROC glDeleteTextures = nullptr;
  PFNGLTEXIMAGE2DPROC glTexImage2D = nullptr;
  PFNGLTEXPARAMETERIPROC glTexParameteri = nullptr;

  PFNGLGENRENDERBUFFERSPROC glGenRenderbuffers = nullptr;
  PFNGLBINDRENDERBUFFERPROC glBindRenderbuffer = nullptr;
  PFNGLRENDERBUFFERSTORAGEPROC glRenderbufferStorage = nullptr;
  PFNGLFRAMEBUFFERRENDERBUFFERPROC glFramebufferRenderbuffer = nullptr;
  PFNGLDELETERENDERBUFFERSPROC glDeleteRenderbuffers = nullptr;

  bool Load();
};

}  // namespace mpv_native_texture
