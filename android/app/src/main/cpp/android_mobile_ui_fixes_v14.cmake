# Android-native preferences after v13.
# - Replace the desktop Preferences dialog from the Android MENU path.
# - Keep only settings that are meaningful on mobile.
# - Leave targeting preferences untouched until combat/targeting gets a mobile pass.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V14_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V14_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V14_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V14_DLGUTIL_CPP "${CBOE_ANDROID_UI_V14_ROOT}/src/game/boe.dlgutil.cpp")
set(CBOE_ANDROID_V14_WINUTIL_CPP "${CBOE_ANDROID_UI_V14_ROOT}/src/tools/winutil.cpp")

# ---------------------------------------------------------------------------
# boe.dlgutil.cpp: small preference bridge using the existing game semantics.
# Keep all preference ownership here so winutil.cpp does not need universe or
# desktop-dialog dependencies merely to draw the Android settings page.
# ---------------------------------------------------------------------------
file(READ "${CBOE_ANDROID_V14_DLGUTIL_CPP}" V14_DLGUTIL)

set(V14_PREF_BRIDGE_ANCHOR [=[void autosave_preferences(cDialog* parent);]=])
set(V14_PREF_BRIDGE_INSERT [=[#ifdef __ANDROID__
int android_pref_game_speed() {
    int speed = get_int_pref("GameSpeed", 0);
    if(speed < 0 || speed > 3)
        speed = 0;
    return speed;
}

bool android_pref_sound_enabled() {
    return get_bool_pref("PlaySounds", true);
}

bool android_pref_autosave_enabled() {
    return get_bool_pref("Autosave", true);
}

bool android_pref_easy_mode_enabled() {
    if(overall_mode == MODE_STARTUP && !party_in_memory)
        return get_bool_pref("EasyMode", false);
    return univ.party.easy_mode;
}

bool android_pref_less_wandering_enabled() {
    if(overall_mode == MODE_STARTUP && !party_in_memory)
        return get_bool_pref("LessWanderingMonsters", false);
    return univ.party.less_wm;
}

bool android_pref_splash_enabled() {
    return get_bool_pref("ShowStartupSplash", true);
}

bool android_pref_instant_help_enabled() {
    return get_bool_pref("ShowInstantHelp", true);
}

void android_prepare_mobile_preferences() {
    // Android relies on OpenBoE's in-game picker. The desktop preference for
    // switching back to an OS file picker is intentionally not exposed here.
    if(!get_bool_pref("FancyFilePicker", true)) {
        set_pref("FancyFilePicker", true);
        save_prefs();
    }
}

void android_apply_mobile_preference(int index) {
    switch(index) {
        case 0:
            set_pref("GameSpeed", (android_pref_game_speed() + 1) % 4);
            break;
        case 1:
            set_pref("PlaySounds", !android_pref_sound_enabled());
            break;
        case 2:
            set_pref("Autosave", !android_pref_autosave_enabled());
            break;
        case 3:
            if(overall_mode == MODE_STARTUP && !party_in_memory)
                set_pref("EasyMode", !android_pref_easy_mode_enabled());
            else
                univ.party.easy_mode = !univ.party.easy_mode;
            break;
        case 4:
            if(overall_mode == MODE_STARTUP && !party_in_memory)
                set_pref("LessWanderingMonsters", !android_pref_less_wandering_enabled());
            else
                univ.party.less_wm = !univ.party.less_wm;
            break;
        case 5:
            set_pref("ShowStartupSplash", !android_pref_splash_enabled());
            break;
        case 6:
            set_pref("ShowInstantHelp", !android_pref_instant_help_enabled());
            break;
        case 7:
            clear_pref("ReceivedHelp");
            break;
        default:
            return;
    }
    save_prefs();
}
#endif

void autosave_preferences(cDialog* parent);]=])
string(FIND "${V14_DLGUTIL}" "${V14_PREF_BRIDGE_ANCHOR}" V14_PREF_BRIDGE_POS)
if(V14_PREF_BRIDGE_POS EQUAL -1)
    message(FATAL_ERROR "v14: expected autosave preference declaration anchor not found")
endif()
string(REPLACE "${V14_PREF_BRIDGE_ANCHOR}" "${V14_PREF_BRIDGE_INSERT}" V14_DLGUTIL "${V14_DLGUTIL}")
file(WRITE "${CBOE_ANDROID_V14_DLGUTIL_CPP}" "${V14_DLGUTIL}")

# ---------------------------------------------------------------------------
# winutil.cpp: add a native Preferences page to the existing v13 MENU overlay.
# ---------------------------------------------------------------------------
file(READ "${CBOE_ANDROID_V14_WINUTIL_CPP}" V14_WINUTIL)

# Minimal cross-TU declarations for the preference bridge above.
set(V14_PREF_DECL_OLD [=[void android_refresh_map_cache();]=])
set(V14_PREF_DECL_NEW [=[void android_refresh_map_cache();
int android_pref_game_speed();
bool android_pref_sound_enabled();
bool android_pref_autosave_enabled();
bool android_pref_easy_mode_enabled();
bool android_pref_less_wandering_enabled();
bool android_pref_splash_enabled();
bool android_pref_instant_help_enabled();
void android_prepare_mobile_preferences();
void android_apply_mobile_preference(int index);]=])
string(FIND "${V14_WINUTIL}" "${V14_PREF_DECL_OLD}" V14_PREF_DECL_POS)
if(V14_PREF_DECL_POS EQUAL -1)
    message(FATAL_ERROR "v14: expected Android map declaration anchor not found")
endif()
string(REPLACE "${V14_PREF_DECL_OLD}" "${V14_PREF_DECL_NEW}" V14_WINUTIL "${V14_WINUTIL}")

