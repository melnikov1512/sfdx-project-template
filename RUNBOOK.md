# DX and CI Runbook

This runbook covers common local development and PR CI issues in the `sfdx-project-template` template.

## 1) Local bootstrap

### Symptom

`npm install` fails or dependencies are installed incorrectly.

### Check

```bash
node -v
npm -v
```

### Expected state

- Node.js version 20+
- npm is available in `PATH`

### Actions

```bash
npm ci
```

If the lockfile was changed locally and you need a standard install:

```bash
npm install
```

---

## 2) `npm run lint` checks nothing

### Symptom

The command completes successfully, but the project does not yet contain Aura/LWC JS files.

### Why this happens

The template enables `--no-error-on-unmatched-pattern`, so missing `force-app/main/default/**/{aura,lwc}/**/*.js` files is not treated as an error.

### Actions

- This is normal behavior for an empty template.
- After adding LWC/Aura files, lint starts checking them automatically.

---

## 3) `npm run test:lwc:ci` reports that no tests are found

### Symptom

Jest finishes without failure because test files have not been added yet.

### Why this happens

CI mode runs with `--passWithNoTests`.

### Actions

- This is expected for a template without components.
- After adding LWC components, add `*.test.js` files under `force-app/main/default/lwc/**`.

---

## 4) `npm run test:apex` is skipped

### Symptom

One of the following messages appears:

- `Skipping Apex tests: no local Apex test classes found`
- `Skipping Apex tests: sf CLI not found`
- `Skipping Apex tests: no default target org configured`

### Why this happens

The Apex check in this template is org-dependent and uses graceful skip behavior.

### Actions

1. Add local test classes (`@isTest`) in `force-app/main/default/classes`.
2. Install Salesforce CLI (`sf`).
3. Authorize a default org:

```bash
sf org display --json
```

---

## 5) PR check fails on Salesforce metadata validate

### Symptom

Job `Salesforce Metadata Validate` finished with an error.

### Common causes

- Repository secret `SF_AUTH_URL` is not set.
- There are errors in Salesforce metadata.
- The PR contains changes under the metadata root (`force-app/` or `SFDX_METADATA_DIR`).

### Actions

1. Verify that `SF_AUTH_URL` is configured in the repository.
2. Open artifact `salesforce-validate-<run_id>` and inspect:
   - `.artifacts/salesforce-validate/changed-files.txt`
   - `.artifacts/salesforce-validate/validate.log`
3. Fix metadata issues and re-run PR checks.

---

## 6) PR check unexpectedly skips metadata validate

### Symptom

`Salesforce Metadata Validate` does not run an actual validation.

### Why this happens

The check is intentionally skipped if:

- there are no changes under the metadata root in the PR;
- the metadata root does not exist in the current branch.

### Actions

- If this PR does not include Salesforce metadata, no action is needed.
- If validation was expected, verify the metadata root path:
  - default is `force-app`;
  - or the value of repository variable `SFDX_METADATA_DIR`.

---

## 7) Full local validation before a PR

Run the unified quality gate:

```bash
npm run validate
```

The command runs:

- `npm run lint`
- `npm run prettier:verify`
- `npm run test:lwc:ci`
- `npm run test:apex` (with possible graceful skip)

---

## 8) What to include in a bug report

To speed up diagnostics, include:

- reproduction steps;
- exact command and full output;
- Node/npm versions (`node -v`, `npm -v`);
- for CI issues: a run link and log from artifact `salesforce-validate-<run_id>`.
