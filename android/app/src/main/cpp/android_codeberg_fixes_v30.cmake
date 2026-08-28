# Codeberg migration v30: use the legacy >70 off-grid convention only for
# legacy scenarios. Modern scenarios use the explicit LOC_UNUSED sentinel.
# Keep this surgical because Android's widened renderer still intentionally
# carries the older spot_seen-based graphutil path that Codeberg removed.
if(DEFINED CBOE_ANDROID_CODEBERG_V30_APPLIED)
    return()
endif()
set(CBOE_ANDROID_CODEBERG_V30_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_V30_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(V30_GRAPHUTIL_CPP "${CBOE_ANDROID_V30_ROOT}/src/game/boe.graphutil.cpp")
file(READ "${V30_GRAPHUTIL_CPP}" V30_GRAPHUTIL)

set(V30_PARTY_HIDE_OLD [=[if((is_town()) && (univ.party.town_loc.x > 70))]=])
set(V30_PARTY_HIDE_NEW [=[if((is_town()) && (univ.party.town_loc.x > (univ.scenario.is_legacy ? 70 : LOC_UNUSED)))]=])
string(FIND "${V30_GRAPHUTIL}" "${V30_PARTY_HIDE_OLD}" V30_PARTY_HIDE_POS)
if(V30_PARTY_HIDE_POS EQUAL -1)
    message(FATAL_ERROR "v30: expected legacy party off-map threshold not found")
endif()
string(REPLACE "${V30_PARTY_HIDE_OLD}" "${V30_PARTY_HIDE_NEW}" V30_GRAPHUTIL "${V30_GRAPHUTIL}")
file(WRITE "${V30_GRAPHUTIL_CPP}" "${V30_GRAPHUTIL}")

message(STATUS "Applied Codeberg modern party off-map sentinel without replacing Android graphutil rendering")
