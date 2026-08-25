/*
 *  restypes.h
 *  BoE
 *
 *  Created by Celtic Minstrel on 10-08-25.
 *
 */

#include "res_sound.hpp"

#ifdef __ANDROID__
static std::string android_asset_name(const fs::path& fpath) {
	// SFML's Android SoundBuffer::loadFromFile implementation reads through
	// AAssetManager. Convert staged core-resource paths back to APK asset names.
	const std::string path = fpath.generic_string();
	const std::string marker = "/files/data/";
	const std::string::size_type pos = path.find(marker);
	if(pos != std::string::npos)
		return "data/" + path.substr(pos + marker.size());
	return path;
}
#endif

class SoundLoader : public ResMgr::cLoader<sf::SoundBuffer> {
	/// Load a sound from a WAV file.
	sf::SoundBuffer* operator() (const fs::path& fpath) const override {
		sf::SoundBuffer* snd = new sf::SoundBuffer;
#ifdef __ANDROID__
		if(snd->loadFromFile(android_asset_name(fpath))) return snd;
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
