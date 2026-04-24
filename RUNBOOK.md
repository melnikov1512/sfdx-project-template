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
  - Follow Section 12 (time-boxed exception) if immediate fix is not possible.

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
- for CI issues: a run link and log from artifact `salesforce-validate-<run_id>`.

---

## 9) What to include in a bug report

To speed up diagnostics, include:

- reproduction steps;
- exact command and full output;
- Node/npm versions (`node -v`, `npm -v`);
- for CI issues: a run link and log from artifact `salesforce-validate-<run_id>` or `code-analysis-<run_id>`.

---

## 10) Security gate fails on secret scanning

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
4. If false positive, follow Section 11 (time-boxed exception) and add an owner for cleanup.

### SLA

- `critical`: remediate or block merge within 4 hours.
- `high`: remediate or block merge within 1 business day.

### Fail policy

- Any secret-scan finding in `.github/workflows/security-gates.yml` fails CI on `pull_request` and `push` to `main`.
- Merge is blocked until remediation is merged or a documented, time-boxed exception is approved (Section 11).

---

## 11) Security gate fails on dependency audit

### Symptom

Job `Dependency Audit (High/Critical Gate)` fails due to `npm audit --audit-level=high`.

### Actions

1. Open artifact `dependency-audit-<run_id>` and inspect `npm-audit.json`.
2. Identify direct vs transitive vulnerable packages.
3. Apply the safest upgrade path (`npm update`, explicit version bump, or dependency replacement).
4. Re-run CI and confirm no `high`/`critical` findings remain.
5. If no safe fix exists yet, follow Section 11 and create a time-boxed exception.

### Fail policy

- Any `high` or `critical` dependency vulnerability fails CI.
- `moderate`/`low` do not block merge by default, but should be triaged.

---

## 11) Security gate fails on dependency audit

### Symptom

Job `Dependency Audit (High/Critical Gate)` fails due to `npm audit --audit-level=high`.

### Actions

1. Open artifact `dependency-audit-<run_id>` and inspect `npm-audit.json`.
2. Identify direct vs transitive vulnerable packages.
3. Apply the safest upgrade path (`npm update`, explicit version bump, or dependency replacement).
4. Re-run CI and confirm no `high`/`critical` findings remain.
5. If no safe fix exists yet, follow Section 11 and create a time-boxed exception.

### Fail policy

- Any `high` or `critical` dependency vulnerability fails CI.
- `moderate`/`low` do not block merge by default, but should be triaged.

---

## 13) CodeQL SAST fails in CI

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
   - No PR block after dismissal, but keep a record per Section 12.

### Fail policy

| Severity        | SARIF level | Action                                                          |
| --------------- | ----------- | --------------------------------------------------------------- |
| Critical / High | `error`     | Blocks merge; must be fixed or dismissed with documented reason |
| Medium          | `warning`   | Advisory; visible in Security tab, does not block merge         |
| Low / Info      | `note`      | Informational; no action required                               |

---

## 12) Exception lifecycle (time-boxed risk acceptance)

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

## 15) Release process

Releases are triggered **manually** via GitHub Actions workflow dispatch (`.github/workflows/release.yml`).

### How to trigger a release

1. Go to **Actions → Release → Run workflow** in GitHub UI.
2. Select the branch (`main`) and fill in the inputs:
   - **bump_type**: `patch` | `minor` | `major`
   - **dry_run**: `true` to preview the new version without making changes (recommended before first real release)
3. Click **Run workflow**.

### What the workflow does

```
[You click "Run workflow" with bump_type=minor]
        ↓
npm version minor --no-git-tag-version  →  package.json: 1.0.0 → 1.1.0
        ↓
git commit "chore(release): v1.1.0"  →  pushed to main
        ↓
git tag v1.1.0  →  pushed to origin
        ↓
gh release create v1.1.0 --generate-notes  →  GitHub Release published
```

### Release checklist

- [ ] All feature PRs for this release are merged into `main`.
- [ ] All CI checks on `main` are green.
- [ ] No open critical issues that should block this release.
- [ ] Confirm the correct `bump_type` against SemVer rules (Section 14).
- [ ] Optionally run **dry_run=true** first to verify the resulting version.

### CLI equivalent (emergency / offline)

If GitHub UI is unavailable:

```bash
# 1. Bump version (no git tag)
npm version patch|minor|major --no-git-tag-version

# 2. Commit and push
git add package.json package-lock.json
git commit -m "chore(release): vX.Y.Z"
git push origin main

# 3. Tag and push tag
git tag vX.Y.Z
git push origin vX.Y.Z

# 4. Create GitHub Release
gh release create vX.Y.Z --title "vX.Y.Z" --generate-notes --latest
```

---

## 16) Hotfix process

A hotfix addresses a critical production defect that cannot wait for the normal release cycle.

### When to use a hotfix

- Security vulnerability requiring immediate patch (SLA: critical = 4 h, high = 1 business day).
- Production-blocking regression introduced in the previous release.

### Hotfix workflow

```
main (vX.Y.Z — released)
  │
  └── hotfix/<issue-id>-<short-description>
            │
            │  fix: <description>  ← conventional commit
            │
            └── PR → main
                        │
                        └── release-please creates PATCH release vX.Y.(Z+1)
```

**Step-by-step:**

```bash
# 1. Create hotfix branch from main (latest tag)
git checkout -b hotfix/<issue-id>-<description> main

# 2. Implement the fix
# ...

# 3. Commit with conventional commit (fix: triggers PATCH bump)
git commit -m "fix(<scope>): <description of critical fix>"

# 4. Push and open PR against main
git push origin hotfix/<issue-id>-<description>
gh pr create --base main --title "fix(<scope>): <description>" --body "Closes #<issue-id>"

# 5. After PR merge, release-please will open a PATCH Release PR
# 6. Merge the Release PR → vX.Y.(Z+1) tag + GitHub Release created automatically
```

### Hotfix SLA

| Severity | Max time to release  |
| -------- | -------------------- |
| Critical | 4 hours              |
| High     | 1 business day       |
| Medium   | Next regular release |

### Hotfix exception

If the fix requires bypassing normal quality gates (e.g., emergency secret rotation), follow Section 12 (time-boxed exception) and document:

- `owner`, `reason`, `scope`, `expiration_date`, `rollback_trigger`.
