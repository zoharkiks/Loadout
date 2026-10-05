<p align="center"><img src="docs/app-icon.png" width="128" alt="Loadout app icon"></p>

<h1 align="center">Loadout</h1>

<p align="center"><b>A loadout for every Focus.</b><br>Give every Focus on your Mac its own Dock and its own wallpaper.</p>

<p align="center"><a href="https://loadoutmac.netlify.app"><b>loadoutmac.netlify.app</b></a></p>

Loadout is a menu bar app. When a Focus turns on, it swaps your Dock apps, Dock folders and wallpaper for the ones you picked for that Focus. When the Focus ends, your usual setup comes back.

![The Loadout menu bar panel: the active Work profile, and the list of profiles](docs/menu-bar.jpg)

https://github.com/user-attachments/assets/2f1369d0-5e69-404c-a2d8-19ffaa8f47e0

## Features

- **A Dock per Focus.** Each profile holds its own Dock apps and folders, in your order. Start from what's in your Dock right now and tick only the ones you want.
- **Wallpaper that follows along.** Choose an image, use your current wallpaper, or drop any image onto the profile. It's set on every display.
- **Three ways to switch.** A Focus Filter in System Settings, by hand from the menu bar, or the **Apply Loadout Profile** action in Shortcuts.
- **Make it yours.** Give each profile a colour and an icon. The menu bar panel and editor take on its tint.
- **Private.** No account, no analytics, no network access. Everything stays on your Mac.

<table>
  <tr>
    <td><img src="docs/editor.jpg" alt="Profile editor: name, colour and icon"></td>
    <td><img src="docs/editor-dock.jpg" alt="Profile editor: Dock apps, folders and wallpaper"></td>
  </tr>
  <tr>
    <td align="center">Give each profile a colour and an icon</td>
    <td align="center">Pick its Dock apps, folders and wallpaper</td>
  </tr>
</table>

## Requirements

- macOS 15 Sequoia or later
- Xcode 16 or later, to build it

## Install

### Download

1. Download **[Loadout.dmg](https://github.com/zoharkiks/Loadout/releases/latest/download/Loadout.dmg)** from the [latest release](https://github.com/zoharkiks/Loadout/releases/latest).
2. Open it and drag **Loadout** into **Applications**, then open Loadout.
3. The first time, macOS says it can't verify the developer, because the app isn't notarized yet. Click **Done**, open **System Settings › Privacy & Security**, scroll down to the message about Loadout and click **Open Anyway**, then confirm with your password. After that it opens normally.

### Build it yourself

1. Clone this repo and open `Loadout.xcodeproj` in Xcode.
2. Select the **Loadout** target › **Signing & Capabilities** and choose your own **Team**. A free Apple ID (Personal Team) works.
   Focus Filters only load from apps signed with a team, so an unsigned build will run but won't appear in Focus settings.
3. Press **Run**, or build from Terminal:

   ```bash
   xcodebuild -project Loadout.xcodeproj -target Loadout -configuration Release SYMROOT="$PWD/build" DEVELOPMENT_TEAM=<your team ID> build
   ```

4. Copy `build/Release/Loadout.app` to `/Applications` and open it once so macOS registers its Focus Filter.

## Set up

The first launch walks you through these steps.

![The five welcome screens, in light and dark mode](docs/onboarding.jpg)

1. Click the Loadout icon in the menu bar, then the gear › **Edit Profiles…**, and click **New Profile** (for example "Work").
2. Under **Dock**, use **Add from Current Dock…** or **Add Apps…** / **Add Folders…**. Drag rows to reorder them.
3. Under **Wallpaper**, choose an image or drop one onto the card.
4. On the profile you want back when a Focus ends, turn on **Use when no Focus is on**.
5. In **System Settings › Focus**, open a Focus, choose **Add Filter › Loadout**, and pick the profile.
6. Repeat for each Focus.

You can also apply profiles by hand from the menu bar, or with the **Apply Loadout Profile** action in Shortcuts. To see the welcome screens again, use the gear › **Show Welcome…**.

## How it works

- The Dock is changed through the `com.apple.dock` preferences, then the Dock restarts (a short flicker), the same way `dockutil` does. That's why the app isn't sandboxed.
- A profile with no apps and no folders never touches your Dock, so an unfinished profile can't empty it.
- The wallpaper is set on every display, for the current Space only (a macOS limitation).
- Profiles are stored in `~/Library/Application Support/Loadout/profiles.json`.

## License

[MIT](LICENSE)
