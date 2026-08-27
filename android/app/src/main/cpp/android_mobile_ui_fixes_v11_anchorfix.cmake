# Fix the v11 automap patch's registration anchor after v4 inserts quick actions.
# This runs before v11 and rewrites only the v11 CMake patch script itself.
if(DEFINED CBOE_ANDROID_V11_ANCHORFIX_APPLIED)
    return()
endif()
set(CBOE_ANDROID_V11_ANCHORFIX_APPLIED TRUE CACHE INTERNAL "" FORCE)

set(CBOE_ANDROID_V11_SCRIPT "${CMAKE_CURRENT_LIST_DIR}/android_mobile_ui_fixes_v11.cmake")
file(READ "${CBOE_ANDROID_V11_SCRIPT}" V11_SCRIPT_SOURCE)

set(V11_BAD_REGISTER [=[set(V11_REGISTER_OLD [=[    auto dpad = std::make_shared<AndroidDpadDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 80, "android-movement-dpad", dpad);
    registered = true;]=])
set(V11_REGISTER_NEW [=[    auto dpad = std::make_shared<AndroidDpadDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 80, "android-movement-dpad", dpad);

    auto map_overlay = std::make_shared<AndroidMapOverlayDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 100, "android-map-overlay", map_overlay);
    registered = true;]=])]=])

set(V11_FIXED_REGISTER [=[set(V11_REGISTER_OLD [=[    auto dpad = std::make_shared<AndroidDpadDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 80, "android-movement-dpad", dpad);

    auto quick_actions = std::make_shared<AndroidQuickActionsDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 90, "android-quick-actions", quick_actions);
    registered = true;]=])
set(V11_REGISTER_NEW [=[    auto dpad = std::make_shared<AndroidDpadDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 80, "android-movement-dpad", dpad);

    auto quick_actions = std::make_shared<AndroidQuickActionsDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 90, "android-quick-actions", quick_actions);

    auto map_overlay = std::make_shared<AndroidMapOverlayDrawable>();
    drawable_mgr.add_drawable(UI_LAYER_DEFAULT + 100, "android-map-overlay", map_overlay);
    registered = true;]=])]=])

string(FIND "${V11_SCRIPT_SOURCE}" "${V11_BAD_REGISTER}" V11_BAD_REGISTER_POS)
if(NOT V11_BAD_REGISTER_POS EQUAL -1)
    string(REPLACE "${V11_BAD_REGISTER}" "${V11_FIXED_REGISTER}" V11_SCRIPT_SOURCE "${V11_SCRIPT_SOURCE}")
    file(WRITE "${CBOE_ANDROID_V11_SCRIPT}" "${V11_SCRIPT_SOURCE}")
else()
    string(FIND "${V11_SCRIPT_SOURCE}" "${V11_FIXED_REGISTER}" V11_FIXED_REGISTER_POS)
    if(V11_FIXED_REGISTER_POS EQUAL -1)
        message(FATAL_ERROR "v11 anchorfix: expected registration block not found")
    endif()
endif()

message(STATUS "Applied Android v11 drawable registration anchor fix")
