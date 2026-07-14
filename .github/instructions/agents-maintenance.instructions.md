---
applyTo: ".github/workflows/**,package.json,sfdx-project.json,eslint.config.js,jest.config.js,.prettierrc,RUNBOOK.md,docs/AI-GOVERNANCE.md"
---

After modifying this file, check whether `AGENTS.md` and `README.md` need updating.

Update `AGENTS.md` if the change affects any of the following:
- Available `npm` scripts or their behaviour
- CI/CD workflows (new workflow, renamed job, changed triggers or secrets)
- Repository secrets or variables used in automation
- Salesforce API version (`sourceApiVersion`)
- Tool conventions (linter config, formatter settings, test runner)
- Integration boundaries or authentication patterns

Skip if the change is cosmetic, a bug fix with no behavioural impact, or already accurately reflected in `AGENTS.md`.
