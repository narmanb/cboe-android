#include "winutil.hpp"

#include <boost/filesystem/operations.hpp>
#include "keymods.hpp"

#ifdef __ANDROID__
#include <array>
#include <memory>
#include <SFML/Graphics/ConvexShape.hpp>
#include <SFML/Graphics/RectangleShape.hpp>
#include "game/boe.consts.hpp"
#include "drawable_manager.hpp"

extern cDrawableManager drawable_mgr;
extern eGameMode overall_mode;
extern sf::View mainView;

namespace {
sf::Vector2i android_pointer_position;
bool android_pointer_valid = false;
int android_dpad_finger = -1;

struct AndroidDpadButton {
    sf::FloatRect rect;
    sf::Keyboard::Key key;
    float angle;
};

bool android_dpad_visible() {
    switch(overall_mode) {
        case MODE_STARTUP:
        case MODE_TALKING:
        case MODE_SHOPPING:
        case MODE_RESTING:
            return false;
        default:
            return true;
    }
}

bool android_dpad_geometry(std::array<AndroidDpadButton, 8>& buttons,
                           sf::FloatRect* panel_rect = nullptr) {
    if(!android_dpad_visible())
        return false;

    const float panel_left = static_cast<float>(boe_width) + 18.f;
    const float panel_right_padding = 18.f;
    const float available_width = mainView.getSize().x - panel_left - panel_right_padding;
    const float gap = 8.f;

    if(available_width < 150.f)
        return false;

    float button_size = (available_width - 2.f * gap) / 3.f;
    if(button_size > 76.f)
        button_size = 76.f;
    if(button_size < 42.f)
        return false;

    const float grid_size = 3.f * button_size + 2.f * gap;
    const float left = panel_left + (available_width - grid_size) / 2.f;
    float top = (static_cast<float>(boe_height) - grid_size) / 2.f;
    if(top < 48.f)
        top = 48.f;

    auto cell = [&](int row, int col) {
        return sf::FloatRect(left + col * (button_size + gap),
                             top + row * (button_size + gap),
                             button_size, button_size);
    };

    // Keypad numbering gives us exact one-step 8-direction movement through
    // OpenBoE's existing keyboard action path, including combat/target modes.
    buttons = {{
        {cell(0, 0), sf::Keyboard::Numpad7, 315.f},
        {cell(0, 1), sf::Keyboard::Numpad8,   0.f},
        {cell(0, 2), sf::Keyboard::Numpad9,  45.f},
        {cell(1, 0), sf::Keyboard::Numpad4, 270.f},
        {cell(1, 2), sf::Keyboard::Numpad6,  90.f},
        {cell(2, 0), sf::Keyboard::Numpad1, 225.f},
        {cell(2, 1), sf::Keyboard::Numpad2, 180.f},
        {cell(2, 2), sf::Keyboard::Numpad3, 135.f}
    }};

    if(panel_rect)
        *panel_rect = sf::FloatRect(left - 10.f, top - 10.f, grid_size + 20.f, grid_size + 20.f);

    return true;
}

bool android_dpad_key_at(int pixel_x, int pixel_y, sf::Keyboard::Key& key) {
    std::array<AndroidDpadButton, 8> buttons;
    if(!android_dpad_geometry(buttons))
        return false;

    const sf::Vector2f logical = mainPtr().mapPixelToCoords({pixel_x, pixel_y}, mainView);
    for(const AndroidDpadButton& button : buttons) {
        if(button.rect.contains(logical.x, logical.y)) {
            key = button.key;
            return true;
        }
    }
    return false;
}

class AndroidDpadDrawable : public iDrawable {
public:
    void draw() override {
        std::array<AndroidDpadButton, 8> buttons;
        sf::FloatRect panel_rect;
        if(!android_dpad_geometry(buttons, &panel_rect))
            return;

        sf::RectangleShape panel({panel_rect.width, panel_rect.height});
        panel.setPosition(panel_rect.left, panel_rect.top);
        panel.setFillColor(sf::Color(12, 12, 16, 105));
        panel.setOutlineColor(sf::Color(220, 220, 220, 95));
        panel.setOutlineThickness(1.f);
        mainPtr().draw(panel);

        for(const AndroidDpadButton& button : buttons) {
            sf::RectangleShape box({button.rect.width, button.rect.height});
            box.setPosition(button.rect.left, button.rect.top);
            box.setFillColor(sf::Color(18, 18, 22, 175));
            box.setOutlineColor(sf::Color(238, 238, 238, 205));
            box.setOutlineThickness(2.f);
            mainPtr().draw(box);

            const float radius = button.rect.width * 0.18f;
            sf::ConvexShape arrow(3);
            arrow.setPoint(0, {radius, 0.f});
            arrow.setPoint(1, {radius * 2.f, radius * 2.f});
            arrow.setPoint(2, {0.f, radius * 2.f});
            arrow.setOrigin(radius, radius);
            arrow.setPosition(button.rect.left + button.rect.width / 2.f,
                              button.rect.top + button.rect.height / 2.f);
            arrow.setRotation(button.angle);
            arrow.setFillColor(sf::Color(245, 245, 245, 235));
            mainPtr().draw(arrow);
        }
    }
};

void ensure_android_dpad_registered() {
    static bool registered = false;
    if(registered)
        return;

    auto dpad = std::make_shared<AndroidDpadDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 80, "android-movement-dpad", dpad);
    registered = true;
}

