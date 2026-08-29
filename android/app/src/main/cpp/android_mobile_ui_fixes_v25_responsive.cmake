# Android responsive-layout pass v25.
# Generalize the phone-tuned composition onto other landscape displays by using
# the Galaxy-phone layout as a reference canvas and scaling it uniformly to fit.
# Also make scale-aware dialog text honor the dialog view's actual fit scale.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V25_RESPONSIVE_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V25_RESPONSIVE_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V25_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(V25_WINUTIL_CPP "${CBOE_ANDROID_UI_V25_ROOT}/src/tools/winutil.cpp")
set(V25_RENDER_TEXT_CPP "${CBOE_ANDROID_UI_V25_ROOT}/src/gfx/render_text.cpp")

file(READ "${V25_WINUTIL_CPP}" V25_WINUTIL)

# Treat the current phone composition as a 2340x1080 reference canvas. Devices
# with a different aspect ratio get one uniform scale, preserving the established
# proportions instead of letting fixed physical-pixel minimums dominate.
set(V25_SCALE_ANCHOR [=[// Android touch controls intentionally live in physical screen coordinates,
// not OpenBoE's scaled desktop View.
bool android_dpad_geometry]=])
set(V25_SCALE_INSERT [=[float android_reference_scale() {
    const sf::Vector2u size = mainPtr().getSize();
    if(size.x == 0 || size.y == 0)
        return 1.f;
    const float width_scale = static_cast<float>(size.x) / 2340.f;
    const float height_scale = static_cast<float>(size.y) / 1080.f;
    return std::max(0.35f, std::min(1.25f, std::min(width_scale, height_scale)));
}

// Android touch controls intentionally live in physical screen coordinates,
// not OpenBoE's scaled desktop View.
bool android_dpad_geometry]=])
string(FIND "${V25_WINUTIL}" "${V25_SCALE_ANCHOR}" V25_SCALE_POS)
if(V25_SCALE_POS EQUAL -1)
    message(FATAL_ERROR "v25 responsive: d-pad helper insertion anchor not found")
endif()
string(REPLACE "${V25_SCALE_ANCHOR}" "${V25_SCALE_INSERT}" V25_WINUTIL "${V25_WINUTIL}")

# Scale D-pad dimensions from the reference phone instead of imposing the same
# 78-114 physical-pixel buttons and 128px edge inset on every device.
set(V25_DPAD_OLD [=[    const float gap = 10.f;
    const float right_padding = 128.f;
    const float vertical_padding = 18.f;

    float button_size = static_cast<float>(window_size.y) * 0.152f;
    if(button_size > 114.f) button_size = 114.f;
    if(button_size < 78.f) button_size = 78.f;]=])
set(V25_DPAD_NEW [=[    const float reference_scale = android_reference_scale();
    const float gap = 10.f * reference_scale;
    const float right_padding = 128.f * reference_scale;
    const float vertical_padding = 18.f * reference_scale;

    float button_size = 114.f * reference_scale;
    button_size = std::max(42.f, std::min(114.f, button_size));]=])
string(FIND "${V25_WINUTIL}" "${V25_DPAD_OLD}" V25_DPAD_POS)
if(V25_DPAD_POS EQUAL -1)
    message(FATAL_ERROR "v25 responsive: final v15 d-pad sizing block not found")
endif()
string(REPLACE "${V25_DPAD_OLD}" "${V25_DPAD_NEW}" V25_WINUTIL "${V25_WINUTIL}")

# Scale the entire terrain/info composition as one reference layout. On a 16:9
# display width becomes the limiting dimension, so the established phone layout
# gets slightly letterboxed vertically rather than crushing the info stack.
set(V25_LAYOUT_HEAD_OLD [=[    const float h = static_cast<float>(size.y);
    const float margin = 8.f;
    const float gap = 6.f;

    std::array<AndroidDpadButton, 8> dpad_buttons;]=])
set(V25_LAYOUT_HEAD_NEW [=[    const float w = static_cast<float>(size.x);
    const float h = static_cast<float>(size.y);
    const float reference_scale = android_reference_scale();
    const float content_w = 2340.f * reference_scale;
    const float content_h = 1080.f * reference_scale;
    const float content_left = std::max(0.f, (w - content_w) * 0.5f);
    const float content_top = std::max(0.f, (h - content_h) * 0.5f);
    const float margin = 8.f * reference_scale;
    const float gap = 6.f * reference_scale;

    std::array<AndroidDpadButton, 8> dpad_buttons;]=])
