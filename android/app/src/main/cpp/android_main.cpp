#include <SFML/System/Android/Activity.hpp>

#include <android/asset_manager.h>
#include <android/log.h>
#include <sys/stat.h>
#include <unistd.h>

#include <cerrno>
#include <cstdlib>
#include <fstream>
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

void copy_asset_dir(AAssetManager* manager,
                    const std::string& asset_dir,
                    const std::string& dest_dir) {
    ensure_dir(dest_dir);

    AAssetDir* dir = AAssetManager_openDir(manager, asset_dir.c_str());
    if (!dir) {
        __android_log_print(ANDROID_LOG_ERROR, LOG_TAG,
                            "Could not open asset directory %s", asset_dir.c_str());
        return;
    }

    while (const char* filename = AAssetDir_getNextFileName(dir)) {
        const std::string asset_path = asset_dir + "/" + filename;
        const std::string dest_path = dest_dir + "/" + filename;

        AAsset* asset = AAssetManager_open(manager, asset_path.c_str(), AASSET_MODE_STREAMING);
        if (!asset) {
            __android_log_print(ANDROID_LOG_ERROR, LOG_TAG,
                                "Could not open asset %s", asset_path.c_str());
            continue;
        }

        std::ofstream out(dest_path, std::ios::binary | std::ios::trunc);
        if (!out) {
            __android_log_print(ANDROID_LOG_ERROR, LOG_TAG,
                                "Could not create %s", dest_path.c_str());
            AAsset_close(asset);
            continue;
        }

        char buffer[64 * 1024];
        int read_count = 0;
        while ((read_count = AAsset_read(asset, buffer, sizeof(buffer))) > 0)
            out.write(buffer, read_count);

        AAsset_close(asset);
    }

    AAssetDir_close(dir);
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
    const std::string data_dir = root + "/data";

    // The existing POSIX directory code uses HOME for save/config storage.
    ::setenv("HOME", root.c_str(), 1);
    ::chdir(root.c_str());

    ensure_dir(data_dir);
    copy_asset_dir(activity->assetManager, "data/cursors",  data_dir + "/cursors");
    copy_asset_dir(activity->assetManager, "data/dialogs",  data_dir + "/dialogs");
    copy_asset_dir(activity->assetManager, "data/fonts",    data_dir + "/fonts");
    copy_asset_dir(activity->assetManager, "data/graphics", data_dir + "/graphics");
    copy_asset_dir(activity->assetManager, "data/sounds",   data_dir + "/sounds");
    copy_asset_dir(activity->assetManager, "data/strings",  data_dir + "/strings");
    copy_asset_dir(activity->assetManager, "data/shaders",  data_dir + "/shaders");

    // init_directories() canonicalizes argv[0] and then uses its parent as the
    // program directory. A tiny marker file gives it a valid Android-local path.
    std::string executable_path = root + "/cboe";
    {
        std::ofstream marker(executable_path, std::ios::app);
    }

    char* argv[] = {executable_path.data(), nullptr};
    return cboe_portable_main(1, argv);
}
