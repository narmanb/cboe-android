# Android responsive-layout follow-up after physical 16:9 testing.
# - Anchor the movement pad to the same centered reference canvas as gameplay.
# - Render centered dialog button labels from their real glyph bounds instead of
#   the legacy approximate CENTRE math, which can displace labels on fitted dialogs.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V26_RESPONSIVE_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V26_RESPONSIVE_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V26_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(V26_WINUTIL_CPP "${CBOE_ANDROID_UI_V26_ROOT}/src/tools/winutil.cpp")
set(V26_BUTTON_CPP "${CBOE_ANDROID_UI_V26_ROOT}/src/dialogxml/widgets/button.cpp")

# ---------------------------------------------------------------------------
# D-pad: v25 scaled its dimensions but v15 still bottom-anchored it to the full
# physical window. On 16:9, the rest of the mobile composition is letterboxed
# inside the centered 2340x1080 reference canvas, leaving the bottom arrow row
# outside that composition. Anchor the pad to the reference canvas too.
# ---------------------------------------------------------------------------
file(READ "${V26_WINUTIL_CPP}" V26_WINUTIL)
set(V26_DPAD_POSITION_OLD [=[    const float grid_size = 3.f * button_size + 2.f * gap;
    float left = static_cast<float>(window_size.x) - right_padding - grid_size;
    float top = static_cast<float>(window_size.y) - vertical_padding - grid_size;]=])
set(V26_DPAD_POSITION_NEW [=[    const float grid_size = 3.f * button_size + 2.f * gap;
    const float content_width = 2340.f * reference_scale;
    const float content_height = 1080.f * reference_scale;
    const float content_left = std::max(0.f,
        (static_cast<float>(window_size.x) - content_width) * 0.5f);
    const float content_top = std::max(0.f,
        (static_cast<float>(window_size.y) - content_height) * 0.5f);
    float left = content_left + content_width - right_padding - grid_size;
    float top = content_top + content_height - vertical_padding - grid_size;]=])
string(FIND "${V26_WINUTIL}" "${V26_DPAD_POSITION_OLD}" V26_DPAD_POSITION_POS)
if(V26_DPAD_POSITION_POS EQUAL -1)
    message(FATAL_ERROR "v26 responsive: final D-pad reference position block not found")
endif()
string(REPLACE "${V26_DPAD_POSITION_OLD}" "${V26_DPAD_POSITION_NEW}" V26_WINUTIL "${V26_WINUTIL}")

set(V26_DPAD_PANEL_OLD [=[    if(panel_rect)
        *panel_rect = sf::FloatRect(left - 10.f, top - 10.f, grid_size + 20.f, grid_size + 20.f);]=])
set(V26_DPAD_PANEL_NEW [=[    if(panel_rect) {
        const float panel_padding = 10.f * reference_scale;
        *panel_rect = sf::FloatRect(left - panel_padding, top - panel_padding,
                                    grid_size + panel_padding * 2.f,
                                    grid_size + panel_padding * 2.f);
    }]=])
string(FIND "${V26_WINUTIL}" "${V26_DPAD_PANEL_OLD}" V26_DPAD_PANEL_POS)
if(V26_DPAD_PANEL_POS EQUAL -1)
    message(FATAL_ERROR "v26 responsive: D-pad panel padding block not found")
endif()
string(REPLACE "${V26_DPAD_PANEL_OLD}" "${V26_DPAD_PANEL_NEW}" V26_WINUTIL "${V26_WINUTIL}")
file(WRITE "${V26_WINUTIL_CPP}" "${V26_WINUTIL}")

# ---------------------------------------------------------------------------
# Dialog buttons: body text now follows the fitted Android dialog View correctly,
# but cButton still uses win_draw_string(CENTRE), whose historical centering uses
# an approximate 4/9 width correction and fixed vertical offsets. That can place
# a label outside a short fitted button, making it appear blank. For Android
# centered buttons only, measure the actual unscaled glyph bounds, center those
# bounds in the logical button rectangle, then use the same scale-aware draw path
# that already works for dialog body text. Desktop behavior is untouched.
# ---------------------------------------------------------------------------
file(READ "${V26_BUTTON_CPP}" V26_BUTTON)

