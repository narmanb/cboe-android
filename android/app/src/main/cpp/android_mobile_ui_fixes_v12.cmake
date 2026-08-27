# Android map/input stabilization after v11.
# - Create map_gworld without restoring the desktop second window.
# - Add an always-visible upper-right minimap plus the full MAP overlay.
# - Make the full overlay modal and closable with X / Escape(Android Back).
# - Enlarge movement buttons, shrink the centre ACT hit target, and add held-repeat.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V12_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V12_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V12_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V12_TOWN_CPP "${CBOE_ANDROID_UI_V12_ROOT}/src/game/boe.town.cpp")
set(CBOE_ANDROID_V12_WINUTIL_CPP "${CBOE_ANDROID_UI_V12_ROOT}/src/tools/winutil.cpp")

# ---------------------------------------------------------------------------
# boe.town.cpp
# ---------------------------------------------------------------------------
file(READ "${CBOE_ANDROID_V12_TOWN_CPP}" V12_TOWN)

# init_mini_map() is intentionally skipped on Android because it creates a
# second RenderWindow, but it also used to create the 384x384 map RenderTexture.
# Create only that safe off-screen target before draw_map() uses it.
set(V12_MAP_INIT_OLD [=[		mainPtr().setActive();

		map_gworld().setActive();]=])
set(V12_MAP_INIT_NEW [=[		mainPtr().setActive();

#ifdef __ANDROID__
		if(map_gworld().getSize().x != 384 || map_gworld().getSize().y != 384)
			map_gworld().create(384,384);
#endif
		map_gworld().setActive();]=])
string(FIND "${V12_TOWN}" "${V12_MAP_INIT_OLD}" V12_MAP_INIT_POS)
if(V12_MAP_INIT_POS EQUAL -1)
    message(FATAL_ERROR "v12: expected map_gworld activation block not found")
endif()
string(REPLACE "${V12_MAP_INIT_OLD}" "${V12_MAP_INIT_NEW}" V12_TOWN "${V12_TOWN}")

# Let the Android shell refresh the real explored-map texture without opening
# the full-screen MAP overlay or emitting the map-help message every movement.
set(V12_CHECK_DONE_OLD [=[void check_done() {
}]=])
set(V12_CHECK_DONE_NEW [=[#ifdef __ANDROID__
void android_refresh_map_cache() {
	if(overall_mode != MODE_OUTDOORS && overall_mode != MODE_TOWN)
		return;
	const bool was_visible = map_visible;
	map_visible = true;
	draw_map(true);
	map_visible = was_visible;
	mainPtr().setActive();
}
#endif

void check_done() {
}]=])
string(FIND "${V12_TOWN}" "${V12_CHECK_DONE_OLD}" V12_CHECK_DONE_POS)
if(V12_CHECK_DONE_POS EQUAL -1)
    message(FATAL_ERROR "v12: expected check_done anchor not found")
endif()
string(REPLACE "${V12_CHECK_DONE_OLD}" "${V12_CHECK_DONE_NEW}" V12_TOWN "${V12_TOWN}")

file(WRITE "${CBOE_ANDROID_V12_TOWN_CPP}" "${V12_TOWN}")

# ---------------------------------------------------------------------------
# winutil.cpp
# ---------------------------------------------------------------------------
file(READ "${CBOE_ANDROID_V12_WINUTIL_CPP}" V12_WINUTIL)

