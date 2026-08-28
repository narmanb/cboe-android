# Android ACT placement polish v19.
# - Use the real minimap-to-D-pad gap on phone layouts instead of falling back
#   leftward just because it is shorter than the old four-row requirement.
# - Arrange the eight immediate actions in a compact 3x3 footprint, with the
#   final two buttons centered on the third row.
# - Hide and disable the MENU button while ACT is open; it returns when ACT closes.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V19_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V19_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V19_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V19_WINUTIL_CPP "${CBOE_ANDROID_UI_V19_ROOT}/src/tools/winutil.cpp")
file(READ "${CBOE_ANDROID_V19_WINUTIL_CPP}" V19_WINUTIL)

# v18 required enough vertical room for a 2-column x 4-row panel plus MENU.
# MENU is now mutually exclusive with ACT, and three rows need much less space.
set(V19_REGION_OLD [=[    if(controls_bottom - controls_top < 190.f)
        return false;]=])
set(V19_REGION_NEW [=[    if(controls_bottom - controls_top < 108.f)
        return false;]=])
string(FIND "${V19_WINUTIL}" "${V19_REGION_OLD}" V19_REGION_POS)
if(V19_REGION_POS EQUAL -1)
    message(FATAL_ERROR "v19: expected v18 action-region height guard not found")
endif()
string(REPLACE "${V19_REGION_OLD}" "${V19_REGION_NEW}" V19_WINUTIL "${V19_WINUTIL}")

# Replace the v18 2x4 layout with a 3-column footprint in the actual control gap.
# The first six actions fill two rows; GET and COMBAT are centered on row three.
set(V19_QUICK_GEOM_OLD [=[bool android_quick_geometry(sf::FloatRect& toggle,
                            std::array<sf::FloatRect, ANDROID_QUICK_COUNT>& actions,
                            sf::FloatRect* popup_rect = nullptr) {
    if(!android_mobile_ui_visible())
        return false;

    std::array<AndroidDpadButton, 8> dpad_buttons;
    sf::FloatRect dpad_panel;
    if(!android_dpad_geometry(dpad_buttons, &dpad_panel))
        return false;

    const float button_size = dpad_buttons[0].rect.width;
    const float dpad_gap = dpad_buttons[1].rect.left -
        (dpad_buttons[0].rect.left + dpad_buttons[0].rect.width);
    const float toggle_size = button_size * 0.64f;
    const float toggle_inset = (button_size - toggle_size) * 0.5f;
    toggle = sf::FloatRect(
        dpad_buttons[0].rect.left + button_size + dpad_gap + toggle_inset,
        dpad_buttons[0].rect.top + button_size + dpad_gap + toggle_inset,
        toggle_size,
        toggle_size
    );

    for(auto& rect : actions)
        rect = sf::FloatRect();

    const sf::Vector2u window_size = mainPtr().getSize();
    const float col_gap = 8.f;
    const float row_gap = 6.f;
    float left = 0.f;
    float top = 0.f;
    float action_w = 0.f;
    float action_h = 0.f;
    float total_w = 0.f;
    float total_h = 0.f;

    sf::FloatRect region;
    bool used_gap_region = false;
    if(android_action_controls_region(region)) {
        const float menu_gap = 10.f;
        const float grid_space = region.height - android_action_menu_height() - menu_gap;
        const float candidate_h = (grid_space - row_gap * 3.f) / 4.f;
        if(candidate_h >= 34.f) {
            action_h = std::min(62.f, candidate_h);
            total_h = action_h * 4.f + row_gap * 3.f;
            total_w = region.width;
            action_w = (total_w - col_gap) * 0.5f;
            left = region.left;
            top = region.top + std::max(0.f, (grid_space - total_h) * 0.5f);
            used_gap_region = true;
        }
    }

    if(!used_gap_region) {
        action_w = std::min(132.f, std::max(96.f, static_cast<float>(window_size.y) * 0.14f));
        action_h = std::min(58.f, std::max(42.f, static_cast<float>(window_size.y) * 0.07f));
        total_w = action_w * 2.f + col_gap;
        total_h = action_h * 4.f + row_gap * 3.f;
        const float right = dpad_panel.left - 10.f;
        left = std::max(8.f, right - total_w);
        top = std::max(8.f, (static_cast<float>(window_size.y) - total_h) * 0.5f);
    }

    for(int slot = 0; slot < static_cast<int>(android_quick_visible_actions.size()); ++slot) {
        const int action = android_quick_visible_actions[slot];
        const int row = slot / 2;
        const int col = slot % 2;
        actions[action] = sf::FloatRect(
            left + col * (action_w + col_gap),
            top + row * (action_h + row_gap),
            action_w,
            action_h
        );
    }

    if(popup_rect)
        *popup_rect = sf::FloatRect(left - 6.f, top - 6.f, total_w + 12.f, total_h + 12.f);
    return true;
}]=])
set(V19_QUICK_GEOM_NEW [=[bool android_quick_geometry(sf::FloatRect& toggle,
                            std::array<sf::FloatRect, ANDROID_QUICK_COUNT>& actions,
                            sf::FloatRect* popup_rect = nullptr) {
    if(!android_mobile_ui_visible())
        return false;

    std::array<AndroidDpadButton, 8> dpad_buttons;
    sf::FloatRect dpad_panel;
    if(!android_dpad_geometry(dpad_buttons, &dpad_panel))
        return false;

    const float button_size = dpad_buttons[0].rect.width;
    const float dpad_gap = dpad_buttons[1].rect.left -
        (dpad_buttons[0].rect.left + dpad_buttons[0].rect.width);
    const float toggle_size = button_size * 0.64f;
    const float toggle_inset = (button_size - toggle_size) * 0.5f;
    toggle = sf::FloatRect(
        dpad_buttons[0].rect.left + button_size + dpad_gap + toggle_inset,
        dpad_buttons[0].rect.top + button_size + dpad_gap + toggle_inset,
        toggle_size,
        toggle_size
    );

    for(auto& rect : actions)
        rect = sf::FloatRect();

    const sf::Vector2u window_size = mainPtr().getSize();
    const float col_gap = 7.f;
    const float row_gap = 6.f;
    float left = 0.f;
    float top = 0.f;
    float action_w = 0.f;
    float action_h = 0.f;
    float total_w = 0.f;
    float total_h = 0.f;

    sf::FloatRect region;
    bool used_gap_region = false;
    if(android_action_controls_region(region)) {
        const float candidate_h = (region.height - row_gap * 2.f) / 3.f;
        if(candidate_h >= 30.f) {
            action_h = std::min(58.f, candidate_h);
            total_h = action_h * 3.f + row_gap * 2.f;
            total_w = region.width;
            action_w = (total_w - col_gap * 2.f) / 3.f;
            left = region.left;
            top = region.top + std::max(0.f, (region.height - total_h) * 0.5f);
            used_gap_region = true;
        }
    }

    if(!used_gap_region) {
        action_w = std::min(124.f, std::max(86.f, static_cast<float>(window_size.y) * 0.125f));
        action_h = std::min(54.f, std::max(38.f, static_cast<float>(window_size.y) * 0.062f));
        total_w = action_w * 3.f + col_gap * 2.f;
        total_h = action_h * 3.f + row_gap * 2.f;
        const float right = dpad_panel.left - 10.f;
        left = std::max(8.f, right - total_w);
        top = std::max(8.f, (static_cast<float>(window_size.y) - total_h) * 0.5f);
    }

    const int visible_count = static_cast<int>(android_quick_visible_actions.size());
    for(int slot = 0; slot < visible_count; ++slot) {
        const int action = android_quick_visible_actions[slot];
        const int row = slot / 3;
        float x = left;
        if(row < 2) {
            const int col = slot % 3;
            x += static_cast<float>(col) * (action_w + col_gap);
        } else {
            const int last_col = slot - 6;
            const float pair_w = action_w * 2.f + col_gap;
            x += (total_w - pair_w) * 0.5f + static_cast<float>(last_col) * (action_w + col_gap);
        }
        actions[action] = sf::FloatRect(
            x,
            top + static_cast<float>(row) * (action_h + row_gap),
            action_w,
            action_h
        );
    }

    if(popup_rect)
        *popup_rect = sf::FloatRect(left - 6.f, top - 6.f, total_w + 12.f, total_h + 12.f);
    return true;
}]=])
string(FIND "${V19_WINUTIL}" "${V19_QUICK_GEOM_OLD}" V19_QUICK_GEOM_POS)
if(V19_QUICK_GEOM_POS EQUAL -1)
    message(FATAL_ERROR "v19: expected v18 ACT geometry not found")
