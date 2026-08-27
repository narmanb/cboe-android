# Android explicit-panel interaction pass applied after v4 quick actions.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V5_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V5_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V5_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_WINUTIL_V5_CPP "${CBOE_ANDROID_UI_V5_ROOT}/src/tools/winutil.cpp")
file(READ "${CBOE_ANDROID_WINUTIL_V5_CPP}" CBOE_ANDROID_WINUTIL_V5_SOURCE)

# The mobile copies of the stats/inventory panels need direct Android actions,
# not translated desktop mouse clicks. Pull in the engine helpers we call.
set(CBOE_ANDROID_V5_INCLUDE_OLD [=[#include "game/boe.consts.hpp"
#include "game/boe.actions.hpp"
#include "gfx/render_text.hpp"
#include "dialogxml/dialogs/dialog.hpp"
#include "drawable_manager.hpp"]=])
set(CBOE_ANDROID_V5_INCLUDE_NEW [=[#include "game/boe.consts.hpp"
#include "game/boe.actions.hpp"
#include "game/boe.infodlg.hpp"
#include "game/boe.text.hpp"
#include "gfx/render_text.hpp"
#include "dialogxml/dialogs/dialog.hpp"
#include "dialogxml/widgets/scrollbar.hpp"
#include "drawable_manager.hpp"]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V5_SOURCE}" "${CBOE_ANDROID_V5_INCLUDE_OLD}" CBOE_ANDROID_V5_INCLUDE_POS)
if(CBOE_ANDROID_V5_INCLUDE_POS EQUAL -1)
    message(FATAL_ERROR "Expected post-v4 Android include block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V5_INCLUDE_OLD}" "${CBOE_ANDROID_V5_INCLUDE_NEW}" CBOE_ANDROID_WINUTIL_V5_SOURCE "${CBOE_ANDROID_WINUTIL_V5_SOURCE}")

set(CBOE_ANDROID_V5_EXTERNS_OLD [=[extern sf::RenderTexture& text_area_gworld();]=])
set(CBOE_ANDROID_V5_EXTERNS_NEW [=[extern sf::RenderTexture& text_area_gworld();
extern eItemWinMode stat_window;
extern std::shared_ptr<cScrollbar> item_sbar;
extern std::shared_ptr<cScrollbar> text_sbar;
extern std::vector<int> spec_item_array;]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V5_SOURCE}" "${CBOE_ANDROID_V5_EXTERNS_OLD}" CBOE_ANDROID_V5_EXTERNS_POS)
if(CBOE_ANDROID_V5_EXTERNS_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android render-texture extern block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V5_EXTERNS_OLD}" "${CBOE_ANDROID_V5_EXTERNS_NEW}" CBOE_ANDROID_WINUTIL_V5_SOURCE "${CBOE_ANDROID_WINUTIL_V5_SOURCE}")

# Translate a physical tap into coordinates local to one independently drawn
# mobile panel. Unlike the old desktop translation this does not synthesize any
# mouse event, so it cannot enter nested legacy press/release loops.
set(CBOE_ANDROID_V5_HANDLER_ANCHOR [=[bool android_translate_panel_touch(int x, int y, sf::Vector2i& translated_pixel) {]=])
set(CBOE_ANDROID_V5_HANDLER_INSERT [=[bool android_panel_local(const AndroidMappedPanel& panel, int x, int y,
                         float& local_x, float& local_y) {
    if(!panel.screen.contains(static_cast<float>(x), static_cast<float>(y)) ||
       panel.screen.width <= 0.f || panel.screen.height <= 0.f)
        return false;

    const float u = (static_cast<float>(x) - panel.screen.left) / panel.screen.width;
    const float v = (static_cast<float>(y) - panel.screen.top) / panel.screen.height;
    local_x = u * panel.legacy.width;
    local_y = v * panel.legacy.height;
    return true;
}

bool android_handle_info_panel_tap(int x, int y) {
    if(!android_mobile_input_enabled())
        return false;

    AndroidMobileLayout layout;
    if(!android_mobile_layout(layout))
        return false;

    float lx = 0.f, ly = 0.f;

    // Party panel: preserve the useful desktop semantics, but invoke them
    // directly. Name = select PC, HP/SP = print details, ? = PC info,
    // right-most swap glyph = trade places.
    if(android_panel_local(layout.stats, x, y, lx, ly)) {
        if(ly >= 21.f && ly < 99.f) {
            const int row = static_cast<int>((ly - 21.f) / 13.f);
            if(row >= 0 && row < 6) {
                bool need_redraw = false;
                bool need_reprint = false;
                if(lx >= 241.f && lx < 253.f) {
                    display_pc(static_cast<short>(row), 1, nullptr);
                    return true;
                }
                if(lx >= 253.f && lx < 267.f)
                    handle_trade_places(static_cast<short>(row), need_reprint);
                else if(lx >= 184.f && lx < 214.f)
                    handle_print_pc_hp(row, need_reprint);
                else if(lx >= 214.f && lx < 241.f)
                    handle_print_pc_sp(row, need_reprint);
                else
                    handle_switch_pc(static_cast<short>(row), need_redraw, need_reprint);
                advance_time(false, need_redraw, need_reprint);
                return true;
            }
        }
        if(ly >= 101.f && ly <= 116.f && lx >= 248.f) {
            show_dialog_action("help-stats");
            return true;
        }
        return true;
    }

    // Inventory panel bottom strip: six party pages, Special, Quests, Help.
    if(android_panel_local(layout.inventory, x, y, lx, ly)) {
        if(ly >= 124.f && ly <= 144.f) {
            static const float pc_left[6] = {10.f, 40.f, 68.f, 98.f, 126.f, 156.f};
            for(int i = 0; i < 6; ++i) {
                if(lx >= pc_left[i] && lx <= pc_left[i] + 18.f) {
                    bool need_redraw = false;
                    handle_switch_pc_items(static_cast<short>(i), need_redraw);
                    bool need_reprint = true;
                    update_item_stats_area(need_reprint);
                    advance_time(false, need_redraw, need_reprint);
                    return true;
                }
            }
            if(lx >= 176.f && lx <= 211.f) {
                set_stat_window(ITEM_WIN_SPECIAL, true);
                return true;
            }
            if(lx >= 213.f && lx <= 248.f) {
                set_stat_window(ITEM_WIN_QUESTS, true);
                return true;
            }
            if(lx >= 249.f) {
                show_dialog_action("help-inventory");
                return true;
            }
        }

        // Eight visible item rows. The source panel uses 13-pixel row spacing.
        if(ly >= 15.f && ly < 120.f) {
            const int row = static_cast<int>((ly - 15.f) / 13.f);
            if(row >= 0 && row < 8) {
                const int item_hit = static_cast<int>(item_sbar ? item_sbar->getPosition() : 0) + row;

                // Special/quest pages are information-oriented. Avoid destructive
                // assumptions about buttons that differ from normal inventories.
                if(stat_window >= ITEM_WIN_SPECIAL) {
                    if(item_hit >= 0 && item_hit < static_cast<int>(spec_item_array.size()))
                        show_item_info(static_cast<short>(item_hit));
                    return true;
                }

                if(item_hit < 0 || item_hit >= 24)
                    return true;

                bool did_something = false;
                bool need_redraw = false;
                bool need_reprint = false;
                bool opened_dialog = false;

                if(lx < 196.f)
                    handle_equip_item(static_cast<short>(item_hit), need_redraw);
                else if(lx < 210.f)
                    handle_use_item(static_cast<short>(item_hit), did_something, need_redraw);
                else if(lx < 224.f)
                    handle_give_item(static_cast<short>(item_hit), did_something, need_redraw);
                else if(lx < 238.f)
                    handle_drop_item(static_cast<short>(item_hit), need_redraw);
                else {
                    show_item_info(static_cast<short>(item_hit));
                    opened_dialog = true;
                }

                if(!opened_dialog) {
                    update_item_stats_area(need_reprint);
                    advance_time(did_something, need_redraw, need_reprint);
                }
                return true;
            }
        }
        return true;
    }

    // Transcript itself is display-only for now. Its old scrollbar is a separate
    // desktop widget and will be replaced by a native mobile control later.
    if(android_panel_local(layout.transcript, x, y, lx, ly))
        return true;

    return false;
}

bool android_translate_panel_touch(int x, int y, sf::Vector2i& translated_pixel) {]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V5_SOURCE}" "${CBOE_ANDROID_V5_HANDLER_ANCHOR}" CBOE_ANDROID_V5_HANDLER_POS)
if(CBOE_ANDROID_V5_HANDLER_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android terrain translation anchor was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V5_HANDLER_ANCHOR}" "${CBOE_ANDROID_V5_HANDLER_INSERT}" CBOE_ANDROID_WINUTIL_V5_SOURCE "${CBOE_ANDROID_WINUTIL_V5_SOURCE}")

# In v4 the ACT drawable can be painted before the d-pad's solid backing panel,
# hiding the centre button even though its hit box works. Draw the centre cell
# again at the end of the d-pad pass so it is unambiguously visible.
set(CBOE_ANDROID_V5_DPAD_OLD [=[            mainPtr().draw(arrow);
        }

        mainPtr().setView(previous_view);]=])
set(CBOE_ANDROID_V5_DPAD_NEW [=[            mainPtr().draw(arrow);
        }

        sf::FloatRect act_toggle;
        std::array<sf::FloatRect, ANDROID_QUICK_COUNT> act_actions;
        if(android_quick_geometry(act_toggle, act_actions))
            draw_android_quick_button(act_toggle, "ACT", android_mobile_input_enabled(),
                                      android_quick_pressed == ANDROID_QUICK_TOGGLE);

        mainPtr().setView(previous_view);]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V5_SOURCE}" "${CBOE_ANDROID_V5_DPAD_OLD}" CBOE_ANDROID_V5_DPAD_POS)
if(CBOE_ANDROID_V5_DPAD_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android d-pad draw tail was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V5_DPAD_OLD}" "${CBOE_ANDROID_V5_DPAD_NEW}" CBOE_ANDROID_WINUTIL_V5_SOURCE "${CBOE_ANDROID_WINUTIL_V5_SOURCE}")

# v3 deliberately swallowed release events on the copied panels. Now that the
# panels have explicit actions, fire the direct handler on release instead.
set(CBOE_ANDROID_V5_RELEASE_OLD [=[                if(&win == &mainPtr() && android_info_panel_contains(x, y)) {
                    event.type = sf::Event::Count;
                    break;
                }
                sf::Vector2i translated(x, y);]=])
set(CBOE_ANDROID_V5_RELEASE_NEW [=[                if(&win == &mainPtr() && android_info_panel_contains(x, y)) {
                    android_handle_info_panel_tap(x, y);
                    event.type = sf::Event::Count;
                    break;
                }
                sf::Vector2i translated(x, y);]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V5_SOURCE}" "${CBOE_ANDROID_V5_RELEASE_OLD}" CBOE_ANDROID_V5_RELEASE_POS)
if(CBOE_ANDROID_V5_RELEASE_POS EQUAL -1)
    message(FATAL_ERROR "Expected post-v4 Android panel release block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V5_RELEASE_OLD}" "${CBOE_ANDROID_V5_RELEASE_NEW}" CBOE_ANDROID_WINUTIL_V5_SOURCE "${CBOE_ANDROID_WINUTIL_V5_SOURCE}")

file(WRITE "${CBOE_ANDROID_WINUTIL_V5_CPP}" "${CBOE_ANDROID_WINUTIL_V5_SOURCE}")
message(STATUS "Applied Android mobile UI v5 explicit stats/inventory controls and ACT visibility fix")
