# Android physical-device follow-up after v27.
# v27 correctly resets mainView before redrawing the underlying game/title,
# but restoring mainView again after presenting the dialog breaks cControl's
# release hit-test: handleClick() maps MouseButtonReleased through the window's
# currently active view. Leave the frontmost dialog view active after draw();
# the v27 pre-redraw reset is sufficient to prevent the stale-view flash.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V28_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V28_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V28_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V28_DIALOG_CPP "${CBOE_ANDROID_UI_V28_ROOT}/src/dialogxml/dialogs/dialog.cpp")
file(READ "${CBOE_ANDROID_V28_DIALOG_CPP}" V28_DIALOG)

set(V28_DRAW_END_OLD [=[	target.setActive(true);
	target.display();
	// Do not leak a dialog-local view into the next game/title redraw.
	target.setView(mainView);
#else]=])
set(V28_DRAW_END_NEW [=[	target.setActive(true);
	target.display();
#else]=])

string(FIND "${V28_DIALOG}" "${V28_DRAW_END_OLD}" V28_DRAW_END_POS)
if(V28_DRAW_END_POS EQUAL -1)
    message(FATAL_ERROR "v28: expected v27 dialog draw-end view reset not found")
endif()
string(REPLACE "${V28_DRAW_END_OLD}" "${V28_DRAW_END_NEW}" V28_DIALOG "${V28_DIALOG}")
file(WRITE "${CBOE_ANDROID_V28_DIALOG_CPP}" "${V28_DIALOG}")

message(STATUS "Applied Android dialog touch-release view fix v28")
