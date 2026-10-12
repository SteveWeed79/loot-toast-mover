# LootToastMover

A small World of Warcraft addon that lets you move the loot toast alerts
(`AlertFrame`) anywhere on screen instead of leaving them in Blizzard's default
position near the top center. One download works in every version of the game Blizzard
runs: retail, World of Warcraft: Forever, Mists of Pandaria Classic, Classic Era,
TBC Anniversary and Titan Reforged Classic.

## What it does

Blizzard's alert system anchors loot toasts, achievement popups and similar alerts to a
fixed screen position managed by the UI's frame position manager. LootToastMover opts
`AlertFrame` out of that manager and re-anchors it to a draggable anchor box you position
yourself. The position is saved account-wide and reapplied on login.

## Installation

Install from CurseForge (project `1262382`), or grab the zip from the
[latest release](https://github.com/SteveWeed79/loot-toast-mover/releases/latest) and
extract it into the `AddOns` folder of the game you play:

```
<World of Warcraft>/_retail_/Interface/AddOns/         # retail
<World of Warcraft>/_classic_/Interface/AddOns/        # Mists of Pandaria Classic
<World of Warcraft>/_classic_era_/Interface/AddOns/    # Classic Era
<World of Warcraft>/_classic_beta_/Interface/AddOns/   # Forever beta
```

The other games each have a folder of their own alongside these, and the folder for
Forever's full launch on November 4 has not been announced. Whichever game it is, the addon
goes in the `Interface/AddOns/` folder inside that game's folder.

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
- **Addon Compartment** — the addon-list button next to the minimap. Retail and Forever
  only; the Classic games do not have one.

The broker plugin only appears when a broker display is installed. LibDataBroker is looked
up rather than bundled, because every broker bar ships its own copy; see
[Dependencies](#dependencies).

## Compatibility

One zip runs in every version of the game Blizzard currently runs. The TOC lists an
Interface number for each, and a client loads the addon as long as one of them is its own:

| Game | Interface | Version |
| --- | --- | --- |
| Retail (Midnight) | `120100` | 12.1.0 |
| World of Warcraft: Forever | `16001` | 1.60.1 |
| Mists of Pandaria Classic | `50504` | 5.5.4 |
| Titan Reforged Classic (China only) | `38002` | 3.80.2 |
| TBC Anniversary | `20506` | 2.5.6 |
| Classic Era | `11509` | 1.15.9 |

[`tools/games.lua`](tools/games.lua) is the same list in code; the TOC check and the
release tooling both work from it.

The addon needs no per-game code. Forever runs the retail client and UI, and the Classic
games share a UI codebase whose `AlertFrame` anchors and stacks alerts exactly the way
retail's does, with the same 276×96 loot toast, the same options panel API and the same
minimap. All of that was checked against Blizzard's UI source for each game's current
build. Forever restricts what addons can read about combat, which does not affect an addon
that never reads any.

What differs is how much Blizzard sends through that frame:

- **Retail and Forever** — loot, achievements and the other alerts listed in
  [the CurseForge description](docs/curseforge-description.md#what-it-moves).
- **The Classic games** — loot never goes through it, so what moves is mostly achievement
  toasts, in the games that have achievements. Classic Era has none, so very little appears
  there at all.

`/ltm test` fires a genuine loot toast in every game, so placement can always be checked.
The Addon Compartment is the one feature that is not everywhere: only retail and Forever
have one, and the Classic games ignore its TOC fields.

Wrath of the Lich King Classic and Cataclysm Classic are not listed because neither is
running any more: those realms moved on to Cataclysm Classic and then to Mists of Pandaria
Classic.

Patch 12.0 raised the floor for mainline addons to `120000`, so the retail number has to be
kept current, and the others have to track their clients the same way. Check the live value
in any game with `/dump select(4, GetBuildInfo())`.

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

Publishing is **manual**. Nothing fires on a schedule — the addon has real users, and an
unattended upload is not something that should happen while nobody is watching.

Run the **Release** workflow from the Actions tab and pick a bump:

| Bump | Effect |
| --- | --- |
| `none` | Tag and publish what is already committed, version unchanged |
| `patch` | 4.11.1 → 4.11.2 |
| `minor` | 4.11.1 → 4.12.0 |
| `major` | 4.11.1 → 5.0.0 |

It bumps `## Version` in the TOC, the banner in `LootToastMover.lua` and `CHANGELOG.md`
together, commits, tags, runs the tests, then publishes to CurseForge (project `1262382`)
and GitHub releases. The optional **notes** input becomes the changelog line. Nothing ships
if the tests fail, and it refuses to reuse an existing tag.

Pushing a `v*` tag by hand also works and just packages that tag.

### When a game patch lands

Tick **update_interface** on a release run. It pulls the current Interface version of every
supported game into the TOC as part of that release, so nobody has to look six numbers up.
With no **notes**, the changelog line names every game's version.

Being an expansion behind is what took this addon out of service once already — a 12.x
client will not load anything below Interface `120000`, and 4.8.3 sat on 11.1.5 for months
— but noticing that and shipping to players are separate decisions, and this keeps the
second one deliberate. A run that updates the Interface version needs a real bump, not
`none`, or there is no new version for anyone to update to; the workflow says so and stops.

It tracks live clients only. A beta or PTR Interface number would mark the addon out of
date on the live client it is meant to support. Forever is the exception until it launches,
because its beta is the only Forever client there is: for now the updater reads Forever's
number from Blizzard's `wow_classic_beta` product. If any lookup returns another game's
build, or nothing at all, `tests/check_toc.lua` fails the run before anything is tagged or
published.

The workflow names the games the way the updater does — `retail`, `forever`, `mists`,
`titan`, `anniversary` and `vanilla` — and `vanilla` is not interchangeable with
`classic_era`. The updater checks for `classic` first, so `classic_era` quietly fetches
Mists of Pandaria Classic a second time and leaves Classic Era out.

When Blizzard moves a Classic game on to its next expansion, the new Interface number falls
outside every range in `tools/games.lua`, and the check fails on purpose. Try the addon in
that client, then add the game to `tools/games.lua` and the workflow's flavor list, and
update this README and the CurseForge description.

`tools/bump_version.lua <none|patch|minor|major> [note]` does the file edits and can be run
by hand; it prints the resulting version.

Bumping and publishing live in one job deliberately. Pushing a tag from a workflow does not
start another workflow, because GitHub does not trigger runs from events made with
`GITHUB_TOKEN`, so a job that only tagged would appear to succeed and publish nothing.

Publishing requires one repository secret, `CF_API_KEY`, holding a CurseForge API token
(Settings → Secrets and variables → Actions). `GITHUB_TOKEN` is provided automatically.

## License

[MIT](LICENSE). The addon ships the licence file inside the zip, and declares it in the
TOC as `## X-License: MIT`.
