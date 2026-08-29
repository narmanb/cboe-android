# Compatibility follow-up for Android mobile UI v9 after the Codeberg max_dim()
# API migration. v9's original town exploration replacement still searches for
# `univ.town->max_dim` and therefore silently stopped matching once that became
# `univ.town->max_dim()`. Keep the 11-column viewport and exploration window in sync.
if(DEFINED CBOE_ANDROID_MOBILE_UI_V9_MAXDIM_FIX_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_V9_MAXDIM_FIX_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_V9_MAXDIM_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(V9_MAXDIM_LOCUTILS "${CBOE_ANDROID_V9_MAXDIM_ROOT}/src/game/boe.locutils.cpp")
file(READ "${V9_MAXDIM_LOCUTILS}" V9_MAXDIM_TEXT)

set(V9_MAXDIM_OLD [=[		for(look.x = max(0,dest.x - 4); look.x < min(univ.town->max_dim(),dest.x + 5); look.x++)]=])
set(V9_MAXDIM_NEW [=[		for(look.x = max(0,dest.x - 5); look.x < min(univ.town->max_dim(),dest.x + 6); look.x++)]=])
string(FIND "${V9_MAXDIM_TEXT}" "${V9_MAXDIM_OLD}" V9_MAXDIM_POS)
if(V9_MAXDIM_POS EQUAL -1)
    message(FATAL_ERROR "v9 max_dim compatibility: expected town exploration loop not found")
endif()
string(REPLACE "${V9_MAXDIM_OLD}" "${V9_MAXDIM_NEW}" V9_MAXDIM_TEXT "${V9_MAXDIM_TEXT}")
file(WRITE "${V9_MAXDIM_LOCUTILS}" "${V9_MAXDIM_TEXT}")

message(STATUS "Restored Android 11-column town exploration window after max_dim() migration")
