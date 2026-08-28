# Codeberg migration v27: normalize dialog hover coordinates to logical UI scale.
# The base Android source patch owns cDialog focus/click handling, so this runs
# afterward and changes only the non-Android mouse-hover branch.
if(DEFINED CBOE_ANDROID_CODEBERG_V27_APPLIED)
    return()
endif()
set(CBOE_ANDROID_CODEBERG_V27_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_V27_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V27_DIALOG_CPP "${CBOE_ANDROID_V27_ROOT}/src/dialogxml/dialogs/dialog.cpp")
file(READ "${CBOE_ANDROID_V27_DIALOG_CPP}" V27_DIALOG)

set(V27_MOVE_OLD [=[		case sf::Event::MouseMoved:{
#ifndef __ANDROID__
			// Did the window move, potentially dirtying the canvas below it?]=])
set(V27_MOVE_NEW [=[		case sf::Event::MouseMoved:{
#ifndef __ANDROID__
			int x = currentEvent.mouseMove.x / get_ui_scale();
			int y = currentEvent.mouseMove.y / get_ui_scale();
			// Did the window move, potentially dirtying the canvas below it?]=])

string(FIND "${V27_DIALOG}" "${V27_MOVE_OLD}" V27_MOVE_POS)
if(V27_MOVE_POS EQUAL -1)
    message(FATAL_ERROR "v27: expected Android-patched dialog MouseMoved block not found")
endif()
string(REPLACE "${V27_MOVE_OLD}" "${V27_MOVE_NEW}" V27_DIALOG "${V27_DIALOG}")

set(V27_HIT_OLD [=[ctrl.second->getBounds().contains(currentEvent.mouseMove.x, currentEvent.mouseMove.y)]=])
set(V27_HIT_NEW [=[ctrl.second->getBounds().contains(x, y)]=])
string(FIND "${V27_DIALOG}" "${V27_HIT_OLD}" V27_HIT_POS)
if(V27_HIT_POS EQUAL -1)
    message(FATAL_ERROR "v27: expected dialog hover hit-test expression not found")
endif()
string(REPLACE "${V27_HIT_OLD}" "${V27_HIT_NEW}" V27_DIALOG "${V27_DIALOG}")

file(WRITE "${CBOE_ANDROID_V27_DIALOG_CPP}" "${V27_DIALOG}")
message(STATUS "Applied Codeberg dialog hover coordinate scaling after Android input patches")
