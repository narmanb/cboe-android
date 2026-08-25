/*
 *  restypes.h
 *  BoE
 *
 *  Created by Celtic Minstrel on 10-08-25.
 *
 */

#include "res_font.hpp"

#ifdef __ANDROID__
static std::string android_asset_name(const fs::path& fpath) {
	// SFML's Android Font::loadFromFile implementation reads through
	// AAssetManager rather than the normal filesystem. Core OpenBoE resources
	// are staged under <internalDataPath>/data for Boost filesystem resolution,
	// while the same files also live in the APK under assets/data. Translate
	// staged core-resource paths back to their APK asset name before handing
	// them to SFML.
	const std::string path = fpath.generic_string();
	const std::string marker = "/files/data/";
	const std::string::size_type pos = path.find(marker);
	if(pos != std::string::npos)
		return "data/" + path.substr(pos + marker.size());
	return path;
}
#endif

class FontLoader : public ResMgr::cLoader<sf::Font> {
	/// Load a font from a TTF or BDF file.
	sf::Font* operator() (const fs::path& fpath) const override {
		sf::Font* theFont = new sf::Font;
#ifdef __ANDROID__
		if(theFont->loadFromFile(android_asset_name(fpath))) return theFont;
#else
		if(theFont->loadFromFile(fpath.string())) return theFont;
#endif
		delete theFont;
		throw ResMgr::xError(ResMgr::ERR_LOAD, "Failed to find font: " + fpath.string());
	}

	ResourceList expand(const std::string& name) const override {
		return {name + ".ttf", name + ".bdf"};
	}

	std::string typeName() const override {
		return "font";
	}
};

// We'll allow all fonts to be loaded simultaneously (and leave some leeway in case a few more fonts are added)
static FontLoader loader;
ResMgr::cPool<sf::Font> ResMgr::fonts(loader, 10);
