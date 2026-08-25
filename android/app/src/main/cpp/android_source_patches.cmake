# Android-only source compatibility patches applied before the main CMake
# project configures its targets. Keep these narrowly tied to verified Android
# failures so the upstream desktop sources remain otherwise untouched.

if(DEFINED CBOE_ANDROID_SOURCE_PATCHES_APPLIED)
    return()
endif()
set(CBOE_ANDROID_SOURCE_PATCHES_APPLIED TRUE CACHE INTERNAL "")

get_filename_component(CBOE_ANDROID_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)

# SFML 2.6.2's sf::Texture copy constructor performs a GPU readback through
# Texture::copyToImage(). On Android/OpenGL ES that path has produced a null
# function-pointer crash. draw_startup_anim only needs to draw the existing
# startanim texture, so keep a reference instead of copying the GPU texture.
set(CBOE_GRAPHICS_CPP "${CBOE_ANDROID_ROOT}/src/game/boe.graphics.cpp")
file(READ "${CBOE_GRAPHICS_CPP}" CBOE_GRAPHICS_SOURCE)
set(CBOE_STARTANIM_COPY_OLD "auto scroll_sprite = *ResMgr::graphics.get(\"startanim\",true);")
set(CBOE_STARTANIM_COPY_NEW "sf::Texture& scroll_sprite = *ResMgr::graphics.get(\"startanim\",true);")
string(FIND "${CBOE_GRAPHICS_SOURCE}" "${CBOE_STARTANIM_COPY_OLD}" CBOE_STARTANIM_COPY_POS)
if(CBOE_STARTANIM_COPY_POS EQUAL -1)
    message(FATAL_ERROR "Expected OpenBoE draw_startup_anim texture copy was not found")
endif()
string(REPLACE "${CBOE_STARTANIM_COPY_OLD}" "${CBOE_STARTANIM_COPY_NEW}" CBOE_GRAPHICS_SOURCE "${CBOE_GRAPHICS_SOURCE}")

# Emit the exact physical pixel center of the Tutorial button once. The CI
# emulator uses this to perform a real Android touchscreen tap instead of only
# checking that the process stayed alive.
set(CBOE_GRAPHICS_INCLUDE_OLD "#include <fmt/format.h>")
set(CBOE_GRAPHICS_INCLUDE_NEW "#include <fmt/format.h>\n#include <android/log.h>")
string(FIND "${CBOE_GRAPHICS_SOURCE}" "${CBOE_GRAPHICS_INCLUDE_OLD}" CBOE_GRAPHICS_INCLUDE_POS)
if(CBOE_GRAPHICS_INCLUDE_POS EQUAL -1)
    message(FATAL_ERROR "Expected OpenBoE graphics include block was not found")
