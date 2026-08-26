#include "winutil.hpp"

#include <boost/filesystem/operations.hpp>
#include "keymods.hpp"

#ifdef __ANDROID__
#include <array>
#include <deque>
#include <memory>
#include <SFML/Graphics/ConvexShape.hpp>
#include <SFML/Graphics/RectangleShape.hpp>
#include <SFML/Graphics/RenderTexture.hpp>
#include <SFML/Graphics/Sprite.hpp>
#include "game/boe.consts.hpp"
#include "drawable_manager.hpp"

extern cDrawableManager drawable_mgr;
extern eGameMode overall_mode;
extern sf::View mainView;
extern std::deque<sf::Event> fake_event_queue;
extern sf::RenderTexture& terrain_screen_gworld();
extern sf::RenderTexture& pc_stats_gworld();
extern sf::RenderTexture& item_stats_gworld();
extern sf::RenderTexture& text_area_gworld();

namespace {
sf::Vector2i android_pointer_position;
bool android_pointer_valid = false;
int android_dpad_finger = -1;

struct AndroidDpadButton {
    sf::FloatRect rect;
    sf::Keyboard::Key primary;
    sf::Keyboard::Key secondary;
    float angle;
};

struct AndroidMappedPanel {
    sf::FloatRect screen;
    sf::FloatRect legacy;
};

struct AndroidMobileLayout {
    AndroidMappedPanel terrain;
    AndroidMappedPanel stats;
    AndroidMappedPanel inventory;
    AndroidMappedPanel transcript;
    sf::FloatRect info_column;
    bool valid = false;
};

bool android_mobile_ui_visible() {
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

bool android_dpad_visible() {
    return android_mobile_ui_visible();
}

sf::FloatRect fit_inside(const sf::FloatRect& bounds, float source_w, float source_h) {
    if(source_w <= 0.f || source_h <= 0.f || bounds.width <= 0.f || bounds.height <= 0.f)
        return {};

    const float scale = std::min(bounds.width / source_w, bounds.height / source_h);
    const float width = source_w * scale;
    const float height = source_h * scale;
    return {
        bounds.left + (bounds.width - width) * 0.5f,
        bounds.top + (bounds.height - height) * 0.5f,
        width,
        height
    };
}

// Android touch controls intentionally live in physical screen coordinates,
// not OpenBoE's scaled desktop View.
bool android_dpad_geometry(std::array<AndroidDpadButton, 8>& buttons,
                           sf::FloatRect* panel_rect = nullptr) {
    if(!android_dpad_visible())
        return false;

    const sf::Vector2u window_size = mainPtr().getSize();
    if(window_size.x < 600 || window_size.y < 320)
        return false;

    const float gap = 8.f;
    const float right_padding = 44.f;
    const float vertical_padding = 18.f;

    float button_size = static_cast<float>(window_size.y) * 0.115f;
    if(button_size > 86.f) button_size = 86.f;
    if(button_size < 58.f) button_size = 58.f;

    const float grid_size = 3.f * button_size + 2.f * gap;
    float left = static_cast<float>(window_size.x) - right_padding - grid_size;
    float top = (static_cast<float>(window_size.y) - grid_size) / 2.f;

    if(left < static_cast<float>(window_size.x) * 0.70f)
        left = static_cast<float>(window_size.x) * 0.70f;
    if(top < vertical_padding)
        top = vertical_padding;
    if(top + grid_size > static_cast<float>(window_size.y) - vertical_padding)
        top = static_cast<float>(window_size.y) - vertical_padding - grid_size;

    auto cell = [&](int row, int col) {
        return sf::FloatRect(left + col * (button_size + gap),
                             top + row * (button_size + gap),
                             button_size, button_size);
    };

    // Use the same real arrow-key path as desktop movement. OpenBoE deliberately
    // delays arrow keys for a few frames so two keys can combine into a diagonal.
    // The previous Android pad emitted Numpad keys, which bypassed that movement
    // system and did nothing on the physical device.
    buttons = {{
        {cell(0, 0), sf::Keyboard::Up,   sf::Keyboard::Left,  315.f},
        {cell(0, 1), sf::Keyboard::Up,   sf::Keyboard::Unknown, 0.f},
        {cell(0, 2), sf::Keyboard::Up,   sf::Keyboard::Right,  45.f},
        {cell(1, 0), sf::Keyboard::Left, sf::Keyboard::Unknown, 270.f},
        {cell(1, 2), sf::Keyboard::Right,sf::Keyboard::Unknown,  90.f},
        {cell(2, 0), sf::Keyboard::Down, sf::Keyboard::Left,  225.f},
        {cell(2, 1), sf::Keyboard::Down, sf::Keyboard::Unknown, 180.f},
        {cell(2, 2), sf::Keyboard::Down, sf::Keyboard::Right, 135.f}
    }};

    if(panel_rect)
        *panel_rect = sf::FloatRect(left - 10.f, top - 10.f, grid_size + 20.f, grid_size + 20.f);

    return true;
}

bool android_mobile_layout(AndroidMobileLayout& layout) {
    layout = {};
    if(!android_mobile_ui_visible())
        return false;

    const sf::Vector2u size = mainPtr().getSize();
    if(size.x < 900 || size.y < 420)
        return false;

    const float h = static_cast<float>(size.y);
    const float margin = 8.f;
    const float gap = 12.f;

    std::array<AndroidDpadButton, 8> dpad_buttons;
    sf::FloatRect dpad_panel;
    if(!android_dpad_geometry(dpad_buttons, &dpad_panel))
        return false;

    // Give the actual world essentially the full phone height while preserving
    // the original terrain texture aspect ratio. No vertical stretching.
    const float terrain_h = h - margin * 2.f;
    const float terrain_w = terrain_h * (279.f / 351.f);
    const sf::FloatRect terrain_bounds(margin, margin, terrain_w, terrain_h);

    const float info_left = terrain_bounds.left + terrain_bounds.width + gap;
    const float info_right = dpad_panel.left - gap;
    const float info_width = info_right - info_left;
    if(info_width < 260.f)
        return false;

    const float info_bottom = h - margin;
    const float info_height = info_bottom - margin;
    const float stats_h = info_height * 0.24f;
    const float inventory_h = info_height * 0.36f;
    const float transcript_h = info_height - stats_h - inventory_h - gap * 2.f;

    const sf::FloatRect stats_bounds(info_left, margin, info_width, stats_h);
    const sf::FloatRect inventory_bounds(info_left, stats_bounds.top + stats_bounds.height + gap,
                                         info_width, inventory_h);
    const sf::FloatRect transcript_bounds(info_left, inventory_bounds.top + inventory_bounds.height + gap,
                                          info_width, transcript_h);

    // These are the legacy logical rectangles from boe.ui.cpp. Touches on the
    // new panels are translated back into these coordinates so existing game
    // interaction code remains unchanged.
    layout.terrain = {fit_inside(terrain_bounds, 279.f, 351.f), {19.f, 7.f, 279.f, 351.f}};
    layout.stats = {fit_inside(stats_bounds, 271.f, 116.f), {305.f, 7.f, 271.f, 116.f}};
    layout.inventory = {fit_inside(inventory_bounds, 271.f, 144.f), {305.f, 132.f, 271.f, 144.f}};
    layout.transcript = {fit_inside(transcript_bounds, 256.f, 138.f), {305.f, 285.f, 256.f, 138.f}};
    layout.info_column = {info_left, margin, info_width, info_height};
    layout.valid = true;
    return true;
}

bool android_translate_panel_touch(int x, int y, sf::Vector2i& translated_pixel) {
    AndroidMobileLayout layout;
    if(!android_mobile_layout(layout))
        return false;

    const AndroidMappedPanel* panels[] = {
        &layout.terrain, &layout.stats, &layout.inventory, &layout.transcript
    };

    for(const AndroidMappedPanel* panel : panels) {
        if(!panel->screen.contains(static_cast<float>(x), static_cast<float>(y)))
            continue;

        const float u = (static_cast<float>(x) - panel->screen.left) / panel->screen.width;
        const float v = (static_cast<float>(y) - panel->screen.top) / panel->screen.height;
        const sf::Vector2f legacy_point(
            panel->legacy.left + u * panel->legacy.width,
            panel->legacy.top + v * panel->legacy.height
        );
        translated_pixel = mainPtr().mapCoordsToPixel(legacy_point, mainView);
        return true;
    }
    return false;
}

bool android_dpad_keys_at(int pixel_x, int pixel_y,
                          sf::Keyboard::Key& primary,
                          sf::Keyboard::Key& secondary) {
    std::array<AndroidDpadButton, 8> buttons;
    if(!android_dpad_geometry(buttons))
        return false;

    for(const AndroidDpadButton& button : buttons) {
        if(button.rect.contains(static_cast<float>(pixel_x), static_cast<float>(pixel_y))) {
            primary = button.primary;
            secondary = button.secondary;
            return true;
        }
    }
    return false;
}

void draw_panel_texture(const sf::RenderTexture& texture, const sf::FloatRect& dest) {
    const sf::Vector2u tex_size = texture.getTexture().getSize();
    if(tex_size.x == 0 || tex_size.y == 0 || dest.width <= 0.f || dest.height <= 0.f)
        return;

    sf::RectangleShape frame({dest.width + 8.f, dest.height + 8.f});
    frame.setPosition(dest.left - 4.f, dest.top - 4.f);
    frame.setFillColor(sf::Color(12, 12, 14, 255));
    frame.setOutlineColor(sf::Color(215, 205, 178, 180));
    frame.setOutlineThickness(2.f);
    mainPtr().draw(frame);

    sf::Sprite sprite(texture.getTexture());
    sprite.setPosition(dest.left, dest.top);
    sprite.setScale(dest.width / static_cast<float>(tex_size.x),
                    dest.height / static_cast<float>(tex_size.y));
    mainPtr().draw(sprite);
}

class AndroidMobileShellDrawable : public iDrawable {
public:
    void draw() override {
        AndroidMobileLayout layout;
        if(!android_mobile_layout(layout))
            return;

        const sf::View previous_view = mainPtr().getView();
        mainPtr().setView(mainPtr().getDefaultView());

        // The legacy desktop composition is still drawn by the underlying game.
        // Cover it completely before composing the independent Android panels so
        // there are no duplicate/overlapping stats, inventory or toolbar pieces.
        const sf::Vector2u size = mainPtr().getSize();
        sf::RectangleShape backdrop({static_cast<float>(size.x), static_cast<float>(size.y)});
        backdrop.setPosition(0.f, 0.f);
        backdrop.setFillColor(sf::Color(28, 28, 30, 255));
        mainPtr().draw(backdrop);

        draw_panel_texture(terrain_screen_gworld(), layout.terrain.screen);
        draw_panel_texture(pc_stats_gworld(), layout.stats.screen);
        draw_panel_texture(item_stats_gworld(), layout.inventory.screen);
        draw_panel_texture(text_area_gworld(), layout.transcript.screen);

        mainPtr().setView(previous_view);
    }
};

class AndroidDpadDrawable : public iDrawable {
public:
    void draw() override {
        std::array<AndroidDpadButton, 8> buttons;
        sf::FloatRect panel_rect;
        if(!android_dpad_geometry(buttons, &panel_rect))
            return;

        const sf::View previous_view = mainPtr().getView();
        mainPtr().setView(mainPtr().getDefaultView());

        sf::RectangleShape panel({panel_rect.width, panel_rect.height});
        panel.setPosition(panel_rect.left, panel_rect.top);
        panel.setFillColor(sf::Color(12, 12, 16, 180));
        panel.setOutlineColor(sf::Color(220, 220, 220, 145));
        panel.setOutlineThickness(1.f);
        mainPtr().draw(panel);

        for(const AndroidDpadButton& button : buttons) {
            sf::RectangleShape box({button.rect.width, button.rect.height});
            box.setPosition(button.rect.left, button.rect.top);
            box.setFillColor(sf::Color(18, 18, 22, 220));
            box.setOutlineColor(sf::Color(238, 238, 238, 230));
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
            arrow.setFillColor(sf::Color(245, 245, 245, 245));
            mainPtr().draw(arrow);
        }

        mainPtr().setView(previous_view);
    }
};

void ensure_android_mobile_ui_registered() {
    static bool registered = false;
    if(registered)
        return;

    auto shell = std::make_shared<AndroidMobileShellDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 70, "android-mobile-shell", shell);

    auto dpad = std::make_shared<AndroidDpadDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 80, "android-movement-dpad", dpad);
    registered = true;
}

