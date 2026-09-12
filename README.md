# Well Water Fetcher

A simple one-button mobile game: lower the bucket into the well, time your tap to
catch the water zone, pull it up by tapping in rhythm before the rope snaps, then
keep it balanced on the walk home before it spills. Repeat until you run out of
stamina for the day.

## How to run it (desktop test, 2 minutes)

1. Download and install **Godot 4.3** (or newer 4.x): https://godotengine.org/download
   (Standard version, not required to get the .NET/C# version — this project is pure GDScript.)
2. Open Godot, click **Import**, and select the `project.godot` file in this folder.
3. Once it opens, press the **Play** button (top-right, or F5). It will ask which
   scene is the main scene — `Main.tscn` is already set, so just press play.
4. Click with your mouse where the orange "TAP" button is to test the whole loop.

## How to export it to an Android APK

1. In Godot: **Editor > Manage Export Templates** → download the templates that match
   your Godot version (one-time setup).
2. Install the **Android SDK** (Android Studio is the easiest way to get it) and set
   the SDK path in **Editor > Editor Settings > Export > Android**.
3. In the project: **Project > Export...** → **Add** → **Android**.
4. Set a package name (e.g. `com.yourname.wellwater`), then click **Export Project**
   and choose a location for the `.apk`.
5. For a real device: enable Developer Mode + USB debugging on your phone, plug it
   in, and use `adb install yourgame.apk`, or just copy the APK to the phone and
   open it (allow "install from unknown sources").
6. For the Play Store, you'll eventually need to export an `.aab` and sign it with
   a release keystore — Godot's docs walk through this: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html

## What's already built

- Full one-tap-per-action game loop (lowering, filling, raising, carrying, delivery)
- Rope stress / snap mechanic, stamina system, scoring, and a mini "toast" message system
- Everything is built procedurally in `Main.gd` — no manual scene editing needed,
  so you (or I) can keep extending it purely in code

## Easy next steps to extend it

- Swap the colored rectangles for real sprites/animations (bucket, character, well)
- Add sound effects (splash, rope creak, footsteps) — drop audio files into an
  `assets/` folder and play them with an `AudioStreamPlayer`
- Add a day/night cycle or a village that upgrades as you deliver more water
- Add difficulty scaling (faster lowering speed, narrower water zone) as trips increase
- Save high scores locally with Godot's `FileAccess` / `ConfigFile`

## Project structure

```
WellWaterGame/
├── project.godot   # engine config, sets Main.tscn as the entry scene
├── Main.tscn       # tiny root scene, just attaches Main.gd
├── Main.gd         # ALL game logic + procedurally-built UI lives here
├── icon.svg        # placeholder app icon
└── README.md       # this file
```
