# Normalize the v16 CMake script's mouse-move patch to use a stable single-line
# anchor. Earlier Android patches preserve the MouseMoved case but can change the
# exact coordinate/guard text around it, so matching the whole block is brittle.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V16_SCRIPTFIX_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V16_SCRIPTFIX_APPLIED TRUE CACHE INTERNAL "" FORCE)

set(CBOE_ANDROID_V16_SCRIPT "${CMAKE_CURRENT_LIST_DIR}/android_mobile_ui_fixes_v16.cmake")
file(READ "${CBOE_ANDROID_V16_SCRIPT}" V16_SCRIPT)

# Use a higher bracket delimiter for these outer string literals because the
# text being edited itself contains CMake [=[ ... ]=] literals.
set(V16_SCRIPT_OLD [==[set(V16_MOUSE_MOVE_OLD [=[            case sf::Event::MouseMoved: {
                const int x = event.mouseMove.x;
                const int y = event.mouseMove.y;
                if(&win == &mainPtr() && android_info_panel_contains(x, y)) {
                    event.type = sf::Event::Count;
                    break;
                }]=])
set(V16_MOUSE_MOVE_NEW [=[            case sf::Event::MouseMoved: {
                const int x = event.mouseMove.x;
                const int y = event.mouseMove.y;
                if(&win == &mainPtr() && android_panel_scroll_target != ANDROID_PANEL_SCROLL_NONE) {
                    android_update_panel_scroll(x, y);
                    event.type = sf::Event::Count;
                    break;
                }
                if(&win == &mainPtr() && android_info_panel_contains(x, y)) {
                    event.type = sf::Event::Count;
                    break;
                }]=])]==])

set(V16_SCRIPT_NEW [==[set(V16_MOUSE_MOVE_OLD [=[            case sf::Event::MouseMoved: {]=])
set(V16_MOUSE_MOVE_NEW [=[            case sf::Event::MouseMoved: {
                if(&win == &mainPtr() && android_panel_scroll_target != ANDROID_PANEL_SCROLL_NONE) {
                    android_update_panel_scroll(event.mouseMove.x, event.mouseMove.y);
                    event.type = sf::Event::Count;
                    break;
                }]=])]==])

string(FIND "${V16_SCRIPT}" "${V16_SCRIPT_OLD}" V16_SCRIPT_POS)
if(V16_SCRIPT_POS EQUAL -1)
    message(FATAL_ERROR "v16 scriptfix: expected original mouse-move patch block not found")
endif()
string(REPLACE "${V16_SCRIPT_OLD}" "${V16_SCRIPT_NEW}" V16_SCRIPT "${V16_SCRIPT}")
file(WRITE "${CBOE_ANDROID_V16_SCRIPT}" "${V16_SCRIPT}")
message(STATUS "Hardened Android v16 mouse-move patch anchor")
