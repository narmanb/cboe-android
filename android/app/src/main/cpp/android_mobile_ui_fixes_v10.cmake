# Android quick-action completeness pass after the 11x9 viewport work.
# Restore three core desktop toolbar actions that were omitted from the first
# mobile ACT menu: map, pick up/get items, and enter/leave combat.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V10_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V10_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V10_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_WINUTIL_V10_CPP "${CBOE_ANDROID_UI_V10_ROOT}/src/tools/winutil.cpp")
file(READ "${CBOE_ANDROID_WINUTIL_V10_CPP}" CBOE_ANDROID_WINUTIL_V10_SOURCE)

# display_map() is implemented by the game but is not declared by boe.actions.hpp.
# Keep winutil's Android dependency surface small and declare only what is needed.
set(CBOE_ANDROID_V10_DECL_OLD [=[void give_pc_info(short pc_num);
void set_stat_window(eItemWinMode new_stat, bool record);]=])
set(CBOE_ANDROID_V10_DECL_NEW [=[void give_pc_info(short pc_num);
void set_stat_window(eItemWinMode new_stat, bool record);
void display_map();]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V10_SOURCE}" "${CBOE_ANDROID_V10_DECL_OLD}" CBOE_ANDROID_V10_DECL_POS)
if(CBOE_ANDROID_V10_DECL_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android minimal declaration block was not found for v10")
endif()
string(REPLACE "${CBOE_ANDROID_V10_DECL_OLD}" "${CBOE_ANDROID_V10_DECL_NEW}" CBOE_ANDROID_WINUTIL_V10_SOURCE "${CBOE_ANDROID_WINUTIL_V10_SOURCE}")

set(CBOE_ANDROID_V10_ENUM_OLD [=[    ANDROID_QUICK_USE,
    ANDROID_QUICK_REST_WAIT,
    ANDROID_QUICK_COUNT]=])
set(CBOE_ANDROID_V10_ENUM_NEW [=[    ANDROID_QUICK_USE,
    ANDROID_QUICK_REST_WAIT,
    ANDROID_QUICK_MAP,
    ANDROID_QUICK_GET,
    ANDROID_QUICK_COMBAT,
    ANDROID_QUICK_COUNT]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V10_SOURCE}" "${CBOE_ANDROID_V10_ENUM_OLD}" CBOE_ANDROID_V10_ENUM_POS)
if(CBOE_ANDROID_V10_ENUM_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android quick-action enum was not found for v10")
endif()
string(REPLACE "${CBOE_ANDROID_V10_ENUM_OLD}" "${CBOE_ANDROID_V10_ENUM_NEW}" CBOE_ANDROID_WINUTIL_V10_SOURCE "${CBOE_ANDROID_WINUTIL_V10_SOURCE}")

# The original popup was exactly four rows because it contained eight actions.
# Size it from the actual action count so the added commands fit without overlap.
set(CBOE_ANDROID_V10_HEIGHT_OLD [=[    const float total_w = action_w * 2.f + gap;
    const float total_h = action_h * 4.f + gap * 3.f;]=])
set(CBOE_ANDROID_V10_HEIGHT_NEW [=[    const float total_w = action_w * 2.f + gap;
    const int action_rows = (ANDROID_QUICK_COUNT + 1) / 2;
    const float total_h = action_h * static_cast<float>(action_rows) +
                          gap * static_cast<float>(action_rows - 1);]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V10_SOURCE}" "${CBOE_ANDROID_V10_HEIGHT_OLD}" CBOE_ANDROID_V10_HEIGHT_POS)
if(CBOE_ANDROID_V10_HEIGHT_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android quick-action popup height block was not found for v10")
endif()
string(REPLACE "${CBOE_ANDROID_V10_HEIGHT_OLD}" "${CBOE_ANDROID_V10_HEIGHT_NEW}" CBOE_ANDROID_WINUTIL_V10_SOURCE "${CBOE_ANDROID_WINUTIL_V10_SOURCE}")

set(CBOE_ANDROID_V10_AVAIL_OLD [=[        case ANDROID_QUICK_REST_WAIT:
            return overall_mode == MODE_OUTDOORS || overall_mode == MODE_COMBAT;
        default:]=])
set(CBOE_ANDROID_V10_AVAIL_NEW [=[        case ANDROID_QUICK_REST_WAIT:
            return overall_mode == MODE_OUTDOORS || overall_mode == MODE_COMBAT;
        case ANDROID_QUICK_MAP:
            return overall_mode == MODE_OUTDOORS || overall_mode == MODE_TOWN;
        case ANDROID_QUICK_GET:
            return overall_mode == MODE_TOWN || overall_mode == MODE_COMBAT;
        case ANDROID_QUICK_COMBAT:
            return overall_mode == MODE_TOWN || overall_mode == MODE_COMBAT;
        default:]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V10_SOURCE}" "${CBOE_ANDROID_V10_AVAIL_OLD}" CBOE_ANDROID_V10_AVAIL_POS)
if(CBOE_ANDROID_V10_AVAIL_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android quick-action availability block was not found for v10")
endif()
string(REPLACE "${CBOE_ANDROID_V10_AVAIL_OLD}" "${CBOE_ANDROID_V10_AVAIL_NEW}" CBOE_ANDROID_WINUTIL_V10_SOURCE "${CBOE_ANDROID_WINUTIL_V10_SOURCE}")

set(CBOE_ANDROID_V10_LABEL_OLD [=[        case ANDROID_QUICK_REST_WAIT:
            return overall_mode == MODE_OUTDOORS ? "CAMP" : "WAIT";
        default: return "";]=])
set(CBOE_ANDROID_V10_LABEL_NEW [=[        case ANDROID_QUICK_REST_WAIT:
            return overall_mode == MODE_OUTDOORS ? "CAMP" : "WAIT";
        case ANDROID_QUICK_MAP: return "MAP";
        case ANDROID_QUICK_GET: return "GET";
        case ANDROID_QUICK_COMBAT: return "SWORD";
        default: return "";]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V10_SOURCE}" "${CBOE_ANDROID_V10_LABEL_OLD}" CBOE_ANDROID_V10_LABEL_POS)
if(CBOE_ANDROID_V10_LABEL_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android quick-action label block was not found for v10")
endif()
string(REPLACE "${CBOE_ANDROID_V10_LABEL_OLD}" "${CBOE_ANDROID_V10_LABEL_NEW}" CBOE_ANDROID_WINUTIL_V10_SOURCE "${CBOE_ANDROID_WINUTIL_V10_SOURCE}")

set(CBOE_ANDROID_V10_DISPATCH_OLD [=[        case ANDROID_QUICK_REST_WAIT:
            if(overall_mode == MODE_OUTDOORS)
                handle_rest(need_redraw, need_reprint);
            else if(overall_mode == MODE_COMBAT)
                handle_wait(did_something, need_redraw, need_reprint);
            else handled = false;
            break;
        default:]=])
set(CBOE_ANDROID_V10_DISPATCH_NEW [=[        case ANDROID_QUICK_REST_WAIT:
            if(overall_mode == MODE_OUTDOORS)
                handle_rest(need_redraw, need_reprint);
            else if(overall_mode == MODE_COMBAT)
                handle_wait(did_something, need_redraw, need_reprint);
            else handled = false;
            break;
        case ANDROID_QUICK_MAP:
            if(overall_mode == MODE_OUTDOORS || overall_mode == MODE_TOWN) {
                display_map();
                return; // map display is informational and must not advance time
            } else handled = false;
            break;
        case ANDROID_QUICK_GET:
            if(overall_mode == MODE_TOWN || overall_mode == MODE_COMBAT)
                handle_get_items(did_something, need_redraw, need_reprint);
            else handled = false;
            break;
        case ANDROID_QUICK_COMBAT:
            if(overall_mode == MODE_TOWN || overall_mode == MODE_COMBAT)
                handle_combat_switch(did_something, need_redraw, need_reprint);
            else handled = false;
            break;
        default:]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V10_SOURCE}" "${CBOE_ANDROID_V10_DISPATCH_OLD}" CBOE_ANDROID_V10_DISPATCH_POS)
if(CBOE_ANDROID_V10_DISPATCH_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android quick-action dispatch block was not found for v10")
endif()
string(REPLACE "${CBOE_ANDROID_V10_DISPATCH_OLD}" "${CBOE_ANDROID_V10_DISPATCH_NEW}" CBOE_ANDROID_WINUTIL_V10_SOURCE "${CBOE_ANDROID_WINUTIL_V10_SOURCE}")

file(WRITE "${CBOE_ANDROID_WINUTIL_V10_CPP}" "${CBOE_ANDROID_WINUTIL_V10_SOURCE}")
message(STATUS "Applied Android mobile UI v10 map/get/combat quick actions")
