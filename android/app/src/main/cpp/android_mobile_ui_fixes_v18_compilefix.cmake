# Android mobile UI v18 compile-order fix.
# v18's ACT geometry is emitted before the shared controls-region helpers are
# defined in transformed winutil.cpp, so provide narrow forward declarations.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V18_COMPILEFIX_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V18_COMPILEFIX_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V18_COMPILEFIX_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V18_COMPILEFIX_WINUTIL_CPP "${CBOE_ANDROID_UI_V18_COMPILEFIX_ROOT}/src/tools/winutil.cpp")
file(READ "${CBOE_ANDROID_V18_COMPILEFIX_WINUTIL_CPP}" V18_COMPILEFIX_WINUTIL)

set(V18_COMPILEFIX_ANCHOR [=[bool android_quick_geometry(sf::FloatRect& toggle,]=])
set(V18_COMPILEFIX_REPLACEMENT [=[bool android_action_controls_region(sf::FloatRect& region);
float android_action_menu_height();

bool android_quick_geometry(sf::FloatRect& toggle,]=])
string(FIND "${V18_COMPILEFIX_WINUTIL}" "${V18_COMPILEFIX_ANCHOR}" V18_COMPILEFIX_POS)
if(V18_COMPILEFIX_POS EQUAL -1)
    message(FATAL_ERROR "v18 compilefix: ACT geometry anchor not found")
endif()
string(REPLACE "${V18_COMPILEFIX_ANCHOR}" "${V18_COMPILEFIX_REPLACEMENT}" V18_COMPILEFIX_WINUTIL "${V18_COMPILEFIX_WINUTIL}")

file(WRITE "${CBOE_ANDROID_V18_COMPILEFIX_WINUTIL_CPP}" "${V18_COMPILEFIX_WINUTIL}")
message(STATUS "Applied Android mobile UI v18 helper forward declarations")
