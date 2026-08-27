# Android physical-test fixes after v6.
# - Route each Party Stats ? button to the engine's real full PC-info dialog.
# - Match quick SAVE/LOAD availability to normal OpenBoE town/outdoors rules.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V7_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V7_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V7_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_WINUTIL_V7_CPP "${CBOE_ANDROID_UI_V7_ROOT}/src/tools/winutil.cpp")
file(READ "${CBOE_ANDROID_WINUTIL_V7_CPP}" CBOE_ANDROID_WINUTIL_V7_SOURCE)

# v5 used display_pc(), but the original Party Stats PCBTN_INFO handler calls
# give_pc_info(), which is the full read-only character information dialog.
# v5_compilefix deliberately keeps winutil's dependency surface minimal, so add
# the one cross-TU declaration here rather than reintroducing boe.infodlg.hpp.
set(CBOE_ANDROID_V7_DECL_OLD [=[void display_pc(short pc_num, short mode, cDialog* parent_num);
void set_stat_window(eItemWinMode new_stat, bool record);]=])
set(CBOE_ANDROID_V7_DECL_NEW [=[void display_pc(short pc_num, short mode, cDialog* parent_num);
void give_pc_info(short pc_num);
void set_stat_window(eItemWinMode new_stat, bool record);]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V7_SOURCE}" "${CBOE_ANDROID_V7_DECL_OLD}" CBOE_ANDROID_V7_DECL_POS)
if(CBOE_ANDROID_V7_DECL_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android v5 minimal declaration block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V7_DECL_OLD}" "${CBOE_ANDROID_V7_DECL_NEW}" CBOE_ANDROID_WINUTIL_V7_SOURCE "${CBOE_ANDROID_WINUTIL_V7_SOURCE}")

set(CBOE_ANDROID_V7_PC_INFO_OLD [=[                    display_pc(static_cast<short>(row), 1, nullptr);
                    return true;]=])
set(CBOE_ANDROID_V7_PC_INFO_NEW [=[                    give_pc_info(static_cast<short>(row));
                    return true;]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V7_SOURCE}" "${CBOE_ANDROID_V7_PC_INFO_OLD}" CBOE_ANDROID_V7_PC_INFO_POS)
if(CBOE_ANDROID_V7_PC_INFO_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android v5 Party Stats info dispatch was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V7_PC_INFO_OLD}" "${CBOE_ANDROID_V7_PC_INFO_NEW}" CBOE_ANDROID_WINUTIL_V7_SOURCE "${CBOE_ANDROID_WINUTIL_V7_SOURCE}")

# The first quick-action pass enabled SAVE/LOAD outdoors only. OpenBoE's normal
# save path permits a normal town state as well and rejects combat itself. Keep
# the mobile buttons aligned with those normal gameplay states.
set(CBOE_ANDROID_V7_SAVE_AVAIL_OLD [=[        case ANDROID_QUICK_SAVE:
        case ANDROID_QUICK_LOAD:
            return overall_mode == MODE_OUTDOORS;]=])
set(CBOE_ANDROID_V7_SAVE_AVAIL_NEW [=[        case ANDROID_QUICK_SAVE:
        case ANDROID_QUICK_LOAD:
            return overall_mode == MODE_OUTDOORS || overall_mode == MODE_TOWN;]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V7_SOURCE}" "${CBOE_ANDROID_V7_SAVE_AVAIL_OLD}" CBOE_ANDROID_V7_SAVE_AVAIL_POS)
if(CBOE_ANDROID_V7_SAVE_AVAIL_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android v4 SAVE/LOAD availability block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V7_SAVE_AVAIL_OLD}" "${CBOE_ANDROID_V7_SAVE_AVAIL_NEW}" CBOE_ANDROID_WINUTIL_V7_SOURCE "${CBOE_ANDROID_WINUTIL_V7_SOURCE}")

set(CBOE_ANDROID_V7_SAVE_DISPATCH_OLD [=[        case ANDROID_QUICK_SAVE:
            if(overall_mode == MODE_OUTDOORS) do_save(); else handled = false;
            break;
        case ANDROID_QUICK_LOAD:
            if(overall_mode == MODE_OUTDOORS) do_load(); else handled = false;
            break;]=])
set(CBOE_ANDROID_V7_SAVE_DISPATCH_NEW [=[        case ANDROID_QUICK_SAVE:
            if(overall_mode == MODE_OUTDOORS || overall_mode == MODE_TOWN) do_save(); else handled = false;
            break;
        case ANDROID_QUICK_LOAD:
            if(overall_mode == MODE_OUTDOORS || overall_mode == MODE_TOWN) do_load(); else handled = false;
            break;]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V7_SOURCE}" "${CBOE_ANDROID_V7_SAVE_DISPATCH_OLD}" CBOE_ANDROID_V7_SAVE_DISPATCH_POS)
if(CBOE_ANDROID_V7_SAVE_DISPATCH_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android v4 SAVE/LOAD dispatch block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V7_SAVE_DISPATCH_OLD}" "${CBOE_ANDROID_V7_SAVE_DISPATCH_NEW}" CBOE_ANDROID_WINUTIL_V7_SOURCE "${CBOE_ANDROID_WINUTIL_V7_SOURCE}")

file(WRITE "${CBOE_ANDROID_WINUTIL_V7_CPP}" "${CBOE_ANDROID_WINUTIL_V7_SOURCE}")
message(STATUS "Applied Android mobile UI v7 PC-info and SAVE/LOAD fixes")
