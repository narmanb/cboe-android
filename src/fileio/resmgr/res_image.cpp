/*
 *  restypes.h
 *  BoE
 *
 *  Created by Celtic Minstrel on 10-08-25.
 *
 */

#include "res_image.hpp"

#ifdef __ANDROID__
static std::string android_asset_name(const fs::path& fpath) {
	// SFML's Android Texture/Image file loaders use AAssetManager. The core
	// resources are mirrored into internal storage for Boost filesystem
	// discovery, but SFML must receive their APK asset name.
	const std::string path = fpath.generic_string();
	const std::string marker = "/files/data/";
	const std::string::size_type pos = path.find(marker);
	if(pos != std::string::npos)
		return "data/" + path.substr(pos + marker.size());
	return path;
}
#endif

class ImageLoader : public ResMgr::cLoader<sf::Texture> {
	/// Load an image from a PNG file.
	sf::Texture* operator() (const fs::path& fpath) const override {
		sf::Texture* img = new sf::Texture();
#ifdef __ANDROID__
		if(img->loadFromFile(android_asset_name(fpath))) return img;
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
