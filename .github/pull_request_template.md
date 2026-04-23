## Summary

<!-- Briefly describe what this PR does and why. -->

## Type of Change

- [ ] Bug fix
- [ ] New feature / enhancement
- [ ] Refactor / cleanup
- [ ] CI / tooling / infrastructure
- [ ] Documentation
- [ ] Salesforce metadata change

## Related Issues

<!-- Link issues closed by this PR, e.g. Closes #9 -->

Closes #

---

## Security Self-Review Checklist

> Complete this section for every PR. If a check is N/A, mark it and briefly explain why.

- [ ] **No secrets or credentials** — no API keys, tokens, passwords, or private keys in code, config, or test data.
- [ ] **Input validation** — all user-supplied input is validated, sanitised, and not passed to eval / exec / innerHTML without escaping.
- [ ] **Dependency hygiene** — new `npm` packages have no known High/Critical CVEs (`npm audit`); version is pinned or ranged conservatively.
- [ ] **Least privilege** — new code does not request unnecessary permissions (org-wide access, admin APIs, broad SOQL without sharing enforcement).
- [ ] **Apex CRUD/FLS** — any new or modified Apex performs proper sharing enforcement (`with sharing`, `stripInaccessible`, or explicit FLS check).
- [ ] **Sensitive data handling** — no PII, credentials, or confidential data is logged, stored unencrypted, or returned in API responses unnecessarily.
- [ ] **Auth / access control** — permission checks are present where expected; no guest/public access introduced unintentionally.
- [ ] **Salesforce metadata** — no permission sets, profiles, or connected apps grant broader access than required.

> If any item is checked **No** or has an exception, document the reason and reference a time-boxed exception issue per `RUNBOOK.md` Section 12.

---

## Testing

- [ ] `npm run validate` passes locally
- [ ] New or changed logic is covered by unit tests
- [ ] Relevant LWC tests updated / added
