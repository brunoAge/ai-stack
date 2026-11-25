#!/usr/bin/env bash
# Self-check: syntax, shellcheck when installed, and the no-clobber logic of install.sh
# against a throwaway CURSOR_HOME. Installs nothing.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash -n "$REPO/install.sh" "$REPO/check.sh"
if command -v shellcheck >/dev/null; then shellcheck "$REPO/install.sh" "$REPO/check.sh"; else echo "shellcheck not installed, skipped"; fi
jq -e . "$REPO/cursor/hooks.json" >/dev/null

CURSOR_HOME="$(mktemp -d)"
trap 'rm -rf "$CURSOR_HOME"' EXIT
export CURSOR_HOME
# shellcheck source=install.sh
source "$REPO/install.sh"

# Fresh home: files and hook get installed.
copy_stack_files >/dev/null
configure_rtk_hook >/dev/null
cmp -s "$REPO/cursor/rules/workflow-preferences.mdc" "$CURSOR_HOME/rules/workflow-preferences.mdc"
cmp -s "$REPO/cursor/skills/update-stack/SKILL.md" "$CURSOR_HOME/skills/update-stack/SKILL.md"
cmp -s "$REPO/cursor/hooks.json" "$CURSOR_HOME/hooks.json"

# A changed file and a foreign hooks.json are kept when the answer is no (stdin is not a terminal).
echo local >"$CURSOR_HOME/rules/pt-br.mdc"
echo '{"version":1,"hooks":{"stop":[{"command":"mine"}]}}' >"$CURSOR_HOME/hooks.json"
copy_stack_files </dev/null >/dev/null 2>&1
configure_rtk_hook </dev/null >/dev/null 2>&1
[[ $(cat "$CURSOR_HOME/rules/pt-br.mdc") == local ]]
jq -e '.hooks.stop[0].command == "mine" and (.hooks.preToolUse == null)' "$CURSOR_HOME/hooks.json" >/dev/null

# The merge expression keeps foreign hooks and adds the rtk one.
jq "$RTK_HOOK_MERGE" "$CURSOR_HOME/hooks.json" | jq -e '.hooks.stop[0].command == "mine" and .hooks.preToolUse[0].matcher == "Shell"' >/dev/null

# model-slots.mdc is not renamed without a yes.
touch "$CURSOR_HOME/rules/model-slots.mdc"
retire_model_slots </dev/null 2>/dev/null
[[ -e $CURSOR_HOME/rules/model-slots.mdc ]]

echo "check.sh: OK"
