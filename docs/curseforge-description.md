# LootToastMover

Blizzard decides where your loot toasts appear. This lets you decide instead.

Drag a box to the spot you want and that's where alerts show up. The box is the exact
size and shape of a real loot toast, sitting precisely where the next one will land — so
you're not guessing at an offset or farming a drop to see whether you got it right. Type
`/ltm test` and a genuine toast fires on the spot to confirm it.

Your position is saved account-wide and restored every login.

## Getting started

1. Type `/ltm`, or click the bag icon on your minimap
2. Drag the box where you want alerts to appear
3. Click or type `/ltm` again to hide it

That's it. Nothing to configure.

## Commands

| Command | What it does |
| --- | --- |
| `/ltm` | Show or hide the anchor box |
| `/ltm test` | Fire a sample loot toast to check placement |
| `/ltm reset` | Move the anchor back to its default position |
| `/ltm config` | Open the options panel |
| `/ltm minimap` | Show or hide the minimap button |

`/loottoastpos` is the original command and still works. `/ltm` is a shorter alias for it.

## Four ways in

However your UI is set up, the addon is somewhere you'll find it:

- **Minimap button** — the bag icon on the minimap ring. Left-click toggles the anchor box,
  right-click opens the options panel, and you can drag it anywhere around the ring.
- **Options panel** — Game Menu → Options → AddOns → **LootToastMover**. Buttons for showing
  the anchor, firing a sample toast and resetting the position, plus a checkbox to hide the
  minimap button.
- **Broker plugin** — if you run Titan Panel, Bazooka, ChocolateBar, ElvUI datatexts or any
  other broker display, LootToastMover appears in its plugin list as a launcher.
- **Addon Compartment** — the addon-list button next to the minimap.

## What it moves

The anchor controls Blizzard's whole alert frame, so it repositions every pop-up alert that
uses it, not just loot:

- Loot received, and loot upgrades
- Achievements and achievement criteria
- Money won
- New recipes learned
- Honor awarded
- Monthly activities
- Guild renames
- Specialization unlocks

Alerts stack upward from the anchor, the same way they always have.

## Requirements

Retail only, built for patch 12.1 (Midnight).

**No dependencies.** The addon is a single Lua file. The minimap button is written directly
against the game's widget API, and the broker plugin uses the LibDataBroker your broker
display already loads, so nothing is bundled and nothing is duplicated.

## Upgrading from an older version

Your saved position carries over automatically — toasts stay exactly where you had them,
including across the change that made the anchor box the toast's real footprint.

If you used 4.9.0 or 4.10.0 and wondered where the addon went: the minimap button and the
broker plugin were removed in 4.9.0 and are back as of 4.11.0.

## Source and bug reports

[github.com/SteveWeed79/loot-toast-mover](https://github.com/SteveWeed79/loot-toast-mover)

MIT licensed.
