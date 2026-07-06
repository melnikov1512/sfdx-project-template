# Salesforce DX Project Template

[![PR Check](https://github.com/melnikov1512/sfdx-project-template/actions/workflows/pr-check.yml/badge.svg)](https://github.com/melnikov1512/sfdx-project-template/actions/workflows/pr-check.yml)
[![Security Gates](https://github.com/melnikov1512/sfdx-project-template/actions/workflows/security-gates.yml/badge.svg)](https://github.com/melnikov1512/sfdx-project-template/actions/workflows/security-gates.yml)
![API Version](https://img.shields.io/badge/Salesforce_API-v66.0-00A1E0)
![Node](https://img.shields.io/badge/Node.js-20%2B-339933)

A production-ready Salesforce DX project template with Node-based quality tooling, CI/CD pipelines, and GitHub Copilot AI integration baked in. Clone, configure secrets, and start shipping metadata.

## What's included

- **Linting** — ESLint flat config for Aura, LWC, and Jest mocks (`@salesforce/eslint-config-lwc`)
- **Formatting** — Prettier with Apex and XML plugins; enforced in CI and on pre-commit
- **LWC unit tests** — `@salesforce/sfdx-lwc-jest` with watch, debug, and coverage modes
- **Apex SAST** — `sf code-analyzer` (SARIF output) on every PR; blocks on `error`-level findings
- **Pre-commit hooks** — Husky + lint-staged: format → lint → related LWC tests
- **CI pipelines** — PR checks, Salesforce metadata validate-only, security gates, AI PR summaries, automated releases, and manual deploy to staging/production
- **GitHub Copilot** — custom agents, instruction files, skills, and prompt files pre-configured under `.github/`

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| Node.js 20+ | Required |
| npm | Required |
| [Salesforce CLI (`sf`)](https://developer.salesforce.com/tools/salesforcecli) | Required for Apex tests and org operations |
| Authenticated default org | For `test:apex` and deploy commands |
| `SF_AUTH_URL` repository secret | For CI metadata validation |

## Getting started

```bash
# 1. Install dependencies
npm install

# 2. Authenticate your org (browser login)
sf org login web --alias my-org --set-default

# 3. Run full local validation
npm run validate
```

> [!NOTE]
> `test:apex` is skipped gracefully if no `@isTest` classes are found, `sf` is not installed, or no default org is configured. No false failures in a fresh template.

## Project structure

```
sfdx-project-template/
├── force-app/               # Salesforce source root (deploy target)
│   └── main/default/        # Standard metadata directories go here
├── config/
│   └── project-scratch-def.json   # Scratch org definition
├── .github/
│   ├── agents/              # Copilot custom agents (gem-*, context-architect, …)
│   ├── instructions/        # Auto-applied Copilot instruction files
│   ├── prompts/             # Copilot prompt files
│   ├── skills/              # Copilot skills (tavily, gh-cli, refactor, …)
│   └── workflows/           # CI/CD pipelines
├── sfdx-project.json        # SFDX config — API v66.0, package dir: force-app
├── eslint.config.js         # ESLint flat config
├── jest.config.js           # LWC Jest config
└── package.json             # npm scripts and lint-staged config
```

## Commands

### Daily development

| Command | What it does |
|---------|-------------|
| `npm run lint` | ESLint for Aura/LWC JS |
| `npm run prettier` | Format all supported files |
| `npm run test:lwc` | Run LWC Jest tests |
| `npm run test:lwc:watch` | Jest in watch mode |
| `npm run test:lwc:coverage` | Jest with coverage report |
| `npm run test:apex` | Run Apex tests on connected org |
| `npm run test` | LWC CI + Apex tests |
| `npm run validate` | lint + prettier check + LWC CI + Apex tests |
| `npm run lint:apex` | Salesforce SAST via `sf code-analyzer` |

### Scratch org

```bash
# Create and set as default
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias dev \
  --duration-days 7 \
  --set-default

# Open in browser
sf org open

# Deploy source
sf project deploy start --source-dir force-app
```

## CI/CD pipelines

| Workflow | Trigger | What it does |
|----------|---------|-------------|
| `pr-check.yml` | Pull request → `main` | Lint, format check, LWC tests, Apex SAST, Salesforce metadata validate-only |
| `security-gates.yml` | PR + push `main` + weekly | Secret scanning, dependency audit (blocks on `high`/`critical`) |
| `ai-pr-summary.yml` | Pull request | AI-generated PR summary via GitHub Models (`gpt-4o-mini`) — no extra secrets |
| `ai-test-recommendations.yml` | Pull request | AI-suggested test improvements |
| `codeql.yml` | PR + push `main` | CodeQL analysis |
| `release.yml` | Push → `main` | Creates/updates Release PR via `release-please` |
| `deploy.yml` | Manual (`workflow_dispatch`) | Deploy to `staging` or `production` with validate gate |

> [!IMPORTANT]
> Metadata validation in CI requires the `SF_AUTH_URL` repository secret. If metadata changes are detected in a PR but the secret is missing, the check fails with an explicit error.

> [!TIP]
> Set the optional repository variable `SFDX_METADATA_DIR` to override the metadata root without changing code. Defaults to `force-app`.

## Deployment

Deployments to `staging` and `production` are triggered manually via **Actions → Deploy → Run workflow**.

- A validate-only gate always runs before the actual deploy.
- The `production` environment requires Required Reviewers and enforces a `main`-only branch policy.
- For rollback procedures, see `RUNBOOK.md` Section 17.

## Releasing

This project uses [release-please](https://github.com/googleapis/release-please) with [Conventional Commits](https://www.conventionalcommits.org/):

| Commit type | Version bump |
|-------------|-------------|
| `fix:` | PATCH |
| `feat:` | MINOR |
| `feat!:` / `BREAKING CHANGE:` | MAJOR |

Merging the Release PR created by `release-please` publishes a tag and GitHub Release. `CHANGELOG.md` is maintained automatically — do not edit manually.

## GitHub Copilot integration

The `.github/` directory contains a full Copilot setup:

- **Instruction files** — auto-applied context for Apex, LWC, unit tests, and Salesforce CLI based on file patterns
- **Custom agents** — specialized sub-agents: `gem-apex-specialist`, `gem-lwc-specialist`, `gem-sf-data-architect`, `gem-implementer`, `gem-reviewer`, `gem-debugger`, and more
- **Skills** — on-demand workflows: `create-implementation-plan`, `refactor-plan`, `architecture-blueprint-generator`, `github-issues`, Tavily web search, and more
- **Prompt files** — reusable prompts for common tasks (e.g. `create-exception-handler`)

## Troubleshooting

For common issues — bootstrap failures, lint false negatives, Apex test skips, CI metadata validation failures, and security exception lifecycle — see **`RUNBOOK.md`**.
