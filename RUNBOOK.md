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

## 8) Code Analysis findings: severity, false positives and exceptions

### Symptom

Job `Salesforce Code Analysis` runs in PR check and reports findings in SARIF format or logs.

### Common causes and handling

- **Real findings** (CRUD/FLS, SOQL injection, best practices, PMD/ESLint Salesforce rules):
    - Review the `code-analysis-<run_id>` artifact (`results.sarif`).
    - Fix the underlying issue and re-run checks.
- **False positive** (rule too broad, context-specific safety, intentional pattern):
    - Document the reason and severity (e.g., "intentional: test data factory").
    - Follow Section 13 (exception lifecycle) if immediate fix is not possible.

### Severity thresholds and merge policy

The following table defines the enforced security severity thresholds across all CI security jobs.

| Tool                                            | SARIF level / audit level      | Merge policy                                          |
| ----------------------------------------------- | ------------------------------ | ----------------------------------------------------- |
| **CodeQL** (`codeql.yml`)                       | `error` (HIGH / CRITICAL CWEs) | ❌ Blocks merge                                       |
| **CodeQL** (`codeql.yml`)                       | `warning` (MEDIUM)             | ⚠️ Advisory — visible in Security tab, does not block |
| **Salesforce Code Analyzer** (`pr-check.yml`)   | `error` (HIGH / CRITICAL)      | ❌ Blocks merge                                       |
| **Salesforce Code Analyzer** (`pr-check.yml`)   | `warning` (MEDIUM)             | ⚠️ Advisory — artifact only, does not block           |
| **Gitleaks secret scan** (`security-gates.yml`) | any finding                    | ❌ Blocks merge                                       |
| **npm audit** (`security-gates.yml`)            | `high` / `critical`            | ❌ Blocks merge                                       |
| **npm audit** (`security-gates.yml`)            | `moderate` / `low`             | ⚠️ Advisory — triage recommended                      |

### Local code analysis

Run analysis locally before pushing:

```bash
npm run lint:apex
```

This installs the code-analyzer plugin (if needed) and outputs results to `.artifacts/code-analysis/results.sarif`.

### CodeQL findings

CodeQL findings are also visible in:

- **GitHub Security tab** → Code scanning alerts (requires `security-events: write` permission).
- **PR Checks** → annotations on diff lines where findings occur.

To dismiss a CodeQL alert as a false positive, use the Security tab UI and document the reason; this does not bypass CI but suppresses the alert.

---

## 9) What to include in a bug report

To speed up diagnostics, include:

- reproduction steps;
- exact command and full output;
- Node/npm versions (`node -v`, `npm -v`);
- for CI issues: a run link and log from artifact `salesforce-validate-<run_id>` or `code-analysis-<run_id>`.

---

## 10) Security gate fails on secret scanning

### Symptom

Job `Secret Scan (Fail on Findings)` fails in `.github/workflows/security-gates.yml`.

### Actions

1. Open artifact `secret-scan-<run_id>` and review `gitleaks.sarif`.
2. Confirm whether the finding is a real secret (token, key, password, private key) or false positive.
3. If real:
    - immediately rotate/revoke the exposed credential;
    - remove secret from repository history if required by policy;
    - push a remediation commit and re-run checks.
4. If false positive, follow Section 13 (exception lifecycle) and add an owner for cleanup.

### SLA

- `critical`: remediate or block merge within 4 hours.
- `high`: remediate or block merge within 1 business day.

### Fail policy

- Any secret-scan finding in `.github/workflows/security-gates.yml` fails CI on `pull_request` and `push` to `main`.
- Merge is blocked until remediation is merged or a documented, time-boxed exception is approved (Section 13).

---

## 11) Security gate fails on dependency audit

### Symptom

Job `Dependency Audit (High/Critical Gate)` fails due to `npm audit --audit-level=high`.

### Actions

1. Open artifact `dependency-audit-<run_id>` and inspect `npm-audit.json`.
2. Identify direct vs transitive vulnerable packages.
3. Apply the safest upgrade path (`npm update`, explicit version bump, or dependency replacement).
4. Re-run CI and confirm no `high`/`critical` findings remain.
5. If no safe fix exists yet, follow Section 13 (exception lifecycle) and create a time-boxed exception.

