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
| `/ltm` | Show or hide the draggable anchor box |
| `/ltm test` | Show a sample loot toast |
| `/ltm reset` | Move the anchor back to its default position |
| `/ltm config` | Open the options panel |
| `/ltm minimap` | Show or hide the minimap button |

`/loottoastpos` is the original command and still works; `/ltm` is a shorter alias for it.

The anchor box is the toast's actual footprint — same 276×96 size as a real loot toast,
sitting exactly where the first one will appear. Drag it with the left mouse button and
what you see is where toasts land. Further toasts stack upward from it.

`/ltm test` fires a genuine loot toast through Blizzard's alert system, so you can confirm
the placement without waiting for a drop. Run `/ltm` again to hide the box when you are
done.

## Where to find it

The same three actions are reachable from four places, so the addon is visible however your
UI is set up:

- **Minimap button** — the bag icon on the minimap ring. Left-click toggles the anchor box,
  right-click opens the options panel, and dragging moves the button around the ring. Hide
  it from the options panel or with `/ltm minimap`.
- **Options panel** — Game Menu → Options → AddOns → **LootToastMover**, with buttons for
  everything the slash commands do. `/ltm config` opens it directly.
- **Broker plugin** — if you run a broker display (Titan Panel, Bazooka, ChocolateBar,
  ElvUI datatexts, …), LootToastMover appears in its plugin list as a launcher. Same clicks
  as the minimap button.
- **Addon Compartment** — the addon-list button next to the minimap.

The broker plugin only appears when a broker display is installed. LibDataBroker is looked
up rather than bundled, because every broker bar ships its own copy; see
[Dependencies](#dependencies).

## Compatibility

Targets Interface `120100` (patch 12.1, Midnight). Patch 12.0 raised the floor for mainline
addons to `120000`, so this has to be kept current; check the live
value in-game with `/dump select(4, GetBuildInfo())`.

## Saved variables

`LootToastMoverDB` is account-wide and holds the anchor's screen position, the minimap
button's placement under `minimapButton`, and a `schema` number used for upgrades.
`/ltm reset` clears the position keys.

Two upgrades happen automatically on first load:

- **From 4.8.x**: the stale `minimap` sub-table left behind by the old LibDBIcon button is
  dropped.
- **From 4.9.x**: saved positions are shifted so toasts stay exactly where you put them.
  Older versions drew the first toast 31 pixels *below* a 60-pixel box; the box is now the
  toast's real 96-pixel footprint with the toast sitting on it, so the stored offset has to
  move to compensate. The shift depends on which anchor point was saved.

## Dependencies

None, still. Versions up to 4.8.x bundled LibStub, CallbackHandler-1.0, LibDataBroker-1.1
and LibDBIcon-1.0 — roughly 930 lines of third-party code — purely for a minimap button and
a broker plugin. Both are back without any of it:

- The **minimap button** is written directly against the widget API, about sixty lines in
  `LootToastMover.lua`.
- The **broker plugin** looks LibDataBroker up with `LibStub:GetLibrary("LibDataBroker-1.1",
  true)` instead of shipping it. Every broker display embeds the library itself, so it is
  always loaded whenever there is a bar for the plugin to appear on; with no bar installed
  the lookup returns nil and the addon carries on. Registration happens once at
  `PLAYER_LOGIN`, after every addon has loaded — there is no retry ticker.

## Development

The repository root *is* the addon, which is the layout the
[BigWigs packager](https://github.com/BigWigsMods/packager) expects. `.pkgmeta` renames it
to `LootToastMover` when building the zip.

Checks, all of which CI runs on every push:

```sh
luacheck .                    # lint
lua5.1 tests/run_tests.lua    # regression tests against a stubbed WoW API
lua5.1 tests/check_toc.lua    # TOC and packaging sanity (see below)
```

WoW runs Lua 5.1, so the tooling does too. See [tests/README.md](tests/README.md) for how
the stub works and what each test guards against.

## Releasing

Releases are cut by the **Release** workflow, from the Actions tab. Pick a bump and run it:

| Bump | Effect |
| --- | --- |
| `none` | Tag and publish what is already committed, version unchanged |
| `patch` | 4.10.0 → 4.10.1 |
| `minor` | 4.10.0 → 4.11.0 |
| `major` | 4.10.0 → 5.0.0 |

The workflow bumps `## Version` in the TOC, the banner in `LootToastMover.lua` and
`CHANGELOG.md` together, commits, tags, runs the tests, and publishes to CurseForge
(project `1262382`) and GitHub releases. The optional **notes** input becomes the
changelog line. Nothing ships if the tests fail.

`tools/bump_version.lua <none|patch|minor|major> [note]` does the file edits and can be
run by hand; it prints the resulting version.

Pushing a `v*` tag manually also works and just packages that tag.

### Staying current automatically

Being an expansion behind is what took this addon out of service once already: a 12.x
client will not load anything below Interface `120000`, and 4.8.3 sat on 11.1.5 for
months.

The same workflow runs daily. When Blizzard ships a patch it updates the Interface
version and releases a patch bump on its own, with a changelog entry naming the game
version. When nothing has changed it stops after the check. It tracks retail only — a
beta or PTR Interface number would mark the addon out of date on the live client it is
meant to support.

Bumping and publishing live in one workflow deliberately. Pushing a tag from a workflow
does not start another workflow, because GitHub does not trigger runs from events made
with `GITHUB_TOKEN`, so a job that only tagged would appear to succeed and publish
nothing.

Publishing requires one repository secret, `CF_API_KEY`, holding a CurseForge API token
(Settings → Secrets and variables → Actions). `GITHUB_TOKEN` is provided automatically.

## License

[MIT](LICENSE). The addon ships the licence file inside the zip, and declares it in the
TOC as `## X-License: MIT`.
