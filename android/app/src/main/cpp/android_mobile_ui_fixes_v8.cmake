# Android physical-touch duplicate suppression after v7.
# SFML/Android can deliver a near-immediate duplicate mouse release for one
# physical tap. Most direct panel actions merely repeat, but the two-step party
# order switch interprets the duplicate as selecting the same PC again.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V8_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V8_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V8_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_WINUTIL_V8_CPP "${CBOE_ANDROID_UI_V8_ROOT}/src/tools/winutil.cpp")
file(READ "${CBOE_ANDROID_WINUTIL_V8_CPP}" CBOE_ANDROID_WINUTIL_V8_SOURCE)

# Suppress only a very fast repeat release at essentially the same physical
# coordinate. A legitimate second tap on another PC row remains immediate.
set(CBOE_ANDROID_V8_HANDLER_ANCHOR [=[bool android_handle_info_panel_tap(int x, int y) {]=])
set(CBOE_ANDROID_V8_HANDLER_INSERT [=[bool android_accept_info_panel_tap(int x, int y) {
    static sf::Clock duplicate_clock;
    static bool have_previous = false;
    static int previous_x = 0;
    static int previous_y = 0;

    int dx = x - previous_x;
    int dy = y - previous_y;
    if(dx < 0) dx = -dx;
    if(dy < 0) dy = -dy;

    const bool duplicate = have_previous &&
        duplicate_clock.getElapsedTime().asMilliseconds() < 120 &&
        dx <= 12 && dy <= 12;

    if(duplicate)
        return false;

    previous_x = x;
    previous_y = y;
    have_previous = true;
    duplicate_clock.restart();
    return true;
}

bool android_handle_info_panel_tap(int x, int y) {]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V8_SOURCE}" "${CBOE_ANDROID_V8_HANDLER_ANCHOR}" CBOE_ANDROID_V8_HANDLER_POS)
if(CBOE_ANDROID_V8_HANDLER_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android direct panel handler anchor was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V8_HANDLER_ANCHOR}" "${CBOE_ANDROID_V8_HANDLER_INSERT}" CBOE_ANDROID_WINUTIL_V8_SOURCE "${CBOE_ANDROID_WINUTIL_V8_SOURCE}")

set(CBOE_ANDROID_V8_RELEASE_OLD [=[                if(&win == &mainPtr() && android_info_panel_contains(x, y)) {
                    android_handle_info_panel_tap(x, y);
                    event.type = sf::Event::Count;
                    break;
                }]=])
set(CBOE_ANDROID_V8_RELEASE_NEW [=[                if(&win == &mainPtr() && android_info_panel_contains(x, y)) {
                    if(event.mouseButton.button == sf::Mouse::Left && android_accept_info_panel_tap(x, y))
                        android_handle_info_panel_tap(x, y);
                    event.type = sf::Event::Count;
                    break;
                }]=])
string(FIND "${CBOE_ANDROID_WINUTIL_V8_SOURCE}" "${CBOE_ANDROID_V8_RELEASE_OLD}" CBOE_ANDROID_V8_RELEASE_POS)
if(CBOE_ANDROID_V8_RELEASE_POS EQUAL -1)
    message(FATAL_ERROR "Expected Android v5 direct panel release block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_V8_RELEASE_OLD}" "${CBOE_ANDROID_V8_RELEASE_NEW}" CBOE_ANDROID_WINUTIL_V8_SOURCE "${CBOE_ANDROID_WINUTIL_V8_SOURCE}")

file(WRITE "${CBOE_ANDROID_WINUTIL_V8_CPP}" "${CBOE_ANDROID_WINUTIL_V8_SOURCE}")
message(STATUS "Applied Android mobile UI v8 duplicate panel-tap suppression")
