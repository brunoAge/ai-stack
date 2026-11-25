# ai-stack

My personal AI coding stack. Today it is Cursor CLI only; each tool gets its own folder (`cursor/`, later maybe `claude-code/`).

[Português (pt-BR)](#pt-br)

## What's in it

| Piece | What it does | Lives in |
|---|---|---|
| [Cursor CLI](https://cursor.com/docs/cli/overview) (`agent`) | The main agent | `~/.local/bin/agent` |
| [RTK](https://github.com/rtk-ai/rtk) (Rust Token Killer) | `preToolUse` hook that rewrites shell commands to cut tokens | `~/.cursor/hooks.json` ([`cursor/hooks.json`](cursor/hooks.json)) |
| [Matt Pocock's skills](https://github.com/mattpocock/skills) | On-demand procedures (`/ask-matt`, `/tdd`, `/grill-me`, ...). Installed by their own installer, not copied here | `~/.agents/skills/` |
| `ponytail.mdc` | Lazy senior dev mode: smallest complete change. Fetched at install time from [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail), pinned to a commit in `install.sh`, not copied here | `~/.cursor/rules/` |
| [`pt-br.mdc`](cursor/rules/pt-br.mdc) | Reply in Brazilian Portuguese to Portuguese; code and docs in the repo's language | `~/.cursor/rules/` |
| [`workflow-preferences.mdc`](cursor/rules/workflow-preferences.mdc) | Which model runs the chat and each subagent role, and the third-party budget | `~/.cursor/rules/` |
| [`update-stack`](cursor/skills/update-stack/SKILL.md) | `/update-stack`: syncs this repo and Ponytail into `~/.cursor/` and `~/.agents/`, diff first, and checks for newer pins; Matt's skills live in `~/.agents/skills/` | `~/.agents/skills/` |

## Install

```bash
git clone https://github.com/brunoAge/ai-stack.git && cd ai-stack
./install.sh
```

Requires `bash`, `curl`, `jq`, and Node.js (`npx`) for Matt's skills. The script is idempotent:

1. Installs Cursor CLI if `agent` is missing: `curl https://cursor.com/install -fsS | bash` ([docs](https://cursor.com/docs/cli/installation)). Log in with `agent login`.
2. Installs RTK if missing: `curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh` ([README](https://github.com/rtk-ai/rtk#installation)).
3. Adds `{"command": "rtk hook cursor", "matcher": "Shell"}` to `~/.cursor/hooks.json` with `jq`, keeping your other hooks (backup in `hooks.json.bak`). It does not run `rtk init -g --agent cursor` because that also writes `~/.claude/RTK.md`.
4. Installs Matt's skills if missing: `npx skills@1.9.0 add mattpocock/skills -g -a cursor -y` ([README](https://github.com/mattpocock/skills), [skills CLI](https://github.com/vercel-labs/skills)). Run `/setup-matt-pocock-skills` once per repo.
5. Copies `cursor/rules/*.mdc` into `~/.cursor/rules/` and `cursor/skills/` into `~/.agents/skills/`, and fetches `ponytail.mdc` from [upstream](https://raw.githubusercontent.com/DietrichGebert/ponytail/2a1fe842d078cf66ec7f3e6096a8ca4279c2cad7/.cursor/rules/ponytail.mdc), pinned to a commit. A file that differs shows a diff and asks before overwriting.
6. Offers to rename an old `~/.cursor/rules/model-slots.mdc` to `.bak` (replaced by `workflow-preferences.mdc`).

Self-check (syntax, shellcheck if installed, and the no-clobber logic against a temp dir): `./check.sh`.

## Update

In an agent chat opened in this repo, run `/update-stack`. It fetches Matt's skills (the list in his `plugin.json`; skills you have that are not in it are reported as "not in Matt's list", never removed unless you ask), the pinned Ponytail and this repo, shows the diff, reports newer versions of the Ponytail and `skills` pins, and writes only after you say ok. It never commits.

## How the model rule works

[`workflow-preferences.mdc`](cursor/rules/workflow-preferences.mdc):

- The parent chat stays on Grok (`grok-4.7`, effort high, Fast on) and dispatches: it plans, delegates and reviews.
- Roles are `Task` subagents with the model slug set on the call: `executor` → Composer 2.5 (Cursor pool); `researcher`, `reviewer`, `implementer` → Grok; `advisor` → `claude-opus-5-5-medium`.
- `other_models: open|closed` is the budget switch. Open: at most one third-party call per task, either the Opus advisor (approach not chosen, expensive undo) or Gemini Carbon: "ceiling" launches a `gemini-4-carbon-medium` subagent, while "ceiling" with "high" hands off a prompt for `gemini-4-carbon`, Effort high, instead of launching. Closed: no third-party launch and no hand-off; the parent answers on Grok, and a launch rejected for the spending limit stops and suggests `closed`.
- Asking for "high" gets a hand-off prompt for you to start the agent yourself. Fable, Sonnet and Hydrogen are not used.

Roles exist only in the rule: Cursor CLI reads declared agents (`.cursor/agents/`) at project level only, so there is no user-level agent file to install.

## References

- Cursor CLI: <https://cursor.com/docs/cli/overview>, hooks: <https://cursor.com/docs/hooks>, rules: <https://cursor.com/docs/context/rules>
- RTK: <https://github.com/rtk-ai/rtk>
- Matt Pocock's skills: <https://github.com/mattpocock/skills>, skills CLI: <https://github.com/vercel-labs/skills>
- Ponytail: <https://github.com/DietrichGebert/ponytail>
- Conventional Commits: <https://www.conventionalcommits.org/>

<a id="pt-br"></a>
## Português (pt-BR)

Minha stack pessoal de IA para programar, hoje só com o Cursor CLI. Cada ferramenta tem sua pasta (`cursor/`; um `claude-code/` pode entrar depois).

**O que tem:** Cursor CLI (`agent`) como agente principal; RTK (Rust Token Killer) como hook `preToolUse` que reescreve comandos shell para gastar menos tokens; as skills do Matt Pocock, instaladas pelo instalador oficial; três rules (`ponytail`, baixada do upstream na instalação, fixada num commit, `pt-br` e `workflow-preferences`); e a skill `/update-stack`.

**Instalar:** `./install.sh`. Precisa de `bash`, `curl`, `jq` e Node.js. Pode rodar de novo: o que já existe fica, e arquivo diferente mostra o diff e pergunta antes de sobrescrever. O hook do RTK entra no `~/.cursor/hooks.json` sem apagar os outros hooks. O `model-slots.mdc` antigo só é renomeado para `.bak` depois de você confirmar. Autoteste: `./check.sh`.

**Atualizar:** num chat do agente aberto neste repo, `/update-stack`. Usa a lista do `plugin.json` do Matt (skill instalada fora dela aparece como "not in Matt's list" e só sai se você pedir), mostra o diff, avisa se há versão nova dos pins (Ponytail e `skills`) e só grava depois do seu ok. A skill fica em `~/.agents/skills/update-stack/`. Não faz commit.

**Rule de modelos:** o chat principal fica no Grok (`grok-4.7`, effort high, Fast) e despacha. `executor` vai para o Composer 2.5; `researcher`, `reviewer` e `implementer` para o Grok; `advisor` para o `claude-opus-5-5-medium`. Com `other_models: open`, no máximo uma chamada de terceiro por tarefa: Opus (advisor) ou Gemini Carbon, nunca os dois. "Ceiling" escolhe o modelo (Carbon) e "high" escolhe o effort: ceiling sozinho lança um subagent `gemini-4-carbon-medium`; ceiling com high não lança nada e entrega o prompt para você rodar com `gemini-4-carbon`, Effort high. Com `closed`, nenhuma chamada nem entrega: responde no Grok e avisa que Opus e Carbon estão fechados. Se o limite de gasto rejeitar a chamada, para e sugere `closed`; outra rejeição também para, sem trocar de modelo. Os papéis existem só na rule, porque o Cursor CLI lê agentes declarados (`.cursor/agents/`) só no nível do projeto.

Links oficiais: seção [References](#references).
