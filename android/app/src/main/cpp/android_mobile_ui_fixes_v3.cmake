# Android gameplay UI/input stabilization pass applied after mobile UI v2.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V3_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V3_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V3_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_WINUTIL_V3_CPP "${CBOE_ANDROID_UI_V3_ROOT}/src/tools/winutil.cpp")
file(READ "${CBOE_ANDROID_WINUTIL_V3_CPP}" CBOE_ANDROID_WINUTIL_V3_SOURCE)

# Dialogs are drawn inline on Android, but gameplay touch remapping must not run
# while a cDialog owns input. Otherwise a Done/Save/etc. tap that overlaps one
# of the mobile panels is translated into legacy gameplay coordinates.
set(CBOE_ANDROID_V3_INCLUDE_OLD [=[#include "game/boe.consts.hpp"
#include "game/boe.actions.hpp"
#include "gfx/render_text.hpp"
#include "drawable_manager.hpp"]=])
set(CBOE_ANDROID_V3_INCLUDE_NEW [=[#include "game/boe.consts.hpp"
#include "game/boe.actions.hpp"
#include "gfx/render_text.hpp"
#include "dialogxml/dialogs/dialog.hpp"
#include "drawable_manager.hpp"]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V3_SOURCE}" "${CBOE_ANDROID_V3_INCLUDE_OLD}" CBOE_ANDROID_V3_INCLUDE_POS)
if(CBOE_ANDROID_V3_INCLUDE_POS EQUAL -1)
    message(FATAL_ERROR "Expected post-v2 Android winutil include block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V3_INCLUDE_OLD}" "${CBOE_ANDROID_V3_INCLUDE_NEW}" CBOE_ANDROID_WINUTIL_V3_SOURCE "${CBOE_ANDROID_WINUTIL_V3_SOURCE}")

set(CBOE_ANDROID_V3_VISIBILITY_OLD [=[bool android_dpad_visible() {
    return android_mobile_ui_visible();
}]=])
set(CBOE_ANDROID_V3_VISIBILITY_NEW [=[bool android_mobile_input_enabled() {
    // Keep the mobile layout visible behind an inline modal, but let the dialog
    // receive untouched physical coordinates while it is open.
    return !cDialog::anyOpen();
}

bool android_dpad_visible() {
    return android_mobile_ui_visible();
}]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V3_SOURCE}" "${CBOE_ANDROID_V3_VISIBILITY_OLD}" CBOE_ANDROID_V3_VISIBILITY_POS)
if(CBOE_ANDROID_V3_VISIBILITY_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android d-pad visibility helper was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V3_VISIBILITY_OLD}" "${CBOE_ANDROID_V3_VISIBILITY_NEW}" CBOE_ANDROID_WINUTIL_V3_SOURCE "${CBOE_ANDROID_WINUTIL_V3_SOURCE}")

# The copied stats/inventory/transcript textures still contain desktop widgets
# whose click handlers enter nested press/release loops. On Android that causes
# the miniature legacy UI, scrollbar fragments, and hold-to-activate behavior.
# Until each mobile panel has explicit Android actions, make those copies
# display-only. Terrain remains mapped because direct map touching is useful and
# does not enter those nested widget loops.
set(CBOE_ANDROID_V3_TRANSLATE_OLD [=[bool android_translate_panel_touch(int x, int y, sf::Vector2i& translated_pixel) {
    AndroidMobileLayout layout;
    if(!android_mobile_layout(layout))
        return false;

    const AndroidMappedPanel* panels[] = {
        &layout.terrain, &layout.stats, &layout.inventory, &layout.transcript
    };

    for(const AndroidMappedPanel* panel : panels) {]=])
set(CBOE_ANDROID_V3_TRANSLATE_NEW [=[bool android_translate_panel_touch(int x, int y, sf::Vector2i& translated_pixel) {
    if(!android_mobile_input_enabled())
        return false;

    AndroidMobileLayout layout;
    if(!android_mobile_layout(layout))
        return false;

    const AndroidMappedPanel* panels[] = {
        &layout.terrain
    };

    for(const AndroidMappedPanel* panel : panels) {]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V3_SOURCE}" "${CBOE_ANDROID_V3_TRANSLATE_OLD}" CBOE_ANDROID_V3_TRANSLATE_POS)
if(CBOE_ANDROID_V3_TRANSLATE_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android panel translation helper was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V3_TRANSLATE_OLD}" "${CBOE_ANDROID_V3_TRANSLATE_NEW}" CBOE_ANDROID_WINUTIL_V3_SOURCE "${CBOE_ANDROID_WINUTIL_V3_SOURCE}")

set(CBOE_ANDROID_V3_PANEL_GUARD_ANCHOR [=[bool android_translate_panel_touch(int x, int y, sf::Vector2i& translated_pixel) {]=])
set(CBOE_ANDROID_V3_PANEL_GUARD_INSERT [=[bool android_info_panel_contains(int x, int y) {
    if(!android_mobile_input_enabled())
        return false;

    AndroidMobileLayout layout;
    if(!android_mobile_layout(layout))
        return false;

    const float fx = static_cast<float>(x);
    const float fy = static_cast<float>(y);
    return layout.stats.screen.contains(fx, fy) ||
           layout.inventory.screen.contains(fx, fy) ||
           layout.transcript.screen.contains(fx, fy);
}

bool android_translate_panel_touch(int x, int y, sf::Vector2i& translated_pixel) {]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V3_SOURCE}" "${CBOE_ANDROID_V3_PANEL_GUARD_ANCHOR}" CBOE_ANDROID_V3_PANEL_GUARD_POS)
if(CBOE_ANDROID_V3_PANEL_GUARD_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android panel translation anchor was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V3_PANEL_GUARD_ANCHOR}" "${CBOE_ANDROID_V3_PANEL_GUARD_INSERT}" CBOE_ANDROID_WINUTIL_V3_SOURCE "${CBOE_ANDROID_WINUTIL_V3_SOURCE}")

set(CBOE_ANDROID_V3_DPAD_OLD [=[bool android_dpad_keys_at(int pixel_x, int pixel_y,
                          sf::Keyboard::Key& primary,
                          sf::Keyboard::Key& secondary) {
    std::array<AndroidDpadButton, 8> buttons;]=])
set(CBOE_ANDROID_V3_DPAD_NEW [=[bool android_dpad_keys_at(int pixel_x, int pixel_y,
                          sf::Keyboard::Key& primary,
                          sf::Keyboard::Key& secondary) {
    if(!android_mobile_input_enabled())
        return false;

    std::array<AndroidDpadButton, 8> buttons;]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V3_SOURCE}" "${CBOE_ANDROID_V3_DPAD_OLD}" CBOE_ANDROID_V3_DPAD_POS)
if(CBOE_ANDROID_V3_DPAD_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android d-pad hit-test helper was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V3_DPAD_OLD}" "${CBOE_ANDROID_V3_DPAD_NEW}" CBOE_ANDROID_WINUTIL_V3_SOURCE "${CBOE_ANDROID_WINUTIL_V3_SOURCE}")

# Suppress gameplay mouse events that land on the display-only mobile info
# copies. Critically, android_info_panel_contains() returns false during modals,
# so dialog buttons over the exact same screen area pass through untouched.
set(CBOE_ANDROID_V3_MOUSE_PRESS_OLD [=[                if(&win == &mainPtr() && event.mouseButton.button == sf::Mouse::Left &&
                   android_dpad_keys_at(x, y, primary, secondary)) {
                    android_move_from_keys(primary, secondary);
                    event.type = sf::Event::Count;
                    break;
                }
                sf::Vector2i translated(x, y);]=])
set(CBOE_ANDROID_V3_MOUSE_PRESS_NEW [=[                if(&win == &mainPtr() && event.mouseButton.button == sf::Mouse::Left &&
                   android_dpad_keys_at(x, y, primary, secondary)) {
                    android_move_from_keys(primary, secondary);
                    event.type = sf::Event::Count;
                    break;
                }
                if(&win == &mainPtr() && android_info_panel_contains(x, y)) {
                    event.type = sf::Event::Count;
                    break;
                }
                sf::Vector2i translated(x, y);]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V3_SOURCE}" "${CBOE_ANDROID_V3_MOUSE_PRESS_OLD}" CBOE_ANDROID_V3_MOUSE_PRESS_POS)
if(CBOE_ANDROID_V3_MOUSE_PRESS_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android mouse press dispatch block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V3_MOUSE_PRESS_OLD}" "${CBOE_ANDROID_V3_MOUSE_PRESS_NEW}" CBOE_ANDROID_WINUTIL_V3_SOURCE "${CBOE_ANDROID_WINUTIL_V3_SOURCE}")

set(CBOE_ANDROID_V3_MOUSE_RELEASE_OLD [=[            case sf::Event::MouseButtonReleased: {
                const int x = event.mouseButton.x;
                const int y = event.mouseButton.y;
                sf::Vector2i translated(x, y);]=])
set(CBOE_ANDROID_V3_MOUSE_RELEASE_NEW [=[            case sf::Event::MouseButtonReleased: {
                const int x = event.mouseButton.x;
                const int y = event.mouseButton.y;
                if(&win == &mainPtr() && android_info_panel_contains(x, y)) {
                    event.type = sf::Event::Count;
                    break;
                }
                sf::Vector2i translated(x, y);]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V3_SOURCE}" "${CBOE_ANDROID_V3_MOUSE_RELEASE_OLD}" CBOE_ANDROID_V3_MOUSE_RELEASE_POS)
if(CBOE_ANDROID_V3_MOUSE_RELEASE_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android mouse release dispatch block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V3_MOUSE_RELEASE_OLD}" "${CBOE_ANDROID_V3_MOUSE_RELEASE_NEW}" CBOE_ANDROID_WINUTIL_V3_SOURCE "${CBOE_ANDROID_WINUTIL_V3_SOURCE}")

set(CBOE_ANDROID_V3_MOUSE_MOVE_OLD [=[            case sf::Event::MouseMoved: {
                const int x = event.mouseMove.x;
                const int y = event.mouseMove.y;
                sf::Vector2i translated(x, y);]=])
set(CBOE_ANDROID_V3_MOUSE_MOVE_NEW [=[            case sf::Event::MouseMoved: {
                const int x = event.mouseMove.x;
                const int y = event.mouseMove.y;
                if(&win == &mainPtr() && android_info_panel_contains(x, y)) {
                    event.type = sf::Event::Count;
                    break;
                }
                sf::Vector2i translated(x, y);]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V3_SOURCE}" "${CBOE_ANDROID_V3_MOUSE_MOVE_OLD}" CBOE_ANDROID_V3_MOUSE_MOVE_POS)
if(CBOE_ANDROID_V3_MOUSE_MOVE_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android mouse move dispatch block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V3_MOUSE_MOVE_OLD}" "${CBOE_ANDROID_V3_MOUSE_MOVE_NEW}" CBOE_ANDROID_WINUTIL_V3_SOURCE "${CBOE_ANDROID_WINUTIL_V3_SOURCE}")

file(WRITE "${CBOE_ANDROID_WINUTIL_V3_CPP}" "${CBOE_ANDROID_WINUTIL_V3_SOURCE}")
message(STATUS "Applied Android mobile UI v3 modal-routing and legacy-panel isolation fixes")
