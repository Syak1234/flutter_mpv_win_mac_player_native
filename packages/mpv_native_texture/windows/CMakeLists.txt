cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "mpv_native_texture")

# This value is used when compiling the plugin.
set(PLUGIN_NAME "mpv_native_texture_plugin")

add_library(${PLUGIN_NAME} SHARED
  "mpv_native_texture_plugin.cpp"
  "mpv_native_texture_plugin.h"
  "mpv_native_texture_plugin_c_api.cpp"
  "mpv_player.cpp"
  "mpv_player.h"
  "mpv_dll.cpp"
  "mpv_dll.h"
  "gl_ext.cpp"
  "gl_ext.h"
  "wgl_offscreen.cpp"
  "wgl_offscreen.h"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_STANDARD 17
  CXX_STANDARD_REQUIRED YES
  POSITION_INDEPENDENT_CODE ON)

# Headers
target_include_directories(${PLUGIN_NAME} PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

# Link Flutter + Windows system libs.
target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  flutter_wrapper_plugin
  opengl32
  Shlwapi
)

# Export the plugin registration function.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  DEFINE_SYMBOL MPV_NATIVE_TEXTURE_PLUGIN_EXPORTS)

# Ensure headers are copied for consumers.
set(mpv_native_texture_bundled_libraries
  ""
  PARENT_SCOPE
)

# Copy mpv-2.dll into runner output if present in the source tree.
set(MPV_DLL "${CMAKE_CURRENT_SOURCE_DIR}/third_party/mpv/bin/mpv-2.dll")
if(EXISTS "${MPV_DLL}")
  add_custom_command(TARGET ${PLUGIN_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      "${MPV_DLL}"
      "$<TARGET_FILE_DIR:${PLUGIN_NAME}>/mpv-2.dll")
endif()
