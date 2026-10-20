# Math Mind Base Game

This folder is a reusable, independent Godot project. It contains the gameplay code, scenes, AdMob plugin, Android Gradle template, and supporting assets needed to build another game.

## Create a new game

1. Copy the entire base_game folder and rename the copy.
2. Open the copied project.godot in Godot 4.7.2 or a compatible Godot 4 release.
3. Update the app name in project.godot.
4. Update package/unique_name, version, and signing options in export_presets.cfg.
5. Replace the artwork under assets/generated/ while keeping filenames and dimensions when possible.
6. Replace easy_levels.json, medium_levels.json, hard_levels.json, and expert_levels.json under assets/data/.
7. Test every difficulty, rewarded-ad flow, interstitial schedule, and bottom banner before publishing.

## JSON contract

Each bank contains a top-level levels array. Each level needs level_num, difficulty, title, rows, cols, cells, and bank.

Fixed cell example: {"r":0,"c":0,"type":"fixed","val":"5"}
Answer cell example: {"r":0,"c":2,"type":"empty","target":"6"}

The bank array must contain every draggable target required to solve the board. Supported arithmetic symbols are +, -, ×, and ÷.

## Replaceable content

- Launcher and splash assets: assets/generated/app-icon-*
- Backgrounds and UI artwork: assets/generated/
- Level data: assets/data/
- Audio: assets/audio/

If filenames change, update their references in scenes, scripts, project.godot, and export_presets.cfg.

## Ads

The template uses the Poing Studios Godot AdMob plugin. Debug builds use Google's test ad unit IDs. Before release, replace the production IDs and verify the AdMob application ID in the Android export configuration.

## Intentionally excluded

- .godot/ imported-editor cache
- Root build/ APK/output files
- android/build/.gradle/
- android/build/build/ generated Gradle output
- android/build/local.properties machine-specific SDK path

Godot and Gradle regenerate these files on the new development machine.