### Fail policy

- Any `high` or `critical` dependency vulnerability fails CI.
- `moderate`/`low` do not block merge by default, but should be triaged.

---

## 12) CodeQL SAST fails in CI

### Symptom

Job `CodeQL Analysis (JavaScript)` fails in `.github/workflows/codeql.yml`.

### Actions

1. Open the **Security** tab → **Code scanning alerts** to view annotated findings.
2. Review the finding category (CWE ID, rule name) and the affected file/line in the PR diff.
3. If real:
    - Fix the root cause (e.g., sanitise input, remove insecure pattern).
    - Re-push and wait for re-analysis.
4. If false positive:
    - Dismiss via the Security tab UI (requires write access).
    - Document reason in the dismissal form.
    - No PR block after dismissal, but keep a record per Section 13.

### Fail policy

| Severity        | SARIF level | Action                                                          |
| --------------- | ----------- | --------------------------------------------------------------- |
| Critical / High | `error`     | Blocks merge; must be fixed or dismissed with documented reason |
| Medium          | `warning`   | Advisory; visible in Security tab, does not block merge         |
| Low / Info      | `note`      | Informational; no action required                               |

---

## 13) Exception lifecycle (time-boxed risk acceptance)

Use exceptions only when an immediate safe remediation is not available.

### Required fields

- `owner`: accountable engineer.
- `reason`: why the exception is required.
- `scope`: affected workflow/finding/package/path.
- `expiration_date`: hard deadline for removal.
- `rollback_trigger`: condition that cancels the exception immediately (for example, fix released, active exploit, policy update).

### Process

1. Create an issue with all required fields and link CI run evidence.
2. Obtain approval from the code owner/security reviewer.
3. Apply the minimum temporary bypass needed.
4. Track expiration and remove the bypass before `expiration_date`.
5. Close the issue only after cleanup is merged and CI is green without the bypass.

---

## 14) SemVer versioning strategy

