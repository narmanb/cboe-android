#include <SFML/System/Android/Activity.hpp>

#include <android/asset_manager.h>
#include <android/log.h>
#include <sys/stat.h>
#include <unistd.h>

#include <cerrno>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>

extern int cboe_portable_main(int argc, char* argv[]);

namespace {

constexpr const char* LOG_TAG = "OpenBoE";

void ensure_dir(const std::string& path) {
    if (::mkdir(path.c_str(), 0700) != 0 && errno != EEXIST) {
        __android_log_print(ANDROID_LOG_ERROR, LOG_TAG,
                            "mkdir failed for %s (errno %d)", path.c_str(), errno);
    }
}

void ensure_dir_recursive(const std::string& path) {
    if (path.empty())
        return;

    std::size_t pos = 1;
    while ((pos = path.find('/', pos)) != std::string::npos) {
        ensure_dir(path.substr(0, pos));
        ++pos;
    }
    ensure_dir(path);
}

bool copy_asset_file(AAssetManager* manager,
                     const std::string& asset_path,
                     const std::string& dest_path) {
    AAsset* asset = AAssetManager_open(manager, asset_path.c_str(), AASSET_MODE_STREAMING);
    if (!asset) {
        __android_log_print(ANDROID_LOG_ERROR, LOG_TAG,
                            "Could not open asset %s", asset_path.c_str());
        return false;
    }

    const std::size_t slash = dest_path.find_last_of('/');
    if (slash != std::string::npos)
        ensure_dir_recursive(dest_path.substr(0, slash));

    std::ofstream out(dest_path, std::ios::binary | std::ios::trunc);
    if (!out) {
        __android_log_print(ANDROID_LOG_ERROR, LOG_TAG,
                            "Could not create %s", dest_path.c_str());
        AAsset_close(asset);
        return false;
    }

    char buffer[64 * 1024];
    int read_count = 0;
    bool ok = true;
    while ((read_count = AAsset_read(asset, buffer, sizeof(buffer))) > 0) {
        out.write(buffer, read_count);
        if (!out) {
            ok = false;
            break;
        }
    }
    if (read_count < 0)
        ok = false;

    out.close();
    AAsset_close(asset);

    if (!ok) {
        __android_log_print(ANDROID_LOG_ERROR, LOG_TAG,
                            "Failed while copying %s to %s",
                            asset_path.c_str(), dest_path.c_str());
    }
    return ok;
}

bool copy_regular_file(const std::string& source_path,
                       const std::string& dest_path) {
    std::ifstream in(source_path, std::ios::binary);
    if (!in) {
        __android_log_print(ANDROID_LOG_ERROR, LOG_TAG,
                            "Could not open staged file %s", source_path.c_str());
        return false;
    }

    const std::size_t slash = dest_path.find_last_of('/');
    if (slash != std::string::npos)
        ensure_dir_recursive(dest_path.substr(0, slash));

    std::ofstream out(dest_path, std::ios::binary | std::ios::trunc);
    if (!out) {
        __android_log_print(ANDROID_LOG_ERROR, LOG_TAG,
                            "Could not create %s", dest_path.c_str());
        return false;
    }

    out << in.rdbuf();
    out.close();
    return in.good() || in.eof() ? static_cast<bool>(out) : false;
}

// Android's directory-enumeration behavior for packaged assets can vary with
// the way AGP packs/compresses them. The build writes an explicit list of every
// bundled data file, so stage from that list using exact AAsset paths instead
// of depending on AAssetManager_openDir() returning every filename.
bool stage_assets(AAssetManager* manager, const std::string& root) {
    constexpr const char* manifest_path = "data/assets-manifest.txt";
    AAsset* manifest_asset = AAssetManager_open(manager, manifest_path, AASSET_MODE_BUFFER);
    if (!manifest_asset) {
        __android_log_print(ANDROID_LOG_ERROR, LOG_TAG,
                            "Could not open asset manifest %s", manifest_path);
        return false;
    }

    const off_t manifest_size = AAsset_getLength(manifest_asset);
    std::string manifest(static_cast<std::size_t>(manifest_size), '\0');
    const int bytes_read = AAsset_read(manifest_asset, manifest.data(), manifest.size());
    AAsset_close(manifest_asset);

    if (bytes_read < 0 || static_cast<std::size_t>(bytes_read) != manifest.size()) {
        __android_log_print(ANDROID_LOG_ERROR, LOG_TAG,
                            "Could not read complete asset manifest");
        return false;
    }

    std::istringstream lines(manifest);
    std::string asset_path;
    int copied = 0;
    int failed = 0;
    while (std::getline(lines, asset_path)) {
        if (!asset_path.empty() && asset_path.back() == '\r')
            asset_path.pop_back();
        if (asset_path.empty() || asset_path == manifest_path)
            continue;

        const std::string dest_path = root + "/" + asset_path;
        if (copy_asset_file(manager, asset_path, dest_path))
            ++copied;
        else
            ++failed;
    }

    __android_log_print(failed == 0 ? ANDROID_LOG_INFO : ANDROID_LOG_ERROR,
                        LOG_TAG, "Staged %d game assets (%d failed)", copied, failed);
    return copied > 0 && failed == 0;
}

// The three original/core scenarios are special-cased by OpenBoE's loader: it
// looks for them under progDir/"Blades of Exile Scenarios" rather than the
// normal custom-scenario directory. Android's progDir is the app's internal
// data root, so install those three there. Busywork remains a custom scenario
// and belongs in $HOME/.config/openboe/blades/Scenarios.
bool install_stock_scenarios(const std::string& root) {
    static const char* const scenario_names[] = {
        "busywork",
        "stealth",
        "valleydy",
        "zakhazi"
    };

    const std::string custom_scenario_dir = root + "/.config/openboe/blades/Scenarios";
    const std::string core_scenario_dir = root + "/Blades of Exile Scenarios";
    ensure_dir_recursive(custom_scenario_dir);
    ensure_dir_recursive(core_scenario_dir);

    int installed = 0;
    int present = 0;
    for (const char* scenario_name : scenario_names) {
        const std::string name(scenario_name);
        const std::string filename = name + ".boes";
        const std::string source_path = root + "/data/stock-scenarios/" + filename;
        const bool is_core = name == "stealth" || name == "valleydy" || name == "zakhazi";
        const std::string& dest_dir = is_core ? core_scenario_dir : custom_scenario_dir;
        const std::string dest_path = dest_dir + "/" + filename;

        struct stat source_stat {};
        if (::stat(source_path.c_str(), &source_stat) != 0 || source_stat.st_size <= 0) {
            __android_log_print(ANDROID_LOG_ERROR, LOG_TAG,
                                "Bundled stock scenario missing: %s", source_path.c_str());
            return false;
        }

        struct stat dest_stat {};
        if (::stat(dest_path.c_str(), &dest_stat) == 0 && dest_stat.st_size > 0) {
            ++present;
            continue;
        }

        if (!copy_regular_file(source_path, dest_path)) {
            __android_log_print(ANDROID_LOG_ERROR, LOG_TAG,
                                "Could not install stock scenario %s", filename.c_str());
            return false;
        }

        struct stat installed_stat {};
        if (::stat(dest_path.c_str(), &installed_stat) != 0 || installed_stat.st_size <= 0) {
            __android_log_print(ANDROID_LOG_ERROR, LOG_TAG,
                                "Installed stock scenario is invalid: %s", dest_path.c_str());
            return false;
        }
        ++installed;
    }

    __android_log_print(ANDROID_LOG_INFO, LOG_TAG,
                        "Stock scenarios ready: %d installed, %d already present",
                        installed, present);
    return true;
}

} // namespace

