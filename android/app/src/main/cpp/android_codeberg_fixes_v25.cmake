# Android Codeberg migration v25: clear cached town monsters when a scenario ends.
# This ports the small upstream safety fix without replacing boe.actions.cpp,
# which contains Android-specific input changes and other unrelated upstream refactors.
if(DEFINED CBOE_ANDROID_CODEBERG_V25_APPLIED)
    return()
endif()
set(CBOE_ANDROID_CODEBERG_V25_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_V25_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V25_ACTIONS_CPP "${CBOE_ANDROID_V25_ROOT}/src/game/boe.actions.cpp")
file(READ "${CBOE_ANDROID_V25_ACTIONS_CPP}" V25_ACTIONS)

set(V25_OLD [=[	univ.exportGraphics();
	univ.exportSummons();
	univ.clear_stored_pcs();
	reload_startup();]=])
set(V25_NEW [=[	univ.exportGraphics();
	univ.exportSummons();
	univ.clear_stored_pcs();
	// Saved town populations belong to the scenario that just ended. Leaving
	// them attached to the party can make a later scenario with the same town
	// number restore monsters from the wrong scenario.
	for(auto& pop : univ.party.creature_save) {
		pop.which_town = 200;
		pop.clear();
	}
	reload_startup();]=])

string(FIND "${V25_ACTIONS}" "${V25_OLD}" V25_POS)
if(V25_POS EQUAL -1)
    message(FATAL_ERROR "v25: expected handle_victory cleanup anchor not found")
endif()
string(REPLACE "${V25_OLD}" "${V25_NEW}" V25_ACTIONS "${V25_ACTIONS}")
file(WRITE "${CBOE_ANDROID_V25_ACTIONS_CPP}" "${V25_ACTIONS}")
message(STATUS "Applied Codeberg scenario-exit cached-monster cleanup")
