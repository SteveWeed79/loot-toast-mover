# LootToastMover

A small World of Warcraft addon that lets you move the loot toast alerts
(`AlertFrame`) anywhere on screen instead of leaving them in Blizzard's default
position near the top center.

## What it does

Blizzard's alert system anchors loot toasts, achievement popups and similar alerts to a
fixed screen position managed by the UI's frame position manager. LootToastMover opts
`AlertFrame` out of that manager and re-anchors it to a draggable anchor box you position
yourself. The position is saved account-wide and reapplied on login.

## Installation

Install from CurseForge (project `1262382`), or grab the zip from the
[latest release](https://github.com/SteveWeed79/loot-toast-mover/releases/latest) and
extract it into:

```
<World of Warcraft>/_retail_/Interface/AddOns/
```

The release zip already contains a correctly named `LootToastMover/` folder. If you copy
from a git checkout instead, the folder **must** be named `LootToastMover` — the
repository directory name (`loot-toast-mover`) will not load.

The addon is a single Lua file with no third-party dependencies.

## Usage

| Command | Effect |
| --- | --- |
| `/loottoastpos` | Show or hide the draggable anchor box |
| `/loottoastpos reset` | Move the anchor back to its default position |

With the anchor box visible, drag it with the left mouse button to choose where alerts
appear. Toasts are placed 56 pixels below the center of the anchor box. Run
`/loottoastpos` again to hide the box once you are happy with the placement.

The addon also appears in the **Addon Compartment** — the addon-list button next to the
minimap. Clicking its entry there toggles the anchor box, same as the bare slash command.

## Compatibility

Targets Interface `120100` (patch 12.1, Midnight). Patch 12.0 raised the floor for mainline
addons to `120000`, so this has to be kept current; check the live
value in-game with `/dump select(4, GetBuildInfo())`.

## Saved variables

`LootToastMoverDB` is account-wide and holds the anchor's screen position.
`/loottoastpos reset` clears those keys.

Upgrading from 4.8.x also drops the stale `minimap` sub-table that the old LibDBIcon
minimap button left behind.

## Dependencies

None. Versions up to 4.8.x bundled LibStub, CallbackHandler-1.0, LibDataBroker-1.1 and
LibDBIcon-1.0 — roughly 930 lines of third-party code — purely to put a clickable button
near the minimap. Blizzard's Addon Compartment (TOC-registered since 10.1) does that
natively, so 4.9.0 drops all four.

## Development

The repository root *is* the addon, which is the layout the
[BigWigs packager](https://github.com/BigWigsMods/packager) expects. `.pkgmeta` renames it
to `LootToastMover` when building the zip.

Checks, all of which CI runs on every push:

```sh
luacheck .                    # lint
lua5.1 tests/run_tests.lua    # regression tests against a stubbed WoW API
lua5.1 tests/check_toc.lua    # TOC sanity: interface number, compartment handlers, file list
```

WoW runs Lua 5.1, so the tooling does too. See [tests/README.md](tests/README.md) for how
the stub works and what each test guards against.

## Releasing

Pushing a version tag builds the addon and publishes it to CurseForge (project `1262382`)
and to GitHub releases:

```sh
git tag -a v4.8.4 -m "4.8.4"
git push origin v4.8.4
```

The tag runs the test suite first and stops if it fails. Bump `## Version` in
`LootToastMover.toc` and the banner at the top of `LootToastMover.lua` to match the tag
before tagging — `check_toc.lua` fails the build if those two drift apart.

Publishing requires one repository secret, `CF_API_KEY`, holding a CurseForge API token
(Settings → Secrets and variables → Actions). `GITHUB_TOKEN` is provided automatically.
