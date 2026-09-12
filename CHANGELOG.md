# Changelog

Notable changes to LootToastMover. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [4.10.0] - 2026-09-12

### Added

- `/loottoastpos test` shows a sample loot toast, so you can check placement without
  waiting for a drop.

### Changed

- **The anchor box is now the real thing.** It matches the exact size of a loot toast
  (276×96) and sits exactly where the first toast will appear, with later toasts stacking
  upward from it. Previously the box was a 260×60 placeholder and the first toast actually
  landed 31 pixels *below* it, so what you dragged was not where toasts went.
- Your saved position is adjusted automatically the first time you log in, so toasts stay
  exactly where you had them. Nothing to redo.

## [4.9.0] - 2026-09-12

### Changed

- The minimap button is replaced by Blizzard's **Addon Compartment** — the addon-list
  button next to the minimap. Click the LootToastMover entry there to show or hide the
  anchor box, as before.

### Removed

- All four bundled libraries: LibStub, CallbackHandler-1.0, LibDataBroker-1.1 and
  LibDBIcon-1.0. They were carried solely to provide the minimap button, which the game
  now does natively. The addon is a single Lua file with no third-party dependencies.
- The unused `minimap` entry the old button left behind in your saved variables is cleared
  when you upgrade.

**If you use a broker display** such as Titan Panel or ChocolateBar, LootToastMover no
longer appears in it, because the LibDataBroker object went with the libraries. Use the
Addon Compartment or `/loottoastpos` instead.

## [4.8.4] - 2026-09-11

### Fixed

- The addon could fail to load at all. Its own file was listed before its libraries, so it
  reached for LibStub before LibStub existed and errored out, unless some other addon
  happened to load LibStub first.
- `/loottoastpos` threw a Lua error every time it was used, because it called an API that
  Blizzard removed during the 11.x cycle.
- The minimap button's position was never remembered between sessions.
- `/loottoastpos reset` wiped the minimap button's settings along with the anchor position.
- `/loottoastpos  reset` typed with extra spaces silently toggled the anchor instead of
  resetting it.
- A one-second repeating timer kept running for the entire play session.

### Changed

- Updated for patch 12.1 (Interface `120100`). Earlier builds targeted 11.1.5, which a
  12.x client will not load.
- An unrecognised slash command now prints usage instead of doing nothing.

## [4.8.3]

The last build before the above, and the baseline for this changelog.
