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

# Touch-backed pointer coordinates are now handled directly in OpenBoE's
# Android-port source (src/tools/winutil.cpp and src/game/boe.actions.cpp).
# Keeping a second text-replacement patch here would fail once the permanent
# source fix is already present, so no pointer source rewrite is needed here.
