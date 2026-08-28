# Codeberg migration v29: defer the EnterTown autosave until the queued town
# entry special has actually finished. This prevents the autosave from capturing
# stale pre-special state when an entry node changes flags, inventory, location,
# or other party/scenario state.
if(DEFINED CBOE_ANDROID_CODEBERG_V29_APPLIED)
    return()
endif()
set(CBOE_ANDROID_CODEBERG_V29_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_V29_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(V29_TOWN_CPP "${CBOE_ANDROID_V29_ROOT}/src/game/boe.town.cpp")
set(V29_TOWN_HPP "${CBOE_ANDROID_V29_ROOT}/src/game/boe.town.hpp")
set(V29_SPECIALS_CPP "${CBOE_ANDROID_V29_ROOT}/src/game/boe.specials.cpp")
set(V29_SPECIALS_HPP "${CBOE_ANDROID_V29_ROOT}/src/game/boe.specials.hpp")

# queue_special() now reports whether a valid special was queued/run.
file(READ "${V29_SPECIALS_HPP}" V29_SHPP)
set(V29_QUEUE_DECL_OLD [=[void queue_special(eSpecCtx mode, eSpecCtxType which_type, spec_num_t spec, location spec_loc);]=])
set(V29_QUEUE_DECL_NEW [=[bool queue_special(eSpecCtx mode, eSpecCtxType which_type, spec_num_t spec, location spec_loc);]=])
string(FIND "${V29_SHPP}" "${V29_QUEUE_DECL_OLD}" V29_QUEUE_DECL_POS)
if(V29_QUEUE_DECL_POS EQUAL -1)
    message(FATAL_ERROR "v29: expected queue_special declaration not found")
endif()
string(REPLACE "${V29_QUEUE_DECL_OLD}" "${V29_QUEUE_DECL_NEW}" V29_SHPP "${V29_SHPP}")
file(WRITE "${V29_SPECIALS_HPP}" "${V29_SHPP}")

file(READ "${V29_SPECIALS_CPP}" V29_SPECIALS)
set(V29_QUEUE_IMPL_OLD [=[void queue_special(eSpecCtx mode, eSpecCtxType which_type, spec_num_t spec, location spec_loc) {
	if(spec < 0) return;
	pending_special_type queued_special;
	queued_special.spec = spec;
	queued_special.where = spec_loc;
	queued_special.type = which_type;
	queued_special.mode = mode;
	queued_special.trigger_time = univ.party.age;
	// FIXME: I forced calling the leave special just to avoid calling them outside, ie. with town_num=200
	if (mode==eSpecCtx::LEAVE_TOWN)
		run_special(queued_special, nullptr, nullptr, nullptr);
	else
		special_queue.push(queued_special);
}]=])
set(V29_QUEUE_IMPL_NEW [=[bool queue_special(eSpecCtx mode, eSpecCtxType which_type, spec_num_t spec, location spec_loc) {
	if(spec < 0) return false;
	pending_special_type queued_special;
	queued_special.spec = spec;
	queued_special.where = spec_loc;
	queued_special.type = which_type;
	queued_special.mode = mode;
	queued_special.trigger_time = univ.party.age;
	// FIXME: I forced calling the leave special just to avoid calling them outside, ie. with town_num=200
	if (mode==eSpecCtx::LEAVE_TOWN)
		run_special(queued_special, nullptr, nullptr, nullptr);
	else
		special_queue.push(queued_special);
	return true;
}]=])
string(FIND "${V29_SPECIALS}" "${V29_QUEUE_IMPL_OLD}" V29_QUEUE_IMPL_POS)
if(V29_QUEUE_IMPL_POS EQUAL -1)
    message(FATAL_ERROR "v29: expected queue_special implementation not found")
endif()
string(REPLACE "${V29_QUEUE_IMPL_OLD}" "${V29_QUEUE_IMPL_NEW}" V29_SPECIALS "${V29_SPECIALS}")

set(V29_AUTOSAVE_EXTERN_OLD [=[void run_special(pending_special_type spec, short* a, short* b, bool* redraw) {
	unsigned long store_time = univ.party.age;
	univ.party.age = spec.trigger_time;
	run_special(spec.mode, spec.type, spec.spec, spec.where, a, b, redraw);
	univ.party.age = std::max(univ.party.age, store_time);
}

// This is the big painful one, the main special engine entry point]=])
set(V29_AUTOSAVE_EXTERN_NEW [=[void run_special(pending_special_type spec, short* a, short* b, bool* redraw) {
	unsigned long store_time = univ.party.age;
	univ.party.age = spec.trigger_time;
	run_special(spec.mode, spec.type, spec.spec, spec.where, a, b, redraw);
	univ.party.age = std::max(univ.party.age, store_time);
}

extern bool need_enter_town_autosave;

// This is the big painful one, the main special engine entry point]=])
string(FIND "${V29_SPECIALS}" "${V29_AUTOSAVE_EXTERN_OLD}" V29_AUTOSAVE_EXTERN_POS)
if(V29_AUTOSAVE_EXTERN_POS EQUAL -1)
    message(FATAL_ERROR "v29: expected pending-special wrapper anchor not found")
endif()
string(REPLACE "${V29_AUTOSAVE_EXTERN_OLD}" "${V29_AUTOSAVE_EXTERN_NEW}" V29_SPECIALS "${V29_SPECIALS}")

set(V29_SPECIAL_END_OLD [=[	special_in_progress = false;
	
	// TODO: Should find a way to do this that doesn't risk stack overflow]=])
set(V29_SPECIAL_END_NEW [=[	special_in_progress = false;
	if(which_mode == eSpecCtx::ENTER_TOWN && need_enter_town_autosave){
		try_auto_save("EnterTown");
		need_enter_town_autosave = false;
	}
	
	// TODO: Should find a way to do this that doesn't risk stack overflow]=])
string(FIND "${V29_SPECIALS}" "${V29_SPECIAL_END_OLD}" V29_SPECIAL_END_POS)
if(V29_SPECIAL_END_POS EQUAL -1)
    message(FATAL_ERROR "v29: expected run_special completion anchor not found")
endif()
string(REPLACE "${V29_SPECIAL_END_OLD}" "${V29_SPECIAL_END_NEW}" V29_SPECIALS "${V29_SPECIALS}")
file(WRITE "${V29_SPECIALS_CPP}" "${V29_SPECIALS}")

# Town entry can now remember whether its entry node was queued.
file(READ "${V29_TOWN_HPP}" V29_THPP)
set(V29_TOWN_DECL_OLD [=[void handle_town_specials(short town_number, bool town_dead,location start_loc) ;]=])
set(V29_TOWN_DECL_NEW [=[bool handle_town_specials(short town_number, bool town_dead,location start_loc) ;]=])
string(FIND "${V29_THPP}" "${V29_TOWN_DECL_OLD}" V29_TOWN_DECL_POS)
if(V29_TOWN_DECL_POS EQUAL -1)
    message(FATAL_ERROR "v29: expected handle_town_specials declaration not found")
endif()
string(REPLACE "${V29_TOWN_DECL_OLD}" "${V29_TOWN_DECL_NEW}" V29_THPP "${V29_THPP}")
file(WRITE "${V29_TOWN_HPP}" "${V29_THPP}")

file(READ "${V29_TOWN_CPP}" V29_TOWN)
set(V29_PENDING_FLAG_OLD [=[void force_town_enter(short which_town,location where_start) {
	town_force = which_town;
	town_force_loc = where_start;
}

//short entry_dir; // if 9, go to forced]=])
set(V29_PENDING_FLAG_NEW [=[void force_town_enter(short which_town,location where_start) {
	town_force = which_town;
	town_force_loc = where_start;
}

bool need_enter_town_autosave = false;

//short entry_dir; // if 9, go to forced]=])
string(FIND "${V29_TOWN}" "${V29_PENDING_FLAG_OLD}" V29_PENDING_FLAG_POS)
if(V29_PENDING_FLAG_POS EQUAL -1)
    message(FATAL_ERROR "v29: expected force_town_enter anchor not found")
endif()
string(REPLACE "${V29_PENDING_FLAG_OLD}" "${V29_PENDING_FLAG_NEW}" V29_TOWN "${V29_TOWN}")

set(V29_ENTRY_QUEUE_OLD [=[	if(!debug_enter)
		handle_town_specials(town_number, (short) town_toast,(entry_dir < 9) ? univ.town->start_locs[entry_dir] : town_force_loc);]=])
set(V29_ENTRY_QUEUE_NEW [=[	bool specials_queued = false;
	if(!debug_enter)
		specials_queued = handle_town_specials(town_number, (short) town_toast,(entry_dir < 9) ? univ.town->start_locs[entry_dir] : town_force_loc);]=])
string(FIND "${V29_TOWN}" "${V29_ENTRY_QUEUE_OLD}" V29_ENTRY_QUEUE_POS)
if(V29_ENTRY_QUEUE_POS EQUAL -1)
    message(FATAL_ERROR "v29: expected town-entry special queue call not found")
endif()
string(REPLACE "${V29_ENTRY_QUEUE_OLD}" "${V29_ENTRY_QUEUE_NEW}" V29_TOWN "${V29_TOWN}")

set(V29_ENTRY_SAVE_OLD [=[	draw_terrain(1);

	try_auto_save("EnterTown");
}]=])
set(V29_ENTRY_SAVE_NEW [=[	draw_terrain(1);

	// If special nodes still need to be called, we can't do the autosave yet.
	if(specials_queued) need_enter_town_autosave = true;
	else try_auto_save("EnterTown");
}]=])
string(FIND "${V29_TOWN}" "${V29_ENTRY_SAVE_OLD}" V29_ENTRY_SAVE_POS)
if(V29_ENTRY_SAVE_POS EQUAL -1)
    message(FATAL_ERROR "v29: expected immediate EnterTown autosave anchor not found")
endif()
string(REPLACE "${V29_ENTRY_SAVE_OLD}" "${V29_ENTRY_SAVE_NEW}" V29_TOWN "${V29_TOWN}")

set(V29_TOWN_IMPL_OLD [=[void handle_town_specials(short /*town_number*/, bool town_dead,location /*start_loc*/) {
	queue_special(eSpecCtx::ENTER_TOWN, eSpecCtxType::TOWN, town_dead ? univ.town->spec_on_entry_if_dead : univ.town->spec_on_entry, univ.party.town_loc);
}]=])
set(V29_TOWN_IMPL_NEW [=[bool handle_town_specials(short /*town_number*/, bool town_dead,location /*start_loc*/) {
	return queue_special(eSpecCtx::ENTER_TOWN, eSpecCtxType::TOWN, town_dead ? univ.town->spec_on_entry_if_dead : univ.town->spec_on_entry, univ.party.town_loc);
}]=])
string(FIND "${V29_TOWN}" "${V29_TOWN_IMPL_OLD}" V29_TOWN_IMPL_POS)
if(V29_TOWN_IMPL_POS EQUAL -1)
    message(FATAL_ERROR "v29: expected handle_town_specials implementation not found")
endif()
string(REPLACE "${V29_TOWN_IMPL_OLD}" "${V29_TOWN_IMPL_NEW}" V29_TOWN "${V29_TOWN}")
file(WRITE "${V29_TOWN_CPP}" "${V29_TOWN}")

message(STATUS "Applied Codeberg deferred EnterTown autosave ordering fix")
