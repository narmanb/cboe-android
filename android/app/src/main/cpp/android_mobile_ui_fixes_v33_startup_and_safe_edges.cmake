# Android physical-device follow-up after v32.
#
# Fix three problems that should be independent of any particular device:
# 1. Startup button captions are centered from real glyph bounds in the logical
#    startup button rectangle instead of using the legacy CENTRE approximation.
# 2. Startup press feedback redraws the complete startup scene on Android rather
#    than using a logical-coordinate clip rectangle against a scaled viewport.
#    The latter can expose a black/cropped fragment while opening a modal.
# 3. D-pad bottom padding includes a proportional safe-edge margin so controls
#    do not sit inside rounded-corner/system-edge regions on different displays.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V33_STARTUP_SAFE_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V33_STARTUP_SAFE_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V33_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(V33_GRAPHICS_CPP "${CBOE_ANDROID_UI_V33_ROOT}/src/game/boe.graphics.cpp")
set(V33_WINUTIL_CPP "${CBOE_ANDROID_UI_V33_ROOT}/src/tools/winutil.cpp")

# ---------------------------------------------------------------------------
# Startup captions: use actual SFML glyph bounds and let mainView perform the
# one uniform startup transform. This avoids the legacy CENTRE offsets that are
# visibly wrong once the title screen is scaled on Android.
# ---------------------------------------------------------------------------
file(READ "${V33_GRAPHICS_CPP}" V33_GRAPHICS)
set(V33_START_LABEL_OLD [=[	style.colour = base_color;
	style.lineHeight = 18;
	win_draw_string(mainPtr(),to_rect,button_labels[which_position],eTextMode::CENTRE,style);
}]=])
set(V33_START_LABEL_NEW [=[	style.colour = base_color;
	style.lineHeight = 18;

	// Android startup artwork and text must share the same logical coordinate
	// system. Measure the caption itself and center that glyph box in the real
	// startup button rectangle; mainView then scales both together exactly once.
	sf::Text draw_text;
	style.applyTo(draw_text);
	const std::string label(button_labels[which_position]);
	draw_text.setString(sf::String::fromUtf8(label.begin(), label.end()));
	const sf::FloatRect glyph = draw_text.getLocalBounds();
	const rectangle& bounds = startup_button[which_position];
	const float x = static_cast<float>(bounds.left) +
		(static_cast<float>(bounds.width()) - glyph.width) * 0.5f - glyph.left;
	const float y = static_cast<float>(bounds.top) +
		(static_cast<float>(bounds.height()) - glyph.height) * 0.5f - glyph.top;
	draw_text.setPosition(x, y);
	mainPtr().draw(draw_text);
}]=])
string(FIND "${V33_GRAPHICS}" "${V33_START_LABEL_OLD}" V33_START_LABEL_POS)
if(V33_START_LABEL_POS EQUAL -1)
    message(FATAL_ERROR "v33 startup: expected startup caption renderer not found")
endif()
string(REPLACE "${V33_START_LABEL_OLD}" "${V33_START_LABEL_NEW}" V33_GRAPHICS "${V33_GRAPHICS}")

# ---------------------------------------------------------------------------
# Startup press redraw: clip_rect() receives logical coordinates while the
# Android startup screen is being shown through a scaled viewport. On physical
# devices that can turn the pressed-button refresh into a large black/cropped
# rectangle. During MODE_STARTUP redraw the whole scene instead; keep clipping
# for arrow buttons used elsewhere.
# ---------------------------------------------------------------------------
set(V33_ARROW_BEGIN_OLD [=[	// Draw depressed:
	mainPtr().setActive();
	clip_rect(mainPtr(), button_rect);
	refresh_stat_areas(1);
	mainPtr().display();]=])
set(V33_ARROW_BEGIN_NEW [=[	// Draw depressed. Startup uses a scaled Android viewport, so its logical
	// button rectangle is not a safe OpenGL clip rectangle. Redraw the complete
	// startup frame there; other modes keep the original clipped fast path.
	mainPtr().setActive();
	const bool android_startup_full_redraw = overall_mode == MODE_STARTUP;
	if(android_startup_full_redraw)
		mainPtr().setView(mainView);
	else
		clip_rect(mainPtr(), button_rect);
	refresh_stat_areas(1);
	mainPtr().display();]=])
string(FIND "${V33_GRAPHICS}" "${V33_ARROW_BEGIN_OLD}" V33_ARROW_BEGIN_POS)
if(V33_ARROW_BEGIN_POS EQUAL -1)
    message(FATAL_ERROR "v33 startup: expected arrow-button initial clip block not found")
endif()
string(REPLACE "${V33_ARROW_BEGIN_OLD}" "${V33_ARROW_BEGIN_NEW}" V33_GRAPHICS "${V33_GRAPHICS}")

set(V33_ARROW_END_OLD [=[	undo_clip(mainPtr());
	play_sound(37, time_in_ticks(5));]=])
set(V33_ARROW_END_NEW [=[	if(!android_startup_full_redraw)
		undo_clip(mainPtr());
	play_sound(37, time_in_ticks(5));]=])
string(FIND "${V33_GRAPHICS}" "${V33_ARROW_END_OLD}" V33_ARROW_END_POS)
if(V33_ARROW_END_POS EQUAL -1)
    message(FATAL_ERROR "v33 startup: expected arrow-button clip cleanup not found")
endif()
string(REPLACE "${V33_ARROW_END_OLD}" "${V33_ARROW_END_NEW}" V33_GRAPHICS "${V33_GRAPHICS}")
file(WRITE "${V33_GRAPHICS_CPP}" "${V33_GRAPHICS}")

# ---------------------------------------------------------------------------
# Physical safe edge for the D-pad. Use a percentage of the shorter display
# axis rather than a device/resolution constant. v32 already scales the pad from
# both axes; this only guarantees that its bottom edge remains visibly inside
# the usable screen on displays with rounded corners or system-edge intrusion.
# ---------------------------------------------------------------------------
file(READ "${V33_WINUTIL_CPP}" V33_WINUTIL)
set(V33_SAFE_OLD [=[    const float gap = 10.f * control_scale;
    const float right_padding = 128.f * control_scale;
    const float vertical_padding = 18.f * control_scale;

    float button_size = 114.f * control_scale;]=])
set(V33_SAFE_NEW [=[    const float gap = 10.f * control_scale;
    const float right_padding = 128.f * control_scale;
    const float short_side = static_cast<float>(std::min(window_size.x, window_size.y));
    const float vertical_padding = std::max(18.f * control_scale, short_side * 0.035f);

    float button_size = 114.f * control_scale;]=])
string(FIND "${V33_WINUTIL}" "${V33_SAFE_OLD}" V33_SAFE_POS)
if(V33_SAFE_POS EQUAL -1)
    message(FATAL_ERROR "v33 safe edge: expected v32 D-pad padding block not found")
endif()
string(REPLACE "${V33_SAFE_OLD}" "${V33_SAFE_NEW}" V33_WINUTIL "${V33_WINUTIL}")
file(WRITE "${V33_WINUTIL_CPP}" "${V33_WINUTIL}")

message(STATUS "Applied Android startup caption/redraw and proportional safe-edge fix v33")
