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
FetchContent_MakeAvailable(SFML)

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

add_library(cboe SHARED
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