This project follows [Semantic Versioning 2.0.0](https://semver.org/):

| Increment         | When                            | Conventional Commit type                            |
| ----------------- | ------------------------------- | --------------------------------------------------- |
| **PATCH** `x.y.Z` | Backward-compatible bug fix     | `fix:`                                              |
| **MINOR** `x.Y.z` | New backward-compatible feature | `feat:`                                             |
| **MAJOR** `X.y.z` | Breaking change                 | `feat!:` or any type with `BREAKING CHANGE:` footer |

### Conventional Commits reference

All commits merged to `main` **must** follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

> [!NOTE]
> There is no automated CHANGELOG generation. Release Please was removed from this template. Maintain a CHANGELOG manually if required, or adopt a changelog tool separately.

Common types and their changelog visibility:

| Type       | Changelog section | Visible |
| ---------- | ----------------- | ------- |
| `feat`     | ✨ Features       | ✅      |
| `fix`      | 🐛 Bug Fixes      | ✅      |
| `perf`     | ⚡ Performance    | ✅      |
| `docs`     | 📚 Documentation  | ✅      |
| `revert`   | ⏪ Reverts        | ✅      |
| `chore`    | 🔧 Maintenance    | hidden  |
| `refactor` | ♻️ Refactoring    | hidden  |
| `test`     | 🧪 Tests          | hidden  |
| `ci`       | ⚙️ CI/CD          | hidden  |

**Breaking change syntax:**

```bash
feat!: drop support for Node 18

# or with footer:
feat: redesign auth flow

BREAKING CHANGE: SF_AUTH_URL format changed from X to Y
```

---

## 15) Hotfix process

A hotfix addresses a critical production defect that cannot wait for the normal release cycle.

### When to use a hotfix

- Security vulnerability requiring immediate patch (SLA: critical = 4 h, high = 1 business day).
- Production-blocking regression introduced in the previous release.

### Hotfix workflow

```
main
  │
  └── hotfix/<issue-id>-<short-description>
            │
            │  fix: <description>  ← conventional commit
            │
            └── PR → main
                        │
                        └── deploy workflow triggered manually
```

**Step-by-step:**

```bash
# 1. Create hotfix branch from main
git checkout -b hotfix/<issue-id>-<description> main

# 2. Implement the fix
# ...

# 3. Commit with conventional commit
git commit -m "fix(<scope>): <description of critical fix>"

# 4. Push and open PR against main
git push origin hotfix/<issue-id>-<description>
gh pr create --base main --title "fix(<scope>): <description>" --body "Closes #<issue-id>"

# 5. After PR merge, trigger deploy workflow manually (Actions → Deploy → Run workflow)
#    Select ref=main, environment=staging → verify, then environment=production
```

### Hotfix SLA

| Severity | Max time to release  |
| -------- | -------------------- |
| Critical | 4 hours              |
| High     | 1 business day       |
| Medium   | Next regular release |

### Hotfix exception

If the fix requires bypassing normal quality gates (e.g., emergency secret rotation), follow Section 13 (time-boxed exception) and document:

- `owner`, `reason`, `scope`, `expiration_date`, `rollback_trigger`.

---

## 17) Deploy workflow and rollback

### Overview

The deploy workflow (`.github/workflows/deploy.yml`) deploys Salesforce metadata to target environments with a mandatory validate step before every deploy.

### Environments

| Environment  | Secrets                            | GitHub Environment Protection                                   |
| ------------ | ---------------------------------- | --------------------------------------------------------------- |
| `staging`    | `SF_AUTH_URL` (environment secret) | Recommended: required reviewer                                  |
| `production` | `SF_AUTH_URL` (environment secret) | Required: required reviewer + deployment branch policy (`main`) |

Repository-level secrets `SF_AUTH_URL_STAGING` and `SF_AUTH_URL_PRODUCTION` are used by the validate job — this allows validate to run without waiting for environment approval.

### Required setup

1. In the GitHub repository → **Settings → Environments**, create `staging` and `production` environments.
2. In each environment, add the `SF_AUTH_URL` secret (SFDX Auth URL for the target org).
3. Add repository-level secrets `SF_AUTH_URL_STAGING` and `SF_AUTH_URL_PRODUCTION` (Settings → Secrets → Actions) — used by the validate job.
4. For `production`, enable **Required reviewers** and **Deployment branch policy: main only**.

### Running a deploy

1. **Actions → Deploy → Run workflow**.
2. Select `ref`: branch or tag to deploy (default: `main`).
3. Select `environment`: `staging` or `production`.
4. Optional: `dry_run: true` — runs validate only, no actual deploy.
5. Wait for the `validate` job to pass.
6. For `production`: confirm the deploy in the GitHub Environments UI.

### Rollback

Rollback is performed by re-deploying the previous working version.

#### Quick rollback (via workflow)

1. Find the previous successful deploy in `.artifacts/deploy/deploy.log` or GitHub deployments.
2. Identify the Git commit/tag of the last known-good version:
    ```bash
    git log --oneline --decorate origin/main | head -20
    ```
3. Create a hotfix branch from the known-good tag:
    ```bash
    git checkout -b hotfix/<issue-id>-rollback <previous-good-tag>
    git push origin hotfix/<issue-id>-rollback
    ```
4. Open a PR to `main` and merge (fast-track).
5. Run deploy workflow with `environment=staging` → verify it works.
6. Run deploy workflow with `environment=production`.

#### Emergency rollback (via sf CLI directly)

If an immediate rollback is needed without the workflow:

```bash
# Authenticate to the org
sf org login sfdx-url --sfdx-url-file <auth-file> --alias rollback-org

# Cancel an active in-progress deploy
sf project deploy cancel --job-id <deployment-id> --target-org rollback-org

# Deploy the previous version
git checkout <previous-good-tag>
sf project deploy start \
  --source-dir force-app \
  --target-org rollback-org \
  --wait 60
```

### SLA

| Severity                    | Rollback SLA      |
| --------------------------- | ----------------- |
| Critical (production down)  | 1 hour            |
| High (major feature broken) | 4 hours           |
| Medium                      | Next business day |

### Deploy artifacts

- Validate log: artifact `deploy-validate-<run_id>` → `validate.log`, `results/`
- Deploy log: artifact `deploy-<environment>-<run_id>` → `deploy.log`, `results/`

### Related sections

- Hotfix process: Section 15
- Security gate failures: Section 10–13
- Exception lifecycle: Section 13

---

## 18) AI Workflow Disable / Emergency Disable

For the full procedure see **[`docs/AI-GOVERNANCE.md` — Section 4](docs/AI-GOVERNANCE.md#4-disable--rollback-procedure)**.

### Quick-reference: rollback triggers

Act immediately when any of the following conditions are met:

| Trigger                                      | Threshold                                             |
| -------------------------------------------- | ----------------------------------------------------- |
| AI comment accuracy drops                    | < 50% precision for 2+ consecutive quarterly reviews  |
| Pipeline slowdown caused by AI               | Average `ai-summary` job > 5 min over a 1-week window |
| Security incident traced to AI data handling | Any confirmed sensitive content leak via AI prompt    |
| GitHub Models API failure rate               | > 50% persistent failures over 2 weeks                |

### Quick-reference: disable options

- **Single PR** — cancel the `ai-summary` job in Actions UI, or (if label filtering is configured) add a `[skip ai]` label to the PR.
- **All PRs (emergency)** — **Settings → Actions → General → Workflows → AI PR Summary → Disable workflow**.
- **Permanent rollback** — delete `.github/workflows/ai-pr-summary.yml` via a hotfix branch (Section 16); commit with `ci: remove AI PR summary workflow`.

---

## 19) AI Test Recommendations

### What it is

The `ai-test-recommendations.yml` GitHub Actions workflow runs automatically on every pull request. It analyzes the changed files in the PR, calls the AI model, and posts an **advisory** comment listing suggested test cases per file. The comment is informational only — it does not gate the pipeline and does not replace mandatory CI checks.

### How to read the PR comment

The workflow posts a collapsible comment structured as follows:

1. **Advisory disclaimer** — a notice at the top stating that the suggestions are AI-generated and are not a replacement for the project's required test suite.
2. **Recommendations table** — one row per changed file:

    | File                                       | Type | Suggested Test Cases                                                        |
    | ------------------------------------------ | ---- | --------------------------------------------------------------------------- |
    | `force-app/.../myComponent/myComponent.js` | LWC  | Unit test for `connectedCallback`, mock wire adapter for `@wire(getRecord)` |
    | `force-app/.../MyClass.cls`                | Apex | Positive/negative unit tests, bulk data test (200+ records)                 |

3. **Overall risk level** — a single indicator at the bottom of the comment:
    - 🟢 **Low** — config or metadata-only changes, no logic touched.
    - 🟡 **Medium** — logic changes in one or a few files.
    - 🔴 **High** — widespread changes, shared utilities, or security-sensitive code.
4. **Fallback mode** — when the AI model is unavailable the comment shows the changed file list only, without analysis (see [When AI is unavailable](#when-ai-is-unavailable) below).

### File type → test strategy

Use this table to map the file type identified in the comment to the correct test tool:

| File Type               | Detection                              | Required Test Tool                  | Example command                                     |
| ----------------------- | -------------------------------------- | ----------------------------------- | --------------------------------------------------- |
| LWC                     | path matches `**/lwc/**`               | Jest via `sfdx-lwc-jest`            | `npm run test:lwc`                                  |
| Apex class / trigger    | `*.cls`, `*.trigger`                   | `sf apex run test`                  | `sf apex run test --target-org <alias>`             |
| Metadata (non-LWC/Apex) | `force-app/` subtree, other extensions | Manual validation / deploy validate | `sf project deploy validate --source-dir force-app` |
| Config / CI             | `.github/`, `package.json`, etc.       | Review + integration test           | `npm run validate`                                  |

### What to do with AI recommendations

1. Treat the comment as a **checklist supplement**, not an authoritative test plan.
2. Cross-reference suggestions against existing test files under `force-app/main/default/lwc/*/__tests__/` — avoid duplicating tests that already exist.
3. AI suggestions are **starting points**. Verify relevance to the actual change before implementing; discard suggestions for code paths that were not modified.
4. If a suggestion is unclear or wrong, dismiss it and proceed with your own judgment — the comment has no impact on CI status.

### When AI is unavailable

When the GitHub Models API is unreachable or returns an error, the workflow automatically switches to **fallback mode**:

- The PR comment is still posted, listing changed files without AI-generated analysis.
- The workflow job exits with **success** — the pipeline is not blocked.
- No action is required from the developer. This is expected degraded behavior, not an error.

To confirm fallback mode was triggered, check the `ai-test-recommendations` job logs in the Actions tab for the line:

```
AI analysis unavailable — posting fallback comment.
```

### Disabling the workflow

For the general AI workflow disable process, see **Section 18** above.

Specific disable options for `ai-test-recommendations`:

- **Single PR** — cancel the `ai-test-recommendations` job in the Actions UI. The rest of the pipeline is unaffected.
- **All PRs (temporary)** — go to **Settings → Actions → General → Workflows**, find `AI Test Recommendations`, and click **Disable workflow**.
- **All PRs (via repository variable)** — add a repository variable `DISABLE_AI_TEST_REC` with value `true`. The workflow checks this variable at startup and skips execution when it is set.
- **Permanent removal** — delete or rename `.github/workflows/ai-test-recommendations.yml` via a hotfix branch (Section 16); commit with `ci: remove AI test recommendations workflow`.

---

## 20) Local deploy with `npm run deploy`

### What it is

`scripts/deploy.js` is a local Node.js wrapper around `sf project deploy start/validate`. It is intended for deploying directly from your workstation to any authenticated org — dev sandboxes, scratch orgs, or QA environments.

For CI/CD-governed deploys to `staging` and `production`, use the **Actions → Deploy** workflow (Section 17) instead.

### Prerequisites

- Salesforce CLI (`sf`) installed and available in `PATH`.
- Target org authenticated: `sf org login web --alias <alias>` or `sf org login sfdx-url`.

### Options

| Flag              | Short | Default      | Description                                            |
| ----------------- | ----- | ------------ | ------------------------------------------------------ |
| `--target-org`    | `-o`  | _(required)_ | Authenticated org alias or username                    |
| `--validate-only` |       | `false`      | Run `sf project deploy validate` — no actual deploy    |
| `--tests`         | `-t`  | `false`      | Add `--test-level RunLocalTests` to the deploy command |
| `--source-dir`    |       | `force-app`  | Metadata source directory to deploy                    |
| `--wait`          |       | `30`         | Minutes to wait for the operation                      |

### Examples

```bash
# Deploy all metadata to a dev org
npm run deploy -- --target-org my-dev-org

# Validate only — dry run without deploying
npm run deploy -- --target-org my-dev-org --validate-only

# Deploy and run all local Apex tests
npm run deploy -- --target-org my-dev-org --tests

# Deploy a subset of metadata
npm run deploy -- --target-org my-dev-org --source-dir force-app/main/default/classes

# Increase wait timeout for large deployments
npm run deploy -- --target-org my-dev-org --wait 60
```

### Artifacts

Results are written to `.artifacts/deploy/results/` (created automatically). This directory is gitignored.

### Troubleshooting

| Symptom                                         | Cause                                           | Fix                                                                     |
| ----------------------------------------------- | ----------------------------------------------- | ----------------------------------------------------------------------- |
| `Error: --target-org is required`               | Flag not passed                                 | Add `-- --target-org <alias>` (note the `--` separator)                 |
| `Error: source directory 'force-app' not found` | Wrong working directory or missing `force-app/` | Run from repo root; ensure metadata exists                              |
| `failed to run sf: ...`                         | `sf` CLI not in `PATH`                          | Install Salesforce CLI or run `npm run validate` to confirm environment |
| Deploy times out                                | Large deployment or slow org                    | Add `--wait 60` (or higher)                                             |