string(FIND "${V25_WINUTIL}" "${V25_LAYOUT_HEAD_OLD}" V25_LAYOUT_HEAD_POS)
if(V25_LAYOUT_HEAD_POS EQUAL -1)
    message(FATAL_ERROR "v25 responsive: mobile-layout header not found")
endif()
string(REPLACE "${V25_LAYOUT_HEAD_OLD}" "${V25_LAYOUT_HEAD_NEW}" V25_WINUTIL "${V25_WINUTIL}")

set(V25_TERRAIN_OLD [=[    const float terrain_h = h - margin * 2.f;
    const float terrain_w = terrain_h * (335.f / 351.f);
    const sf::FloatRect terrain_bounds(margin, margin, terrain_w, terrain_h);]=])
set(V25_TERRAIN_NEW [=[    const float terrain_h = content_h - margin * 2.f;
    const float terrain_w = terrain_h * (335.f / 351.f);
    const sf::FloatRect terrain_bounds(content_left + margin, content_top + margin,
                                       terrain_w, terrain_h);]=])
string(FIND "${V25_WINUTIL}" "${V25_TERRAIN_OLD}" V25_TERRAIN_POS)
if(V25_TERRAIN_POS EQUAL -1)
    message(FATAL_ERROR "v25 responsive: 11x9 terrain layout block not found")
endif()
string(REPLACE "${V25_TERRAIN_OLD}" "${V25_TERRAIN_NEW}" V25_WINUTIL "${V25_WINUTIL}")

set(V25_INFO_MIN_OLD [=[    if(info_width < 260.f)
        return false;]=])
set(V25_INFO_MIN_NEW [=[    if(info_width < 260.f * reference_scale)
        return false;]=])
string(FIND "${V25_WINUTIL}" "${V25_INFO_MIN_OLD}" V25_INFO_MIN_POS)
if(V25_INFO_MIN_POS EQUAL -1)
    message(FATAL_ERROR "v25 responsive: info-column minimum not found")
endif()
string(REPLACE "${V25_INFO_MIN_OLD}" "${V25_INFO_MIN_NEW}" V25_WINUTIL "${V25_WINUTIL}")

set(V25_INFO_BOTTOM_OLD [=[    const float info_bottom = h - margin;
    const float info_height = info_bottom - margin;]=])
set(V25_INFO_BOTTOM_NEW [=[    const float info_bottom = content_top + content_h - margin;
    const float info_height = info_bottom - (content_top + margin);]=])
string(FIND "${V25_WINUTIL}" "${V25_INFO_BOTTOM_OLD}" V25_INFO_BOTTOM_POS)
if(V25_INFO_BOTTOM_POS EQUAL -1)
    message(FATAL_ERROR "v25 responsive: info-column vertical bounds not found")
endif()
string(REPLACE "${V25_INFO_BOTTOM_OLD}" "${V25_INFO_BOTTOM_NEW}" V25_WINUTIL "${V25_WINUTIL}")

set(V25_PANEL_TOP_OLD [=[    if(panel_width < 240.f)
        return false;

    float panel_top = margin;]=])
set(V25_PANEL_TOP_NEW [=[    if(panel_width < 240.f * reference_scale)
        return false;

    float panel_top = content_top + margin;]=])
string(FIND "${V25_WINUTIL}" "${V25_PANEL_TOP_OLD}" V25_PANEL_TOP_POS)
if(V25_PANEL_TOP_POS EQUAL -1)
    message(FATAL_ERROR "v25 responsive: panel top/minimum block not found")
endif()
string(REPLACE "${V25_PANEL_TOP_OLD}" "${V25_PANEL_TOP_NEW}" V25_WINUTIL "${V25_WINUTIL}")

set(V25_INFO_COLUMN_OLD [=[    layout.info_column = {info_left, margin, panel_width, info_height};]=])
set(V25_INFO_COLUMN_NEW [=[    layout.info_column = {info_left, content_top + margin, panel_width, info_height};]=])
string(FIND "${V25_WINUTIL}" "${V25_INFO_COLUMN_OLD}" V25_INFO_COLUMN_POS)
if(V25_INFO_COLUMN_POS EQUAL -1)
    message(FATAL_ERROR "v25 responsive: info-column output not found")
endif()
string(REPLACE "${V25_INFO_COLUMN_OLD}" "${V25_INFO_COLUMN_NEW}" V25_WINUTIL "${V25_WINUTIL}")

