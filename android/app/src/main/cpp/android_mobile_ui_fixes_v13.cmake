# Android UI polish and desktop-menubar replacement after v12.
# - Remove the desktop-looking TGUI menubar on Android without losing its commands.
# - Add a touch-native MENU overlay backed by the real handle_menu_choice() actions.
# - Slightly enlarge the D-pad, keep ACT smaller, and enlarge the automap close target.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V13_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V13_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V13_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V13_WINUTIL_CPP "${CBOE_ANDROID_UI_V13_ROOT}/src/tools/winutil.cpp")
set(CBOE_ANDROID_V13_MENUS_CPP "${CBOE_ANDROID_UI_V13_ROOT}/src/game/boe.menus.linux.cpp")
set(CBOE_ANDROID_V13_GRAPHICS_CPP "${CBOE_ANDROID_UI_V13_ROOT}/src/game/boe.graphics.cpp")

# ---------------------------------------------------------------------------
# Hide the desktop TGUI menubar on Android while still constructing menu_ptr.
# This preserves menu state/spell-menu maintenance used by the rest of OpenBoE.
# ---------------------------------------------------------------------------
file(READ "${CBOE_ANDROID_V13_MENUS_CPP}" V13_MENUS)
set(V13_MENUBAR_REGISTER_OLD [=[void init_menubar() {
	menu_ptr.reset(new OpenBoEMenu(univ));
	
	event_listeners["menubar"] = std::dynamic_pointer_cast<iEventListener>(menu_ptr); 
	drawable_mgr.add_drawable(UI_LAYER_MENUBAR, "menubar", menu_ptr); 
}]=])
set(V13_MENUBAR_REGISTER_NEW [=[void init_menubar() {
	menu_ptr.reset(new OpenBoEMenu(univ));
#ifndef __ANDROID__
	event_listeners["menubar"] = std::dynamic_pointer_cast<iEventListener>(menu_ptr);
	drawable_mgr.add_drawable(UI_LAYER_MENUBAR, "menubar", menu_ptr);
#endif
}]=])
string(FIND "${V13_MENUS}" "${V13_MENUBAR_REGISTER_OLD}" V13_MENUBAR_REGISTER_POS)
if(V13_MENUBAR_REGISTER_POS EQUAL -1)
    message(FATAL_ERROR "v13: expected Linux menubar registration block not found")
endif()
string(REPLACE "${V13_MENUBAR_REGISTER_OLD}" "${V13_MENUBAR_REGISTER_NEW}" V13_MENUS "${V13_MENUS}")
file(WRITE "${CBOE_ANDROID_V13_MENUS_CPP}" "${V13_MENUS}")

# Do not reserve/shift the Android viewport for a menubar that is no longer drawn.
file(READ "${CBOE_ANDROID_V13_GRAPHICS_CPP}" V13_GRAPHICS)
set(V13_MENUBAR_LAYOUT_OLD [=[	init_menubar();
	adjust_window_for_menubar(mode, width, height);
	showMenuBar();]=])
