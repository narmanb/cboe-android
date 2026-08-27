# Android project include wrapper for the mobile gameplay UI pass.
# Keep the existing compatibility/lifecycle patches, then apply the current
# Android layout/input fixes once to OpenBoE's source before it is compiled.
include("${CMAKE_CURRENT_LIST_DIR}/android_project_include.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/android_mobile_ui_fixes.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/android_mobile_ui_fixes_v3.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/android_mobile_ui_fixes_v4.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/android_mobile_ui_fixes_v5.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/android_mobile_ui_fixes_v5_compilefix.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/android_mobile_ui_fixes_v6.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/android_mobile_ui_fixes_v7.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/android_mobile_ui_fixes_v8.cmake")