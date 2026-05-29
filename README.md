# protops-skills

Personal Claude Code skills marketplace.

## Plugins

| Plugin | What it does |
|---|---|
| [check-consistency](plugins/check-consistency/) | Review a git diff against inferred repo patterns and universal best practices. Flags inconsistencies, sloppy comments, lazy / over-engineered code, and hardcoded paths. |
| [rubber-duck](plugins/rubber-duck/) | Structured rubber-duck debugging — forces articulating the problem before any solution is proposed. |
| [standup](plugins/standup/) | Daily standup summary from git activity — 3-bullet Yesterday / Today / Blockers. |
| [bank-jargon](plugins/bank-jargon/) | Personal banking / software / AI terminology notebook. Maintains a glossary at `~/.claude/data/bank-jargon/glossary.md`. |
| [safe-commit](plugins/safe-commit/) | Commit safety layer — secret scanning, identity verification, commit hygiene. Blocks commits with secrets / sensitive files / hardcoded paths / merge markers. After a clean commit, reminds you to run `/me:check-consistency`. |

## Hook-only plugins (installed separately, not in the `me` bundle)

Hooks can't live inside a skill bundle, so these install on their own.

| Plugin | What it does |
|---|---|
| [alert-sounds](plugins/alert-sounds/) | UserPromptSubmit / Stop / Notification / PermissionRequest hooks that play distinct sounds, flash the taskbar, and tint the statusline. Per-event config at `hooks/config.json`. Fork of `mk-cc-all:alert-sounds`. |
| [next-step](plugins/next-step/) | Tiny UserPromptSubmit hook that injects a `**Next:**` directive into every prompt so Claude ends each response with a copy-pasteable slash command. Standalone alternative to `mk-flow`'s much bigger `intent-inject.sh`. |

Install:
```bash
claude plugin install alert-sounds@protops-skills
claude plugin install next-step@protops-skills
```

## Install

All skills install under the `me:` namespace. The bundle exposes both:
- **Skills** (auto-trigger on natural language) — e.g. saying "review my diff" fires `me:check-consistency`.
- **Slash commands** (manual `/`-autocomplete) — e.g. `/me:check-consistency`, `/me:rubber-duck`, `/me:standup`, `/me:bank-jargon`, `/me:safe-commit`.

### From GitHub (once published)

```bash
claude plugin marketplace add github:pprotops/protops-skills

# Recommended: install the bundle (all 5 skills under the `me:` namespace)
claude plugin install me@protops-skills

# Or cherry-pick a single plugin (bare slash command, no `me:` prefix)
claude plugin install check-consistency@protops-skills
```

### From a local checkout (development)

```bash
claude plugin marketplace add /path/to/protops-skills
claude plugin install me@protops-skills
```

## Layout

```
protops-skills/
├── .claude-plugin/
│   ├── marketplace.json      # marketplace metadata + plugin list
│   └── plugin.json           # bundle plugin (installs all skills at once)
├── plugins/
│   └── <plugin>/
│       ├── .claude-plugin/plugin.json
│       └── skills/<plugin>/SKILL.md
└── README.md
```
