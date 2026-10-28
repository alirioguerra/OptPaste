<div align="center">

<img src="docs/icon.png" width="128" height="128" alt="OptPaste icon" />

# OptPaste

**Everything you copy, one shortcut away.**

A clipboard history for the Mac that opens with <kbd>⌥</kbd> <kbd>V</kbd>, on top of any app.

[![Latest release](https://img.shields.io/github/v/release/alirioguerra/OptPaste?label=release&color=7c5cff)](https://github.com/alirioguerra/OptPaste/releases/latest)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111?logo=apple)
![Swift](https://img.shields.io/badge/Swift-SwiftUI%20%2B%20AppKit-F05138?logo=swift&logoColor=white)
![Free](https://img.shields.io/badge/price-free%20forever-2ea44f)

[**Download**](https://optpaste.pages.dev/downloads/OptPaste.dmg) · [Website](https://optpaste.pages.dev) · [Releases](https://github.com/alirioguerra/OptPaste/releases) · [Português](README.pt-BR.md)

<br />

<img src="docs/screenshot.jpg" width="720" alt="OptPaste panel open over a browser on macOS, showing copied text, a link and an image" />

</div>

---

> [!WARNING]
> **OptPaste is not signed with an Apple Developer ID or notarized yet.** The app is safe and the code is all here, but macOS will block it the first time you open it. See [Opening OptPaste for the first time](#opening-optpaste-for-the-first-time) below.

## Why

On Windows, <kbd>⊞ Win</kbd> + <kbd>V</kbd> opens a window with your latest copies and one click pastes the one you pick. The Mac keeps nothing like that at hand. OptPaste brings that experience to macOS: copied something ten minutes ago and already overwrote it? Press <kbd>⌥</kbd> <kbd>V</kbd> and paste it again.

## Features

| | |
|---|---|
| ⌨️ **One shortcut, from any app** | <kbd>⌥</kbd> <kbd>V</kbd> opens your history wherever you are. Prefer another combo? Record your own. |
| 📋 **Pastes for you** | Pick an item and it's pasted straight into the app you were using, or just copied if you prefer. |
| 📌 **Pin what matters** | Addresses, canned replies, snippets: pinned items stay on top and survive "Clear all". |
| 🖼️ **Text, images and files** | Everything that goes through the clipboard, with the source app's icon and when it was copied. |
| 🔒 **Masked passwords** | Items from password managers show up hidden, or are never stored at all. |
| ✂️ **Cut and paste in Finder** | <kbd>⌘</kbd> <kbd>X</kbd> then <kbd>⌘</kbd> <kbd>V</kbd> moves files, like on Windows. |
| 🪶 **Light and out of the way** | Lives in the menu bar, starts at login, keeps 10 to 200 items. |
| 🔄 **Automatic updates** | New versions install themselves through [Sparkle](https://sparkle-project.org). |
| 🌐 **English and Portuguese** | Follows your system language. |

## Shortcuts

| Keys | Action |
|---|---|
| <kbd>⌥</kbd> <kbd>V</kbd> | Open the history |
| <kbd>↑</kbd> <kbd>↓</kbd> | Move through items |
| <kbd>↩</kbd> | Paste the selected item |
| <kbd>1</kbd> … <kbd>9</kbd> | Paste by position |
| <kbd>P</kbd> | Pin or unpin |
| <kbd>⌫</kbd> | Delete from history |
| <kbd>esc</kbd> | Close |

## Privacy

Your history never leaves your Mac.

- Everything OptPaste writes to disk is encrypted with **AES-256-GCM**, with a key generated on your Mac and kept in your Keychain.
- No account, no server, no telemetry. The app only goes online to check for a new version.
- It's open source: you don't have to take my word for it, read the code.

## Install

1. Download [**OptPaste.dmg**](https://optpaste.pages.dev/downloads/OptPaste.dmg) (or grab it from [Releases](https://github.com/alirioguerra/OptPaste/releases/latest)).
2. Open the `.dmg` and drag **OptPaste** into **Applications**.
3. Open it and follow the steps below the first time.

Requires **macOS 14 Sonoma** or later.

### Opening OptPaste for the first time

Because the app isn't signed with a Developer ID or notarized by Apple yet, Gatekeeper shows a warning like *"Apple could not verify OptPaste is free of malware"*. To open it anyway:

**macOS 15 Sequoia and later**

1. Open OptPaste once and click **Done** on the warning.
2. Go to **System Settings → Privacy & Security**.
3. Scroll down to the message about OptPaste and click **Open Anyway**, then confirm with your password.

**macOS 14 Sonoma**

- Right-click (or <kbd>⌃</kbd>-click) OptPaste in Applications, choose **Open**, then **Open** again.

**Or, from the Terminal**

```sh
xattr -dr com.apple.quarantine /Applications/OptPaste.app
```

You only need to do this once. Updates delivered by Sparkle are still verified: the app only installs versions signed with the project's EdDSA key.

### Permissions

On first launch OptPaste asks for **Accessibility** (System Settings → Privacy & Security → Accessibility). It's used only to send <kbd>⌘</kbd> <kbd>V</kbd> to the app you were in, so the item is pasted for you. Without it, OptPaste still works and just copies the item.

## Build from source

```sh
git clone https://github.com/alirioguerra/OptPaste.git
cd OptPaste
open OptPaste.xcodeproj
```

Or from the command line:

```sh
xcodebuild -scheme OptPaste -configuration Debug build
```

Sparkle comes in through Swift Package Manager, so Xcode resolves it on the first build. You'll need to pick your own signing team in **Signing & Capabilities**.

## Support

OptPaste is and always will be free. If it helps you and you'd like to support it:

<a href="https://www.buymeacoffee.com/alirioguerra" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me a Coffee" height="60" width="217" /></a>

Paying for an Apple Developer account is what will let the app be signed and notarized, so the warning above goes away.

---

<div align="center">
Made by <a href="https://alirioguerra.github.io">Alírio Guerra</a>
</div>
