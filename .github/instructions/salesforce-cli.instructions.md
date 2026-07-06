---
applyTo:
  - "sfdx-project.json"
  - "config/**"
  - "manifest/**"
  - ".forceignore"
---

# Salesforce CLI — Local Development Workflow

## Command Preference

- Always use `sf` (SF CLI v2), not `sfdx` (deprecated)
- API version is pinned to `66.0` — do not override unless explicitly asked

---

## Authentication

```bash
# Authenticate with SFDX URL (CI/CD style)
sf org login sfdx-url --sfdx-url-file <file> --alias <alias>

# Authenticate interactively (browser)
sf org login web --alias <alias>

# Set default org
sf config set target-org <alias>

# Check current auth
sf org display
```

---

## Scratch Org Lifecycle

```bash
# Create scratch org (definition in config/project-scratch-def.json)
sf org create scratch --definition-file config/project-scratch-def.json --alias <alias> --duration-days 30 --set-default

# Open scratch org in browser
sf org open --target-org <alias>

# List all orgs
sf org list

# Delete scratch org
sf org delete scratch --target-org <alias> --no-prompt
```

---

## Deploy & Retrieve

```bash
# Deploy all source to default org
sf project deploy start --source-dir force-app

# Deploy specific metadata
sf project deploy start --source-dir force-app/main/default/classes/MyClass.cls

# Validate only (no deploy)
sf project deploy validate --source-dir force-app

# Retrieve all tracked changes from org
sf project retrieve start --source-dir force-app

# Retrieve specific metadata
sf project retrieve start --metadata ApexClass:MyClass
```

---

## Running Apex Tests

```bash
# Run all local tests
sf apex run test --test-level RunLocalTests --wait 10

# Run specific test class
sf apex run test --class-names MyClassTest --wait 10

# Run with code coverage
sf apex run test --class-names MyClassTest --code-coverage --wait 10
```

---

## Permission Sets

```bash
# Assign permission set to current user
sf org assign permset --name MyPermissionSet

# Assign to specific user
sf org assign permset --name MyPermissionSet --on-behalf-of user@example.com
```

---

## Useful Utilities

```bash
# Execute anonymous Apex
sf apex run --file scripts/apex/myScript.apex

# Run SOQL query
sf data query --query "SELECT Id, Name FROM Account LIMIT 10"

# Tail debug logs
sf apex tail log --color

# Generate password for scratch org user
sf org generate password
```

---

## .forceignore Rules

- `**/__tests__/**` — Jest test files excluded from push/pull
- Do not add `force-app/` itself — it is the deploy root
- Keep in sync with `.gitignore` for generated/local files

---

## Key Files

| File                              | Purpose                                     |
| --------------------------------- | ------------------------------------------- |
| `sfdx-project.json`               | Package directories, API version, namespace |
| `config/project-scratch-def.json` | Scratch org features and settings           |
| `.forceignore`                    | Files excluded from source push/pull        |
