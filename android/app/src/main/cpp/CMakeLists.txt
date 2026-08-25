cmake_minimum_required(VERSION 3.22.1)
project(cboe_android LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(NOT ANDROID)
    message(FATAL_ERROR "This CMake project is for the Android port only")
endif()

get_filename_component(CBOE_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)

include(FetchContent)

# Keep the game on the SFML 2 API it was written for. SFML 2.6.2 includes
# the NativeActivity bootstrap and Android backends that let the existing
# portable main() entry point run without rewriting the game loop.
set(SFML_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(SFML_BUILD_DOC OFF CACHE BOOL "" FORCE)
set(SFML_BUILD_TEST_SUITE OFF CACHE BOOL "" FORCE)
set(SFML_BUILD_GRAPHICS ON CACHE BOOL "" FORCE)
set(SFML_BUILD_AUDIO ON CACHE BOOL "" FORCE)
set(SFML_BUILD_NETWORK ON CACHE BOOL "" FORCE)
FetchContent_Declare(
    SFML
    URL https://github.com/SFML/SFML/archive/refs/tags/2.6.2.tar.gz
)
# Populate SFML first so we can apply a small Android-only source fix before
# its targets are configured. SFML 2.6.2 constructs Font::Page through a
# temporary std::pair; because sf::Texture is copy-only in SFML 2, that copies
# the glyph texture and calls Texture::copyToImage(). The OpenGL ES readback
# path crashes on Android during the first TGUI glyph. Construct the page in
# place instead so no texture copy/readback occurs.
FetchContent_GetProperties(SFML)
if(NOT sfml_POPULATED)
    FetchContent_Populate(SFML)

    set(SFML_FONT_CPP "${sfml_SOURCE_DIR}/src/SFML/Graphics/Font.cpp")
    file(READ "${SFML_FONT_CPP}" SFML_FONT_SOURCE)
    set(SFML_FONT_OLD "pageIterator = m_pages.insert(std::make_pair(characterSize, Page(m_isSmooth))).first;")
    set(SFML_FONT_NEW "pageIterator = m_pages.emplace(std::piecewise_construct, std::forward_as_tuple(characterSize), std::forward_as_tuple(m_isSmooth)).first;")
    string(FIND "${SFML_FONT_SOURCE}" "${SFML_FONT_OLD}" SFML_FONT_PATCH_POS)
    if(SFML_FONT_PATCH_POS EQUAL -1)
        message(FATAL_ERROR "Expected SFML 2.6.2 Font::loadPage insertion was not found")
    endif()
    string(REPLACE "${SFML_FONT_OLD}" "${SFML_FONT_NEW}" SFML_FONT_SOURCE "${SFML_FONT_SOURCE}")
    file(WRITE "${SFML_FONT_CPP}" "${SFML_FONT_SOURCE}")

    # SFML 2.6.2 GLES Texture::copyToImage uses framebuffer extension entry points
    # before ensuring SFML has initialized those pointers. Font atlas growth reaches
    # this readback path, so initialize extensions before the first FBO call.
    set(SFML_TEXTURE_CPP "${sfml_SOURCE_DIR}/src/SFML/Graphics/Texture.cpp")
    file(READ "${SFML_TEXTURE_CPP}" SFML_TEXTURE_SOURCE)
    set(SFML_GLES_READBACK_OLD [=[#ifdef SFML_OPENGL_ES

    // OpenGL ES doesn't have the glGetTexImage function]=])
    set(SFML_GLES_READBACK_NEW [=[#ifdef SFML_OPENGL_ES

    priv::ensureExtensionsInit();

    // OpenGL ES doesn't have the glGetTexImage function]=])
    string(FIND "${SFML_TEXTURE_SOURCE}" "${SFML_GLES_READBACK_OLD}" SFML_GLES_READBACK_POS)
    if(SFML_GLES_READBACK_POS EQUAL -1)
        message(FATAL_ERROR "Expected SFML 2.6.2 GLES Texture::copyToImage block was not found")
    endif()
    string(REPLACE "${SFML_GLES_READBACK_OLD}" "${SFML_GLES_READBACK_NEW}" SFML_TEXTURE_SOURCE "${SFML_TEXTURE_SOURCE}")
    file(WRITE "${SFML_TEXTURE_CPP}" "${SFML_TEXTURE_SOURCE}")

    # Android touchscreen input should behave like the desktop left mouse.
    # Patching SFML here makes existing OpenBoE controls work without per-screen touch code.
    set(SFML_ANDROID_WINDOW_CPP "${sfml_SOURCE_DIR}/src/SFML/Window/Android/WindowImplAndroid.cpp")
    file(READ "${SFML_ANDROID_WINDOW_CPP}" SFML_ANDROID_WINDOW_SOURCE)

    set(SFML_TOUCH_DOWN_OLD [=[            event.type = Event::TouchBegan;
            event.touch.finger = static_cast<unsigned int>(id);
            event.touch.x = x;
            event.touch.y = y;

            states.touchEvents[id] = Vector2i(event.touch.x, event.touch.y);]=])
    set(SFML_TOUCH_DOWN_NEW [=[            event.type = Event::MouseButtonPressed;
            event.mouseButton.button = Mouse::Left;
            event.mouseButton.x = x;
            event.mouseButton.y = y;

            states.mousePosition = Vector2i(x, y);
            states.isButtonPressed[Mouse::Left] = true;
            states.touchEvents[id] = Vector2i(x, y);]=])

    set(SFML_TOUCH_UP_OLD [=[            event.type = Event::TouchEnded;
            event.touch.finger = static_cast<unsigned int>(id);
            event.touch.x = x;
            event.touch.y = y;

            states.touchEvents.erase(id);]=])
    set(SFML_TOUCH_UP_NEW [=[            event.type = Event::MouseButtonReleased;
            event.mouseButton.button = Mouse::Left;
            event.mouseButton.x = x;
            event.mouseButton.y = y;

            states.mousePosition = Vector2i(x, y);
            states.isButtonPressed[Mouse::Left] = false;
            states.touchEvents.erase(id);]=])

    set(SFML_TOUCH_MOVE_OLD [=[            event.touch.finger = static_cast<unsigned int>(id);
            event.touch.x = x;
            event.touch.y = y;

            states.touchEvents[id] = Vector2i(event.touch.x, event.touch.y);]=])
    set(SFML_TOUCH_MOVE_NEW [=[            event.type = Event::MouseMoved;
            event.mouseMove.x = x;
            event.mouseMove.y = y;

            states.mousePosition = Vector2i(x, y);
            states.touchEvents[id] = Vector2i(x, y);]=])

    string(FIND "${SFML_ANDROID_WINDOW_SOURCE}" "${SFML_TOUCH_DOWN_OLD}" SFML_TOUCH_DOWN_POS)
    string(FIND "${SFML_ANDROID_WINDOW_SOURCE}" "${SFML_TOUCH_UP_OLD}" SFML_TOUCH_UP_POS)
    string(FIND "${SFML_ANDROID_WINDOW_SOURCE}" "${SFML_TOUCH_MOVE_OLD}" SFML_TOUCH_MOVE_POS)
    if(SFML_TOUCH_DOWN_POS EQUAL -1 OR SFML_TOUCH_UP_POS EQUAL -1 OR SFML_TOUCH_MOVE_POS EQUAL -1)
        message(FATAL_ERROR "Expected SFML 2.6.2 Android touch input blocks were not found")
    endif()
    string(REPLACE "${SFML_TOUCH_DOWN_OLD}" "${SFML_TOUCH_DOWN_NEW}" SFML_ANDROID_WINDOW_SOURCE "${SFML_ANDROID_WINDOW_SOURCE}")
    string(REPLACE "${SFML_TOUCH_UP_OLD}" "${SFML_TOUCH_UP_NEW}" SFML_ANDROID_WINDOW_SOURCE "${SFML_ANDROID_WINDOW_SOURCE}")
    string(REPLACE "${SFML_TOUCH_MOVE_OLD}" "${SFML_TOUCH_MOVE_NEW}" SFML_ANDROID_WINDOW_SOURCE "${SFML_ANDROID_WINDOW_SOURCE}")
    file(WRITE "${SFML_ANDROID_WINDOW_CPP}" "${SFML_ANDROID_WINDOW_SOURCE}")

    add_subdirectory("${sfml_SOURCE_DIR}" "${sfml_BINARY_DIR}")
endif()
FetchContent_GetProperties(SFML SOURCE_DIR SFML_SOURCE_DIR)

# Classic BoE uses Boost.Filesystem plus header-only Boost modules. Boost's
# modular CMake build only exposes headers for modules that are explicitly
# selected, so include every module currently used directly by the game.
set(BOOST_INCLUDE_LIBRARIES filesystem system algorithm dynamic_bitset any lexical_cast ptr_container spirit math CACHE STRING "" FORCE)
FetchContent_Declare(
    Boost
    URL https://github.com/boostorg/boost/releases/download/boost-1.85.0/boost-1.85.0-cmake.tar.xz
)
FetchContent_MakeAvailable(Boost)

# TGUI 0.9.5 is the revision pinned by the upstream repository and has an
# Android-aware CMake build. Building it in the same project lets it reuse the
# SFML targets above instead of searching for desktop libraries.
set(TGUI_BACKEND SFML CACHE STRING "" FORCE)
set(TGUI_CXX_STANDARD 17 CACHE STRING "" FORCE)
set(TGUI_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(TGUI_BUILD_DOC OFF CACHE BOOL "" FORCE)
set(TGUI_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(TGUI_BUILD_GUI_BUILDER OFF CACHE BOOL "" FORCE)
add_subdirectory("${CBOE_ROOT}/deps/TGUI" "${CMAKE_CURRENT_BINARY_DIR}/tgui")

set(GAME_SOURCES
    "${CBOE_ROOT}/src/game/boe.actions.cpp"
    "${CBOE_ROOT}/src/game/boe.combat.cpp"
    "${CBOE_ROOT}/src/game/boe.dlgutil.cpp"
    "${CBOE_ROOT}/src/game/boe.fileio.cpp"
    "${CBOE_ROOT}/src/game/boe.graphics.cpp"
    "${CBOE_ROOT}/src/game/boe.graphutil.cpp"
    "${CBOE_ROOT}/src/game/boe.infodlg.cpp"
    "${CBOE_ROOT}/src/game/boe.items.cpp"
    "${CBOE_ROOT}/src/game/boe.locutils.cpp"
    "${CBOE_ROOT}/src/game/boe.main.cpp"
    "${CBOE_ROOT}/src/game/boe.monster.cpp"
    "${CBOE_ROOT}/src/game/boe.newgraph.cpp"
    "${CBOE_ROOT}/src/game/boe.party.cpp"
    "${CBOE_ROOT}/src/game/boe.specials.cpp"
    "${CBOE_ROOT}/src/game/boe.startup.cpp"
    "${CBOE_ROOT}/src/game/boe.text.cpp"
    "${CBOE_ROOT}/src/game/boe.town.cpp"
    "${CBOE_ROOT}/src/game/boe.townspec.cpp"
    "${CBOE_ROOT}/src/game/boe.ui.cpp"
    "${CBOE_ROOT}/src/game/boe.menus.linux.cpp"
    "${CBOE_ROOT}/src/game/boe.menu.cpp"
    "${CBOE_ROOT}/src/pcedit/pc.editors.cpp"
    "${CBOE_ROOT}/src/fileio/fileio_party.cpp"
    "${CBOE_ROOT}/src/view_dialogs.cpp"
    "${CBOE_ROOT}/deps/fmtlib/src/format.cc"
    "${CBOE_ROOT}/deps/fmtlib/src/os.cc"
)

set(TOOLS_SOURCES
    "${CBOE_ROOT}/src/tools/undo.cpp"
    "${CBOE_ROOT}/src/tools/framerate_limiter.cpp"
    "${CBOE_ROOT}/src/tools/drawable_manager.cpp"
    "${CBOE_ROOT}/src/tools/keymods.cpp"
    "${CBOE_ROOT}/src/tools/replay.cpp"
    "${CBOE_ROOT}/src/tools/profile.cpp"
    "${CBOE_ROOT}/src/tools/winutil.cpp"
    "${CBOE_ROOT}/src/tools/prefs.cpp"
    "${CBOE_ROOT}/src/tools/cursors.android.cpp"
    "${CBOE_ROOT}/src/tools/winutil.android.cpp"
    "${CBOE_ROOT}/src/alchemy.cpp"
    "${CBOE_ROOT}/src/damage.cpp"
    "${CBOE_ROOT}/src/enchant.cpp"
    "${CBOE_ROOT}/src/location.cpp"
    "${CBOE_ROOT}/src/mathutil.cpp"
    "${CBOE_ROOT}/src/porting.cpp"
    "${CBOE_ROOT}/src/pattern.cpp"
    "${CBOE_ROOT}/src/sounds.cpp"
    "${CBOE_ROOT}/src/spell.cpp"
    "${CBOE_ROOT}/src/utility.cpp"
    "${CBOE_ROOT}/src/fileio/estreams.cpp"
    "${CBOE_ROOT}/src/fileio/fileio.cpp"
    "${CBOE_ROOT}/src/fileio/fileio_scen.cpp"
    "${CBOE_ROOT}/src/fileio/map_parse.cpp"
    "${CBOE_ROOT}/src/fileio/special_parse.cpp"
    "${CBOE_ROOT}/src/fileio/tarball.cpp"
    "${CBOE_ROOT}/src/fileio/tagfile.cpp"
    "${CBOE_ROOT}/src/fileio/gzstream/gzstream.cpp"
)

file(GLOB RESMGR_SOURCES CONFIGURE_DEPENDS "${CBOE_ROOT}/src/fileio/resmgr/*.cpp")
file(GLOB GFX_SOURCES CONFIGURE_DEPENDS "${CBOE_ROOT}/src/gfx/*.cpp")
file(GLOB SCENARIO_SOURCES CONFIGURE_DEPENDS "${CBOE_ROOT}/src/scenario/*.cpp")
file(GLOB UNIVERSE_SOURCES CONFIGURE_DEPENDS "${CBOE_ROOT}/src/universe/*.cpp")
file(GLOB DIALOGXML_SOURCES CONFIGURE_DEPENDS
    "${CBOE_ROOT}/src/dialogxml/*.cpp"
    "${CBOE_ROOT}/src/dialogxml/dialogs/*.cpp"
    "${CBOE_ROOT}/src/dialogxml/widgets/*.cpp"
    "${CBOE_ROOT}/src/fileio/xml-parser/*.cpp"
)

# SFML invokes main(0, nullptr) on Android. Rename the game's desktop main and
# provide a small Android wrapper that supplies a valid argv[0] and unpacks
# bundled game resources to the app's private filesystem first.
set_source_files_properties("${CBOE_ROOT}/src/game/boe.main.cpp"
    PROPERTIES COMPILE_DEFINITIONS "main=cboe_portable_main"
)

add_library(cboe SHARED
    "${CMAKE_CURRENT_LIST_DIR}/android_main.cpp"
    ${GAME_SOURCES}
    ${TOOLS_SOURCES}
    ${RESMGR_SOURCES}
    ${GFX_SOURCES}
    ${SCENARIO_SOURCES}
    ${UNIVERSE_SOURCES}
    ${DIALOGXML_SOURCES}
)

# SCons normally generates this header. Generate a small Android equivalent so
# version/reporting code can compile before we wire in release metadata.
execute_process(
    COMMAND git rev-parse --short HEAD
    WORKING_DIRECTORY "${CBOE_ROOT}"
    OUTPUT_VARIABLE CBOE_GIT_REV
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)
if(NOT CBOE_GIT_REV)
    set(CBOE_GIT_REV "android")
endif()
set(GENERATED_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")
file(MAKE_DIRECTORY "${GENERATED_DIR}/tools")
file(WRITE "${GENERATED_DIR}/tools/gitrev.hpp"
"\n#define GIT_REVISION \"${CBOE_GIT_REV}\"\n#define GIT_TAG \"\"\n#define GIT_TAG_REVISION \"\"\n#define GIT_STATUS \"android-port\"\n#define GIT_REPO \"https://github.com/narmanb/cboe-android\"\n")

# The desktop SCons build adds every source directory to the include path.
# Reproduce that behavior without having to manually maintain dozens of paths.
file(GLOB_RECURSE CBOE_HEADERS CONFIGURE_DEPENDS
    "${CBOE_ROOT}/src/*.h"
    "${CBOE_ROOT}/src/*.hpp"
)
set(CBOE_INCLUDE_DIRS "${CBOE_ROOT}/src")
foreach(header ${CBOE_HEADERS})
    get_filename_component(header_dir "${header}" DIRECTORY)
    list(APPEND CBOE_INCLUDE_DIRS "${header_dir}")
endforeach()
list(REMOVE_DUPLICATES CBOE_INCLUDE_DIRS)

target_include_directories(cboe PRIVATE
    ${CBOE_INCLUDE_DIRS}
    "${GENERATED_DIR}"
    "${CBOE_ROOT}/deps/Catch2/include/external"
    "${CBOE_ROOT}/deps/cppcodec"
    "${CBOE_ROOT}/deps/fmtlib/include"
    "${SFML_SOURCE_DIR}/src"
    "${SFML_SOURCE_DIR}/extlibs/headers/glad/include"
)

target_compile_definitions(cboe PRIVATE TIXML_USE_TICPP)
target_compile_options(cboe PRIVATE
    -fpermissive
    -fexceptions
    -frtti
    -include "${CBOE_ROOT}/src/global.hpp"
)

# SFML's Android bootstrap loads the application library dynamically. The
# sfml-main archive provides ANativeActivity_onCreate inside libcboe.so, so it
# must be linked whole just as SFML's official Android.mk example does.
target_link_libraries(cboe PRIVATE
    "-Wl,--whole-archive"
    sfml-main
    "-Wl,--no-whole-archive"
    tgui
    Boost::filesystem
    Boost::system
    Boost::algorithm
    Boost::dynamic_bitset
    Boost::any
    Boost::lexical_cast
    Boost::ptr_container
    Boost::spirit
    Boost::math
    sfml-graphics
    sfml-window
    sfml-audio
    sfml-network
    sfml-system
    GLESv1_CM
    z
    android
    log
)

# sfml-activity is the tiny bootstrap NativeActivity loaded directly by the
# manifest. It then loads SFML, TGUI and libcboe.so.
add_dependencies(cboe sfml-activity)
