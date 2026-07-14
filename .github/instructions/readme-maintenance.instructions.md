---
applyTo: "README.md,.github/workflows/**,package.json,sfdx-project.json,eslint.config.js,jest.config.js,.prettierrc,.github/agents/**,.github/instructions/**,.github/skills/**,.github/prompts/**"
---

After modifying this file, check whether `README.md` needs updating.

Update `README.md` if the change affects any of the following:
- `npm` scripts listed in the **Commands** table (added, renamed, removed, or changed behaviour)
- Prerequisites (Node.js version, SF CLI requirement, new required secrets or variables)
- CI/CD workflows listed in the **CI/CD pipelines** table (new workflow, renamed job, changed trigger)
- Project structure (new top-level directory or significant structural change)
- GitHub Copilot integration counts or file listings (agents, skills, instruction files, prompts)
- Repository secrets or variables that users must configure
- Salesforce API version badge (`sourceApiVersion` in `sfdx-project.json`)

Skip if the change is cosmetic, a bug fix with no user-visible impact, or already accurately reflected in `README.md`.