void make_android_dpad_key_event(sf::Event& event, sf::Keyboard::Key key) {
    event.type = sf::Event::KeyPressed;
    event.key.code = key;
    event.key.alt = false;
    event.key.control = false;
    event.key.shift = false;
    event.key.system = false;
}
}
#endif

// Measured on 5/23/25. For now, must be re-measured at 1x UI scale whenever preferences change (unless making the window smaller, maybe).
short prefs_height = 529;

// The default scale should be the largest that the user's screen can fit all three
// BoE application windows and core dialogs of the main game (because they should probably default to match each other).
double fallback_scale() {
    static double scale = 0;

#ifdef __ANDROID__
    // The desktop fallback is deliberately conservative because it must fit the
    // game, editors, and large preference dialogs. Android only runs the game,
    // so use the landscape screen much more aggressively while reserving roughly
    // one third of the width for touch controls. OpenBoE's existing viewport
    // math scales the 605x430 game canvas by UIScale, so this makes the old UI
    // close to full-height without distorting its coordinate system.
    if(scale == 0) {
        const sf::VideoMode desktop = sf::VideoMode::getDesktopMode();
        const double width_scale = (static_cast<double>(desktop.width) * 0.68) / boe_width;
        const double usable_height = desktop.height > 32 ? static_cast<double>(desktop.height - 24) : desktop.height;
        const double height_scale = usable_height / boe_height;
        scale = width_scale < height_scale ? width_scale : height_scale;
        if(scale < 1.0) scale = 1.0;
        if(scale > 2.25) scale = 2.25;
    }

    // Previous Android test builds inherited the desktop centered-layout and
    // may also have persisted a 1x UIScale. Force the new Android foundation
    // until the dedicated mobile layout has its own user-facing preferences.
    static bool android_layout_prepared = false;
    if(!android_layout_prepared) {
        set_pref("DisplayMode", 1); // fullscreen, top-left anchored
        clear_pref("UIScale");      // use the Android fallback above
        android_layout_prepared = true;
    }
    return scale;
#endif

    // Suppress the float comparison warning.
    // We know it's safe here - we're just comparing static values.
    #ifdef __GNUC__
    #pragma GCC diagnostic push
    #pragma GCC diagnostic ignored "-Wfloat-equal"
    #endif
    if(scale == 0){
        sf::VideoMode desktop = sf::VideoMode::getDesktopMode();

        short max_width = max(boe_width, max(pc_width, scen_width));
        short max_height = max(prefs_height, max(boe_height, max(pc_height, scen_height))) + getMenubarHeight();

        std::vector<double> scale_options = {1.0, 1.5, 2.0, 3.0, 4.0};
        for(auto it = scale_options.rbegin(); it != scale_options.rend(); ++it){
            short max_scaled_width = max_width * (*it);
            short max_scaled_height = max_height * (*it);

            if(max_scaled_width <= desktop.width && max_scaled_height <= desktop.height){
                scale = (*it);
                break;
            }
        }
    }
    // Hopefully no one would ever have such a small monitor to not fit the default size.
    // But just in case:
    if(scale == 0){
        scale = 1.0;
    }
    #ifdef __GNUC__
    #pragma GCC diagnostic pop
    #endif

    return scale;
}

sf::Vector2i get_pointer_position(sf::Window& win) {
#ifdef __ANDROID__
    ensure_android_dpad_registered();
    if(android_pointer_valid)
        return android_pointer_position;
#endif
    return sf::Mouse::getPosition(win);
}

