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
| `/loottoastpos test` | Show a sample loot toast |
| `/loottoastpos reset` | Move the anchor back to its default position |

The anchor box is the toast's actual footprint — same 276×96 size as a real loot toast,
sitting exactly where the first one will appear. Drag it with the left mouse button and
what you see is where toasts land. Further toasts stack upward from it.

`/loottoastpos test` fires a genuine loot toast through Blizzard's alert system, so you
can confirm the placement without waiting for a drop. Run `/loottoastpos` again to hide
the box when you are done.

The addon also appears in the **Addon Compartment** — the addon-list button next to the
minimap. Clicking its entry there toggles the anchor box, same as the bare slash command.

## Compatibility

Targets Interface `120100` (patch 12.1, Midnight). Patch 12.0 raised the floor for mainline
addons to `120000`, so this has to be kept current; check the live
value in-game with `/dump select(4, GetBuildInfo())`.

## Saved variables

`LootToastMoverDB` is account-wide and holds the anchor's screen position plus a `schema`
number used for upgrades. `/loottoastpos reset` clears the position keys.

Two upgrades happen automatically on first load:

- **From 4.8.x**: the stale `minimap` sub-table left behind by the old LibDBIcon button is
  dropped.
- **From 4.9.x**: saved positions are shifted so toasts stay exactly where you put them.
  Older versions drew the first toast 31 pixels *below* a 60-pixel box; the box is now the
  toast's real 96-pixel footprint with the toast sitting on it, so the stored offset has to
  move to compensate. The shift depends on which anchor point was saved.

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
