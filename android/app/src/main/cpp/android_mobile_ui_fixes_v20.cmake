# Android ACT layout/icon polish v20.
# - Reorder immediate actions so COMBAT is deliberately far from the ACT toggle.
# - Widen the 3-column grid left toward the information column, move it slightly
#   upward, and use the available vertical gap for taller touch targets.
# - Give action labels their own text lane to the right of the toolbar icon.
# - Remove the enclosing ACT panel; the individual command buttons are enough.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V20_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V20_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V20_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V20_WINUTIL_CPP "${CBOE_ANDROID_UI_V20_ROOT}/src/tools/winutil.cpp")
file(READ "${CBOE_ANDROID_V20_WINUTIL_CPP}" V20_WINUTIL)

# Deliberately keep COMBAT on the top row, away from the lower-right ACT toggle.
# LOOK was omitted from the physical-test note, so retain it as the eighth command.
set(V20_ACTION_ORDER_OLD [=[constexpr std::array<int, 8> android_quick_visible_actions = {{
    ANDROID_QUICK_LOOK,
    ANDROID_QUICK_TALK,
    ANDROID_QUICK_MAGE,
    ANDROID_QUICK_PRIEST,
    ANDROID_QUICK_USE,
    ANDROID_QUICK_REST_WAIT,
    ANDROID_QUICK_GET,
    ANDROID_QUICK_COMBAT
}};]=])
set(V20_ACTION_ORDER_NEW [=[constexpr std::array<int, 8> android_quick_visible_actions = {{
    ANDROID_QUICK_COMBAT,
    ANDROID_QUICK_MAGE,
    ANDROID_QUICK_PRIEST,
    ANDROID_QUICK_REST_WAIT,
    ANDROID_QUICK_TALK,
    ANDROID_QUICK_USE,
    ANDROID_QUICK_GET,
    ANDROID_QUICK_LOOK
}};]=])
string(FIND "${V20_WINUTIL}" "${V20_ACTION_ORDER_OLD}" V20_ACTION_ORDER_POS)
if(V20_ACTION_ORDER_POS EQUAL -1)
    message(FATAL_ERROR "v20: expected v18 visible ACT action order not found")
endif()
string(REPLACE "${V20_ACTION_ORDER_OLD}" "${V20_ACTION_ORDER_NEW}" V20_WINUTIL "${V20_WINUTIL}")

