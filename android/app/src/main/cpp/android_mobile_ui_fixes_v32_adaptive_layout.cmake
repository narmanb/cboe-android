# Android adaptive gameplay layout v32.
#
# This deliberately does NOT special-case any phone, Retroid model, resolution,
# or aspect ratio. The established 2340x1080 phone composition remains the
# visual reference, but component sizes respond continuously to both available
# width and height and the layout reflows across the actual physical window.
#
# Key rule: never solve a narrower display by uniformly letterboxing the entire
# mobile UI, and never solve it by keeping height-sized controls so large that
# the information/ACT region is crushed. Preserve touchability while allowing
# terrain/control sizes to yield smoothly as the aspect ratio gets tighter.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V32_ADAPTIVE_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V32_ADAPTIVE_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V32_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(V32_WINUTIL_CPP "${CBOE_ANDROID_UI_V32_ROOT}/src/tools/winutil.cpp")
file(READ "${V32_WINUTIL_CPP}" V32_WINUTIL)

# v25 used a single uniform reference-canvas scale. That makes a narrower
# landscape display shrink vertically even when it has plenty of height. Use a
# continuous two-axis component scale instead. Height remains the primary touch
# sizing signal; width pressure gently reduces components rather than forcing an
# all-or-nothing 2340x1080 fit.
set(V32_SCALE_OLD [=[float android_reference_scale() {
    const sf::Vector2u size = mainPtr().getSize();
    if(size.x == 0 || size.y == 0)
        return 1.f;
    const float width_scale = static_cast<float>(size.x) / 2340.f;
    const float height_scale = static_cast<float>(size.y) / 1080.f;
    return std::max(0.35f, std::min(1.25f, std::min(width_scale, height_scale)));
}]=])
set(V32_SCALE_NEW [=[float android_reference_scale() {
    const sf::Vector2u size = mainPtr().getSize();
    if(size.x == 0 || size.y == 0)
        return 1.f;

    const float width_scale = static_cast<float>(size.x) / 2340.f;
    const float height_scale = static_cast<float>(size.y) / 1080.f;
    const float width_pressure = height_scale > 0.f
        ? std::max(0.55f, std::min(1.f, width_scale / height_scale))
        : 1.f;

    // Keep the canonical wide-phone result unchanged (1.0 at 2340x1080), but
    // only partially follow width pressure on tighter aspect ratios. Layout
    // reflow below handles the rest instead of shrinking the whole interface.
    const float shape_factor = 0.55f + 0.45f * width_pressure;
    return std::max(0.45f, std::min(1.25f, height_scale * shape_factor));
}]=])
string(FIND "${V32_WINUTIL}" "${V32_SCALE_OLD}" V32_SCALE_POS)
if(V32_SCALE_POS EQUAL -1)
    message(FATAL_ERROR "v32 adaptive: expected v25 reference-scale helper not found")
endif()
string(REPLACE "${V32_SCALE_OLD}" "${V32_SCALE_NEW}" V32_WINUTIL "${V32_WINUTIL}")

# v27 made D-pad size depend on height alone. Replace that with the same adaptive
# component scale used by the rest of the right-side controls so no aspect ratio
# can get a full-height D-pad while ACT/minimap are simultaneously compressed.
set(V32_DPAD_SIZE_OLD [=[    const float reference_scale = android_reference_scale();
    float control_scale = static_cast<float>(window_size.y) / 1080.f;
    control_scale = std::max(0.65f, std::min(1.f, control_scale));
    const float gap = 10.f * control_scale;
    const float right_padding = 128.f * control_scale;
    const float vertical_padding = 18.f * control_scale;

    float button_size = 114.f * control_scale;
    button_size = std::max(42.f, std::min(114.f, button_size));]=])
set(V32_DPAD_SIZE_NEW [=[    const float reference_scale = android_reference_scale();
    const float control_scale = std::max(0.55f, std::min(1.15f, reference_scale));
    const float gap = 10.f * control_scale;
    const float right_padding = 128.f * control_scale;
    const float vertical_padding = 18.f * control_scale;

    float button_size = 114.f * control_scale;
    button_size = std::max(42.f, std::min(122.f, button_size));]=])
string(FIND "${V32_WINUTIL}" "${V32_DPAD_SIZE_OLD}" V32_DPAD_SIZE_POS)
if(V32_DPAD_SIZE_POS EQUAL -1)
    message(FATAL_ERROR "v32 adaptive: expected v27 D-pad sizing block not found")
endif()
string(REPLACE "${V32_DPAD_SIZE_OLD}" "${V32_DPAD_SIZE_NEW}" V32_WINUTIL "${V32_WINUTIL}")

