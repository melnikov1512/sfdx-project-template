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
- Run full test flow (LWC CI + Apex checks):
  ```bash
  npm run test
  ```
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
- Code analysis job runs on every PR and scans Apex, LWC, Aura, and metadata using `sf code-analyzer` (SARIF output, graceful skip if no metadata).
- Security CI runs `.github/workflows/security-gates.yml` with secret scanning on `pull_request` + `push: main` and dependency audit on `pull_request` + `schedule`.
- AI PR Summary CI runs `.github/workflows/ai-pr-summary.yml` on every `pull_request` (opened/synchronize/reopened) targeting `main`:
  - Posts a structured summary comment: **What Changed** / **What to Check Manually** / Risk Level.
  - Calls GitHub Models API (`gpt-4o-mini`, `models: read` permission, `github.token`) — no external secrets needed.
  - Excludes lock files, `.env*`, and key/cert files from the diff before sending to AI.
  - Falls back to plain diff-stats comment on any AI error; never fails the pipeline due to AI issues.
  - Comment is upserted (idempotent) on force-push.
- Release CI runs `.github/workflows/release.yml` on `push: main`; creates/updates a Release PR via `release-please`. Merging the Release PR creates a tag and GitHub Release.
- Deploy CI runs `.github/workflows/deploy.yml` via manual `workflow_dispatch`; requires GitHub Environments (`staging`, `production`) with scoped `SF_AUTH_URL` secrets. The `production` environment must have Required Reviewers and a `main`-only branch policy. Validate gate runs before every deploy. Rollback procedure is in `RUNBOOK.md` Section 17.

## Release & Versioning Conventions

> **Release trigger:** Manual `workflow_dispatch` only — go to Actions → Release → Run workflow. No automatic release on push to main.
- **Commit style:** All commits merged to `main` must follow [Conventional Commits](https://www.conventionalcommits.org/): `<type>[scope]: <description>`.
- **SemVer mapping:** `fix:` → PATCH, `feat:` → MINOR, `feat!:` / `BREAKING CHANGE:` footer → MAJOR.
- **Release automation:** `release-please` (`.github/workflows/release.yml`) creates Release PRs automatically on push to `main`. Merge the Release PR to publish a tag + GitHub Release.
- **Hotfix branches:** Use `hotfix/<issue-id>-<description>` branched from `main`; commit with `fix:` to trigger a PATCH release. Full hotfix process in `RUNBOOK.md` Section 16.
- **Changelog:** `CHANGELOG.md` is auto-maintained by `release-please`. Do not edit manually.
- **Config files:** `.release-please-config.json` (changelog sections, release type) and `.release-please-manifest.json` (current version) at repo root.

## Project-Specific Conventions
- Use **ESLint flat config** (`eslint.config.js`), not legacy `.eslintrc*`.
- LWC test files match `**/lwc/**/*.test.js`; these explicitly disable `@lwc/lwc/no-unexpected-wire-adapter-usages`.
- Jest ignores `.localdevserver` (`jest.config.js`); do not rely on files there in tests.
- Pre-commit commands are defined via Husky + `lint-staged` in `package.json` (format + lint + related LWC tests); ensure a Husky pre-commit hook exists in the active branch/repo setup.
- `.forceignore` excludes test folders like `**/__tests__/**` from source push/pull flows; keep deploy intent in mind when adding test assets.
- GitHub Actions metadata validation expects repository secret `SF_AUTH_URL`; optional repository variable `SFDX_METADATA_DIR` changes the metadata root without code changes.

## Integration Points and Boundaries
- Salesforce org interaction is expected through SFDX/SF CLI workflows (repository includes `sfdx-project.json` + scratch definition).
- API version is pinned to `66.0` (`sfdx-project.json`); align new metadata with this target unless intentionally upgraded.
- Ignore local IDE/state directories in automation (`.sf/`, `.sfdx/`, `.illuminatedCloud/`, `IlluminatedCloud/`).
- CI metadata validation authenticates with `sf org login sfdx-url`; keep auth material in GitHub secrets only and do not assume local `.sf/` or `.sfdx/` state exists on runners.
- Security incidents and temporary risk acceptances must follow `RUNBOOK.md` triage/exception process (owner + reason + expiration + rollback trigger).

## Salesforce Knowledge Sources (Context7)

When working on Salesforce tasks, agents MUST use Context7 (`get-library-docs` tool) with these library IDs instead of relying on general knowledge. Always resolve the ID first if unsure.

| Context7 Library ID | What it covers | Priority |
|---|---|---|
| `/damecek/salesforce-documentation-context` | Complete Salesforce Platform docs (Apex, LWC, Aura, Metadata API, REST API) | ⭐ Primary |
| `/forcedotcom/sf-skills` | Agentforce skills: Flow, Apex, SOQL, LWC patterns | ⭐ Primary |
| `/websites/lwc_dev` | LWC official framework docs (wire, lifecycle, decorators) | LWC tasks |
| `/websites/v1_lightningdesignsystem` | SLDS: utility classes, design tokens, component blueprints | UI tasks |
| `/trailheadapps/apex-recipes` | Apex best-practice code examples (collections, DML, async) | Apex tasks |
| `/trailheadapps/lwc-recipes` | LWC pattern examples (wire, events, navigation) | LWC tasks |
| `/salesforcecli/cli` | SF CLI / sfdx commands reference | CLI/CI tasks |
| `/forcedotcom/schemas` | JSON schemas for `sfdx-project.json` and scratch org definitions | Config tasks |
| `/apex-enterprise-patterns/fflib-apex-common-samplecode` | Enterprise patterns: Service Layer, Unit of Work, Selector, Domain | Complex Apex |

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
