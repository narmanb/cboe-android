# Android dialog-close follow-up kept separate from the reverted v29 layout experiment.
# v28 must leave the fitted dialog View active while the modal is open so release
# hit-testing works. Once the outermost modal actually closes, restore mainView
# before redrawing the title/game underneath. This prevents a stale dialog View
# from leaking into the next base redraw without changing title/gameplay geometry.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V31_DIALOG_CLOSE_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V31_DIALOG_CLOSE_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V31_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(V31_DIALOG_CPP "${CBOE_ANDROID_UI_V31_ROOT}/src/dialogxml/dialogs/dialog.cpp")
file(READ "${V31_DIALOG_CPP}" V31_DIALOG)

set(V31_CLOSE_OLD [=[#ifdef __ANDROID__
	set_cursor(former_curs);
	topWindow = formerTop;
	if(formerTop)
		formerTop->draw();
	else if(redraw_everything)
		redraw_everything();
#else]=])
set(V31_CLOSE_NEW [=[#ifdef __ANDROID__
	set_cursor(former_curs);
	topWindow = formerTop;
	if(formerTop) {
		formerTop->draw();
	} else {
		mainPtr().setView(mainView);
		if(redraw_everything)
			redraw_everything();
	}
#else]=])

string(FIND "${V31_DIALOG}" "${V31_CLOSE_OLD}" V31_CLOSE_POS)
if(V31_CLOSE_POS EQUAL -1)
    message(FATAL_ERROR "v31 dialog close: expected Android outer-dialog redraw block not found")
endif()
string(REPLACE "${V31_CLOSE_OLD}" "${V31_CLOSE_NEW}" V31_DIALOG "${V31_DIALOG}")
file(WRITE "${V31_DIALOG_CPP}" "${V31_DIALOG}")

message(STATUS "Applied Android outer-dialog mainView restore v31")
