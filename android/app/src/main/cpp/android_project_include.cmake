# Android project-include wrapper.
#
# The main compatibility patch converts OpenBoE's desktop modal windows into
# overlays inside the NativeActivity RenderWindow.  Once those auxiliary
# RenderWindows are gone, SFML's stock Android lifecycle ownership is the safest
# behavior: the real window context must always replace ActivityStates::context
# when it is constructed.  Build #51 tried pinning the first context instead;
# emulator diagnostics showed intermittent startup loss and repeated
# "Failed to activate the window's context" messages after resume.

include("${CMAKE_CURRENT_LIST_DIR}/android_source_patches.cmake")

# Add a runtime marker after android_source_patches.cmake has transformed
# cDialog::run().  CI uses this to prove a title-screen tap progressed into a
# real modal dialog rather than merely drawing the blue pressed button state.
set(CBOE_ANDROID_DIALOG_CPP "${CBOE_ANDROID_ROOT}/src/dialogxml/dialogs/dialog.cpp")
file(READ "${CBOE_ANDROID_DIALOG_CPP}" CBOE_ANDROID_DIALOG_SOURCE)

set(CBOE_ANDROID_DIALOG_LOG_INCLUDE_OLD "#include <boost/lexical_cast.hpp>")
set(CBOE_ANDROID_DIALOG_LOG_INCLUDE_NEW "#include <boost/lexical_cast.hpp>\n#include <android/log.h>")
string(FIND "${CBOE_ANDROID_DIALOG_SOURCE}" "${CBOE_ANDROID_DIALOG_LOG_INCLUDE_OLD}" CBOE_ANDROID_DIALOG_LOG_INCLUDE_POS)
if(CBOE_ANDROID_DIALOG_LOG_INCLUDE_POS EQUAL -1)
    message(FATAL_ERROR "Expected dialog Android log include anchor was not found")
endif()
string(REPLACE "${CBOE_ANDROID_DIALOG_LOG_INCLUDE_OLD}" "${CBOE_ANDROID_DIALOG_LOG_INCLUDE_NEW}" CBOE_ANDROID_DIALOG_SOURCE "${CBOE_ANDROID_DIALOG_SOURCE}")

set(CBOE_ANDROID_DIALOG_OPEN_OLD [=[#ifdef __ANDROID__
	// Android has exactly one NativeActivity window. Draw this modal into the
	// main RenderWindow instead of creating a second SFML window/context.
	animTimer.restart();]=])
set(CBOE_ANDROID_DIALOG_OPEN_NEW [=[#ifdef __ANDROID__
	// Android has exactly one NativeActivity window. Draw this modal into the
	// main RenderWindow instead of creating a second SFML window/context.
	__android_log_print(ANDROID_LOG_INFO, "OpenBoEAndroid", "DIALOG_OPEN %s", fname.c_str());
	animTimer.restart();]=])
string(FIND "${CBOE_ANDROID_DIALOG_SOURCE}" "${CBOE_ANDROID_DIALOG_OPEN_OLD}" CBOE_ANDROID_DIALOG_OPEN_POS)
if(CBOE_ANDROID_DIALOG_OPEN_POS EQUAL -1)
    message(FATAL_ERROR "Expected transformed Android cDialog::run block was not found")
endif()
string(REPLACE "${CBOE_ANDROID_DIALOG_OPEN_OLD}" "${CBOE_ANDROID_DIALOG_OPEN_NEW}" CBOE_ANDROID_DIALOG_SOURCE "${CBOE_ANDROID_DIALOG_SOURCE}")
file(WRITE "${CBOE_ANDROID_DIALOG_CPP}" "${CBOE_ANDROID_DIALOG_SOURCE}")
message(STATUS "Added Android inline-dialog runtime marker")

# android_source_patches.cmake schedules its SFML EglContext experiment with a
# deferred call. Schedule this restoration after it. CMake executes deferred
# calls in insertion order, so this runs after the experimental patch and puts
# SFML's lifecycle assignment/destructor semantics back to stock 2.6.2 while
# retaining the single-window dialog and minimap changes.
function(cboe_restore_sfml_android_lifecycle_context)
    FetchContent_GetProperties(SFML)
    if(NOT sfml_POPULATED OR NOT EXISTS "${sfml_SOURCE_DIR}/src/SFML/Window/EglContext.cpp")
        message(FATAL_ERROR "SFML source was not populated before Android lifecycle restoration")
    endif()

    set(SFML_EGL_CPP "${sfml_SOURCE_DIR}/src/SFML/Window/EglContext.cpp")
    file(READ "${SFML_EGL_CPP}" SFML_EGL_SOURCE)

    set(SFML_PINNED_CONTEXT_OLD [=[    // NativeActivity has one real window. Auxiliary SFML contexts must not
    // steal lifecycle surface recreation from the main RenderWindow.
    if (!states.context)
        states.context = this;]=])
    set(SFML_PINNED_CONTEXT_NEW [=[    states.context = this;]=])
    string(FIND "${SFML_EGL_SOURCE}" "${SFML_PINNED_CONTEXT_OLD}" SFML_PINNED_CONTEXT_POS)
    if(SFML_PINNED_CONTEXT_POS EQUAL -1)
        message(FATAL_ERROR "Expected experimental SFML lifecycle ownership patch was not found")
    endif()
    string(REPLACE "${SFML_PINNED_CONTEXT_OLD}" "${SFML_PINNED_CONTEXT_NEW}" SFML_EGL_SOURCE "${SFML_EGL_SOURCE}")

    set(SFML_CONTEXT_DTOR_PATCH_OLD [=[EglContext::~EglContext()
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
    set(SFML_CONTEXT_DTOR_PATCH_NEW [=[EglContext::~EglContext()
{
    // Notify unshared OpenGL resources of context destruction]=])
    string(FIND "${SFML_EGL_SOURCE}" "${SFML_CONTEXT_DTOR_PATCH_OLD}" SFML_CONTEXT_DTOR_PATCH_POS)
    if(SFML_CONTEXT_DTOR_PATCH_POS EQUAL -1)
        message(FATAL_ERROR "Expected experimental SFML lifecycle destructor patch was not found")
    endif()
    string(REPLACE "${SFML_CONTEXT_DTOR_PATCH_OLD}" "${SFML_CONTEXT_DTOR_PATCH_NEW}" SFML_EGL_SOURCE "${SFML_EGL_SOURCE}")

    file(WRITE "${SFML_EGL_CPP}" "${SFML_EGL_SOURCE}")
    message(STATUS "Restored stock SFML Android EGL lifecycle ownership after single-window conversion")
endfunction()

cmake_language(DEFER CALL cboe_restore_sfml_android_lifecycle_context)
