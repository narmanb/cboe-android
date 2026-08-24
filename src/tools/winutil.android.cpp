#include "winutil.hpp"

#include <SFML/Graphics/Image.hpp>
#include <SFML/Graphics/RenderWindow.hpp>
#include <sstream>
#include <sys/utsname.h>

extern void play_sound(snd_num_t which, sf::Time delay = sf::Time(), bool force = false);

// Kept equivalent to the Linux implementation for physical keyboards and
// controller keyboard mappings. Touch text entry can be added separately once
// the native build is running.
char keyToChar(sf::Keyboard::Key key, bool isShift) {
    using kb = sf::Keyboard;
    switch(key) {
        case kb::A: return isShift ? 'A' : 'a';
        case kb::B: return isShift ? 'B' : 'b';
        case kb::C: return isShift ? 'C' : 'c';
        case kb::D: return isShift ? 'D' : 'd';
        case kb::E: return isShift ? 'E' : 'e';
        case kb::F: return isShift ? 'F' : 'f';
        case kb::G: return isShift ? 'G' : 'g';
        case kb::H: return isShift ? 'H' : 'h';
        case kb::I: return isShift ? 'I' : 'i';
        case kb::J: return isShift ? 'J' : 'j';
        case kb::K: return isShift ? 'K' : 'k';
        case kb::L: return isShift ? 'L' : 'l';
        case kb::M: return isShift ? 'M' : 'm';
        case kb::N: return isShift ? 'N' : 'n';
        case kb::O: return isShift ? 'O' : 'o';
        case kb::P: return isShift ? 'P' : 'p';
        case kb::Q: return isShift ? 'Q' : 'q';
        case kb::R: return isShift ? 'R' : 'r';
        case kb::S: return isShift ? 'S' : 's';
        case kb::T: return isShift ? 'T' : 't';
        case kb::U: return isShift ? 'U' : 'u';
        case kb::V: return isShift ? 'V' : 'v';
        case kb::W: return isShift ? 'W' : 'w';
        case kb::X: return isShift ? 'X' : 'x';
        case kb::Y: return isShift ? 'Y' : 'y';
        case kb::Z: return isShift ? 'Z' : 'z';
        case kb::Num1: return isShift ? '!' : '1';
        case kb::Num2: return isShift ? '@' : '2';
        case kb::Num3: return isShift ? '#' : '3';
        case kb::Num4: return isShift ? '$' : '4';
        case kb::Num5: return isShift ? '%' : '5';
        case kb::Num6: return isShift ? '^' : '6';
        case kb::Num7: return isShift ? '&' : '7';
        case kb::Num8: return isShift ? '*' : '8';
        case kb::Num9: return isShift ? '(' : '9';
        case kb::Num0: return isShift ? ')' : '0';
        case kb::Tilde: return isShift ? '~' : '`';
        case kb::Dash: return isShift ? '_' : '-';
        case kb::Equal: return isShift ? '+' : '=';
        case kb::LBracket: return isShift ? '{' : '[';
        case kb::RBracket: return isShift ? '}' : ']';
        case kb::SemiColon: return isShift ? ':' : ';';
        case kb::Quote: return isShift ? '"' : '\'';
        case kb::Comma: return isShift ? '<' : ',';
        case kb::Period: return isShift ? '>' : '.';
        case kb::Slash: return isShift ? '?' : '/';
        case kb::BackSlash: return isShift ? '|' : '\\';
        case kb::Tab: return '\t';
        case kb::Space: return ' ';
        case kb::Return: return '\n';
        case kb::BackSpace: return '\b';
        case kb::Delete: return '\x7f';
        default: break;
    }
    return 0;
}

std::string get_os_version() {
    struct utsname details {};
    if(uname(&details) != 0)
        return "Android";

    std::ostringstream version;
    version << "Android (" << details.release << ")";
    return version.str();
}

void _makeFrontWindow(sf::Window&) {
}

void _setWindowFloating(sf::Window&, bool) {
}

void init_fileio() {
    // Android's Storage Access Framework will replace the desktop native file
    // dialogs. Returning from here allows the engine to start meanwhile.
}

fs::path nav_get_party() {
    return {};
}

fs::path nav_put_party(fs::path) {
    return {};
}

fs::path nav_get_scenario() {
    return {};
}

fs::path nav_put_scenario(fs::path) {
    return {};
}

fs::path nav_get_rsrc(std::initializer_list<std::string>) {
    return {};
}

fs::path nav_put_rsrc(std::initializer_list<std::string>, fs::path) {
    return {};
}

void set_clipboard(std::string) {
}

std::string get_clipboard() {
    return {};
}

void set_clipboard_img(sf::Image&) {
}

std::unique_ptr<sf::Image> get_clipboard_img() {
    return nullptr;
}

void beep() {
    play_sound(1);
}

void launchURL(std::string) {
    // TODO: launch ACTION_VIEW through JNI.
}

void preprocess_args(int&, char*[]) {
}

void ModalSession::pumpEvents() {
}

ModalSession::ModalSession(sf::Window&, sf::Window& p) : session(nullptr), parent(&p) {
}

ModalSession::~ModalSession() {
}

int getMenubarHeight() {
    // The Linux-style TGUI menubar is drawn inside the game window on Android.
    return 20;
}

void adjust_window_for_menubar(int, unsigned int, unsigned int) {
}
