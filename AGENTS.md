# AGENTS.md

## Agent Bootstrapping (CRITICAL — read first)

Every agent, before starting any task, **must**:

1. Read `.github/copilot-instructions.md` in full — this is the primary source of project rules, tone, and conventions.
2. Read this file (`AGENTS.md`) in full.
3. Load any `.github/instructions/*.instructions.md` files that match the file types you will be editing:

| Instruction file                     | When to load                                                        |
| ------------------------------------ | ------------------------------------------------------------------- |
| `apex-patterns.instructions.md`      | Editing `.cls` or `.trigger` files                                  |
| `lwc-patterns.instructions.md`       | Editing LWC `.js`, `.html`, `.css`                                  |
| `unit-tests.instructions.md`         | Writing or editing Apex test classes                                |
| `node-scripts.instructions.md`       | Editing `scripts/**/*.js` or `*.config.js`                          |
| `salesforce-cli.instructions.md`     | Editing `sfdx-project.json`, `config/**`, `manifest/**`             |
| `agents-maintenance.instructions.md` | Editing `.gitlab-ci.yml`, `package.json`, CI/tooling config          |
| `readme-maintenance.instructions.md` | Editing `README.md`, `.github/agents/**`, `.github/instructions/**` |

> For a plain-language overview of how agents, instructions, skills, and prompts relate to each other (and why custom instructions are NOT automatically inherited by delegated sub-agents), see [`docs/copilot-customization-guide.md`](docs/copilot-customization-guide.md).

---

## Repository Purpose

- This repository is a **Salesforce DX template** (`sfdx-project-template`) with Node-based quality tooling and no business metadata committed yet.
- Treat `force-app/` as the deployable Salesforce source root (configured in `sfdx-project.json`).

## Architecture Snapshot

- Single package directory: `force-app` (`sfdx-project.json`).
- Expected Salesforce metadata root: `force-app/main/default/` (not present in this snapshot yet; add when committing first metadata).
- Local quality toolchain lives in Node config files at repo root:
    - `eslint.config.js` for Aura/LWC linting profiles
    - `jest.config.js` for LWC unit tests
    - `package.json` for scripts, hooks, and formatting
    - `.prettierrc` for Prettier settings (4-space indent, Apex + XML plugins)
    - `@salesforce/sfdx-scanner` (code-analyzer plugin) for Salesforce-specific SAST (Apex, LWC, Aura, metadata)
- Scratch org baseline is defined in `config/project-scratch-def.json`.

## Critical Workflows (Use These First)

- Install dependencies:
    ```bash
    npm install
    ```
- Lint Aura/LWC JS:
    ```bash
    npm run lint
    ```
- Run LWC tests:
    ```bash
    npm run test:lwc
    ```
- Run LWC tests with coverage:
    ```bash
    npm run test:lwc:coverage
    ```
- Run full test flow (LWC CI + Apex checks):
    ```bash
    npm run test
    ```
    > `test:apex` gracefully skips if: no `@isTest` classes found, `sf` CLI missing, or no default org configured.
- Run related tests in pre-commit style (already wired via `lint-staged`):
    ```bash
    npx sfdx-lwc-jest -- --bail --findRelatedTests --passWithNoTests
    ```
- Format all supported metadata/code files:
    ```bash
    npm run prettier
    ```
- Run full local validation (lint + prettier check + LWC Jest CI mode + Apex checks):
    ```bash
    npm run validate
    ```
- Run Salesforce code analysis locally (Apex/LWC/Aura SAST):
    ```bash
    npm run lint:apex
    ```
- MR pipeline also runs `.gitlab-ci.yml`; when an MR changes files under `force-app/` (or `SFDX_METADATA_DIR`), the `salesforce_validate` job adds a Salesforce metadata validate-only gate.
- Security checks run via `.gitlab-ci.yml` (`secret_scan`, `dependency_audit`) on every MR to `main`, on push to `main`, and on a weekly GitLab Pipeline Schedule. CodeQL SAST from the former GitHub setup has no GitLab Free/Core equivalent and was not ported — see `RUNBOOK.md` §12 for the documented gap.

## Project-Specific Conventions

