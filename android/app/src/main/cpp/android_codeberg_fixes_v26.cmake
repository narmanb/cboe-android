# Android Codeberg migration v26: clear stale legacy scenario names for parties
# whose old save header says they are not currently inside a scenario.
# Codeberg's full file also expects max_dim(), so port only this safety fix here.
if(DEFINED CBOE_ANDROID_CODEBERG_V26_APPLIED)
    return()
endif()
set(CBOE_ANDROID_CODEBERG_V26_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_V26_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(CBOE_ANDROID_V26_FILEIO_PARTY "${CBOE_ANDROID_V26_ROOT}/src/fileio/fileio_party.cpp")
file(READ "${CBOE_ANDROID_V26_FILEIO_PARTY}" V26_PARTY_IO)

set(V26_OLD [=[	}else{
		univ.party.scen_name = "";
	}
	
	univ.party.import_legacy(store_party, univ);]=])
set(V26_NEW [=[	}else{
		univ.party.scen_name = "";
		// import_legacy() copies scen_name from the legacy structure, so clear
		// that source too or stale bytes can put an out-of-scenario party back
		// into a scenario it is no longer actually in.
		store_party.scen_name[0] = '\0';
	}
	
	univ.party.import_legacy(store_party, univ);]=])

string(FIND "${V26_PARTY_IO}" "${V26_OLD}" V26_POS)
if(V26_POS EQUAL -1)
    message(FATAL_ERROR "v26: expected legacy scenario-name import anchor not found")
endif()
string(REPLACE "${V26_OLD}" "${V26_NEW}" V26_PARTY_IO "${V26_PARTY_IO}")
file(WRITE "${CBOE_ANDROID_V26_FILEIO_PARTY}" "${V26_PARTY_IO}")
message(STATUS "Applied Codeberg legacy party scenario-name safety fix")