# v26 anchored the D-pad to a centered, uniformly fitted 2340x1080 canvas. The
# adaptive layout occupies the actual physical window, so anchor controls to its
# physical safe edges instead. This is resolution-independent: only measured
# window bounds and the continuously scaled padding are used.
set(V32_DPAD_POS_OLD [=[    const float grid_size = 3.f * button_size + 2.f * gap;
    const float content_width = 2340.f * reference_scale;
    const float content_height = 1080.f * reference_scale;
    const float content_left = std::max(0.f,
        (static_cast<float>(window_size.x) - content_width) * 0.5f);
    const float content_top = std::max(0.f,
        (static_cast<float>(window_size.y) - content_height) * 0.5f);
    float left = content_left + content_width - right_padding - grid_size;
    float top = content_top + content_height - vertical_padding - grid_size;]=])
set(V32_DPAD_POS_NEW [=[    const float grid_size = 3.f * button_size + 2.f * gap;
    float left = static_cast<float>(window_size.x) - right_padding - grid_size;
    float top = static_cast<float>(window_size.y) - vertical_padding - grid_size;]=])
string(FIND "${V32_WINUTIL}" "${V32_DPAD_POS_OLD}" V32_DPAD_POS_POS)
if(V32_DPAD_POS_POS EQUAL -1)
    message(FATAL_ERROR "v32 adaptive: expected v26 fitted-canvas D-pad anchor not found")
endif()
string(REPLACE "${V32_DPAD_POS_OLD}" "${V32_DPAD_POS_NEW}" V32_WINUTIL "${V32_WINUTIL}")

# Use the full physical window for composition. The phone reference remains
# pixel-for-pixel equivalent at 2340x1080, while other screens receive a true
# reflow instead of a centered letterboxed reference canvas.
set(V32_LAYOUT_OLD [=[    const float w = static_cast<float>(size.x);
    const float h = static_cast<float>(size.y);
    const float reference_scale = android_reference_scale();
    const float content_w = 2340.f * reference_scale;
    const float content_h = 1080.f * reference_scale;
    const float content_left = std::max(0.f, (w - content_w) * 0.5f);
    const float content_top = std::max(0.f, (h - content_h) * 0.5f);
    const float margin = 8.f * reference_scale;
    const float gap = 6.f * reference_scale;]=])
set(V32_LAYOUT_NEW [=[    const float w = static_cast<float>(size.x);
    const float h = static_cast<float>(size.y);
    const float reference_scale = android_reference_scale();
    const float content_w = w;
    const float content_h = h;
    const float content_left = 0.f;
    const float content_top = 0.f;
    const float margin = std::max(4.f, 8.f * reference_scale);
    const float gap = std::max(3.f, 6.f * reference_scale);]=])
string(FIND "${V32_WINUTIL}" "${V32_LAYOUT_OLD}" V32_LAYOUT_POS)
if(V32_LAYOUT_POS EQUAL -1)
    message(FATAL_ERROR "v32 adaptive: expected v25 fitted mobile-layout header not found")
endif()
string(REPLACE "${V32_LAYOUT_OLD}" "${V32_LAYOUT_NEW}" V32_WINUTIL "${V32_WINUTIL}")

# Terrain is allowed to use full height only when doing so still leaves a usable
# information column before the D-pad. On tighter screens it yields smoothly in
# BOTH dimensions while retaining its original aspect ratio; only the terrain
# column gains vertical breathing room, not the entire application.
set(V32_TERRAIN_OLD [=[    const float terrain_h = content_h - margin * 2.f;
    const float terrain_w = terrain_h * (335.f / 351.f);
    const sf::FloatRect terrain_bounds(content_left + margin, content_top + margin,
                                       terrain_w, terrain_h);]=])
set(V32_TERRAIN_NEW [=[    const float terrain_ratio = 335.f / 351.f;
    const float full_terrain_h = std::max(1.f, content_h - margin * 2.f);
    const float min_info_width = std::max(220.f, 260.f * reference_scale);
    const float max_terrain_w = std::max(1.f,
        dpad_panel.left - content_left - margin - gap * 2.f - min_info_width);
    const float terrain_h = std::min(full_terrain_h, max_terrain_w / terrain_ratio);
    const float terrain_w = terrain_h * terrain_ratio;
    const float terrain_top = content_top + margin +
        std::max(0.f, (full_terrain_h - terrain_h) * 0.5f);
    const sf::FloatRect terrain_bounds(content_left + margin, terrain_top,
                                       terrain_w, terrain_h);]=])
string(FIND "${V32_WINUTIL}" "${V32_TERRAIN_OLD}" V32_TERRAIN_POS)
if(V32_TERRAIN_POS EQUAL -1)
    message(FATAL_ERROR "v32 adaptive: expected v25 terrain block not found")
endif()
string(REPLACE "${V32_TERRAIN_OLD}" "${V32_TERRAIN_NEW}" V32_WINUTIL "${V32_WINUTIL}")

file(WRITE "${V32_WINUTIL_CPP}" "${V32_WINUTIL}")
message(STATUS "Applied general Android adaptive gameplay layout v32")