set(V12_CLOCK_INCLUDE_OLD [=[#include <SFML/Graphics/Sprite.hpp>]=])
set(V12_CLOCK_INCLUDE_NEW [=[#include <SFML/Graphics/Sprite.hpp>
#include <SFML/System/Clock.hpp>]=])
string(FIND "${V12_WINUTIL}" "${V12_CLOCK_INCLUDE_OLD}" V12_CLOCK_INCLUDE_POS)
if(V12_CLOCK_INCLUDE_POS EQUAL -1)
    message(FATAL_ERROR "v12: expected Sprite include anchor not found")
endif()
string(REPLACE "${V12_CLOCK_INCLUDE_OLD}" "${V12_CLOCK_INCLUDE_NEW}" V12_WINUTIL "${V12_WINUTIL}")

set(V12_MAP_DECL_OLD [=[void display_map();]=])
set(V12_MAP_DECL_NEW [=[void display_map();
void android_refresh_map_cache();]=])
string(FIND "${V12_WINUTIL}" "${V12_MAP_DECL_OLD}" V12_MAP_DECL_POS)
if(V12_MAP_DECL_POS EQUAL -1)
    message(FATAL_ERROR "v12: expected display_map declaration not found")
endif()
string(REPLACE "${V12_MAP_DECL_OLD}" "${V12_MAP_DECL_NEW}" V12_WINUTIL "${V12_WINUTIL}")

set(V12_STATE_OLD [=[bool android_map_overlay_visible = false;
int android_map_close_finger = -1;]=])
set(V12_STATE_NEW [=[bool android_map_overlay_visible = false;
int android_map_close_finger = -1;
bool android_map_suppress_mouse_release = false;
bool android_map_suppress_back_release = false;
bool android_map_cache_dirty = true;
bool android_dpad_hold_active = false;
sf::Keyboard::Key android_dpad_hold_primary = sf::Keyboard::Unknown;
sf::Keyboard::Key android_dpad_hold_secondary = sf::Keyboard::Unknown;
sf::Clock android_dpad_hold_clock;
sf::Clock android_dpad_repeat_clock;]=])
string(FIND "${V12_WINUTIL}" "${V12_STATE_OLD}" V12_STATE_POS)
if(V12_STATE_POS EQUAL -1)
    message(FATAL_ERROR "v12: expected v11 map state block not found")
endif()
string(REPLACE "${V12_STATE_OLD}" "${V12_STATE_NEW}" V12_WINUTIL "${V12_WINUTIL}")

# Larger arrows, with a little more spacing. Keep the established Android right
# safe area so immersive navigation gestures are not accidentally triggered.
set(V12_DPAD_GEOM_OLD [=[    const float gap = 8.f;
    const float right_padding = 128.f;
    const float vertical_padding = 18.f;

    float button_size = static_cast<float>(window_size.y) * 0.115f;
    if(button_size > 86.f) button_size = 86.f;
    if(button_size < 58.f) button_size = 58.f;]=])
set(V12_DPAD_GEOM_NEW [=[    const float gap = 10.f;
    const float right_padding = 128.f;
    const float vertical_padding = 18.f;

    float button_size = static_cast<float>(window_size.y) * 0.13f;
    if(button_size > 98.f) button_size = 98.f;
    if(button_size < 66.f) button_size = 66.f;]=])
string(FIND "${V12_WINUTIL}" "${V12_DPAD_GEOM_OLD}" V12_DPAD_GEOM_POS)
if(V12_DPAD_GEOM_POS EQUAL -1)
    message(FATAL_ERROR "v12: expected d-pad geometry block not found")
endif()
string(REPLACE "${V12_DPAD_GEOM_OLD}" "${V12_DPAD_GEOM_NEW}" V12_WINUTIL "${V12_WINUTIL}")

# Keep ACT in the centre visually, but make its actual box smaller than the
# surrounding arrows so a slightly-off movement press is much less likely to
# open the action menu.
set(V12_ACT_GEOM_OLD [=[    toggle = sf::FloatRect(
        dpad_buttons[0].rect.left + button_size + dpad_gap,
        dpad_buttons[0].rect.top + button_size + dpad_gap,
        button_size,
        button_size
    );]=])
set(V12_ACT_GEOM_NEW [=[    const float toggle_size = button_size * 0.72f;
    const float toggle_inset = (button_size - toggle_size) * 0.5f;
    toggle = sf::FloatRect(
        dpad_buttons[0].rect.left + button_size + dpad_gap + toggle_inset,
        dpad_buttons[0].rect.top + button_size + dpad_gap + toggle_inset,
        toggle_size,
        toggle_size
    );]=])
string(FIND "${V12_WINUTIL}" "${V12_ACT_GEOM_OLD}" V12_ACT_GEOM_POS)
if(V12_ACT_GEOM_POS EQUAL -1)
    message(FATAL_ERROR "v12: expected ACT geometry block not found")
endif()
string(REPLACE "${V12_ACT_GEOM_OLD}" "${V12_ACT_GEOM_NEW}" V12_WINUTIL "${V12_WINUTIL}")

# Mark the map dirty after every direct mobile movement and add a conservative
# held-repeat: one immediate step, 375 ms pause, then about 7 steps/second.
set(V12_MOVE_TAIL_OLD [=[    if(!handle_screen_shift(delta, need_redraw))
        handle_terrain_screen_actions(delta, false, false, did_something, need_redraw, need_reprint);
    advance_time(did_something, need_redraw, need_reprint);
}]=])
set(V12_MOVE_TAIL_NEW [=[    if(!handle_screen_shift(delta, need_redraw))
        handle_terrain_screen_actions(delta, false, false, did_something, need_redraw, need_reprint);
    advance_time(did_something, need_redraw, need_reprint);
    android_map_cache_dirty = true;
}

void android_begin_dpad_hold(sf::Keyboard::Key primary, sf::Keyboard::Key secondary) {
    android_dpad_hold_active = true;
    android_dpad_hold_primary = primary;
    android_dpad_hold_secondary = secondary;
    android_dpad_hold_clock.restart();
    android_dpad_repeat_clock.restart();
}

void android_end_dpad_hold() {
    android_dpad_hold_active = false;
    android_dpad_hold_primary = sf::Keyboard::Unknown;
    android_dpad_hold_secondary = sf::Keyboard::Unknown;
}

void android_service_dpad_hold() {
    if(!android_dpad_hold_active)
        return;
    if(!android_mobile_input_enabled()) {
        android_end_dpad_hold();
        return;
    }
    if(android_dpad_hold_clock.getElapsedTime().asMilliseconds() < 375)
        return;
    if(android_dpad_repeat_clock.getElapsedTime().asMilliseconds() < 140)
        return;
    android_dpad_repeat_clock.restart();
    android_move_from_keys(android_dpad_hold_primary, android_dpad_hold_secondary);
}]=])
string(FIND "${V12_WINUTIL}" "${V12_MOVE_TAIL_OLD}" V12_MOVE_TAIL_POS)
if(V12_MOVE_TAIL_POS EQUAL -1)
    message(FATAL_ERROR "v12: expected Android move tail not found")
endif()
string(REPLACE "${V12_MOVE_TAIL_OLD}" "${V12_MOVE_TAIL_NEW}" V12_WINUTIL "${V12_WINUTIL}")

# Geometry shared by the renderer and modal hit-testing.
set(V12_MAP_CLASS_ANCHOR [=[class AndroidMapOverlayDrawable : public iDrawable {]=])
set(V12_MAP_CLASS_INSERT [=[sf::FloatRect android_map_overlay_destination() {
    const sf::Texture& texture = android_map_display_gworld().getTexture();
    const sf::Vector2u tex_size = texture.getSize();
    const sf::Vector2u window_size = mainPtr().getSize();
    if(tex_size.x == 0 || tex_size.y == 0)
        return {};
    const float margin = 24.f;
    const sf::FloatRect bounds(margin, margin,
                               static_cast<float>(window_size.x) - margin * 2.f,
                               static_cast<float>(window_size.y) - margin * 2.f);
    return fit_inside(bounds, static_cast<float>(tex_size.x), static_cast<float>(tex_size.y));
}

sf::FloatRect android_map_overlay_close_rect() {
    const sf::FloatRect dest = android_map_overlay_destination();
    if(dest.width <= 0.f || dest.height <= 0.f)
        return {};
    const sf::Vector2u window_size = mainPtr().getSize();
    const float close_size = 44.f;
    const float close_left = std::min(static_cast<float>(window_size.x) - close_size - 12.f,
                                      dest.left + dest.width + 10.f);
    const float close_top = std::max(12.f, dest.top - 8.f);
    return {close_left, close_top, close_size, close_size};
}

sf::FloatRect android_map_mini_rect() {
    const sf::Vector2u size = mainPtr().getSize();
    float mini = static_cast<float>(size.y) * 0.26f;
    if(mini > 190.f) mini = 190.f;
    if(mini < 145.f) mini = 145.f;
    return {static_cast<float>(size.x) - mini - 20.f, 18.f, mini, mini};
}

class AndroidMapMiniDrawable : public iDrawable {
public:
    void draw() override {
        if(android_map_overlay_visible || !android_mobile_input_enabled())
            return;
        if(overall_mode != MODE_OUTDOORS && overall_mode != MODE_TOWN)
            return;

        if(android_map_cache_dirty) {
            android_refresh_map_cache();
            android_map_cache_dirty = false;
        }

        const sf::Texture& texture = android_map_display_gworld().getTexture();
        const sf::Vector2u tex_size = texture.getSize();
        if(tex_size.x == 0 || tex_size.y == 0)
            return;

        const sf::View previous_view = mainPtr().getView();
        mainPtr().setView(mainPtr().getDefaultView());
        const sf::FloatRect dest = android_map_mini_rect();

        sf::RectangleShape frame({dest.width + 8.f, dest.height + 8.f});
        frame.setPosition(dest.left - 4.f, dest.top - 4.f);
        frame.setFillColor(sf::Color(12,12,14,245));
        frame.setOutlineColor(sf::Color(220,210,184,220));
        frame.setOutlineThickness(2.f);
        mainPtr().draw(frame);

        sf::Sprite sprite(texture);
        sprite.setPosition(dest.left, dest.top);
        sprite.setScale(dest.width / static_cast<float>(tex_size.x),
                        dest.height / static_cast<float>(tex_size.y));
        mainPtr().draw(sprite);
        mainPtr().setView(previous_view);
    }
};

class AndroidMapOverlayDrawable : public iDrawable {]=])
string(FIND "${V12_WINUTIL}" "${V12_MAP_CLASS_ANCHOR}" V12_MAP_CLASS_POS)
if(V12_MAP_CLASS_POS EQUAL -1)
    message(FATAL_ERROR "v12: expected map overlay class anchor not found")
endif()
string(REPLACE "${V12_MAP_CLASS_ANCHOR}" "${V12_MAP_CLASS_INSERT}" V12_WINUTIL "${V12_WINUTIL}")

# Register the compact map between quick actions and the full overlay.
set(V12_REGISTER_OLD [=[    auto dpad = std::make_shared<AndroidDpadDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 80, "android-movement-dpad", dpad);

    auto quick_actions = std::make_shared<AndroidQuickActionsDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 90, "android-quick-actions", quick_actions);

    auto map_overlay = std::make_shared<AndroidMapOverlayDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 100, "android-map-overlay", map_overlay);
    registered = true;]=])
set(V12_REGISTER_NEW [=[    auto dpad = std::make_shared<AndroidDpadDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 80, "android-movement-dpad", dpad);

    auto quick_actions = std::make_shared<AndroidQuickActionsDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 90, "android-quick-actions", quick_actions);

    auto mini_map_overlay = std::make_shared<AndroidMapMiniDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 95, "android-live-minimap", mini_map_overlay);

    auto map_overlay = std::make_shared<AndroidMapOverlayDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 100, "android-map-overlay", map_overlay);
    registered = true;]=])