// We use many nested event loops in this codebase. Each one of them
// calls pollEvent() and they each need to remember to call handleModifier()
// or else modifier keys will claim to be held forever.
// The best solution for this is to wrap pollEvent() so that it calls
// handleModifier for us every time.
bool pollEvent(sf::Window& win, sf::Event& event){
#ifdef __ANDROID__
    ensure_android_dpad_registered();
#endif
    if(win.pollEvent(event)) {
#ifdef __ANDROID__
        // Treat a touchscreen as the desktop left mouse at the common event
        // wrapper. This covers the main loop and all of OpenBoE's nested UI
        // loops, while also remembering coordinates for code that asks for the
        // current pointer position instead of reading coordinates from the event.
        switch(event.type) {
            case sf::Event::TouchBegan: {
                const int x = event.touch.x;
                const int y = event.touch.y;
                sf::Keyboard::Key dpad_key;
                if(&win == &mainPtr() && android_dpad_key_at(x, y, dpad_key)) {
                    android_dpad_finger = static_cast<int>(event.touch.finger);
                    make_android_dpad_key_event(event, dpad_key);
                    break;
                }
                android_pointer_position = {x, y};
                android_pointer_valid = true;
                event.type = sf::Event::MouseButtonPressed;
                event.mouseButton.button = sf::Mouse::Left;
                event.mouseButton.x = x;
                event.mouseButton.y = y;
                break;
            }
            case sf::Event::TouchEnded: {
                if(android_dpad_finger == static_cast<int>(event.touch.finger)) {
                    android_dpad_finger = -1;
                    event.type = sf::Event::Count;
                    break;
                }
                const int x = event.touch.x;
                const int y = event.touch.y;
                android_pointer_position = {x, y};
                android_pointer_valid = true;
                event.type = sf::Event::MouseButtonReleased;
                event.mouseButton.button = sf::Mouse::Left;
                event.mouseButton.x = x;
                event.mouseButton.y = y;
                break;
            }
            case sf::Event::TouchMoved: {
                if(android_dpad_finger == static_cast<int>(event.touch.finger)) {
                    event.type = sf::Event::Count;
                    break;
                }
                const int x = event.touch.x;
                const int y = event.touch.y;
                android_pointer_position = {x, y};
                android_pointer_valid = true;
                event.type = sf::Event::MouseMoved;
                event.mouseMove.x = x;
                event.mouseMove.y = y;
                break;
            }
            case sf::Event::MouseButtonPressed:
            case sf::Event::MouseButtonReleased:
                android_pointer_position = {event.mouseButton.x, event.mouseButton.y};
                android_pointer_valid = true;
                break;
            case sf::Event::MouseMoved:
                android_pointer_position = {event.mouseMove.x, event.mouseMove.y};
                android_pointer_valid = true;
                break;
            default:
                break;
        }
#endif
        if(kb.handleModifier(event)) return false;
        return true;
    }

    return false;
}

bool pollEvent(sf::Window* win, sf::Event& event){
    return pollEvent(*win, event);
}

extern fs::path progDir;

void launchDocs(std::string relative_url) {
    if(fs::is_directory(progDir/"doc")){
        launchURL("file://" + (progDir/"doc"/relative_url).string());
    }else{
        launchURL("http://openboe.com/docs/" + relative_url);
    }
}

bool check_window_moved(sf::RenderWindow& win, int& winLastX, int& winLastY, std::string position_pref) {
    auto winPosition = win.getPosition();
    bool moved = false;
    if(winLastX != winPosition.x || winLastY != winPosition.y){
        // Save the positions of main window and map window as hidden preferences
        // (clamped to keep them fully on-screen when they appear the first time)
        if(!position_pref.empty()){
            sf::VideoMode desktop = sf::VideoMode::getDesktopMode();

            int pref_x = minmax(0, desktop.width - win.getSize().x, winPosition.x);
            int pref_y = minmax(0, desktop.height - win.getSize().y, winPosition.y);
            set_pref(position_pref + "X", pref_x);
            set_pref(position_pref + "Y", pref_y);
        }
        moved = true;
    }
    winLastX = winPosition.x;
    winLastY = winPosition.y;
    return moved;
}

void makeFrontWindow(sf::Window& win) {
    static sf::Event evt;
    _makeFrontWindow(win);
    // Discard GainedFocus events generated by our own meddling:
    while(pollEvent(win, evt));
}

void makeFrontWindow(sf::Window& win, sf::Window& prev) {
    static sf::Event evt;
    _makeFrontWindow(win);
    // Discard GainedFocus and LostFocus events generated by our own meddling:
    while(pollEvent(win, evt));
    while(pollEvent(prev, evt));
}

void setWindowFloating(sf::Window& win, bool floating) {
    static sf::Event evt;
    _setWindowFloating(win, floating);
    // Discard GainedFocus and LostFocus events generated by our own meddling:
    while(pollEvent(win, evt));
}
