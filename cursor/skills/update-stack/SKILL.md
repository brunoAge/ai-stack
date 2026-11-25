---
name: update-stack
description: Syncs this repo's Cursor rules, skills and hook, Matt Pocock's skills and the pinned upstream Ponytail rule into ~/.cursor/ and ~/.agents/, showing the diff before writing, and checks for newer pins.
disable-model-invocation: true
---

# Update stack

Run when the user asks for `/update-stack`. Fetch, show the diff and stop. Write only after an explicit ok (`yes`, `ok`, `go ahead`, `sim`, `pode gravar`). A partial ok replaces the list: write only what it confirmed.

Repo: the open workspace has `install.sh` and `cursor/rules/workflow-preferences.mdc`. If it does not, ask the user for the path of their `ai-stack` checkout. Without a repo, skip the repo part of the report; Matt and Ponytail still run.

## 1. Fetch

Three sources. If a fetch this round needs fails: stop, name the source and write nothing.

1. **Matt.** Shallow clone of `https://github.com/mattpocock/skills.git` into a temp dir. Stable set = the skills listed in `.claude-plugin/plugin.json` of that clone (the `skills` array, read with `jq`; or `gh api repos/mattpocock/skills/contents/.claude-plugin/plugin.json`). Installed = keys of `~/.agents/.skill-lock.json` whose `source` is `mattpocock/skills`.
2. **Ponytail.** Raw bytes of the `PONYTAIL_URL` pinned in the repo's `install.sh`.
3. **Repo.** If the checkout has an `origin` remote, run `git fetch origin main` and read `origin/main`; otherwise read the working tree. Keep the temp dir: the ok reuses these bytes.

Done when this round's sources are on disk, or you stopped at the one that failed.

## 2. Diff

Build the report and stop. Write nothing in this step.

**Matt.** Three lists: new (in the stable set, not in the lock), not in Matt's list (in the lock, not in the stable set; never removed unless Bruno asks), changed (`diff -rq` between the clone and the installed folder). For each changed skill, paste the `SKILL.md` diff and list the other files.

**Ponytail.** Unified diff against `~/.cursor/rules/ponytail.mdc`. The repo does not keep a copy.

**Repo.** Map repo → machine:

| Repo | Machine |
| --- | --- |
| `cursor/rules/<name>.mdc` | `~/.cursor/rules/<name>.mdc` |
| `cursor/skills/<name>/` | `~/.agents/skills/<name>/` |
| `cursor/hooks.json` entry `rtk hook cursor` | entry in `~/.cursor/hooks.json` |

Unified diff for every file the ok may write. A missing machine file is listed as new. For the hook, report only whether the `rtk hook cursor` entry with matcher `Shell` is present; the ok adds that one entry and keeps every other hook. `~/.cursor/rules/model-slots.mdc` present: list it as "rename to `model-slots.mdc.bak`", part of the ok.

**Pins.** Latest upstream versions against the pins in `install.sh`:

- Ponytail: `gh api 'repos/DietrichGebert/ponytail/commits?path=.cursor/rules/ponytail.mdc&per_page=1' --jq '.[0].sha'`. If it differs from the pinned commit, show the unified diff of `ponytail.mdc` between the pinned and the latest commit.
- Skills CLI: `npm view skills version` against the `skills@<version>` in `install.sh`.

Propose bumping the pin in `install.sh`; edit it only after Bruno's ok.

Close the report with what the ok writes and what stays out. Nothing to write: say so and stop.

Done when the user has the report and no file was written.

## 3. Write

After the ok, in this order, with the bytes already fetched:

1. **Ponytail** to `~/.cursor/rules/ponytail.mdc` (and the bumped pin in `install.sh`, if confirmed).
2. **Matt**, only the names in the diff. Remove one only when Bruno asks (`npx --yes skills@<pinned> remove <names> -g -y`). Update the ones that stayed (`npx --yes skills@<pinned> update -g -y <names>`). Add the new ones (`npx --yes skills@<pinned> add mattpocock/skills -g -a cursor -y -s <name>`, repeating `-s`).
3. **Repo** files. Single file: copy over the target. Directory: the target becomes that copy. Hook: add the entry with `jq`, keeping the rest of `~/.cursor/hooks.json`. Rename `model-slots.mdc` if it was in the ok.

Stop at the first failing command and say what already reached disk. Delete the temp dir. Do not commit or push.

Done when each item of the ok is on disk, or you stopped at the failure and listed what was written.

Close with what changed on the machine, what changed in the repo working tree, and that this chat still has the old rules loaded until a new chat starts. The commit is the user's.