# cButton did not previously need the UI-scale declaration. The Android-only
# centering path below does, and winutil.hpp is where get_ui_scale() is exposed.
set(V26_BUTTON_INCLUDE_OLD [=[#include "gfx/render_image.hpp"
#include "gfx/render_text.hpp"]=])
set(V26_BUTTON_INCLUDE_NEW [=[#include "gfx/render_image.hpp"
#include "gfx/render_text.hpp"
#include "tools/winutil.hpp"]=])
string(FIND "${V26_BUTTON}" "${V26_BUTTON_INCLUDE_OLD}" V26_BUTTON_INCLUDE_POS)
if(V26_BUTTON_INCLUDE_POS EQUAL -1)
    message(FATAL_ERROR "v26 responsive: button render include block not found")
endif()
string(REPLACE "${V26_BUTTON_INCLUDE_OLD}" "${V26_BUTTON_INCLUDE_NEW}" V26_BUTTON "${V26_BUTTON}")

set(V26_BUTTON_LINEHEIGHT_OLD [=[		style.colour = sf::Color::Black;
		style.lineHeight = 8;
		eTextMode textMode = eTextMode::CENTRE;]=])
set(V26_BUTTON_LINEHEIGHT_NEW [=[		style.colour = sf::Color::Black;
#ifdef __ANDROID__
		style.lineHeight = style.pointSize;
#else
		style.lineHeight = 8;
#endif
		eTextMode textMode = eTextMode::CENTRE;]=])
string(FIND "${V26_BUTTON}" "${V26_BUTTON_LINEHEIGHT_OLD}" V26_BUTTON_LINEHEIGHT_POS)
if(V26_BUTTON_LINEHEIGHT_POS EQUAL -1)
    message(FATAL_ERROR "v26 responsive: button text-style anchor not found")
endif()
string(REPLACE "${V26_BUTTON_LINEHEIGHT_OLD}" "${V26_BUTTON_LINEHEIGHT_NEW}" V26_BUTTON "${V26_BUTTON}")

set(V26_BUTTON_DRAW_OLD [=[		for(std::string line : forced_lines){
			win_draw_string(getWindow(),to_rect,line,textMode,style);
			to_rect.offset(0, style.pointSize);
		}]=])
set(V26_BUTTON_DRAW_NEW [=[		for(std::string line : forced_lines){
#ifdef __ANDROID__
			if(textMode == eTextMode::CENTRE) {
				sf::Text logical_text;
				style.applyTo(logical_text);
				logical_text.setString(sf::String::fromUtf8(line.begin(), line.end()));
				const sf::FloatRect glyph_bounds = logical_text.getLocalBounds();

				sf::Text draw_text;
				style.applyTo(draw_text, get_ui_scale());
				draw_text.setString(sf::String::fromUtf8(line.begin(), line.end()));
				const float x = static_cast<float>(to_rect.left) +
					(static_cast<float>(to_rect.width()) - glyph_bounds.width) * 0.5f -
					glyph_bounds.left;
				const float y = static_cast<float>(to_rect.top) +
					(static_cast<float>(to_rect.height()) - glyph_bounds.height) * 0.5f -
					glyph_bounds.top;
				draw_text.setPosition(x, y);
				draw_scale_aware_text(getWindow(), draw_text);
			} else {
				win_draw_string(getWindow(),to_rect,line,textMode,style);
			}
#else
			win_draw_string(getWindow(),to_rect,line,textMode,style);
#endif
			to_rect.offset(0, style.pointSize);
		}]=])
string(FIND "${V26_BUTTON}" "${V26_BUTTON_DRAW_OLD}" V26_BUTTON_DRAW_POS)
if(V26_BUTTON_DRAW_POS EQUAL -1)
    message(FATAL_ERROR "v26 responsive: button label draw loop not found")
endif()
string(REPLACE "${V26_BUTTON_DRAW_OLD}" "${V26_BUTTON_DRAW_NEW}" V26_BUTTON "${V26_BUTTON}")
file(WRITE "${V26_BUTTON_CPP}" "${V26_BUTTON}")

message(STATUS "Applied Android responsive D-pad and dialog button follow-up v26")
