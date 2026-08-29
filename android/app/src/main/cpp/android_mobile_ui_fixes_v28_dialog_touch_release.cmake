# Android physical-device follow-up after v27.
# v27 correctly resets mainView before redrawing the underlying game/title,
# but restoring mainView again after presenting the dialog breaks cControl's
# release hit-test: handleClick() maps MouseButtonReleased through the window's
# currently active view. Leave the frontmost dialog view active after draw();
# the v27 pre-redraw reset is sufficient to prevent the stale-view flash.
# Also expose exact dialog-control centers/clicks to the emulator smoke test so
# a future press-vs-release coordinate regression cannot pass CI unnoticed.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V28_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V28_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V28_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V28_DIALOG_CPP "${CBOE_ANDROID_UI_V28_ROOT}/src/dialogxml/dialogs/dialog.cpp")
set(CBOE_ANDROID_V28_CONTROL_CPP "${CBOE_ANDROID_UI_V28_ROOT}/src/dialogxml/widgets/control.cpp")

# Keep the frontmost dialog view active after cDialog::draw(). cControl::handleClick
# consumes MouseButtonReleased after redraw() and maps that release through the
# RenderWindow's current view, so resetting to mainView here makes every modal
# button look pressable but fail its release hit-test.
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

# Emulator diagnostics: log each clickable control's exact physical center once
# per process. The runtime smoke uses this to tap a real fitted-modal button.
set(V28_DIALOG_INCLUDE_OLD [=[#include <map>
#include "dialog.hpp"]=])
set(V28_DIALOG_INCLUDE_NEW [=[#include <map>
#include <set>
#include <android/log.h>
#include "dialog.hpp"]=])
string(FIND "${V28_DIALOG}" "${V28_DIALOG_INCLUDE_OLD}" V28_DIALOG_INCLUDE_POS)
if(V28_DIALOG_INCLUDE_POS EQUAL -1)
    message(FATAL_ERROR "v28: expected dialog include anchor not found")
endif()
string(REPLACE "${V28_DIALOG_INCLUDE_OLD}" "${V28_DIALOG_INCLUDE_NEW}" V28_DIALOG "${V28_DIALOG}")

set(V28_DIALOG_CONTROLS_OLD [=[		ctrlIter iter = dialog->controls.begin();
		while(iter != dialog->controls.end()){
			iter->second->draw();
			iter++;
		}]=])
set(V28_DIALOG_CONTROLS_NEW [=[		static std::set<std::string> android_logged_control_centers;
		ctrlIter iter = dialog->controls.begin();
		while(iter != dialog->controls.end()){
			if(iter->second->isVisible() && iter->second->isClickable()) {
				const std::string log_key = dialog->fname + ":" + iter->first;
				if(android_logged_control_centers.insert(log_key).second) {
					const rectangle bounds = iter->second->getBounds();
					const sf::Vector2f center(
						(static_cast<float>(bounds.left) + static_cast<float>(bounds.right)) * 0.5f,
						(static_cast<float>(bounds.top) + static_cast<float>(bounds.bottom)) * 0.5f);
					const sf::Vector2i pixel = target.mapCoordsToPixel(center, android_dialog_view(*dialog));
					__android_log_print(ANDROID_LOG_INFO, "OpenBoEAndroid",
						"DIALOG_CONTROL_CENTER %s %s %d %d",
						dialog->fname.c_str(), iter->first.c_str(), pixel.x, pixel.y);
				}
			}
			iter->second->draw();
			iter++;
		}]=])
string(FIND "${V28_DIALOG}" "${V28_DIALOG_CONTROLS_OLD}" V28_DIALOG_CONTROLS_POS)
if(V28_DIALOG_CONTROLS_POS EQUAL -1)
    message(FATAL_ERROR "v28: expected Android dialog control draw loop not found")
endif()
string(REPLACE "${V28_DIALOG_CONTROLS_OLD}" "${V28_DIALOG_CONTROLS_NEW}" V28_DIALOG "${V28_DIALOG}")
file(WRITE "${CBOE_ANDROID_V28_DIALOG_CPP}" "${V28_DIALOG}")

# Log successful control dispatches too. A press event alone is insufficient:
# the physical regression reported on Retroid happened when release mapping used
# mainView and handleClick() therefore returned false.
file(READ "${CBOE_ANDROID_V28_CONTROL_CPP}" V28_CONTROL)
set(V28_CONTROL_INCLUDE_OLD [=[#include "winutil.hpp"]=])
set(V28_CONTROL_INCLUDE_NEW [=[#include "winutil.hpp"
#include <android/log.h>]=])
string(FIND "${V28_CONTROL}" "${V28_CONTROL_INCLUDE_OLD}" V28_CONTROL_INCLUDE_POS)
if(V28_CONTROL_INCLUDE_POS EQUAL -1)
    message(FATAL_ERROR "v28: expected control include anchor not found")
endif()
string(REPLACE "${V28_CONTROL_INCLUDE_OLD}" "${V28_CONTROL_INCLUDE_NEW}" V28_CONTROL "${V28_CONTROL}")

set(V28_TRIGGER_OLD [=[bool cControl::triggerClickHandler(cDialog& dlg, std::string id, eKeyMod mods){
	if(recording){]=])
set(V28_TRIGGER_NEW [=[bool cControl::triggerClickHandler(cDialog& dlg, std::string id, eKeyMod mods){
	__android_log_print(ANDROID_LOG_INFO, "OpenBoEAndroid", "DIALOG_CONTROL_CLICK %s", id.c_str());
	if(recording){]=])
string(FIND "${V28_CONTROL}" "${V28_TRIGGER_OLD}" V28_TRIGGER_POS)
if(V28_TRIGGER_POS EQUAL -1)
    message(FATAL_ERROR "v28: expected control click-dispatch anchor not found")
endif()
string(REPLACE "${V28_TRIGGER_OLD}" "${V28_TRIGGER_NEW}" V28_CONTROL "${V28_CONTROL}")
file(WRITE "${CBOE_ANDROID_V28_CONTROL_CPP}" "${V28_CONTROL}")

message(STATUS "Applied Android dialog touch-release view fix v28")
