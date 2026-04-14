# Salesforce DX Project Template

`sfdx-project-template` is a minimal Salesforce DX project template with Node-based quality tooling for Aura/LWC.

This repository includes:

- package directory `force-app` configured in `sfdx-project.json`;
- ESLint (flat config), Prettier, and `@salesforce/sfdx-lwc-jest` configured;
- scratch org baseline prepared in `config/project-scratch-def.json`;
- no business metadata added yet.

## Current Project Layout

- `sfdx-project.json` - SFDX project configuration (`sourceApiVersion`: `66.0`)
- `config/project-scratch-def.json` - base scratch org configuration
- `eslint.config.js` - lint rules for Aura/LWC/Jest mocks
- `jest.config.js` - LWC Jest configuration
- `package.json` - npm scripts, lint-staged, dev tooling

## Quick Start

### Prerequisites

- Node.js 20+ and npm
- (Optional for Apex validation) Salesforce CLI (`sf`) in `PATH`
- (Optional for Apex validation) authenticated default target org
- (For GitHub Actions metadata validation) repository secret `SF_AUTH_URL`

Check org availability:

```bash
sf org display --json
```

```bash
npm install
```

## Daily Development Commands

Lint JS for Aura/LWC:

```bash
npm run lint
```

Full test run (LWC Jest + Apex tests when an org is available):

```bash
npm run test
```

Format files:

```bash
npm run prettier
```

Full local validation before a PR:

```bash
npm run validate
```

`npm run validate` runs `lint`, `prettier:verify`, `test:lwc:ci`, and then `test:apex`.
The Apex step is skipped gracefully (without failing the template pipeline) if:

- there are no local Apex test classes (`@isTest`) in `force-app/main/default/classes`;
- `sf` CLI is not installed;
- a default target org is not configured.

## CI Expectations

PR workflow `.github/workflows/pr-check.yml` always runs:

- `npm run lint`
- `npm run prettier:verify`
- `npm run test:lwc:ci`

Security workflow `.github/workflows/security-gates.yml` runs:

- secret scanning on `pull_request` and `push` to `main`;
- dependency audit on `pull_request` and weekly `schedule`;
- fail policy: any secret-scan finding fails the job, and dependency findings with severity `high` or `critical` fail the job;
- approved, time-boxed exceptions must follow `RUNBOOK.md` Section 11 with owner, reason, and expiration.

If a PR changes files under `force-app/` (or under the directory defined by repository variable `SFDX_METADATA_DIR`), the workflow also runs a Salesforce metadata validate-only check.

This check requires:

- repository secret `SF_AUTH_URL` containing an SFDX auth URL for the CI org;
- the workflow uses a fixed wait value `--wait 30`, aligned with job `timeout-minutes: 30`.

Metadata check behavior:

- if there are no changes under the metadata root in the PR, the check completes successfully and logs a skip message;
- if the metadata root does not exist in the branch yet, the check is also skipped without a false template failure;
- if metadata changes exist but `SF_AUTH_URL` is not set, the PR check fails with an explicit error;
- logs and the list of changed files are stored in the GitHub Actions artifact `salesforce-validate-<run_id>`.

## Onboarding Runbook

For common local development and CI issues, use `RUNBOOK.md`.

The runbook covers:

- bootstrap/dependency installation;
- lint and LWC test behavior in an empty template;
- reasons for graceful skip in `npm run test:apex`;
- diagnostics for failure and skip scenarios of `Salesforce Metadata Validate` in PRs.
- security triage and exception lifecycle for secret scan and dependency audit findings.

## Additional Test Modes

LWC unit tests only (Jest):

```bash
npm run test:lwc
```

Apex tests (if an org is available):

```bash
npm run test:apex
```

CI test mode:

```bash
npm run test:lwc:ci
```

Watch mode:

```bash
npm run test:lwc:watch
```

Coverage:

```bash
npm run test:lwc:coverage
```

## Notes for Template Usage

- Salesforce metadata source root is `force-app/` (per `sfdx-project.json`).
- When adding the first metadata, create the standard path `force-app/main/default/`.
- For scratch org usage, use `config/project-scratch-def.json` as the base definition file.
- For CI metadata validation, use a dedicated low-privilege org user and store its auth URL only in the `SF_AUTH_URL` secret.
