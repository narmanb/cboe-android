# Android physical-device responsive follow-up after v26.
# - Keep touch controls sized from display height so 16:9 devices do not shrink them merely because they are narrower.
# - Reset the main RenderWindow view before redrawing beneath Android dialogs to avoid one-frame stale-view corruption.
# - Draw centered Android button labels directly in the active dialog view and remove the desktop BTN_PUSH caption offset.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V27_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V27_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V27_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V27_WINUTIL_CPP "${CBOE_ANDROID_UI_V27_ROOT}/src/tools/winutil.cpp")
set(CBOE_ANDROID_V27_DIALOG_CPP "${CBOE_ANDROID_UI_V27_ROOT}/src/dialogxml/dialogs/dialog.cpp")
set(CBOE_ANDROID_V27_BUTTON_CPP "${CBOE_ANDROID_UI_V27_ROOT}/src/dialogxml/widgets/button.cpp")

# ---------------------------------------------------------------------------
# winutil.cpp: the responsive content canvas should compact to narrower screens,
# but the finger-sized D-pad should follow display height instead of width.
# A 1920x1080 Retroid therefore keeps the same 114px reference button size as
# the 2340x1080 phone while still using the v26 responsive anchoring.
# ---------------------------------------------------------------------------
file(READ "${CBOE_ANDROID_V27_WINUTIL_CPP}" V27_WINUTIL)
set(V27_DPAD_OLD [=[    const float reference_scale = android_reference_scale();
    const float gap = 10.f * reference_scale;
    const float right_padding = 128.f * reference_scale;
    const float vertical_padding = 18.f * reference_scale;

    float button_size = 114.f * reference_scale;
    button_size = std::max(42.f, std::min(114.f, button_size));]=])
set(V27_DPAD_NEW [=[    const float reference_scale = android_reference_scale();
    float control_scale = static_cast<float>(window_size.y) / 1080.f;
    control_scale = std::max(0.65f, std::min(1.f, control_scale));
    const float gap = 10.f * control_scale;
    const float right_padding = 128.f * control_scale;
    const float vertical_padding = 18.f * control_scale;

    float button_size = 114.f * control_scale;
    button_size = std::max(42.f, std::min(114.f, button_size));]=])
string(FIND "${V27_WINUTIL}" "${V27_DPAD_OLD}" V27_DPAD_POS)
if(V27_DPAD_POS EQUAL -1)
    message(FATAL_ERROR "v27: expected v25 responsive D-pad sizing block not found")
endif()
string(REPLACE "${V27_DPAD_OLD}" "${V27_DPAD_NEW}" V27_WINUTIL "${V27_WINUTIL}")
file(WRITE "${CBOE_ANDROID_V27_WINUTIL_CPP}" "${V27_WINUTIL}")

# ---------------------------------------------------------------------------
# dialog.cpp: cDialog::draw() may enter with mainPtr() still using the previous
# dialog viewport. redraw_everything() must always run in the normal game view;
# otherwise a newly opened dialog can expose one frame of zoomed/cropped base UI.
# ---------------------------------------------------------------------------
file(READ "${CBOE_ANDROID_V27_DIALOG_CPP}" V27_DIALOG)
set(V27_DIALOG_EXTERN_OLD [=[#ifdef __ANDROID__
extern bool android_suppress_main_present;]=])
set(V27_DIALOG_EXTERN_NEW [=[#ifdef __ANDROID__
extern bool android_suppress_main_present;
extern sf::View mainView;]=])
string(FIND "${V27_DIALOG}" "${V27_DIALOG_EXTERN_OLD}" V27_DIALOG_EXTERN_POS)
if(V27_DIALOG_EXTERN_POS EQUAL -1)
    message(FATAL_ERROR "v27: expected Android dialog helper declarations not found")
endif()
string(REPLACE "${V27_DIALOG_EXTERN_OLD}" "${V27_DIALOG_EXTERN_NEW}" V27_DIALOG "${V27_DIALOG}")

set(V27_DIALOG_DRAW_START_OLD [=[#ifdef __ANDROID__
	sf::RenderWindow& target = mainPtr();

	// Draw the normal game/title screen and every parent dialog into one back
	// buffer, then present only after the frontmost dialog has been composited.
	android_suppress_main_present = true;]=])
set(V27_DIALOG_DRAW_START_NEW [=[#ifdef __ANDROID__
	sf::RenderWindow& target = mainPtr();

	// Always redraw the underlying game/title in its normal view. A previous
	// dialog may have left mainPtr() using a fitted modal viewport.
	target.setView(mainView);

	// Draw the normal game/title screen and every parent dialog into one back
	// buffer, then present only after the frontmost dialog has been composited.
	android_suppress_main_present = true;]=])
