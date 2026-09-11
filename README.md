# LootToastMover

A small World of Warcraft addon that lets you move the loot toast alerts
(`AlertFrame`) anywhere on screen instead of leaving them in Blizzard's default
position near the top center.

## What it does

Blizzard's alert system anchors loot toasts, achievement popups and similar
alerts to a fixed screen position managed by the UI's frame position manager.
LootToastMover opts `AlertFrame` out of that manager and re-anchors it to a
draggable anchor box you position yourself. The position is saved account-wide
and reapplied on login.

## Installation

The addon folder **must** be named `LootToastMover` for WoW to load it, so copy
the inner folder rather than cloning the repository straight into your AddOns
directory:

```
<World of Warcraft>/_retail_/Interface/AddOns/LootToastMover/
```

The `Libs/` directory is vendored, so there are no separate dependencies to
install.

## Usage

| Command | Effect |
| --- | --- |
| `/loottoastpos` | Show or hide the draggable anchor box |
| `/loottoastpos reset` | Move the anchor back to its default position |

With the anchor box visible, drag it with the left mouse button to choose where
alerts appear. Toasts are placed 56 pixels below the center of the anchor box.
Run `/loottoastpos` again to hide the box once you are happy with the placement.

If you use a DataBroker display (Titan Panel, ChocolateBar, etc.) the addon also
registers a broker object; left-clicking it toggles the anchor box.

## Saved variables

`LootToastMoverDB` is account-wide and holds the anchor's screen position, plus a
`minimap` sub-table owned by LibDBIcon for the minimap button's angle and hidden state.
`/loottoastpos reset` clears the position keys and leaves the minimap settings alone.

## Development

Regression tests run outside the game against a stubbed WoW API:

```sh
lua5.1 tests/run_tests.lua
```

See [tests/README.md](tests/README.md).

## Bundled libraries

| Library | Purpose |
| --- | --- |
| [LibStub](https://www.wowace.com/projects/libstub) | Library versioning stub |
| [CallbackHandler-1.0](https://www.wowace.com/projects/callbackhandler) | Event callbacks used by the libraries below |
| [LibDataBroker-1.1](https://github.com/tekkub/libdatabroker-1-1) | Broker data object |
| [LibDBIcon-1.0](https://www.wowace.com/projects/libdbicon-1-0) | Minimap button |

These are third-party libraries redistributed under their own licenses.