# Scale the live minimap's spacing and minimum size with the same reference
# factor so 16:9 devices do not fall into the large fixed-pixel fallback.
set(V25_MINIMAP_OLD [=[sf::FloatRect android_map_mini_rect() {
    const sf::Vector2u size = mainPtr().getSize();
    AndroidMobileLayout layout;
    std::array<AndroidDpadButton, 8> dpad_buttons;
    sf::FloatRect dpad_panel;
    if(android_mobile_layout(layout) && android_dpad_geometry(dpad_buttons, &dpad_panel)) {
        const float top = 14.f;
        const float info_gap = 8.f;
        const float menu_lane = 60.f;
        const float lane_gap = 8.f;
        const float left = layout.stats.screen.left + layout.stats.screen.width + info_gap;
        const float right = dpad_panel.left + dpad_panel.width - menu_lane - lane_gap;
        const float width_limit = right - left;
        const float height_limit = dpad_panel.top - top - 12.f;
        const float mini = std::min(width_limit, height_limit);
        if(mini >= 145.f)
            return {left, top, mini, mini};
    }

    // Defensive fallback for unusually small/odd displays.
    float mini = static_cast<float>(size.y) * 0.26f;
    if(mini > 190.f) mini = 190.f;
    if(mini < 145.f) mini = 145.f;
    return {static_cast<float>(size.x) - mini - 20.f, 18.f, mini, mini};
}]=])
set(V25_MINIMAP_NEW [=[sf::FloatRect android_map_mini_rect() {
    const sf::Vector2u size = mainPtr().getSize();
    const float scale = android_reference_scale();
    AndroidMobileLayout layout;
    std::array<AndroidDpadButton, 8> dpad_buttons;
    sf::FloatRect dpad_panel;
    if(android_mobile_layout(layout) && android_dpad_geometry(dpad_buttons, &dpad_panel)) {
        const float top = std::max(6.f, 14.f * scale);
        const float info_gap = 8.f * scale;
        const float menu_lane = 60.f * scale;
        const float lane_gap = 8.f * scale;
        const float left = layout.stats.screen.left + layout.stats.screen.width + info_gap;
        const float right = dpad_panel.left + dpad_panel.width - menu_lane - lane_gap;
        const float width_limit = right - left;
        const float height_limit = dpad_panel.top - top - 12.f * scale;
        const float mini = std::min(width_limit, height_limit);
        if(mini >= 145.f * scale)
            return {left, top, mini, mini};
    }

    float mini = static_cast<float>(size.y) * 0.26f;
    mini = std::min(190.f * scale, std::max(96.f, mini));
    return {static_cast<float>(size.x) - mini - 20.f * scale,
            std::max(6.f, 18.f * scale), mini, mini};
}]=])
string(FIND "${V25_WINUTIL}" "${V25_MINIMAP_OLD}" V25_MINIMAP_POS)
if(V25_MINIMAP_POS EQUAL -1)
    message(FATAL_ERROR "v25 responsive: final v16 minimap geometry not found")
endif()
string(REPLACE "${V25_MINIMAP_OLD}" "${V25_MINIMAP_NEW}" V25_WINUTIL "${V25_WINUTIL}")

# The ACT/MENU gap is also reference-scaled. Fixed 145/190px thresholds were
# the reason the Retroid-class layout abandoned this region entirely.
set(V25_CONTROL_REGION_OLD [=[bool android_action_controls_region(sf::FloatRect& region) {
    AndroidMobileLayout layout;
    std::array<AndroidDpadButton, 8> dpad_buttons;
    sf::FloatRect dpad_panel;
    if(!android_mobile_layout(layout) || !android_dpad_geometry(dpad_buttons, &dpad_panel))
        return false;

    const float mini_top = 14.f;
    const float info_gap = 8.f;
    const float menu_lane = 60.f;
    const float lane_gap = 8.f;
    const float mini_left = layout.stats.screen.left + layout.stats.screen.width + info_gap;
    const float mini_right = dpad_panel.left + dpad_panel.width - menu_lane - lane_gap;
    const float width_limit = mini_right - mini_left;
    const float height_limit = dpad_panel.top - mini_top - 12.f;
    const float mini_size = std::min(width_limit, height_limit);
    if(mini_size < 145.f)
        return false;

    const float controls_top = mini_top + mini_size + 14.f;
    const float controls_bottom = dpad_panel.top - 12.f;
    if(controls_bottom - controls_top < 190.f)
        return false;

    region = {dpad_panel.left, controls_top, dpad_panel.width,
              controls_bottom - controls_top};
    return true;
}]=])
set(V25_CONTROL_REGION_NEW [=[bool android_action_controls_region(sf::FloatRect& region) {
    const float scale = android_reference_scale();
    AndroidMobileLayout layout;
    std::array<AndroidDpadButton, 8> dpad_buttons;
    sf::FloatRect dpad_panel;
    if(!android_mobile_layout(layout) || !android_dpad_geometry(dpad_buttons, &dpad_panel))
        return false;

    const float mini_top = std::max(6.f, 14.f * scale);
    const float info_gap = 8.f * scale;
    const float menu_lane = 60.f * scale;
    const float lane_gap = 8.f * scale;
    const float mini_left = layout.stats.screen.left + layout.stats.screen.width + info_gap;
    const float mini_right = dpad_panel.left + dpad_panel.width - menu_lane - lane_gap;
    const float width_limit = mini_right - mini_left;
    const float height_limit = dpad_panel.top - mini_top - 12.f * scale;
    const float mini_size = std::min(width_limit, height_limit);
    if(mini_size < 145.f * scale)
        return false;

    const float controls_top = mini_top + mini_size + 14.f * scale;
    const float controls_bottom = dpad_panel.top - 12.f * scale;
    if(controls_bottom - controls_top < 190.f * scale)
        return false;

    region = {dpad_panel.left, controls_top, dpad_panel.width,
              controls_bottom - controls_top};
    return true;
}]=])
string(FIND "${V25_WINUTIL}" "${V25_CONTROL_REGION_OLD}" V25_CONTROL_REGION_POS)
if(V25_CONTROL_REGION_POS EQUAL -1)
    message(FATAL_ERROR "v25 responsive: ACT/MENU region helper not found")
