# Android responsive-layout follow-up after 1920x1080 Retroid physical testing.
# The previous 2340x1080 reference-canvas fit used the narrower axis for every
# dimension. On a 1920x1080 display that shrank the whole composition to ~82%
# and created unused bars above/below while also shrinking ACT text and controls.
# Reflow the mobile shell across the actual physical window instead: size touch
# controls from display height, use the full window height, and let horizontal
# panel widths adapt to the available width.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V29_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V29_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V29_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(V29_WINUTIL_CPP "${CBOE_ANDROID_UI_V29_ROOT}/src/tools/winutil.cpp")
set(V29_DIALOG_CPP "${CBOE_ANDROID_UI_V29_ROOT}/src/dialogxml/dialogs/dialog.cpp")

file(READ "${V29_WINUTIL_CPP}" V29_WINUTIL)

# Geometry scale now represents physical height, not a letterboxed 2340x1080
# canvas. This keeps a 1080-high Retroid at the same control/text sizes as the
# established 1080-high phone while shorter displays still scale down safely.
set(V29_SCALE_OLD [=[float android_reference_scale() {
    const sf::Vector2u size = mainPtr().getSize();
    if(size.x == 0 || size.y == 0)
        return 1.f;
    const float width_scale = static_cast<float>(size.x) / 2340.f;
    const float height_scale = static_cast<float>(size.y) / 1080.f;
    return std::max(0.35f, std::min(1.25f, std::min(width_scale, height_scale)));
}]=])
set(V29_SCALE_NEW [=[float android_reference_scale() {
    const sf::Vector2u size = mainPtr().getSize();
    if(size.y == 0)
        return 1.f;
    const float height_scale = static_cast<float>(size.y) / 1080.f;
    return std::max(0.35f, std::min(1.25f, height_scale));
}]=])
string(FIND "${V29_WINUTIL}" "${V29_SCALE_OLD}" V29_SCALE_POS)
if(V29_SCALE_POS EQUAL -1)
    message(FATAL_ERROR "v29: expected v25 reference-scale helper not found")
endif()
string(REPLACE "${V29_SCALE_OLD}" "${V29_SCALE_NEW}" V29_WINUTIL "${V29_WINUTIL}")

# v26 anchored the D-pad to the fitted reference canvas. The canvas is gone;
# anchor it directly to the physical right/bottom edges using the v27 height-
# based padding and button size.
set(V29_DPAD_OLD [=[    const float grid_size = 3.f * button_size + 2.f * gap;
    const float content_width = 2340.f * reference_scale;
    const float content_height = 1080.f * reference_scale;
    const float content_left = std::max(0.f,
        (static_cast<float>(window_size.x) - content_width) * 0.5f);
    const float content_top = std::max(0.f,
        (static_cast<float>(window_size.y) - content_height) * 0.5f);
    float left = content_left + content_width - right_padding - grid_size;
    float top = content_top + content_height - vertical_padding - grid_size;]=])
set(V29_DPAD_NEW [=[    const float grid_size = 3.f * button_size + 2.f * gap;
    float left = static_cast<float>(window_size.x) - right_padding - grid_size;
    float top = static_cast<float>(window_size.y) - vertical_padding - grid_size;]=])
string(FIND "${V29_WINUTIL}" "${V29_DPAD_OLD}" V29_DPAD_POS)
if(V29_DPAD_POS EQUAL -1)
    message(FATAL_ERROR "v29: expected v26 reference-canvas D-pad anchor not found")
endif()
string(REPLACE "${V29_DPAD_OLD}" "${V29_DPAD_NEW}" V29_WINUTIL "${V29_WINUTIL}")

# Main mobile shell: use the entire physical window. Terrain keeps its existing
# aspect ratio; the information column absorbs the horizontal difference between
# display classes instead of shrinking every element uniformly.
set(V29_LAYOUT_OLD [=[    const float w = static_cast<float>(size.x);
    const float h = static_cast<float>(size.y);
    const float reference_scale = android_reference_scale();
    const float content_w = 2340.f * reference_scale;
    const float content_h = 1080.f * reference_scale;
    const float content_left = std::max(0.f, (w - content_w) * 0.5f);
    const float content_top = std::max(0.f, (h - content_h) * 0.5f);
    const float margin = 8.f * reference_scale;
    const float gap = 6.f * reference_scale;]=])
set(V29_LAYOUT_NEW [=[    const float w = static_cast<float>(size.x);
    const float h = static_cast<float>(size.y);
    const float reference_scale = android_reference_scale();
    const float content_w = w;
    const float content_h = h;
    const float content_left = 0.f;
    const float content_top = 0.f;
    const float margin = 8.f * reference_scale;
    const float gap = 6.f * reference_scale;]=])