// SFML's Android bootstrap deliberately calls main(0, nullptr). The desktop
// OpenBoE startup code expects argv[0] to be a real executable path, so this
// Android wrapper supplies one and stages the packaged game data into normal
// filesystem storage before entering the unchanged portable game main().
int main(int, char**) {
    sf::priv::ActivityStates& states = sf::priv::getActivity();
    ANativeActivity* activity = states.activity;

    if (!activity || !activity->internalDataPath || !activity->assetManager) {
        __android_log_print(ANDROID_LOG_ERROR, LOG_TAG,
                            "Android activity/data path/asset manager unavailable");
        return 1;
    }

    const std::string root(activity->internalDataPath);

    // The existing POSIX directory code uses HOME for save/config storage.
    ::setenv("HOME", root.c_str(), 1);
    ::chdir(root.c_str());

    if (!stage_assets(activity->assetManager, root)) {
        __android_log_print(ANDROID_LOG_ERROR, LOG_TAG,
                            "Game resource staging failed; refusing to start");
        return 2;
    }

    if (!install_stock_scenarios(root)) {
        __android_log_print(ANDROID_LOG_ERROR, LOG_TAG,
                            "Stock scenario installation failed; refusing to start");
        return 3;
    }

    // Verify the first font that OpenBoE requests before handing control to the
    // game. This makes a packaging/staging regression explicit in logcat rather
    // than surfacing later as an uncaught ResMgr exception.
    const std::string bold_font = root + "/data/fonts/bold.ttf";
    struct stat font_stat {};
    if (::stat(bold_font.c_str(), &font_stat) != 0 || font_stat.st_size <= 0) {
        __android_log_print(ANDROID_LOG_ERROR, LOG_TAG,
                            "Required staged font missing: %s", bold_font.c_str());
        return 4;
    }
    __android_log_print(ANDROID_LOG_INFO, LOG_TAG,
                        "Verified staged font %s (%lld bytes)", bold_font.c_str(),
                        static_cast<long long>(font_stat.st_size));

    // init_directories() canonicalizes argv[0] and then uses its parent as the
    // program directory. A tiny marker file gives it a valid Android-local path.
    std::string executable_path = root + "/cboe";
    {
        std::ofstream marker(executable_path, std::ios::app);
    }

    char* argv[] = {executable_path.data(), nullptr};
    return cboe_portable_main(1, argv);
}
