<div align="center">

# Salesforce DX Project Template

[![PR Check](https://github.com/melnikov1512/sfdx-project-template/actions/workflows/pr-check.yml/badge.svg)](https://github.com/melnikov1512/sfdx-project-template/actions/workflows/pr-check.yml)
[![Security Gates](https://github.com/melnikov1512/sfdx-project-template/actions/workflows/security-gates.yml/badge.svg)](https://github.com/melnikov1512/sfdx-project-template/actions/workflows/security-gates.yml)
![Salesforce API](https://img.shields.io/badge/Salesforce_API-v66.0-00A1E0)
![Node.js](https://img.shields.io/badge/Node.js-20%2B-339933)

_Production-ready Salesforce DX starter with quality tooling, CI/CD, and GitHub Copilot AI built in_

[Getting Started](#getting-started) • [Commands](#commands) • [CI/CD](#cicd-pipelines) • [Copilot Integration](#github-copilot-integration) • [Troubleshooting](#troubleshooting)

</div>

Clone this template, add your metadata to `force-app/`, configure the `SF_AUTH_URL` secret, and you're ready to ship. Everything else — linting, formatting, testing, security gates, deployments, and AI-assisted code review — is already wired up.

## What's included

- **Linting** — ESLint flat config for LWC and Aura JS (`@salesforce/eslint-config-lwc`)
- **Formatting** — Prettier with Apex and XML plugins; 4-space indent for all code files; enforced in CI and on pre-commit
- **LWC unit tests** — `@salesforce/sfdx-lwc-jest` with watch, debug, and coverage modes
- **Apex SAST** — `sf code-analyzer` (SARIF output) on every PR; blocks on `error`-level findings
- **Pre-commit hooks** — Husky + lint-staged: format → lint → related LWC tests, automatically
- **CI pipelines** — PR checks, metadata validate-only gate, security scanning, AI PR summaries, and guarded manual deploys
- **GitHub Copilot** — 18 custom agents, 4 instruction files, 19 skills, and prompt files pre-wired under `.github/`

## Prerequisites

| Requirement                                                                   | Version / Notes                                    |
| ----------------------------------------------------------------------------- | -------------------------------------------------- |
| [Node.js](https://nodejs.org)                                                 | 20+                                                |
| [Salesforce CLI (`sf`)](https://developer.salesforce.com/tools/salesforcecli) | Latest; required for Apex tests and org operations |
| Authenticated Salesforce org                                                  | Required for `test:apex` and deploy commands       |
| `SF_AUTH_URL` repository secret                                               | Required for CI metadata validation                |

## Getting started

```bash
# 1. Install dependencies
npm install

# 2. Authenticate your org
sf org login web --alias my-org --set-default

# 3. Run full local validation
npm run validate
```

> [!NOTE]
> `test:apex` is skipped gracefully when no `@isTest` classes exist, `sf` is not installed, or no default org is configured — no false failures on a fresh clone.

## Project structure

```
sfdx-project-template/
├── force-app/
│   └── main/default/          # Add your Salesforce metadata here
├── config/
│   └── project-scratch-def.json
├── docs/
│   └── plans/                 # Implementation plans
├── scripts/
│   └── deploy.js              # Local deploy helper (mirrors deploy.yml)
├── .github/
│   ├── agents/                # 18 Copilot custom agents
│   ├── instructions/          # Auto-applied Copilot instruction files
│   ├── prompts/               # Reusable Copilot prompt files
│   ├── skills/                # 19 on-demand Copilot skills
│   └── workflows/             # CI/CD pipeline definitions
├── sfdx-project.json          # API v66.0, package dir: force-app
├── .prettierrc                # Prettier config: 4-space indent, Apex + XML plugins
├── eslint.config.js
├── jest.config.js
└── package.json
```

## Commands

### Daily development

| Command                     | Description                               |
| --------------------------- | ----------------------------------------- |
| `npm run lint`              | ESLint for LWC/Aura JS                    |
| `npm run prettier`          | Format all supported files in-place       |
| `npm run prettier:verify`   | Check formatting without writing          |
| `npm run test:lwc`          | Run LWC Jest tests                        |
| `npm run test:lwc:watch`    | Jest in watch mode                        |
| `npm run test:lwc:coverage` | Jest with coverage report                 |
| `npm run test:apex`         | Run Apex tests on connected org           |
| `npm run test`              | LWC CI + Apex tests                       |
| `npm run validate`          | Lint + format check + LWC CI + Apex tests |
| `npm run lint:apex`         | Salesforce SAST via `sf code-analyzer`    |

### Scratch org workflow

```bash
# Create a scratch org and set it as default
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias dev \
  --duration-days 30 \
  --set-default

# Deploy source
sf project deploy start --source-dir force-app

# Open in browser
sf org open
```

## CI/CD pipelines

| Workflow                      | Trigger                      | What it does                                                        |
| ----------------------------- | ---------------------------- | ------------------------------------------------------------------- |
| `pr-check.yml`                | PR → `main`                  | Lint, format check, LWC tests, Apex SAST, metadata validate-only    |
| `security-gates.yml`          | PR + push `main` + weekly    | Secret scanning, dependency audit (blocks on `high`/`critical`)     |
| `ai-pr-summary.yml`           | PR opened/updated            | AI-generated PR summary via GitHub Models (`gpt-4o-mini`)           |
| `ai-test-recommendations.yml` | PR opened/updated            | AI-suggested test improvements                                      |
| `codeql.yml`                  | PR + push `main`             | CodeQL static analysis                                              |
| `deploy.yml`                  | Manual (`workflow_dispatch`) | Deploy any branch to `staging` or `production` with a validate gate |

> [!IMPORTANT]
> Metadata validation in CI requires the `SF_AUTH_URL` repository secret. PRs that touch `force-app/` (or the path set in `SFDX_METADATA_DIR`) will fail explicitly if the secret is absent.

> [!TIP]
> Set the optional repository variable `SFDX_METADATA_DIR` to change the metadata root without modifying any code. Defaults to `force-app`.

## Deployment

Deployments to `staging` and `production` are triggered manually via **Actions → Deploy → Run workflow**.

- A validate-only gate always runs before the actual deploy.
- The `production` environment requires Required Reviewers and enforces a `main`-only branch policy.
- For rollback steps, see `RUNBOOK.md` §17.

## GitHub Copilot integration

The `.github/` directory ships a complete Copilot workspace setup:

**Instruction files** — auto-applied context scoped by file pattern:

| File                             | Applies to                             |
| -------------------------------- | -------------------------------------- |
| `apex-patterns.instructions.md`  | Apex classes and triggers              |
| `lwc-patterns.instructions.md`   | LWC JS, HTML, and CSS                  |
| `unit-tests.instructions.md`     | Apex test classes                      |
| `salesforce-cli.instructions.md` | `sfdx-project.json`, config, manifests |

**Custom agents** — 18 specialized sub-agents including `gem-apex-specialist`, `gem-lwc-specialist`, `gem-sf-data-architect`, `gem-orchestrator`, `gem-implementer`, `gem-reviewer`, `gem-debugger`, and more.

**Skills** — 19 on-demand workflows: `create-implementation-plan`, `refactor-plan`, `architecture-blueprint-generator`, `github-issues`, Tavily search/research/crawl, and more.

**Prompt files** — reusable prompts for common Salesforce tasks (e.g., `create-exception-handler`).

## Troubleshooting

For common issues — bootstrap failures, lint false negatives, Apex test skips, CI metadata validation failures, and security exception lifecycle — see **`RUNBOOK.md`**.
