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

## Project-Specific Conventions
- Use **ESLint flat config** (`eslint.config.js`), not legacy `.eslintrc*`.
- LWC test files match `**/lwc/**/*.test.js`; these explicitly disable `@lwc/lwc/no-unexpected-wire-adapter-usages`.
- Jest ignores `.localdevserver` (`jest.config.js`); do not rely on files there in tests.
- Pre-commit commands are defined via Husky + `lint-staged` in `package.json` (format + lint + related LWC tests); ensure a Husky pre-commit hook exists in the active branch/repo setup.
- `.forceignore` excludes test folders like `**/__tests__/**` from source push/pull flows; keep deploy intent in mind when adding test assets.

## Integration Points and Boundaries
- Salesforce org interaction is expected through SFDX/SF CLI workflows (repository includes `sfdx-project.json` + scratch definition).
- API version is pinned to `66.0` (`sfdx-project.json`); align new metadata with this target unless intentionally upgraded.
- Ignore local IDE/state directories in automation (`.sf/`, `.sfdx/`, `.illuminatedCloud/`, `IlluminatedCloud/`).

## Agent Operating Guidance for This Repo
- Before editing, inspect `force-app/main/default/` to detect which metadata types are present in the current branch.
- When adding new LWC/Aura code, wire it to existing npm workflows (lint, jest, prettier) and verify locally.
- Prefer small, metadata-type-scoped changes; this template has minimal structure, so avoid introducing cross-cutting abstractions prematurely.
- If adding first functional metadata, document any new folder conventions directly in this file for future agents.
