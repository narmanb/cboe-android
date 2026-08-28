# Android Exploration UI v2 layout polish after v14.
# - Keep the real 11x9 world viewport unchanged.
# - Move the D-pad to the lower-right and enlarge it one more modest step.
# - Expand the live minimap into the upper-right column, aligned closely with
#   the information stack instead of floating as a tiny square in empty space.
# - Give MENU a permanent narrow slot immediately to the right of the minimap.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V15_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V15_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V15_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V15_WINUTIL_CPP "${CBOE_ANDROID_UI_V15_ROOT}/src/tools/winutil.cpp")
file(READ "${CBOE_ANDROID_V15_WINUTIL_CPP}" V15_WINUTIL)

# One last small touch-size increase. Hold-repeat and tap semantics are unchanged.
set(V15_DPAD_SIZE_OLD [=[    float button_size = static_cast<float>(window_size.y) * 0.142f;
    if(button_size > 106.f) button_size = 106.f;
    if(button_size < 72.f) button_size = 72.f;]=])
set(V15_DPAD_SIZE_NEW [=[    float button_size = static_cast<float>(window_size.y) * 0.152f;
    if(button_size > 114.f) button_size = 114.f;
    if(button_size < 78.f) button_size = 78.f;]=])
string(FIND "${V15_WINUTIL}" "${V15_DPAD_SIZE_OLD}" V15_DPAD_SIZE_POS)
if(V15_DPAD_SIZE_POS EQUAL -1)
    message(FATAL_ERROR "v15: expected v13 d-pad size block not found")
endif()
string(REPLACE "${V15_DPAD_SIZE_OLD}" "${V15_DPAD_SIZE_NEW}" V15_WINUTIL "${V15_WINUTIL}")

# Put movement controls at the bottom of the right control column. This opens
# the upper part of that column for a useful live minimap without overlap.
set(V15_DPAD_TOP_OLD [=[    float top = (static_cast<float>(window_size.y) - grid_size) / 2.f;]=])
set(V15_DPAD_TOP_NEW [=[    float top = static_cast<float>(window_size.y) - vertical_padding - grid_size;]=])
string(FIND "${V15_WINUTIL}" "${V15_DPAD_TOP_OLD}" V15_DPAD_TOP_POS)
if(V15_DPAD_TOP_POS EQUAL -1)
    message(FATAL_ERROR "v15: expected centered d-pad top calculation not found")
endif()
string(REPLACE "${V15_DPAD_TOP_OLD}" "${V15_DPAD_TOP_NEW}" V15_WINUTIL "${V15_WINUTIL}")

# Grow the live minimap to use the same right-side column as the D-pad. Its
# left edge follows the D-pad panel, which leaves only the normal small layout
# gap between the map frame and the Stats/Inventory/Transcript stack. Reserve
# a slim lane on the map's right for the permanent MENU button.
set(V15_MINIMAP_OLD [=[sf::FloatRect android_map_mini_rect() {
    const sf::Vector2u size = mainPtr().getSize();
    float mini = static_cast<float>(size.y) * 0.26f;
    if(mini > 190.f) mini = 190.f;
    if(mini < 145.f) mini = 145.f;
    return {static_cast<float>(size.x) - mini - 20.f, 18.f, mini, mini};
}]=])
set(V15_MINIMAP_NEW [=[sf::FloatRect android_map_mini_rect() {
    const sf::Vector2u size = mainPtr().getSize();
    std::array<AndroidDpadButton, 8> dpad_buttons;
    sf::FloatRect dpad_panel;
    if(android_dpad_geometry(dpad_buttons, &dpad_panel)) {
        const float top = 14.f;
        const float menu_lane = 72.f;
        const float lane_gap = 8.f;
        const float width_limit = dpad_panel.width - menu_lane - lane_gap;
        const float height_limit = dpad_panel.top - top - 12.f;
        const float mini = std::min(width_limit, height_limit);
        if(mini >= 145.f)
            return {dpad_panel.left, top, mini, mini};
    }

    // Defensive fallback for unusually small/odd displays.
    float mini = static_cast<float>(size.y) * 0.26f;
    if(mini > 190.f) mini = 190.f;
    if(mini < 145.f) mini = 145.f;
    return {static_cast<float>(size.x) - mini - 20.f, 18.f, mini, mini};
}]=])
string(FIND "${V15_WINUTIL}" "${V15_MINIMAP_OLD}" V15_MINIMAP_POS)
if(V15_MINIMAP_POS EQUAL -1)
    message(FATAL_ERROR "v15: expected v12 minimap geometry function not found")
endif()
string(REPLACE "${V15_MINIMAP_OLD}" "${V15_MINIMAP_NEW}" V15_WINUTIL "${V15_WINUTIL}")

# Place MENU in the narrow lane beside the enlarged minimap. The 5x7 Android
# pixel font needs about 58 physical pixels for the four-letter label, so keep
# at least that much width when the display permits it.
set(V15_MENU_BUTTON_OLD [=[sf::FloatRect android_legacy_menu_button_rect() {
    const sf::Vector2u size = mainPtr().getSize();
    float mini = static_cast<float>(size.y) * 0.26f;
    if(mini > 190.f) mini = 190.f;
    if(mini < 145.f) mini = 145.f;
    const float width = 132.f;
    const float height = 58.f;
    const float right = static_cast<float>(size.x) - mini - 34.f;
    return {right - width, 18.f, width, height};
}]=])
set(V15_MENU_BUTTON_NEW [=[sf::FloatRect android_legacy_menu_button_rect() {
    std::array<AndroidDpadButton, 8> dpad_buttons;
    sf::FloatRect dpad_panel;
    if(android_dpad_geometry(dpad_buttons, &dpad_panel)) {
        const sf::FloatRect mini = android_map_mini_rect();
        const float gap = 8.f;
        const float left = mini.left + mini.width + gap;
        const float right = dpad_panel.left + dpad_panel.width;
        const float width = right - left;
        if(width >= 60.f)
            return {left, mini.top, width, 58.f};
    }

    const sf::Vector2u size = mainPtr().getSize();
    return {static_cast<float>(size.x) - 152.f, 18.f, 132.f, 58.f};
}]=])
string(FIND "${V15_WINUTIL}" "${V15_MENU_BUTTON_OLD}" V15_MENU_BUTTON_POS)
if(V15_MENU_BUTTON_POS EQUAL -1)
    message(FATAL_ERROR "v15: expected v13 MENU button geometry function not found")
endif()
string(REPLACE "${V15_MENU_BUTTON_OLD}" "${V15_MENU_BUTTON_NEW}" V15_WINUTIL "${V15_WINUTIL}")

file(WRITE "${CBOE_ANDROID_V15_WINUTIL_CPP}" "${V15_WINUTIL}")
message(STATUS "Applied Android Exploration UI v2 geometry (mobile UI v15)")
