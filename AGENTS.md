# AGENTS.md

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
- PR CI also runs `.github/workflows/pr-check.yml`; when a PR changes files under `force-app/` (or `SFDX_METADATA_DIR`), it adds a Salesforce metadata validate-only gate.
- Security checks run via `.github/workflows/security-gates.yml` on every PR to `main` and weekly (CodeQL, secret scan, dependency audit).
- AI-assisted PR summaries run via `.github/workflows/ai-pr-summary.yml`; advisory only, never blocks merge. Governed by `docs/AI-GOVERNANCE.md`.
- AI test recommendations run via `.github/workflows/ai-test-recommendations.yml` on every PR to `main`; posts a file-by-file test checklist comment using GitHub Models (gpt-4o-mini); advisory only, never blocks merge.

## Project-Specific Conventions

- Always use `sf` (SF CLI v2), not `sfdx` (deprecated).
- Use **ESLint flat config** (`eslint.config.js`), not legacy `.eslintrc*`.
- **Code formatting** uses `.prettierrc` with `tabWidth: 4` (4-space indent) for all supported file types (JS, CSS, HTML, JSON, Apex, XML, YAML, Markdown). Files under `.github/` and `.husky/` are excluded from Prettier via `.prettierignore`.
- LWC test files match `**/lwc/**/*.test.js`; these explicitly disable `@lwc/lwc/no-unexpected-wire-adapter-usages`.
- Jest ignores `.localdevserver` (`jest.config.js`); do not rely on files there in tests.
- Pre-commit commands are defined via Husky + `lint-staged` in `package.json` (format + lint + related LWC tests); ensure a Husky pre-commit hook exists in the active branch/repo setup.
- `.forceignore` excludes test folders like `**/__tests__/**` from source push/pull flows; keep deploy intent in mind when adding test assets.
- GitHub Actions metadata validation expects repository secret `SF_AUTH_URL`; optional repository variable `SFDX_METADATA_DIR` changes the metadata root without code changes.
- Manual deploy workflow (`.github/workflows/deploy.yml`) targets `staging` or `production` environments with a `dry_run` flag. Requires **repository secrets** `SF_AUTH_URL_STAGING` / `SF_AUTH_URL_PRODUCTION` for validation and **environment-scoped secret** `SF_AUTH_URL` per GitHub Environment for actual deploy.
- **Node.js scripts** (`scripts/**/*.js`): always CJS, `'use strict'` required, `node:` prefix for all built-in requires, `parseArgs` from `node:util` for CLI argument parsing (Node 18.11+), `spawnSync` with `shell: false` + `stdio: 'inherit'` for CLI wrappers, `fatal()` helper at bottom of file. See `.github/instructions/node-scripts.instructions.md`.
- **ESLint coverage**: `scripts/**/*.js` and `*.config.js` (root) are covered by a `globals.node` + `eslintJs/recommended` block in `eslint.config.js`; `scripts/**/*.js` is also in the `lint-staged` pre-commit gate.
- **Node.js MCP server**: no MCP server added — `bash` tool + Context7 + GitHub MCP already covers all npm/Node.js development needs (no official Node.js Foundation MCP exists as of mid-2025).

## Integration Points and Boundaries

- Salesforce org interaction is expected through SFDX/SF CLI workflows (repository includes `sfdx-project.json` + scratch definition).
- API version is pinned to `66.0` (`sfdx-project.json`); align new metadata with this target unless intentionally upgraded.
- Ignore local IDE/state directories in automation (`.sf/`, `.sfdx/`, `.illuminatedCloud/`, `IlluminatedCloud/`).
- CI metadata validation authenticates with `sf org login sfdx-url`; keep auth material in GitHub secrets only and do not assume local `.sf/` or `.sfdx/` state exists on runners.
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

- Before editing, inspect `force-app/main/default/` to detect which metadata types are present in the current branch.
- When adding new LWC/Aura code, wire it to existing npm workflows (lint, jest, prettier) and verify locally.
- Prefer small, metadata-type-scoped changes; this template has minimal structure, so avoid introducing cross-cutting abstractions prematurely.
- If adding first functional metadata, document any new folder conventions directly in this file for future agents.
- Plans live in `docs/plans/<plan-name>/`; the primary plan file is `<plan-name>.md` with supporting files co-located in the same folder.
