# Android physical-test fixes after v5 panel controls.
# - Use the real desktop Party Stats help resource (help-party).
# - Draw quick-action labels directly in physical screen coordinates. The
#   normal win_draw_string path does not visibly render in this Android overlay.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V6_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V6_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V6_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_WINUTIL_V6_CPP "${CBOE_ANDROID_UI_V6_ROOT}/src/tools/winutil.cpp")
file(READ "${CBOE_ANDROID_WINUTIL_V6_CPP}" CBOE_ANDROID_WINUTIL_V6_SOURCE)

# v5 accidentally invented a dialog resource name. The legacy Party Stats help
# button in boe.actions.cpp dispatches help-party; use that same engine resource.
set(CBOE_ANDROID_V6_STATS_HELP_OLD [=[show_dialog_action("help-stats");]=])
set(CBOE_ANDROID_V6_STATS_HELP_NEW [=[show_dialog_action("help-party");]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V6_SOURCE}" "${CBOE_ANDROID_V6_STATS_HELP_OLD}" CBOE_ANDROID_V6_STATS_HELP_POS)
if(CBOE_ANDROID_V6_STATS_HELP_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android v5 stats-help dispatch was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V6_STATS_HELP_OLD}" "${CBOE_ANDROID_V6_STATS_HELP_NEW}" CBOE_ANDROID_WINUTIL_V6_SOURCE "${CBOE_ANDROID_WINUTIL_V6_SOURCE}")

# All quick-action boxes render on the physical device, but their text does not.
# The overlay is drawn in the window's default (physical-pixel) view while
# win_draw_string is part of OpenBoE's legacy/scaled text path. Use a tiny
# built-in 5x7 uppercase font made of SFML rectangles instead, so labels share
# exactly the same coordinate space as the boxes and require no font resources.
set(CBOE_ANDROID_V6_QUICK_ANCHOR [=[void draw_android_quick_button(const sf::FloatRect& rect, const std::string& label,
                               bool available, bool pressed) {]=])
set(CBOE_ANDROID_V6_QUICK_INSERT [=[std::array<unsigned char, 7> android_quick_glyph(char c) {
    switch(c) {
        case 'A': return {{14,17,17,31,17,17,17}};
        case 'C': return {{14,17,16,16,16,17,14}};
        case 'D': return {{30,17,17,17,17,17,30}};
        case 'E': return {{31,16,16,30,16,16,31}};
        case 'G': return {{14,17,16,23,17,17,15}};
        case 'I': return {{31,4,4,4,4,4,31}};
        case 'K': return {{17,18,20,24,20,18,17}};
        case 'L': return {{16,16,16,16,16,16,31}};
        case 'M': return {{17,27,21,21,17,17,17}};
        case 'O': return {{14,17,17,17,17,17,14}};
        case 'P': return {{30,17,17,30,16,16,16}};
        case 'R': return {{30,17,17,30,20,18,17}};
        case 'S': return {{15,16,16,14,1,1,30}};
        case 'T': return {{31,4,4,4,4,4,4}};
        case 'U': return {{17,17,17,17,17,17,14}};
        case 'V': return {{17,17,17,17,17,10,4}};
        case 'W': return {{17,17,17,21,21,21,10}};
        default:  return {{0,0,0,0,0,0,0}};
    }
}

void draw_android_quick_label(const sf::FloatRect& rect, const std::string& label,
                              const sf::Color& colour) {
    if(label.empty())
        return;

    const float pixel = 2.5f;
    const float glyph_w = 5.f * pixel;
    const float glyph_h = 7.f * pixel;
    const float spacing = pixel;
    const float text_w = static_cast<float>(label.size()) * glyph_w +
                         static_cast<float>(label.size() - 1) * spacing;
    const float start_x = rect.left + (rect.width - text_w) * 0.5f;
    const float start_y = rect.top + (rect.height - glyph_h) * 0.5f;

    sf::RectangleShape dot({pixel, pixel});
    dot.setFillColor(colour);
    for(std::size_t i = 0; i < label.size(); ++i) {
        const std::array<unsigned char, 7> rows = android_quick_glyph(label[i]);
        const float glyph_x = start_x + static_cast<float>(i) * (glyph_w + spacing);
        for(int row = 0; row < 7; ++row) {
            for(int col = 0; col < 5; ++col) {
                if((rows[row] & (1u << (4 - col))) == 0)
                    continue;
                dot.setPosition(glyph_x + static_cast<float>(col) * pixel,
                                start_y + static_cast<float>(row) * pixel);
                mainPtr().draw(dot);
            }
        }
    }
}

void draw_android_quick_button(const sf::FloatRect& rect, const std::string& label,
                               bool available, bool pressed) {]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V6_SOURCE}" "${CBOE_ANDROID_V6_QUICK_ANCHOR}" CBOE_ANDROID_V6_QUICK_ANCHOR_POS)
if(CBOE_ANDROID_V6_QUICK_ANCHOR_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android v4 quick-button function was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V6_QUICK_ANCHOR}" "${CBOE_ANDROID_V6_QUICK_INSERT}" CBOE_ANDROID_WINUTIL_V6_SOURCE "${CBOE_ANDROID_WINUTIL_V6_SOURCE}")

set(CBOE_ANDROID_V6_LABEL_OLD [=[    TextStyle style;
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
    win_draw_string(mainPtr(), label_rect, label, eTextMode::CENTRE, style);]=])
set(CBOE_ANDROID_V6_LABEL_NEW [=[    draw_android_quick_label(rect, label,
                             available ? sf::Color::White : sf::Color(130, 130, 136, 255));]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V6_SOURCE}" "${CBOE_ANDROID_V6_LABEL_OLD}" CBOE_ANDROID_V6_LABEL_POS)
if(CBOE_ANDROID_V6_LABEL_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android quick-button legacy text block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V6_LABEL_OLD}" "${CBOE_ANDROID_V6_LABEL_NEW}" CBOE_ANDROID_WINUTIL_V6_SOURCE "${CBOE_ANDROID_WINUTIL_V6_SOURCE}")

file(WRITE "${CBOE_ANDROID_WINUTIL_V6_CPP}" "${CBOE_ANDROID_WINUTIL_V6_SOURCE}")
message(STATUS "Applied Android mobile UI v6 stats-help and physical quick-label fixes")