endif()
string(REPLACE "${CBOE_GRAPHICS_INCLUDE_OLD}" "${CBOE_GRAPHICS_INCLUDE_NEW}" CBOE_GRAPHICS_SOURCE "${CBOE_GRAPHICS_SOURCE}")
set(CBOE_DRAW_STARTUP_OLD [=[void draw_startup(short but_type) {
	sf::Texture& startup_gworld = *ResMgr::graphics.get("startup", true);]=])
set(CBOE_DRAW_STARTUP_NEW [=[void draw_startup(short but_type) {
	static bool android_startup_center_logged = false;
	if(!android_startup_center_logged) {
		const rectangle& r = startup_button[STARTBTN_TUTORIAL];
		sf::Vector2f center((r.left + r.right) / 2.0f, (r.top + r.bottom) / 2.0f);
		sf::Vector2i pixel = mainPtr().mapCoordsToPixel(center, mainView);
		__android_log_print(ANDROID_LOG_INFO, "OpenBoEAndroid", "TUTORIAL_CENTER %d %d", pixel.x, pixel.y);
		android_startup_center_logged = true;
	}
	sf::Texture& startup_gworld = *ResMgr::graphics.get("startup", true);]=])
string(FIND "${CBOE_GRAPHICS_SOURCE}" "${CBOE_DRAW_STARTUP_OLD}" CBOE_DRAW_STARTUP_POS)
if(CBOE_DRAW_STARTUP_POS EQUAL -1)
    message(FATAL_ERROR "Expected OpenBoE draw_startup function was not found")
endif()
string(REPLACE "${CBOE_DRAW_STARTUP_OLD}" "${CBOE_DRAW_STARTUP_NEW}" CBOE_GRAPHICS_SOURCE "${CBOE_GRAPHICS_SOURCE}")

# Android dialogs are composited into the one NativeActivity RenderWindow. While
# the base game is being redrawn underneath an open dialog, defer its buffer swap
# so the dialog can be drawn into the same back buffer and presented once.
set(CBOE_MAINVIEW_OLD [=[sf::View mainView;

extern enum_map(eGuiArea, rectangle) win_to_rects;]=])
set(CBOE_MAINVIEW_NEW [=[sf::View mainView;
bool android_suppress_main_present = false;

extern enum_map(eGuiArea, rectangle) win_to_rects;]=])
string(FIND "${CBOE_GRAPHICS_SOURCE}" "${CBOE_MAINVIEW_OLD}" CBOE_MAINVIEW_POS)
if(CBOE_MAINVIEW_POS EQUAL -1)
    message(FATAL_ERROR "Expected OpenBoE mainView definition was not found")
endif()
string(REPLACE "${CBOE_MAINVIEW_OLD}" "${CBOE_MAINVIEW_NEW}" CBOE_GRAPHICS_SOURCE "${CBOE_GRAPHICS_SOURCE}")
set(CBOE_REDRAW_PRESENT_OLD [=[	mainPtr().display();
}

void put_background() {]=])
set(CBOE_REDRAW_PRESENT_NEW [=[	if(!android_suppress_main_present)
		mainPtr().display();
}

void put_background() {]=])
string(FIND "${CBOE_GRAPHICS_SOURCE}" "${CBOE_REDRAW_PRESENT_OLD}" CBOE_REDRAW_PRESENT_POS)
if(CBOE_REDRAW_PRESENT_POS EQUAL -1)
    message(FATAL_ERROR "Expected OpenBoE redraw_screen present call was not found")
endif()
string(REPLACE "${CBOE_REDRAW_PRESENT_OLD}" "${CBOE_REDRAW_PRESENT_NEW}" CBOE_GRAPHICS_SOURCE "${CBOE_GRAPHICS_SOURCE}")

file(WRITE "${CBOE_GRAPHICS_CPP}" "${CBOE_GRAPHICS_SOURCE}")
message(STATUS "Applied Android draw_startup, dialog-compositing, and touch-test graphics patches")

# On desktop the game shows Welcome / Tip-of-the-Day in a separate modal
# RenderWindow before the real main event loop starts. SFML's Android backend
# only supports one native window. On Android that hidden modal dialog can own
# the input/lifecycle loop while the title screen is what gets drawn underneath,
# which makes the visible title buttons appear completely dead and can expose the
# little dialog surface after an app switch. Do not create those pre-main-loop
# desktop windows on Android. We can reintroduce their content later as an
# in-window overlay.
set(CBOE_MAIN_CPP "${CBOE_ANDROID_ROOT}/src/game/boe.main.cpp")
file(READ "${CBOE_MAIN_CPP}" CBOE_MAIN_SOURCE)
set(CBOE_STARTUP_DIALOGS_OLD [=[		init_boe(argc, argv);
		
		if(!get_bool_pref("GameRunBefore"))
			showWelcome();
		else if(get_bool_pref("GiveIntroHint", true))
			tip_of_day();
		set_pref("GameRunBefore", true);
		finished_init = true;]=])
set(CBOE_STARTUP_DIALOGS_NEW [=[		init_boe(argc, argv);
		
		// Android: skip desktop-only startup modal windows. The main title
		// screen must own the NativeActivity surface and event loop directly.
		set_pref("GameRunBefore", true);
		finished_init = true;]=])
string(FIND "${CBOE_MAIN_SOURCE}" "${CBOE_STARTUP_DIALOGS_OLD}" CBOE_STARTUP_DIALOGS_POS)
if(CBOE_STARTUP_DIALOGS_POS EQUAL -1)
    message(FATAL_ERROR "Expected OpenBoE startup welcome/tip block was not found")
endif()
string(REPLACE "${CBOE_STARTUP_DIALOGS_OLD}" "${CBOE_STARTUP_DIALOGS_NEW}" CBOE_MAIN_SOURCE "${CBOE_MAIN_SOURCE}")

# The minimap is another standalone desktop RenderWindow. It is initialized even
# while hidden, which is enough for SFML Android to replace the NativeActivity's
# global lifecycle context with the wrong window. Keep it disabled until it is
# ported to the same in-window overlay model as dialogs.
set(CBOE_MINIMAP_INIT_OLD "\tinit_mini_map();")
string(FIND "${CBOE_MAIN_SOURCE}" "${CBOE_MINIMAP_INIT_OLD}" CBOE_MINIMAP_INIT_POS)
if(CBOE_MINIMAP_INIT_POS EQUAL -1)
    message(FATAL_ERROR "Expected OpenBoE minimap initialization call was not found")
endif()
set(CBOE_MINIMAP_INIT_NEW "\t// Android: standalone minimap RenderWindow disabled; port it as an overlay later.")
string(REPLACE "${CBOE_MINIMAP_INIT_OLD}" "${CBOE_MINIMAP_INIT_NEW}" CBOE_MAIN_SOURCE "${CBOE_MAIN_SOURCE}")

file(WRITE "${CBOE_MAIN_CPP}" "${CBOE_MAIN_SOURCE}")
message(STATUS "Skipped desktop startup dialogs and standalone minimap window on Android")

# Log actual startup-button dispatch so CI can prove that a real Android tap
# reached OpenBoE's existing desktop click handler.
set(CBOE_STARTUP_CPP "${CBOE_ANDROID_ROOT}/src/game/boe.startup.cpp")
file(READ "${CBOE_STARTUP_CPP}" CBOE_STARTUP_SOURCE)
set(CBOE_STARTUP_INCLUDE_OLD "#include <boost/lexical_cast.hpp>")
set(CBOE_STARTUP_INCLUDE_NEW "#include <boost/lexical_cast.hpp>\n#include <android/log.h>")
string(FIND "${CBOE_STARTUP_SOURCE}" "${CBOE_STARTUP_INCLUDE_OLD}" CBOE_STARTUP_INCLUDE_POS)
if(CBOE_STARTUP_INCLUDE_POS EQUAL -1)
    message(FATAL_ERROR "Expected OpenBoE startup include block was not found")
endif()
string(REPLACE "${CBOE_STARTUP_INCLUDE_OLD}" "${CBOE_STARTUP_INCLUDE_NEW}" CBOE_STARTUP_SOURCE "${CBOE_STARTUP_SOURCE}")
set(CBOE_STARTUP_CLICK_OLD [=[void handle_startup_button_click(eStartButton btn, eKeyMod mods) {
	if(recording){]=])
set(CBOE_STARTUP_CLICK_NEW [=[void handle_startup_button_click(eStartButton btn, eKeyMod mods) {
	__android_log_print(ANDROID_LOG_INFO, "OpenBoEAndroid", "STARTUP_BUTTON_CLICK %d", static_cast<int>(btn));
	if(recording){]=])
string(FIND "${CBOE_STARTUP_SOURCE}" "${CBOE_STARTUP_CLICK_OLD}" CBOE_STARTUP_CLICK_POS)
if(CBOE_STARTUP_CLICK_POS EQUAL -1)
    message(FATAL_ERROR "Expected OpenBoE startup click handler was not found")
endif()
string(REPLACE "${CBOE_STARTUP_CLICK_OLD}" "${CBOE_STARTUP_CLICK_NEW}" CBOE_STARTUP_SOURCE "${CBOE_STARTUP_SOURCE}")
file(WRITE "${CBOE_STARTUP_CPP}" "${CBOE_STARTUP_SOURCE}")
message(STATUS "Added Android startup touch-dispatch diagnostics")

# SFML Android has one NativeActivity window, but OpenBoE's dialog framework is
# desktop-oriented and creates a new sf::RenderWindow for every modal dialog.
# The physical-device symptom is very specific: a title button draws its blue
# pressed state, then the action stalls. Render every dialog (including nested
# dialogs) as a centered viewport inside mainPtr() instead, and map touchscreen
# pixels back into that dialog-local coordinate system.
set(CBOE_DIALOG_HPP "${CBOE_ANDROID_ROOT}/src/dialogxml/dialogs/dialog.hpp")
file(READ "${CBOE_DIALOG_HPP}" CBOE_DIALOG_HPP_SOURCE)
set(CBOE_DIALOG_GETWINDOW_OLD "\tsf::RenderWindow& getWindow() override { return win; }")
set(CBOE_DIALOG_GETWINDOW_NEW "\tsf::RenderWindow& getWindow() override;")
string(FIND "${CBOE_DIALOG_HPP_SOURCE}" "${CBOE_DIALOG_GETWINDOW_OLD}" CBOE_DIALOG_GETWINDOW_POS)
if(CBOE_DIALOG_GETWINDOW_POS EQUAL -1)
    message(FATAL_ERROR "Expected cDialog::getWindow inline definition was not found")
endif()
string(REPLACE "${CBOE_DIALOG_GETWINDOW_OLD}" "${CBOE_DIALOG_GETWINDOW_NEW}" CBOE_DIALOG_HPP_SOURCE "${CBOE_DIALOG_HPP_SOURCE}")
file(WRITE "${CBOE_DIALOG_HPP}" "${CBOE_DIALOG_HPP_SOURCE}")

set(CBOE_DIALOG_CPP "${CBOE_ANDROID_ROOT}/src/dialogxml/dialogs/dialog.cpp")
file(READ "${CBOE_DIALOG_CPP}" CBOE_DIALOG_SOURCE)

set(CBOE_DIALOG_HELPERS_ANCHOR [=[extern void showError(std::string str1, cDialog* parent = nullptr);
]=])
set(CBOE_DIALOG_HELPERS_INSERT [=[extern void showError(std::string str1, cDialog* parent = nullptr);

#ifdef __ANDROID__
extern bool android_suppress_main_present;

static sf::View android_dialog_view(const cDialog& dialog) {
	rectangle bounds = dialog.getBounds();
	float ui_scale = static_cast<float>(get_ui_scale());
	if(ui_scale < 0.1f) ui_scale = 1.0f;

	const float logical_width = static_cast<float>(bounds.width()) / ui_scale;
	const float logical_height = static_cast<float>(bounds.height()) / ui_scale;
	sf::Vector2u target_size = mainPtr().getSize();
	float pixel_width = static_cast<float>(bounds.width());
	float pixel_height = static_cast<float>(bounds.height());
	float fit = 1.0f;
	if(pixel_width > 0.0f && pixel_width > target_size.x)
		fit = static_cast<float>(target_size.x) / pixel_width;
	if(pixel_height > 0.0f && pixel_height * fit > target_size.y)
		fit = static_cast<float>(target_size.y) / pixel_height;
	pixel_width *= fit;
	pixel_height *= fit;

	sf::View view(sf::FloatRect(0.0f, 0.0f, logical_width, logical_height));
	if(target_size.x > 0 && target_size.y > 0) {
		view.setViewport(sf::FloatRect(
			(static_cast<float>(target_size.x) - pixel_width) / (2.0f * target_size.x),
			(static_cast<float>(target_size.y) - pixel_height) / (2.0f * target_size.y),
			pixel_width / target_size.x,
			pixel_height / target_size.y));
	}
	return view;
}

static rectangle android_dialog_rect(const cDialog& dialog) {
	rectangle bounds = dialog.getBounds();
	float ui_scale = static_cast<float>(get_ui_scale());
	if(ui_scale < 0.1f) ui_scale = 1.0f;
	return rectangle(0, 0,
		static_cast<int>(bounds.height() / ui_scale),
		static_cast<int>(bounds.width() / ui_scale));
}
#endif
]=])
string(FIND "${CBOE_DIALOG_SOURCE}" "${CBOE_DIALOG_HELPERS_ANCHOR}" CBOE_DIALOG_HELPERS_POS)
if(CBOE_DIALOG_HELPERS_POS EQUAL -1)
    message(FATAL_ERROR "Expected dialog helper insertion anchor was not found")
endif()
string(REPLACE "${CBOE_DIALOG_HELPERS_ANCHOR}" "${CBOE_DIALOG_HELPERS_INSERT}" CBOE_DIALOG_SOURCE "${CBOE_DIALOG_SOURCE}")

set(CBOE_DIALOG_DESTRUCTOR_OLD [=[cDialog::~cDialog(){
	ctrlIter iter = controls.begin();
	while(iter != controls.end()){
		delete iter->second;
		iter++;
	}
	win.close();
}

bool cDialog::add]=])
set(CBOE_DIALOG_DESTRUCTOR_NEW [=[cDialog::~cDialog(){
	ctrlIter iter = controls.begin();
	while(iter != controls.end()){
		delete iter->second;
		iter++;
	}
	win.close();
}

sf::RenderWindow& cDialog::getWindow() {
#ifdef __ANDROID__
	return mainPtr();
#else
	return win;
#endif
}

bool cDialog::add]=])
string(FIND "${CBOE_DIALOG_SOURCE}" "${CBOE_DIALOG_DESTRUCTOR_OLD}" CBOE_DIALOG_DESTRUCTOR_POS)
if(CBOE_DIALOG_DESTRUCTOR_POS EQUAL -1)
    message(FATAL_ERROR "Expected cDialog destructor block was not found")
endif()
string(REPLACE "${CBOE_DIALOG_DESTRUCTOR_OLD}" "${CBOE_DIALOG_DESTRUCTOR_NEW}" CBOE_DIALOG_SOURCE "${CBOE_DIALOG_SOURCE}")

set(CBOE_DIALOG_RUN_OLD [=[void cDialog::run(std::function<void(cDialog&)> onopen){
	cPict::resetAnim();
	cDialog* formerTop = topWindow;

	sf::RenderWindow* parentWin = &(parent ? parent->win : mainPtr());
	auto parentPos = parentWin->getPosition();
	auto parentSz = parentWin->getSize();
	cursor_type former_curs = Cursor::current;
	dialogNotToast = true;
	set_cursor(sword_curs);
	sf::Event currentEvent;
	// Focus the first text field, if there is one
	if(!tabOrder.empty()) {
		auto iter = std::find_if(tabOrder.begin(), tabOrder.end(), [](std::pair<std::string,cTextField*> ctrl){
			return ctrl.second->isVisible();
		});
		if(iter != tabOrder.end()) {
			iter->second->triggerFocusHandler(*this, iter->first, false);
			currentFocus = iter->first;
		}
	}
	// Make sure the requested size isn't insane.
	auto desktop = sf::VideoMode::getDesktopMode();
	if(winRect.width() > desktop.width * 1.5 || winRect.height() > desktop.height * 1.5) {
		throw std::string("Dialog ") + fname + std::string(" requested a crazy window size of ") + std::to_string(winRect.width()) + "x" + std::to_string(winRect.height());
	}
	// Sometimes it seems like the Cocoa menu handling clobbers the active rendering context.
	// For whatever reason, delaying 100 milliseconds appears to fix this.
	sf::sleep(sf::milliseconds(100));
	// So this little section of code is a real-life valley of dying things.
	// Instantiating a window and then closing it seems to fix the update error, because magic.
	win.create(sf::VideoMode(1,1),"");
	win.close();
	win.create(sf::VideoMode(winRect.width(), winRect.height()), "Dialog", sf::Style::Titlebar);
	winLastX = parentPos.x + (int(parentSz.x) - winRect.width()) / 2;
	winLastY = parentPos.y + (int(parentSz.y) - winRect.height()) / 2;
	win.setPosition({winLastX, winLastY});
	draw();
	stackWindowsCorrectly();
	// This is a loose modal session, as it doesn't prevent you from clicking away,
	// but it does prevent editing other dialogs, and it also keeps this window on top
	// even when it loses focus.
	ModalSession dlog(win, *parentWin);
	animTimer.restart();

	has_focus = true;
	topWindow = this;

	// Run the static onOpen event first
	if(cDialog::onOpen) cDialog::onOpen(*this);
	// Run this dialog's onOpen event
	if(onopen) onopen(*this);

	handle_events();

	win.setVisible(false);
	// Flush events on parent window from while this one was running
	while(pollEvent(parentWin, currentEvent));
	set_cursor(former_curs);
	topWindow = formerTop;
	stackWindowsCorrectly();
	if(cDialog::onClose) cDialog::onClose(*this);
}]=])
set(CBOE_DIALOG_RUN_NEW [=[void cDialog::run(std::function<void(cDialog&)> onopen){
	cPict::resetAnim();
	cDialog* formerTop = topWindow;

#ifdef __ANDROID__
	sf::RenderWindow* parentWin = &mainPtr();
#else
	sf::RenderWindow* parentWin = &(parent ? parent->win : mainPtr());
#endif
	auto parentPos = parentWin->getPosition();
	auto parentSz = parentWin->getSize();
	cursor_type former_curs = Cursor::current;
	dialogNotToast = true;
	set_cursor(sword_curs);
	sf::Event currentEvent;
	// Focus the first text field, if there is one
	if(!tabOrder.empty()) {
		auto iter = std::find_if(tabOrder.begin(), tabOrder.end(), [](std::pair<std::string,cTextField*> ctrl){
			return ctrl.second->isVisible();
		});
		if(iter != tabOrder.end()) {
			iter->second->triggerFocusHandler(*this, iter->first, false);
			currentFocus = iter->first;
		}
	}
	// Make sure the requested size isn't insane.
	auto desktop = sf::VideoMode::getDesktopMode();
	if(winRect.width() > desktop.width * 1.5 || winRect.height() > desktop.height * 1.5) {
		throw std::string("Dialog ") + fname + std::string(" requested a crazy window size of ") + std::to_string(winRect.width()) + "x" + std::to_string(winRect.height());
	}
#ifdef __ANDROID__
	// Android has exactly one NativeActivity window. Draw this modal into the
	// main RenderWindow instead of creating a second SFML window/context.
	animTimer.restart();
	has_focus = true;
	topWindow = this;
	draw();
	ModalSession dlog(getWindow(), *parentWin);
#else
	// Sometimes it seems like the Cocoa menu handling clobbers the active rendering context.
	// For whatever reason, delaying 100 milliseconds appears to fix this.
	sf::sleep(sf::milliseconds(100));
	// So this little section of code is a real-life valley of dying things.
	// Instantiating a window and then closing it seems to fix the update error, because magic.
	win.create(sf::VideoMode(1,1),"");
	win.close();
	win.create(sf::VideoMode(winRect.width(), winRect.height()), "Dialog", sf::Style::Titlebar);
	winLastX = parentPos.x + (int(parentSz.x) - winRect.width()) / 2;
	winLastY = parentPos.y + (int(parentSz.y) - winRect.height()) / 2;
	win.setPosition({winLastX, winLastY});
	draw();
	stackWindowsCorrectly();
	// This is a loose modal session, as it doesn't prevent you from clicking away,
	// but it does prevent editing other dialogs, and it also keeps this window on top
	// even when it loses focus.
	ModalSession dlog(win, *parentWin);
	animTimer.restart();

	has_focus = true;
	topWindow = this;
#endif

	// Run the static onOpen event first
	if(cDialog::onOpen) cDialog::onOpen(*this);
	// Run this dialog's onOpen event
	if(onopen) onopen(*this);

	handle_events();

#ifdef __ANDROID__
	set_cursor(former_curs);
	topWindow = formerTop;
	if(formerTop)
		formerTop->draw();
	else if(redraw_everything)
		redraw_everything();
#else
	win.setVisible(false);
	// Flush events on parent window from while this one was running
	while(pollEvent(parentWin, currentEvent));
	set_cursor(former_curs);
	topWindow = formerTop;
	stackWindowsCorrectly();
#endif
	if(cDialog::onClose) cDialog::onClose(*this);
}]=])
string(FIND "${CBOE_DIALOG_SOURCE}" "${CBOE_DIALOG_RUN_OLD}" CBOE_DIALOG_RUN_POS)
if(CBOE_DIALOG_RUN_POS EQUAL -1)
    message(FATAL_ERROR "Expected cDialog::run implementation was not found")
endif()
string(REPLACE "${CBOE_DIALOG_RUN_OLD}" "${CBOE_DIALOG_RUN_NEW}" CBOE_DIALOG_SOURCE "${CBOE_DIALOG_SOURCE}")

set(CBOE_DIALOG_EVENT_LOOP_OLD [=[			if(has_focus && onHandleEvents) onHandleEvents(win);
			while(pollEvent(win, currentEvent)){]=])
set(CBOE_DIALOG_EVENT_LOOP_NEW [=[			if(has_focus && onHandleEvents) onHandleEvents(getWindow());
			while(pollEvent(getWindow(), currentEvent)){]=])
string(FIND "${CBOE_DIALOG_SOURCE}" "${CBOE_DIALOG_EVENT_LOOP_OLD}" CBOE_DIALOG_EVENT_LOOP_POS)
if(CBOE_DIALOG_EVENT_LOOP_POS EQUAL -1)
    message(FATAL_ERROR "Expected cDialog event-loop window calls were not found")
endif()
string(REPLACE "${CBOE_DIALOG_EVENT_LOOP_OLD}" "${CBOE_DIALOG_EVENT_LOOP_NEW}" CBOE_DIALOG_SOURCE "${CBOE_DIALOG_SOURCE}")

set(CBOE_DIALOG_STACK_OLD [=[void cDialog::stackWindowsCorrectly() {
	// Put all dialogs in correct z order:
	std::vector<cDialog*> dialog_stack;
	cDialog* next = this;
	while(next != nullptr){
		dialog_stack.push_back(next);
		next = next->parent;
	}
	makeFrontWindow(mainPtr());
	for(int i = dialog_stack.size() - 1; i >= 0; --i){
		if(dialog_stack[i]->dialogNotToast){
			makeFrontWindow(dialog_stack[i]->win);
		}
	}
}]=])
set(CBOE_DIALOG_STACK_NEW [=[void cDialog::stackWindowsCorrectly() {
#ifdef __ANDROID__
	// All Android dialogs share mainPtr(); there are no OS windows to reorder.
	return;
#else
	// Put all dialogs in correct z order:
	std::vector<cDialog*> dialog_stack;
	cDialog* next = this;
	while(next != nullptr){
		dialog_stack.push_back(next);
		next = next->parent;
	}
	makeFrontWindow(mainPtr());
	for(int i = dialog_stack.size() - 1; i >= 0; --i){
		if(dialog_stack[i]->dialogNotToast){
			makeFrontWindow(dialog_stack[i]->win);
		}
	}
#endif
}]=])
string(FIND "${CBOE_DIALOG_SOURCE}" "${CBOE_DIALOG_STACK_OLD}" CBOE_DIALOG_STACK_POS)
if(CBOE_DIALOG_STACK_POS EQUAL -1)
    message(FATAL_ERROR "Expected cDialog::stackWindowsCorrectly implementation was not found")
endif()
string(REPLACE "${CBOE_DIALOG_STACK_OLD}" "${CBOE_DIALOG_STACK_NEW}" CBOE_DIALOG_SOURCE "${CBOE_DIALOG_SOURCE}")

set(CBOE_DIALOG_POINTER_EVENTS_OLD [=[		case sf::Event::MouseButtonPressed:
			key.mod = current_key_mod();
			where = {(int)(currentEvent.mouseButton.x / get_ui_scale()), (int)(currentEvent.mouseButton.y / get_ui_scale())};
			process_click(where, key.mod, fps_limiter);
			break;
		case sf::Event::LostFocus:
			has_focus = false;
			if(onLostFocus){
				onLostFocus(win);
			}
			break;
		case sf::Event::GainedFocus:
			if(!has_focus){
				has_focus = true;
				if(onGainedFocus){
					onGainedFocus(win);
				}
				stackWindowsCorrectly();
			}
			BOOST_FALLTHROUGH;
		case sf::Event::MouseMoved:{
			// Did the window move, potentially dirtying the canvas below it?
			if(check_window_moved(win, winLastX, winLastY))
				if (redraw_everything != NULL)
					redraw_everything();

			bool inField = false;
			for(auto& ctrl : controls) {
				if(ctrl.second->getType() == CTRL_FIELD && ctrl.second->getBounds().contains(currentEvent.mouseMove.x, currentEvent.mouseMove.y)) {
					set_cursor(text_curs);
					inField = true;
					break;
				}
			}
			if(!inField) set_cursor(sword_curs);
		}break;]=])
set(CBOE_DIALOG_POINTER_EVENTS_NEW [=[		case sf::Event::MouseButtonPressed:
			key.mod = current_key_mod();
#ifdef __ANDROID__
			{
				sf::Vector2f mapped = mainPtr().mapPixelToCoords(
					{currentEvent.mouseButton.x, currentEvent.mouseButton.y}, android_dialog_view(*this));
				where = {static_cast<int>(mapped.x), static_cast<int>(mapped.y)};
			}
#else
			where = {(int)(currentEvent.mouseButton.x / get_ui_scale()), (int)(currentEvent.mouseButton.y / get_ui_scale())};
#endif
			process_click(where, key.mod, fps_limiter);
			break;
		case sf::Event::LostFocus:
			has_focus = false;
#ifndef __ANDROID__
			if(onLostFocus){
				onLostFocus(win);
			}
#endif
			break;
		case sf::Event::GainedFocus:
			if(!has_focus){
				has_focus = true;
#ifndef __ANDROID__
				if(onGainedFocus){
					onGainedFocus(win);
				}
				stackWindowsCorrectly();
#endif
			}
#ifdef __ANDROID__
			break;
#else
			BOOST_FALLTHROUGH;
#endif
		case sf::Event::MouseMoved:{
#ifndef __ANDROID__
			// Did the window move, potentially dirtying the canvas below it?
			if(check_window_moved(win, winLastX, winLastY))
				if (redraw_everything != NULL)
					redraw_everything();

			bool inField = false;
			for(auto& ctrl : controls) {
				if(ctrl.second->getType() == CTRL_FIELD && ctrl.second->getBounds().contains(currentEvent.mouseMove.x, currentEvent.mouseMove.y)) {
					set_cursor(text_curs);
					inField = true;
					break;
				}
			}
			if(!inField) set_cursor(sword_curs);
#endif
		}break;]=])
string(FIND "${CBOE_DIALOG_SOURCE}" "${CBOE_DIALOG_POINTER_EVENTS_OLD}" CBOE_DIALOG_POINTER_EVENTS_POS)
if(CBOE_DIALOG_POINTER_EVENTS_POS EQUAL -1)
    message(FATAL_ERROR "Expected cDialog pointer/focus event block was not found")
endif()
string(REPLACE "${CBOE_DIALOG_POINTER_EVENTS_OLD}" "${CBOE_DIALOG_POINTER_EVENTS_NEW}" CBOE_DIALOG_SOURCE "${CBOE_DIALOG_SOURCE}")

set(CBOE_DIALOG_DRAW_OLD [=[void cDialog::draw(){
	win.setActive(false);
	tileImage(win,winRect,::bg[bg]);
	if(doAnimations && animTimer.getElapsedTime().asMilliseconds() >= (1000 / anim_pict_fps)) {
		cPict::advanceAnim();
		animTimer.restart();
	}
	
	// Scale dialogs:
	sf::View view = win.getDefaultView();
	view.setViewport(sf::FloatRect(0, 0, get_ui_scale(), get_ui_scale()));
	win.setView(view);
	
	ctrlIter iter = controls.begin();
	while(iter != controls.end()){
		iter->second->draw();
		iter++;
	}
	
	win.setActive();
	win.display();
}]=])
set(CBOE_DIALOG_DRAW_NEW [=[void cDialog::draw(){
#ifdef __ANDROID__
	sf::RenderWindow& target = mainPtr();

	// Draw the normal game/title screen and every parent dialog into one back
	// buffer, then present only after the frontmost dialog has been composited.
	android_suppress_main_present = true;
	if(redraw_everything)
		redraw_everything();
	else
		target.clear(sf::Color::Black);
	android_suppress_main_present = false;

	std::vector<cDialog*> dialog_stack;
	for(cDialog* next = this; next != nullptr; next = next->parent)
		dialog_stack.push_back(next);

	for(auto it = dialog_stack.rbegin(); it != dialog_stack.rend(); ++it) {
		cDialog* dialog = *it;
		target.setActive(true);
		target.setView(android_dialog_view(*dialog));
		tileImage(target, android_dialog_rect(*dialog), ::bg[dialog->bg]);

		if(dialog->doAnimations && dialog->animTimer.getElapsedTime().asMilliseconds() >= (1000 / dialog->anim_pict_fps)) {
			cPict::advanceAnim();
			dialog->animTimer.restart();
		}

		ctrlIter iter = dialog->controls.begin();
		while(iter != dialog->controls.end()){
			iter->second->draw();
			iter++;
		}
	}

	target.setActive(true);
	target.display();
#else
	win.setActive(false);
	tileImage(win,winRect,::bg[bg]);
	if(doAnimations && animTimer.getElapsedTime().asMilliseconds() >= (1000 / anim_pict_fps)) {
		cPict::advanceAnim();
		animTimer.restart();
	}
	
	// Scale dialogs:
	sf::View view = win.getDefaultView();
	view.setViewport(sf::FloatRect(0, 0, get_ui_scale(), get_ui_scale()));
	win.setView(view);
	
	ctrlIter iter = controls.begin();
	while(iter != controls.end()){
		iter->second->draw();
		iter++;
	}
	
	win.setActive();
	win.display();
#endif
}]=])
string(FIND "${CBOE_DIALOG_SOURCE}" "${CBOE_DIALOG_DRAW_OLD}" CBOE_DIALOG_DRAW_POS)
if(CBOE_DIALOG_DRAW_POS EQUAL -1)
    message(FATAL_ERROR "Expected cDialog::draw implementation was not found")
endif()
string(REPLACE "${CBOE_DIALOG_DRAW_OLD}" "${CBOE_DIALOG_DRAW_NEW}" CBOE_DIALOG_SOURCE "${CBOE_DIALOG_SOURCE}")

file(WRITE "${CBOE_DIALOG_CPP}" "${CBOE_DIALOG_SOURCE}")
message(STATUS "Converted OpenBoE modal dialogs to Android in-window overlays")

# The Android SFML lifecycle stores one global EglContext pointer and assumes
# there can only ever be one window. A later auxiliary RenderWindow used to
# overwrite that pointer, so Home/app-switch recreated the EGL surface on the
# wrong context and the real game window resumed black. Once SFML has been
# populated, keep the first real window context as lifecycle owner and only clear
# it if that exact context is destroyed.
function(cboe_patch_sfml_android_lifecycle_context)
    FetchContent_GetProperties(SFML)
    if(NOT sfml_POPULATED OR NOT EXISTS "${sfml_SOURCE_DIR}/src/SFML/Window/EglContext.cpp")
        message(FATAL_ERROR "SFML source was not populated before deferred Android lifecycle patch")
    endif()

    set(SFML_EGL_CPP "${sfml_SOURCE_DIR}/src/SFML/Window/EglContext.cpp")
    file(READ "${SFML_EGL_CPP}" SFML_EGL_SOURCE)

    set(SFML_CONTEXT_OWNER_OLD [=[    states.context = this;]=])
    set(SFML_CONTEXT_OWNER_NEW [=[    // NativeActivity has one real window. Auxiliary SFML contexts must not
    // steal lifecycle surface recreation from the main RenderWindow.
    if (!states.context)
        states.context = this;]=])
    string(FIND "${SFML_EGL_SOURCE}" "${SFML_CONTEXT_OWNER_OLD}" SFML_CONTEXT_OWNER_POS)
    if(SFML_CONTEXT_OWNER_POS EQUAL -1)
        message(FATAL_ERROR "Expected SFML Android states.context assignment was not found")
    endif()
    string(REPLACE "${SFML_CONTEXT_OWNER_OLD}" "${SFML_CONTEXT_OWNER_NEW}" SFML_EGL_SOURCE "${SFML_EGL_SOURCE}")

    set(SFML_CONTEXT_DTOR_OLD [=[EglContext::~EglContext()
{
    // Notify unshared OpenGL resources of context destruction]=])
    set(SFML_CONTEXT_DTOR_NEW [=[EglContext::~EglContext()
{
#ifdef SFML_SYSTEM_ANDROID
    if (ActivityStates* states = getActivityStatesPtr())
    {
        Lock lock(states->mutex);
        if (states->context == this)
            states->context = NULL;
    }
#endif

    // Notify unshared OpenGL resources of context destruction]=])
    string(FIND "${SFML_EGL_SOURCE}" "${SFML_CONTEXT_DTOR_OLD}" SFML_CONTEXT_DTOR_POS)
    if(SFML_CONTEXT_DTOR_POS EQUAL -1)
        message(FATAL_ERROR "Expected SFML EglContext destructor was not found")
    endif()
    string(REPLACE "${SFML_CONTEXT_DTOR_OLD}" "${SFML_CONTEXT_DTOR_NEW}" SFML_EGL_SOURCE "${SFML_EGL_SOURCE}")

    file(WRITE "${SFML_EGL_CPP}" "${SFML_EGL_SOURCE}")
    message(STATUS "Pinned Android lifecycle surface ownership to the main SFML EGL context")
endfunction()
cmake_language(DEFER CALL cboe_patch_sfml_android_lifecycle_context)

# Touch-backed pointer coordinates are now handled directly in OpenBoE's
# Android-port source (src/tools/winutil.cpp and src/game/boe.actions.cpp).
# Keeping a second text-replacement patch here would fail once the permanent
# source fix is already present, so no pointer source rewrite is needed here.