# Compile-only dependency repair for the v5 explicit panel controls.
# v5 calls only two declarations that were being obtained by including
# boe.infodlg.hpp and boe.text.hpp directly in winutil.cpp. Those headers rely
# on broader game include ordering and are not safe standalone dependencies.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V5_COMPILEFIX_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V5_COMPILEFIX_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V5_FIX_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_WINUTIL_V5_FIX_CPP "${CBOE_ANDROID_UI_V5_FIX_ROOT}/src/tools/winutil.cpp")
file(READ "${CBOE_ANDROID_WINUTIL_V5_FIX_CPP}" CBOE_ANDROID_WINUTIL_V5_FIX_SOURCE)

set(CBOE_ANDROID_V5_UNSAFE_INCLUDES [=[#include "game/boe.consts.hpp"
#include "game/boe.actions.hpp"
#include "game/boe.infodlg.hpp"
#include "game/boe.text.hpp"
#include "gfx/render_text.hpp"
#include "dialogxml/dialogs/dialog.hpp"
#include "dialogxml/widgets/scrollbar.hpp"
#include "drawable_manager.hpp"]=])

set(CBOE_ANDROID_V5_SAFE_INCLUDES [=[#include "game/boe.consts.hpp"
#include "game/boe.actions.hpp"
#include "gfx/render_text.hpp"
#include "dialogxml/dialogs/dialog.hpp"
#include "dialogxml/widgets/scrollbar.hpp"
#include "drawable_manager.hpp"

// Minimal cross-TU declarations needed by the Android v5 panel dispatcher.
// Keep these local to the Android-generated winutil.cpp dependency surface.
void display_pc(short pc_num, short mode, cDialog* parent_num);
void set_stat_window(eItemWinMode new_stat, bool record);]=])

string(FIND "${CBOE_ANDROID_WINUTIL_V5_FIX_SOURCE}" "${CBOE_ANDROID_V5_UNSAFE_INCLUDES}" CBOE_ANDROID_V5_UNSAFE_INCLUDE_POS)
if(CBOE_ANDROID_V5_UNSAFE_INCLUDE_POS EQUAL -1)
    message(FATAL_ERROR "Expected v5 unsafe Android include block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V5_UNSAFE_INCLUDES}" "${CBOE_ANDROID_V5_SAFE_INCLUDES}" CBOE_ANDROID_WINUTIL_V5_FIX_SOURCE "${CBOE_ANDROID_WINUTIL_V5_FIX_SOURCE}")

file(WRITE "${CBOE_ANDROID_WINUTIL_V5_FIX_CPP}" "${CBOE_ANDROID_WINUTIL_V5_FIX_SOURCE}")
message(STATUS "Applied Android v5 minimal declaration compile fix")
