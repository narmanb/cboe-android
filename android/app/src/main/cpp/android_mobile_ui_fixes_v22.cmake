# Android ACT divider/text polish v22.
# - Align minimap and ACT left edges to the same vertical divider.
# - Extend ACT rows a few more pixels downward.
# - Restore labels through the proven generic quick-button text path.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V22_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V22_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V22_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V22_WINUTIL_CPP "${CBOE_ANDROID_UI_V22_ROOT}/src/tools/winutil.cpp")
file(READ "${CBOE_ANDROID_V22_WINUTIL_CPP}" V22_WINUTIL)

# The physical screenshot shows the actual shared divider about four pixels left
# of the former minimap/ACT origin. Move the minimap itself onto that divider.
set(V22_MINI_GAP_OLD [=[        const float top = 14.f;
        const float info_gap = 8.f;
        const float menu_lane = 60.f;
        const float lane_gap = 8.f;
        const float left = layout.stats.screen.left + layout.stats.screen.width + info_gap;]=])
set(V22_MINI_GAP_NEW [=[        const float top = 14.f;
        const float info_gap = 4.f;
        const float menu_lane = 60.f;
        const float lane_gap = 8.f;
        const float left = layout.stats.screen.left + layout.stats.screen.width + info_gap;]=])
string(FIND "${V22_WINUTIL}" "${V22_MINI_GAP_OLD}" V22_MINI_GAP_POS)
if(V22_MINI_GAP_POS EQUAL -1)
    message(FATAL_ERROR "v22: expected v16 minimap gap geometry not found")
endif()
string(REPLACE "${V22_MINI_GAP_OLD}" "${V22_MINI_GAP_NEW}" V22_WINUTIL "${V22_WINUTIL}")

# Keep the control-region calculation synchronized with the shifted minimap so
# the ACT top boundary still begins below the map rather than its former edge.
set(V22_REGION_GAP_OLD [=[    const float mini_top = 14.f;
    const float info_gap = 8.f;
    const float menu_lane = 60.f;
    const float lane_gap = 8.f;
    const float mini_left = layout.stats.screen.left + layout.stats.screen.width + info_gap;]=])
set(V22_REGION_GAP_NEW [=[    const float mini_top = 14.f;
    const float info_gap = 4.f;
    const float menu_lane = 60.f;
    const float lane_gap = 8.f;
    const float mini_left = layout.stats.screen.left + layout.stats.screen.width + info_gap;]=])
string(FIND "${V22_WINUTIL}" "${V22_REGION_GAP_OLD}" V22_REGION_GAP_POS)
if(V22_REGION_GAP_POS EQUAL -1)
    message(FATAL_ERROR "v22: expected v18 action-region minimap gap not found")
endif()
string(REPLACE "${V22_REGION_GAP_OLD}" "${V22_REGION_GAP_NEW}" V22_WINUTIL "${V22_WINUTIL}")

# Match ACT to the exact same divider formula used by the shifted minimap. Keep
# this local because android_quick_geometry is compiled before android_map_mini_rect.
set(V22_ACT_LEFT_OLD [=[        const float info_right = layout.info_column.left + layout.info_column.width;
        const float desired_left = info_right + 2.f;
        const float desired_right = dpad_panel.left + dpad_panel.width;]=])
set(V22_ACT_LEFT_NEW [=[        const float desired_left =
            layout.stats.screen.left + layout.stats.screen.width + 4.f;
        const float desired_right = dpad_panel.left + dpad_panel.width;]=])
string(FIND "${V22_WINUTIL}" "${V22_ACT_LEFT_OLD}" V22_ACT_LEFT_POS)
if(V22_ACT_LEFT_POS EQUAL -1)
    message(FATAL_ERROR "v22: expected v21 ACT left-edge geometry not found")
endif()
string(REPLACE "${V22_ACT_LEFT_OLD}" "${V22_ACT_LEFT_NEW}" V22_WINUTIL "${V22_WINUTIL}")

# Add another four pixels to each of the three rows. The top remains fixed, so
# this uses the safe space below the current grid exactly as requested.
set(V22_HEIGHT_OLD [=[            action_h = std::min(64.f, candidate_h + 3.f);
            total_h = action_h * 3.f + row_gap * 2.f;]=])