endif()
string(REPLACE "${V25_CONTROL_REGION_OLD}" "${V25_CONTROL_REGION_NEW}" V25_WINUTIL "${V25_WINUTIL}")

set(V25_MENU_HEIGHT_OLD [=[float android_action_menu_height() {
    const float h = static_cast<float>(mainPtr().getSize().y) * 0.07f;
    return std::min(82.f, std::max(68.f, h));
}]=])
set(V25_MENU_HEIGHT_NEW [=[float android_action_menu_height() {
    const float scale = android_reference_scale();
    const float h = static_cast<float>(mainPtr().getSize().y) * 0.07f;
    return std::min(82.f * scale, std::max(48.f, std::max(68.f * scale, h * scale)));
}]=])
string(FIND "${V25_WINUTIL}" "${V25_MENU_HEIGHT_OLD}" V25_MENU_HEIGHT_POS)
if(V25_MENU_HEIGHT_POS EQUAL -1)
    message(FATAL_ERROR "v25 responsive: MENU height helper not found")
endif()
string(REPLACE "${V25_MENU_HEIGHT_OLD}" "${V25_MENU_HEIGHT_NEW}" V25_WINUTIL "${V25_WINUTIL}")

# Scale the final v20 ACT geometry's fixed dimensions. The phone still evaluates
# to the existing numbers; narrower devices get proportionally smaller controls.
set(V25_QUICK_HEAD_OLD [=[    const sf::Vector2u window_size = mainPtr().getSize();
    const float col_gap = 6.f;
    const float row_gap = 5.f;]=])
set(V25_QUICK_HEAD_NEW [=[    const sf::Vector2u window_size = mainPtr().getSize();
    const float scale = android_reference_scale();
    const float col_gap = 6.f * scale;
    const float row_gap = 5.f * scale;]=])
string(FIND "${V25_WINUTIL}" "${V25_QUICK_HEAD_OLD}" V25_QUICK_HEAD_POS)
if(V25_QUICK_HEAD_POS EQUAL -1)
    message(FATAL_ERROR "v25 responsive: final v20 ACT geometry header not found")
endif()
string(REPLACE "${V25_QUICK_HEAD_OLD}" "${V25_QUICK_HEAD_NEW}" V25_WINUTIL "${V25_WINUTIL}")

string(REPLACE "const float desired_left = info_right + 10.f;"
               "const float desired_left = info_right + 10.f * scale;"
               V25_WINUTIL "${V25_WINUTIL}")
string(REPLACE "if(candidate_w >= 270.f && candidate_h >= 32.f) {"
               "if(candidate_w >= 270.f * scale && candidate_h >= 32.f * scale) {"
               V25_WINUTIL "${V25_WINUTIL}")
string(REPLACE "action_h = std::min(60.f, candidate_h);"
               "action_h = std::min(60.f * scale, candidate_h);"
               V25_WINUTIL "${V25_WINUTIL}")
string(REPLACE "action_w = std::min(138.f, std::max(96.f, static_cast<float>(window_size.y) * 0.14f));"
               "action_w = std::min(138.f * scale, std::max(72.f, 96.f * scale));"
               V25_WINUTIL "${V25_WINUTIL}")
