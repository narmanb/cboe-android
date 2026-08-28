# Android inventory/transcript gesture classification hardening after v16.
# A panel gesture must not activate an inventory item when the finger moved
# beyond the drag threshold, even if Android did not emit intermediate
# MouseMoved events before release.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V17_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V17_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V17_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V17_WINUTIL_CPP "${CBOE_ANDROID_UI_V17_ROOT}/src/tools/winutil.cpp")
file(READ "${CBOE_ANDROID_V17_WINUTIL_CPP}" V17_WINUTIL)

# Track both axes so release-time displacement can classify a gesture even if
# the platform did not deliver any intermediate mouse-move event.
set(V17_STATE_OLD [=[float android_panel_scroll_start_y = 0.f;
long android_panel_scroll_start_position = 0;]=])
set(V17_STATE_NEW [=[float android_panel_scroll_start_x = 0.f;
float android_panel_scroll_start_y = 0.f;
long android_panel_scroll_start_position = 0;]=])
string(FIND "${V17_WINUTIL}" "${V17_STATE_OLD}" V17_STATE_POS)
if(V17_STATE_POS EQUAL -1)
    message(FATAL_ERROR "v17: expected v16 panel gesture state not found")
endif()
string(REPLACE "${V17_STATE_OLD}" "${V17_STATE_NEW}" V17_WINUTIL "${V17_WINUTIL}")

# Arm every Inventory/Transcript panel press, not only panels that currently
# need a visible scrollbar. Presses remain non-destructive; stationary releases
# still reach android_handle_info_panel_tap(), while drags are consumed.
set(V17_BEGIN_OLD [=[bool android_begin_panel_scroll(int x, int y) {
    android_panel_scroll_target = ANDROID_PANEL_SCROLL_NONE;
    android_panel_scroll_dragging = false;
    android_panel_scroll_track_drag = false;

    if(!android_mobile_input_enabled())
        return false;

    const float fx = static_cast<float>(x);
    const float fy = static_cast<float>(y);
    AndroidMobileLayout layout;
    if(!android_mobile_layout(layout))
        return false;

    for(AndroidPanelScrollTarget target : {ANDROID_PANEL_SCROLL_INVENTORY,
                                           ANDROID_PANEL_SCROLL_TRANSCRIPT}) {
        sf::FloatRect track, thumb;
        if(!android_panel_scrollbar_geometry(target, track, thumb))
            continue;
        if(track.contains(fx, fy)) {
            android_panel_scroll_target = target;
            android_panel_scroll_dragging = true;
            android_panel_scroll_track_drag = true;
            android_panel_scroll_start_y = fy;
            std::shared_ptr<cScrollbar> bar = android_panel_scrollbar(target);
            android_panel_scroll_start_position = bar ? bar->getPosition() : 0;
            android_scroll_track_to_y(target, fy);
            return true;
        }

        const AndroidMappedPanel* panel = android_panel_for_scroll_target(layout, target);
        if(panel && panel->screen.contains(fx, fy)) {
            android_panel_scroll_target = target;
            android_panel_scroll_start_y = fy;
            std::shared_ptr<cScrollbar> bar = android_panel_scrollbar(target);
            android_panel_scroll_start_position = bar ? bar->getPosition() : 0;
            return false;
        }
    }
    return false;
}]=])
set(V17_BEGIN_NEW [=[bool android_begin_panel_scroll(int x, int y) {
    android_panel_scroll_target = ANDROID_PANEL_SCROLL_NONE;
    android_panel_scroll_dragging = false;
    android_panel_scroll_track_drag = false;

    if(!android_mobile_input_enabled())
        return false;

    const float fx = static_cast<float>(x);
    const float fy = static_cast<float>(y);
    AndroidMobileLayout layout;
    if(!android_mobile_layout(layout))
        return false;

    for(AndroidPanelScrollTarget target : {ANDROID_PANEL_SCROLL_INVENTORY,
                                           ANDROID_PANEL_SCROLL_TRANSCRIPT}) {
        sf::FloatRect track, thumb;
        if(android_panel_scrollbar_geometry(target, track, thumb) && track.contains(fx, fy)) {
            android_panel_scroll_target = target;
            android_panel_scroll_dragging = true;
            android_panel_scroll_track_drag = true;
            android_panel_scroll_start_x = fx;
            android_panel_scroll_start_y = fy;
            std::shared_ptr<cScrollbar> bar = android_panel_scrollbar(target);
            android_panel_scroll_start_position = bar ? bar->getPosition() : 0;
            android_scroll_track_to_y(target, fy);
            return true;
        }

        const AndroidMappedPanel* panel = android_panel_for_scroll_target(layout, target);
        if(panel && panel->screen.contains(fx, fy)) {
            android_panel_scroll_target = target;
            android_panel_scroll_start_x = fx;
            android_panel_scroll_start_y = fy;
            std::shared_ptr<cScrollbar> bar = android_panel_scrollbar(target);
            android_panel_scroll_start_position = bar ? bar->getPosition() : 0;
            return true;
        }
    }
    return false;
}]=])
string(FIND "${V17_WINUTIL}" "${V17_BEGIN_OLD}" V17_BEGIN_POS)
if(V17_BEGIN_POS EQUAL -1)
    message(FATAL_ERROR "v17: expected v16 panel begin handler not found")
