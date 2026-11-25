---
name: update-stack
description: Syncs this repo's Cursor rules, skills and hook, Matt Pocock's skills and the upstream Ponytail rule into ~/.cursor/, showing the diff before writing.
disable-model-invocation: true
---

# Update stack

Run when the user asks for `/update-stack`. Fetch, show the diff and stop. Write only after an explicit ok (`yes`, `ok`, `go ahead`, `sim`, `pode gravar`). A partial ok replaces the list: write only what it confirmed.

Repo: the open workspace has `install.sh` and `cursor/rules/workflow-preferences.mdc`. If it does not, ask the user for the path of their `ai-stack` checkout. Without a repo, skip the repo part of the report; Matt and Ponytail still run.

## 1. Fetch

Three sources. If a fetch this round needs fails: stop, name the source and write nothing.

1. **Matt.** Shallow clone of `https://github.com/mattpocock/skills.git` into a temp dir. Stable set = directories with `SKILL.md` under `skills/engineering` and `skills/productivity`. Installed = keys of `~/.agents/.skill-lock.json` whose `source` is `mattpocock/skills`.
2. **Ponytail.** Raw bytes of `https://raw.githubusercontent.com/DietrichGebert/ponytail/main/.cursor/rules/ponytail.mdc`.
3. **Repo.** If the checkout has an `origin` remote, run `git fetch origin main` and read `origin/main`; otherwise read the working tree. Keep the temp dir: the ok reuses these bytes.

Done when this round's sources are on disk, or you stopped at the one that failed.

## 2. Diff

Build the report and stop. Write nothing in this step.

**Matt.** Three lists: new (in the stable set, not in the lock), removed (in the lock, not in the stable set), changed (`diff -rq` between the clone and the installed folder). For each changed skill, paste the `SKILL.md` diff and list the other files.

**Ponytail.** Unified diff against `~/.cursor/rules/ponytail.mdc`. The repo does not keep a copy.

**Repo.** Map repo → machine:

| Repo | Machine |
| --- | --- |
| `cursor/rules/<name>.mdc` | `~/.cursor/rules/<name>.mdc` |
| `cursor/skills/<name>/` | `~/.cursor/skills/<name>/` |
| `cursor/hooks.json` entry `rtk hook cursor` | entry in `~/.cursor/hooks.json` |

Unified diff for every file the ok may write. A missing machine file is listed as new. For the hook, report only whether the `rtk hook cursor` entry with matcher `Shell` is present; the ok adds that one entry and keeps every other hook. `~/.cursor/rules/model-slots.mdc` present: list it as "rename to `model-slots.mdc.bak`", part of the ok.

Close the report with what the ok writes and what stays out. Nothing to write: say so and stop.

Done when the user has the report and no file was written.

## 3. Write

After the ok, in this order, with the bytes already fetched:

1. **Ponytail** to `~/.cursor/rules/ponytail.mdc`.
2. **Matt**, only the names in the diff. Remove the ones that left (`npx --yes skills@latest remove <names> -g -y`). Update the ones that stayed (`npx --yes skills@latest update -g -y <names>`). Add the new ones (`npx --yes skills@latest add mattpocock/skills -g -a cursor -y -s <name>`, repeating `-s`).
3. **Repo** files. Single file: copy over the target. Directory: the target becomes that copy. Hook: add the entry with `jq`, keeping the rest of `~/.cursor/hooks.json`. Rename `model-slots.mdc` if it was in the ok.

Stop at the first failing command and say what already reached disk. Delete the temp dir. Do not commit or push.

Done when each item of the ok is on disk, or you stopped at the failure and listed what was written.

Close with what changed on the machine, what changed in the repo working tree, and that this chat still has the old rules loaded until a new chat starts. The commit is the user's.
