# Codeberg migration v34: correct monster facing-sheet selection and trim-mask
# construction without replacing Android's widened renderer or graphics/input work.
if(DEFINED CBOE_ANDROID_CODEBERG_V34_APPLIED)
    return()
endif()
set(CBOE_ANDROID_CODEBERG_V34_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_V34_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(V34_GRAPHUTIL_CPP "${CBOE_ANDROID_V34_ROOT}/src/game/boe.graphutil.cpp")
set(V34_GRAPHICS_CPP "${CBOE_ANDROID_V34_ROOT}/src/game/boe.graphics.cpp")

# Codeberg fixed the two directional halves of monster graphics being selected
# backwards for outdoor encounters and standard town/combat monster sheets.
file(READ "${V34_GRAPHUTIL_CPP}" V34_GRAPHUTIL)
set(V34_OUT_CUSTOM_OLD [=[((enc.direction < 4) ? 0 : (width * height))]=])
set(V34_OUT_CUSTOM_NEW [=[((enc.direction >= 4) ? 0 : (width * height))]=])
string(FIND "${V34_GRAPHUTIL}" "${V34_OUT_CUSTOM_OLD}" V34_OUT_CUSTOM_POS)
if(V34_OUT_CUSTOM_POS EQUAL -1)
    message(FATAL_ERROR "v34: outdoor custom-monster facing anchor not found")
endif()
string(REPLACE "${V34_OUT_CUSTOM_OLD}" "${V34_OUT_CUSTOM_NEW}" V34_GRAPHUTIL "${V34_GRAPHUTIL}")

set(V34_OUT_STD_OLD [=[get_monster_template_rect(picture_wanted,(enc.direction < 4) ? 0 : 1,k)]=])
set(V34_OUT_STD_NEW [=[get_monster_template_rect(picture_wanted,(enc.direction >= 4) ? 0 : 1,k)]=])
string(FIND "${V34_GRAPHUTIL}" "${V34_OUT_STD_OLD}" V34_OUT_STD_POS)
if(V34_OUT_STD_POS EQUAL -1)
    message(FATAL_ERROR "v34: outdoor standard-monster facing anchor not found")
endif()
string(REPLACE "${V34_OUT_STD_OLD}" "${V34_OUT_STD_NEW}" V34_GRAPHUTIL "${V34_GRAPHUTIL}")

set(V34_TOWN_STD_OLD [=[int pic_mode = (monst.direction) < 4 ? 0 : 1;]=])
set(V34_TOWN_STD_NEW [=[int pic_mode = (monst.direction) >= 4 ? 0 : 1;]=])
string(FIND "${V34_GRAPHUTIL}" "${V34_TOWN_STD_OLD}" V34_TOWN_STD_POS)
if(V34_TOWN_STD_POS EQUAL -1)
    message(FATAL_ERROR "v34: town/combat monster facing anchor not found")
endif()
string(REPLACE "${V34_TOWN_STD_OLD}" "${V34_TOWN_STD_NEW}" V34_GRAPHUTIL "${V34_GRAPHUTIL}")
file(WRITE "${V34_GRAPHUTIL_CPP}" "${V34_GRAPHUTIL}")

# Build trim masks without the RenderTexture display()/vertical-flip path.
# Reuse the render target so the OpenGL ES path does not repeatedly construct a
# temporary context while masks are lazily initialized.
file(READ "${V34_GRAPHICS_CPP}" V34_GRAPHICS)
set(V34_MASK_RENDER_OLD [=[static void init_trim_mask(std::unique_ptr<sf::Texture>& mask, rectangle src_rect) {
	sf::RenderTexture render;
	rectangle dest_rect;]=])
set(V34_MASK_RENDER_NEW [=[static void init_trim_mask(std::unique_ptr<sf::Texture>& mask, rectangle src_rect) {
	static sf::RenderTexture render;
	static bool init = false;
	if(!init){
		render.create(28, 36);
		init = true;
	}
	rectangle dest_rect;]=])
string(FIND "${V34_GRAPHICS}" "${V34_MASK_RENDER_OLD}" V34_MASK_RENDER_POS)
if(V34_MASK_RENDER_POS EQUAL -1)
    message(FATAL_ERROR "v34: trim-mask RenderTexture anchor not found")
endif()
string(REPLACE "${V34_MASK_RENDER_OLD}" "${V34_MASK_RENDER_NEW}" V34_GRAPHICS "${V34_GRAPHICS}")

set(V34_MASK_FLIP_OLD [=[	std::tie(dest_rect.top, dest_rect.bottom) = std::make_tuple(36 - dest_rect.top, 36 - dest_rect.bottom);
]=])
string(FIND "${V34_GRAPHICS}" "${V34_MASK_FLIP_OLD}" V34_MASK_FLIP_POS)
if(V34_MASK_FLIP_POS EQUAL -1)
    message(FATAL_ERROR "v34: trim-mask manual flip anchor not found")
endif()
string(REPLACE "${V34_MASK_FLIP_OLD}" "" V34_GRAPHICS "${V34_GRAPHICS}")

set(V34_MASK_DISPLAY_OLD [=[	rect_draw_some_item(*ResMgr::graphics.get("trim"), src_rect, render, dest_rect);
	render.display();
	mask.reset(new sf::Texture);]=])
set(V34_MASK_DISPLAY_NEW [=[	rect_draw_some_item(*ResMgr::graphics.get("trim"), src_rect, render, dest_rect);
	// render.display(); // Using it as a mask, we don't need to flip
	mask.reset(new sf::Texture);]=])
string(FIND "${V34_GRAPHICS}" "${V34_MASK_DISPLAY_OLD}" V34_MASK_DISPLAY_POS)
if(V34_MASK_DISPLAY_POS EQUAL -1)
    message(FATAL_ERROR "v34: trim-mask display anchor not found")
endif()
string(REPLACE "${V34_MASK_DISPLAY_OLD}" "${V34_MASK_DISPLAY_NEW}" V34_GRAPHICS "${V34_GRAPHICS}")
file(WRITE "${V34_GRAPHICS_CPP}" "${V34_GRAPHICS}")

message(STATUS "Applied Codeberg monster-facing and trim-mask fixes")