string(REPLACE "action_h = std::min(58.f, std::max(42.f, static_cast<float>(window_size.y) * 0.068f));"
               "action_h = std::min(58.f * scale, std::max(34.f, 42.f * scale));"
               V25_WINUTIL "${V25_WINUTIL}")
string(REPLACE "top = fallback_region.top + 1.f;"
               "top = fallback_region.top + 1.f * scale;"
               V25_WINUTIL "${V25_WINUTIL}")
string(REPLACE "dpad_panel.top - total_h - 10.f"
               "dpad_panel.top - total_h - 10.f * scale"
               V25_WINUTIL "${V25_WINUTIL}")

# The large MENU button's minimum width should follow the same scale.
set(V25_MENU_WIDTH_OLD [=[        const float width = std::min(region.width, std::max(160.f, region.width * 0.62f));]=])
set(V25_MENU_WIDTH_NEW [=[        const float width = std::min(region.width, std::max(120.f, 160.f * android_reference_scale()));]=])
string(FIND "${V25_WINUTIL}" "${V25_MENU_WIDTH_OLD}" V25_MENU_WIDTH_POS)
if(V25_MENU_WIDTH_POS EQUAL -1)
    message(FATAL_ERROR "v25 responsive: final MENU width expression not found")
endif()
string(REPLACE "${V25_MENU_WIDTH_OLD}" "${V25_MENU_WIDTH_NEW}" V25_WINUTIL "${V25_WINUTIL}")

file(WRITE "${V25_WINUTIL_CPP}" "${V25_WINUTIL}")

# Dialog labels use scale-aware text, which deliberately draws in the window's
# default physical-pixel view. The old code multiplied by get_ui_scale() only.
# When a dialog had to be fit smaller on a shorter screen, its button artwork
# respected the fitted View but text did not, causing shifted/missing labels.
# Derive the actual pixels-per-logical-unit from the active View and apply the
# additional fit factor to both text position and glyph scale.
file(READ "${V25_RENDER_TEXT_CPP}" V25_RENDER_TEXT)
set(V25_TEXT_OLD [=[		sf::Vector2f text_position = str_to_draw.getPosition() * (float)get_ui_scale();
		text_position += scaled_view_top_left(dest_window, scaled_view);
		// Rounding to whole-number positions *might* avoid unpredictable graphics bugs:
		round_vec(text_position);
		str_to_draw.setPosition(text_position);

		// Draw the text immediately
		dest_window.draw(str_to_draw);]=])
set(V25_TEXT_NEW [=[		#ifdef __ANDROID__
		const sf::FloatRect viewport = scaled_view.getViewport();
		const sf::Vector2u target_size = dest_window.getSize();
		const sf::Vector2f view_size = scaled_view.getSize();
		const float physical_scale_x = view_size.x > 0.f
			? viewport.width * static_cast<float>(target_size.x) / view_size.x : 1.f;
		const float physical_scale_y = view_size.y > 0.f
			? viewport.height * static_cast<float>(target_size.y) / view_size.y : 1.f;
		float ui_scale = static_cast<float>(get_ui_scale());
		if(ui_scale < 0.1f) ui_scale = 1.f;
		sf::Vector2f text_position(
			str_to_draw.getPosition().x * physical_scale_x,
			str_to_draw.getPosition().y * physical_scale_y);
		text_position += scaled_view_top_left(dest_window, scaled_view);
		const sf::Vector2f old_scale = str_to_draw.getScale();
		str_to_draw.setScale(old_scale.x * physical_scale_x / ui_scale,
		                     old_scale.y * physical_scale_y / ui_scale);
		#else
		sf::Vector2f text_position = str_to_draw.getPosition() * (float)get_ui_scale();
		text_position += scaled_view_top_left(dest_window, scaled_view);
		#endif
		// Rounding to whole-number positions *might* avoid unpredictable graphics bugs:
		round_vec(text_position);
		str_to_draw.setPosition(text_position);

		// Draw the text immediately
		dest_window.draw(str_to_draw);]=])
string(FIND "${V25_RENDER_TEXT}" "${V25_TEXT_OLD}" V25_TEXT_POS)
if(V25_TEXT_POS EQUAL -1)
    message(FATAL_ERROR "v25 responsive: scale-aware RenderWindow text block not found")
endif()
string(REPLACE "${V25_TEXT_OLD}" "${V25_TEXT_NEW}" V25_RENDER_TEXT "${V25_RENDER_TEXT}")
file(WRITE "${V25_RENDER_TEXT_CPP}" "${V25_RENDER_TEXT}")

message(STATUS "Applied Android responsive gameplay and dialog-text scaling v25")
