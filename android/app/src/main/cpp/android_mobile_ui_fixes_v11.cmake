# Android automap pass after v10.
# The desktop automap is a second SFML RenderWindow. Android only presents the
# activity's primary window, so keep OpenBoE's real map generation but composite
# it into a RenderTexture and draw that texture over the existing Android UI.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V11_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V11_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V11_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V11_TOWN_CPP "${CBOE_ANDROID_UI_V11_ROOT}/src/game/boe.town.cpp")
set(CBOE_ANDROID_V11_WINUTIL_CPP "${CBOE_ANDROID_UI_V11_ROOT}/src/tools/winutil.cpp")

# ---------------------------------------------------------------------------
# boe.town.cpp: preserve the original automap terrain generation, but on
# Android render its final 40x40 viewport into an off-screen texture instead of
# trying to expose mini_map(), the desktop-only second RenderWindow.
# ---------------------------------------------------------------------------
file(READ "${CBOE_ANDROID_V11_TOWN_CPP}" V11_TOWN)

set(V11_MAP_TEX_ANCHOR [=[sf::Color parchment = {255,255,205};

long pause_dummy;]=])
set(V11_MAP_TEX_INSERT [=[sf::Color parchment = {255,255,205};

#ifdef __ANDROID__
sf::RenderTexture& android_map_display_gworld() {
    static sf::RenderTexture instance;
    return instance;
}
#endif

long pause_dummy;]=])
string(FIND "${V11_TOWN}" "${V11_MAP_TEX_ANCHOR}" V11_MAP_TEX_POS)
if(V11_MAP_TEX_POS EQUAL -1)
    message(FATAL_ERROR "v11: expected automap texture insertion anchor not found")
endif()
string(REPLACE "${V11_MAP_TEX_ANCHOR}" "${V11_MAP_TEX_INSERT}" V11_TOWN "${V11_TOWN}")

set(V11_DRAW_MAP_TAIL_OLD [=[		map_gworld().display();
		// this stops flickering if the display time is too long
		glFlush();
	}
	
	mini_map().setActive(false);]=])
set(V11_DRAW_MAP_TAIL_NEW [=[		map_gworld().display();
		// this stops flickering if the display time is too long
		glFlush();
	}

#ifdef __ANDROID__
	// Android has no usable second application RenderWindow. Preserve the real
	// automap generated above and compose the same visible 40x40 map viewport
	// into an off-screen texture which winutil draws over the primary window.
	sf::RenderTexture& android_map = android_map_display_gworld();
	const unsigned int android_map_size = 264;
	if(android_map.getSize().x != android_map_size || android_map.getSize().y != android_map_size)
		android_map.create(android_map_size, android_map_size);
	android_map.setActive();
	android_map.clear(sf::Color(20,20,22));

	const rectangle android_frame = {8,8,256,256};
	const rectangle android_area = {12,12,252,252};
	fill_rect(android_map, android_frame, parchment);

	if(canMap) {
		rect_draw_some_item(map_gworld().getTexture(), area_to_draw_from, android_map, android_area);

		// Preserve the useful life-detection dots from the desktop automap.
		if(draw_pcs && is_town() && univ.party.status[ePartyStatus::DETECT_LIFE] > 0) {
			for(short i = 0; i < univ.town.monst.size(); i++)
				if(univ.town.monst[i].is_alive()) {
					where = univ.town.monst[i].cur_loc;
					if(is_explored(where.x,where.y) &&
					   where.x >= view_rect.left && where.x < view_rect.right &&
					   where.y >= view_rect.top && where.y < view_rect.bottom) {
						draw_rect.left = android_area.left + 6 * (where.x - view_rect.left);
						draw_rect.top = android_area.top + 6 * (where.y - view_rect.top);
						draw_rect.right = draw_rect.left + 6;
						draw_rect.bottom = draw_rect.top + 6;
						fill_rect(android_map, draw_rect, Colours::GREEN);
						frame_circle(android_map, draw_rect, Colours::BLUE);
					}
				}
		}

		// Preserve the desktop automap's red party marker.
		if(draw_pcs && overall_mode != MODE_SHOPPING && overall_mode != MODE_TALKING) {
			where = is_town() ? univ.party.town_loc : global_to_local(univ.party.out_loc);
			draw_rect.left = android_area.left + 6 * (where.x - view_rect.left);
			draw_rect.top = android_area.top + 6 * (where.y - view_rect.top);
			draw_rect.right = draw_rect.left + 6;
			draw_rect.bottom = draw_rect.top + 6;
			fill_rect(android_map, draw_rect, Colours::RED);
			frame_circle(android_map, draw_rect, sf::Color::Black);
		}
	}

	android_map.display();
	mainPtr().setActive();
	return;
#endif
	
	mini_map().setActive(false);]=])
