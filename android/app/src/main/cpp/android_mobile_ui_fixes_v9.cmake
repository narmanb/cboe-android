# Android real 11x9 terrain viewport experiment after v8.
# This is a renderer change, not an image stretch: the terrain RenderTexture is
# widened by two native 28px columns and the world centre moves from local x=4
# to x=5. Keep the existing 9-row height and native 28x36 tile geometry.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V9_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V9_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V9_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V9_GRAPHICS_CPP "${CBOE_ANDROID_UI_V9_ROOT}/src/game/boe.graphics.cpp")
set(CBOE_ANDROID_V9_GRAPHUTIL_CPP "${CBOE_ANDROID_UI_V9_ROOT}/src/game/boe.graphutil.cpp")
set(CBOE_ANDROID_V9_LOCUTILS_CPP "${CBOE_ANDROID_UI_V9_ROOT}/src/game/boe.locutils.cpp")
set(CBOE_ANDROID_V9_NEWGRAPH_CPP "${CBOE_ANDROID_UI_V9_ROOT}/src/game/boe.newgraph.cpp")
set(CBOE_ANDROID_V9_ACTIONS_CPP "${CBOE_ANDROID_UI_V9_ROOT}/src/game/boe.actions.cpp")
set(CBOE_ANDROID_V9_MAIN_CPP "${CBOE_ANDROID_UI_V9_ROOT}/src/game/boe.main.cpp")
set(CBOE_ANDROID_V9_UI_CPP "${CBOE_ANDROID_UI_V9_ROOT}/src/game/boe.ui.cpp")
set(CBOE_ANDROID_V9_WINUTIL_CPP "${CBOE_ANDROID_UI_V9_ROOT}/src/tools/winutil.cpp")

