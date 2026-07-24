<div style="text-align: center">

# Salesforce DX Project Template

![Salesforce API](https://img.shields.io/badge/Salesforce_API-v66.0-00A1E0)
![Node.js](https://img.shields.io/badge/Node.js-18.11%2B-339933)

_Production-ready Salesforce DX starter with quality tooling, CI/CD, and GitHub Copilot AI built in_

[Getting Started](#getting-started) • [Commands](#commands) • [CI/CD](#cicd-pipeline) • [Copilot Integration](#github-copilot-integration) • [Commit Policy](#commit-policy) • [Troubleshooting](#troubleshooting)

</div>

Clone this template, add your metadata to `force-app/`, configure the `SF_AUTH_URL` CI/CD variable, and you're ready to ship. Everything else — linting, formatting, testing, security gates, and deployments — is already wired up.

## What's included

- **Linting** — ESLint flat config for LWC and Aura JS (`@salesforce/eslint-config-lwc`)
- **Formatting** — Prettier with Apex and XML plugins; 4-space indent for all code files; enforced in CI and on pre-commit
- **LWC unit tests** — `@salesforce/sfdx-lwc-jest` with watch, debug, and coverage modes
- **Apex SAST** — `sf code-analyzer` (SARIF output) on every MR; blocks on `error`-level findings
- **Pre-commit hooks** — Husky + lint-staged: format → lint → related LWC tests, automatically
- **CI/CD pipeline** — MR checks, metadata validate-only gate, security scanning, and a guarded manual deploy job
- **GitHub Copilot** — 18 custom agents, 7 instruction files, 19 skills, and prompt files pre-wired under `.github/` (works locally regardless of git host)

## Prerequisites

| Requirement                                                                   | Version / Notes                                    |
| ----------------------------------------------------------------------------- | -------------------------------------------------- |
| [Node.js](https://nodejs.org)                                                 | 18.11+                                             |
| [Salesforce CLI (`sf`)](https://developer.salesforce.com/tools/salesforcecli) | Latest; required for Apex tests and org operations |
| Authenticated Salesforce org                                                  | Required for `test:apex` and deploy commands       |
| `SF_AUTH_URL` CI/CD variable                                                  | Required for CI metadata validation (protected + masked, scoped to environment `qa_org`) |

## Getting started

```bash
# 1. Clone the repo and install dependencies (uses package-lock.json as-is)
git clone https://git.vrpconsulting.com/artem.melnikov/sfdx-project-template.git
cd sfdx-project-template
npm ci

# 2. Authenticate your Dev Hub
sf org login web --alias devhub --set-default-dev-hub

# 3. Create a scratch org
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias dev \
  --duration-days 30 \
  --set-default

# 4. Deploy metadata to the scratch org
npm run deploy -- --target-org dev

# 5. Validate everything looks good
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
│   └── deploy.js              # Local deploy helper (mirrors the deploy pipeline jobs)
├── .github/
│   ├── agents/                # 18 Copilot custom agents
│   ├── instructions/          # Auto-applied Copilot instruction files
│   ├── prompts/               # Reusable Copilot prompt files
│   └── skills/                # 19 on-demand Copilot skills
├── .gitlab/
│   └── merge_request_templates/
│       └── Default.md         # MR template (security self-review, testing checklist)
├── .gitlab-ci.yml             # CI/CD pipeline definition
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
| `npm run deploy`            | Deploy to an org (see Local deploy below) |

### Scratch org workflow

```bash
# Create a scratch org and set it as default
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias dev \
  --duration-days 30 \
  --set-default

# Deploy source using the local deploy helper
npm run deploy -- --target-org dev

# Open in browser
sf org open
```

### Local deploy

`npm run deploy` is a thin wrapper around `sf project deploy start/validate` that saves results to `.artifacts/deploy/`.

```bash
# Deploy to an org (authenticated alias required)
npm run deploy -- --target-org <alias>

# Validate only — no actual deploy
npm run deploy -- --target-org <alias> --validate-only

# Deploy and run all local Apex tests
npm run deploy -- --target-org <alias> --tests

# Deploy a custom metadata directory
npm run deploy -- --target-org <alias> --source-dir force-app/main/default/classes

# Increase wait timeout (minutes, default: 30)
npm run deploy -- --target-org <alias> --wait 60
```

> [!NOTE]
> Results and logs are written to `.artifacts/deploy/results/`. For CI/CD-governed deploys to QA and higher envs, use the **GitLab CI/CD deploy pipeline** instead — see `RUNBOOK.md` §17.

## CI/CD pipeline

| Job                      | Trigger                                    | What it does                                                        |
| ------------------------ | ------------------------------------------- | --------------------------------------------------------------------|
| `lint_format_test`       | MR → `main`                                 | Lint, format check, LWC tests                                       |
| `code_analysis`          | MR → `main`                                 | Salesforce Apex/LWC/Aura SAST via `sf code-analyzer`                 |
| `salesforce_validate`    | MR → `main` (when `force-app/**` changes)   | Metadata validate-only against the `qa_org` environment              |
| `secret_scan`            | MR + push `main` + scheduled                | Gitleaks secret scanning (blocks on any finding)                     |
| `dependency_audit`       | MR + scheduled                              | `npm audit` dependency gate (blocks on `high`/`critical`)            |
| `deploy_validate_qa_org` | Manual (`Run pipeline` in UI)               | Validate-only deploy gate, runs automatically ahead of deploy        |
| `deploy_qa_org`          | Manual (`Run pipeline` in UI)               | Deploy to `qa_org`; skipped if `DRY_RUN=true` pipeline variable set   |

> [!IMPORTANT]
> Metadata validation in CI requires the `SF_AUTH_URL` CI/CD variable (protected + masked, scoped to environment `qa_org`). MRs that touch `force-app/` (or the path set in `SFDX_METADATA_DIR`) will fail explicitly if the variable is absent.

> [!TIP]
> Set the optional CI/CD variable `SFDX_METADATA_DIR` to change the metadata root without modifying any code. Defaults to `force-app`.

> [!NOTE]
> CodeQL SAST from the former GitHub Actions setup has no direct GitLab Free/Core equivalent and was not ported — see `RUNBOOK.md` §12 for the documented gap and mitigation options.

## Deployment

Deployments to QA and higher envs are triggered manually via **CI/CD → Pipelines → Run pipeline**.

- A validate-only gate (`deploy_validate_qa_org`) always runs before the actual deploy job.
- The `deploy_qa_org` job requires a manual click to run (`when: manual`); set the `DRY_RUN=true` pipeline variable to stop after validation.
- GitLab Free/Core has no Protected Environment approval rules — access to higher environments is controlled via protected branches and CI/CD variable scoping instead.
- For rollback steps, see `RUNBOOK.md` §17.

## GitHub Copilot integration

The `.github/` directory ships a complete Copilot CLI workspace setup. This is a **local tooling configuration** — it works regardless of where the repository is hosted (GitHub or GitLab) and was intentionally kept as-is during the move to GitLab.

**Instruction files** — auto-applied context scoped by file pattern:

| File                             | Applies to                             |
| -------------------------------- | -------------------------------------- |
| `apex-patterns.instructions.md`      | Apex classes and triggers                                    |
| `lwc-patterns.instructions.md`       | LWC JS, HTML, and CSS                                        |
| `unit-tests.instructions.md`         | Apex test classes                                            |
| `salesforce-cli.instructions.md`     | `sfdx-project.json`, config, manifests                       |
| `node-scripts.instructions.md`       | `scripts/**/*.js`, `*.config.js`                             |
| `agents-maintenance.instructions.md` | `.gitlab-ci.yml`, `package.json`, `sfdx-project.json`, `RUNBOOK.md` |
| `readme-maintenance.instructions.md` | `README.md`, `.github/agents\|instructions\|skills\|prompts/**` |

**Custom agents** — 18 specialized sub-agents including `gem-apex-specialist`, `gem-lwc-specialist`, `gem-sf-data-architect`, `gem-orchestrator`, `gem-implementer`, `gem-reviewer`, `gem-debugger`, and more.

**Skills** — 19 on-demand workflows: `create-implementation-plan`, `refactor-plan`, `architecture-blueprint-generator`, Tavily search/research/crawl, and more.

> [!NOTE]
> A few skills (`gh-cli`, `github-issues`, `my-issues`, `my-pull-requests`) and the `github-actions-expert` agent target GitHub.com APIs (Issues, PRs, Actions) specifically. They remain available for reference but do not apply to this repository now that it is hosted on GitLab — use GitLab's own `glab` CLI / Web IDE for issues and merge requests instead.

**Prompt files** — reusable prompts for common Salesforce tasks (e.g., `create-exception-handler`).

**Using these mechanisms** — see [`docs/copilot-customization-guide.md`](docs/copilot-customization-guide.md) for a guide on when to use agents vs. instructions vs. skills vs. prompts, including an important note on why custom instructions are not automatically inherited by delegated sub-agents.

**MCP servers** — see [`docs/mcp-setup.md`](docs/mcp-setup.md) for the recommended set of MCP servers (Salesforce DX, GitHub, Context7, Tavily, and more) and how to configure them globally in your IDE.

## Commit policy

This project follows the [Conventional Commits](https://www.conventionalcommits.org/) specification.

### Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

- **Description**: present tense, imperative mood, max 72 characters (`add` not `added`)
- **Body**: explain _why_, not _what_ — wrap at 72 characters
- **Footer**: reference issues (`Closes #123`) or breaking changes

### Types

| Type       | When to use                                      |
| ---------- | ------------------------------------------------ |
| `feat`     | New feature or capability                        |
| `fix`      | Bug fix                                          |
| `docs`     | Documentation only (README, AGENTS.md, comments) |
| `style`    | Formatting, whitespace — no logic change         |
| `refactor` | Code restructure — no new feature, no bug fix    |
| `perf`     | Performance improvement                          |
| `test`     | Add or update tests / test scripts               |
| `build`    | Dependencies, package.json, npm scripts          |
| `ci`       | CI/CD workflow changes                           |
| `chore`    | Config, tooling, minor housekeeping              |
| `revert`   | Revert a previous commit                         |

### Scopes

| Scope      | Maps to                                               |
| ---------- | ----------------------------------------------------- |
| `apex`     | `force-app/**/classes/**`, `force-app/**/triggers/**` |
| `lwc`      | `force-app/**/lwc/**`                                 |
| `aura`     | `force-app/**/aura/**`                                |
| `metadata` | Other Salesforce metadata under `force-app/`          |
| `ci`       | `.gitlab-ci.yml`, `.gitlab/**`                        |
| `copilot`  | `.github/agents/**`, `instructions/**`, `skills/**`   |
| `config`   | `sfdx-project.json`, `config/**`, `eslint.config.js`  |
| `scripts`  | `scripts/**`                                          |
| `docs`     | `docs/**`, `RUNBOOK.md`, `README.md`                  |
| `deps`     | `package.json`, `package-lock.json`                   |

Omit scope when the change spans multiple unrelated areas.

### Breaking changes

```
feat(apex)!: rename AccountSelector.getRecentAccounts to findRecentAccounts

BREAKING CHANGE: callers must update method references before deploying
```

### Examples

```
feat(apex): add AccountSelector with getRecentAccounts query
test(apex): add AccountSelectorTest covering limit and ordering
fix(ci): use RunLocalTests for validate-only deploys
refactor(lwc): extract date formatting into shared utility
docs: add commit policy section to README
build(deps): bump @salesforce/eslint-config-lwc to 4.x
ci: add Apex test coverage gate to the MR pipeline
```

### Rules

1. One logical change per commit — if the diff spans unrelated concerns, split it.
2. Never commit secrets — skip `.env`, auth files, or any credential material.
3. Do not use `--no-verify` unless explicitly required and documented.
4. Do not force-push to `main`.

---

## Troubleshooting

For common issues — bootstrap failures, lint false negatives, Apex test skips, CI metadata validation failures, and security exception lifecycle — see **`RUNBOOK.md`**.