endif()
string(REPLACE "${V19_QUICK_GEOM_OLD}" "${V19_QUICK_GEOM_NEW}" V19_WINUTIL "${V19_WINUTIL}")

# When ACT is expanded the regular MENU button is intentionally absent, so it
# must not retain an invisible hit target over the action buttons.
set(V19_MENU_HIT_OLD [=[    if(!android_legacy_menu_open)
        return android_legacy_menu_button_rect().contains(fx, fy) ? ANDROID_MENU_TOGGLE : ANDROID_MENU_NONE;]=])
set(V19_MENU_HIT_NEW [=[    if(!android_legacy_menu_open) {
        if(android_quick_menu_open)
            return ANDROID_MENU_NONE;
        return android_legacy_menu_button_rect().contains(fx, fy) ? ANDROID_MENU_TOGGLE : ANDROID_MENU_NONE;
    }]=])
string(FIND "${V19_WINUTIL}" "${V19_MENU_HIT_OLD}" V19_MENU_HIT_POS)
if(V19_MENU_HIT_POS EQUAL -1)
    message(FATAL_ERROR "v19: expected Android MENU closed-state hit test not found")
endif()
string(REPLACE "${V19_MENU_HIT_OLD}" "${V19_MENU_HIT_NEW}" V19_WINUTIL "${V19_WINUTIL}")

# Match the hit test visually: MENU disappears as soon as ACT opens and returns
# automatically when ACT closes.
set(V19_MENU_DRAW_OLD [=[    void draw() override {
        if(cDialog::anyOpen() || android_map_overlay_visible)
            return;

        const sf::View previous_view = mainPtr().getView();]=])
set(V19_MENU_DRAW_NEW [=[    void draw() override {
        if(cDialog::anyOpen() || android_map_overlay_visible)
            return;
        if(!android_legacy_menu_open && android_quick_menu_open)
            return;

        const sf::View previous_view = mainPtr().getView();]=])
string(FIND "${V19_WINUTIL}" "${V19_MENU_DRAW_OLD}" V19_MENU_DRAW_POS)
if(V19_MENU_DRAW_POS EQUAL -1)
    message(FATAL_ERROR "v19: expected Android MENU drawable guard not found")
endif()
string(REPLACE "${V19_MENU_DRAW_OLD}" "${V19_MENU_DRAW_NEW}" V19_WINUTIL "${V19_WINUTIL}")

file(WRITE "${CBOE_ANDROID_V19_WINUTIL_CPP}" "${V19_WINUTIL}")
message(STATUS "Applied Android mobile UI v19 ACT placement and MENU exclusivity")