- **Language**: all code comments and all documentation (README, AGENTS.md, `docs/**`, ApexDoc/JSDoc, inline comments) must be written in English only, regardless of the chat language.
- **Link verification**: never state/output a URL unless it was just confirmed live via an actual tool call/fetch in the current turn — never cite a URL reconstructed from memory. If fetch-based tools fail or are blocked, fall back to a browser tool (Playwright) before concluding a link is dead. Full rule: see "Link Verification (CRITICAL)" in `.github/copilot-instructions.md`.
- Always use `sf` (SF CLI v2), not `sfdx` (deprecated).
- Use **ESLint flat config** (`eslint.config.js`), not legacy `.eslintrc*`.
- **Code formatting** uses `.prettierrc` with `tabWidth: 4` (4-space indent) for all supported file types (JS, CSS, HTML, JSON, Apex, XML, YAML, Markdown). `.prettierignore` excludes `.idea/`, `IlluminatedCloud/`, `.npm-cache/`, `node_modules/`, `.github/`, `.husky/`, and all `*.md` files (Markdown is not auto-formatted by `npm run prettier`).
- LWC test files match `**/lwc/**/*.test.js`; these explicitly disable `@lwc/lwc/no-unexpected-wire-adapter-usages`.
- Jest ignores `.localdevserver` (`jest.config.js`); do not rely on files there in tests.
- Pre-commit commands are defined via Husky + `lint-staged` in `package.json` (format + lint + related LWC tests); ensure a Husky pre-commit hook exists in the active branch/repo setup.
- `.forceignore` excludes test folders like `**/__tests__/**` from source push/pull flows; keep deploy intent in mind when adding test assets.
- GitLab CI/CD metadata validation expects the CI/CD variable `SF_AUTH_URL` (protected + masked, scoped to environment `qa_org`); optional CI/CD variable `SFDX_METADATA_DIR` changes the metadata root without code changes.
- Manual deploy jobs (`deploy_validate_qa_org`, `deploy_qa_org` in `.gitlab-ci.yml`) target a single `qa_org` GitLab environment today (extensible by duplicating the job pair with a new `environment: name:` and a matching scoped variable) with a `DRY_RUN` pipeline variable to skip the actual deploy. Both jobs authenticate using the `SF_AUTH_URL` variable scoped to that environment — there is no project-wide, unscoped `SF_AUTH_URL`.
- **Node.js scripts** (`scripts/**/*.js`): always CJS, `'use strict'` required, `node:` prefix for all built-in requires, `parseArgs` from `node:util` for CLI argument parsing (Node 18.11+), `spawnSync` with `shell: false` + `stdio: 'inherit'` for CLI wrappers, `fatal()` helper at bottom of file. See `.github/instructions/node-scripts.instructions.md`.
- **ESLint coverage**: `scripts/**/*.js` and `*.config.js` (root) are covered by a `globals.node` + `eslintJs/recommended` block in `eslint.config.js`; `scripts/**/*.js` is also in the `lint-staged` pre-commit gate.
- **Node.js MCP server**: no MCP server added — `bash` tool + Context7 + GitHub MCP already covers all npm/Node.js development needs (no official Node.js Foundation MCP exists as of mid-2025).

## Integration Points and Boundaries

- Salesforce org interaction is expected through SFDX/SF CLI workflows (repository includes `sfdx-project.json` + scratch definition).
- API version is pinned to `66.0` (`sfdx-project.json`); align new metadata with this target unless intentionally upgraded.
- Ignore local IDE/state directories in automation (`.sf/`, `.sfdx/`, `.illuminatedCloud/`, `IlluminatedCloud/`).
- CI metadata validation authenticates with `sf org login sfdx-url`; keep auth material in GitLab CI/CD variables (protected + masked) only and do not assume local `.sf/` or `.sfdx/` state exists on runners.
- Security incidents and temporary risk acceptances must follow `RUNBOOK.md` triage/exception process (owner + reason + expiration + rollback trigger).

## Salesforce Knowledge Sources (Context7)

When working on Salesforce tasks, agents MUST use Context7 (`get-library-docs` tool) with these library IDs instead of relying on general knowledge. Always resolve the ID first if unsure.

| Context7 Library ID                                      | What it covers                                                              | Priority     |
| -------------------------------------------------------- | --------------------------------------------------------------------------- | ------------ |
| `/damecek/salesforce-documentation-context`              | Complete Salesforce Platform docs (Apex, LWC, Aura, Metadata API, REST API) | ⭐ Primary   |
| `/forcedotcom/sf-skills`                                 | Agentforce skills: Flow, Apex, SOQL, LWC patterns                           | ⭐ Primary   |
| `/websites/lwc_dev`                                      | LWC official framework docs (wire, lifecycle, decorators)                   | LWC tasks    |
| `/websites/v1_lightningdesignsystem`                     | SLDS: utility classes, design tokens, component blueprints                  | UI tasks     |
| `/trailheadapps/apex-recipes`                            | Apex best-practice code examples (collections, DML, async)                  | Apex tasks   |
| `/trailheadapps/lwc-recipes`                             | LWC pattern examples (wire, events, navigation)                             | LWC tasks    |
| `/salesforcecli/cli`                                     | SF CLI / sfdx commands reference                                            | CLI/CI tasks |
| `/forcedotcom/schemas`                                   | JSON schemas for `sfdx-project.json` and scratch org definitions            | Config tasks |
| `/apex-enterprise-patterns/fflib-apex-common-samplecode` | Enterprise patterns: Service Layer, Unit of Work, Selector, Domain          | Complex Apex |

**Usage pattern:**

```
1. resolve-library-id if ID uncertain
2. get-library-docs with context7CompatibleLibraryID + topic
3. Fall back to Fetch → developer.salesforce.com if Context7 has no match
```

## Agent Operating Guidance for This Repo

- **Never create git commits unless the user explicitly asks to commit.** Making changes to files is fine; committing them is not permitted without explicit instruction.
- Before editing, inspect `force-app/main/default/` to detect which metadata types are present in the current branch.
- When adding new LWC/Aura code, wire it to existing npm workflows (lint, jest, prettier) and verify locally.
- Prefer small, metadata-type-scoped changes; this template has minimal structure, so avoid introducing cross-cutting abstractions prematurely.
- If adding first functional metadata, document any new folder conventions directly in this file for future agents.
- Plans live in `docs/plans/<plan-name>/`; the primary plan file is `<plan-name>.md` with supporting files co-located in the same folder.