set(V22_HEIGHT_NEW [=[            action_h = std::min(68.f, candidate_h + 7.f);
            total_h = action_h * 3.f + row_gap * 2.f;]=])
string(FIND "${V22_WINUTIL}" "${V22_HEIGHT_OLD}" V22_HEIGHT_POS)
if(V22_HEIGHT_POS EQUAL -1)
    message(FATAL_ERROR "v22: expected v21 ACT row height not found")
endif()
string(REPLACE "${V22_HEIGHT_OLD}" "${V22_HEIGHT_NEW}" V22_WINUTIL "${V22_WINUTIL}")

set(V22_FALLBACK_HEIGHT_OLD [=[        action_h = std::min(62.f, std::max(45.f, static_cast<float>(window_size.y) * 0.072f));]=])
set(V22_FALLBACK_HEIGHT_NEW [=[        action_h = std::min(66.f, std::max(48.f, static_cast<float>(window_size.y) * 0.076f));]=])
string(FIND "${V22_WINUTIL}" "${V22_FALLBACK_HEIGHT_OLD}" V22_FALLBACK_HEIGHT_POS)
if(V22_FALLBACK_HEIGHT_POS EQUAL -1)
    message(FATAL_ERROR "v22: expected v21 ACT fallback row height not found")
endif()
string(REPLACE "${V22_FALLBACK_HEIGHT_OLD}" "${V22_FALLBACK_HEIGHT_NEW}" V22_WINUTIL "${V22_WINUTIL}")

# v20's custom label lane proved unreliable on the physical device: the icon
# rendered, but win_draw_string produced no visible label. Reuse the original
# quick-button renderer that was already physically proven to draw labels, add
# leading padding so the text starts beyond the icon, then paint the icon last.
set(V22_ACTION_BUTTON_OLD [=[void draw_android_quick_action_button(const sf::FloatRect& rect, int action,
                                      bool available, bool pressed) {
    sf::RectangleShape box({rect.width, rect.height});
    box.setPosition(rect.left, rect.top);
    if(!available)
        box.setFillColor(sf::Color(28, 28, 32, 225));
    else if(pressed)
        box.setFillColor(sf::Color(72, 72, 82, 245));
    else
        box.setFillColor(sf::Color(18, 18, 22, 235));
    box.setOutlineColor(available ? sf::Color(238, 238, 238, 230)
                                  : sf::Color(110, 110, 116, 190));
    box.setOutlineThickness(2.f);
    mainPtr().draw(box);

    draw_android_quick_icon(rect, action, available);

    TextStyle style;
    style.font = FONT_BOLD;
    style.pointSize = 14;
    style.lineHeight = 16;
    style.colour = available ? sf::Color::White : sf::Color(130, 130, 136, 255);

    const float icon_lane = std::min(46.f, std::max(40.f, rect.height * 0.82f));
    rectangle label_rect {
        static_cast<int>(rect.top),
        static_cast<int>(rect.left + icon_lane),
        static_cast<int>(rect.top + rect.height),
        static_cast<int>(rect.left + rect.width - 3.f)
    };
    win_draw_string(mainPtr(), label_rect, android_quick_label(action),
                    eTextMode::CENTRE, style);
}]=])
set(V22_ACTION_BUTTON_NEW [=[void draw_android_quick_action_button(const sf::FloatRect& rect, int action,
                                      bool available, bool pressed) {
    const std::string padded_label = "     " + android_quick_label(action);
    draw_android_quick_button(rect, padded_label, available, pressed);
    draw_android_quick_icon(rect, action, available);
}]=])
string(FIND "${V22_WINUTIL}" "${V22_ACTION_BUTTON_OLD}" V22_ACTION_BUTTON_POS)
if(V22_ACTION_BUTTON_POS EQUAL -1)
    message(FATAL_ERROR "v22: expected v21 ACT custom label renderer not found")
endif()
string(REPLACE "${V22_ACTION_BUTTON_OLD}" "${V22_ACTION_BUTTON_NEW}" V22_WINUTIL "${V22_WINUTIL}")

file(WRITE "${CBOE_ANDROID_V22_WINUTIL_CPP}" "${V22_WINUTIL}")
message(STATUS "Applied Android mobile UI v22 divider alignment and label restore")
