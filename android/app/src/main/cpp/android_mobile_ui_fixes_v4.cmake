# Android quick-action overlay applied after the v3 mobile input stabilization.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V4_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V4_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V4_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_WINUTIL_V4_CPP "${CBOE_ANDROID_UI_V4_ROOT}/src/tools/winutil.cpp")
file(READ "${CBOE_ANDROID_WINUTIL_V4_CPP}" CBOE_ANDROID_WINUTIL_V4_SOURCE)

# Add a one-tap Android action menu in the unused centre cell of the 8-way pad.
# The popup calls the engine's real action functions directly instead of routing
# touches through the old desktop toolbar's nested press/release loops.
set(CBOE_ANDROID_V4_ACTION_ANCHOR [=[void draw_panel_texture(const sf::RenderTexture& texture, const sf::FloatRect& dest) {]=])
set(CBOE_ANDROID_V4_ACTION_INSERT [=[enum AndroidQuickAction {
    ANDROID_QUICK_NONE = -1,
    ANDROID_QUICK_TOGGLE = -2,
    ANDROID_QUICK_DISMISS = -3,
    ANDROID_QUICK_SAVE = 0,
    ANDROID_QUICK_LOAD,
    ANDROID_QUICK_LOOK,
    ANDROID_QUICK_MAGE,
    ANDROID_QUICK_PRIEST,
    ANDROID_QUICK_TALK,
    ANDROID_QUICK_USE,
    ANDROID_QUICK_REST_WAIT,
    ANDROID_QUICK_COUNT
};

bool android_quick_menu_open = false;
int android_quick_pressed = ANDROID_QUICK_NONE;

bool android_quick_geometry(sf::FloatRect& toggle,
                            std::array<sf::FloatRect, ANDROID_QUICK_COUNT>& actions,
                            sf::FloatRect* popup_rect = nullptr) {
    if(!android_mobile_ui_visible())
        return false;

    std::array<AndroidDpadButton, 8> dpad_buttons;
    sf::FloatRect dpad_panel;
    if(!android_dpad_geometry(dpad_buttons, &dpad_panel))
        return false;

    const float button_size = dpad_buttons[0].rect.width;
    const float dpad_gap = dpad_buttons[1].rect.left -
        (dpad_buttons[0].rect.left + dpad_buttons[0].rect.width);
    toggle = sf::FloatRect(
        dpad_buttons[0].rect.left + button_size + dpad_gap,
        dpad_buttons[0].rect.top + button_size + dpad_gap,
        button_size,
        button_size
    );

    const sf::Vector2u window_size = mainPtr().getSize();
    const float gap = 8.f;
    float action_w = std::min(132.f, std::max(96.f, static_cast<float>(window_size.y) * 0.14f));
    float action_h = std::min(60.f, std::max(44.f, static_cast<float>(window_size.y) * 0.072f));
    const float total_w = action_w * 2.f + gap;
    const float total_h = action_h * 4.f + gap * 3.f;
    float right = dpad_panel.left - 10.f;
    float left = right - total_w;
    if(left < 8.f)
        left = 8.f;
    float top = (static_cast<float>(window_size.y) - total_h) * 0.5f;
    if(top < 8.f)
        top = 8.f;

    for(int i = 0; i < ANDROID_QUICK_COUNT; ++i) {
        const int row = i / 2;
        const int col = i % 2;
        actions[i] = sf::FloatRect(
            left + col * (action_w + gap),
            top + row * (action_h + gap),
            action_w,
            action_h
        );
    }

    if(popup_rect)
        *popup_rect = sf::FloatRect(left - 8.f, top - 8.f, total_w + 16.f, total_h + 16.f);
    return true;
}

bool android_quick_available(int action) {
    switch(action) {
        case ANDROID_QUICK_SAVE:
        case ANDROID_QUICK_LOAD:
            return overall_mode == MODE_OUTDOORS;
        case ANDROID_QUICK_LOOK:
        case ANDROID_QUICK_MAGE:
        case ANDROID_QUICK_PRIEST:
            return prime_time();
        case ANDROID_QUICK_TALK:
            return overall_mode == MODE_TOWN || overall_mode == MODE_TALK_TOWN;
        case ANDROID_QUICK_USE:
            return overall_mode == MODE_TOWN || overall_mode == MODE_USE_TOWN;
        case ANDROID_QUICK_REST_WAIT:
            return overall_mode == MODE_OUTDOORS || overall_mode == MODE_COMBAT;
        default:
            return false;
    }
}

std::string android_quick_label(int action) {
    switch(action) {
        case ANDROID_QUICK_SAVE: return "SAVE";
        case ANDROID_QUICK_LOAD: return "LOAD";
        case ANDROID_QUICK_LOOK: return "LOOK";
        case ANDROID_QUICK_MAGE: return "MAGE";
        case ANDROID_QUICK_PRIEST: return "PRIEST";
        case ANDROID_QUICK_TALK: return "TALK";
        case ANDROID_QUICK_USE: return "USE";
        case ANDROID_QUICK_REST_WAIT:
            return overall_mode == MODE_OUTDOORS ? "CAMP" : "WAIT";
        default: return "";
    }
}

int android_quick_hit_at(int x, int y) {
    if(!android_mobile_input_enabled())
        return ANDROID_QUICK_NONE;

    sf::FloatRect toggle;
    std::array<sf::FloatRect, ANDROID_QUICK_COUNT> actions;
    if(!android_quick_geometry(toggle, actions))
        return ANDROID_QUICK_NONE;

    const float fx = static_cast<float>(x);
    const float fy = static_cast<float>(y);
    if(toggle.contains(fx, fy))
        return ANDROID_QUICK_TOGGLE;
    if(android_quick_menu_open) {
        for(int i = 0; i < ANDROID_QUICK_COUNT; ++i)
            if(actions[i].contains(fx, fy))
                return i;
    }
    return ANDROID_QUICK_NONE;
}

void android_dispatch_quick_action(int action) {
    bool did_something = false;
    bool need_redraw = false;
    bool need_reprint = false;
    bool handled = true;

    switch(action) {
        case ANDROID_QUICK_SAVE:
            if(overall_mode == MODE_OUTDOORS) do_save(); else handled = false;
            break;
        case ANDROID_QUICK_LOAD:
            if(overall_mode == MODE_OUTDOORS) do_load(); else handled = false;
            break;
        case ANDROID_QUICK_LOOK:
            if(prime_time()) handle_begin_look(false, need_redraw, need_reprint); else handled = false;
            break;
        case ANDROID_QUICK_MAGE:
        case ANDROID_QUICK_PRIEST:
            if(prime_time()) {
                handle_spellcast(action == ANDROID_QUICK_MAGE ? eSkill::MAGE_SPELLS : eSkill::PRIEST_SPELLS,
                                 did_something, need_redraw, need_reprint);
            } else handled = false;
            break;
        case ANDROID_QUICK_TALK:
            if(overall_mode == MODE_TOWN || overall_mode == MODE_TALK_TOWN)
                handle_begin_talk(need_reprint);
            else handled = false;
            break;
        case ANDROID_QUICK_USE:
            if(overall_mode == MODE_TOWN || overall_mode == MODE_USE_TOWN)
                handle_use_space_select(need_reprint);
            else handled = false;
            break;
        case ANDROID_QUICK_REST_WAIT:
            if(overall_mode == MODE_OUTDOORS)
                handle_rest(need_redraw, need_reprint);
            else if(overall_mode == MODE_COMBAT)
                handle_wait(did_something, need_redraw, need_reprint);
            else handled = false;
            break;
        default:
            handled = false;
            break;
    }

    if(handled && action != ANDROID_QUICK_SAVE && action != ANDROID_QUICK_LOAD)
        advance_time(did_something, need_redraw, need_reprint);
}

void draw_android_quick_button(const sf::FloatRect& rect, const std::string& label,
                               bool available, bool pressed) {
    sf::RectangleShape box({rect.width, rect.height});
    box.setPosition(rect.left, rect.top);
    if(!available)
        box.setFillColor(sf::Color(28, 28, 32, 225));
    else if(pressed)
        box.setFillColor(sf::Color(72, 72, 82, 245));
    else
        box.setFillColor(sf::Color(18, 18, 22, 235));
    box.setOutlineColor(available ? sf::Color(238, 238, 238, 230) : sf::Color(110, 110, 116, 190));
    box.setOutlineThickness(2.f);
    mainPtr().draw(box);

    TextStyle style;
    style.font = FONT_BOLD;
    style.pointSize = 12;
    style.lineHeight = 14;
    style.colour = available ? sf::Color::White : sf::Color(130, 130, 136, 255);
    rectangle label_rect {
        static_cast<int>(rect.top),
        static_cast<int>(rect.left),
        static_cast<int>(rect.top + rect.height),
        static_cast<int>(rect.left + rect.width)
    };
    win_draw_string(mainPtr(), label_rect, label, eTextMode::CENTRE, style);
}

class AndroidQuickActionsDrawable : public iDrawable {
public:
    void draw() override {
        sf::FloatRect toggle;
        std::array<sf::FloatRect, ANDROID_QUICK_COUNT> actions;
        sf::FloatRect popup;
        if(!android_quick_geometry(toggle, actions, &popup))
            return;

        const sf::View previous_view = mainPtr().getView();
        mainPtr().setView(mainPtr().getDefaultView());

        draw_android_quick_button(toggle, "ACT", android_mobile_input_enabled(),
                                  android_quick_pressed == ANDROID_QUICK_TOGGLE);

        if(android_quick_menu_open && android_mobile_input_enabled()) {
            sf::RectangleShape panel({popup.width, popup.height});
            panel.setPosition(popup.left, popup.top);
            panel.setFillColor(sf::Color(8, 8, 12, 235));
            panel.setOutlineColor(sf::Color(220, 220, 220, 180));
            panel.setOutlineThickness(2.f);
            mainPtr().draw(panel);

            for(int i = 0; i < ANDROID_QUICK_COUNT; ++i) {
                draw_android_quick_button(actions[i], android_quick_label(i), android_quick_available(i),
                                          android_quick_pressed == i);
            }
        }

        mainPtr().setView(previous_view);
    }
};

void draw_panel_texture(const sf::RenderTexture& texture, const sf::FloatRect& dest) {]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V4_SOURCE}" "${CBOE_ANDROID_V4_ACTION_ANCHOR}" CBOE_ANDROID_V4_ACTION_POS)
if(CBOE_ANDROID_V4_ACTION_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android panel drawing anchor was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V4_ACTION_ANCHOR}" "${CBOE_ANDROID_V4_ACTION_INSERT}" CBOE_ANDROID_WINUTIL_V4_SOURCE "${CBOE_ANDROID_WINUTIL_V4_SOURCE}")

# Register the quick-action overlay above the movement pad.
set(CBOE_ANDROID_V4_REGISTER_OLD [=[    auto dpad = std::make_shared<AndroidDpadDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 80, "android-movement-dpad", dpad);
    registered = true;]=])
set(CBOE_ANDROID_V4_REGISTER_NEW [=[    auto dpad = std::make_shared<AndroidDpadDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 80, "android-movement-dpad", dpad);

    auto quick_actions = std::make_shared<AndroidQuickActionsDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 90, "android-quick-actions", quick_actions);
    registered = true;]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V4_SOURCE}" "${CBOE_ANDROID_V4_REGISTER_OLD}" CBOE_ANDROID_V4_REGISTER_POS)
if(CBOE_ANDROID_V4_REGISTER_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android drawable registration block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V4_REGISTER_OLD}" "${CBOE_ANDROID_V4_REGISTER_NEW}" CBOE_ANDROID_WINUTIL_V4_SOURCE "${CBOE_ANDROID_WINUTIL_V4_SOURCE}")

# Presses on the ACT cell or its popup are captured immediately. Actions fire
# on release, so an action that opens a dialog cannot leak that same release
# into the newly-opened modal.
set(CBOE_ANDROID_V4_MOUSE_PRESS_OLD [=[                sf::Keyboard::Key primary = sf::Keyboard::Unknown;
                sf::Keyboard::Key secondary = sf::Keyboard::Unknown;
                if(&win == &mainPtr() && event.mouseButton.button == sf::Mouse::Left &&
                   android_dpad_keys_at(x, y, primary, secondary)) {
                    android_move_from_keys(primary, secondary);
                    event.type = sf::Event::Count;
                    break;
                }
                if(&win == &mainPtr() && android_info_panel_contains(x, y)) {]=])
set(CBOE_ANDROID_V4_MOUSE_PRESS_NEW [=[                sf::Keyboard::Key primary = sf::Keyboard::Unknown;
                sf::Keyboard::Key secondary = sf::Keyboard::Unknown;
                if(&win == &mainPtr() && event.mouseButton.button == sf::Mouse::Left) {
                    const int quick_hit = android_quick_hit_at(x, y);
                    if(quick_hit != ANDROID_QUICK_NONE) {
                        android_quick_pressed = quick_hit;
                        event.type = sf::Event::Count;
                        break;
                    }
                }
                if(&win == &mainPtr() && event.mouseButton.button == sf::Mouse::Left &&
                   android_dpad_keys_at(x, y, primary, secondary)) {
                    android_quick_menu_open = false;
                    android_move_from_keys(primary, secondary);
                    event.type = sf::Event::Count;
                    break;
                }
                if(&win == &mainPtr() && android_quick_menu_open) {
                    android_quick_menu_open = false;
                    android_quick_pressed = ANDROID_QUICK_DISMISS;
                    event.type = sf::Event::Count;
                    break;
                }
                if(&win == &mainPtr() && android_info_panel_contains(x, y)) {]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V4_SOURCE}" "${CBOE_ANDROID_V4_MOUSE_PRESS_OLD}" CBOE_ANDROID_V4_MOUSE_PRESS_POS)
if(CBOE_ANDROID_V4_MOUSE_PRESS_POS EQUAL -1)
    message(FATAL_ERROR "Expected post-v3 Android mouse press block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V4_MOUSE_PRESS_OLD}" "${CBOE_ANDROID_V4_MOUSE_PRESS_NEW}" CBOE_ANDROID_WINUTIL_V4_SOURCE "${CBOE_ANDROID_WINUTIL_V4_SOURCE}")

set(CBOE_ANDROID_V4_MOUSE_RELEASE_OLD [=[            case sf::Event::MouseButtonReleased: {
                const int x = event.mouseButton.x;
                const int y = event.mouseButton.y;
                if(&win == &mainPtr() && android_info_panel_contains(x, y)) {]=])
set(CBOE_ANDROID_V4_MOUSE_RELEASE_NEW [=[            case sf::Event::MouseButtonReleased: {
                const int x = event.mouseButton.x;
                const int y = event.mouseButton.y;
                if(&win == &mainPtr() && android_quick_pressed != ANDROID_QUICK_NONE) {
                    const int pressed = android_quick_pressed;
                    const int released = android_quick_hit_at(x, y);
                    android_quick_pressed = ANDROID_QUICK_NONE;
                    event.type = sf::Event::Count;
                    if(pressed == released) {
                        if(pressed == ANDROID_QUICK_TOGGLE) {
                            android_quick_menu_open = !android_quick_menu_open;
                        } else if(pressed >= 0 && pressed < ANDROID_QUICK_COUNT) {
                            android_quick_menu_open = false;
                            if(android_quick_available(pressed))
                                android_dispatch_quick_action(pressed);
                        }
                    }
                    break;
                }
                if(&win == &mainPtr() && android_info_panel_contains(x, y)) {]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V4_SOURCE}" "${CBOE_ANDROID_V4_MOUSE_RELEASE_OLD}" CBOE_ANDROID_V4_MOUSE_RELEASE_POS)
if(CBOE_ANDROID_V4_MOUSE_RELEASE_POS EQUAL -1)
    message(FATAL_ERROR "Expected post-v3 Android mouse release block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V4_MOUSE_RELEASE_OLD}" "${CBOE_ANDROID_V4_MOUSE_RELEASE_NEW}" CBOE_ANDROID_WINUTIL_V4_SOURCE "${CBOE_ANDROID_WINUTIL_V4_SOURCE}")

file(WRITE "${CBOE_ANDROID_WINUTIL_V4_CPP}" "${CBOE_ANDROID_WINUTIL_V4_SOURCE}")
message(STATUS "Applied Android mobile UI v4 quick-action overlay")
