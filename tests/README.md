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
| `wow_stub.lua` | Minimal emulation of the WoW API — frames, events, timers, `GameTooltip`, and the chat `print` |
| `run_tests.lua` | Behavioural test sections |
| `check_toc.lua` | Static checks on `LootToastMover.toc` |

The stub models only what the addon actually touches; any widget method it does not
implement is a no-op. One detail is deliberate: **`IsAddOnLoaded` is left undefined**, because
the bare global was moved into `C_AddOns` in 10.2.0 and stopped working in 11.0.2. Leaving
it nil is what makes the suite notice if the addon ever reaches for it again.

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

`check_toc.lua` separately verifies the interface number clears the `120000` floor, the
CurseForge project id is present and numeric, every file the TOC lists exists, the
compartment handlers named in the TOC are actually defined, and the `## Version` has not
drifted from the banner in `LootToastMover.lua`.
