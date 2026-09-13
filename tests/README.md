# Tests

Regression tests that run the addon outside the game against a stubbed WoW API.

```sh
lua5.1 tests/run_tests.lua    # behaviour
lua5.1 tests/check_toc.lua    # TOC sanity
```

Both exit non-zero on failure. WoW runs Lua 5.1, so the tests do too.

## Layout

| File | Purpose |
| --- | --- |
| `wow_stub.lua` | Minimal emulation of the WoW API — frames, events, timers, `GameTooltip`, `Minimap`, the `Settings` panel registry, the cursor, and the chat `print` |
| `run_tests.lua` | Behavioural test sections |
| `check_toc.lua` | Static checks on `LootToastMover.toc` |

The stub models only what the addon actually touches; any widget method it does not
implement is a no-op. One detail is deliberate: **`IsAddOnLoaded` is left undefined**, because
the bare global was moved into `C_AddOns` in 10.2.0 and stopped working in 11.0.2. Leaving
it nil is what makes the suite notice if the addon ever reaches for it again.

`LibStub` is left undefined for the same kind of reason: the addon bundles no libraries and
must load without one. `InstallBrokerLibs()` puts a stand-in LibStub and LibDataBroker in
place before loading, standing in for the copy a broker display embeds, so the broker
sections can test both worlds.

Files are loaded in the order the `.toc` lists them, read from the `.toc` itself, because
load order was the cause of a real bug.

## Running against another revision

`LTM_ADDON_DIR` points either script at a different copy of the addon, which is how to
confirm a test actually catches the bug it claims to:

```sh
git worktree add /tmp/ltm-old <some-older-commit>
LTM_ADDON_DIR=/tmp/ltm-old lua5.1 tests/run_tests.lua
```

Against 4.8.3 every section fails; against the current tree all of them pass.

## What each section guards

| Section | Concern |
| --- | --- |
| Loads standalone with no third-party libraries | 4.8.3 listed its own file before the libraries, so `LibStub` was nil when called. The libraries are gone now, and the addon must stay dependency-free |
| Slash command survives repeated use | The handler called the removed `IsAddOnLoaded` global and re-registered a minimap icon every time |
| Addon Compartment entry points | Blizzard looks these up as globals named in the TOC, so a rename that misses one side leaves a dead entry |
| Anchor position round-trips through SavedVariables | Position must survive a relog |
| Reset clears only the anchor position | Reset used to wipe the whole saved table |
| Upgrading from 4.8.x drops the stale minimap table | The old LibDBIcon sub-table is dead weight once the minimap button is gone |
| Slash argument parsing | A padded `reset` silently toggled instead, and unknown input gave no feedback |
| No leaked timers | A 1-second ticker retried forever for the whole session |
| Alerts stay on the anchor after Blizzard re-anchors | Blizzard calls `UpdateAnchors` on every alert; the hook has to reapply every time |
| Anchor box is the toast footprint | The box must be the real 276×96 toast size with no fudge offset, or it does not show where toasts land |
| Sample toast | `GetItemInfo` returns nil for an uncached item and Blizzard's setup function passes that nil onward, so the alert must wait for the item to load |
| Upgrading from 4.9.x keeps toasts where they were | Pins the exact migrated offsets for each anchor point |
| The upgrade shift is geometrically correct | Proves the same thing from the two layouts rather than from the addon's own formula |
| The upgrade shift runs exactly once | A migration that re-applies every login would walk the anchor off the screen |
| Minimap button | 4.9.0 left the Addon Compartment as the only visible sign the addon had loaded, so players could not find it. The button must exist, show by default, and answer both mouse buttons |
| Minimap button position round-trips | A dragged button must come back where it was put, without resurrecting the LibDBIcon table the 4.8.x cleanup removes |
| Minimap button can be hidden and stays hidden | Hiding it is a preference, not a session toggle |
| Options panel is registered with the game's settings | Nothing appeared under Options → AddOns, so players there concluded the addon had not loaded |
| Options panel callbacks | Blizzard's canvas layout drives `OnRefresh`/`OnCommit`/`OnDefault`; `OnDefault` backs the panel's Defaults button |
| Broker plugin | Broker bars only show addons that register a LibDataBroker object, and this one registered none |
| Broker plugin is optional | The library is looked up, never bundled, so no broker bar must mean no error and no retry loop |
| Slash command aliases | `/loottoastpos` is a lot to type for an addon nobody can find; `/ltm` has to keep working alongside it |

`check_toc.lua` separately verifies:

- the interface number clears the `120000` floor a 12.x client requires
- the CurseForge project id is present and numeric
- every file the TOC lists actually exists, with libraries ahead of the addon's own file
- the compartment handlers named in the TOC resolve to functions in the Lua file
- `## Version` has not drifted from the banner in `LootToastMover.lua`
- `.pkgmeta` names a `manual-changelog` file that exists, and that `CHANGELOG.md` has an
  entry for the version being shipped

The last one matters because the packager falls back to a changelog generated from raw
commit messages when it cannot find the file named in `.pkgmeta`, without reporting
anything. Each of these was confirmed to fail when deliberately broken.
