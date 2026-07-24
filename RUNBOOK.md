# DX and CI Runbook

This runbook covers common local development and MR pipeline issues in the `sfdx-project-template` template.

## 1) Local bootstrap

### Symptom

`npm install` fails or dependencies are installed incorrectly.

### Check

```bash
node -v
npm -v
```

### Expected state

- Node.js version 18.11+ (CI jobs run on Node 24)
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

## 5) MR pipeline fails on Salesforce metadata validate

### Symptom

Job `salesforce_validate` finished with an error.

### Common causes

- CI/CD variable `SF_AUTH_URL` (scoped to environment `qa_org`) is not set.
- There are errors in Salesforce metadata.
- The MR contains changes under the metadata root (`force-app/` or `SFDX_METADATA_DIR`).

### Actions

1. Verify that `SF_AUTH_URL` is configured under **Settings → CI/CD → Variables**, scoped to environment `qa_org`.
2. Open the `salesforce_validate` job artifacts (browse in the pipeline view) and inspect the deploy log under `.artifacts/deploy/`.
3. Fix metadata issues and re-run the pipeline.

---

## 6) MR pipeline unexpectedly skips metadata validate

### Symptom

`salesforce_validate` does not run an actual validation.

### Why this happens

The job is intentionally skipped if there are no changes under the metadata root (`force-app/`) in the merge request (`rules: changes:` in `.gitlab-ci.yml`).

### Actions

- If this MR does not include Salesforce metadata, no action is needed.
- If validation was expected, verify the metadata root path:
    - default is `force-app`;
    - or the value of CI/CD variable `SFDX_METADATA_DIR`.

---

## 7) Full local validation before an MR

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

Job `code_analysis` runs in the MR pipeline and reports findings in SARIF format or logs.

### Common causes and handling

- **Real findings** (CRUD/FLS, SOQL injection, best practices, PMD/ESLint Salesforce rules):
    - Review the `code_analysis` job artifact (`results.sarif`).
    - Fix the underlying issue and re-run the pipeline.
- **False positive** (rule too broad, context-specific safety, intentional pattern):
    - Document the reason and severity (e.g., "intentional: test data factory").
    - Follow Section 13 (exception lifecycle) if immediate fix is not possible.

### Severity thresholds and merge policy

The following table defines the enforced security severity thresholds across all CI security jobs.

| Tool                                       | SARIF level / audit level | Merge policy                                 |
| ------------------------------------------- | -------------------------- | --------------------------------------------- |
| **Salesforce Code Analyzer** (`code_analysis`)   | `error` (HIGH / CRITICAL) | ❌ Blocks merge                               |
| **Salesforce Code Analyzer** (`code_analysis`)   | `warning` (MEDIUM)        | ⚠️ Advisory — artifact only, does not block   |
| **Gitleaks secret scan** (`secret_scan`)         | any finding               | ❌ Blocks merge                               |
| **npm audit** (`dependency_audit`)               | `high` / `critical`       | ❌ Blocks merge                               |
| **npm audit** (`dependency_audit`)               | `moderate` / `low`        | ⚠️ Advisory — triage recommended              |

> [!NOTE]
> CodeQL SAST was part of the former GitHub Actions setup and has no direct GitLab Free/Core equivalent — see Section 12 for the coverage gap and mitigation options.

### Local code analysis

Run analysis locally before pushing:

```bash
npm run lint:apex
```

This installs the code-analyzer plugin (if needed) and outputs results to `.artifacts/code-analysis/results.sarif`.

---

## 9) What to include in a bug report

To speed up diagnostics, include:

- reproduction steps;
- exact command and full output;
- Node/npm versions (`node -v`, `npm -v`);
- for CI issues: a pipeline link and the job log/artifacts from `salesforce_validate` or `code_analysis`.

---

## 10) Security gate fails on secret scanning

### Symptom

Job `secret_scan` fails in `.gitlab-ci.yml`.

### Actions

1. Open the `secret_scan` job artifact and review `gitleaks.sarif`.
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

- Any secret-scan finding in the `secret_scan` job fails the pipeline on merge requests and pushes to `main`.
- Merge is blocked until remediation is merged or a documented, time-boxed exception is approved (Section 13).

---

## 11) Security gate fails on dependency audit

### Symptom

Job `dependency_audit` fails due to `npm audit --audit-level=high`.

### Actions

1. Open the `dependency_audit` job artifact and inspect `npm-audit.json`.
2. Identify direct vs transitive vulnerable packages.
3. Apply the safest upgrade path (`npm update`, explicit version bump, or dependency replacement).
4. Re-run the pipeline and confirm no `high`/`critical` findings remain.
5. If no safe fix exists yet, follow Section 13 (exception lifecycle) and create a time-boxed exception.

### Fail policy

- Any `high` or `critical` dependency vulnerability fails the pipeline.
- `moderate`/`low` do not block merge by default, but should be triaged.

---

## 12) SAST coverage gap (CodeQL retired)

### Background

The former GitHub Actions setup included CodeQL SAST (`codeql.yml`) for JavaScript static analysis. CodeQL is a GitHub-exclusive product and has **no direct equivalent on GitLab Free/Core** — GitLab's built-in SAST templates require a Premium/Ultimate license, which is not available in this environment.

### Current mitigation