string(FIND "${V11_TOWN}" "${V11_DRAW_MAP_TAIL_OLD}" V11_DRAW_MAP_TAIL_POS)
if(V11_DRAW_MAP_TAIL_POS EQUAL -1)
    message(FATAL_ERROR "v11: expected draw_map desktop-window tail not found")
endif()
string(REPLACE "${V11_DRAW_MAP_TAIL_OLD}" "${V11_DRAW_MAP_TAIL_NEW}" V11_TOWN "${V11_TOWN}")

set(V11_DISPLAY_MAP_OLD [=[	give_help(62,0);
	
	rectangle the_rect;
	rectangle	dlogpicrect = {6,6,42,42};
	
	mini_map().setVisible(true);
	map_visible = true;
	draw_map(true);
	makeFrontWindow(mainPtr(), mini_map());
	
	set_cursor(sword_curs);]=])
set(V11_DISPLAY_MAP_NEW [=[	give_help(62,0);

#ifdef __ANDROID__
	// Generate the normal explored automap, but never expose the desktop-only
	// mini_map RenderWindow. draw_map()'s Android branch writes the final map to
	// android_map_display_gworld() and immediately returns to the primary window.
	map_visible = true;
	draw_map(true);
	map_visible = false;
	mainPtr().setActive();
	set_cursor(sword_curs);
	return;
#else
	
	rectangle the_rect;
	rectangle	dlogpicrect = {6,6,42,42};
	
	mini_map().setVisible(true);
	map_visible = true;
	draw_map(true);
	makeFrontWindow(mainPtr(), mini_map());
	
	set_cursor(sword_curs);
#endif]=])
string(FIND "${V11_TOWN}" "${V11_DISPLAY_MAP_OLD}" V11_DISPLAY_MAP_POS)
if(V11_DISPLAY_MAP_POS EQUAL -1)
    message(FATAL_ERROR "v11: expected display_map desktop-window block not found")
endif()
string(REPLACE "${V11_DISPLAY_MAP_OLD}" "${V11_DISPLAY_MAP_NEW}" V11_TOWN "${V11_TOWN}")

file(WRITE "${CBOE_ANDROID_V11_TOWN_CPP}" "${V11_TOWN}")

# ---------------------------------------------------------------------------
# winutil.cpp: add a top-layer drawable for the generated automap, make MAP a
# toggle, and consume the entire tap used to close the overlay so it cannot
# accidentally activate gameplay underneath it.
# ---------------------------------------------------------------------------
file(READ "${CBOE_ANDROID_V11_WINUTIL_CPP}" V11_WINUTIL)

set(V11_MAP_EXTERN_OLD [=[extern sf::RenderTexture& text_area_gworld();]=])
set(V11_MAP_EXTERN_NEW [=[extern sf::RenderTexture& text_area_gworld();
extern sf::RenderTexture& android_map_display_gworld();]=])
string(FIND "${V11_WINUTIL}" "${V11_MAP_EXTERN_OLD}" V11_MAP_EXTERN_POS)
if(V11_MAP_EXTERN_POS EQUAL -1)
    message(FATAL_ERROR "v11: expected Android RenderTexture extern anchor not found")
endif()
string(REPLACE "${V11_MAP_EXTERN_OLD}" "${V11_MAP_EXTERN_NEW}" V11_WINUTIL "${V11_WINUTIL}")

set(V11_MAP_STATE_OLD [=[sf::Vector2i android_pointer_position;
bool android_pointer_valid = false;
int android_dpad_finger = -1;]=])
set(V11_MAP_STATE_NEW [=[sf::Vector2i android_pointer_position;
bool android_pointer_valid = false;
int android_dpad_finger = -1;
bool android_map_overlay_visible = false;
int android_map_close_finger = -1;]=])
string(FIND "${V11_WINUTIL}" "${V11_MAP_STATE_OLD}" V11_MAP_STATE_POS)
if(V11_MAP_STATE_POS EQUAL -1)
    message(FATAL_ERROR "v11: expected Android input-state anchor not found")
endif()
string(REPLACE "${V11_MAP_STATE_OLD}" "${V11_MAP_STATE_NEW}" V11_WINUTIL "${V11_WINUTIL}")

set(V11_MAP_CLASS_ANCHOR [=[class AndroidDpadDrawable : public iDrawable {]=])
set(V11_MAP_CLASS_INSERT [=[class AndroidMapOverlayDrawable : public iDrawable {
public:
    void draw() override {
        if(!android_map_overlay_visible)
            return;

        const sf::Texture& texture = android_map_display_gworld().getTexture();
        const sf::Vector2u tex_size = texture.getSize();
        if(tex_size.x == 0 || tex_size.y == 0)
            return;

        const sf::View previous_view = mainPtr().getView();
        mainPtr().setView(mainPtr().getDefaultView());

        const sf::Vector2u window_size = mainPtr().getSize();
        sf::RectangleShape shade({static_cast<float>(window_size.x), static_cast<float>(window_size.y)});
        shade.setPosition(0.f, 0.f);
        shade.setFillColor(sf::Color(0,0,0,220));
        mainPtr().draw(shade);

        const float margin = 24.f;
        const sf::FloatRect bounds(margin, margin,
                                   static_cast<float>(window_size.x) - margin * 2.f,
                                   static_cast<float>(window_size.y) - margin * 2.f);
        sf::FloatRect dest = fit_inside(bounds,
                                        static_cast<float>(tex_size.x),
                                        static_cast<float>(tex_size.y));

        sf::RectangleShape frame({dest.width + 12.f, dest.height + 12.f});
        frame.setPosition(dest.left - 6.f, dest.top - 6.f);
        frame.setFillColor(sf::Color(12,12,14,255));
        frame.setOutlineColor(sf::Color(240,232,205,235));
        frame.setOutlineThickness(3.f);
        mainPtr().draw(frame);

        sf::Sprite sprite(texture);
        sprite.setPosition(dest.left, dest.top);
        sprite.setScale(dest.width / static_cast<float>(tex_size.x),
                        dest.height / static_cast<float>(tex_size.y));
        mainPtr().draw(sprite);

        // Visual close affordance. The whole overlay is tappable, not just X.
        const float close_size = 44.f;
        const float close_left = std::min(static_cast<float>(window_size.x) - close_size - 12.f,
                                          dest.left + dest.width + 10.f);
        const float close_top = std::max(12.f, dest.top - 8.f);
        sf::RectangleShape close_box({close_size, close_size});
        close_box.setPosition(close_left, close_top);
        close_box.setFillColor(sf::Color(18,18,22,245));
        close_box.setOutlineColor(sf::Color(245,245,245,235));
        close_box.setOutlineThickness(2.f);
        mainPtr().draw(close_box);

        for(float angle : {45.f, -45.f}) {
            sf::RectangleShape slash({close_size * 0.62f, 4.f});
            slash.setOrigin(close_size * 0.31f, 2.f);
            slash.setPosition(close_left + close_size * 0.5f, close_top + close_size * 0.5f);
            slash.setRotation(angle);
            slash.setFillColor(sf::Color(245,245,245,245));
            mainPtr().draw(slash);
        }

        mainPtr().setView(previous_view);
    }
};

class AndroidDpadDrawable : public iDrawable {]=])
string(FIND "${V11_WINUTIL}" "${V11_MAP_CLASS_ANCHOR}" V11_MAP_CLASS_POS)
if(V11_MAP_CLASS_POS EQUAL -1)
    message(FATAL_ERROR "v11: expected Android d-pad drawable anchor not found")
endif()
string(REPLACE "${V11_MAP_CLASS_ANCHOR}" "${V11_MAP_CLASS_INSERT}" V11_WINUTIL "${V11_WINUTIL}")

set(V11_REGISTER_OLD [=[    auto dpad = std::make_shared<AndroidDpadDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 80, "android-movement-dpad", dpad);
    registered = true;]=])
set(V11_REGISTER_NEW [=[    auto dpad = std::make_shared<AndroidDpadDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 80, "android-movement-dpad", dpad);

    auto map_overlay = std::make_shared<AndroidMapOverlayDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 100, "android-map-overlay", map_overlay);
    registered = true;]=])
string(FIND "${V11_WINUTIL}" "${V11_REGISTER_OLD}" V11_REGISTER_POS)
if(V11_REGISTER_POS EQUAL -1)
    message(FATAL_ERROR "v11: expected Android drawable registration anchor not found")
endif()
string(REPLACE "${V11_REGISTER_OLD}" "${V11_REGISTER_NEW}" V11_WINUTIL "${V11_WINUTIL}")

set(V11_MAP_DISPATCH_OLD [=[        case ANDROID_QUICK_MAP:
            if(overall_mode == MODE_OUTDOORS || overall_mode == MODE_TOWN) {
                display_map();
                return; // map display is informational and must not advance time
            } else handled = false;
            break;]=])
set(V11_MAP_DISPATCH_NEW [=[        case ANDROID_QUICK_MAP:
            if(overall_mode == MODE_OUTDOORS || overall_mode == MODE_TOWN) {
                if(android_map_overlay_visible) {
                    android_map_overlay_visible = false;
                    return;
                }
                display_map();
                android_map_overlay_visible = true;
                return; // map display is informational and must not advance time
            } else handled = false;
            break;]=])
string(FIND "${V11_WINUTIL}" "${V11_MAP_DISPATCH_OLD}" V11_MAP_DISPATCH_POS)
if(V11_MAP_DISPATCH_POS EQUAL -1)
    message(FATAL_ERROR "v11: expected v10 MAP dispatch block not found")
endif()
string(REPLACE "${V11_MAP_DISPATCH_OLD}" "${V11_MAP_DISPATCH_NEW}" V11_WINUTIL "${V11_WINUTIL}")

set(V11_TOUCH_BEGIN_OLD [=[            case sf::Event::TouchBegan: {
                const int x = event.touch.x;
                const int y = event.touch.y;]=])
set(V11_TOUCH_BEGIN_NEW [=[            case sf::Event::TouchBegan: {
                const int x = event.touch.x;
                const int y = event.touch.y;
                if(&win == &mainPtr() && android_map_overlay_visible) {
                    android_map_overlay_visible = false;
                    android_map_close_finger = static_cast<int>(event.touch.finger);
                    event.type = sf::Event::Count;
                    break;
                }]=])
string(FIND "${V11_WINUTIL}" "${V11_TOUCH_BEGIN_OLD}" V11_TOUCH_BEGIN_POS)
if(V11_TOUCH_BEGIN_POS EQUAL -1)
    message(FATAL_ERROR "v11: expected Android TouchBegan anchor not found")
endif()
string(REPLACE "${V11_TOUCH_BEGIN_OLD}" "${V11_TOUCH_BEGIN_NEW}" V11_WINUTIL "${V11_WINUTIL}")

set(V11_TOUCH_END_OLD [=[            case sf::Event::TouchEnded: {
                if(android_dpad_finger == static_cast<int>(event.touch.finger)) {]=])
set(V11_TOUCH_END_NEW [=[            case sf::Event::TouchEnded: {
                if(android_map_close_finger == static_cast<int>(event.touch.finger)) {
                    android_map_close_finger = -1;
                    event.type = sf::Event::Count;
                    break;
                }
                if(android_dpad_finger == static_cast<int>(event.touch.finger)) {]=])
string(FIND "${V11_WINUTIL}" "${V11_TOUCH_END_OLD}" V11_TOUCH_END_POS)
if(V11_TOUCH_END_POS EQUAL -1)
    message(FATAL_ERROR "v11: expected Android TouchEnded anchor not found")
endif()
string(REPLACE "${V11_TOUCH_END_OLD}" "${V11_TOUCH_END_NEW}" V11_WINUTIL "${V11_WINUTIL}")

set(V11_TOUCH_MOVE_OLD [=[            case sf::Event::TouchMoved: {
                if(android_dpad_finger == static_cast<int>(event.touch.finger)) {]=])
set(V11_TOUCH_MOVE_NEW [=[            case sf::Event::TouchMoved: {
                if(android_map_close_finger == static_cast<int>(event.touch.finger)) {
                    event.type = sf::Event::Count;
                    break;
                }
                if(android_dpad_finger == static_cast<int>(event.touch.finger)) {]=])
string(FIND "${V11_WINUTIL}" "${V11_TOUCH_MOVE_OLD}" V11_TOUCH_MOVE_POS)
if(V11_TOUCH_MOVE_POS EQUAL -1)
    message(FATAL_ERROR "v11: expected Android TouchMoved anchor not found")
endif()
string(REPLACE "${V11_TOUCH_MOVE_OLD}" "${V11_TOUCH_MOVE_NEW}" V11_WINUTIL "${V11_WINUTIL}")

file(WRITE "${CBOE_ANDROID_V11_WINUTIL_CPP}" "${V11_WINUTIL}")
message(STATUS "Applied Android mobile UI v11 in-window automap overlay")