set(V13_MENUBAR_LAYOUT_NEW [=[	init_menubar();
#ifndef __ANDROID__
	adjust_window_for_menubar(mode, width, height);
	showMenuBar();
#endif]=])
string(FIND "${V13_GRAPHICS}" "${V13_MENUBAR_LAYOUT_OLD}" V13_MENUBAR_LAYOUT_POS)
if(V13_MENUBAR_LAYOUT_POS EQUAL -1)
    message(FATAL_ERROR "v13: expected menubar viewport block not found")
endif()
string(REPLACE "${V13_MENUBAR_LAYOUT_OLD}" "${V13_MENUBAR_LAYOUT_NEW}" V13_GRAPHICS "${V13_GRAPHICS}")
file(WRITE "${CBOE_ANDROID_V13_GRAPHICS_CPP}" "${V13_GRAPHICS}")

# ---------------------------------------------------------------------------
# winutil.cpp: Android menu, larger D-pad and map close target.
# ---------------------------------------------------------------------------
file(READ "${CBOE_ANDROID_V13_WINUTIL_CPP}" V13_WINUTIL)

set(V13_MENU_INCLUDE_OLD [=[#include "game/boe.actions.hpp"
#include "gfx/render_text.hpp"]=])
set(V13_MENU_INCLUDE_NEW [=[#include "game/boe.actions.hpp"
#include "game/boe.menus.hpp"
#include "gfx/render_text.hpp"]=])
string(FIND "${V13_WINUTIL}" "${V13_MENU_INCLUDE_OLD}" V13_MENU_INCLUDE_POS)
if(V13_MENU_INCLUDE_POS EQUAL -1)
    message(FATAL_ERROR "v13: expected Android game include block not found")
endif()
string(REPLACE "${V13_MENU_INCLUDE_OLD}" "${V13_MENU_INCLUDE_NEW}" V13_WINUTIL "${V13_WINUTIL}")

# One more modest size increase requested by physical testing.
set(V13_DPAD_OLD [=[    const float gap = 10.f;
    const float right_padding = 128.f;
    const float vertical_padding = 18.f;

    float button_size = static_cast<float>(window_size.y) * 0.13f;
    if(button_size > 98.f) button_size = 98.f;
    if(button_size < 66.f) button_size = 66.f;]=])
set(V13_DPAD_NEW [=[    const float gap = 10.f;
    const float right_padding = 128.f;
    const float vertical_padding = 18.f;

    float button_size = static_cast<float>(window_size.y) * 0.142f;
    if(button_size > 106.f) button_size = 106.f;
    if(button_size < 72.f) button_size = 72.f;]=])
string(FIND "${V13_WINUTIL}" "${V13_DPAD_OLD}" V13_DPAD_POS)
if(V13_DPAD_POS EQUAL -1)
    message(FATAL_ERROR "v13: expected v12 d-pad geometry block not found")
endif()
string(REPLACE "${V13_DPAD_OLD}" "${V13_DPAD_NEW}" V13_WINUTIL "${V13_WINUTIL}")

# Keep ACT from growing along with the arrows.
set(V13_ACT_SIZE_OLD [=[    const float toggle_size = button_size * 0.72f;]=])
set(V13_ACT_SIZE_NEW [=[    const float toggle_size = button_size * 0.64f;]=])
string(FIND "${V13_WINUTIL}" "${V13_ACT_SIZE_OLD}" V13_ACT_SIZE_POS)
if(V13_ACT_SIZE_POS EQUAL -1)
    message(FATAL_ERROR "v13: expected v12 ACT size line not found")
endif()
string(REPLACE "${V13_ACT_SIZE_OLD}" "${V13_ACT_SIZE_NEW}" V13_WINUTIL "${V13_WINUTIL}")

# Make the full automap close affordance genuinely finger-sized.
set(V13_MAP_CLOSE_OLD [=[    const float close_size = 44.f;]=])
set(V13_MAP_CLOSE_NEW [=[    const float close_size = 76.f;]=])
string(FIND "${V13_WINUTIL}" "${V13_MAP_CLOSE_OLD}" V13_MAP_CLOSE_POS)
if(V13_MAP_CLOSE_POS EQUAL -1)
    message(FATAL_ERROR "v13: expected v12 map close size not found")
endif()
string(REPLACE "${V13_MAP_CLOSE_OLD}" "${V13_MAP_CLOSE_NEW}" V13_WINUTIL "${V13_WINUTIL}")

# Extend the tiny physical-pixel font so the Android menu can use normal labels.
set(V13_GLYPH_OLD [=[        case 'W': return {{17,17,17,21,21,21,10}};
        default:  return {{0,0,0,0,0,0,0}};]=])
set(V13_GLYPH_NEW [=[        case 'W': return {{17,17,17,21,21,21,10}};
        case 'B': return {{30,17,17,30,17,17,30}};
        case 'F': return {{31,16,16,30,16,16,16}};
        case 'H': return {{17,17,17,31,17,17,17}};
        case 'J': return {{7,2,2,2,18,18,12}};
        case 'N': return {{17,25,21,19,17,17,17}};
        case 'Q': return {{14,17,17,17,21,18,13}};
        case 'X': return {{17,17,10,4,10,17,17}};
        case 'Y': return {{17,17,10,4,4,4,4}};
        case 'Z': return {{31,1,2,4,8,16,31}};
        case '0': return {{14,17,19,21,25,17,14}};
        case '1': return {{4,12,4,4,4,4,14}};
        case '2': return {{14,17,1,2,4,8,31}};
        case '3': return {{30,1,1,14,1,1,30}};
        case '4': return {{2,6,10,18,31,2,2}};
        case '5': return {{31,16,16,30,1,1,30}};
        case '6': return {{14,16,16,30,17,17,14}};
        case '7': return {{31,1,2,4,8,8,8}};
        case '8': return {{14,17,17,14,17,17,14}};
        case '9': return {{14,17,17,15,1,1,14}};
        default:  return {{0,0,0,0,0,0,0}};]=])
string(FIND "${V13_WINUTIL}" "${V13_GLYPH_OLD}" V13_GLYPH_POS)
if(V13_GLYPH_POS EQUAL -1)
    message(FATAL_ERROR "v13: expected Android pixel-font tail not found")
endif()
string(REPLACE "${V13_GLYPH_OLD}" "${V13_GLYPH_NEW}" V13_WINUTIL "${V13_WINUTIL}")

# Menu state lives beside the other Android-only UI state.
set(V13_MENU_STATE_OLD [=[sf::Clock android_dpad_repeat_clock;]=])
set(V13_MENU_STATE_NEW [=[sf::Clock android_dpad_repeat_clock;
bool android_legacy_menu_open = false;
int android_legacy_menu_page = 0;
int android_legacy_menu_pressed = -1000;]=])
string(FIND "${V13_WINUTIL}" "${V13_MENU_STATE_OLD}" V13_MENU_STATE_POS)
if(V13_MENU_STATE_POS EQUAL -1)
    message(FATAL_ERROR "v13: expected v12 d-pad clock state not found")
endif()
string(REPLACE "${V13_MENU_STATE_OLD}" "${V13_MENU_STATE_NEW}" V13_WINUTIL "${V13_WINUTIL}")

# Hide the tiny live minimap while the Android menu is open.
set(V13_MINI_GUARD_OLD [=[        if(android_map_overlay_visible || !android_mobile_input_enabled())
            return;]=])
set(V13_MINI_GUARD_NEW [=[        if(android_map_overlay_visible || android_legacy_menu_open || !android_mobile_input_enabled())
            return;]=])
string(FIND "${V13_WINUTIL}" "${V13_MINI_GUARD_OLD}" V13_MINI_GUARD_POS)
if(V13_MINI_GUARD_POS EQUAL -1)
    message(FATAL_ERROR "v13: expected v12 live minimap guard not found")
endif()
string(REPLACE "${V13_MINI_GUARD_OLD}" "${V13_MINI_GUARD_NEW}" V13_WINUTIL "${V13_WINUTIL}")

# Add an Android-native category menu before the D-pad drawable. It uses the
# same eMenu dispatcher as desktop, so unique commands are preserved without
# routing touches through the TGUI desktop menubar.
set(V13_MENU_CLASS_ANCHOR [=[class AndroidDpadDrawable : public iDrawable {]=])
set(V13_MENU_CLASS_INSERT [=[enum AndroidLegacyMenuPage {
    ANDROID_MENU_ROOT = 0,
    ANDROID_MENU_FILE,
    ANDROID_MENU_PARTY,
    ANDROID_MENU_ACTIONS,
    ANDROID_MENU_LIBRARY,
    ANDROID_MENU_HELP
};

constexpr int ANDROID_MENU_NONE = -1000;
constexpr int ANDROID_MENU_TOGGLE = -1001;
constexpr int ANDROID_MENU_BACK = -1002;
constexpr int ANDROID_MENU_CLOSE = -1003;
constexpr int ANDROID_MENU_BLOCK = -1004;
constexpr int ANDROID_MENU_ITEM_BASE = 100;

struct AndroidLegacyMenuItem {
    std::string label;
    eMenu action;
};

struct AndroidLegacyMenuRootItem {
    std::string label;
    int page;
};

std::vector<AndroidLegacyMenuRootItem> android_legacy_menu_root_items() {
    if(overall_mode == MODE_STARTUP)
        return {{"FILE", ANDROID_MENU_FILE}, {"LIBRARY", ANDROID_MENU_LIBRARY}, {"HELP", ANDROID_MENU_HELP}};
    return {{"FILE", ANDROID_MENU_FILE}, {"PARTY", ANDROID_MENU_PARTY},
            {"ACTIONS", ANDROID_MENU_ACTIONS}, {"LIBRARY", ANDROID_MENU_LIBRARY},
            {"HELP", ANDROID_MENU_HELP}};
}

std::vector<AndroidLegacyMenuItem> android_legacy_menu_items() {
    switch(android_legacy_menu_page) {
        case ANDROID_MENU_FILE:
            if(overall_mode == MODE_STARTUP)
                return {{"NEW GAME", eMenu::FILE_NEW}, {"OPEN GAME", eMenu::FILE_OPEN},
                        {"PREFS", eMenu::PREFS}, {"QUIT", eMenu::QUIT}};
            return {{"SAVE", eMenu::FILE_SAVE}, {"SAVE AS", eMenu::FILE_SAVE_AS},
                    {"NEW GAME", eMenu::FILE_NEW}, {"OPEN GAME", eMenu::FILE_OPEN},
                    {"ABORT", eMenu::FILE_ABORT}, {"PREFS", eMenu::PREFS},
                    {"QUIT", eMenu::QUIT}};
        case ANDROID_MENU_PARTY:
            return {{"GRAPHIC", eMenu::OPTIONS_PC_GRAPHIC}, {"RENAME", eMenu::OPTIONS_RENAME_PC},
                    {"NEW PC", eMenu::OPTIONS_NEW_PC}, {"DELETE PC", eMenu::OPTIONS_DELETE_PC},
                    {"TALK NOTES", eMenu::OPTIONS_TALK_NOTES}, {"ENCOUNTER", eMenu::OPTIONS_ENCOUNTER_NOTES},
                    {"PARTY STATS", eMenu::OPTIONS_STATS}, {"JOURNAL", eMenu::OPTIONS_JOURNAL}};
        case ANDROID_MENU_ACTIONS:
            // MAP is already a first-class ACT command; keep the unique desktop actions here.
            return {{"ALCHEMY", eMenu::ACTIONS_ALCHEMY}, {"WAIT 80", eMenu::ACTIONS_WAIT}};
        case ANDROID_MENU_LIBRARY:
            return {{"MAGE SPELLS", eMenu::LIBRARY_MAGE}, {"PRIEST SPELLS", eMenu::LIBRARY_PRIEST},
                    {"SKILL INFO", eMenu::LIBRARY_SKILLS}, {"ALCHEMY", eMenu::LIBRARY_ALCHEMY},
                    {"TIPS", eMenu::LIBRARY_TIPS}, {"INTRO", eMenu::LIBRARY_INTRO}};
        case ANDROID_MENU_HELP:
            return {{"INDEX", eMenu::HELP_TOC}, {"ABOUT", eMenu::ABOUT},
                    {"OUTDOOR", eMenu::HELP_OUT}, {"TOWN", eMenu::HELP_TOWN},
                    {"COMBAT", eMenu::HELP_COMBAT}, {"BARRIER", eMenu::HELP_BARRIER},
                    {"HINTS", eMenu::HELP_HINTS}, {"SPELL HELP", eMenu::HELP_SPELLS}};
        default:
            return {};
    }
}

sf::FloatRect android_legacy_menu_button_rect() {
    const sf::Vector2u size = mainPtr().getSize();
    float mini = static_cast<float>(size.y) * 0.26f;
    if(mini > 190.f) mini = 190.f;
    if(mini < 145.f) mini = 145.f;
    const float width = 132.f;
    const float height = 58.f;
    const float right = static_cast<float>(size.x) - mini - 34.f;
    return {right - width, 18.f, width, height};
}

sf::FloatRect android_legacy_menu_panel_rect() {
    const sf::Vector2u size = mainPtr().getSize();
    float width = std::min(820.f, static_cast<float>(size.x) * 0.62f);
    float height = std::min(540.f, static_cast<float>(size.y) - 56.f);
    return {(static_cast<float>(size.x) - width) * 0.5f,
            (static_cast<float>(size.y) - height) * 0.5f,
            width, height};
}

sf::FloatRect android_legacy_menu_back_rect() {
    const sf::FloatRect panel = android_legacy_menu_panel_rect();
    return {panel.left + 18.f, panel.top + 16.f, 126.f, 52.f};
}

sf::FloatRect android_legacy_menu_close_rect() {
    const sf::FloatRect panel = android_legacy_menu_panel_rect();
    return {panel.left + panel.width - 144.f, panel.top + 16.f, 126.f, 52.f};
}

sf::FloatRect android_legacy_menu_item_rect(int index, int count) {
    const sf::FloatRect panel = android_legacy_menu_panel_rect();
    const float gap = 12.f;
    const int cols = 2;
    const int rows = std::max(1, (count + cols - 1) / cols);
    const float left_margin = 22.f;
    const float item_w = (panel.width - left_margin * 2.f - gap) / 2.f;
    const float available_h = panel.height - 106.f;
    float item_h = (available_h - gap * static_cast<float>(rows - 1)) / static_cast<float>(rows);
    if(item_h > 86.f) item_h = 86.f;
    const float total_h = item_h * static_cast<float>(rows) + gap * static_cast<float>(rows - 1);
    const float top = panel.top + 84.f + std::max(0.f, (available_h - total_h) * 0.5f);
    const int row = index / cols;
    const int col = index % cols;
    return {panel.left + left_margin + static_cast<float>(col) * (item_w + gap),
            top + static_cast<float>(row) * (item_h + gap), item_w, item_h};
}

int android_legacy_menu_hit_at(int x, int y) {
    const float fx = static_cast<float>(x);
    const float fy = static_cast<float>(y);
    if(!android_legacy_menu_open)
        return android_legacy_menu_button_rect().contains(fx, fy) ? ANDROID_MENU_TOGGLE : ANDROID_MENU_NONE;

    if(android_legacy_menu_close_rect().contains(fx, fy))
        return ANDROID_MENU_CLOSE;
    if(android_legacy_menu_page != ANDROID_MENU_ROOT && android_legacy_menu_back_rect().contains(fx, fy))
        return ANDROID_MENU_BACK;

    if(android_legacy_menu_page == ANDROID_MENU_ROOT) {
        const auto items = android_legacy_menu_root_items();
        for(int i = 0; i < static_cast<int>(items.size()); ++i)
            if(android_legacy_menu_item_rect(i, static_cast<int>(items.size())).contains(fx, fy))
                return ANDROID_MENU_ITEM_BASE + i;
    } else {
        const auto items = android_legacy_menu_items();
        for(int i = 0; i < static_cast<int>(items.size()); ++i)
            if(android_legacy_menu_item_rect(i, static_cast<int>(items.size())).contains(fx, fy))
                return ANDROID_MENU_ITEM_BASE + i;
    }
    return ANDROID_MENU_BLOCK;
}

bool android_legacy_menu_capture_press(int x, int y) {
    if(cDialog::anyOpen() || android_map_overlay_visible)
        return false;
    const int hit = android_legacy_menu_hit_at(x, y);
    if(hit == ANDROID_MENU_NONE)
        return false;
    android_legacy_menu_pressed = hit;
    return true;
}

void android_legacy_menu_close() {
    android_legacy_menu_open = false;
    android_legacy_menu_page = ANDROID_MENU_ROOT;
    android_legacy_menu_pressed = ANDROID_MENU_NONE;
}

bool android_legacy_menu_capture_release(int x, int y) {
    if(android_legacy_menu_pressed == ANDROID_MENU_NONE)
        return android_legacy_menu_open;

    const int pressed = android_legacy_menu_pressed;
    const int released = android_legacy_menu_hit_at(x, y);
    android_legacy_menu_pressed = ANDROID_MENU_NONE;

    if(pressed != released)
        return true;

    if(pressed == ANDROID_MENU_TOGGLE) {
        android_legacy_menu_open = true;
        android_legacy_menu_page = ANDROID_MENU_ROOT;
        android_quick_menu_open = false;
        android_end_dpad_hold();
        return true;
    }
    if(pressed == ANDROID_MENU_CLOSE) {
        android_legacy_menu_close();
        return true;
    }
    if(pressed == ANDROID_MENU_BACK) {
        android_legacy_menu_page = ANDROID_MENU_ROOT;
        return true;
    }
    if(pressed >= ANDROID_MENU_ITEM_BASE) {
        const int index = pressed - ANDROID_MENU_ITEM_BASE;
        if(android_legacy_menu_page == ANDROID_MENU_ROOT) {
            const auto items = android_legacy_menu_root_items();
            if(index >= 0 && index < static_cast<int>(items.size()))
                android_legacy_menu_page = items[index].page;
            return true;
        }
        const auto items = android_legacy_menu_items();
        if(index >= 0 && index < static_cast<int>(items.size())) {
            const eMenu action = items[index].action;
            android_legacy_menu_close();
            handle_menu_choice(action);
        }
        return true;
    }
    return true;
}

class AndroidLegacyMenuDrawable : public iDrawable {
public:
    void draw() override {
        if(cDialog::anyOpen() || android_map_overlay_visible)
            return;

        const sf::View previous_view = mainPtr().getView();
        mainPtr().setView(mainPtr().getDefaultView());

        if(!android_legacy_menu_open) {
            draw_android_quick_button(android_legacy_menu_button_rect(), "MENU", true,
                                      android_legacy_menu_pressed == ANDROID_MENU_TOGGLE);
            mainPtr().setView(previous_view);
            return;
        }

        const sf::Vector2u size = mainPtr().getSize();
        sf::RectangleShape shade({static_cast<float>(size.x), static_cast<float>(size.y)});
        shade.setPosition(0.f, 0.f);
        shade.setFillColor(sf::Color(0,0,0,205));
        mainPtr().draw(shade);

        const sf::FloatRect panel_rect = android_legacy_menu_panel_rect();
        sf::RectangleShape panel({panel_rect.width, panel_rect.height});
        panel.setPosition(panel_rect.left, panel_rect.top);
        panel.setFillColor(sf::Color(15,15,19,252));
        panel.setOutlineColor(sf::Color(226,216,190,235));
        panel.setOutlineThickness(3.f);
        mainPtr().draw(panel);

        if(android_legacy_menu_page != ANDROID_MENU_ROOT)
            draw_android_quick_button(android_legacy_menu_back_rect(), "BACK", true,
                                      android_legacy_menu_pressed == ANDROID_MENU_BACK);
        draw_android_quick_button(android_legacy_menu_close_rect(), "CLOSE", true,
                                  android_legacy_menu_pressed == ANDROID_MENU_CLOSE);

        if(android_legacy_menu_page == ANDROID_MENU_ROOT) {
            const auto items = android_legacy_menu_root_items();
            for(int i = 0; i < static_cast<int>(items.size()); ++i)
                draw_android_quick_button(android_legacy_menu_item_rect(i, static_cast<int>(items.size())),
                                          items[i].label, true,
                                          android_legacy_menu_pressed == ANDROID_MENU_ITEM_BASE + i);
        } else {
            const auto items = android_legacy_menu_items();
            for(int i = 0; i < static_cast<int>(items.size()); ++i)
                draw_android_quick_button(android_legacy_menu_item_rect(i, static_cast<int>(items.size())),
                                          items[i].label, true,
                                          android_legacy_menu_pressed == ANDROID_MENU_ITEM_BASE + i);
        }

        mainPtr().setView(previous_view);
    }
};

class AndroidDpadDrawable : public iDrawable {]=])
string(FIND "${V13_WINUTIL}" "${V13_MENU_CLASS_ANCHOR}" V13_MENU_CLASS_POS)
if(V13_MENU_CLASS_POS EQUAL -1)
    message(FATAL_ERROR "v13: expected Android D-pad drawable anchor not found")
endif()
string(REPLACE "${V13_MENU_CLASS_ANCHOR}" "${V13_MENU_CLASS_INSERT}" V13_WINUTIL "${V13_WINUTIL}")

# Register the native menu above the map/quick-action layers.
set(V13_REGISTER_OLD [=[    auto mini_map_overlay = std::make_shared<AndroidMapMiniDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 95, "android-live-minimap", mini_map_overlay);

    auto map_overlay = std::make_shared<AndroidMapOverlayDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 100, "android-map-overlay", map_overlay);
    registered = true;]=])
set(V13_REGISTER_NEW [=[    auto mini_map_overlay = std::make_shared<AndroidMapMiniDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 95, "android-live-minimap", mini_map_overlay);

    auto map_overlay = std::make_shared<AndroidMapOverlayDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 100, "android-map-overlay", map_overlay);

    auto android_menu = std::make_shared<AndroidLegacyMenuDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 110, "android-native-menu", android_menu);
    registered = true;]=])
string(FIND "${V13_WINUTIL}" "${V13_REGISTER_OLD}" V13_REGISTER_POS)
if(V13_REGISTER_POS EQUAL -1)
    message(FATAL_ERROR "v13: expected v12 drawable registration tail not found")
endif()
string(REPLACE "${V13_REGISTER_OLD}" "${V13_REGISTER_NEW}" V13_WINUTIL "${V13_WINUTIL}")

# Physical touches currently arrive as mouse events on the tested phones. Catch
# the Android menu before ACT/D-pad/panel routing so the overlay is truly modal.
set(V13_MOUSE_PRESS_OLD [=[                    android_map_suppress_mouse_release = true;
                    event.type = sf::Event::Count;
                    break;
                }
                sf::Keyboard::Key primary = sf::Keyboard::Unknown;]=])
set(V13_MOUSE_PRESS_NEW [=[                    android_map_suppress_mouse_release = true;
                    event.type = sf::Event::Count;
                    break;
                }
                if(&win == &mainPtr() && event.mouseButton.button == sf::Mouse::Left &&
                   android_legacy_menu_capture_press(x, y)) {
                    event.type = sf::Event::Count;
                    break;
                }
                sf::Keyboard::Key primary = sf::Keyboard::Unknown;]=])
string(FIND "${V13_WINUTIL}" "${V13_MOUSE_PRESS_OLD}" V13_MOUSE_PRESS_POS)
if(V13_MOUSE_PRESS_POS EQUAL -1)
    message(FATAL_ERROR "v13: expected v12 mouse-press map prefix not found")
endif()
string(REPLACE "${V13_MOUSE_PRESS_OLD}" "${V13_MOUSE_PRESS_NEW}" V13_WINUTIL "${V13_WINUTIL}")

set(V13_MOUSE_RELEASE_OLD [=[                if(&win == &mainPtr() && (android_map_overlay_visible || android_map_suppress_mouse_release)) {
                    android_map_suppress_mouse_release = false;
                    event.type = sf::Event::Count;
                    break;
                }
                if(&win == &mainPtr() && android_dpad_hold_active) {]=])
set(V13_MOUSE_RELEASE_NEW [=[                if(&win == &mainPtr() && (android_map_overlay_visible || android_map_suppress_mouse_release)) {
                    android_map_suppress_mouse_release = false;
                    event.type = sf::Event::Count;
                    break;
                }
                if(&win == &mainPtr() && event.mouseButton.button == sf::Mouse::Left &&
                   (android_legacy_menu_open || android_legacy_menu_pressed != ANDROID_MENU_NONE)) {
                    android_legacy_menu_capture_release(x, y);
                    event.type = sf::Event::Count;
                    break;
                }
                if(&win == &mainPtr() && android_dpad_hold_active) {]=])
string(FIND "${V13_WINUTIL}" "${V13_MOUSE_RELEASE_OLD}" V13_MOUSE_RELEASE_POS)
if(V13_MOUSE_RELEASE_POS EQUAL -1)
    message(FATAL_ERROR "v13: expected v12 mouse-release prefix not found")
endif()
string(REPLACE "${V13_MOUSE_RELEASE_OLD}" "${V13_MOUSE_RELEASE_NEW}" V13_WINUTIL "${V13_WINUTIL}")

# Android Back: submenu -> root, root -> close. Preserve v12 map-back behavior.
set(V13_BACK_OLD [=[            case sf::Event::KeyPressed:
                if(&win == &mainPtr() && android_map_overlay_visible && event.key.code == sf::Keyboard::Escape) {
                    android_map_overlay_visible = false;
                    android_map_suppress_back_release = true;
                    event.type = sf::Event::Count;
                }
                break;]=])
set(V13_BACK_NEW [=[            case sf::Event::KeyPressed:
                if(&win == &mainPtr() && android_map_overlay_visible && event.key.code == sf::Keyboard::Escape) {
                    android_map_overlay_visible = false;
                    android_map_suppress_back_release = true;
                    event.type = sf::Event::Count;
                } else if(&win == &mainPtr() && android_legacy_menu_open && event.key.code == sf::Keyboard::Escape) {
                    if(android_legacy_menu_page == ANDROID_MENU_ROOT)
                        android_legacy_menu_close();
                    else
                        android_legacy_menu_page = ANDROID_MENU_ROOT;
                    android_map_suppress_back_release = true;
                    event.type = sf::Event::Count;
                }
                break;]=])
string(FIND "${V13_WINUTIL}" "${V13_BACK_OLD}" V13_BACK_POS)
if(V13_BACK_POS EQUAL -1)
    message(FATAL_ERROR "v13: expected v12 Android Back block not found")
endif()
string(REPLACE "${V13_BACK_OLD}" "${V13_BACK_NEW}" V13_WINUTIL "${V13_WINUTIL}")

file(WRITE "${CBOE_ANDROID_V13_WINUTIL_CPP}" "${V13_WINUTIL}")
message(STATUS "Applied Android mobile UI v13 native menu, larger controls, and map close polish")