# ---------------------------------------------------------------------------
# boe.ui.cpp: widen the Android build's logical terrain rectangle by 56px.
# Stats/inventory may overlap this in the hidden legacy composition, but the
# Android shell independently composes those panels and consumes their touches.
# ---------------------------------------------------------------------------
file(READ "${CBOE_ANDROID_V9_UI_CPP}" V9_UI)
set(V9_UI_OLD [=[	{7,19,358,298},      // terrain view]=])
set(V9_UI_NEW [=[	{7,19,358,354},      // terrain view (Android 11x9: 335px wide)]=])
string(FIND "${V9_UI}" "${V9_UI_OLD}" V9_UI_POS)
if(V9_UI_POS EQUAL -1)
    message(FATAL_ERROR "v9: expected terrain UI rectangle not found")
endif()
string(REPLACE "${V9_UI_OLD}" "${V9_UI_NEW}" V9_UI "${V9_UI}")
file(WRITE "${CBOE_ANDROID_V9_UI_CPP}" "${V9_UI}")

# ---------------------------------------------------------------------------
# boe.graphics.cpp: widen the terrain texture/frame, render 11 columns, widen
# clips, keep target overlays/rest screen aligned, and resize spot_seen.
# ---------------------------------------------------------------------------
file(READ "${CBOE_ANDROID_V9_GRAPHICS_CPP}" V9_GRAPHICS)

set(V9_SPOT_OLD [=[char spot_seen[9][9];]=])
set(V9_SPOT_NEW [=[char spot_seen[11][9];]=])
string(FIND "${V9_GRAPHICS}" "${V9_SPOT_OLD}" V9_SPOT_POS)
if(V9_SPOT_POS EQUAL -1)
    message(FATAL_ERROR "v9: expected spot_seen declaration not found")
endif()
string(REPLACE "${V9_SPOT_OLD}" "${V9_SPOT_NEW}" V9_GRAPHICS "${V9_GRAPHICS}")

# Construct a 335x351 terrain frame from native, unscaled slices of terscreen.
# 335 = 13px left frame + 11*28px tiles + 14px right frame.
set(V9_TERRAIN_LOAD_OLD [=[	loadImageToRenderTexture(terrain_screen_gworld(), "terscreen");]=])
set(V9_TERRAIN_LOAD_NEW [=[	loadImageToRenderTexture(terrain_screen_gworld(), "terscreen");
	{
		const sf::Texture& android_terrain_frame = *ResMgr::graphics.get("terscreen");
		terrain_screen_gworld().create(335, 351);
		terrain_screen_gworld().clear(sf::Color::Black);

		// Preserve every frame/background pixel at native scale. The middle 56px
		// is tiled from the empty centre of the original frame; terrain itself is
		// subsequently rendered as two genuinely additional columns.
		rect_draw_some_item(android_terrain_frame, {0,0,351,13}, terrain_screen_gworld(), {0,0,351,13});
		rect_draw_some_item(android_terrain_frame, {0,13,351,265}, terrain_screen_gworld(), {0,13,351,265});
		rect_draw_some_item(android_terrain_frame, {0,13,351,69}, terrain_screen_gworld(), {0,265,351,321});
		rect_draw_some_item(android_terrain_frame, {0,265,351,279}, terrain_screen_gworld(), {0,321,351,335});
		terrain_screen_gworld().display();
	}]=])
string(FIND "${V9_GRAPHICS}" "${V9_TERRAIN_LOAD_OLD}" V9_TERRAIN_LOAD_POS)
if(V9_TERRAIN_LOAD_POS EQUAL -1)
    message(FATAL_ERROR "v9: expected terrain texture load not found")
endif()
string(REPLACE "${V9_TERRAIN_LOAD_OLD}" "${V9_TERRAIN_LOAD_NEW}" V9_GRAPHICS "${V9_GRAPHICS}")

set(V9_DRAW_LOOP_OLD [=[	for(short q = 0; q < 9; q++) {
		for(short r = 0; r < 9; r++) {
			where_draw = (is_out()) ? univ.party.out_loc : center;
			where_draw.x += q - 4;
			where_draw.y += r - 4;]=])
set(V9_DRAW_LOOP_NEW [=[	for(short q = 0; q < 11; q++) {
		for(short r = 0; r < 9; r++) {
			where_draw = (is_out()) ? univ.party.out_loc : center;
			where_draw.x += q - 5;
			where_draw.y += r - 4;]=])
string(FIND "${V9_GRAPHICS}" "${V9_DRAW_LOOP_OLD}" V9_DRAW_LOOP_POS)
if(V9_DRAW_LOOP_POS EQUAL -1)
    message(FATAL_ERROR "v9: expected 9x9 terrain draw loop not found")
endif()
string(REPLACE "${V9_DRAW_LOOP_OLD}" "${V9_DRAW_LOOP_NEW}" V9_GRAPHICS "${V9_GRAPHICS}")

set(V9_LABEL_CLIP_OLD [=[	clip_rect(terrain_screen_gworld(), {13, 13, 337, 265});]=])
set(V9_LABEL_CLIP_NEW [=[	clip_rect(terrain_screen_gworld(), {13, 13, 337, 321});]=])
string(FIND "${V9_GRAPHICS}" "${V9_LABEL_CLIP_OLD}" V9_LABEL_CLIP_POS)
if(V9_LABEL_CLIP_POS EQUAL -1)
    message(FATAL_ERROR "v9: expected terrain label clip not found")
endif()
string(REPLACE "${V9_LABEL_CLIP_OLD}" "${V9_LABEL_CLIP_NEW}" V9_GRAPHICS "${V9_GRAPHICS}")

set(V9_REST_OLD [=[	for(int q = 0; q < 9; q++) {
		for(int r = 0; r < 9; r++) {]=])
set(V9_REST_NEW [=[	for(int q = 0; q < 11; q++) {
		for(int r = 0; r < 9; r++) {]=])
string(FIND "${V9_GRAPHICS}" "${V9_REST_OLD}" V9_REST_POS)
if(V9_REST_POS EQUAL -1)
    message(FATAL_ERROR "v9: expected rest-screen terrain loop not found")
endif()
string(REPLACE "${V9_REST_OLD}" "${V9_REST_NEW}" V9_GRAPHICS "${V9_GRAPHICS}")

set(V9_TARGET_OLD [=[				for(short i = 0; i < 9; i++)
					for(short j = 0; j < 9; j++) {
						store_loc.x = center.x + i - 4;
						store_loc.y = center.y + j - 4;]=])
set(V9_TARGET_NEW [=[				for(short i = 0; i < 11; i++)
					for(short j = 0; j < 9; j++) {
						store_loc.x = center.x + i - 5;
						store_loc.y = center.y + j - 4;]=])
string(FIND "${V9_GRAPHICS}" "${V9_TARGET_OLD}" V9_TARGET_POS)
if(V9_TARGET_POS EQUAL -1)
    message(FATAL_ERROR "v9: expected target-pattern viewport loop not found")
endif()
string(REPLACE "${V9_TARGET_OLD}" "${V9_TARGET_NEW}" V9_GRAPHICS "${V9_GRAPHICS}")

file(WRITE "${CBOE_ANDROID_V9_GRAPHICS_CPP}" "${V9_GRAPHICS}")

# ---------------------------------------------------------------------------
# boe.graphutil.cpp: entities, PCs, boats/horses, items and fields must all use
# local centre x=5. Tile y centre remains 4.
# ---------------------------------------------------------------------------
file(READ "${CBOE_ANDROID_V9_GRAPHUTIL_CPP}" V9_GRAPHUTIL)

string(REPLACE "extern char spot_seen[9][9];" "extern char spot_seen[11][9];" V9_GRAPHUTIL "${V9_GRAPHUTIL}")
string(REPLACE "enc.m_loc.x - univ.party.out_loc.x + 4" "enc.m_loc.x - univ.party.out_loc.x + 5" V9_GRAPHUTIL "${V9_GRAPHUTIL}")
string(REPLACE "monst.cur_loc.x - center.x + 4" "monst.cur_loc.x - center.x + 5" V9_GRAPHUTIL "${V9_GRAPHUTIL}")
string(REPLACE "who.combat_pos.x - center.x + 4" "who.combat_pos.x - center.x + 5" V9_GRAPHUTIL "${V9_GRAPHUTIL}")
string(REPLACE "univ.current_pc().combat_pos.x - center.x + 4" "univ.current_pc().combat_pos.x - center.x + 5" V9_GRAPHUTIL "${V9_GRAPHUTIL}")
string(REPLACE "loc.x - center.x + 4" "loc.x - center.x + 5" V9_GRAPHUTIL "${V9_GRAPHUTIL}")
string(REPLACE "boat.loc.x - center.x + 4" "boat.loc.x - center.x + 5" V9_GRAPHUTIL "${V9_GRAPHUTIL}")
string(REPLACE "horse.loc.x - center.x + 4" "horse.loc.x - center.x + 5" V9_GRAPHUTIL "${V9_GRAPHUTIL}")
string(REPLACE "location where_draw(4 + where.x - center.x, 4 + where.y - center.y);" "location where_draw(5 + where.x - center.x, 4 + where.y - center.y);" V9_GRAPHUTIL "${V9_GRAPHUTIL}")
string(REPLACE "store_loc.x < 9 && store_loc.y >= 0 && store_loc.y < 9" "store_loc.x < 11 && store_loc.y >= 0 && store_loc.y < 9" V9_GRAPHUTIL "${V9_GRAPHUTIL}")
string(REPLACE "location target(4,4);" "location target(5,4);" V9_GRAPHUTIL "${V9_GRAPHUTIL}")

# Fail fast if the main centre conversions did not take effect.
string(FIND "${V9_GRAPHUTIL}" "who.combat_pos.x - center.x + 5" V9_GRAPHUTIL_PC_POS)
string(FIND "${V9_GRAPHUTIL}" "location where_draw(5 + where.x - center.x, 4 + where.y - center.y);" V9_GRAPHUTIL_FIELD_POS)
string(FIND "${V9_GRAPHUTIL}" "location target(5,4);" V9_GRAPHUTIL_PARTY_POS)
if(V9_GRAPHUTIL_PC_POS EQUAL -1 OR V9_GRAPHUTIL_FIELD_POS EQUAL -1 OR V9_GRAPHUTIL_PARTY_POS EQUAL -1)
    message(FATAL_ERROR "v9: one or more graphutil centre conversions failed")
endif()
file(WRITE "${CBOE_ANDROID_V9_GRAPHUTIL_CPP}" "${V9_GRAPHUTIL}")

# ---------------------------------------------------------------------------
# boe.locutils.cpp: on-screen width and exploration window become +/-5 in x,
# while preserving the legacy +/-4 vertical sight/exploration height.
# ---------------------------------------------------------------------------
file(READ "${CBOE_ANDROID_V9_LOCUTILS_CPP}" V9_LOCUTILS)
set(V9_POINT_OLD [=[	if((abs((short) (center.x - check.x)) <=4) && (abs((short) (center.y - check.y)) <= 4))]=])
set(V9_POINT_NEW [=[	if((abs((short) (center.x - check.x)) <=5) && (abs((short) (center.y - check.y)) <= 4))]=])
string(FIND "${V9_LOCUTILS}" "${V9_POINT_OLD}" V9_POINT_POS)
if(V9_POINT_POS EQUAL -1)
    message(FATAL_ERROR "v9: expected point_onscreen bounds not found")
endif()
string(REPLACE "${V9_POINT_OLD}" "${V9_POINT_NEW}" V9_LOCUTILS "${V9_LOCUTILS}")

string(REPLACE "for(look.x = dest.x - 4; look.x < dest.x + 5; look.x++)" "for(look.x = dest.x - 5; look.x < dest.x + 6; look.x++)" V9_LOCUTILS "${V9_LOCUTILS}")
string(REPLACE "for(look.x = max(0,dest.x - 4); look.x < min(univ.town->max_dim,dest.x + 5); look.x++)" "for(look.x = max(0,dest.x - 5); look.x < min(univ.town->max_dim,dest.x + 6); look.x++)" V9_LOCUTILS "${V9_LOCUTILS}")
file(WRITE "${CBOE_ANDROID_V9_LOCUTILS_CPP}" "${V9_LOCUTILS}")

# ---------------------------------------------------------------------------
# boe.newgraph.cpp: fog/light geometry and animation trajectories shift one
# native tile right for the new local centre and widen their clipping region.
# ---------------------------------------------------------------------------
file(READ "${CBOE_ANDROID_V9_NEWGRAPH_CPP}" V9_NEWGRAPH)
string(REPLACE "big_to = {13,13,337,265}" "big_to = {13,13,337,321}" V9_NEWGRAPH "${V9_NEWGRAPH}")
string(REPLACE "to_rect.offset(-28 + i * 28,-36 + 36 * j);" "to_rect.offset(i * 28,-36 + 36 * j);" V9_NEWGRAPH "${V9_NEWGRAPH}")
string(REPLACE "big_to = {13+2,13+14,337+3,265+15}" "big_to = {13+2,13+14,337+3,321+15}" V9_NEWGRAPH "${V9_NEWGRAPH}")
string(REPLACE "int xOffset = 28 + 28 * (i - 3), yOffset = 16 + 36 * (j - 3);" "int xOffset = 56 + 28 * (i - 3), yOffset = 16 + 36 * (j - 3);" V9_NEWGRAPH "${V9_NEWGRAPH}")
string(REPLACE "int xOffset = 13 + 28 * (i - 2), yOffset = 13 + 36 * (j - 2);" "int xOffset = 41 + 28 * (i - 2), yOffset = 13 + 36 * (j - 2);" V9_NEWGRAPH "${V9_NEWGRAPH}")
string(REPLACE "screen_ul.x = center.x - 4; screen_ul.y = center.y - 4;" "screen_ul.x = center.x - 5; screen_ul.y = center.y - 4;" V9_NEWGRAPH "${V9_NEWGRAPH}")

string(FIND "${V9_NEWGRAPH}" "screen_ul.x = center.x - 5" V9_NEWGRAPH_SCREEN_POS)
string(FIND "${V9_NEWGRAPH}" "337,321" V9_NEWGRAPH_CLIP_POS)
if(V9_NEWGRAPH_SCREEN_POS EQUAL -1 OR V9_NEWGRAPH_CLIP_POS EQUAL -1)
    message(FATAL_ERROR "v9: newgraph viewport conversion failed")
endif()
file(WRITE "${CBOE_ANDROID_V9_NEWGRAPH_CPP}" "${V9_NEWGRAPH}")

# ---------------------------------------------------------------------------
# boe.actions.cpp / boe.main.cpp: make terrain touching and cursor centre agree
# with 11 columns. The expanded win_to_rects terrain rect supplies the bounds.
# ---------------------------------------------------------------------------
file(READ "${CBOE_ANDROID_V9_ACTIONS_CPP}" V9_ACTIONS)
string(REPLACE "out_loc.x += center.x - 4;" "out_loc.x += center.x - 5;" V9_ACTIONS "${V9_ACTIONS}")
string(REPLACE "location offset = {i - 4, j - 4};" "location offset = {i - 5, j - 4};" V9_ACTIONS "${V9_ACTIONS}")
string(FIND "${V9_ACTIONS}" "location offset = {i - 5, j - 4};" V9_ACTIONS_TOUCH_POS)
if(V9_ACTIONS_TOUCH_POS EQUAL -1)
    message(FATAL_ERROR "v9: terrain touch centre conversion failed")
endif()
file(WRITE "${CBOE_ANDROID_V9_ACTIONS_CPP}" "${V9_ACTIONS}")

file(READ "${CBOE_ANDROID_V9_MAIN_CPP}" V9_MAIN)
string(REPLACE "if(tile.x != 4 || tile.y != 4){" "if(tile.x != 5 || tile.y != 4){" V9_MAIN "${V9_MAIN}")
file(WRITE "${CBOE_ANDROID_V9_MAIN_CPP}" "${V9_MAIN}")

# ---------------------------------------------------------------------------
# winutil.cpp (already transformed by v1-v8): allocate physical Android space
# using the new source aspect and map terrain touches into the wider logical rect.
# ---------------------------------------------------------------------------
file(READ "${CBOE_ANDROID_V9_WINUTIL_CPP}" V9_WINUTIL)
string(REPLACE "const float terrain_w = terrain_h * (279.f / 351.f);" "const float terrain_w = terrain_h * (335.f / 351.f);" V9_WINUTIL "${V9_WINUTIL}")
string(REPLACE "layout.terrain = {fit_inside(terrain_bounds, 279.f, 351.f), {19.f, 7.f, 279.f, 351.f}};" "layout.terrain = {fit_inside(terrain_bounds, 335.f, 351.f), {19.f, 7.f, 335.f, 351.f}};" V9_WINUTIL "${V9_WINUTIL}")
string(FIND "${V9_WINUTIL}" "terrain_h * (335.f / 351.f)" V9_WINUTIL_ASPECT_POS)
string(FIND "${V9_WINUTIL}" "fit_inside(terrain_bounds, 335.f, 351.f)" V9_WINUTIL_MAP_POS)
if(V9_WINUTIL_ASPECT_POS EQUAL -1 OR V9_WINUTIL_MAP_POS EQUAL -1)
    message(FATAL_ERROR "v9: Android shell terrain aspect/mapping conversion failed")
endif()
file(WRITE "${CBOE_ANDROID_V9_WINUTIL_CPP}" "${V9_WINUTIL}")

message(STATUS "Applied Android mobile UI v9 real 11x9 terrain viewport")
