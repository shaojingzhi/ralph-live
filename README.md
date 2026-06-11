# Ralph

[English](README.md) | [简体中文](README.zh-CN.md)

Ralph is an autonomous AI agent loop that runs AI coding tools repeatedly until all PRD items are complete. Each iteration is a fresh instance with clean context. Memory persists via git history, `progress.txt`, and `prd.json`.

This fork keeps the Ralph workflow and adds:

- Codex CLI support in `ralph.sh`
- OpenCode support in `ralph.sh`
- a unified installer for Codex, OpenCode, Amp, and Claude Code
- globally installable `prd` and `ralph` skills
- live monitoring: per-iteration log streaming, post-iteration git status diff, and a `scripts/watch-ralph.sh` dashboard

## Supported tools

- Codex CLI
- OpenCode
- Amp
- Claude Code

## Prerequisites

- One supported AI coding tool installed and authenticated
- `jq` installed
- A git repository for your project

## Quick start

Install skills globally for Codex:

```bash
./install.sh --tool codex
```

Install skills and the Ralph runner into a project:

```bash
./install.sh --tool codex --project /path/to/your-project
```

Then in Codex:

```text
Use the prd skill to create a PRD for adding task priorities
Use the ralph skill to convert tasks/prd-task-priorities.md to scripts/ralph/prd.json
```

Then run Ralph:

```bash
cd /path/to/your-project/scripts/ralph
./ralph.sh --tool codex 10
```

Watch progress live from a second terminal:

```bash
./scripts/watch-ralph.sh --follow
```

## Installation

See [docs/INSTALL.md](docs/INSTALL.md).

## Demo

- Minimal runnable example: `examples/minimal/prd.json`
- Step-by-step walkthrough: [docs/DEMO.md](docs/DEMO.md)

## Workflow

### 1. Create a PRD

Use the `prd` skill to generate a detailed requirements document.

Example:

```text
Use the prd skill to create a PRD for a task priority system
```

### 2. Convert the PRD to `prd.json`

Use the `ralph` skill to convert the markdown PRD into Ralph's JSON format.

Example:

```text
Use the ralph skill to convert tasks/prd-task-priority-system.md to scripts/ralph/prd.json
```

### 3. Run Ralph

```bash
./scripts/ralph/ralph.sh --tool codex 10
```

Ralph will:

1. Read the target branch from `prd.json`
2. Pick the highest priority story where `passes: false`
3. Implement that single story
4. Run relevant quality checks
5. Commit if checks pass
6. Update `prd.json` to mark the story complete
7. Append learnings to `progress.txt`
8. Repeat until all stories pass or max iterations is reached

## Key files

| File | Purpose |
|------|---------|
| `ralph.sh` | Main loop runner |
| `CODEX.md` | Prompt template for Codex CLI |
| `OPENCODE.md` | Prompt template for OpenCode |
| `prompt.md` | Prompt template for Amp |
| `CLAUDE.md` | Prompt template for Claude Code |
| `skills/prd/` | Skill for generating PRDs |
| `skills/ralph/` | Skill for converting PRDs to `prd.json` |
| `install.sh` | Unified installer for skills and project files |
| `install-codex.sh` | Compatibility wrapper for Codex installs |
| `install-opencode.sh` | Compatibility wrapper for OpenCode installs |
| `prd.json.example` | Example Ralph task file |
| `scripts/watch-ralph.sh` | Live monitoring dashboard for the current Ralph run |

## Codex notes

- `ralph.sh` runs `codex exec` from the git repo root when available.
- The default Codex sandbox is `workspace-write`.
- The default Codex approval policy is `never`, which is better for non-interactive loops.
- Codex uses your configured default model unless you pass `--model` or set `CODEX_MODEL`.
- You can override the sandbox with `RALPH_CODEX_SANDBOX` or `--codex-sandbox`.
- You can override approval with `RALPH_CODEX_APPROVAL` or `--codex-approval`.
- Completion is detected by matching `<promise>COMPLETE</promise>`.

## OpenCode notes

- `ralph.sh` runs OpenCode from the git repo root when available
- OpenCode runs are isolated from nested desktop session variables to avoid `Session not found`
- The default OpenCode model is `codexzh/gpt-5.4`
- The default OpenCode agent is `build`
- Completion is detected by matching `<promise>COMPLETE</promise>`

## Live monitoring

Ralph now streams each iteration's output to both the terminal and a per-iteration log, prints the post-iteration `git status` diff when the worktree changes, and ships a `scripts/watch-ralph.sh` dashboard:

```bash
./scripts/watch-ralph.sh           # one-shot snapshot
./scripts/watch-ralph.sh --follow  # refresh every 5 seconds
```

The dashboard shows the current branch, unpushed commits, run status, current story, overall PRD progress, recent commits, and the tail of the latest Ralph output. When using Claude Code, `CLAUDE.md` also requires the agent to print structured log markers such as `STORY`, `PLAN`, `EDITING`, `TEST`, and `GIT` so progress is readable from the live stream.

## Why Ralph works

### Each iteration uses fresh context

Every iteration starts a new agent instance. The only memory between iterations is:

- git history
- `progress.txt`
- `prd.json`

### Stories should stay small

Each story should be small enough to finish in a single focused iteration. Large stories should be split by dependency or layer.

### Feedback loops matter

Ralph depends on checks such as typecheck, tests, and browser verification for UI stories.

## Compatibility note

OpenCode teams can define a local `reviewer` role, but that role is typically used as a subagent by a main coding agent rather than as a direct `opencode run --agent reviewer` entrypoint.
