# Android Get Items party-selector polish v24.
# - Remove the old asterisk label used to indicate the receiving character.
# - Keep the selected character's portrait button visibly depressed instead.
if(DEFINED CBOE_ANDROID_MOBILE_UI_FIXES_V24_APPLIED)
    return()
endif()
set(CBOE_ANDROID_MOBILE_UI_FIXES_V24_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_UI_V24_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V24_ITEMS_CPP "${CBOE_ANDROID_UI_V24_ROOT}/src/game/boe.items.cpp")
file(READ "${CBOE_ANDROID_V24_ITEMS_CPP}" V24_ITEMS)

set(V24_SELECTOR_OLD [=[		if(current_getting_pc == i)
			me.addLabelFor(id, "*   ", LABEL_LEFT, 7, true);
		else me.addLabelFor(id,"    ", LABEL_LEFT, 7, true);]=])
set(V24_SELECTOR_NEW [=[		// On touch screens the portrait button itself is the selection indicator.
		// Keep the chosen recipient visibly pressed instead of drawing a tiny,
		// position-sensitive asterisk beside the row.
		me[id].setActive(current_getting_pc == i);]=])

string(FIND "${V24_ITEMS}" "${V24_SELECTOR_OLD}" V24_SELECTOR_POS)
if(V24_SELECTOR_POS EQUAL -1)
    message(FATAL_ERROR "v24: expected Get Items asterisk selector code not found")
endif()
string(REPLACE "${V24_SELECTOR_OLD}" "${V24_SELECTOR_NEW}" V24_ITEMS "${V24_ITEMS}")

file(WRITE "${CBOE_ANDROID_V24_ITEMS_CPP}" "${V24_ITEMS}")
message(STATUS "Applied Android mobile UI v24 Get Items portrait selection state")
