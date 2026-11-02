# PotSteam

**Chinese cooking, made everyday.**

PotSteam is an iOS cooking companion for exploring Chinese recipes and bringing the ingredients, preparation and cooking steps together. Its minimal bowl-and-steam mark celebrates the warmth of a home-cooked meal.

## What you can do

- Discover Chinese recipes and save favorites.
- Track ingredients in My Kitchen and create a shopping list.
- Adjust recipes for 1–8 servings and choose US or metric units.
- Follow preparation checklists and cooking steps, with optional timers.
- Save a rating and notes after cooking.

Kitchen data, favorites, preferences and history are stored locally on the device; no account is required. Recipe discovery uses an online catalog, with bundled and saved content available offline when present. Local storage is not a cross-device backup.

## Status

This is a **development preview**, not an App Store release or a signed iPhone distribution. The repository includes the iOS source, an Explore web view, backend and supporting content. The current simulator build and Explore tests have been checked; full release, real-device, content and platform acceptance remain outstanding. See [release evidence](docs/release/RELEASE-EVIDENCE-AUDIT.md).

## Run locally

Requires macOS, Xcode, Node.js and npm. Open `ios/CNrecipe.xcodeproj`, choose the CNrecipe scheme and an iPhone simulator. To regenerate bundled assets, run `npm ci` followed by `npm run build:assets`. The original project-specific testing instructions are in [development notes](docs/DEVELOPMENT.md).

## Privacy and data

The app does not currently require sign-in. Recipe searches use the online API; local kitchen data is stored on the device. Review source configuration before connecting a different backend.

## License

No license has been granted yet. Contact the owner before reuse or redistribution, including recipe images and other content.