endif()
string(REPLACE "${V17_BEGIN_OLD}" "${V17_BEGIN_NEW}" V17_WINUTIL "${V17_WINUTIL}")

# Re-run the movement classifier at release. This catches Android sequences
# where press/release coordinates differ but no MouseMoved event was delivered.
set(V17_END_OLD [=[bool android_end_panel_scroll() {
    if(android_panel_scroll_target == ANDROID_PANEL_SCROLL_NONE)
        return false;
    const bool consumed = android_panel_scroll_dragging || android_panel_scroll_track_drag;
    android_panel_scroll_target = ANDROID_PANEL_SCROLL_NONE;
    android_panel_scroll_dragging = false;
    android_panel_scroll_track_drag = false;
    return consumed;
}]=])
set(V17_END_NEW [=[bool android_end_panel_scroll(int x, int y) {
    if(android_panel_scroll_target == ANDROID_PANEL_SCROLL_NONE)
        return false;

    if(!android_panel_scroll_track_drag) {
        const float dx = static_cast<float>(x) - android_panel_scroll_start_x;
        const float dy = static_cast<float>(y) - android_panel_scroll_start_y;
        const float drag_threshold = 14.f;
        if(dx <= -drag_threshold || dx >= drag_threshold ||
           dy <= -drag_threshold || dy >= drag_threshold) {
            android_update_panel_scroll(x, y);
            android_panel_scroll_dragging = true;
        }
    }

    const bool consumed = android_panel_scroll_dragging || android_panel_scroll_track_drag;
    android_panel_scroll_target = ANDROID_PANEL_SCROLL_NONE;
    android_panel_scroll_dragging = false;
    android_panel_scroll_track_drag = false;
    return consumed;
}]=])
string(FIND "${V17_WINUTIL}" "${V17_END_OLD}" V17_END_POS)
if(V17_END_POS EQUAL -1)
    message(FATAL_ERROR "v17: expected v16 panel end handler not found")
endif()
string(REPLACE "${V17_END_OLD}" "${V17_END_NEW}" V17_WINUTIL "${V17_WINUTIL}")

set(V17_RELEASE_CALL_OLD [=[const bool consumed_scroll = android_end_panel_scroll();]=])
set(V17_RELEASE_CALL_NEW [=[const bool consumed_scroll = android_end_panel_scroll(x, y);]=])
string(FIND "${V17_WINUTIL}" "${V17_RELEASE_CALL_OLD}" V17_RELEASE_CALL_POS)
if(V17_RELEASE_CALL_POS EQUAL -1)
    message(FATAL_ERROR "v17: expected v16 panel release call not found")
endif()
string(REPLACE "${V17_RELEASE_CALL_OLD}" "${V17_RELEASE_CALL_NEW}" V17_WINUTIL "${V17_WINUTIL}")

file(WRITE "${CBOE_ANDROID_V17_WINUTIL_CPP}" "${V17_WINUTIL}")
message(STATUS "Applied Android mobile UI v17 tap-vs-scroll gesture hardening")
