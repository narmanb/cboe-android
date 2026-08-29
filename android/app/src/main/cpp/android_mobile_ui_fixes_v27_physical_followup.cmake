# Android physical-device responsive follow-up after v26.
# - Keep touch controls sized from display height so 16:9 devices do not shrink them merely because they are narrower.
# - Reset the main RenderWindow view before redrawing beneath Android dialogs to avoid one-frame stale-view corruption.
# - Draw centered Android button labels directly in the active dialog view and undo the legacy BTN_PUSH caption offset.
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
    if(button_size > 114.f) button_size = 114.f;
    if(button_size < 42.f) button_size = 42.f;]=])
set(V27_DPAD_NEW [=[    const float reference_scale = android_reference_scale();
    float control_scale = static_cast<float>(window_size.y) / 1080.f;
    if(control_scale > 1.f) control_scale = 1.f;
    if(control_scale < 0.65f) control_scale = 0.65f;
    const float gap = 10.f * control_scale;
    const float right_padding = 128.f * control_scale;
    const float vertical_padding = 18.f * control_scale;

    float button_size = 114.f * control_scale;
    if(button_size > 114.f) button_size = 114.f;
    if(button_size < 42.f) button_size = 42.f;]=])
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
	android_suppress_main_present = true;]=])
set(V27_DIALOG_DRAW_START_NEW [=[#ifdef __ANDROID__
	sf::RenderWindow& target = mainPtr();
	target.setView(mainView);
	android_suppress_main_present = true;]=])
string(FIND "${V27_DIALOG}" "${V27_DIALOG_DRAW_START_OLD}" V27_DIALOG_DRAW_START_POS)
if(V27_DIALOG_DRAW_START_POS EQUAL -1)
    message(FATAL_ERROR "v27: expected Android dialog draw start not found")
endif()
string(REPLACE "${V27_DIALOG_DRAW_START_OLD}" "${V27_DIALOG_DRAW_START_NEW}" V27_DIALOG "${V27_DIALOG}")

set(V27_DIALOG_DRAW_END_OLD [=[	target.display();
	return;
#else]=])
set(V27_DIALOG_DRAW_END_NEW [=[	target.display();
	target.setView(mainView);
	return;
#else]=])
string(FIND "${V27_DIALOG}" "${V27_DIALOG_DRAW_END_OLD}" V27_DIALOG_DRAW_END_POS)
if(V27_DIALOG_DRAW_END_POS EQUAL -1)
    message(FATAL_ERROR "v27: expected Android dialog draw end not found")
endif()
string(REPLACE "${V27_DIALOG_DRAW_END_OLD}" "${V27_DIALOG_DRAW_END_NEW}" V27_DIALOG "${V27_DIALOG}")
file(WRITE "${CBOE_ANDROID_V27_DIALOG_CPP}" "${V27_DIALOG}")

# ---------------------------------------------------------------------------
# button.cpp: centered button text should share the exact same dialog view as
# the button artwork. The v26 path temporarily converted it to physical/default
# view coordinates, which still diverges on fitted dialogs. Also compensate the
# desktop BTN_PUSH convention that moves its caption 42 logical pixels below the
# icon; on Android these controls are rendered as touch buttons and need their
# captions centered inside the visible button frame.
# ---------------------------------------------------------------------------
file(READ "${CBOE_ANDROID_V27_BUTTON_CPP}" V27_BUTTON)
set(V27_BUTTON_OLD [=[#ifdef __ANDROID__
				if(textMode == eTextMode::CENTRE) {
					sf::Text logical_text;
					style.applyTo(logical_text);
					logical_text.setString(label);
					sf::FloatRect logical_bounds = logical_text.getLocalBounds();
					sf::Vector2f logical_position(
						(static_cast<float>(to_rect.left + to_rect.right) - logical_bounds.width) * 0.5f - logical_bounds.left,
						(static_cast<float>(to_rect.top + to_rect.bottom) - logical_bounds.height) * 0.5f - logical_bounds.top
					);

					sf::Text draw_text;
					style.applyTo(draw_text, static_cast<float>(get_ui_scale()));
					draw_text.setString(label);
					draw_text.setPosition(logical_position);
					draw_scale_aware_text(getWindow(), draw_text);
					return;
				}
#endif]=])
set(V27_BUTTON_NEW [=[#ifdef __ANDROID__
				if(textMode == eTextMode::CENTRE) {
					rectangle android_center_rect = to_rect;
					if(type == BTN_PUSH) {
						android_center_rect.top -= 42;
						android_center_rect.bottom -= 42;
					}

					sf::Text draw_text;
					style.applyTo(draw_text);
					draw_text.setString(label);
					sf::FloatRect logical_bounds = draw_text.getLocalBounds();
					draw_text.setPosition(
						(static_cast<float>(android_center_rect.left + android_center_rect.right) - logical_bounds.width) * 0.5f - logical_bounds.left,
						(static_cast<float>(android_center_rect.top + android_center_rect.bottom) - logical_bounds.height) * 0.5f - logical_bounds.top
					);
					getWindow().draw(draw_text);
					return;
				}
#endif]=])
string(FIND "${V27_BUTTON}" "${V27_BUTTON_OLD}" V27_BUTTON_POS)
if(V27_BUTTON_POS EQUAL -1)
    message(FATAL_ERROR "v27: expected v26 centered Android button path not found")
endif()
string(REPLACE "${V27_BUTTON_OLD}" "${V27_BUTTON_NEW}" V27_BUTTON "${V27_BUTTON}")
file(WRITE "${CBOE_ANDROID_V27_BUTTON_CPP}" "${V27_BUTTON}")

message(STATUS "Applied Android physical-device responsive follow-up v27")
