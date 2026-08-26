/*
 *  restypes.h
 *  BoE
 *
 *  Created by Celtic Minstrel on 10-08-25.
 *
 */

#include "res_sound.hpp"

#ifdef __ANDROID__
#include <fstream>
#include <vector>

static bool android_asset_name(const fs::path& fpath, std::string& asset_name) {
	// SFML's Android SoundBuffer::loadFromFile implementation reads through
	// AAssetManager. Core resources are APK assets mirrored into /files/data,
	// while scenario sounds are extracted/imported into normal app-private
	// filesystem paths and therefore need loadFromMemory instead.
	const std::string path = fpath.generic_string();
	const std::string marker = "/files/data/";
	const std::string::size_type pos = path.find(marker);
	if(pos == std::string::npos)
		return false;
	asset_name = "data/" + path.substr(pos + marker.size());
	return true;
}

static bool load_android_sound(sf::SoundBuffer& sound, const fs::path& fpath) {
	std::string asset_name;
	if(android_asset_name(fpath, asset_name))
		return sound.loadFromFile(asset_name);

	std::ifstream in(fpath.string(), std::ios::binary);
	if(!in)
		return false;
	std::vector<char> bytes((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
	if(bytes.empty())
		return false;
	return sound.loadFromMemory(bytes.data(), bytes.size());
}
#endif

class SoundLoader : public ResMgr::cLoader<sf::SoundBuffer> {
	/// Load a sound from a WAV file.
	sf::SoundBuffer* operator() (const fs::path& fpath) const override {
		sf::SoundBuffer* snd = new sf::SoundBuffer;
#ifdef __ANDROID__
		if(load_android_sound(*snd, fpath)) return snd;
#else
		if(snd->loadFromFile(fpath.string())) return snd;
#endif
		delete snd;
		throw ResMgr::xError(ResMgr::ERR_LOAD, "Failed to load WAV sound: " + fpath.string());
	}

	ResourceList expand(const std::string& name) const override {
		return {name + ".wav"};
	}

	std::string typeName() const override {
		return "sound";
	}
};

// TODO: What's a good max sound count?
static SoundLoader loader;
ResMgr::cPool<sf::SoundBuffer> ResMgr::sounds(loader, 50);