# v19 correctly moved ACT into the minimap-to-D-pad gap, but used only the
# D-pad's width. On the tested phone there is useful blank space immediately to
# the right of the info stack. Use that space too and spend the full vertical
# gap on three slightly taller rows.
set(V20_QUICK_GEOM_OLD [=[bool android_quick_geometry(sf::FloatRect& toggle,
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
set(V20_QUICK_GEOM_NEW [=[bool android_quick_geometry(sf::FloatRect& toggle,
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
    const float col_gap = 6.f;
    const float row_gap = 5.f;
    float left = 0.f;
    float top = 0.f;
    float action_w = 0.f;
    float action_h = 0.f;
    float total_w = 0.f;
    float total_h = 0.f;

    sf::FloatRect region;
    AndroidMobileLayout layout;
    bool used_gap_region = false;
    if(android_action_controls_region(region) && android_mobile_layout(layout)) {
        const float info_right = layout.info_column.left + layout.info_column.width;
        const float desired_left = info_right + 10.f;
        const float desired_right = dpad_panel.left + dpad_panel.width;
        const float candidate_w = desired_right - desired_left;
        const float candidate_h = (region.height - row_gap * 2.f) / 3.f;
        if(candidate_w >= 270.f && candidate_h >= 32.f) {
            left = desired_left;
            total_w = candidate_w;
            action_w = (total_w - col_gap * 2.f) / 3.f;
            action_h = std::min(60.f, candidate_h);
            total_h = action_h * 3.f + row_gap * 2.f;
            // Bias upward rather than vertically centering; this gives the
            // minimap a small clean gap and keeps more air above the D-pad.
            top = region.top + std::max(0.f, (region.height - total_h) * 0.18f);
            used_gap_region = true;
        }
    }

    if(!used_gap_region) {
        action_w = std::min(138.f, std::max(96.f, static_cast<float>(window_size.y) * 0.14f));
        action_h = std::min(58.f, std::max(42.f, static_cast<float>(window_size.y) * 0.068f));
        total_w = action_w * 3.f + col_gap * 2.f;
        total_h = action_h * 3.f + row_gap * 2.f;
        const float right = dpad_panel.left + dpad_panel.width;
        left = std::max(8.f, right - total_w);
        sf::FloatRect fallback_region;
        if(android_action_controls_region(fallback_region))
            top = fallback_region.top + 1.f;
        else
            top = std::max(8.f, dpad_panel.top - total_h - 10.f);
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
        *popup_rect = sf::FloatRect(left, top, total_w, total_h);
    return true;
}]=])
string(FIND "${V20_WINUTIL}" "${V20_QUICK_GEOM_OLD}" V20_QUICK_GEOM_POS)
if(V20_QUICK_GEOM_POS EQUAL -1)
    message(FATAL_ERROR "v20: expected v19 ACT geometry not found")
endif()
string(REPLACE "${V20_QUICK_GEOM_OLD}" "${V20_QUICK_GEOM_NEW}" V20_WINUTIL "${V20_WINUTIL}")

# The generic button centres its text across the entire rectangle. That worked
# before icons were added, but now places letters directly over the icon. Keep
# the standard button style while reserving a left icon lane for ACT commands.
set(V20_DRAWABLE_ANCHOR [=[class AndroidQuickActionsDrawable : public iDrawable {]=])
set(V20_DRAWABLE_INSERT [=[void draw_android_quick_action_button(const sf::FloatRect& rect, int action,
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
    style.pointSize = 12;
    style.lineHeight = 14;
    style.colour = available ? sf::Color::White : sf::Color(130, 130, 136, 255);

    const float icon_lane = std::min(46.f, std::max(35.f, rect.height * 0.78f));
    rectangle label_rect {
        static_cast<int>(rect.top),
        static_cast<int>(rect.left + icon_lane),
        static_cast<int>(rect.top + rect.height),
        static_cast<int>(rect.left + rect.width - 3.f)
    };
    win_draw_string(mainPtr(), label_rect, android_quick_label(action),
                    eTextMode::CENTRE, style);
}

class AndroidQuickActionsDrawable : public iDrawable {]=])
string(FIND "${V20_WINUTIL}" "${V20_DRAWABLE_ANCHOR}" V20_DRAWABLE_POS)
if(V20_DRAWABLE_POS EQUAL -1)
    message(FATAL_ERROR "v20: expected ACT drawable class anchor not found")
endif()
string(REPLACE "${V20_DRAWABLE_ANCHOR}" "${V20_DRAWABLE_INSERT}" V20_WINUTIL "${V20_WINUTIL}")

# Drop the large enclosing panel entirely. Its empty third-row corners looked
# like stray black boxes; individual outlined command buttons are sufficient.
set(V20_PANEL_DRAW_OLD [=[        if(android_quick_menu_open && android_mobile_input_enabled()) {
            sf::RectangleShape panel({popup.width, popup.height});
            panel.setPosition(popup.left, popup.top);
            panel.setFillColor(sf::Color(8, 8, 12, 235));
            panel.setOutlineColor(sf::Color(220, 220, 220, 180));
            panel.setOutlineThickness(2.f);
            mainPtr().draw(panel);

            for(int action : android_quick_visible_actions) {
                const bool available = android_quick_available(action);
                draw_android_quick_button(actions[action], android_quick_label(action), available,
                                          android_quick_pressed == action);
                draw_android_quick_icon(actions[action], action, available);
            }
        }]=])
set(V20_PANEL_DRAW_NEW [=[        if(android_quick_menu_open && android_mobile_input_enabled()) {
            for(int action : android_quick_visible_actions) {
                const bool available = android_quick_available(action);
                draw_android_quick_action_button(actions[action], action, available,
                                                 android_quick_pressed == action);
            }
        }]=])
string(FIND "${V20_WINUTIL}" "${V20_PANEL_DRAW_OLD}" V20_PANEL_DRAW_POS)
if(V20_PANEL_DRAW_POS EQUAL -1)
    message(FATAL_ERROR "v20: expected v18 ACT panel draw block not found")
endif()
string(REPLACE "${V20_PANEL_DRAW_OLD}" "${V20_PANEL_DRAW_NEW}" V20_WINUTIL "${V20_WINUTIL}")

file(WRITE "${CBOE_ANDROID_V20_WINUTIL_CPP}" "${V20_WINUTIL}")
message(STATUS "Applied Android mobile UI v20 wider reordered ACT controls")
