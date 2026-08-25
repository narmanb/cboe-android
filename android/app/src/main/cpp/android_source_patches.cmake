# Android-only source compatibility patches applied before the main CMake
# project configures its targets. Keep these narrowly tied to verified Android
# failures so the upstream desktop sources remain otherwise untouched.

if(DEFINED CBOE_ANDROID_SOURCE_PATCHES_APPLIED)
    return()
endif()
set(CBOE_ANDROID_SOURCE_PATCHES_APPLIED TRUE CACHE INTERNAL "")

get_filename_component(CBOE_ANDROID_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)

# SFML 2.6.2's sf::Texture copy constructor performs a GPU readback through
# Texture::copyToImage(). On Android/OpenGL ES that path has produced a null
# function-pointer crash. draw_startup_anim only needs to draw the existing
# startanim texture, so keep a reference instead of copying the GPU texture.
set(CBOE_GRAPHICS_CPP "${CBOE_ANDROID_ROOT}/src/game/boe.graphics.cpp")
file(READ "${CBOE_GRAPHICS_CPP}" CBOE_GRAPHICS_SOURCE)
set(CBOE_STARTANIM_COPY_OLD "auto scroll_sprite = *ResMgr::graphics.get(\"startanim\",true);")
set(CBOE_STARTANIM_COPY_NEW "sf::Texture& scroll_sprite = *ResMgr::graphics.get(\"startanim\",true);")
string(FIND "${CBOE_GRAPHICS_SOURCE}" "${CBOE_STARTANIM_COPY_OLD}" CBOE_STARTANIM_COPY_POS)
if(CBOE_STARTANIM_COPY_POS EQUAL -1)
    message(FATAL_ERROR "Expected OpenBoE draw_startup_anim texture copy was not found")
endif()
string(REPLACE "${CBOE_STARTANIM_COPY_OLD}" "${CBOE_STARTANIM_COPY_NEW}" CBOE_GRAPHICS_SOURCE "${CBOE_GRAPHICS_SOURCE}")
file(WRITE "${CBOE_GRAPHICS_CPP}" "${CBOE_GRAPHICS_SOURCE}")
message(STATUS "Applied Android draw_startup_anim texture-reference patch")
