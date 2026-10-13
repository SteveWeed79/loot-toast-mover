#!/bin/bash
# Sends LootToastMover's strings to the CurseForge translation tool for its project.
#
#   tools/upload_translations.sh english   the English phrases, and nothing else
#   tools/upload_translations.sh drafts    the English phrases, then this repository's draft
#                                          translation of each one, in every language CurseForge
#                                          translates
#
# English goes up with "DeletePhrase", so CurseForge holds exactly the phrases the addon has: a
# string removed here is removed there, translations and all. The release workflow sends it
# before every release, which is how a new string reaches the translators.
#
# The drafts go up with "DoNothing", which leaves other phrases alone but replaces whatever
# CurseForge already holds for the phrases it sends. That is right once, to give translators
# something to start from, and wrong after they have started, so the release never does it.
#
# Needs CF_API_KEY, a CurseForge API token for an account that manages the project, and lua5.1.
# The project id is read from the TOC.

set -euo pipefail

mode="${1:-}"
case "$mode" in
	english|drafts) ;;
	*) echo "usage: $0 <english|drafts>" >&2; exit 2 ;;
esac
: "${CF_API_KEY:?CF_API_KEY must hold a CurseForge API token}"

here="$(cd "$(dirname "$0")" && pwd)"
root="${LTM_ADDON_DIR:-$here/..}"
project="$(tr -d '\r' < "$root/LootToastMover.toc" | sed -n 's/^## X-Curse-Project-ID: *\([0-9][0-9]*\) *$/\1/p')"
if [ -z "$project" ]; then
	echo "No ## X-Curse-Project-ID in LootToastMover.toc" >&2
	exit 1
fi
endpoint="https://legacy.curseforge.com/api/projects/$project/localization/import"

phrases="$(mktemp)"
response="$(mktemp)"
trap 'rm -f "$phrases" "$response"' EXIT

upload() {
	local language="$1" handling="$2" status
	lua5.1 "$here/export_locale.lua" "$language" > "$phrases"
	printf 'Uploading %s: %d phrases, %s... ' "$language" "$(wc -l < "$phrases")" "$handling"
	status="$(curl -sS -0 -X POST -w '%{http_code}' -o "$response" \
		-H "X-Api-Token: $CF_API_KEY" \
		-F "metadata={\"language\": \"$language\", \"namespace\": \"\", \"formatType\": \"TableAdditions\", \"missing-phrase-handling\": \"$handling\"}" \
		-F "localizations=<$phrases" \
		"$endpoint")" || status="no response"
	if [ "$status" = 200 ]; then
		echo "done."
	else
		echo "failed ($status)."
		cat "$response" >&2 || true
		echo >&2
		exit 1
	fi
}

upload enUS DeletePhrase
if [ "$mode" = drafts ]; then
	# esMX is left to its translators: it already starts from the Spanish, CurseForge's
	# improvements included, so a copy of the Spanish drafts would only go stale there.
	for language in deDE esES frFR itIT koKR ptBR ruRU zhCN zhTW; do
		upload "$language" DoNothing
	done
fi
