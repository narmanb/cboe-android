# Android responsive startup diagnostics v30.
# The title-screen layout can change with aspect ratio, so CI must not infer one
# button's physical position from another. Log the real Make New Party center
# alongside the existing Tutorial center after the title geometry is laid out.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V30_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V30_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V30_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V30_GRAPHICS_CPP "${CBOE_ANDROID_UI_V30_ROOT}/src/game/boe.graphics.cpp")
file(READ "${CBOE_ANDROID_V30_GRAPHICS_CPP}" V30_GRAPHICS)

set(V30_STARTUP_CENTER_OLD [=[	static bool android_startup_center_logged = false;
	if(!android_startup_center_logged) {
		const rectangle& r = startup_button[STARTBTN_TUTORIAL];
		sf::Vector2f center((r.left + r.right) / 2.0f, (r.top + r.bottom) / 2.0f);
		sf::Vector2i pixel = mainPtr().mapCoordsToPixel(center, mainView);
		__android_log_print(ANDROID_LOG_INFO, "OpenBoEAndroid", "TUTORIAL_CENTER %d %d", pixel.x, pixel.y);
		android_startup_center_logged = true;
	}]=])
set(V30_STARTUP_CENTER_NEW [=[	static bool android_startup_center_logged = false;
	if(!android_startup_center_logged) {
		const rectangle& tutorial_rect = startup_button[STARTBTN_TUTORIAL];
		const sf::Vector2f tutorial_center(
			(tutorial_rect.left + tutorial_rect.right) / 2.0f,
			(tutorial_rect.top + tutorial_rect.bottom) / 2.0f);
		const sf::Vector2i tutorial_pixel = mainPtr().mapCoordsToPixel(tutorial_center, mainView);
		__android_log_print(ANDROID_LOG_INFO, "OpenBoEAndroid", "TUTORIAL_CENTER %d %d",
			tutorial_pixel.x, tutorial_pixel.y);

		const rectangle& new_rect = startup_button[STARTBTN_NEW];
		const sf::Vector2f new_center(
			(new_rect.left + new_rect.right) / 2.0f,
			(new_rect.top + new_rect.bottom) / 2.0f);
		const sf::Vector2i new_pixel = mainPtr().mapCoordsToPixel(new_center, mainView);
		__android_log_print(ANDROID_LOG_INFO, "OpenBoEAndroid", "STARTUP_NEW_CENTER %d %d",
			new_pixel.x, new_pixel.y);
		android_startup_center_logged = true;
	}]=])

string(FIND "${V30_GRAPHICS}" "${V30_STARTUP_CENTER_OLD}" V30_STARTUP_CENTER_POS)
if(V30_STARTUP_CENTER_POS EQUAL -1)
    message(FATAL_ERROR "v30: expected Android Tutorial-center diagnostic block not found")
endif()
string(REPLACE "${V30_STARTUP_CENTER_OLD}" "${V30_STARTUP_CENTER_NEW}" V30_GRAPHICS "${V30_GRAPHICS}")
file(WRITE "${CBOE_ANDROID_V30_GRAPHICS_CPP}" "${V30_GRAPHICS}")

message(STATUS "Applied Android responsive startup-center diagnostics v30")
