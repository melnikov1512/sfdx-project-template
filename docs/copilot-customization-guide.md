# Guide to GitHub Copilot Customization in This Repository

## Why This Document Exists

This repository already uses four GitHub Copilot customization mechanisms: custom
sub-agents, custom instructions, skills, and prompts. This document briefly explains
what each of these is, how they differ from one another, when to use which — and
separately calls out an important nuance about instruction inheritance by sub-agents.

## Overview of the 4 Mechanisms

| Mechanism               | Where It Lives                                                                           | When It Triggers                                                            | Example in This Repo                                 |
| ----------------------- | ---------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------- |
| **Custom Agents**       | `.github/agents/*.agent.md`                                                              | Explicit call / task delegation to a sub-agent                              | `.github/agents/gem-implementer.agent.md`            |
| **Custom Instructions** | `.github/copilot-instructions.md`, `AGENTS.md`, `.github/instructions/*.instructions.md` | Automatically: repo-wide — always; path-scoped — via `applyTo` glob         | `.github/instructions/apex-patterns.instructions.md` |
| **Skills**              | `.github/skills/<name>/SKILL.md`                                                         | Copilot decides on its own to load it when the task matches the description | `.github/skills/create-readme/SKILL.md`              |
| **Prompts**             | `.github/prompts/*.prompt.md`                                                            | Explicit invocation via slash command / prompt selection                    | `.github/prompts/create-exception-handler.prompt.md` |

## Custom Agents (`.github/agents/*.agent.md`)

Custom sub-agents are specialized versions of Copilot tailored to a specific role
(TDD implementation, review, debugging, documentation, etc.). They let you describe
an agent's expertise, tools, and workflow once, instead of repeating the same
instructions in chat every time.

An agent is defined by a Markdown file with YAML frontmatter. Example from this
repository (`.github/agents/gem-implementer.agent.md`):

```markdown
---
description: 'TDD code implementation — features, bugs, refactoring. Never reviews own work.'
name: gem-implementer
---

# Role

IMPLEMENTER: Write code using TDD (Red-Green-Refactor). Follow plan specifications...
```

Key frontmatter fields: `name` (optional — otherwise the filename is used) and
`description` (required — Copilot and other agents use it to decide when to invoke
this sub-agent). The body of the file typically describes: role, expertise,
knowledge sources, a step-by-step workflow, output format, and hard constraints
(constitutional rules).

In this repository, such agents live at the repo level (`.github/agents/*.agent.md`)
— the gem-agents (`gem-*`), as well as `api-architect`, `context-architect`,
`critical-thinking`, `github-actions-expert`, and the orchestrator
`gem-orchestrator`, which delegates tasks to the others.

