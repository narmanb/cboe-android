# Codeberg migration v28: preserve legacy door balance while supporting the
# corrected town-difficulty behavior for scenarios that explicitly opt in.
if(DEFINED CBOE_ANDROID_CODEBERG_V28_APPLIED)
    return()
endif()
set(CBOE_ANDROID_CODEBERG_V28_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_V28_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(V28_MAIN_CPP "${CBOE_ANDROID_V28_ROOT}/src/game/boe.main.cpp")
set(V28_TOWN_CPP "${CBOE_ANDROID_V28_ROOT}/src/game/boe.town.cpp")
set(V28_UNIVERSE_HPP "${CBOE_ANDROID_V28_ROOT}/src/universe/universe.hpp")
set(V28_UNIVERSE_CPP "${CBOE_ANDROID_V28_ROOT}/src/universe/universe.cpp")

# Advertise support for the Codeberg feature flag so scenarios created by the
# newer editor are accepted by the Android game.
file(READ "${V28_MAIN_CPP}" V28_MAIN)
set(V28_FLAGS_OLD [=[	// Game balance
	{"magic-resistance", {"fixed"}} // Resist Magic used to not help with magic damage!]=])
set(V28_FLAGS_NEW [=[	// Game balance
	{"magic-resistance", {"fixed"}}, // Resist Magic used to not help with magic damage!
	{"door-town-difficulty", {"fixed"}}]=])
string(FIND "${V28_MAIN}" "${V28_FLAGS_OLD}" V28_FLAGS_POS)
if(V28_FLAGS_POS EQUAL -1)
    message(FATAL_ERROR "v28: expected feature-flag table anchor not found")
endif()
string(REPLACE "${V28_FLAGS_OLD}" "${V28_FLAGS_NEW}" V28_MAIN "${V28_MAIN}")
file(WRITE "${V28_MAIN_CPP}" "${V28_MAIN}")

# Add the same cCurTown helper used by Codeberg. Old/legacy scenarios have no
# feature flag, so their historical door balance remains unchanged; scenarios
# with door-town-difficulty=fixed use the town difficulty value.
file(READ "${V28_UNIVERSE_HPP}" V28_UHPP)
set(V28_DECL_OLD [=[	void import_legacy(legacy::big_tr_type& old);
	
	cTown* operator -> ();]=])
set(V28_DECL_NEW [=[	void import_legacy(legacy::big_tr_type& old);
	
	int door_diff_adjust();
	cTown* operator -> ();]=])
string(FIND "${V28_UHPP}" "${V28_DECL_OLD}" V28_DECL_POS)
if(V28_DECL_POS EQUAL -1)
    message(FATAL_ERROR "v28: expected cCurTown declaration anchor not found")
endif()
string(REPLACE "${V28_DECL_OLD}" "${V28_DECL_NEW}" V28_UHPP "${V28_UHPP}")
file(WRITE "${V28_UNIVERSE_HPP}" "${V28_UHPP}")

file(READ "${V28_UNIVERSE_CPP}" V28_UCPP)
set(V28_IMPL_OLD [=[const cTown& cCurTown::operator * () const {
	return *record();
}

void cCurTown::place_preset_fields() {]=])
set(V28_IMPL_NEW [=[const cTown& cCurTown::operator * () const {
	return *record();
}

int cCurTown::door_diff_adjust() {
	return univ.scenario.has_feature_flag("door-town-difficulty") ? arena->difficulty : 0;
}

void cCurTown::place_preset_fields() {]=])
string(FIND "${V28_UCPP}" "${V28_IMPL_OLD}" V28_IMPL_POS)
if(V28_IMPL_POS EQUAL -1)
    message(FATAL_ERROR "v28: expected cCurTown implementation anchor not found")
endif()
string(REPLACE "${V28_IMPL_OLD}" "${V28_IMPL_NEW}" V28_UCPP "${V28_UCPP}")
file(WRITE "${V28_UNIVERSE_CPP}" "${V28_UCPP}")

# Route lockpicking and bashing through the compatibility helper.
file(READ "${V28_TOWN_CPP}" V28_TOWN)
set(V28_PICK_OLD [=[+ univ.town->difficulty * 7]=])
set(V28_PICK_NEW [=[+ univ.town.door_diff_adjust() * 7]=])
string(FIND "${V28_TOWN}" "${V28_PICK_OLD}" V28_PICK_POS)
if(V28_PICK_POS EQUAL -1)
    message(FATAL_ERROR "v28: expected lockpick town-difficulty expression not found")
endif()
string(REPLACE "${V28_PICK_OLD}" "${V28_PICK_NEW}" V28_TOWN "${V28_TOWN}")

set(V28_BASH_OLD [=[+ univ.town->difficulty * 4]=])
set(V28_BASH_NEW [=[+ univ.town.door_diff_adjust() * 4]=])
string(FIND "${V28_TOWN}" "${V28_BASH_OLD}" V28_BASH_POS)
if(V28_BASH_POS EQUAL -1)
    message(FATAL_ERROR "v28: expected bash-door town-difficulty expression not found")
endif()
string(REPLACE "${V28_BASH_OLD}" "${V28_BASH_NEW}" V28_TOWN "${V28_TOWN}")
file(WRITE "${V28_TOWN_CPP}" "${V28_TOWN}")

message(STATUS "Applied Codeberg door-town-difficulty compatibility feature")
