# Tests

Regression tests that run the addon outside the game against a stubbed WoW API.

```sh
lua5.1 tests/run_tests.lua
```

Exits non-zero if anything fails. WoW runs Lua 5.1, so the tests do too.

## Layout

| File | Purpose |
| --- | --- |
| `wow_stub.lua` | Minimal emulation of the WoW API — frames, events, timers, the chat `print`, and a stand-in for LibDBIcon |
| `run_tests.lua` | The test sections themselves |

The stub models only what the addon actually touches; any widget method it does not
implement is a no-op. Two details are deliberate:

- **`IsAddOnLoaded` is left undefined.** The bare global was moved into `C_AddOns` in 10.2.0
  and stopped working in 11.0.2, so a current client does not have it. Leaving it nil is
  what makes the test suite notice if the addon ever calls it again.
- **LibDBIcon is substituted.** The real library needs far more of the widget API than is
  worth emulating, so `wow_stub.installDBIcon()` reproduces just the two behaviours the
  addon depends on, both taken from the bundled source: `Register()` raises a hard error
  when the same name is registered twice, and the button's position is written into the
  `db` table passed to `Register` rather than kept internally.

Files are loaded in the order the `.toc` lists them, read from the `.toc` itself, because
load order is one of the things these tests cover.

## Running against another revision

`LTM_ADDON_DIR` points the suite at a different copy of the addon, which is how to confirm
a test actually catches the bug it claims to:

```sh
git worktree add /tmp/ltm-old <some-older-commit>
LTM_ADDON_DIR=/tmp/ltm-old lua5.1 tests/run_tests.lua
```

Against 4.8.3 every section fails; against the current tree all of them pass.

## What each section guards

| Section | Bug it guards against |
| --- | --- |
| Loads cleanly when LootToastMover is the only addon installed | The `.toc` listed the addon's own file before the libraries, so `LibStub` was nil when the addon called it |
| Slash command survives repeated use | The handler called the removed `IsAddOnLoaded` global, and re-registered the minimap icon on every invocation |
| Minimap button state is persisted | `Register()` was handed a throwaway `{}`, so the dragged position was lost at logout |
| Anchor position round-trips through SavedVariables | Position must survive a relog |
| Minimap settings survive anchor changes | Dragging the anchor replaced the whole saved table, and reset wiped it |
| Slash argument parsing | A padded `reset` silently toggled instead, and unknown input gave no feedback |
| No leaked timers | A 1-second ticker retried forever for the whole session |
| Degrades gracefully when the libraries are absent | Core anchoring must not depend on the optional libraries |
