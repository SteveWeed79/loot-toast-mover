#!/usr/bin/env bash
#
# Check that what LootToastMover assumes about Blizzard's UI code is still true, for one game.
#
# The addon is small because it leans on a handful of facts about how Blizzard lays alerts
# out. Each check below names the fact and what in the addon rests on it. If one fails, the
# addon needs a code change, not just a new Interface number.
#
#   tools/check_blizzard_source.sh                        # retail
#   WOW_GAME=classic_era tools/check_blizzard_source.sh   # another game, by mirror branch
#   WOW_UI_SOURCE=/path/to/checkout tools/check_blizzard_source.sh
#
# WOW_GAME is a branch of the community mirror of Blizzard's UI source:
#
#   live                 Retail
#   forever              World of Warcraft: Forever
#   classic              Mists of Pandaria Classic
#   classic_titan        Titan Reforged Classic
#   classic_anniversary  TBC Anniversary
#   classic_era          Classic Era
#
# Keep this list in step with tools/games.lua and .github/workflows/blizzard-source.yml.
#
# Exits non-zero, and prints what changed, if any check fails.

set -uo pipefail

MIRROR="https://github.com/Gethe/wow-ui-source.git"
GAME="${WOW_GAME:-live}"

case "$GAME" in
    live|forever) COMPARTMENT=1 ;;
    classic|classic_titan|classic_anniversary|classic_era) COMPARTMENT=0 ;;
    *)
        printf 'Unknown WOW_GAME "%s". One of: live, forever, classic, classic_titan, classic_anniversary, classic_era.\n' "$GAME" >&2
        exit 2 ;;
esac

failures=0
checked=0

pass() { printf '  ok   %s\n' "$1"; }
fail() {
    printf '  FAIL %s\n       %s\n' "$1" "$2"
    failures=$((failures + 1))
}

# present <name> <file> <fixed text> <what rests on it>
present() {
    checked=$((checked + 1))
    if [ -n "$2" ] && grep -qF -- "$3" "$2"; then pass "$1"; else fail "$1" "$4"; fi
}

# absent <name> <directory> <fixed text> <what it would mean>
absent() {
    checked=$((checked + 1))
    if grep -rqF --include='*.lua' -- "$3" "$2"; then fail "$1" "$4"; else pass "$1"; fi
}

if [ -n "${WOW_UI_SOURCE:-}" ]; then
    SRC="$WOW_UI_SOURCE"
else
    SRC="$(mktemp -d)"
    trap 'rm -rf "$SRC"' EXIT
    printf 'Fetching the %s branch of Blizzard'"'"'s UI source...\n' "$GAME"
    if ! git clone --quiet --depth 1 --branch "$GAME" "$MIRROR" "$SRC"; then
        printf 'Could not fetch %s (%s).\n' "$MIRROR" "$GAME" >&2
        exit 2
    fi
fi

ADDONS="$SRC/Interface/AddOns"
if [ ! -d "$ADDONS" ]; then
    printf 'No Interface/AddOns under %s.\n' "$SRC" >&2
    exit 2
fi

# The files move between Mainline/ and Classic/ directories from game to game, so they are
# found by name. An empty result fails every check that reads the file.
find_one() { find "$ADDONS" -name "$1" -path "*$2*" | head -n 1; }

ALERTS_LUA="$(find_one AlertFrames.lua Blizzard_FrameXML)"
ALERTS_XML="$(find_one AlertFrames.xml Blizzard_FrameXML)"
SYSTEMS_XML="$(find_one AlertFrameSystems.xml Blizzard_FrameXML)"
SYSTEMS_LUA="$(find_one AlertFrameSystems.lua Blizzard_FrameXML)"
PANELS_LUA="$(find_one UIParentPanelManager.lua Blizzard_UIParentPanelManager)"
EDITMODE_LUA="$(find_one EditModeManager.lua Blizzard_EditMode)"

printf '\nLootToastMover against Blizzard UI source: %s\n\n' "$GAME"

echo 'Where alerts are anchored'
present 'AlertFrame exists and is an alert container' "$ALERTS_XML" \
    '<Frame name="AlertFrame" mixin="AlertFrameMixin" inherits="AlertContainerTemplate">' \
    'The addon re-anchors the global AlertFrame; without it there is nothing to move.'
present 'AlertFrame is 10 by 10' "$ALERTS_XML" '<Size x="10" y="10"/>' \
    'The first toast sits a fixed distance above AlertFrame; a different size moves it off the box.'