# Add a real native preference page rather than dispatching eMenu::PREFS to the
# legacy XML dialog.
set(V14_PREF_ENUM_OLD [=[    ANDROID_MENU_LIBRARY,
    ANDROID_MENU_HELP
};]=])
set(V14_PREF_ENUM_NEW [=[    ANDROID_MENU_LIBRARY,
    ANDROID_MENU_HELP,
    ANDROID_MENU_PREFS
};]=])
string(FIND "${V14_WINUTIL}" "${V14_PREF_ENUM_OLD}" V14_PREF_ENUM_POS)
if(V14_PREF_ENUM_POS EQUAL -1)
    message(FATAL_ERROR "v14: expected v13 menu-page enum tail not found")
endif()
string(REPLACE "${V14_PREF_ENUM_OLD}" "${V14_PREF_ENUM_NEW}" V14_WINUTIL "${V14_WINUTIL}")

# Build touch-sized labels from live preference values. Eight items fit the
# established two-column Android menu grid without scrolling.
set(V14_PREF_ITEMS_OLD [=[        case ANDROID_MENU_HELP:
            return {{"INDEX", eMenu::HELP_TOC}, {"ABOUT", eMenu::ABOUT},
                    {"OUTDOOR", eMenu::HELP_OUT}, {"TOWN", eMenu::HELP_TOWN},
                    {"COMBAT", eMenu::HELP_COMBAT}, {"BARRIER", eMenu::HELP_BARRIER},
                    {"HINTS", eMenu::HELP_HINTS}, {"SPELL HELP", eMenu::HELP_SPELLS}};
        default:
            return {};]=])
set(V14_PREF_ITEMS_NEW [=[        case ANDROID_MENU_HELP:
            return {{"INDEX", eMenu::HELP_TOC}, {"ABOUT", eMenu::ABOUT},
                    {"OUTDOOR", eMenu::HELP_OUT}, {"TOWN", eMenu::HELP_TOWN},
                    {"COMBAT", eMenu::HELP_COMBAT}, {"BARRIER", eMenu::HELP_BARRIER},
                    {"HINTS", eMenu::HELP_HINTS}, {"SPELL HELP", eMenu::HELP_SPELLS}};
        case ANDROID_MENU_PREFS: {
            static const char* speed_names[4] = {"FAST", "MEDIUM", "SLOW", "VERY SLOW"};
            const int speed = android_pref_game_speed();
            return {
                {std::string("GAME SPEED ") + speed_names[speed], eMenu::NONE},
                {std::string("SOUND ") + (android_pref_sound_enabled() ? "ON" : "OFF"), eMenu::NONE},
                {std::string("AUTOSAVE ") + (android_pref_autosave_enabled() ? "ON" : "OFF"), eMenu::NONE},
                {std::string("EASY MODE ") + (android_pref_easy_mode_enabled() ? "ON" : "OFF"), eMenu::NONE},
                {std::string("FEWER MONSTERS ") + (android_pref_less_wandering_enabled() ? "ON" : "OFF"), eMenu::NONE},
                {std::string("SPLASH SCREEN ") + (android_pref_splash_enabled() ? "ON" : "OFF"), eMenu::NONE},
                {std::string("INSTANT HELP ") + (android_pref_instant_help_enabled() ? "ON" : "OFF"), eMenu::NONE},
                {"RESET HELP TIPS", eMenu::NONE}
            };
        }
        default:
            return {};]=])
string(FIND "${V14_WINUTIL}" "${V14_PREF_ITEMS_OLD}" V14_PREF_ITEMS_POS)
if(V14_PREF_ITEMS_POS EQUAL -1)
    message(FATAL_ERROR "v14: expected v13 Help menu tail not found")
endif()
string(REPLACE "${V14_PREF_ITEMS_OLD}" "${V14_PREF_ITEMS_NEW}" V14_WINUTIL "${V14_WINUTIL}")

# Preference buttons stay on the page after a tap so multiple settings can be
# changed quickly. Selecting PREFS from File enters this page instead of opening
# the old desktop cDialog.
set(V14_PREF_RELEASE_OLD [=[        const auto items = android_legacy_menu_items();
        if(index >= 0 && index < static_cast<int>(items.size())) {
            const eMenu action = items[index].action;
            android_legacy_menu_close();
            handle_menu_choice(action);
        }
        return true;]=])
set(V14_PREF_RELEASE_NEW [=[        const auto items = android_legacy_menu_items();
        if(index >= 0 && index < static_cast<int>(items.size())) {
            if(android_legacy_menu_page == ANDROID_MENU_PREFS) {
                android_apply_mobile_preference(index);
                return true;
            }
            const eMenu action = items[index].action;
            if(action == eMenu::PREFS) {
                android_prepare_mobile_preferences();
                android_legacy_menu_page = ANDROID_MENU_PREFS;
                return true;
            }
            android_legacy_menu_close();
            handle_menu_choice(action);
        }
        return true;]=])
string(FIND "${V14_WINUTIL}" "${V14_PREF_RELEASE_OLD}" V14_PREF_RELEASE_POS)
if(V14_PREF_RELEASE_POS EQUAL -1)
    message(FATAL_ERROR "v14: expected v13 menu action release block not found")
endif()
string(REPLACE "${V14_PREF_RELEASE_OLD}" "${V14_PREF_RELEASE_NEW}" V14_WINUTIL "${V14_WINUTIL}")

file(WRITE "${CBOE_ANDROID_V14_WINUTIL_CPP}" "${V14_WINUTIL}")
message(STATUS "Applied Android mobile UI v14 native preferences")