string(FIND "${V29_WINUTIL}" "${V29_LAYOUT_OLD}" V29_LAYOUT_POS)
if(V29_LAYOUT_POS EQUAL -1)
    message(FATAL_ERROR "v29: expected v25 fitted mobile-layout header not found")
endif()
string(REPLACE "${V29_LAYOUT_OLD}" "${V29_LAYOUT_NEW}" V29_WINUTIL "${V29_WINUTIL}")

# Android's original fallback scale reserved 32% of screen width for a desktop
# multi-window arrangement that Android no longer uses. Keep the canonical phone
# scale on extra-wide displays, but on normal landscape displays use the actual
# available width/height and center the fixed-aspect startup screen.
set(V29_FALLBACK_OLD [=[#ifdef __ANDROID__
    if(scale == 0) {
        const sf::VideoMode desktop = sf::VideoMode::getDesktopMode();
        const double width_scale = (static_cast<double>(desktop.width) * 0.68) / boe_width;
        const double usable_height = desktop.height > 32 ? static_cast<double>(desktop.height - 24) : desktop.height;
        const double height_scale = usable_height / boe_height;
        scale = width_scale < height_scale ? width_scale : height_scale;
        if(scale < 1.0) scale = 1.0;
        if(scale > 2.25) scale = 2.25;
    }

    static bool android_layout_prepared = false;
    if(!android_layout_prepared) {
        set_pref("DisplayMode", 1);
        clear_pref("UIScale");
        android_layout_prepared = true;
    }
    return scale;
#endif]=])
set(V29_FALLBACK_NEW [=[#ifdef __ANDROID__
    if(scale == 0) {
        const sf::VideoMode desktop = sf::VideoMode::getDesktopMode();
        const double width_scale = static_cast<double>(desktop.width) / boe_width;
        const double usable_height = desktop.height > 32 ? static_cast<double>(desktop.height - 24) : desktop.height;
        const double height_scale = usable_height / boe_height;
        scale = width_scale < height_scale ? width_scale : height_scale;
        if(scale < 1.0) scale = 1.0;
        const double aspect = desktop.height > 0
            ? static_cast<double>(desktop.width) / static_cast<double>(desktop.height)
            : 2.0;
        // Preserve the established wide-phone title size. Standard landscape
        // devices can use more of their height instead of inheriting that cap.
        const double max_scale = aspect >= 2.0 ? 2.25 : 2.60;
        if(scale > max_scale) scale = max_scale;
    }

    static bool android_layout_prepared = false;
    if(!android_layout_prepared) {
        const sf::VideoMode desktop = sf::VideoMode::getDesktopMode();
        const double aspect = desktop.height > 0
            ? static_cast<double>(desktop.width) / static_cast<double>(desktop.height)
            : 2.0;
        set_pref("DisplayMode", aspect >= 2.0 ? 1 : 0);
        clear_pref("UIScale");
        android_layout_prepared = true;
    }
    return scale;
#endif]=])
string(FIND "${V29_WINUTIL}" "${V29_FALLBACK_OLD}" V29_FALLBACK_POS)
if(V29_FALLBACK_POS EQUAL -1)
    message(FATAL_ERROR "v29: expected Android fallback scale block not found")
endif()
string(REPLACE "${V29_FALLBACK_OLD}" "${V29_FALLBACK_NEW}" V29_WINUTIL "${V29_WINUTIL}")

file(WRITE "${V29_WINUTIL_CPP}" "${V29_WINUTIL}")

# v28 intentionally leaves the dialog view active until MouseButtonReleased so
# the release hit-test works. Once the modal actually closes, restore mainView
# before the base title/game redraw. Otherwise the next title action can briefly
# redraw through a stale dialog viewport, producing the intermittent black/
# cropped flash seen on the Retroid.
file(READ "${V29_DIALOG_CPP}" V29_DIALOG)
set(V29_CLOSE_OLD [=[#ifdef __ANDROID__
	set_cursor(former_curs);
	topWindow = formerTop;
	if(formerTop)
		formerTop->draw();
	else if(redraw_everything)
		redraw_everything();
#else]=])
set(V29_CLOSE_NEW [=[#ifdef __ANDROID__
	set_cursor(former_curs);
	topWindow = formerTop;
	if(formerTop) {
		formerTop->draw();
	} else {
		mainPtr().setView(mainView);
		if(redraw_everything)
			redraw_everything();
	}
#else]=])
string(FIND "${V29_DIALOG}" "${V29_CLOSE_OLD}" V29_CLOSE_POS)
if(V29_CLOSE_POS EQUAL -1)
    message(FATAL_ERROR "v29: expected Android dialog close redraw block not found")
endif()
string(REPLACE "${V29_CLOSE_OLD}" "${V29_CLOSE_NEW}" V29_DIALOG "${V29_DIALOG}")
file(WRITE "${V29_DIALOG_CPP}" "${V29_DIALOG}")

message(STATUS "Applied Android full-height responsive layout and dialog-close view fix v29")