present 'the container lays out through UpdateAnchors' "$ALERTS_LUA" \
    'function AlertContainerMixin:UpdateAnchors()' \
    'The addon hooks AlertFrame:UpdateAnchors to put AlertFrame back on the box after every pass.'
present 'a new alert goes through UpdateAnchors' "$ALERTS_LUA" 'self:UpdateAnchors();' \
    'If alerts stop calling it, the hook stops firing and toasts drift back to Blizzard'"'"'s spot.'

echo 'How alerts stack'
present 'queued alerts stack upward, BOTTOM to TOP, 10 apart' "$ALERTS_LUA" \
    'alertFrame:SetPoint("BOTTOM", relativeAlert, "TOP", 0, 10);' \
    'Stacking downward mirrors exactly this link; a different one would be left unmirrored.'
present 'self-placing frames start BOTTOM to BOTTOM' "$ALERTS_LUA" \
    '["CENTER"] = { point = "BOTTOM", relativePoint = "BOTTOM" },' \
    'The box lines its bottom edge up with AlertFrame'"'"'s so the first alert lands on it.'
present 'and continue BOTTOM to TOP' "$ALERTS_LUA" \
    '["CENTER"] = { point = "BOTTOM", relativePoint = "TOP" },' \
    'Stacking downward recognises a link by BOTTOM-to-TOP.'
present 'the container keeps its subsystems in alertFrameSubSystems' "$ALERTS_LUA" \
    'self.alertFrameSubSystems = {};' \
    'Stacking downward walks this list to find the frames on screen.'
present 'a queue keeps its frames in alertFramePool' "$ALERTS_LUA" \
    'self.alertFramePool = CreateFramePool(' \
    'Stacking downward reads the active frames from alertFramePool:EnumerateActive().'
present 'self-placing frames are AlertFrameAutoAnchoredMixin' "$ALERTS_LUA" \
    'function AlertFrameAutoAnchoredMixin:AdjustAnchors(relativeAlert)' \
    'This is how a frame the alert system places is told from one it only passes through.'
present 'and keep their frame in anchorFrame' "$ALERTS_LUA" 'self.anchorFrame = anchorFrame;' \
    'Stacking downward reads the frame from system.anchorFrame.'

echo 'The loot toast'
present 'the loot toast is 276 by 96' "$SYSTEMS_XML" '<Size x="276" y="96"/>' \
    'The anchor box is drawn at the toast'"'"'s size so it shows where one will land.'
present 'the toast template is LootWonAlertFrameTemplate' "$SYSTEMS_XML" \
    'name="LootWonAlertFrameTemplate"' \
    'The size above is read from this template.'
present 'LootAlertSystem is the loot toast queue' "$SYSTEMS_LUA" \
    'LootAlertSystem = AlertFrame:AddQueuedAlertFrameSubSystem("LootWonAlertFrameTemplate"' \
    '/ltm test fires its sample through LootAlertSystem:AddAlert.'

echo 'The rest of the client'
present 'Escape hides the frames named in UISpecialFrames' "$PANELS_LUA" \
    'for index, value in pairs(UISpecialFrames) do' \
    'The anchor box adds its name to this list so that Escape hides it.'
absent 'nothing hands AlertFrame to a managed-frame container' "$ADDONS" \
    'AddManagedFrame(AlertFrame' \
    'Something else now positions AlertFrame as well; check the addon still wins.'
if [ -n "$EDITMODE_LUA" ]; then
    present 'Edit Mode announces that it opened' "$EDITMODE_LUA" \
        'EventRegistry:TriggerEvent("EditMode.Enter");' \
        'The anchor box appears with Edit Mode by listening for this.'
    present 'and that it closed' "$EDITMODE_LUA" 'EventRegistry:TriggerEvent("EditMode.Exit");' \
        'The anchor box goes again by listening for this.'
else
    printf '  skip Edit Mode events (this game has no Edit Mode)\n'
fi
if [ "$COMPARTMENT" -eq 1 ]; then
    COMPARTMENT_XML="$(find_one AddonCompartment.xml Blizzard_Minimap)"
    present 'the Addon Compartment is a frame called AddonCompartmentFrame' "$COMPARTMENT_XML" \
        'name="AddonCompartmentFrame"' \
        'A first run hides the minimap button where this frame exists.'
else
    absent 'there is no Addon Compartment' "$ADDONS" 'AddonCompartmentFrame' \
        'This game gained a compartment: add it to the games that hide the minimap button by default.'
fi

printf '\n%d checked, %d failed\n' "$checked" "$failures"
[ "$failures" -eq 0 ]