string(FIND "${V12_WINUTIL}" "${V12_REGISTER_OLD}" V12_REGISTER_POS)
if(V12_REGISTER_POS EQUAL -1)
    message(FATAL_ERROR "v12: expected v11 drawable registration block not found")
endif()
string(REPLACE "${V12_REGISTER_OLD}" "${V12_REGISTER_NEW}" V12_WINUTIL "${V12_WINUTIL}")

# MAP already regenerated the cache when opening the full overlay.
set(V12_MAP_OPEN_OLD [=[                display_map();
                android_map_overlay_visible = true;
                return; // map display is informational and must not advance time]=])
set(V12_MAP_OPEN_NEW [=[                display_map();
                android_map_cache_dirty = false;
                android_map_overlay_visible = true;
                return; // map display is informational and must not advance time]=])
string(FIND "${V12_WINUTIL}" "${V12_MAP_OPEN_OLD}" V12_MAP_OPEN_POS)
if(V12_MAP_OPEN_POS EQUAL -1)
    message(FATAL_ERROR "v12: expected v11 map-open block not found")
endif()
string(REPLACE "${V12_MAP_OPEN_OLD}" "${V12_MAP_OPEN_NEW}" V12_WINUTIL "${V12_WINUTIL}")

# Any non-MAP quick action can change exploration/state; refresh the small map
# on the next frame rather than every frame.
set(V12_QUICK_TAIL_OLD [=[    if(handled && action != ANDROID_QUICK_SAVE && action != ANDROID_QUICK_LOAD)
        advance_time(did_something, need_redraw, need_reprint);
}]=])
set(V12_QUICK_TAIL_NEW [=[    if(handled && action != ANDROID_QUICK_SAVE && action != ANDROID_QUICK_LOAD)
        advance_time(did_something, need_redraw, need_reprint);
    if(handled)
        android_map_cache_dirty = true;
}]=])
string(FIND "${V12_WINUTIL}" "${V12_QUICK_TAIL_OLD}" V12_QUICK_TAIL_POS)
if(V12_QUICK_TAIL_POS EQUAL -1)
    message(FATAL_ERROR "v12: expected quick-action tail not found")
endif()
string(REPLACE "${V12_QUICK_TAIL_OLD}" "${V12_QUICK_TAIL_NEW}" V12_WINUTIL "${V12_WINUTIL}")

# Direct SFML touch path: consume all overlay touches, but only X closes it.
set(V12_TOUCH_MAP_OLD [=[                if(&win == &mainPtr() && android_map_overlay_visible) {
                    android_map_overlay_visible = false;
                    android_map_close_finger = static_cast<int>(event.touch.finger);
                    event.type = sf::Event::Count;
                    break;
                }]=])
set(V12_TOUCH_MAP_NEW [=[                if(&win == &mainPtr() && android_map_overlay_visible) {
                    const sf::FloatRect close_rect = android_map_overlay_close_rect();
                    if(close_rect.contains(static_cast<float>(x), static_cast<float>(y)))
                        android_map_overlay_visible = false;
                    android_map_close_finger = static_cast<int>(event.touch.finger);
                    event.type = sf::Event::Count;
                    break;
                }]=])
string(FIND "${V12_WINUTIL}" "${V12_TOUCH_MAP_OLD}" V12_TOUCH_MAP_POS)
if(V12_TOUCH_MAP_POS EQUAL -1)
    message(FATAL_ERROR "v12: expected v11 touch map block not found")
endif()
string(REPLACE "${V12_TOUCH_MAP_OLD}" "${V12_TOUCH_MAP_NEW}" V12_WINUTIL "${V12_WINUTIL}")

# Start/stop repeat on the direct-touch D-pad path too.
set(V12_TOUCH_DPAD_OLD [=[                    android_dpad_finger = static_cast<int>(event.touch.finger);
                    android_move_from_keys(primary, secondary);
                    event.type = sf::Event::Count;]=])
set(V12_TOUCH_DPAD_NEW [=[                    android_dpad_finger = static_cast<int>(event.touch.finger);
                    android_begin_dpad_hold(primary, secondary);
                    android_move_from_keys(primary, secondary);
                    event.type = sf::Event::Count;]=])
string(FIND "${V12_WINUTIL}" "${V12_TOUCH_DPAD_OLD}" V12_TOUCH_DPAD_POS)
if(V12_TOUCH_DPAD_POS EQUAL -1)
    message(FATAL_ERROR "v12: expected touch d-pad dispatch not found")
endif()
string(REPLACE "${V12_TOUCH_DPAD_OLD}" "${V12_TOUCH_DPAD_NEW}" V12_WINUTIL "${V12_WINUTIL}")

set(V12_TOUCH_END_DPAD_OLD [=[                if(android_dpad_finger == static_cast<int>(event.touch.finger)) {
                    android_dpad_finger = -1;
                    event.type = sf::Event::Count;]=])
set(V12_TOUCH_END_DPAD_NEW [=[                if(android_dpad_finger == static_cast<int>(event.touch.finger)) {
                    android_dpad_finger = -1;
                    android_end_dpad_hold();
                    event.type = sf::Event::Count;]=])
string(FIND "${V12_WINUTIL}" "${V12_TOUCH_END_DPAD_OLD}" V12_TOUCH_END_DPAD_POS)
if(V12_TOUCH_END_DPAD_POS EQUAL -1)
    message(FATAL_ERROR "v12: expected touch d-pad release not found")
endif()
string(REPLACE "${V12_TOUCH_END_DPAD_OLD}" "${V12_TOUCH_END_DPAD_NEW}" V12_WINUTIL "${V12_WINUTIL}")

# Physical-device touches currently arrive as mouse events. Make the full map
# modal here before ACT, d-pad, terrain, or info-panel hit testing can run.
set(V12_MOUSE_PRESS_PREFIX_OLD [=[            case sf::Event::MouseButtonPressed: {
                const int x = event.mouseButton.x;
                const int y = event.mouseButton.y;
                sf::Keyboard::Key primary = sf::Keyboard::Unknown;]=])
set(V12_MOUSE_PRESS_PREFIX_NEW [=[            case sf::Event::MouseButtonPressed: {
                const int x = event.mouseButton.x;
                const int y = event.mouseButton.y;
                if(&win == &mainPtr() && android_map_overlay_visible) {
                    if(event.mouseButton.button == sf::Mouse::Left) {
                        const sf::FloatRect close_rect = android_map_overlay_close_rect();
                        if(close_rect.contains(static_cast<float>(x), static_cast<float>(y)))
                            android_map_overlay_visible = false;
                    }
                    android_map_suppress_mouse_release = true;
                    event.type = sf::Event::Count;
                    break;
                }
                sf::Keyboard::Key primary = sf::Keyboard::Unknown;]=])
string(FIND "${V12_WINUTIL}" "${V12_MOUSE_PRESS_PREFIX_OLD}" V12_MOUSE_PRESS_PREFIX_POS)
if(V12_MOUSE_PRESS_PREFIX_POS EQUAL -1)
    message(FATAL_ERROR "v12: expected mouse press prefix not found")
endif()
string(REPLACE "${V12_MOUSE_PRESS_PREFIX_OLD}" "${V12_MOUSE_PRESS_PREFIX_NEW}" V12_WINUTIL "${V12_WINUTIL}")

set(V12_MOUSE_DPAD_OLD [=[                if(&win == &mainPtr() && event.mouseButton.button == sf::Mouse::Left &&
                   android_dpad_keys_at(x, y, primary, secondary)) {
                    android_quick_menu_open = false;
                    android_move_from_keys(primary, secondary);]=])
set(V12_MOUSE_DPAD_NEW [=[                if(&win == &mainPtr() && event.mouseButton.button == sf::Mouse::Left &&
                   android_dpad_keys_at(x, y, primary, secondary)) {
                    android_quick_menu_open = false;
                    android_begin_dpad_hold(primary, secondary);
                    android_move_from_keys(primary, secondary);]=])
string(FIND "${V12_WINUTIL}" "${V12_MOUSE_DPAD_OLD}" V12_MOUSE_DPAD_POS)
if(V12_MOUSE_DPAD_POS EQUAL -1)
    message(FATAL_ERROR "v12: expected mouse d-pad block not found")
endif()
string(REPLACE "${V12_MOUSE_DPAD_OLD}" "${V12_MOUSE_DPAD_NEW}" V12_WINUTIL "${V12_WINUTIL}")

set(V12_MOUSE_RELEASE_PREFIX_OLD [=[            case sf::Event::MouseButtonReleased: {
                const int x = event.mouseButton.x;
                const int y = event.mouseButton.y;
                if(&win == &mainPtr() && android_quick_pressed != ANDROID_QUICK_NONE) {]=])
set(V12_MOUSE_RELEASE_PREFIX_NEW [=[            case sf::Event::MouseButtonReleased: {
                const int x = event.mouseButton.x;
                const int y = event.mouseButton.y;
                if(&win == &mainPtr() && (android_map_overlay_visible || android_map_suppress_mouse_release)) {
                    android_map_suppress_mouse_release = false;
                    event.type = sf::Event::Count;
                    break;
                }
                if(&win == &mainPtr() && android_dpad_hold_active) {
                    android_end_dpad_hold();
                    event.type = sf::Event::Count;
                    break;
                }
                if(&win == &mainPtr() && android_quick_pressed != ANDROID_QUICK_NONE) {]=])
string(FIND "${V12_WINUTIL}" "${V12_MOUSE_RELEASE_PREFIX_OLD}" V12_MOUSE_RELEASE_PREFIX_POS)
if(V12_MOUSE_RELEASE_PREFIX_POS EQUAL -1)
    message(FATAL_ERROR "v12: expected mouse release prefix not found")
endif()
string(REPLACE "${V12_MOUSE_RELEASE_PREFIX_OLD}" "${V12_MOUSE_RELEASE_PREFIX_NEW}" V12_WINUTIL "${V12_WINUTIL}")

# Escape is SFML's Android Back-key mapping. Consume both edges so closing the
# map cannot trigger a game action underneath it.
set(V12_MOUSE_MOVE_TAIL_OLD [=[                event.mouseMove.x = translated.x;
                event.mouseMove.y = translated.y;
                break;
            }
            default:
                break;]=])
set(V12_MOUSE_MOVE_TAIL_NEW [=[                event.mouseMove.x = translated.x;
                event.mouseMove.y = translated.y;
                break;
            }
            case sf::Event::KeyPressed:
                if(&win == &mainPtr() && android_map_overlay_visible && event.key.code == sf::Keyboard::Escape) {
                    android_map_overlay_visible = false;
                    android_map_suppress_back_release = true;
                    event.type = sf::Event::Count;
                }
                break;
            case sf::Event::KeyReleased:
                if(&win == &mainPtr() && android_map_suppress_back_release && event.key.code == sf::Keyboard::Escape) {
                    android_map_suppress_back_release = false;
                    event.type = sf::Event::Count;
                }
                break;
            default:
                break;]=])
string(FIND "${V12_WINUTIL}" "${V12_MOUSE_MOVE_TAIL_OLD}" V12_MOUSE_MOVE_TAIL_POS)
if(V12_MOUSE_MOVE_TAIL_POS EQUAL -1)
    message(FATAL_ERROR "v12: expected Android mouse-move switch tail not found")
endif()
string(REPLACE "${V12_MOUSE_MOVE_TAIL_OLD}" "${V12_MOUSE_MOVE_TAIL_NEW}" V12_WINUTIL "${V12_WINUTIL}")

# Service held movement once the native event queue is empty. This keeps taps
# immediate and allows repeats at a controlled rate without synthesizing key spam.
set(V12_POLL_IDLE_OLD [=[    return false;
}

bool pollEvent(sf::Window* win, sf::Event& event){]=])
set(V12_POLL_IDLE_NEW [=[#ifdef __ANDROID__
    if(&win == &mainPtr())
        android_service_dpad_hold();
#endif
    return false;
}

bool pollEvent(sf::Window* win, sf::Event& event){]=])
string(FIND "${V12_WINUTIL}" "${V12_POLL_IDLE_OLD}" V12_POLL_IDLE_POS)
if(V12_POLL_IDLE_POS EQUAL -1)
    message(FATAL_ERROR "v12: expected pollEvent idle tail not found")
endif()
string(REPLACE "${V12_POLL_IDLE_OLD}" "${V12_POLL_IDLE_NEW}" V12_WINUTIL "${V12_WINUTIL}")

file(WRITE "${CBOE_ANDROID_V12_WINUTIL_CPP}" "${V12_WINUTIL}")
message(STATUS "Applied Android mobile UI v12 live minimap, modal map, and held d-pad repeat")
