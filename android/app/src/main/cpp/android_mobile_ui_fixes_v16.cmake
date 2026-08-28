# Android Exploration UI v2 interaction/scroll polish after v15.
# - Expand the live minimap leftward to nearly meet Party Stats.
# - Tap the live minimap to open the real full automap.
# - Close the full automap by tapping outside its content, while preserving X/Back.
# - Add native visible scroll thumbs plus swipe/drag scrolling for Inventory/Transcript.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V16_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V16_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V16_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V16_TEXT_CPP "${CBOE_ANDROID_UI_V16_ROOT}/src/game/boe.text.cpp")
set(CBOE_ANDROID_V16_WINUTIL_CPP "${CBOE_ANDROID_UI_V16_ROOT}/src/tools/winutil.cpp")

# ---------------------------------------------------------------------------
# boe.text.cpp: expose only the oldest meaningful transcript scrollbar position.
# The desktop scrollbar keeps a fixed 0..58 range, but on mobile we should hide
# the thumb until there is actually more than the 11 visible lines and avoid
# scrolling upward into empty history.
# ---------------------------------------------------------------------------
file(READ "${CBOE_ANDROID_V16_TEXT_CPP}" V16_TEXT)
set(V16_TEXT_ANCHOR [=[void print_buf () {]=])
set(V16_TEXT_INSERT [=[#ifdef __ANDROID__
long android_transcript_min_position() {
    long total_lines = 0;
    for(int i = 0; i < TEXT_BUF_LEN; ++i) {
        if(text_buffer[i].line_count > 0)
            total_lines += text_buffer[i].line_count;
    }
    long scrollable_lines = total_lines - LINES_IN_TEXT_WIN;
    if(scrollable_lines < 0)
        scrollable_lines = 0;
    long min_position = 58 - scrollable_lines;
    if(min_position < 0)
        min_position = 0;
    return min_position;
}
#endif

void print_buf () {]=])
string(FIND "${V16_TEXT}" "${V16_TEXT_ANCHOR}" V16_TEXT_POS)
if(V16_TEXT_POS EQUAL -1)
    message(FATAL_ERROR "v16: expected print_buf anchor not found")
endif()
string(REPLACE "${V16_TEXT_ANCHOR}" "${V16_TEXT_INSERT}" V16_TEXT "${V16_TEXT}")
file(WRITE "${CBOE_ANDROID_V16_TEXT_CPP}" "${V16_TEXT}")

# ---------------------------------------------------------------------------
# winutil.cpp
# ---------------------------------------------------------------------------
file(READ "${CBOE_ANDROID_V16_WINUTIL_CPP}" V16_WINUTIL)

# Minimal declarations for refreshing the independently composed mobile panels.
set(V16_DECL_OLD [=[void give_pc_info(short pc_num);
void set_stat_window(eItemWinMode new_stat, bool record);
void display_map();]=])
set(V16_DECL_NEW [=[void give_pc_info(short pc_num);
void set_stat_window(eItemWinMode new_stat, bool record);
void display_map();
void put_item_screen(eItemWinMode screen_num);
void print_buf();
long android_transcript_min_position();]=])
string(FIND "${V16_WINUTIL}" "${V16_DECL_OLD}" V16_DECL_POS)
if(V16_DECL_POS EQUAL -1)
    message(FATAL_ERROR "v16: expected Android declaration block not found")
endif()
string(REPLACE "${V16_DECL_OLD}" "${V16_DECL_NEW}" V16_WINUTIL "${V16_WINUTIL}")

# Scroll gesture state. OpenBoE's real cScrollbar objects remain authoritative;
# this merely provides mobile-native touch/drag behavior for them.
set(V16_STATE_OLD [=[bool android_map_cache_dirty = true;
bool android_dpad_hold_active = false;]=])
set(V16_STATE_NEW [=[bool android_map_cache_dirty = true;
enum AndroidPanelScrollTarget {
    ANDROID_PANEL_SCROLL_NONE = 0,
    ANDROID_PANEL_SCROLL_INVENTORY,
    ANDROID_PANEL_SCROLL_TRANSCRIPT
};
AndroidPanelScrollTarget android_panel_scroll_target = ANDROID_PANEL_SCROLL_NONE;
bool android_panel_scroll_dragging = false;
bool android_panel_scroll_track_drag = false;
float android_panel_scroll_start_y = 0.f;
long android_panel_scroll_start_position = 0;
bool android_dpad_hold_active = false;]=])
string(FIND "${V16_WINUTIL}" "${V16_STATE_OLD}" V16_STATE_POS)
if(V16_STATE_POS EQUAL -1)
    message(FATAL_ERROR "v16: expected v12 Android state block not found")
endif()
string(REPLACE "${V16_STATE_OLD}" "${V16_STATE_NEW}" V16_WINUTIL "${V16_WINUTIL}")

# Use the otherwise-empty gap immediately to the right of Party Stats. Preserve
# a 60px MENU lane at the far right, but let the minimap grow leftward until it
# is only a small visual gap from the actual stats panel.
set(V16_MINIMAP_OLD [=[sf::FloatRect android_map_mini_rect() {
    const sf::Vector2u size = mainPtr().getSize();
    std::array<AndroidDpadButton, 8> dpad_buttons;
    sf::FloatRect dpad_panel;
    if(android_dpad_geometry(dpad_buttons, &dpad_panel)) {
        const float top = 14.f;
        const float menu_lane = 72.f;
        const float lane_gap = 8.f;
        const float width_limit = dpad_panel.width - menu_lane - lane_gap;
        const float height_limit = dpad_panel.top - top - 12.f;
        const float mini = std::min(width_limit, height_limit);
        if(mini >= 145.f)
            return {dpad_panel.left, top, mini, mini};
    }

    // Defensive fallback for unusually small/odd displays.
    float mini = static_cast<float>(size.y) * 0.26f;
    if(mini > 190.f) mini = 190.f;
    if(mini < 145.f) mini = 145.f;
    return {static_cast<float>(size.x) - mini - 20.f, 18.f, mini, mini};
}]=])
set(V16_MINIMAP_NEW [=[sf::FloatRect android_map_mini_rect() {
    const sf::Vector2u size = mainPtr().getSize();
    AndroidMobileLayout layout;
    std::array<AndroidDpadButton, 8> dpad_buttons;
    sf::FloatRect dpad_panel;
    if(android_mobile_layout(layout) && android_dpad_geometry(dpad_buttons, &dpad_panel)) {
        const float top = 14.f;
        const float info_gap = 8.f;
        const float menu_lane = 60.f;
        const float lane_gap = 8.f;
        const float left = layout.stats.screen.left + layout.stats.screen.width + info_gap;
        const float right = dpad_panel.left + dpad_panel.width - menu_lane - lane_gap;
        const float width_limit = right - left;
        const float height_limit = dpad_panel.top - top - 12.f;
        const float mini = std::min(width_limit, height_limit);
        if(mini >= 145.f)
            return {left, top, mini, mini};
    }

    // Defensive fallback for unusually small/odd displays.
    float mini = static_cast<float>(size.y) * 0.26f;
    if(mini > 190.f) mini = 190.f;
    if(mini < 145.f) mini = 145.f;
    return {static_cast<float>(size.x) - mini - 20.f, 18.f, mini, mini};
}]=])
string(FIND "${V16_WINUTIL}" "${V16_MINIMAP_OLD}" V16_MINIMAP_POS)
if(V16_MINIMAP_POS EQUAL -1)
    message(FATAL_ERROR "v16: expected v15 minimap geometry not found")
endif()
string(REPLACE "${V16_MINIMAP_OLD}" "${V16_MINIMAP_NEW}" V16_WINUTIL "${V16_WINUTIL}")

# Native scrollbar drawing and gesture helpers. The tracks sit in the spare
# horizontal margin beside the fitted panel textures whenever possible, so they
# do not cover inventory action icons or transcript text.
set(V16_SCROLL_HELPER_ANCHOR [=[class AndroidMobileShellDrawable : public iDrawable {]=])
set(V16_SCROLL_HELPER_INSERT [=[std::shared_ptr<cScrollbar> android_panel_scrollbar(AndroidPanelScrollTarget target) {
    if(target == ANDROID_PANEL_SCROLL_INVENTORY)
        return item_sbar;
    if(target == ANDROID_PANEL_SCROLL_TRANSCRIPT)
        return text_sbar;
    return nullptr;
}

long android_panel_scroll_min(AndroidPanelScrollTarget target) {
    if(target == ANDROID_PANEL_SCROLL_TRANSCRIPT)
        return android_transcript_min_position();
    return 0;
}

long android_panel_scroll_max(AndroidPanelScrollTarget target) {
    std::shared_ptr<cScrollbar> bar = android_panel_scrollbar(target);
    return bar ? bar->getMaximum() : 0;
}

const AndroidMappedPanel* android_panel_for_scroll_target(const AndroidMobileLayout& layout,
                                                           AndroidPanelScrollTarget target) {
    if(target == ANDROID_PANEL_SCROLL_INVENTORY)
        return &layout.inventory;
    if(target == ANDROID_PANEL_SCROLL_TRANSCRIPT)
        return &layout.transcript;
    return nullptr;
}

bool android_panel_scrollbar_geometry(AndroidPanelScrollTarget target,
                                      sf::FloatRect& track,
                                      sf::FloatRect& thumb) {
    AndroidMobileLayout layout;
    if(!android_mobile_layout(layout))
        return false;
    const AndroidMappedPanel* panel = android_panel_for_scroll_target(layout, target);
    std::shared_ptr<cScrollbar> bar = android_panel_scrollbar(target);
    if(!panel || !bar)
        return false;

    const long min_pos = android_panel_scroll_min(target);
    const long max_pos = android_panel_scroll_max(target);
    if(max_pos <= min_pos)
        return false;

    float track_w = 14.f;
    float track_left = panel->screen.left + panel->screen.width + 6.f;
    const float info_right = layout.info_column.left + layout.info_column.width - 3.f;
    if(track_left + track_w > info_right)
        track_left = panel->screen.left + panel->screen.width - track_w - 4.f;
    track = {track_left, panel->screen.top + 5.f,
             track_w, std::max(28.f, panel->screen.height - 10.f)};

    const long visible = target == ANDROID_PANEL_SCROLL_INVENTORY ? 8 : 11;
    const long range = max_pos - min_pos;
    const float visible_fraction = static_cast<float>(visible) /
        static_cast<float>(visible + range);
    float thumb_h = track.height * visible_fraction;
    if(thumb_h < 30.f) thumb_h = 30.f;
    if(thumb_h > track.height) thumb_h = track.height;

    long pos = bar->getPosition();
    if(pos < min_pos) pos = min_pos;
    if(pos > max_pos) pos = max_pos;
    const float fraction = range > 0 ?
        static_cast<float>(pos - min_pos) / static_cast<float>(range) : 0.f;
    const float travel = track.height - thumb_h;
    thumb = {track.left, track.top + travel * fraction, track.width, thumb_h};
    return true;
}

void android_refresh_panel_scroll(AndroidPanelScrollTarget target) {
    if(target == ANDROID_PANEL_SCROLL_INVENTORY)
        put_item_screen(stat_window);
    else if(target == ANDROID_PANEL_SCROLL_TRANSCRIPT)
        print_buf();
}

void android_set_panel_scroll_position(AndroidPanelScrollTarget target, long position) {
    std::shared_ptr<cScrollbar> bar = android_panel_scrollbar(target);
    if(!bar)
        return;
    const long min_pos = android_panel_scroll_min(target);
    const long max_pos = android_panel_scroll_max(target);
    if(position < min_pos) position = min_pos;
    if(position > max_pos) position = max_pos;
    if(position == bar->getPosition())
        return;
    bar->setPosition(position);
    android_refresh_panel_scroll(target);
}

void android_scroll_track_to_y(AndroidPanelScrollTarget target, float y) {
    sf::FloatRect track, thumb;
    if(!android_panel_scrollbar_geometry(target, track, thumb))
        return;
    const long min_pos = android_panel_scroll_min(target);
    const long max_pos = android_panel_scroll_max(target);
    const long range = max_pos - min_pos;
    const float travel = track.height - thumb.height;
    if(range <= 0 || travel <= 0.f)
        return;
    float local = y - track.top - thumb.height * 0.5f;
    if(local < 0.f) local = 0.f;
    if(local > travel) local = travel;
    const float fraction = local / travel;
    const long new_pos = min_pos + static_cast<long>(fraction * static_cast<float>(range) + 0.5f);
    android_set_panel_scroll_position(target, new_pos);
}

bool android_begin_panel_scroll(int x, int y) {
    android_panel_scroll_target = ANDROID_PANEL_SCROLL_NONE;
    android_panel_scroll_dragging = false;
    android_panel_scroll_track_drag = false;

    if(!android_mobile_input_enabled())
        return false;

    const float fx = static_cast<float>(x);
    const float fy = static_cast<float>(y);
    AndroidMobileLayout layout;
    if(!android_mobile_layout(layout))
        return false;

    for(AndroidPanelScrollTarget target : {ANDROID_PANEL_SCROLL_INVENTORY,
                                           ANDROID_PANEL_SCROLL_TRANSCRIPT}) {
        sf::FloatRect track, thumb;
        if(!android_panel_scrollbar_geometry(target, track, thumb))
            continue;
        if(track.contains(fx, fy)) {
            android_panel_scroll_target = target;
            android_panel_scroll_dragging = true;
            android_panel_scroll_track_drag = true;
            android_panel_scroll_start_y = fy;
            std::shared_ptr<cScrollbar> bar = android_panel_scrollbar(target);
            android_panel_scroll_start_position = bar ? bar->getPosition() : 0;
            android_scroll_track_to_y(target, fy);
            return true;
        }

        const AndroidMappedPanel* panel = android_panel_for_scroll_target(layout, target);
        if(panel && panel->screen.contains(fx, fy)) {
            android_panel_scroll_target = target;
            android_panel_scroll_start_y = fy;
            std::shared_ptr<cScrollbar> bar = android_panel_scrollbar(target);
            android_panel_scroll_start_position = bar ? bar->getPosition() : 0;
            return false;
        }
    }
    return false;
}

bool android_update_panel_scroll(int x, int y) {
    if(android_panel_scroll_target == ANDROID_PANEL_SCROLL_NONE)
        return false;
    const float fy = static_cast<float>(y);
    if(android_panel_scroll_track_drag) {
        android_scroll_track_to_y(android_panel_scroll_target, fy);
        return true;
    }

    const float delta = android_panel_scroll_start_y - fy;
    if(!android_panel_scroll_dragging) {
        if(delta > -14.f && delta < 14.f)
            return true;
        android_panel_scroll_dragging = true;
    }

    AndroidMobileLayout layout;
    if(!android_mobile_layout(layout))
        return true;
    const AndroidMappedPanel* panel = android_panel_for_scroll_target(layout, android_panel_scroll_target);
    if(!panel)
        return true;
    const float visible_rows = android_panel_scroll_target == ANDROID_PANEL_SCROLL_INVENTORY ? 8.f : 11.f;
    float step_px = panel->screen.height / visible_rows;
    if(step_px < 1.f) step_px = 1.f;
    const long steps = static_cast<long>(delta / step_px);
    android_set_panel_scroll_position(android_panel_scroll_target,
                                      android_panel_scroll_start_position + steps);
    return true;
}

bool android_end_panel_scroll() {
    if(android_panel_scroll_target == ANDROID_PANEL_SCROLL_NONE)
        return false;
    const bool consumed = android_panel_scroll_dragging || android_panel_scroll_track_drag;
    android_panel_scroll_target = ANDROID_PANEL_SCROLL_NONE;
    android_panel_scroll_dragging = false;
    android_panel_scroll_track_drag = false;
    return consumed;
}

void android_draw_panel_scrollbar(AndroidPanelScrollTarget target) {
    sf::FloatRect track, thumb;
    if(!android_panel_scrollbar_geometry(target, track, thumb))
        return;

    sf::RectangleShape track_shape({track.width, track.height});
    track_shape.setPosition(track.left, track.top);
    track_shape.setFillColor(sf::Color(17,17,20,215));
    track_shape.setOutlineColor(sf::Color(215,205,178,175));
    track_shape.setOutlineThickness(1.f);
    mainPtr().draw(track_shape);

    sf::RectangleShape thumb_shape({thumb.width, thumb.height});
    thumb_shape.setPosition(thumb.left, thumb.top);
    thumb_shape.setFillColor(sf::Color(215,215,220,235));
    thumb_shape.setOutlineColor(sf::Color(35,35,40,245));
    thumb_shape.setOutlineThickness(1.f);
    mainPtr().draw(thumb_shape);
}

class AndroidMobileShellDrawable : public iDrawable {]=])
string(FIND "${V16_WINUTIL}" "${V16_SCROLL_HELPER_ANCHOR}" V16_SCROLL_HELPER_POS)
if(V16_SCROLL_HELPER_POS EQUAL -1)
    message(FATAL_ERROR "v16: expected Android mobile shell class anchor not found")
endif()
string(REPLACE "${V16_SCROLL_HELPER_ANCHOR}" "${V16_SCROLL_HELPER_INSERT}" V16_WINUTIL "${V16_WINUTIL}")

# Paint the native scrollbars on top of the independent panel textures.
set(V16_SHELL_DRAW_OLD [=[        draw_panel_texture(text_area_gworld(), layout.transcript.screen);

        mainPtr().setView(previous_view);]=])
set(V16_SHELL_DRAW_NEW [=[        draw_panel_texture(text_area_gworld(), layout.transcript.screen);
        android_draw_panel_scrollbar(ANDROID_PANEL_SCROLL_INVENTORY);
        android_draw_panel_scrollbar(ANDROID_PANEL_SCROLL_TRANSCRIPT);

        mainPtr().setView(previous_view);]=])
string(FIND "${V16_WINUTIL}" "${V16_SHELL_DRAW_OLD}" V16_SHELL_DRAW_POS)
if(V16_SHELL_DRAW_POS EQUAL -1)
    message(FATAL_ERROR "v16: expected Android shell draw tail not found")
endif()
string(REPLACE "${V16_SHELL_DRAW_OLD}" "${V16_SHELL_DRAW_NEW}" V16_WINUTIL "${V16_WINUTIL}")

# Direct SFML touch path: tapping outside the actual map content closes the full
# overlay. Also let the live minimap open the full map directly.
set(V16_TOUCH_MAP_OLD [=[                if(&win == &mainPtr() && android_map_overlay_visible) {
                    const sf::FloatRect close_rect = android_map_overlay_close_rect();
                    if(close_rect.contains(static_cast<float>(x), static_cast<float>(y)))
                        android_map_overlay_visible = false;
                    android_map_close_finger = static_cast<int>(event.touch.finger);
                    event.type = sf::Event::Count;
                    break;
                }]=])
set(V16_TOUCH_MAP_NEW [=[                if(&win == &mainPtr() && android_map_overlay_visible) {
                    const float fx = static_cast<float>(x);
                    const float fy = static_cast<float>(y);
                    const sf::FloatRect close_rect = android_map_overlay_close_rect();
                    const sf::FloatRect dest = android_map_overlay_destination();
                    const bool inside_map = fx >= dest.left - 8.f && fx <= dest.left + dest.width + 8.f &&
                                            fy >= dest.top - 8.f && fy <= dest.top + dest.height + 8.f;
                    if(close_rect.contains(fx, fy) || !inside_map)
                        android_map_overlay_visible = false;
                    android_map_close_finger = static_cast<int>(event.touch.finger);
                    event.type = sf::Event::Count;
                    break;
                }
                if(&win == &mainPtr() && !android_legacy_menu_open && !cDialog::anyOpen() &&
                   (overall_mode == MODE_OUTDOORS || overall_mode == MODE_TOWN) &&
                   android_map_mini_rect().contains(static_cast<float>(x), static_cast<float>(y))) {
                    android_quick_menu_open = false;
                    display_map();
                    android_map_cache_dirty = false;
                    android_map_overlay_visible = true;
                    android_map_close_finger = static_cast<int>(event.touch.finger);
                    event.type = sf::Event::Count;
                    break;
                }]=])
string(FIND "${V16_WINUTIL}" "${V16_TOUCH_MAP_OLD}" V16_TOUCH_MAP_POS)
if(V16_TOUCH_MAP_POS EQUAL -1)
    message(FATAL_ERROR "v16: expected v12 touch map block not found")
endif()
string(REPLACE "${V16_TOUCH_MAP_OLD}" "${V16_TOUCH_MAP_NEW}" V16_WINUTIL "${V16_WINUTIL}")

# Mouse/Android physical-touch path: same map behavior, then arm a panel swipe
# before the existing info-panel suppression swallows the press.
set(V16_MOUSE_MAP_OLD [=[                if(&win == &mainPtr() && android_map_overlay_visible) {
                    if(event.mouseButton.button == sf::Mouse::Left) {
                        const sf::FloatRect close_rect = android_map_overlay_close_rect();
                        if(close_rect.contains(static_cast<float>(x), static_cast<float>(y)))
                            android_map_overlay_visible = false;
                    }
                    android_map_suppress_mouse_release = true;
                    event.type = sf::Event::Count;
                    break;
                }
                if(&win == &mainPtr() && event.mouseButton.button == sf::Mouse::Left &&
                   android_legacy_menu_capture_press(x, y)) {
                    event.type = sf::Event::Count;
                    break;
                }
                sf::Keyboard::Key primary = sf::Keyboard::Unknown;]=])
set(V16_MOUSE_MAP_NEW [=[                if(&win == &mainPtr() && android_map_overlay_visible) {
                    if(event.mouseButton.button == sf::Mouse::Left) {
                        const float fx = static_cast<float>(x);
                        const float fy = static_cast<float>(y);
                        const sf::FloatRect close_rect = android_map_overlay_close_rect();
                        const sf::FloatRect dest = android_map_overlay_destination();
                        const bool inside_map = fx >= dest.left - 8.f && fx <= dest.left + dest.width + 8.f &&
                                                fy >= dest.top - 8.f && fy <= dest.top + dest.height + 8.f;
                        if(close_rect.contains(fx, fy) || !inside_map)
                            android_map_overlay_visible = false;
                    }
                    android_map_suppress_mouse_release = true;
                    event.type = sf::Event::Count;
                    break;
                }
                if(&win == &mainPtr() && event.mouseButton.button == sf::Mouse::Left &&
                   !android_legacy_menu_open && !cDialog::anyOpen() &&
                   (overall_mode == MODE_OUTDOORS || overall_mode == MODE_TOWN) &&
                   android_map_mini_rect().contains(static_cast<float>(x), static_cast<float>(y))) {
                    android_quick_menu_open = false;
                    display_map();
                    android_map_cache_dirty = false;
                    android_map_overlay_visible = true;
                    android_map_suppress_mouse_release = true;
                    event.type = sf::Event::Count;
                    break;
                }
                if(&win == &mainPtr() && event.mouseButton.button == sf::Mouse::Left &&
                   android_legacy_menu_capture_press(x, y)) {
                    event.type = sf::Event::Count;
                    break;
                }
                if(&win == &mainPtr() && event.mouseButton.button == sf::Mouse::Left &&
                   android_begin_panel_scroll(x, y)) {
                    event.type = sf::Event::Count;
                    break;
                }
                sf::Keyboard::Key primary = sf::Keyboard::Unknown;]=])
string(FIND "${V16_WINUTIL}" "${V16_MOUSE_MAP_OLD}" V16_MOUSE_MAP_POS)
if(V16_MOUSE_MAP_POS EQUAL -1)
    message(FATAL_ERROR "v16: expected v13 mouse map/menu prefix not found")
endif()
string(REPLACE "${V16_MOUSE_MAP_OLD}" "${V16_MOUSE_MAP_NEW}" V16_WINUTIL "${V16_WINUTIL}")

# Once a panel press is armed, use movement as a swipe gesture before the v3
# display-only guard consumes it.
set(V16_MOUSE_MOVE_OLD [=[            case sf::Event::MouseMoved: {
                const int x = event.mouseMove.x;
                const int y = event.mouseMove.y;
                if(&win == &mainPtr() && android_info_panel_contains(x, y)) {
                    event.type = sf::Event::Count;
                    break;
                }]=])
set(V16_MOUSE_MOVE_NEW [=[            case sf::Event::MouseMoved: {
                const int x = event.mouseMove.x;
                const int y = event.mouseMove.y;
                if(&win == &mainPtr() && android_panel_scroll_target != ANDROID_PANEL_SCROLL_NONE) {
                    android_update_panel_scroll(x, y);
                    event.type = sf::Event::Count;
                    break;
                }
                if(&win == &mainPtr() && android_info_panel_contains(x, y)) {
                    event.type = sf::Event::Count;
                    break;
                }]=])
string(FIND "${V16_WINUTIL}" "${V16_MOUSE_MOVE_OLD}" V16_MOUSE_MOVE_POS)
if(V16_MOUSE_MOVE_POS EQUAL -1)
    message(FATAL_ERROR "v16: expected v3 mouse-move panel guard not found")
endif()
string(REPLACE "${V16_MOUSE_MOVE_OLD}" "${V16_MOUSE_MOVE_NEW}" V16_WINUTIL "${V16_WINUTIL}")

# A dragged panel release is consumed. A stationary press is deliberately allowed
# to continue into the existing direct inventory/stats tap dispatcher.
set(V16_MOUSE_RELEASE_OLD [=[                if(&win == &mainPtr() && event.mouseButton.button == sf::Mouse::Left &&
                   (android_legacy_menu_open || android_legacy_menu_pressed != ANDROID_MENU_NONE)) {
                    android_legacy_menu_capture_release(x, y);
                    event.type = sf::Event::Count;
                    break;
                }
                if(&win == &mainPtr() && android_dpad_hold_active) {]=])
set(V16_MOUSE_RELEASE_NEW [=[                if(&win == &mainPtr() && event.mouseButton.button == sf::Mouse::Left &&
                   (android_legacy_menu_open || android_legacy_menu_pressed != ANDROID_MENU_NONE)) {
                    android_legacy_menu_capture_release(x, y);
                    event.type = sf::Event::Count;
                    break;
                }
                if(&win == &mainPtr() && event.mouseButton.button == sf::Mouse::Left &&
                   android_panel_scroll_target != ANDROID_PANEL_SCROLL_NONE) {
                    const bool consumed_scroll = android_end_panel_scroll();
                    if(consumed_scroll) {
                        event.type = sf::Event::Count;
                        break;
                    }
                }
                if(&win == &mainPtr() && android_dpad_hold_active) {]=])
string(FIND "${V16_WINUTIL}" "${V16_MOUSE_RELEASE_OLD}" V16_MOUSE_RELEASE_POS)
if(V16_MOUSE_RELEASE_POS EQUAL -1)
    message(FATAL_ERROR "v16: expected v13 mouse-release menu block not found")
endif()
string(REPLACE "${V16_MOUSE_RELEASE_OLD}" "${V16_MOUSE_RELEASE_NEW}" V16_WINUTIL "${V16_WINUTIL}")

file(WRITE "${CBOE_ANDROID_V16_WINUTIL_CPP}" "${V16_WINUTIL}")
message(STATUS "Applied Android mobile UI v16 map gestures and native panel scrolling")