void make_android_key_event(sf::Event& event, sf::Keyboard::Key key) {
    event = sf::Event();
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
    if(scale == 0) {
        const sf::VideoMode desktop = sf::VideoMode::getDesktopMode();
        const double width_scale = (static_cast<double>(desktop.width) * 0.68) / boe_width;
        const double usable_height = desktop.height > 32 ? static_cast<double>(desktop.height - 24) : desktop.height;
        const double height_scale = usable_height / boe_height;
        scale = width_scale < height_scale ? width_scale : height_scale;
        if(scale < 1.0) scale = 1.0;
        if(scale > 2.25) scale = 2.25;
    }

    static bool android_layout_prepared = false;
    if(!android_layout_prepared) {
        set_pref("DisplayMode", 1);
        clear_pref("UIScale");
        android_layout_prepared = true;
    }
    return scale;
#endif

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
    ensure_android_mobile_ui_registered();
    if(android_pointer_valid)
        return android_pointer_position;
#endif
    return sf::Mouse::getPosition(win);
}

bool pollEvent(sf::Window& win, sf::Event& event){
#ifdef __ANDROID__
    ensure_android_mobile_ui_registered();
#endif
    if(win.pollEvent(event)) {
#ifdef __ANDROID__
        switch(event.type) {
            case sf::Event::TouchBegan: {
                const int x = event.touch.x;
                const int y = event.touch.y;
                sf::Keyboard::Key primary = sf::Keyboard::Unknown;
                sf::Keyboard::Key secondary = sf::Keyboard::Unknown;
                if(&win == &mainPtr() && android_dpad_keys_at(x, y, primary, secondary)) {
                    android_dpad_finger = static_cast<int>(event.touch.finger);
                    make_android_key_event(event, primary);

                    // A diagonal is represented by two real arrow presses. Queue
                    // the second one so boe.main's existing 3-frame arrow combiner
                    // sees both keys and produces exactly one diagonal step.
                    if(secondary != sf::Keyboard::Unknown) {
                        sf::Event second;
                        make_android_key_event(second, secondary);
                        fake_event_queue.push_back(second);
                    }
                    break;
                }

                sf::Vector2i translated(x, y);
                if(&win == &mainPtr())
                    android_translate_panel_touch(x, y, translated);
                android_pointer_position = translated;
                android_pointer_valid = true;
                event.type = sf::Event::MouseButtonPressed;
                event.mouseButton.button = sf::Mouse::Left;
                event.mouseButton.x = translated.x;
                event.mouseButton.y = translated.y;
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
                sf::Vector2i translated(x, y);
                if(&win == &mainPtr())
                    android_translate_panel_touch(x, y, translated);
                android_pointer_position = translated;
                android_pointer_valid = true;
                event.type = sf::Event::MouseButtonReleased;
                event.mouseButton.button = sf::Mouse::Left;
                event.mouseButton.x = translated.x;
                event.mouseButton.y = translated.y;
                break;
            }
            case sf::Event::TouchMoved: {
                if(android_dpad_finger == static_cast<int>(event.touch.finger)) {
                    event.type = sf::Event::Count;
                    break;
                }
                const int x = event.touch.x;
                const int y = event.touch.y;
                sf::Vector2i translated(x, y);
                if(&win == &mainPtr())
                    android_translate_panel_touch(x, y, translated);
                android_pointer_position = translated;
                android_pointer_valid = true;
                event.type = sf::Event::MouseMoved;
                event.mouseMove.x = translated.x;
                event.mouseMove.y = translated.y;
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
    while(pollEvent(win, evt));
}

void makeFrontWindow(sf::Window& win, sf::Window& prev) {
    static sf::Event evt;
    _makeFrontWindow(win);
    while(pollEvent(win, evt));
    while(pollEvent(prev, evt));
}

void setWindowFloating(sf::Window& win, bool floating) {
    static sf::Event evt;
    _setWindowFloating(win, floating);
    while(pollEvent(win, evt));
}