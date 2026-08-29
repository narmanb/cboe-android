# Codeberg migration v32: bring the outdoor-combat arena model in line with
# current upstream. The temporary arena is 26x26 instead of a 48x48 medium-town
# shell, and terrain/spawn coordinates are shifted together as one subsystem.
if(DEFINED CBOE_ANDROID_CODEBERG_V32_APPLIED)
    return()
endif()
set(CBOE_ANDROID_CODEBERG_V32_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_V32_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(V32_UNIVERSE_HPP "${CBOE_ANDROID_V32_ROOT}/src/universe/universe.hpp")
set(V32_UNIVERSE_CPP "${CBOE_ANDROID_V32_ROOT}/src/universe/universe.cpp")
set(V32_COMBAT_CPP "${CBOE_ANDROID_V32_ROOT}/src/game/boe.combat.cpp")
set(V32_TOWN_CPP "${CBOE_ANDROID_V32_ROOT}/src/game/boe.town.cpp")

# cCurTown: upstream gives temporary combat arenas an explicit 26x26 size.
file(READ "${V32_UNIVERSE_HPP}" V32_UHPP)
set(V32_ARENA_DECL_OLD [=[	vector2d<unsigned long> fields;
public:
	bool quickfire_present = false, belt_present = false;]=])
set(V32_ARENA_DECL_NEW [=[	vector2d<unsigned long> fields;
public:
	static const size_t ARENA_SIZE = 26;
	bool quickfire_present = false, belt_present = false;]=])
string(FIND "${V32_UHPP}" "${V32_ARENA_DECL_OLD}" V32_ARENA_DECL_POS)
if(V32_ARENA_DECL_POS EQUAL -1)
    message(FATAL_ERROR "v32: cCurTown arena-size declaration anchor not found")
endif()
string(REPLACE "${V32_ARENA_DECL_OLD}" "${V32_ARENA_DECL_NEW}" V32_UHPP "${V32_UHPP}")
file(WRITE "${V32_UNIVERSE_HPP}" "${V32_UHPP}")

file(READ "${V32_UNIVERSE_CPP}" V32_UCPP)
set(V32_PREP_OLD [=[void cCurTown::prep_arena() {
	if(arena != nullptr) delete arena;
	arena = new cTown(univ.scenario, AREA_MEDIUM);
	fields.resize(AREA_MEDIUM, AREA_MEDIUM);
	fields.fill(0);
}]=])
set(V32_PREP_NEW [=[void cCurTown::prep_arena() {
	if(arena != nullptr) delete arena;
	arena = new cTown(univ.scenario, ARENA_SIZE);
	arena->in_town_rect = rect(0, 0, ARENA_SIZE - 1, ARENA_SIZE - 1);
	fields.resize(ARENA_SIZE, ARENA_SIZE);
	fields.fill(0);
}]=])
string(FIND "${V32_UCPP}" "${V32_PREP_OLD}" V32_PREP_POS)
if(V32_PREP_POS EQUAL -1)
    message(FATAL_ERROR "v32: prep_arena anchor not found")
endif()
string(REPLACE "${V32_PREP_OLD}" "${V32_PREP_NEW}" V32_UCPP "${V32_UCPP}")
file(WRITE "${V32_UNIVERSE_CPP}" "${V32_UCPP}")

# Outdoor combat PCs/monsters must move with the smaller arena.
file(READ "${V32_COMBAT_CPP}" V32_COMBAT)
set(V32_START_OLD [=[location out_start_loc(20,23);]=])
set(V32_START_NEW [=[location out_start_loc(11,14);]=])
string(FIND "${V32_COMBAT}" "${V32_START_OLD}" V32_START_POS)
if(V32_START_POS EQUAL -1)
    message(FATAL_ERROR "v32: outdoor PC start anchor not found")
endif()
string(REPLACE "${V32_START_OLD}" "${V32_START_NEW}" V32_COMBAT "${V32_COMBAT}")

set(V32_MON_X_OLD [=[get_ran(1,15,25)]=])
set(V32_MON_X_NEW [=[get_ran(1,6,16)]=])
set(V32_MON_Y_OLD [=[get_ran(1,14,18)]=])
set(V32_MON_Y_NEW [=[get_ran(1,5,9)]=])
string(FIND "${V32_COMBAT}" "${V32_MON_X_OLD}" V32_MON_X_POS)
string(FIND "${V32_COMBAT}" "${V32_MON_Y_OLD}" V32_MON_Y_POS)
if(V32_MON_X_POS EQUAL -1 OR V32_MON_Y_POS EQUAL -1)
    message(FATAL_ERROR "v32: outdoor monster placement anchors not found")
endif()
string(REPLACE "${V32_MON_X_OLD}" "${V32_MON_X_NEW}" V32_COMBAT "${V32_COMBAT}")
string(REPLACE "${V32_MON_Y_OLD}" "${V32_MON_Y_NEW}" V32_COMBAT "${V32_COMBAT}")
file(WRITE "${V32_COMBAT_CPP}" "${V32_COMBAT}")

file(READ "${V32_TOWN_CPP}" V32_TOWN)

# Feature-placement grid recentered into 26x26.
set(V32_FEATURE_OLD [=[	static const location special_ter_locs[15] = {
		loc(11,10),loc(11,14),loc(10,20),loc(11,26),loc(9,30),
		loc(15,19),loc(23,19),loc(19,29),loc(20,11),loc(28,16),
		loc(28,24),loc(27,19),loc(27,29),loc(15,28),loc(19,19),
	};]=])
set(V32_FEATURE_NEW [=[	static const location special_ter_locs[15] = {
		loc(2,1),loc(2,5),loc(1,11),loc(2,17),loc(0,21),
		loc(6,10),loc(14,10),loc(10,20),loc(11,2),loc(19,7),
		loc(19,15),loc(18,10),loc(18,20),loc(6,19),loc(10,10),
	};]=])
string(FIND "${V32_TOWN}" "${V32_FEATURE_OLD}" V32_FEATURE_POS)
if(V32_FEATURE_POS EQUAL -1)
    message(FATAL_ERROR "v32: special terrain locations anchor not found")
endif()
string(REPLACE "${V32_FEATURE_OLD}" "${V32_FEATURE_NEW}" V32_TOWN "${V32_TOWN}")

# Custom-town combat arenas: copy only the portion that fits the actual arena.
set(V32_CUSTOM_OLD [=[		// Furthermore, if it's a large town, we drop the outer 8 tiles.
		size_t town_size = univ.scenario.towns[arena]->max_dim();
		int offset = max(0,town_size - 48);
		rectangle town_bounds = univ.scenario.towns[arena]->in_town_rect;
		// Just in case the town boundary is somehow larger than the town...
		town_bounds.left = minmax(0,town_size - 1, town_bounds.left);
		town_bounds.right = minmax(0,town_size - 1, town_bounds.right);
		town_bounds.top = minmax(0,town_size - 1, town_bounds.top);
		town_bounds.bottom = minmax(0,town_size - 1, town_bounds.bottom);
		for(short i = 0; i < 48; i++)
			for(short j = 0; j < 48; j++) {
				// This test also accounts for small towns since the town boundary is never larger than the town
				if(town_bounds.contains(i + offset, j + offset))
					univ.town->terrain(i,j) = univ.scenario.towns[arena]->terrain(i + offset,j + offset);
				else univ.town->terrain(i,j) = 90;
			}]=])
set(V32_CUSTOM_NEW [=[		// Furthermore, if it's a large or medium town, we drop the outer ring of tiles.
		size_t town_size = univ.scenario.towns[arena]->max_dim();
		int offset = max(0,town_size - univ.town->max_dim());
		rectangle town_bounds = univ.scenario.towns[arena]->in_town_rect;
		// Just in case the town boundary is somehow larger than the town...
		town_bounds.left = minmax(0,town_size - 1, town_bounds.left);
		town_bounds.right = minmax(0,town_size - 1, town_bounds.right);
		town_bounds.top = minmax(0,town_size - 1, town_bounds.top);
		town_bounds.bottom = minmax(0,town_size - 1, town_bounds.bottom);
		for(short i = 0; i < univ.town->max_dim(); i++)
			for(short j = 0; j < univ.town->max_dim(); j++) {
				// This test also accounts for small towns since the town boundary is never larger than the town
				if(town_bounds.contains(i + offset, j + offset)) {
					int x = i - town_bounds.left;
					int y = j - town_bounds.top;
					univ.town->terrain(x,y) = univ.scenario.towns[arena]->terrain(i + offset,j + offset);
				}
			}]=])
string(FIND "${V32_TOWN}" "${V32_CUSTOM_OLD}" V32_CUSTOM_POS)
if(V32_CUSTOM_POS EQUAL -1)
    message(FATAL_ERROR "v32: custom combat arena copy anchor not found")
endif()
string(REPLACE "${V32_CUSTOM_OLD}" "${V32_CUSTOM_NEW}" V32_TOWN "${V32_TOWN}")

# Base terrain now fills the real arena instead of a 26x26 island inside 48x48.
set(V32_FILL_OLD [=[	for(short i = 0; i < 48; i++)
		for(short j = 0; j < 48; j++) {
			if((j <= 8) || (j >= 35) || (i <= 8) || (i >= 35))
				univ.town->terrain(i,j) = 90;
			else univ.town->terrain(i,j) = ter_base[arena];
		}
	for(short i = 0; i < 48; i++)
		for(short j = 0; j < 48; j++)
			for(short k = 0; k < 5; k++)
				if((univ.town->terrain(i,j) != 90) && (get_ran(1,1,1000) < terrain_odds[arena][k * 2 + 1]))
					univ.town->terrain(i,j) = terrain_odds[arena][k * 2];]=])
set(V32_FILL_NEW [=[	for(short i = 0; i < univ.town->max_dim(); i++)
		for(short j = 0; j < univ.town->max_dim(); j++) {
			univ.town->terrain(i,j) = ter_base[arena];
		}
	for(short i = 0; i < univ.town->max_dim(); i++)
		for(short j = 0; j < univ.town->max_dim(); j++)
			for(short k = 0; k < 5; k++)
				if((get_ran(1,1,1000) < terrain_odds[arena][k * 2 + 1]))
					univ.town->terrain(i,j) = terrain_odds[arena][k * 2];]=])
string(FIND "${V32_TOWN}" "${V32_FILL_OLD}" V32_FILL_POS)
if(V32_FILL_POS EQUAL -1)
    message(FATAL_ERROR "v32: base arena fill anchor not found")
endif()
string(REPLACE "${V32_FILL_OLD}" "${V32_FILL_NEW}" V32_TOWN "${V32_TOWN}")

# Roads and bridges shifted to the smaller coordinate space.
set(V32_ROAD_OLD [=[	if(arena == 3 || (is_road && surface_arenas.count(arena))) {
		univ.town->terrain(0,0) = 83;
		for(short i = (is_bridge ? 15 : 19); i < (is_bridge ? 26 : 23); i++)
			for(short j = 9; j < 35; j++)
				univ.town->terrain(i,j) = 83;
	}
	if(arena == 4 || (is_road && cave_arenas.count(arena))) {
		univ.town->terrain(0,0) = 82;
		for(short i = (is_bridge ? 15 : 19); i < (is_bridge ? 26 : 23); i++)
			for(short j = 9; j < 35; j++)
				univ.town->terrain(i,j) = 82;
	}]=])
set(V32_ROAD_NEW [=[	if(arena == 3 || (is_road && surface_arenas.count(arena))) {
		univ.town->terrain(0,0) = 83;
		for(short i = (is_bridge ? 6 : 10); i < (is_bridge ? 17 : 14); i++)
			for(short j = 0; j < univ.town->max_dim(); j++)
				univ.town->terrain(i,j) = 83;
	}
	if(arena == 4 || (is_road && cave_arenas.count(arena))) {
		univ.town->terrain(0,0) = 82;
		for(short i = (is_bridge ? 6 : 10); i < (is_bridge ? 17 : 14); i++)
			for(short j = 0; j < univ.town->max_dim(); j++)
				univ.town->terrain(i,j) = 82;
	}]=])
string(FIND "${V32_TOWN}" "${V32_ROAD_OLD}" V32_ROAD_POS)
if(V32_ROAD_POS EQUAL -1)
    message(FATAL_ERROR "v32: arena road anchor not found")
endif()
string(REPLACE "${V32_ROAD_OLD}" "${V32_ROAD_NEW}" V32_TOWN "${V32_TOWN}")

# Crop rows shifted by nine tiles in both axes.
set(V32_CROP_OLD [=[	if(arena == 18 || arena == 19) {
		for(short i = 12; i < 15; i++)
			for(short j = 9; j < 35; j++)
				if(j != 17 && j != 26)
					univ.town->terrain(i,j) = ter_type;
		for(short i = 17; i < 20; i++)
			for(short j = 9; j < 35; j++)
				if(j != 17 && j != 26)
					univ.town->terrain(i,j) = ter_type;
		for(short i = 22; i < 25; i++)
			for(short j = 9; j < 35; j++)
				if(j != 17 && j != 26)
					univ.town->terrain(i,j) = ter_type;
		for(short i = 27; i < 30; i++)
			for(short j = 9; j < 35; j++)
				if(j != 17 && j != 26)
					univ.town->terrain(i,j) = ter_type;
	}]=])
set(V32_CROP_NEW [=[	if(arena == 18 || arena == 19) {
		for(short i = 3; i < 6; i++)
			for(short j = 0; j < univ.town->max_dim(); j++)
				if(j != 8 && j != 17)
					univ.town->terrain(i,j) = ter_type;
		for(short i = 8; i < 11; i++)
			for(short j = 0; j < univ.town->max_dim(); j++)
				if(j != 8 && j != 17)
					univ.town->terrain(i,j) = ter_type;
		for(short i = 13; i < 16; i++)
			for(short j = 0; j < univ.town->max_dim(); j++)
				if(j != 8 && j != 17)
					univ.town->terrain(i,j) = ter_type;
		for(short i = 18; i < 21; i++)
			for(short j = 0; j < univ.town->max_dim(); j++)
				if(j != 8 && j != 17)
					univ.town->terrain(i,j) = ter_type;
	}]=])
string(FIND "${V32_TOWN}" "${V32_CROP_OLD}" V32_CROP_POS)
if(V32_CROP_POS EQUAL -1)
    message(FATAL_ERROR "v32: crop arena anchor not found")
endif()
string(REPLACE "${V32_CROP_OLD}" "${V32_CROP_NEW}" V32_TOWN "${V32_TOWN}")

# Camp decorations follow the same -9,-9 translation.
set(V32_CAMP_OLD [=[	if(arena == 16) {
		stuff_ul = loc(18,14);
		for(short j = 0; j < 4; j++)
			for(short k = 0; k < 4; k++)
				univ.town->terrain(stuff_ul.x + j,stuff_ul.y + k) = cave_camp[k][j];
	}
	if(arena == 17) {
		stuff_ul = loc(18,14);
		for(short j = 0; j < 4; j++)
			for(short k = 0; k < 4; k++)
				univ.town->terrain(stuff_ul.x + j,stuff_ul.y + k) = surf_camp[k][j];
	}]=])
set(V32_CAMP_NEW [=[	if(arena == 16) {
		stuff_ul = loc(9,5);
		for(short j = 0; j < 4; j++)
			for(short k = 0; k < 4; k++)
				univ.town->terrain(stuff_ul.x + j,stuff_ul.y + k) = cave_camp[k][j];
	}
	if(arena == 17) {
		stuff_ul = loc(9,5);
		for(short j = 0; j < 4; j++)
			for(short k = 0; k < 4; k++)
				univ.town->terrain(stuff_ul.x + j,stuff_ul.y + k) = surf_camp[k][j];
	}]=])
string(FIND "${V32_TOWN}" "${V32_CAMP_OLD}" V32_CAMP_POS)
if(V32_CAMP_POS EQUAL -1)
    message(FATAL_ERROR "v32: camp arena anchor not found")
endif()
string(REPLACE "${V32_CAMP_OLD}" "${V32_CAMP_NEW}" V32_TOWN "${V32_TOWN}")

# Natural/cave edge walls now occupy the actual 0/25 arena boundary. Upstream
# also corrects the cave corner tests to use cave wall terrain IDs.
set(V32_WALL_OLD [=[	if(ter_base[ter_type] == 0) {
		for(short i = 0; i < num_walls; i++) {
			r1 = get_ran(1,0,3);
			for(short j = 9; j < 35; j++)
				switch(r1) {
					case 0:
						univ.town->terrain(j,8) = 6;
						break;
					case 1:
						univ.town->terrain(8,j) = 9;
						break;
					case 2:
						univ.town->terrain(j,35) = 12;
						break;
					case 3:
						univ.town->terrain(32,j) = 15;
						break;
				}
		}
		if((univ.town->terrain(17,8) == 6) && (univ.town->terrain(8,20) == 9))
			univ.town->terrain(8,8) = 21;
		if((univ.town->terrain(32,20) == 15) && (univ.town->terrain(17,35) == 12))
			univ.town->terrain(32,35) = 19;
		if((univ.town->terrain(17,8) == 6) && (univ.town->terrain(32,20) == 15))
			univ.town->terrain(32,8) = 32;
		if((univ.town->terrain(8,20) == 9) && (univ.town->terrain(17,35) == 12))
			univ.town->terrain(8,35) = 20;
	}
	if(ter_base[ter_type] == 36) {
		for(short i = 0; i < num_walls; i++) {
			r1 = get_ran(1,0,3);
			for(short j = 9; j < 35; j++)
				switch(r1) {
					case 0:
						univ.town->terrain(j,8) = 24;
						break;
					case 1:
						univ.town->terrain(8,j) = 26;
						break;
					case 2:
						univ.town->terrain(j,35) = 28;
						break;
					case 3:
						univ.town->terrain(32,j) = 30;
						break;
				}
		}
		if((univ.town->terrain(17,8) == 6) && (univ.town->terrain(8,20) == 9))
			univ.town->terrain(8,8) = 35;
		if((univ.town->terrain(32,20) == 15) && (univ.town->terrain(17,35) == 12))
			univ.town->terrain(32,35) = 33;
		if((univ.town->terrain(17,8) == 6) && (univ.town->terrain(32,20) == 15))
			univ.town->terrain(32,8) = 32;
		if((univ.town->terrain(8,20) == 9) && (univ.town->terrain(17,35) == 12))
			univ.town->terrain(8,35) = 34;
	}]=])
set(V32_WALL_NEW [=[	if(ter_base[arena] == 0) {
		for(short i = 0; i < num_walls; i++) {
			r1 = get_ran(1,0,3);
			for(short j = 0; j < univ.town->max_dim(); j++)
				switch(r1) {
					case 0:
						univ.town->terrain(j,0) = 6;
						break;
					case 1:
						univ.town->terrain(0,j) = 9;
						break;
					case 2:
						univ.town->terrain(j,25) = 12;
						break;
					case 3:
						univ.town->terrain(25,j) = 15;
						break;
				}
		}
		if((univ.town->terrain(17,0) == 6) && (univ.town->terrain(0,20) == 9))
			univ.town->terrain(0,0) = 21;
		if((univ.town->terrain(25,20) == 15) && (univ.town->terrain(17,25) == 12))
			univ.town->terrain(25,25) = 19;
		if((univ.town->terrain(17,0) == 6) && (univ.town->terrain(25,20) == 15))
			univ.town->terrain(25,0) = 32;
		if((univ.town->terrain(0,20) == 9) && (univ.town->terrain(17,25) == 12))
			univ.town->terrain(0,25) = 20;
	}
	if(ter_base[arena] == 36) {
		for(short i = 0; i < num_walls; i++) {
			r1 = get_ran(1,0,3);
			for(short j = 0; j < univ.town->max_dim(); j++)
				switch(r1) {
					case 0:
						univ.town->terrain(j,0) = 24;
						break;
					case 1:
						univ.town->terrain(0,j) = 26;
						break;
					case 2:
						univ.town->terrain(j,25) = 28;
						break;
					case 3:
						univ.town->terrain(25,j) = 30;
						break;
				}
		}
		if((univ.town->terrain(17,0) == 24) && (univ.town->terrain(0,20) == 26))
			univ.town->terrain(0,0) = 35;
		if((univ.town->terrain(25,20) == 30) && (univ.town->terrain(17,25) == 28))
			univ.town->terrain(25,25) = 33;
		if((univ.town->terrain(17,0) == 24) && (univ.town->terrain(25,20) == 30))
			univ.town->terrain(25,0) = 32;
		if((univ.town->terrain(0,20) == 26) && (univ.town->terrain(17,25) == 28))
			univ.town->terrain(0,25) = 34;
	}]=])
string(FIND "${V32_TOWN}" "${V32_WALL_OLD}" V32_WALL_POS)
if(V32_WALL_POS EQUAL -1)
    message(FATAL_ERROR "v32: arena wall-generation anchor not found")
endif()
string(REPLACE "${V32_WALL_OLD}" "${V32_WALL_NEW}" V32_TOWN "${V32_TOWN}")

file(WRITE "${V32_TOWN_CPP}" "${V32_TOWN}")
message(STATUS "Applied Codeberg 26x26 outdoor-combat arena migration")
