---
applyTo: ".gitlab-ci.yml,package.json,sfdx-project.json,eslint.config.js,jest.config.js,.prettierrc,RUNBOOK.md"
---

After modifying this file, check whether `AGENTS.md` and `README.md` need updating.

Update `AGENTS.md` if the change affects any of the following:
- Available `npm` scripts or their behaviour
- CI/CD pipeline jobs (new job, renamed job, changed rules or variables)
- CI/CD variables used in automation
- Salesforce API version (`sourceApiVersion`)
- Tool conventions (linter config, formatter settings, test runner)
- Integration boundaries or authentication patterns

Skip if the change is cosmetic, a bug fix with no behavioural impact, or already accurately reflected in `AGENTS.md`.
