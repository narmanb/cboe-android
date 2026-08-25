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

# Emit the exact physical pixel center of the Tutorial button once. The CI
# emulator uses this to perform a real Android touchscreen tap instead of only
# checking that the process stayed alive.
set(CBOE_GRAPHICS_INCLUDE_OLD "#include <fmt/format.h>")
set(CBOE_GRAPHICS_INCLUDE_NEW "#include <fmt/format.h>\n#include <android/log.h>")
string(FIND "${CBOE_GRAPHICS_SOURCE}" "${CBOE_GRAPHICS_INCLUDE_OLD}" CBOE_GRAPHICS_INCLUDE_POS)
if(CBOE_GRAPHICS_INCLUDE_POS EQUAL -1)
    message(FATAL_ERROR "Expected OpenBoE graphics include block was not found")
endif()
string(REPLACE "${CBOE_GRAPHICS_INCLUDE_OLD}" "${CBOE_GRAPHICS_INCLUDE_NEW}" CBOE_GRAPHICS_SOURCE "${CBOE_GRAPHICS_SOURCE}")
set(CBOE_DRAW_STARTUP_OLD [=[void draw_startup(short but_type) {
	sf::Texture& startup_gworld = *ResMgr::graphics.get("startup", true);]=])
set(CBOE_DRAW_STARTUP_NEW [=[void draw_startup(short but_type) {
	static bool android_startup_center_logged = false;
	if(!android_startup_center_logged) {
		const rectangle& r = startup_button[STARTBTN_TUTORIAL];
		sf::Vector2f center((r.left + r.right) / 2.0f, (r.top + r.bottom) / 2.0f);
		sf::Vector2i pixel = mainPtr().mapCoordsToPixel(center, mainView);
		__android_log_print(ANDROID_LOG_INFO, "OpenBoEAndroid", "TUTORIAL_CENTER %d %d", pixel.x, pixel.y);
		android_startup_center_logged = true;
	}
	sf::Texture& startup_gworld = *ResMgr::graphics.get("startup", true);]=])
string(FIND "${CBOE_GRAPHICS_SOURCE}" "${CBOE_DRAW_STARTUP_OLD}" CBOE_DRAW_STARTUP_POS)
if(CBOE_DRAW_STARTUP_POS EQUAL -1)
    message(FATAL_ERROR "Expected OpenBoE draw_startup function was not found")
endif()
string(REPLACE "${CBOE_DRAW_STARTUP_OLD}" "${CBOE_DRAW_STARTUP_NEW}" CBOE_GRAPHICS_SOURCE "${CBOE_GRAPHICS_SOURCE}")
file(WRITE "${CBOE_GRAPHICS_CPP}" "${CBOE_GRAPHICS_SOURCE}")
message(STATUS "Applied Android draw_startup texture and touch-test instrumentation patches")

# On desktop the game shows Welcome / Tip-of-the-Day in a separate modal
# RenderWindow before the real main event loop starts. SFML's Android backend
# only supports one native window. On Android that hidden modal dialog can own
# the input/lifecycle loop while the title screen is what gets drawn underneath,
# which makes the visible title buttons appear completely dead and can expose the
# little dialog surface after an app switch. Do not create those pre-main-loop
# desktop windows on Android. We can reintroduce their content later as an
# in-window overlay.
set(CBOE_MAIN_CPP "${CBOE_ANDROID_ROOT}/src/game/boe.main.cpp")
file(READ "${CBOE_MAIN_CPP}" CBOE_MAIN_SOURCE)
set(CBOE_STARTUP_DIALOGS_OLD [=[		init_boe(argc, argv);
		
		if(!get_bool_pref("GameRunBefore"))
			showWelcome();
		else if(get_bool_pref("GiveIntroHint", true))
			tip_of_day();
		set_pref("GameRunBefore", true);
		finished_init = true;]=])
set(CBOE_STARTUP_DIALOGS_NEW [=[		init_boe(argc, argv);
		
		// Android: skip desktop-only startup modal windows. The main title
		// screen must own the NativeActivity surface and event loop directly.
		set_pref("GameRunBefore", true);
		finished_init = true;]=])
string(FIND "${CBOE_MAIN_SOURCE}" "${CBOE_STARTUP_DIALOGS_OLD}" CBOE_STARTUP_DIALOGS_POS)
if(CBOE_STARTUP_DIALOGS_POS EQUAL -1)
    message(FATAL_ERROR "Expected OpenBoE startup welcome/tip block was not found")
endif()
string(REPLACE "${CBOE_STARTUP_DIALOGS_OLD}" "${CBOE_STARTUP_DIALOGS_NEW}" CBOE_MAIN_SOURCE "${CBOE_MAIN_SOURCE}")
file(WRITE "${CBOE_MAIN_CPP}" "${CBOE_MAIN_SOURCE}")
message(STATUS "Skipped desktop startup modal dialogs on Android")

# Log actual startup-button dispatch so CI can prove that a real Android tap
# reached OpenBoE's existing desktop click handler.
set(CBOE_STARTUP_CPP "${CBOE_ANDROID_ROOT}/src/game/boe.startup.cpp")
file(READ "${CBOE_STARTUP_CPP}" CBOE_STARTUP_SOURCE)
set(CBOE_STARTUP_INCLUDE_OLD "#include <boost/lexical_cast.hpp>")
set(CBOE_STARTUP_INCLUDE_NEW "#include <boost/lexical_cast.hpp>\n#include <android/log.h>")
string(FIND "${CBOE_STARTUP_SOURCE}" "${CBOE_STARTUP_INCLUDE_OLD}" CBOE_STARTUP_INCLUDE_POS)
if(CBOE_STARTUP_INCLUDE_POS EQUAL -1)
    message(FATAL_ERROR "Expected OpenBoE startup include block was not found")
endif()
string(REPLACE "${CBOE_STARTUP_INCLUDE_OLD}" "${CBOE_STARTUP_INCLUDE_NEW}" CBOE_STARTUP_SOURCE "${CBOE_STARTUP_SOURCE}")
set(CBOE_STARTUP_CLICK_OLD [=[void handle_startup_button_click(eStartButton btn, eKeyMod mods) {
	if(recording){]=])
set(CBOE_STARTUP_CLICK_NEW [=[void handle_startup_button_click(eStartButton btn, eKeyMod mods) {
	__android_log_print(ANDROID_LOG_INFO, "OpenBoEAndroid", "STARTUP_BUTTON_CLICK %d", static_cast<int>(btn));
	if(recording){]=])
string(FIND "${CBOE_STARTUP_SOURCE}" "${CBOE_STARTUP_CLICK_OLD}" CBOE_STARTUP_CLICK_POS)
if(CBOE_STARTUP_CLICK_POS EQUAL -1)
    message(FATAL_ERROR "Expected OpenBoE startup click handler was not found")
endif()
string(REPLACE "${CBOE_STARTUP_CLICK_OLD}" "${CBOE_STARTUP_CLICK_NEW}" CBOE_STARTUP_SOURCE "${CBOE_STARTUP_SOURCE}")
file(WRITE "${CBOE_STARTUP_CPP}" "${CBOE_STARTUP_SOURCE}")
message(STATUS "Added Android startup touch-dispatch diagnostics")

# Touch-backed pointer coordinates are now handled directly in OpenBoE's
# Android-port source (src/tools/winutil.cpp and src/game/boe.actions.cpp).
# Keeping a second text-replacement patch here would fail once the permanent
# source fix is already present, so no pointer source rewrite is needed here.
