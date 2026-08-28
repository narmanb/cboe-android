# Android ACT/minimap pixel alignment polish v23.
# - Align the visible minimap frame edge with the visible ACT button edge.
# - Nudge the ACT grid clear of the info-column divider.
# - Pull only COMBAT and PRIEST labels slightly left for equal right padding.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V23_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V23_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V23_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V23_WINUTIL_CPP "${CBOE_ANDROID_UI_V23_ROOT}/src/tools/winutil.cpp")
file(READ "${CBOE_ANDROID_V23_WINUTIL_CPP}" V23_WINUTIL)

# The minimap frame is drawn 4 px outside android_map_mini_rect(), with a 2 px
# outline beyond that. ACT buttons use only their 2 px outline. Therefore the
# map content origin must sit 4 px farther right than the ACT rectangle for the
# two *visible* left borders to line up exactly.
set(V23_MINI_GAP_OLD [=[        const float top = 14.f;
        const float info_gap = 4.f;
        const float menu_lane = 60.f;
        const float lane_gap = 8.f;
        const float left = layout.stats.screen.left + layout.stats.screen.width + info_gap;]=])
set(V23_MINI_GAP_NEW [=[        const float top = 14.f;
        const float info_gap = 10.f;
        const float menu_lane = 60.f;
        const float lane_gap = 8.f;
        const float left = layout.stats.screen.left + layout.stats.screen.width + info_gap;]=])
string(FIND "${V23_WINUTIL}" "${V23_MINI_GAP_OLD}" V23_MINI_GAP_POS)
if(V23_MINI_GAP_POS EQUAL -1)
    message(FATAL_ERROR "v23: expected v22 minimap gap geometry not found")
endif()
string(REPLACE "${V23_MINI_GAP_OLD}" "${V23_MINI_GAP_NEW}" V23_WINUTIL "${V23_WINUTIL}")

# Keep the helper's duplicated minimap calculation identical to the live map.
set(V23_REGION_GAP_OLD [=[    const float mini_top = 14.f;
    const float info_gap = 4.f;
    const float menu_lane = 60.f;
    const float lane_gap = 8.f;
    const float mini_left = layout.stats.screen.left + layout.stats.screen.width + info_gap;]=])
set(V23_REGION_GAP_NEW [=[    const float mini_top = 14.f;
    const float info_gap = 10.f;
    const float menu_lane = 60.f;
    const float lane_gap = 8.f;
    const float mini_left = layout.stats.screen.left + layout.stats.screen.width + info_gap;]=])
string(FIND "${V23_WINUTIL}" "${V23_REGION_GAP_OLD}" V23_REGION_GAP_POS)
if(V23_REGION_GAP_POS EQUAL -1)
    message(FATAL_ERROR "v23: expected v22 action-region minimap gap not found")
endif()
string(REPLACE "${V23_REGION_GAP_OLD}" "${V23_REGION_GAP_NEW}" V23_WINUTIL "${V23_WINUTIL}")

# Move ACT itself only 2 px right. Its 2 px outline then clears the divider,
# while the map's extra 4 px frame padding makes both visible edges coincide.
set(V23_ACT_LEFT_OLD [=[        const float desired_left =
            layout.stats.screen.left + layout.stats.screen.width + 4.f;
        const float desired_right = dpad_panel.left + dpad_panel.width;]=])
set(V23_ACT_LEFT_NEW [=[        const float desired_left =
            layout.stats.screen.left + layout.stats.screen.width + 6.f;
        const float desired_right = dpad_panel.left + dpad_panel.width;]=])
string(FIND "${V23_WINUTIL}" "${V23_ACT_LEFT_OLD}" V23_ACT_LEFT_POS)
if(V23_ACT_LEFT_POS EQUAL -1)
    message(FATAL_ERROR "v23: expected v22 ACT left-edge geometry not found")
endif()
string(REPLACE "${V23_ACT_LEFT_OLD}" "${V23_ACT_LEFT_NEW}" V23_WINUTIL "${V23_WINUTIL}")

# The restored generic renderer works on-device. Keep it, but the two six-letter
# labels need one less leading spacer so their rightmost pixels match the visual
# margin of MAGE/TALK/USE/GET/LOOK instead of touching the button edge.
set(V23_LABEL_PAD_OLD [=[    const std::string padded_label = "     " + android_quick_label(action);
    draw_android_quick_button(rect, padded_label, available, pressed);
    draw_android_quick_icon(rect, action, available);]=])
set(V23_LABEL_PAD_NEW [=[    std::string padded_label =
        (action == ANDROID_QUICK_COMBAT || action == ANDROID_QUICK_PRIEST)
            ? "    " : "     ";
    padded_label += android_quick_label(action);
    draw_android_quick_button(rect, padded_label, available, pressed);
    draw_android_quick_icon(rect, action, available);]=])
string(FIND "${V23_WINUTIL}" "${V23_LABEL_PAD_OLD}" V23_LABEL_PAD_POS)
if(V23_LABEL_PAD_POS EQUAL -1)
    message(FATAL_ERROR "v23: expected v22 restored ACT label renderer not found")
endif()
string(REPLACE "${V23_LABEL_PAD_OLD}" "${V23_LABEL_PAD_NEW}" V23_WINUTIL "${V23_WINUTIL}")

file(WRITE "${CBOE_ANDROID_V23_WINUTIL_CPP}" "${V23_WINUTIL}")
message(STATUS "Applied Android mobile UI v23 visible-border and label alignment")