📖 Official documentation: [About custom agents](https://docs.github.com/en/copilot/concepts/agents/cloud-agent/about-custom-agents).

## Custom Instructions (`copilot-instructions.md`, `AGENTS.md`, `*.instructions.md`)

Custom instructions give Copilot context about the project: conventions,
architecture, what is and isn't allowed. This repository uses three kinds:

- **`.github/copilot-instructions.md`** — repo-wide instructions, applied to all
  requests in the context of the repository (response style, planning rules,
  labels, etc.).
- **`AGENTS.md`** (at repo root) — another repo-wide/agent-level instructions file;
  Copilot and third-party agents read the nearest `AGENTS.md` up the directory tree.
- **`.github/instructions/*.instructions.md`** — path-scoped instructions: applied
  only to files matching the glob pattern in the `applyTo` frontmatter field. For
  example, `.github/instructions/apex-patterns.instructions.md` applies only when
  editing `.cls`/`.trigger` files; `readme-maintenance.instructions.md` triggers on
  changes to `README.md`, `package.json`, `.github/agents/**`, and similar paths:

```markdown
---
applyTo: 'README.md,.gitlab-ci.yml,package.json,sfdx-project.json,eslint.config.js,jest.config.js,.prettierrc,.github/agents/**,.github/instructions/**,.github/skills/**,.github/prompts/**'
---

After changing this file, check whether `README.md` needs to be updated...
```

If the path of the file being edited matches several `*.instructions.md` files at
once, and `copilot-instructions.md` also exists — instructions from **all**
matching files apply simultaneously (they are not mutually exclusive).

📖 Official documentation: [Adding repository custom instructions for GitHub Copilot](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions).

## Skills (`.github/skills/**`)

Skills are folders containing instructions (`SKILL.md`) and, optionally, additional
resources (scripts, templates, reference markdown files) that Copilot loads on
demand when a task matches the skill's description. Unlike custom instructions, a
skill is not automatically applied to every request — the agent decides for itself
whether it's relevant to the current task, based on the `description` field.

Example from this repository (`.github/skills/create-readme/SKILL.md`):

```markdown
---
name: create-readme
description: 'Create a README.md file for the project'
---

## Role

You are a senior software engineer... creating clear and well-structured READMEs.
```

The repository includes both skills for Salesforce/documentation
(`create-readme`, `create-implementation-plan`, `architecture-blueprint-generator`,
`refactor-plan`, `refactor-method-complexity-reduce`), and skills for external
integrations (`gh-cli`, `github-issues`, `my-issues`, `my-pull-requests`,
`tavily-*` — web search, content extraction, crawling, research).

📖 Official documentation: [Adding agent skills for GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills).

## Prompts (`.github/prompts/*.prompt.md`)

Prompts are ready-made, reusable requests for solving a specific, often recurring
task (for example, "create an exception-handling service following the standard
template"). Unlike skills, a prompt is invoked explicitly — via a slash command or
selection from a list, rather than by the agent's own decision.

Example from this repository (`.github/prompts/create-exception-handler.prompt.md`):

```markdown
---
mode: agent
description: Create ExceptionHandlingService if one does not exist in the project
---

Create `ExceptionHandlingService` in `force-app/main/default/classes/services/`.

## Step 1 — Check for existing implementation

...
```

A prompt file's frontmatter typically contains `mode` (e.g., `agent`) and
`description`, while the body contains a detailed step-by-step execution scenario,
constraints, and a usage example.

📖 Official documentation: [Prompt files](https://docs.github.com/en/copilot/tutorials/customization-library/prompt-files).

---

> ⚠️ **Important: custom instructions are not automatically inherited by sub-agents**
>
> `copilot-instructions.md`, `AGENTS.md`, and `.github/instructions/*.instructions.md`
> are automatically loaded only in the **main** Copilot session, where you interact
> with it directly. When the main agent (or an orchestrator, e.g.
> `gem-orchestrator`) **delegates** a task to a sub-agent — via a delegation tool
> (Task tool / custom agent invocation) — the sub-agent runs in a **separate
> context** and does **not automatically receive** the contents of
> `copilot-instructions.md`, `AGENTS.md`, or path-scoped `*.instructions.md` files.
> A sub-agent only sees what is explicitly:
>
> 1. written inside its own `.agent.md` file (frontmatter + body), or
> 2. passed to it directly in the invocation prompt at the time of delegation.
>
> **Practical implication:** if a rule is critical for a specific sub-agent —
> naming conventions, security constraints, forbidden actions ("never commit",
> "don't create files outside `docs/plans/`", etc.) — it **must be duplicated**
> directly inside that sub-agent's `.agent.md` file (see, for example, the
> "Constitutional" / "Rules" / "Anti-Patterns" sections in
> `.github/agents/gem-implementer.agent.md` and other `gem-*.agent.md` files) or
> explicitly included in the text of the delegating prompt. You cannot rely on a
> sub-agent "automatically" reading `AGENTS.md` or `copilot-instructions.md` — that
> is an incorrect assumption that leads to sub-agents violating project
> conventions.

## What to Choose: Decision Table

| Scenario                                                                                           | What to Use                                                                                          |
| -------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Copilot should always follow response style and repository-wide rules                              | `copilot-instructions.md` / `AGENTS.md`                                                              |
| A rule that applies only to files of a certain type/path (`.cls`, LWC, `scripts/**`)               | `.github/instructions/*.instructions.md` with `applyTo`                                              |
| Need a specialized "colleague" with its own role and expertise (reviewer, debugger, planner)       | `.github/agents/*.agent.md`                                                                          |
| A critical rule that a specific sub-agent **must** follow when delegated to                        | Duplicate it in the agent's `.agent.md` or in the delegation prompt text — don't rely on `AGENTS.md` |
| Need a reusable but not always-needed procedure/playbook with extra resources (scripts, templates) | `.github/skills/<name>/SKILL.md`                                                                     |
| Need a ready-made template/command for a specific, often recurring one-off task                    | `.github/prompts/*.prompt.md`                                                                        |

## Links to Official Documentation

- Custom instructions — [Adding repository custom instructions for GitHub Copilot](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions)
- Custom agents — [About custom agents](https://docs.github.com/en/copilot/concepts/agents/cloud-agent/about-custom-agents)
- Prompt files — [Prompt files](https://docs.github.com/en/copilot/tutorials/customization-library/prompt-files)
- Skills — [Adding agent skills for GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills)
