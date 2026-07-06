# Salesforce Project - Copilot Instructions

> **Documentation is organized using GitHub Copilot's instruction files.**  
> **Each `.instructions.md` file automatically applies to specific file patterns.**

---

## Instruction Files

> Instruction files in `.github/instructions/` are auto-applied by Copilot based on `applyTo` glob patterns in each file's frontmatter. No manual switching needed.

---

## Essential Quick Rules

### Response Style

- Keep responses short and direct
- List affected files after completion
- **Never commit changes unless explicitly asked to commit**
- **If the message contains a question — answer it, do not jump to implementation.**
  Questions are identified by: question marks, words like "how", "why", "what", "should I", "can I", or any phrasing that seeks information rather than action. Answering a question is not permission to implement anything.

### Planning (CRITICAL)

**When to create a plan:**
If the user's message contains an explicit planning request — create a plan file immediately.
Trigger phrases (and synonyms): "plan this", "prepare a plan", "outline", "create a plan", "let's plan".

- Create the plan file at the correct path right away — do not present the plan inline in chat
- After creating, briefly report the file path and key points

**Save all plans to:**

```
docs/plans/<plan-name>/<plan-name>.md
```

Folder and file name must be kebab-case describing the task.

All supporting files (research, temp scripts, drafts, diagrams) go in the **same plan folder**:

```
docs/plans/<plan-name>/
├── <plan-name>.md
├── research.md
└── any-other-supporting-file
```

Never create supporting files in the root `docs/` or in arbitrary locations.

**Never implement a plan automatically.** After creating a plan, always ask:

> "Ready to implement. Shall I proceed?"

Only begin implementation when the user explicitly confirms (e.g., "yes", "go ahead", "proceed", "implement it").
Approving or commenting on a plan is **not** permission to implement it.

### Custom Labels (CRITICAL)

**Never hardcode user-facing text** — always use Custom Labels:

- Apex: `System.Label.LabelName`
- LWC: Create `labels.js` module, import and use
- Use component prefixes: `ComponentName_Description`
- Use placeholders: `{0}`, `{1}` for dynamic values

### Timezone Handling

- Apex: Use `.dateGMT()` not `.date()`
- JavaScript: Never use `lightning-formatted-date-time` for Date fields
- Use utility component's `formatDate(value, userTimezone)` for consistent formatting
- Always wire user timezone in date-displaying LWC components

---

## How Instructions Work

Copilot automatically loads the relevant `.github/instructions/*.instructions.md` file based on the file you're editing. When you work on:

- **An Apex class or trigger** → `apex-patterns.instructions.md` applies
- **An LWC component** → `lwc-patterns.instructions.md` applies
- **A test class** → `unit-tests.instructions.md` applies
