#include "cursors.hpp"

// Android is touch-first, so the desktop mouse cursor layer has no visible
// cursor to manipulate. Keep the cursor state for game logic, but make the OS
// operations no-ops.
Cursor::Cursor(fs::path, float, float) : ptr(nullptr) {
}

Cursor::~Cursor() {
}

void Cursor::apply() {
}

void obscureCursor() {
}

void set_cursor(cursor_type which_c) {
    if(which_c != watch_curs)
        Cursor::current = which_c;
}

void restore_cursor() {
    set_cursor(Cursor::current);
}
