# Android ACT final spacing/readability polish v21.
# - Align the ACT grid to the info-column divider like the minimap.
# - Let the three rows extend a few pixels farther downward.
# - Enlarge the authentic toolbar artwork and mobile labels.
# - Replace the half-height WAIT/USE text cells with original CAMP/HAND artwork.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V21_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V21_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V21_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V21_WINUTIL_CPP "${CBOE_ANDROID_UI_V21_ROOT}/src/tools/winutil.cpp")
file(READ "${CBOE_ANDROID_V21_WINUTIL_CPP}" V21_WINUTIL)

# Put the left button outline almost directly on the same divider used by the
# minimap instead of leaving the previous 10px visual gutter.
set(V21_LEFT_OLD [=[        const float info_right = layout.info_column.left + layout.info_column.width;
        const float desired_left = info_right + 10.f;
        const float desired_right = dpad_panel.left + dpad_panel.width;]=])
set(V21_LEFT_NEW [=[        const float info_right = layout.info_column.left + layout.info_column.width;
        const float desired_left = info_right + 2.f;
        const float desired_right = dpad_panel.left + dpad_panel.width;]=])
string(FIND "${V21_WINUTIL}" "${V21_LEFT_OLD}" V21_LEFT_POS)
if(V21_LEFT_POS EQUAL -1)
    message(FATAL_ERROR "v21: expected v20 ACT left-edge geometry not found")
endif()
string(REPLACE "${V21_LEFT_OLD}" "${V21_LEFT_NEW}" V21_WINUTIL "${V21_WINUTIL}")

# Physical testing showed there is still a little safe room below the grid.
# Add only 3px per row so the bottom grows by roughly 9px without crowding D-pad.
set(V21_HEIGHT_OLD [=[            action_h = std::min(60.f, candidate_h);
            total_h = action_h * 3.f + row_gap * 2.f;]=])
set(V21_HEIGHT_NEW [=[            action_h = std::min(64.f, candidate_h + 3.f);
            total_h = action_h * 3.f + row_gap * 2.f;]=])
string(FIND "${V21_WINUTIL}" "${V21_HEIGHT_OLD}" V21_HEIGHT_POS)
if(V21_HEIGHT_POS EQUAL -1)
    message(FATAL_ERROR "v21: expected v20 ACT row-height calculation not found")
endif()
string(REPLACE "${V21_HEIGHT_OLD}" "${V21_HEIGHT_NEW}" V21_WINUTIL "${V21_WINUTIL}")

set(V21_FALLBACK_HEIGHT_OLD [=[        action_h = std::min(58.f, std::max(42.f, static_cast<float>(window_size.y) * 0.068f));]=])
set(V21_FALLBACK_HEIGHT_NEW [=[        action_h = std::min(62.f, std::max(45.f, static_cast<float>(window_size.y) * 0.072f));]=])
string(FIND "${V21_WINUTIL}" "${V21_FALLBACK_HEIGHT_OLD}" V21_FALLBACK_HEIGHT_POS)
if(V21_FALLBACK_HEIGHT_POS EQUAL -1)
    message(FATAL_ERROR "v21: expected v20 ACT fallback row height not found")
endif()
string(REPLACE "${V21_FALLBACK_HEIGHT_OLD}" "${V21_FALLBACK_HEIGHT_NEW}" V21_WINUTIL "${V21_WINUTIL}")

# WAIT (slot 12) and USE (slot 16) in buttons.png are compact text-style cells.
# Use other authentic OpenBoE toolbar art instead: CAMP conveys wait/rest, and
# HAND conveys use/interact. No new artwork is introduced.
set(V21_ICON_MAP_OLD [=[        case ANDROID_QUICK_TALK: return 8;
        case ANDROID_QUICK_USE: return 16;
        case ANDROID_QUICK_REST_WAIT: return 12;
        case ANDROID_QUICK_GET: return 7;]=])
set(V21_ICON_MAP_NEW [=[        case ANDROID_QUICK_TALK: return 8;
        case ANDROID_QUICK_USE: return 9;
        case ANDROID_QUICK_REST_WAIT: return 3;
        case ANDROID_QUICK_GET: return 7;]=])
string(FIND "${V21_WINUTIL}" "${V21_ICON_MAP_OLD}" V21_ICON_MAP_POS)
if(V21_ICON_MAP_POS EQUAL -1)
    message(FATAL_ERROR "v21: expected v18 WAIT/USE toolbar icon map not found")