string(FIND "${V27_DIALOG}" "${V27_DIALOG_DRAW_START_OLD}" V27_DIALOG_DRAW_START_POS)
if(V27_DIALOG_DRAW_START_POS EQUAL -1)
    message(FATAL_ERROR "v27: expected Android dialog draw start not found")
endif()
string(REPLACE "${V27_DIALOG_DRAW_START_OLD}" "${V27_DIALOG_DRAW_START_NEW}" V27_DIALOG "${V27_DIALOG}")

set(V27_DIALOG_DRAW_END_OLD [=[	target.setActive(true);
	target.display();
#else]=])
set(V27_DIALOG_DRAW_END_NEW [=[	target.setActive(true);
	target.display();
	// Do not leak a dialog-local view into the next game/title redraw.
	target.setView(mainView);
#else]=])
string(FIND "${V27_DIALOG}" "${V27_DIALOG_DRAW_END_OLD}" V27_DIALOG_DRAW_END_POS)
if(V27_DIALOG_DRAW_END_POS EQUAL -1)
    message(FATAL_ERROR "v27: expected Android dialog draw end not found")
endif()
string(REPLACE "${V27_DIALOG_DRAW_END_OLD}" "${V27_DIALOG_DRAW_END_NEW}" V27_DIALOG "${V27_DIALOG}")
file(WRITE "${CBOE_ANDROID_V27_DIALOG_CPP}" "${V27_DIALOG}")

# ---------------------------------------------------------------------------
# button.cpp: BTN_PUSH has a desktop convention that places its caption 42
# logical pixels beneath the icon. Android renders these controls inline in a
# fitted modal, so that offset can move the label outside the visible button.
# Keep it on desktop only.
# ---------------------------------------------------------------------------
file(READ "${CBOE_ANDROID_V27_BUTTON_CPP}" V27_BUTTON)
set(V27_PUSH_OLD [=[		} else if(type == BTN_PUSH) {
			to_rect.top += 42;
			style.colour = textClr;
			int w = string_length(getText(), style);
			to_rect.inset((w - 30) / -2,0);
		}]=])
set(V27_PUSH_NEW [=[		} else if(type == BTN_PUSH) {
			style.colour = textClr;
#ifndef __ANDROID__
			to_rect.top += 42;
			int w = string_length(getText(), style);
			to_rect.inset((w - 30) / -2,0);
#endif
		}]=])
string(FIND "${V27_BUTTON}" "${V27_PUSH_OLD}" V27_PUSH_POS)
if(V27_PUSH_POS EQUAL -1)
    message(FATAL_ERROR "v27: expected BTN_PUSH caption-offset block not found")
endif()
string(REPLACE "${V27_PUSH_OLD}" "${V27_PUSH_NEW}" V27_BUTTON "${V27_BUTTON}")

# Center Android labels in the active dialog's own logical view. This makes the
# label and button artwork undergo the identical modal fit transform, instead of
# converting the label through the default physical RenderWindow view again.
set(V27_BUTTON_OLD [=[#ifdef __ANDROID__
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
#endif]=])
set(V27_BUTTON_NEW [=[#ifdef __ANDROID__
			if(textMode == eTextMode::CENTRE) {
				sf::Text draw_text;
				style.applyTo(draw_text);
				draw_text.setString(sf::String::fromUtf8(line.begin(), line.end()));
				const sf::FloatRect glyph_bounds = draw_text.getLocalBounds();
				const float x = static_cast<float>(to_rect.left) +
					(static_cast<float>(to_rect.width()) - glyph_bounds.width) * 0.5f -
					glyph_bounds.left;
				const float y = static_cast<float>(to_rect.top) +
					(static_cast<float>(to_rect.height()) - glyph_bounds.height) * 0.5f -
					glyph_bounds.top;
				draw_text.setPosition(x, y);
				getWindow().draw(draw_text);
			} else {
				win_draw_string(getWindow(),to_rect,line,textMode,style);
			}
#else
			win_draw_string(getWindow(),to_rect,line,textMode,style);
#endif]=])
string(FIND "${V27_BUTTON}" "${V27_BUTTON_OLD}" V27_BUTTON_POS)
if(V27_BUTTON_POS EQUAL -1)
    message(FATAL_ERROR "v27: expected v26 centered Android button path not found")
endif()
string(REPLACE "${V27_BUTTON_OLD}" "${V27_BUTTON_NEW}" V27_BUTTON "${V27_BUTTON}")
file(WRITE "${CBOE_ANDROID_V27_BUTTON_CPP}" "${V27_BUTTON}")

message(STATUS "Applied Android physical-device responsive follow-up v27")
