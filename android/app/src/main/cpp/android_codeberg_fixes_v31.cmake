# Codeberg migration v31: normalize quoted scenario/party names for alphabetical
# scenario-list grouping. Some party/scenario makers prefix the scenario name
# with a quote; Codeberg strips that quote before applying A/The sorting rules.
if(DEFINED CBOE_ANDROID_CODEBERG_V31_APPLIED)
    return()
endif()
set(CBOE_ANDROID_CODEBERG_V31_APPLIED TRUE CACHE INTERNAL "" FORCE)

get_filename_component(CBOE_ANDROID_V31_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../.." ABSOLUTE)
set(V31_FILEIO_CPP "${CBOE_ANDROID_V31_ROOT}/src/game/boe.fileio.cpp")
file(READ "${V31_FILEIO_CPP}" V31_FILEIO)

set(V31_NAME_OLD [=[	boost::algorithm::trim_left(a);
	std::transform(a.begin(), a.end(), a.begin(), tolower);
	if(a.substr(0,2) == "a ") a.erase(a.begin(), a.begin() + 2);]=])
set(V31_NAME_NEW [=[	boost::algorithm::trim_left(a);
	std::transform(a.begin(), a.end(), a.begin(), tolower);
	// Some party makers start with the name of the corresponding scenario in quotes
	if(a.substr(0,1) == "\"") a.erase(a.begin(), a.begin() + 1);
	if(a.substr(0,2) == "a ") a.erase(a.begin(), a.begin() + 2);]=])

string(FIND "${V31_FILEIO}" "${V31_NAME_OLD}" V31_NAME_POS)
if(V31_NAME_POS EQUAL -1)
    message(FATAL_ERROR "v31: expected scenario-name normalization anchor not found")
endif()
string(REPLACE "${V31_NAME_OLD}" "${V31_NAME_NEW}" V31_FILEIO "${V31_FILEIO}")
file(WRITE "${V31_FILEIO_CPP}" "${V31_FILEIO}")

message(STATUS "Applied Codeberg quoted scenario-name sorting compatibility")
