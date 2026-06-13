# Ralph

[English](README.md) | [简体中文](README.zh-CN.md)

Ralph 是一个自动化 AI agent 循环，会反复启动 AI 编码工具，直到 PRD 中的所有条目都完成。每一轮都是一个全新的实例，拥有干净的上下文。跨轮记忆通过 git 历史、`progress.txt` 和 `prd.json` 持续保存。

这个 fork 保留了 Ralph 的工作流，并额外提供：

- `ralph.sh` 中的 Codex CLI 支持
- `ralph.sh` 中的 OpenCode 支持
- 面向 Codex、OpenCode、Amp、Claude Code 的统一安装器
- 可全局安装的 `prd` 与 `ralph` skills
- 实时监控：每轮输出实时落盘、迭代后 git status diff 提示，以及 `scripts/watch-ralph.sh` 监控面板

## 支持的工具

- Codex CLI
- OpenCode
- Amp
- Claude Code

## 前置要求

- 已安装并完成认证的 AI 编码工具之一
- 已安装 `jq`
- 一个 git 项目仓库

## 快速开始

为 Codex 全局安装 skills：

```bash
./install.sh --tool codex
```

将 skills 和 Ralph runner 一起安装到项目中：

```bash
./install.sh --tool codex --project /path/to/your-project
```

然后在 Codex 中：

```text
Use the prd skill to create a PRD for adding task priorities
Use the ralph skill to convert tasks/prd-task-priorities.md to scripts/ralph/prd.json
```

接着运行 Ralph：

```bash
cd /path/to/your-project/scripts/ralph
./ralph.sh --tool codex 10
```

在另一个终端实时查看进度：

```bash
./scripts/watch-ralph.sh --follow
```

## 安装

见 [docs/INSTALL.md](docs/INSTALL.md)。

## 演示

- 最小可跑示例：`examples/minimal/prd.json`
- 分步演示流程：`docs/DEMO.md`

## 工作流

### 1. 创建 PRD

使用 `prd` skill 生成详细的需求文档。

示例：

```text
Use the prd skill to create a PRD for a task priority system
```

### 2. 将 PRD 转换为 `prd.json`

使用 `ralph` skill 将 markdown PRD 转换成 Ralph 使用的 JSON 格式。

示例：

```text
Use the ralph skill to convert tasks/prd-task-priority-system.md to scripts/ralph/prd.json
```

### 3. 运行 Ralph

```bash
./scripts/ralph/ralph.sh --tool codex 10
```

Ralph 会：

1. 从 `prd.json` 读取目标分支
2. 选择优先级最高且 `passes: false` 的 story
3. 只实现这一条 story
4. 运行相关质量检查
5. 如果检查通过则提交
6. 更新 `prd.json`，将该 story 标记为完成
7. 把经验追加到 `progress.txt`
8. 持续重复，直到全部 story 完成或达到最大轮数

## 关键文件

| 文件 | 作用 |
|------|------|
| `ralph.sh` | 主循环执行器 |
| `CODEX.md` | Codex CLI 提示词模板 |
| `OPENCODE.md` | OpenCode 提示词模板 |
| `prompt.md` | Amp 提示词模板 |
| `CLAUDE.md` | Claude Code 提示词模板 |
| `skills/prd/` | 生成 PRD 的 skill |
| `skills/ralph/` | 把 PRD 转成 `prd.json` 的 skill |
| `install.sh` | 统一安装器 |
| `install-codex.sh` | Codex 兼容安装入口 |
| `install-opencode.sh` | OpenCode 兼容安装入口 |
| `prd.json.example` | Ralph 任务文件示例 |
| `scripts/watch-ralph.sh` | 当前 Ralph 任务的实时监控面板 |

## Codex 说明

- `ralph.sh` 会尽量在 git 仓库根目录运行 `codex exec`。
- 默认 Codex sandbox 为 `workspace-write`。
- 默认 Codex approval policy 为 `never`，更适合非交互式循环。
- Codex 默认使用你本机配置的模型，也可以通过 `--model` 或 `CODEX_MODEL` 覆盖。
- 可以用 `RALPH_CODEX_SANDBOX` 或 `--codex-sandbox` 覆盖 sandbox。
- 可以用 `RALPH_CODEX_APPROVAL` 或 `--codex-approval` 覆盖 approval policy。
- 完成判定通过匹配 `<promise>COMPLETE</promise>`。

## OpenCode 说明

- `ralph.sh` 会尽量在 git 仓库根目录运行 OpenCode
- OpenCode 执行前会隔离嵌套桌面会话环境变量，避免 `Session not found`
- 默认 OpenCode 模型为 `codexzh/gpt-5.4`
- 默认 OpenCode agent 为 `build`
- 完成判定通过匹配 `<promise>COMPLETE</promise>`

## 实时监控

Ralph 现在会把每一轮输出同时流式写入终端和单轮日志文件，并在工作树发生变化时打印迭代后的 `git status` diff，同时附带 `scripts/watch-ralph.sh` 监控面板：

```bash
./scripts/watch-ralph.sh           # 拍一次快照
./scripts/watch-ralph.sh --follow  # 每 5 秒刷新一次
```

面板会显示当前分支、未推送提交数、运行状态、当前 story、整体 PRD 进度、最近提交，以及最新 Ralph 输出的尾部内容。配合 Claude Code 时，`CLAUDE.md` 还会要求 agent 打印 `STORY`、`PLAN`、`EDITING`、`TEST`、`GIT` 等结构化日志标记，方便从实时流中跟踪进展。

## 为什么 Ralph 有效

### 每轮都是全新上下文

每一轮都会启动一个新的 agent 实例。跨轮保留的记忆只有：

- git 历史
- `progress.txt`
- `prd.json`

### Story 应该足够小

每个 story 都应该小到可以在单轮中完成。过大的 story 应按依赖关系或分层拆分。

### 反馈闭环很重要

Ralph 依赖类型检查、测试以及 UI story 的浏览器验证等反馈闭环。

## 兼容性说明

OpenCode 团队可以定义本地 `reviewer` 角色，但它通常应作为主编码 agent 的子代理使用，而不是直接通过 `opencode run --agent reviewer` 运行。