endif()
string(REPLACE "${V21_ICON_MAP_OLD}" "${V21_ICON_MAP_NEW}" V21_WINUTIL "${V21_WINUTIL}")

# Make the artwork materially larger. The former 48% row-height target was too
# small on a physical phone, especially next to the full-height button labels.
set(V21_ICON_DRAW_OLD [=[void draw_android_quick_icon(const sf::FloatRect& rect, int action, bool available) {
    if(rect.width < 118.f || rect.height < 34.f)
        return;
    const int slot = android_quick_toolbar_slot(action);
    if(slot < 0)
        return;

    sf::Texture& buttons = *ResMgr::graphics.get("buttons");
    const int col = slot % 6;
    const int row = slot / 6;
    const int source_h = row == 2 ? 16 : 32;
    sf::Sprite sprite(buttons);
    sprite.setTextureRect(sf::IntRect(col * 32, 38 + row * 32, 32, source_h));

    const float target_w = std::min(30.f, rect.height * 0.48f);
    const float scale = target_w / 32.f;
    const float target_h = static_cast<float>(source_h) * scale;
    sprite.setScale(scale, scale);
    sprite.setPosition(rect.left + 9.f, rect.top + (rect.height - target_h) * 0.5f);]=])
set(V21_ICON_DRAW_NEW [=[void draw_android_quick_icon(const sf::FloatRect& rect, int action, bool available) {
    if(rect.width < 82.f || rect.height < 34.f)
        return;
    const int slot = android_quick_toolbar_slot(action);
    if(slot < 0)
        return;

    sf::Texture& buttons = *ResMgr::graphics.get("buttons");
    const int col = slot % 6;
    const int row = slot / 6;
    const int source_h = row == 2 ? 16 : 32;
    sf::Sprite sprite(buttons);
    sprite.setTextureRect(sf::IntRect(col * 32, 38 + row * 32, 32, source_h));

    const float target_w = std::min(38.f, rect.height * 0.72f);
    const float scale = target_w / 32.f;
    const float target_h = static_cast<float>(source_h) * scale;
    sprite.setScale(scale, scale);
    sprite.setPosition(rect.left + 7.f, rect.top + (rect.height - target_h) * 0.5f);]=])
string(FIND "${V21_WINUTIL}" "${V21_ICON_DRAW_OLD}" V21_ICON_DRAW_POS)
if(V21_ICON_DRAW_POS EQUAL -1)
    message(FATAL_ERROR "v21: expected v18 ACT icon renderer not found")
endif()
string(REPLACE "${V21_ICON_DRAW_OLD}" "${V21_ICON_DRAW_NEW}" V21_WINUTIL "${V21_WINUTIL}")

# The labels remain useful even with recognizable icons. Increase them two
# points and reserve enough left-side space for the now-larger icon.
set(V21_LABEL_OLD [=[    draw_android_quick_icon(rect, action, available);

    TextStyle style;
    style.font = FONT_BOLD;
    style.pointSize = 12;
    style.lineHeight = 14;
    style.colour = available ? sf::Color::White : sf::Color(130, 130, 136, 255);

    const float icon_lane = std::min(46.f, std::max(35.f, rect.height * 0.78f));]=])
set(V21_LABEL_NEW [=[    draw_android_quick_icon(rect, action, available);

    TextStyle style;
    style.font = FONT_BOLD;
    style.pointSize = 14;
    style.lineHeight = 16;
    style.colour = available ? sf::Color::White : sf::Color(130, 130, 136, 255);

    const float icon_lane = std::min(46.f, std::max(40.f, rect.height * 0.82f));]=])
string(FIND "${V21_WINUTIL}" "${V21_LABEL_OLD}" V21_LABEL_POS)
if(V21_LABEL_POS EQUAL -1)
    message(FATAL_ERROR "v21: expected v20 ACT label styling not found")
endif()
string(REPLACE "${V21_LABEL_OLD}" "${V21_LABEL_NEW}" V21_WINUTIL "${V21_WINUTIL}")

file(WRITE "${CBOE_ANDROID_V21_WINUTIL_CPP}" "${V21_WINUTIL}")
message(STATUS "Applied Android mobile UI v21 ACT alignment and icon readability")