- `code_analysis` (Salesforce Code Analyzer / PMD-based scanner) still covers Apex/LWC/Aura-specific security rules (CRUD/FLS, SOQL injection, etc.) — see Section 8.
- `secret_scan` and `dependency_audit` remain fully in place — see Sections 10–11.
- General-purpose JavaScript SAST (XSS, injection, insecure patterns outside Salesforce metadata) is **not currently covered**. This is a known, accepted gap.

### If SAST coverage becomes a requirement

- Upgrade the GitLab instance/group to Premium or Ultimate and enable the built-in `SAST.gitlab-ci.yml` template, or
- Add a self-hosted open-source scanner (e.g., Semgrep OSS with the `p/javascript` ruleset) as a custom `.gitlab-ci.yml` job — no license required, but requires ongoing rule maintenance.

Track any decision to close this gap as a normal change to `.gitlab-ci.yml` and this section — it does not require the Section 13 exception process since it is a known, documented gap rather than a temporary bypass.

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
            └── MR → main
                        │
                        └── deploy pipeline job triggered manually
```

**Step-by-step:**

```bash
# 1. Create hotfix branch from main
git checkout -b hotfix/<issue-id>-<description> main

# 2. Implement the fix
# ...

# 3. Commit with conventional commit
git commit -m "fix(<scope>): <description of critical fix>"

# 4. Push and open an MR against main
git push origin hotfix/<issue-id>-<description>
glab mr create --base main --title "fix(<scope>): <description>" --description "Closes #<issue-id>"
# or open the MR from the GitLab UI

# 5. After MR merge, run the deploy job manually:
#    CI/CD → Pipelines → Run pipeline → ref=main → run job `deploy_qa_org`
#    (or any environment added per Section 17)
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

## 17) Deploy pipeline and rollback

### Overview

The deploy jobs (`deploy_validate_qa_org`, `deploy_qa_org` in `.gitlab-ci.yml`) deploy Salesforce metadata to target environments with a mandatory validate step before every deploy.

### Environments

| Environment | CI/CD Variable                          | Protection                                              |
| ----------- | ---------------------------------------- | -------------------------------------------------------- |
| `qa_org`    | `SF_AUTH_URL` (scoped to environment `qa_org`) | GitLab Free/Core has no Protected Environment approval rules — access is controlled by branch/role permissions and manual job execution only |

`qa_org` is the only environment currently wired into `.gitlab-ci.yml`. Both `deploy_validate_qa_org` and `deploy_qa_org` declare `environment: qa_org` and read the `SF_AUTH_URL` CI/CD variable scoped to that environment — there are no project-wide, unscoped secrets involved.

To add more environments (e.g. `staging`, `production`):

1. Duplicate the `deploy_validate_qa_org` / `deploy_qa_org` job pair in `.gitlab-ci.yml` with a new `environment: name:` value (e.g. `staging`).
2. Add a new `SF_AUTH_URL` CI/CD variable scoped to that environment name (**Settings → CI/CD → Variables** → set "Environment scope").

### Required setup

1. In the GitLab project → **Settings → CI/CD → Variables**, add a variable named `SF_AUTH_URL` (Protected + Masked), with **Environment scope** set to `qa_org` (or any additional environment added per above).
2. For production-like environments, restrict who can run manual jobs via **Settings → Repository → Protected branches** (only allow Maintainers to push/merge to `main`) — this is the Free-tier substitute for GitHub's "Required reviewers".

### Running a deploy

1. **CI/CD → Pipelines → Run pipeline**.
2. Select the branch or tag to deploy (default: `main`).
3. Optional: add variable `DRY_RUN` = `true` to only run the validate job, skipping the actual deploy.
4. Run the pipeline; wait for `deploy_validate_qa_org` to pass.
5. If `DRY_RUN` was not set, manually run the `deploy_qa_org` job from the pipeline view (`when: manual`).

### Rollback

Rollback is performed by re-deploying the previous working version.

#### Quick rollback (via pipeline)

1. Find the previous successful deploy in `.artifacts/deploy/deploy.log` or the GitLab **Environments** page (Operate → Environments → `qa_org` → Deployments).
2. Identify the Git commit/tag of the last known-good version:
    ```bash
    git log --oneline --decorate origin/main | head -20
    ```
3. Create a hotfix branch from the known-good tag:
    ```bash
    git checkout -b hotfix/<issue-id>-rollback <previous-good-tag>
    git push origin hotfix/<issue-id>-rollback
    ```
4. Open an MR to `main` and merge (fast-track).
5. Run the deploy pipeline (`CI/CD → Pipelines → Run pipeline`, `deploy_qa_org` job) → verify it works.

#### Emergency rollback (via sf CLI directly)

If an immediate rollback is needed without the pipeline:

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
| --------------------------- | ------------------ |
| Critical (production down)  | 1 hour             |
| High (major feature broken) | 4 hours            |
| Medium                      | Next business day  |

### Deploy artifacts

- Validate log: `deploy_validate_qa_org` job artifacts → `.artifacts/deploy/`
- Deploy log: `deploy_qa_org` job artifacts → `.artifacts/deploy/`

### Related sections

- Hotfix process: Section 15
- Security gate failures: Section 10–12
- Exception lifecycle: Section 13

---

## 18) Local deploy with `npm run deploy`

### What it is

`scripts/deploy.js` is a local Node.js wrapper around `sf project deploy start/validate`. It is intended for deploying directly from your workstation to any authenticated org — dev sandboxes, scratch orgs, or QA environments.

For CI/CD-governed deploys, use the **GitLab CI/CD deploy pipeline** (Section 17) instead.

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
