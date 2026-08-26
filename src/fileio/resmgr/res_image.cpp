/*
 *  restypes.h
 *  BoE
 *
 *  Created by Celtic Minstrel on 10-08-25.
 *
 */

#include "res_image.hpp"

#ifdef __ANDROID__
#include <fstream>
#include <vector>

static bool android_asset_name(const fs::path& fpath, std::string& asset_name) {
	// SFML's Android Texture/Image file loaders use AAssetManager when given a
	// filename. Core resources live in the APK, so translate their mirrored
	// internal-storage path back to an APK asset name. Runtime scenario graphics,
	// however, are extracted/imported into normal app-private filesystem paths;
	// those must be read as bytes and passed to loadFromMemory instead.
	const std::string path = fpath.generic_string();
	const std::string marker = "/files/data/";
	const std::string::size_type pos = path.find(marker);
	if(pos == std::string::npos)
		return false;
	asset_name = "data/" + path.substr(pos + marker.size());
	return true;
}

static bool load_android_texture(sf::Texture& texture, const fs::path& fpath) {
	std::string asset_name;
	if(android_asset_name(fpath, asset_name))
		return texture.loadFromFile(asset_name);

	std::ifstream in(fpath.string(), std::ios::binary);
	if(!in)
		return false;
	std::vector<char> bytes((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
	if(bytes.empty())
		return false;
	return texture.loadFromMemory(bytes.data(), bytes.size());
}
#endif

class ImageLoader : public ResMgr::cLoader<sf::Texture> {
	/// Load an image from a PNG file.
	sf::Texture* operator() (const fs::path& fpath) const override {
		sf::Texture* img = new sf::Texture();
#ifdef __ANDROID__
		if(load_android_texture(*img, fpath)) return img;
#else
		if(img->loadFromFile(fpath.string())) return img;
#endif
		delete img;
		throw ResMgr::xError(ResMgr::ERR_LOAD, "Failed to load PNG image: " + fpath.string());
	}

	ResourceList expand(const std::string& name) const override {
		return {name + ".png", name + ".bmp"};
	}

	std::string typeName() const override {
		return "image";
	}
};

// TODO: What's a good max texture count?
static ImageLoader loader;
ResMgr::cPool<sf::Texture> ResMgr::graphics(loader, 50);
