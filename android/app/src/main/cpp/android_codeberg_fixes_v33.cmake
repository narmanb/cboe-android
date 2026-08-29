# Codeberg migration v33: use real combat-arena bounds for player movement.
# Outdoor combat can flee by stepping off the arena; town combat reports the
# world edge. This must run after the 26x26 arena migration in v32 so it never
# dereferences terrain outside the smaller Android combat arena.
if(DEFINED CBOE_ANDROID_CODEBERG_V33_APPLIED)
    return()
endif()
set(CBOE_ANDROID_CODEBERG_V33_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_V33_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(V33_COMBAT_CPP "${CBOE_ANDROID_V33_ROOT}/src/game/boe.combat.cpp")
file(READ "${V33_COMBAT_CPP}" V33_COMBAT)

set(V33_BOUNDS_ANCHOR [=[	location monst_loc,store_loc;
	eDirection dir;
	
	iLiving* monst_hit = univ.target_there(destination, TARG_MONST);]=])
set(V33_BOUNDS_REPLACEMENT [=[	location monst_loc,store_loc;
	eDirection dir;
	
	if(!univ.town.is_on_map(destination.x, destination.y)) {
		if(which_combat_type == 0) {
			if(univ.debug_mode || get_ran(1,1,10) < 3) {
				univ.current_pc().main_status = eMainStatus::FLED;
				if(combat_active_pc == univ.cur_pc)
					combat_active_pc = 6;
				create_line = "Moved: Fled.";
				univ.current_pc().ap = 0;
			}
			else {
				take_ap(1);
				create_line = "Moved: Couldn't flee.";
			}
			add_string_to_buf(create_line);
			return true;
		}
		add_string_to_buf("Move: You've reached the world's edge.");
		return false;
	}
	
	iLiving* monst_hit = univ.target_there(destination, TARG_MONST);]=])
string(FIND "${V33_COMBAT}" "${V33_BOUNDS_ANCHOR}" V33_BOUNDS_POS)
if(V33_BOUNDS_POS EQUAL -1)
    message(FATAL_ERROR "v33: pc_combat_move bounds insertion anchor not found")
endif()
string(REPLACE "${V33_BOUNDS_ANCHOR}" "${V33_BOUNDS_REPLACEMENT}" V33_COMBAT "${V33_COMBAT}")

set(V33_OLD_FLEE [=[		else if(univ.town->terrain(destination.x,destination.y) == 90 && which_combat_type == 0) {
			if(get_ran(1,1,10) < 3) {
				univ.current_pc().main_status = eMainStatus::FLED;
				if(combat_active_pc == univ.cur_pc)
					combat_active_pc = 6;
				create_line = "Moved: Fled.";
				univ.current_pc().ap = 0;
			}
			else {
				take_ap(1);
				create_line = "Moved: Couldn't flee.";
			}
			add_string_to_buf(create_line);
			return true;
		}
]=])
string(FIND "${V33_COMBAT}" "${V33_OLD_FLEE}" V33_OLD_FLEE_POS)
if(V33_OLD_FLEE_POS EQUAL -1)
    message(FATAL_ERROR "v33: legacy terrain-90 flee block not found")
endif()
string(REPLACE "${V33_OLD_FLEE}" "" V33_COMBAT "${V33_COMBAT}")

file(WRITE "${V33_COMBAT_CPP}" "${V33_COMBAT}")
message(STATUS "Applied Codeberg combat map-bounds flee/world-edge handling")
