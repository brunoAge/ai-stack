#!/usr/bin/env bash
# Installs the personal Cursor CLI stack. Safe to re-run: it skips what is
# already in place and asks before overwriting a file that differs.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURSOR_HOME="${CURSOR_HOME:-$HOME/.cursor}"
AGENTS_HOME="${AGENTS_HOME:-$HOME/.agents}"
export PATH="$HOME/.local/bin:$PATH"
PONYTAIL_URL=https://raw.githubusercontent.com/DietrichGebert/ponytail/2a1fe842d078cf66ec7f3e6096a8ca4279c2cad7/.cursor/rules/ponytail.mdc
RTK_HOOK_MERGE='.version //= 1 | .hooks.preToolUse = ((.hooks.preToolUse // []) + [{"command": "rtk hook cursor", "matcher": "Shell"}])'

log() { printf '==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

# ask "question" -> 0 on yes. Without a terminal it answers no.
ask() {
  local reply
  [[ -t 0 ]] || { warn "no terminal, answering no: $1"; return 1; }
  read -r -p "$1 [y/N] " reply
  [[ $reply =~ ^[Yy]$ ]]
}

# copy_file src dst: copies when missing, skips when identical, asks when different.
copy_file() {
  local src=$1 dst=$2
  if [[ ! -e $dst ]]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    log "installed $dst"
  elif cmp -s "$src" "$dst"; then
    log "unchanged $dst"
  else
    diff -u "$dst" "$src" || true
    if ask "Overwrite $dst with the diff above?"; then
      cp "$src" "$dst"
      log "updated $dst"
    else
      log "kept $dst"
    fi
  fi
}

install_cursor_cli() {
  if command -v agent >/dev/null; then
    log "Cursor CLI present ($(agent --version 2>/dev/null || echo unknown))"
  else
    log "installing Cursor CLI (https://cursor.com/docs/cli/installation)"
    curl https://cursor.com/install -fsS | bash
  fi
}

install_rtk() {
  # `rtk gain` fails on the unrelated crates.io "rtk", so it doubles as an identity check.
  if command -v rtk >/dev/null && rtk gain >/dev/null 2>&1; then
    log "RTK present ($(rtk --version))"
  else
    log "installing RTK (https://github.com/rtk-ai/rtk)"
    curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
  fi
}

# Adds the rtk entry to hooks.json and keeps every other hook. Done with jq
# instead of `rtk init -g --agent cursor`, which also writes ~/.claude/RTK.md.
configure_rtk_hook() {
  local hooks="$CURSOR_HOME/hooks.json" tmp
  mkdir -p "$CURSOR_HOME"
  if [[ ! -e $hooks ]]; then
    cp "$REPO/cursor/hooks.json" "$hooks"
    log "installed $hooks"
  elif jq -e '.hooks.preToolUse[]? | select(.command == "rtk hook cursor")' "$hooks" >/dev/null; then
    log "RTK hook present in $hooks"
  else
    tmp="$(mktemp)"
    jq "$RTK_HOOK_MERGE" "$hooks" >"$tmp"
    diff -u "$hooks" "$tmp" || true
    if ask "Add the RTK hook to $hooks?"; then
      cp "$hooks" "$hooks.bak"
      mv "$tmp" "$hooks"
      log "added RTK hook (backup: $hooks.bak)"
    else
      rm -f "$tmp"
    fi
  fi
}

install_matt_skills() {
  if [[ -d $AGENTS_HOME/skills/setup-matt-pocock-skills || -d $CURSOR_HOME/skills/setup-matt-pocock-skills ]]; then
    log "Matt Pocock skills present (update them with /update-stack)"
  elif ! command -v npx >/dev/null; then
    warn "npx not found: install Node.js, then run: npx skills@1.9.0 add mattpocock/skills -g -a cursor"
  else
    log "installing Matt Pocock skills (https://github.com/mattpocock/skills)"
    npx --yes skills@1.9.0 add mattpocock/skills -g -a cursor -y
  fi
}

copy_stack_files() {
  local src
  for src in "$REPO"/cursor/rules/*.mdc; do
    copy_file "$src" "$CURSOR_HOME/rules/$(basename "$src")"
  done
  while IFS= read -r -d '' src; do
    copy_file "$src" "$AGENTS_HOME/skills/${src#"$REPO/cursor/skills/"}"
  done < <(find "$REPO/cursor/skills" -type f -print0)
}

# Ponytail is fetched from upstream, not vendored, so it always matches the original.
install_ponytail() {
  local tmp
  tmp="$(mktemp)"
  if curl -fsSL "$PONYTAIL_URL" -o "$tmp"; then
    copy_file "$tmp" "$CURSOR_HOME/rules/ponytail.mdc"
  else
    warn "could not fetch $PONYTAIL_URL, ponytail.mdc not installed"
  fi
  rm -f "$tmp"
}

# workflow-preferences.mdc replaces model-slots.mdc; a .bak name keeps Cursor from loading it.
retire_model_slots() {
  local old="$CURSOR_HOME/rules/model-slots.mdc"
  [[ -e $old ]] || return 0
  if ask "Rename $old to model-slots.mdc.bak (replaced by workflow-preferences.mdc)?"; then
    mv "$old" "$old.bak"
    log "renamed $old"
  else
    warn "kept $old: it overlaps workflow-preferences.mdc"
  fi
}

main() {
  command -v jq >/dev/null || { warn "jq is required"; exit 1; }
  install_cursor_cli
  install_rtk
  configure_rtk_hook
  install_matt_skills
  copy_stack_files
  install_ponytail
  retire_model_slots
  log "done. Start a new agent chat to load the rules."
}

# Sourcing (as check.sh does) loads the functions without running the install.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
