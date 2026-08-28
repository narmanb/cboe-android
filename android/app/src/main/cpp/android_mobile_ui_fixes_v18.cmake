# Android exploration controls v18.
# - Keep ACT as a persistent toggle instead of a modal popup.
# - Show only the eight immediate world actions in a compact 2x4 grid.
# - Reuse the original OpenBoE buttons.png toolbar artwork beside short labels.
# - Move/enlarge MENU into the control gap above the D-pad.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V18_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V18_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V18_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V18_WINUTIL_CPP "${CBOE_ANDROID_UI_V18_ROOT}/src/tools/winutil.cpp")
file(READ "${CBOE_ANDROID_V18_WINUTIL_CPP}" V18_WINUTIL)

# Resource manager only; avoid pulling broad game headers into winutil.cpp.
set(V18_INCLUDE_OLD [=[#include "game/boe.actions.hpp"
#include "game/boe.menus.hpp"
#include "gfx/render_text.hpp"
#include "dialogxml/dialogs/dialog.hpp"]=])
set(V18_INCLUDE_NEW [=[#include "game/boe.actions.hpp"
#include "game/boe.menus.hpp"
#include "gfx/render_text.hpp"
#include "fileio/resmgr/res_image.hpp"
#include "dialogxml/dialogs/dialog.hpp"]=])
string(FIND "${V18_WINUTIL}" "${V18_INCLUDE_OLD}" V18_INCLUDE_POS)
if(V18_INCLUDE_POS EQUAL -1)
    message(FATAL_ERROR "v18: expected Android safe include block not found")
endif()
string(REPLACE "${V18_INCLUDE_OLD}" "${V18_INCLUDE_NEW}" V18_WINUTIL "${V18_WINUTIL}")

# Shared vertical region between the enlarged minimap and lower-right D-pad.
# This duplicates the v16 minimap size calculation deliberately so this helper
# can live before both the MENU and ACT class definitions without new ordering
# dependencies.
set(V18_MENU_ENUM_ANCHOR [=[enum AndroidLegacyMenuPage {]=])
set(V18_MENU_ENUM_INSERT [=[bool android_action_controls_region(sf::FloatRect& region) {
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
}

float android_action_menu_height() {
    const float h = static_cast<float>(mainPtr().getSize().y) * 0.07f;
    return std::min(82.f, std::max(68.f, h));
}

enum AndroidLegacyMenuPage {]=])
string(FIND "${V18_WINUTIL}" "${V18_MENU_ENUM_ANCHOR}" V18_MENU_ENUM_POS)
if(V18_MENU_ENUM_POS EQUAL -1)
    message(FATAL_ERROR "v18: expected Android legacy menu enum anchor not found")
endif()
string(REPLACE "${V18_MENU_ENUM_ANCHOR}" "${V18_MENU_ENUM_INSERT}" V18_WINUTIL "${V18_WINUTIL}")

# Replace the narrow 60px lane button with a large centered phone target below
# the ACT grid and above the D-pad. Preserve a fallback for unusual displays.
set(V18_MENU_RECT_OLD [=[sf::FloatRect android_legacy_menu_button_rect() {
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
set(V18_MENU_RECT_NEW [=[sf::FloatRect android_legacy_menu_button_rect() {
    sf::FloatRect region;
    if(android_action_controls_region(region)) {
        const float height = android_action_menu_height();
        const float width = std::min(region.width, std::max(160.f, region.width * 0.62f));
        return {region.left + (region.width - width) * 0.5f,
                region.top + region.height - height,
                width, height};
    }

    const sf::Vector2u size = mainPtr().getSize();
    return {static_cast<float>(size.x) - 210.f, 24.f, 180.f, 72.f};
}]=])
string(FIND "${V18_WINUTIL}" "${V18_MENU_RECT_OLD}" V18_MENU_RECT_POS)
if(V18_MENU_RECT_POS EQUAL -1)
    message(FATAL_ERROR "v18: expected v15 MENU geometry not found")
endif()
string(REPLACE "${V18_MENU_RECT_OLD}" "${V18_MENU_RECT_NEW}" V18_WINUTIL "${V18_WINUTIL}")

# Opening MENU should pause/capture gameplay input but must not destroy the
# player's ACT-open preference. The centered menu already captures all presses.
set(V18_MENU_OPEN_OLD [=[        android_legacy_menu_open = true;
        android_legacy_menu_page = ANDROID_MENU_ROOT;
        android_quick_menu_open = false;
        android_end_dpad_hold();]=])
set(V18_MENU_OPEN_NEW [=[        android_legacy_menu_open = true;
        android_legacy_menu_page = ANDROID_MENU_ROOT;
        android_end_dpad_hold();]=])
string(FIND "${V18_WINUTIL}" "${V18_MENU_OPEN_OLD}" V18_MENU_OPEN_POS)
if(V18_MENU_OPEN_POS EQUAL -1)
    message(FATAL_ERROR "v18: expected MENU-open quick-menu reset not found")
endif()
string(REPLACE "${V18_MENU_OPEN_OLD}" "${V18_MENU_OPEN_NEW}" V18_WINUTIL "${V18_WINUTIL}")

# Keep the existing engine enum/handlers intact for low risk, but expose only
# the eight immediate-world commands requested for the mobile ACT panel.
set(V18_QUICK_STATE_OLD [=[bool android_quick_menu_open = false;
int android_quick_pressed = ANDROID_QUICK_NONE;]=])
set(V18_QUICK_STATE_NEW [=[constexpr std::array<int, 8> android_quick_visible_actions = {{
    ANDROID_QUICK_LOOK,
    ANDROID_QUICK_TALK,
    ANDROID_QUICK_MAGE,
    ANDROID_QUICK_PRIEST,
    ANDROID_QUICK_USE,
    ANDROID_QUICK_REST_WAIT,
    ANDROID_QUICK_GET,
    ANDROID_QUICK_COMBAT
}};

bool android_quick_menu_open = false;
int android_quick_pressed = ANDROID_QUICK_NONE;]=])
string(FIND "${V18_WINUTIL}" "${V18_QUICK_STATE_OLD}" V18_QUICK_STATE_POS)
if(V18_QUICK_STATE_POS EQUAL -1)
    message(FATAL_ERROR "v18: expected quick-action state block not found")
endif()
string(REPLACE "${V18_QUICK_STATE_OLD}" "${V18_QUICK_STATE_NEW}" V18_WINUTIL "${V18_WINUTIL}")

# Re-layout the eight visible commands as a true 2-column x 4-row grid inside
# the vertical gap. Non-visible enum members retain empty hit rectangles.
set(V18_QUICK_GEOM_OLD [=[bool android_quick_geometry(sf::FloatRect& toggle,
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

    const sf::Vector2u window_size = mainPtr().getSize();
    const float gap = 8.f;
    float action_w = std::min(132.f, std::max(96.f, static_cast<float>(window_size.y) * 0.14f));
    float action_h = std::min(60.f, std::max(44.f, static_cast<float>(window_size.y) * 0.072f));
    const float total_w = action_w * 2.f + gap;
    const int action_rows = (ANDROID_QUICK_COUNT + 1) / 2;
    const float total_h = action_h * static_cast<float>(action_rows) +
                          gap * static_cast<float>(action_rows - 1);
    float right = dpad_panel.left - 10.f;
    float left = right - total_w;
    if(left < 8.f)
        left = 8.f;
    float top = (static_cast<float>(window_size.y) - total_h) * 0.5f;
    if(top < 8.f)
        top = 8.f;

    for(int i = 0; i < ANDROID_QUICK_COUNT; ++i) {
        const int row = i / 2;
        const int col = i % 2;
        actions[i] = sf::FloatRect(
            left + col * (action_w + gap),
            top + row * (action_h + gap),
            action_w,
            action_h
        );
    }

    if(popup_rect)
        *popup_rect = sf::FloatRect(left - 8.f, top - 8.f, total_w + 16.f, total_h + 16.f);
    return true;
}]=])
set(V18_QUICK_GEOM_NEW [=[bool android_quick_geometry(sf::FloatRect& toggle,
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
string(FIND "${V18_WINUTIL}" "${V18_QUICK_GEOM_OLD}" V18_QUICK_GEOM_POS)
if(V18_QUICK_GEOM_POS EQUAL -1)
    message(FATAL_ERROR "v18: expected final v10/v13 ACT geometry not found")
endif()
string(REPLACE "${V18_QUICK_GEOM_OLD}" "${V18_QUICK_GEOM_NEW}" V18_WINUTIL "${V18_WINUTIL}")

# Mobile labels: the requested command is WAIT, and SWORD is now COMBAT.
set(V18_WAIT_LABEL_OLD [=[            return overall_mode == MODE_OUTDOORS ? "CAMP" : "WAIT";]=])
set(V18_WAIT_LABEL_NEW [=[            return "WAIT";]=])
string(FIND "${V18_WINUTIL}" "${V18_WAIT_LABEL_OLD}" V18_WAIT_LABEL_POS)
if(V18_WAIT_LABEL_POS EQUAL -1)
    message(FATAL_ERROR "v18: expected CAMP/WAIT label not found")
endif()
string(REPLACE "${V18_WAIT_LABEL_OLD}" "${V18_WAIT_LABEL_NEW}" V18_WINUTIL "${V18_WINUTIL}")

set(V18_COMBAT_LABEL_OLD [=[        case ANDROID_QUICK_COMBAT: return "SWORD";]=])
set(V18_COMBAT_LABEL_NEW [=[        case ANDROID_QUICK_COMBAT: return "COMBAT";]=])
string(FIND "${V18_WINUTIL}" "${V18_COMBAT_LABEL_OLD}" V18_COMBAT_LABEL_POS)
if(V18_COMBAT_LABEL_POS EQUAL -1)
    message(FATAL_ERROR "v18: expected SWORD label not found")
endif()
string(REPLACE "${V18_COMBAT_LABEL_OLD}" "${V18_COMBAT_LABEL_NEW}" V18_WINUTIL "${V18_WINUTIL}")

# Only the eight requested actions participate in ACT hit testing.
set(V18_HIT_LOOP_OLD [=[    if(android_quick_menu_open) {
        for(int i = 0; i < ANDROID_QUICK_COUNT; ++i)
            if(actions[i].contains(fx, fy))
                return i;
    }]=])
set(V18_HIT_LOOP_NEW [=[    if(android_quick_menu_open) {
        for(int action : android_quick_visible_actions)
            if(actions[action].contains(fx, fy))
                return action;
    }]=])
string(FIND "${V18_WINUTIL}" "${V18_HIT_LOOP_OLD}" V18_HIT_LOOP_POS)
if(V18_HIT_LOOP_POS EQUAL -1)
    message(FATAL_ERROR "v18: expected quick-action hit loop not found")
endif()
string(REPLACE "${V18_HIT_LOOP_OLD}" "${V18_HIT_LOOP_NEW}" V18_WINUTIL "${V18_WINUTIL}")

# Draw authentic toolbar icons from buttons.png. Values here are the original
# eToolbarButton slots, intentionally kept local so boe.ui.hpp is not included.
set(V18_QUICK_CLASS_ANCHOR [=[class AndroidQuickActionsDrawable : public iDrawable {]=])
set(V18_QUICK_CLASS_INSERT [=[int android_quick_toolbar_slot(int action) {
    switch(action) {
        case ANDROID_QUICK_MAGE: return 0;
        case ANDROID_QUICK_PRIEST: return 1;
        case ANDROID_QUICK_LOOK: return 2;
        case ANDROID_QUICK_TALK: return 8;
        case ANDROID_QUICK_USE: return 16;
        case ANDROID_QUICK_REST_WAIT: return 12;
        case ANDROID_QUICK_GET: return 7;
        case ANDROID_QUICK_COMBAT: return 10;
        default: return -1;
    }
}

void draw_android_quick_icon(const sf::FloatRect& rect, int action, bool available) {
    if(rect.width < 118.f || rect.height < 34.f)
        return;
    const int slot = android_quick_toolbar_slot(action);
    if(slot < 0)
        return;

    sf::Texture& buttons = *ResMgr::graphics.get("buttons");
    const int col = slot % 6;
    const int row = slot / 6;
    const int source_h = row == 2 ? 16 : 32;
    sf::Sprite sprite(buttons);
    sprite.setTextureRect(sf::IntRect(col * 32, 38 + row * 32, 32, source_h));

    const float target_w = std::min(30.f, rect.height * 0.48f);
    const float scale = target_w / 32.f;
    const float target_h = static_cast<float>(source_h) * scale;
    sprite.setScale(scale, scale);
    sprite.setPosition(rect.left + 9.f, rect.top + (rect.height - target_h) * 0.5f);
    if(!available)
        sprite.setColor(sf::Color(125,125,130,210));
    mainPtr().draw(sprite);
}

class AndroidQuickActionsDrawable : public iDrawable {]=])
string(FIND "${V18_WINUTIL}" "${V18_QUICK_CLASS_ANCHOR}" V18_QUICK_CLASS_POS)
if(V18_QUICK_CLASS_POS EQUAL -1)
    message(FATAL_ERROR "v18: expected quick-action drawable class anchor not found")
endif()
string(REPLACE "${V18_QUICK_CLASS_ANCHOR}" "${V18_QUICK_CLASS_INSERT}" V18_WINUTIL "${V18_WINUTIL}")

set(V18_DRAW_LOOP_OLD [=[            for(int i = 0; i < ANDROID_QUICK_COUNT; ++i) {
                draw_android_quick_button(actions[i], android_quick_label(i), android_quick_available(i),
                                          android_quick_pressed == i);
            }]=])
set(V18_DRAW_LOOP_NEW [=[            for(int action : android_quick_visible_actions) {
                const bool available = android_quick_available(action);
                draw_android_quick_button(actions[action], android_quick_label(action), available,
                                          android_quick_pressed == action);
                draw_android_quick_icon(actions[action], action, available);
            }]=])
string(FIND "${V18_WINUTIL}" "${V18_DRAW_LOOP_OLD}" V18_DRAW_LOOP_POS)
if(V18_DRAW_LOOP_POS EQUAL -1)
    message(FATAL_ERROR "v18: expected quick-action draw loop not found")
endif()
string(REPLACE "${V18_DRAW_LOOP_OLD}" "${V18_DRAW_LOOP_NEW}" V18_WINUTIL "${V18_WINUTIL}")

# ACT now stays open during movement and ordinary gameplay taps. Only tapping
# ACT itself toggles it. This turns the panel into a persistent command bar.
set(V18_DPAD_CLOSE_OLD [=[                if(&win == &mainPtr() && event.mouseButton.button == sf::Mouse::Left &&
                   android_dpad_keys_at(x, y, primary, secondary)) {
                    android_quick_menu_open = false;
                    android_begin_dpad_hold(primary, secondary);]=])
set(V18_DPAD_CLOSE_NEW [=[                if(&win == &mainPtr() && event.mouseButton.button == sf::Mouse::Left &&
                   android_dpad_keys_at(x, y, primary, secondary)) {
                    android_begin_dpad_hold(primary, secondary);]=])
string(FIND "${V18_WINUTIL}" "${V18_DPAD_CLOSE_OLD}" V18_DPAD_CLOSE_POS)
if(V18_DPAD_CLOSE_POS EQUAL -1)
    message(FATAL_ERROR "v18: expected v12 d-pad quick-menu close not found")
endif()
string(REPLACE "${V18_DPAD_CLOSE_OLD}" "${V18_DPAD_CLOSE_NEW}" V18_WINUTIL "${V18_WINUTIL}")

set(V18_OUTSIDE_DISMISS [=[                if(&win == &mainPtr() && android_quick_menu_open) {
                    android_quick_menu_open = false;
                    android_quick_pressed = ANDROID_QUICK_DISMISS;
                    event.type = sf::Event::Count;
                    break;
                }
]=])
string(FIND "${V18_WINUTIL}" "${V18_OUTSIDE_DISMISS}" V18_OUTSIDE_DISMISS_POS)
if(V18_OUTSIDE_DISMISS_POS EQUAL -1)
    message(FATAL_ERROR "v18: expected ACT outside-dismiss block not found")
endif()
string(REPLACE "${V18_OUTSIDE_DISMISS}" "" V18_WINUTIL "${V18_WINUTIL}")

set(V18_ACTION_CLOSE_OLD [=[                        } else if(pressed >= 0 && pressed < ANDROID_QUICK_COUNT) {
                            android_quick_menu_open = false;
                            if(android_quick_available(pressed))]=])
set(V18_ACTION_CLOSE_NEW [=[                        } else if(pressed >= 0 && pressed < ANDROID_QUICK_COUNT) {
                            if(android_quick_available(pressed))]=])
string(FIND "${V18_WINUTIL}" "${V18_ACTION_CLOSE_OLD}" V18_ACTION_CLOSE_POS)
if(V18_ACTION_CLOSE_POS EQUAL -1)
    message(FATAL_ERROR "v18: expected ACT post-action close not found")
endif()
string(REPLACE "${V18_ACTION_CLOSE_OLD}" "${V18_ACTION_CLOSE_NEW}" V18_WINUTIL "${V18_WINUTIL}")

file(WRITE "${CBOE_ANDROID_V18_WINUTIL_CPP}" "${V18_WINUTIL}")
message(STATUS "Applied Android mobile UI v18 persistent icon ACT grid and larger MENU")
