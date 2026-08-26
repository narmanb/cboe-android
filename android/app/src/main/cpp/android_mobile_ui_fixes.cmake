# Android gameplay UI/input fixes applied to the portable source at configure time.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_WINUTIL_CPP "${CBOE_ANDROID_UI_ROOT}/src/tools/winutil.cpp")
file(READ "${CBOE_ANDROID_WINUTIL_CPP}" CBOE_ANDROID_WINUTIL_SOURCE)

# The separated Android panels contain scale-aware text that OpenBoE normally
# draws separately from each RenderTexture. The first mobile shell copied only
# the texture pixels, leaving stats/inventory/transcript text behind.
set(CBOE_ANDROID_UI_INCLUDE_OLD [=[#include <deque>
#include <memory>
#include <SFML/Graphics/ConvexShape.hpp>]=])
set(CBOE_ANDROID_UI_INCLUDE_NEW [=[#include <deque>
#include <map>
#include <memory>
#include <vector>
#include <SFML/Graphics/ConvexShape.hpp>]=])
string(FIND "${CBOE_ANDROID_WINUTIL_SOURCE}" "${CBOE_ANDROID_UI_INCLUDE_OLD}" CBOE_ANDROID_UI_INCLUDE_POS)
if(CBOE_ANDROID_UI_INCLUDE_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android winutil STL include block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_UI_INCLUDE_OLD}" "${CBOE_ANDROID_UI_INCLUDE_NEW}" CBOE_ANDROID_WINUTIL_SOURCE "${CBOE_ANDROID_WINUTIL_SOURCE}")

set(CBOE_ANDROID_UI_GAME_INCLUDE_OLD [=[#include "game/boe.consts.hpp"
#include "drawable_manager.hpp"]=])
set(CBOE_ANDROID_UI_GAME_INCLUDE_NEW [=[#include "game/boe.consts.hpp"
#include "game/boe.actions.hpp"
#include "gfx/render_text.hpp"
#include "drawable_manager.hpp"]=])
string(FIND "${CBOE_ANDROID_WINUTIL_SOURCE}" "${CBOE_ANDROID_UI_GAME_INCLUDE_OLD}" CBOE_ANDROID_UI_GAME_INCLUDE_POS)
if(CBOE_ANDROID_UI_GAME_INCLUDE_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android winutil game include block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_UI_GAME_INCLUDE_OLD}" "${CBOE_ANDROID_UI_GAME_INCLUDE_NEW}" CBOE_ANDROID_WINUTIL_SOURCE "${CBOE_ANDROID_WINUTIL_SOURCE}")

set(CBOE_ANDROID_UI_EXTERN_OLD [=[extern sf::RenderTexture& text_area_gworld();]=])
set(CBOE_ANDROID_UI_EXTERN_NEW [=[extern sf::RenderTexture& text_area_gworld();
extern std::map<sf::RenderTexture*,std::vector<ScaleAwareText>> store_scale_aware_text;]=])
string(FIND "${CBOE_ANDROID_WINUTIL_SOURCE}" "${CBOE_ANDROID_UI_EXTERN_OLD}" CBOE_ANDROID_UI_EXTERN_POS)
if(CBOE_ANDROID_UI_EXTERN_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android winutil RenderTexture extern block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_UI_EXTERN_OLD}" "${CBOE_ANDROID_UI_EXTERN_NEW}" CBOE_ANDROID_WINUTIL_SOURCE "${CBOE_ANDROID_WINUTIL_SOURCE}")

# Leave a real safe area at the right edge even when immersive mode is active.
# This also keeps the pad away from Samsung's transient system-navigation target.
set(CBOE_ANDROID_DPAD_PADDING_OLD "    const float right_padding = 44.f;")
set(CBOE_ANDROID_DPAD_PADDING_NEW "    const float right_padding = 128.f;")
string(FIND "${CBOE_ANDROID_WINUTIL_SOURCE}" "${CBOE_ANDROID_DPAD_PADDING_OLD}" CBOE_ANDROID_DPAD_PADDING_POS)
if(CBOE_ANDROID_DPAD_PADDING_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android d-pad right padding was not found")
endif()
string(REPLACE "${CBOE_ANDROID_DPAD_PADDING_OLD}" "${CBOE_ANDROID_DPAD_PADDING_NEW}" CBOE_ANDROID_WINUTIL_SOURCE "${CBOE_ANDROID_WINUTIL_SOURCE}")

# Align the information stack directly against the full-height world panel and
# give all three panels one coherent width while preserving their native ratios.
set(CBOE_ANDROID_LAYOUT_GAP_OLD "    const float gap = 12.f;")
set(CBOE_ANDROID_LAYOUT_GAP_NEW "    const float gap = 6.f;")
string(FIND "${CBOE_ANDROID_WINUTIL_SOURCE}" "${CBOE_ANDROID_LAYOUT_GAP_OLD}" CBOE_ANDROID_LAYOUT_GAP_POS)
if(CBOE_ANDROID_LAYOUT_GAP_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android mobile-layout gap was not found")
endif()
string(REPLACE "${CBOE_ANDROID_LAYOUT_GAP_OLD}" "${CBOE_ANDROID_LAYOUT_GAP_NEW}" CBOE_ANDROID_WINUTIL_SOURCE "${CBOE_ANDROID_WINUTIL_SOURCE}")

set(CBOE_ANDROID_INFO_LAYOUT_OLD [=[    const float info_bottom = h - margin;
    const float info_height = info_bottom - margin;
    const float stats_h = info_height * 0.24f;
    const float inventory_h = info_height * 0.36f;
    const float transcript_h = info_height - stats_h - inventory_h - gap * 2.f;

    const sf::FloatRect stats_bounds(info_left, margin, info_width, stats_h);
    const sf::FloatRect inventory_bounds(info_left, stats_bounds.top + stats_bounds.height + gap,
                                         info_width, inventory_h);
    const sf::FloatRect transcript_bounds(info_left, inventory_bounds.top + inventory_bounds.height + gap,
                                          info_width, transcript_h);

    // These are the legacy logical rectangles from boe.ui.cpp. Touches on the
    // new panels are translated back into these coordinates so existing game
    // interaction code remains unchanged.
    layout.terrain = {fit_inside(terrain_bounds, 279.f, 351.f), {19.f, 7.f, 279.f, 351.f}};
    layout.stats = {fit_inside(stats_bounds, 271.f, 116.f), {305.f, 7.f, 271.f, 116.f}};
    layout.inventory = {fit_inside(inventory_bounds, 271.f, 144.f), {305.f, 132.f, 271.f, 144.f}};
    layout.transcript = {fit_inside(transcript_bounds, 256.f, 138.f), {305.f, 285.f, 256.f, 138.f}};
    layout.info_column = {info_left, margin, info_width, info_height};]=])
set(CBOE_ANDROID_INFO_LAYOUT_NEW [=[    const float info_bottom = h - margin;
    const float info_height = info_bottom - margin;
    const float native_stack_ratio = (116.f / 271.f) + (144.f / 271.f) + (138.f / 256.f);
    const float max_panel_width_for_height = (info_height - gap * 2.f) / native_stack_ratio;
    const float panel_width = std::min(info_width, max_panel_width_for_height);
    if(panel_width < 240.f)
        return false;

    float panel_top = margin;
    const sf::FloatRect stats_screen(info_left, panel_top, panel_width,
                                     panel_width * (116.f / 271.f));
    panel_top += stats_screen.height + gap;
    const sf::FloatRect inventory_screen(info_left, panel_top, panel_width,
                                         panel_width * (144.f / 271.f));
    panel_top += inventory_screen.height + gap;
    const sf::FloatRect transcript_screen(info_left, panel_top, panel_width,
                                          panel_width * (138.f / 256.f));

    // These are the legacy logical rectangles from boe.ui.cpp. Touches on the
    // new panels are translated back into these coordinates so existing game
    // interaction code remains unchanged.
    layout.terrain = {fit_inside(terrain_bounds, 279.f, 351.f), {19.f, 7.f, 279.f, 351.f}};
    layout.stats = {stats_screen, {305.f, 7.f, 271.f, 116.f}};
    layout.inventory = {inventory_screen, {305.f, 132.f, 271.f, 144.f}};
    layout.transcript = {transcript_screen, {305.f, 285.f, 256.f, 138.f}};
    layout.info_column = {info_left, margin, panel_width, info_height};]=])
string(FIND "${CBOE_ANDROID_WINUTIL_SOURCE}" "${CBOE_ANDROID_INFO_LAYOUT_OLD}" CBOE_ANDROID_INFO_LAYOUT_POS)
if(CBOE_ANDROID_INFO_LAYOUT_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android separated-panel layout block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_INFO_LAYOUT_OLD}" "${CBOE_ANDROID_INFO_LAYOUT_NEW}" CBOE_ANDROID_WINUTIL_SOURCE "${CBOE_ANDROID_WINUTIL_SOURCE}")

# Render the scale-aware text OpenBoE stores beside each RenderTexture. Stored
# glyph sizes already include the desktop UI scale, so compensate for it before
# scaling into the physical Android panel.
set(CBOE_ANDROID_DRAW_PANEL_OLD [=[void draw_panel_texture(const sf::RenderTexture& texture, const sf::FloatRect& dest) {
    const sf::Vector2u tex_size = texture.getTexture().getSize();
    if(tex_size.x == 0 || tex_size.y == 0 || dest.width <= 0.f || dest.height <= 0.f)
        return;

    sf::RectangleShape frame({dest.width + 8.f, dest.height + 8.f});
    frame.setPosition(dest.left - 4.f, dest.top - 4.f);
    frame.setFillColor(sf::Color(12, 12, 14, 255));
    frame.setOutlineColor(sf::Color(215, 205, 178, 180));
    frame.setOutlineThickness(2.f);
    mainPtr().draw(frame);

    sf::Sprite sprite(texture.getTexture());
    sprite.setPosition(dest.left, dest.top);
    sprite.setScale(dest.width / static_cast<float>(tex_size.x),
                    dest.height / static_cast<float>(tex_size.y));
    mainPtr().draw(sprite);
}]=])
set(CBOE_ANDROID_DRAW_PANEL_NEW [=[void draw_panel_texture(const sf::RenderTexture& texture, const sf::FloatRect& dest) {
    const sf::Vector2u tex_size = texture.getTexture().getSize();
    if(tex_size.x == 0 || tex_size.y == 0 || dest.width <= 0.f || dest.height <= 0.f)
        return;

    sf::RectangleShape frame({dest.width + 8.f, dest.height + 8.f});
    frame.setPosition(dest.left - 4.f, dest.top - 4.f);
    frame.setFillColor(sf::Color(12, 12, 14, 255));
    frame.setOutlineColor(sf::Color(215, 205, 178, 180));
    frame.setOutlineThickness(2.f);
    mainPtr().draw(frame);

    const float scale_x = dest.width / static_cast<float>(tex_size.x);
    const float scale_y = dest.height / static_cast<float>(tex_size.y);
    sf::Sprite sprite(texture.getTexture());
    sprite.setPosition(dest.left, dest.top);
    sprite.setScale(scale_x, scale_y);
    mainPtr().draw(sprite);

    sf::RenderTexture* text_key = const_cast<sf::RenderTexture*>(&texture);
    auto text_it = store_scale_aware_text.find(text_key);
    if(text_it == store_scale_aware_text.end())
        return;

    float ui_scale = static_cast<float>(get_ui_scale());
    if(ui_scale < 0.1f)
        ui_scale = 1.f;

    for(const ScaleAwareText& stored : text_it->second) {
        sf::Text text = stored.text;
        const sf::Vector2f logical_pos = text.getPosition();
        text.setPosition(dest.left + logical_pos.x * scale_x,
                         dest.top + logical_pos.y * scale_y);
        const sf::Vector2f old_scale = text.getScale();
        text.setScale(old_scale.x * scale_x / ui_scale,
                      old_scale.y * scale_y / ui_scale);
        mainPtr().draw(text);
    }
}]=])
string(FIND "${CBOE_ANDROID_WINUTIL_SOURCE}" "${CBOE_ANDROID_DRAW_PANEL_OLD}" CBOE_ANDROID_DRAW_PANEL_POS)
if(CBOE_ANDROID_DRAW_PANEL_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android draw_panel_texture implementation was not found")
endif()
string(REPLACE "${CBOE_ANDROID_DRAW_PANEL_OLD}" "${CBOE_ANDROID_DRAW_PANEL_NEW}" CBOE_ANDROID_WINUTIL_SOURCE "${CBOE_ANDROID_WINUTIL_SOURCE}")

# Bypass synthetic keyboard events for the touch D-pad. The Android SFML build
# converts touchscreen events to mouse events before OpenBoE sees them, so the
# previous TouchBegan/key-combination path could never fire on the phone.
set(CBOE_ANDROID_MOVE_HELPER_ANCHOR [=[bool android_dpad_keys_at(int pixel_x, int pixel_y,
                          sf::Keyboard::Key& primary,
                          sf::Keyboard::Key& secondary) {
    std::array<AndroidDpadButton, 8> buttons;
    if(!android_dpad_geometry(buttons))
        return false;

    for(const AndroidDpadButton& button : buttons) {
        if(button.rect.contains(static_cast<float>(pixel_x), static_cast<float>(pixel_y))) {
            primary = button.primary;
            secondary = button.secondary;
            return true;
        }
    }
    return false;
}
]=])
set(CBOE_ANDROID_MOVE_HELPER_INSERT [=[bool android_dpad_keys_at(int pixel_x, int pixel_y,
                          sf::Keyboard::Key& primary,
                          sf::Keyboard::Key& secondary) {
    std::array<AndroidDpadButton, 8> buttons;
    if(!android_dpad_geometry(buttons))
        return false;

    for(const AndroidDpadButton& button : buttons) {
        if(button.rect.contains(static_cast<float>(pixel_x), static_cast<float>(pixel_y))) {
            primary = button.primary;
            secondary = button.secondary;
            return true;
        }
    }
    return false;
}

void android_move_from_keys(sf::Keyboard::Key primary, sf::Keyboard::Key secondary) {
    location delta(0, 0);
    auto apply_key = [&delta](sf::Keyboard::Key key) {
        if(key == sf::Keyboard::Up) --delta.y;
        else if(key == sf::Keyboard::Down) ++delta.y;
        else if(key == sf::Keyboard::Left) --delta.x;
        else if(key == sf::Keyboard::Right) ++delta.x;
    };
    apply_key(primary);
    if(secondary != sf::Keyboard::Unknown)
        apply_key(secondary);
    if(delta.x == 0 && delta.y == 0)
        return;

    bool did_something = false;
    bool need_redraw = false;
    bool need_reprint = false;
    if(!handle_screen_shift(delta, need_redraw))
        handle_terrain_screen_actions(delta, false, false, did_something, need_redraw, need_reprint);
    advance_time(did_something, need_redraw, need_reprint);
}
]=])
string(FIND "${CBOE_ANDROID_WINUTIL_SOURCE}" "${CBOE_ANDROID_MOVE_HELPER_ANCHOR}" CBOE_ANDROID_MOVE_HELPER_POS)
if(CBOE_ANDROID_MOVE_HELPER_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android d-pad hit-test helper was not found")
endif()
string(REPLACE "${CBOE_ANDROID_MOVE_HELPER_ANCHOR}" "${CBOE_ANDROID_MOVE_HELPER_INSERT}" CBOE_ANDROID_WINUTIL_SOURCE "${CBOE_ANDROID_WINUTIL_SOURCE}")

set(CBOE_ANDROID_TOUCH_DPAD_OLD [=[                    android_dpad_finger = static_cast<int>(event.touch.finger);
                    make_android_key_event(event, primary);

                    // A diagonal is represented by two real arrow presses. Queue
                    // the second one so boe.main's existing 3-frame arrow combiner
                    // sees both keys and produces exactly one diagonal step.
                    if(secondary != sf::Keyboard::Unknown) {
                        sf::Event second;
                        make_android_key_event(second, secondary);
                        fake_event_queue.push_back(second);
                    }
                    break;]=])
set(CBOE_ANDROID_TOUCH_DPAD_NEW [=[                    android_dpad_finger = static_cast<int>(event.touch.finger);
                    android_move_from_keys(primary, secondary);
                    event.type = sf::Event::Count;
                    break;]=])
string(FIND "${CBOE_ANDROID_WINUTIL_SOURCE}" "${CBOE_ANDROID_TOUCH_DPAD_OLD}" CBOE_ANDROID_TOUCH_DPAD_POS)
if(CBOE_ANDROID_TOUCH_DPAD_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android TouchBegan d-pad dispatch block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_TOUCH_DPAD_OLD}" "${CBOE_ANDROID_TOUCH_DPAD_NEW}" CBOE_ANDROID_WINUTIL_SOURCE "${CBOE_ANDROID_WINUTIL_SOURCE}")

# Physical Android touches arrive here as Mouse events because of the existing
# SFML compatibility patch. Hit-test the D-pad before panel translation, then
# translate all other touches back to the legacy logical rectangles so the new
# stats/inventory/transcript panels remain fully interactive.
set(CBOE_ANDROID_MOUSE_EVENTS_OLD [=[            case sf::Event::MouseButtonPressed:
            case sf::Event::MouseButtonReleased:
                android_pointer_position = {event.mouseButton.x, event.mouseButton.y};
                android_pointer_valid = true;
                break;
            case sf::Event::MouseMoved:
                android_pointer_position = {event.mouseMove.x, event.mouseMove.y};
                android_pointer_valid = true;
                break;]=])
set(CBOE_ANDROID_MOUSE_EVENTS_NEW [=[            case sf::Event::MouseButtonPressed: {
                const int x = event.mouseButton.x;
                const int y = event.mouseButton.y;
                sf::Keyboard::Key primary = sf::Keyboard::Unknown;
                sf::Keyboard::Key secondary = sf::Keyboard::Unknown;
                if(&win == &mainPtr() && event.mouseButton.button == sf::Mouse::Left &&
                   android_dpad_keys_at(x, y, primary, secondary)) {
                    android_move_from_keys(primary, secondary);
                    event.type = sf::Event::Count;
                    break;
                }
                sf::Vector2i translated(x, y);
                if(&win == &mainPtr())
                    android_translate_panel_touch(x, y, translated);
                android_pointer_position = translated;
                android_pointer_valid = true;
                event.mouseButton.x = translated.x;
                event.mouseButton.y = translated.y;
                break;
            }
            case sf::Event::MouseButtonReleased: {
                const int x = event.mouseButton.x;
                const int y = event.mouseButton.y;
                sf::Vector2i translated(x, y);
                if(&win == &mainPtr())
                    android_translate_panel_touch(x, y, translated);
                android_pointer_position = translated;
                android_pointer_valid = true;
                event.mouseButton.x = translated.x;
                event.mouseButton.y = translated.y;
                break;
            }
            case sf::Event::MouseMoved: {
                const int x = event.mouseMove.x;
                const int y = event.mouseMove.y;
                sf::Vector2i translated(x, y);
                if(&win == &mainPtr())
                    android_translate_panel_touch(x, y, translated);
                android_pointer_position = translated;
                android_pointer_valid = true;
                event.mouseMove.x = translated.x;
                event.mouseMove.y = translated.y;
                break;
            }]=])
string(FIND "${CBOE_ANDROID_WINUTIL_SOURCE}" "${CBOE_ANDROID_MOUSE_EVENTS_OLD}" CBOE_ANDROID_MOUSE_EVENTS_POS)
if(CBOE_ANDROID_MOUSE_EVENTS_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android mouse-event pointer block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_MOUSE_EVENTS_OLD}" "${CBOE_ANDROID_MOUSE_EVENTS_NEW}" CBOE_ANDROID_WINUTIL_SOURCE "${CBOE_ANDROID_WINUTIL_SOURCE}")

file(WRITE "${CBOE_ANDROID_WINUTIL_CPP}" "${CBOE_ANDROID_WINUTIL_SOURCE}")
message(STATUS "Applied Android mobile UI v2 text, alignment, pointer, and direct d-pad fixes")
