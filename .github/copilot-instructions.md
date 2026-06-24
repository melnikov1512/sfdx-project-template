# Salesforce Project - Copilot Instructions

> **Documentation is organized using GitHub Copilot's instruction files.**  
> **Each `.instructions.md` file automatically applies to specific file patterns.**

---

## Instruction Files

All instructions are in [`.github/instructions/`](.github/instructions/) directory:

### [apex-patterns.instructions.md](./instructions/apex-patterns.instructions.md)

**Applies to:** `force-app/main/default/classes/**/*.cls`, `force-app/main/default/triggers/**/*.trigger`

- **Apex Documentation (ApexDoc)** ⚠️ Required for all public classes and methods
- **Project Structure & Class Organization** — Required for all new classes
- Trigger Handler Pattern (BaseTriggerHandler)
- Selector Pattern, Service Layer Pattern
- Exception Handling Pattern (ExceptionHandlingService)
- Custom Labels in Apex
- Timezone Handling in Apex

### [lwc-patterns.instructions.md](./instructions/lwc-patterns.instructions.md)

**Applies to:** `force-app/main/default/lwc/**/*.js`, `**/*.html`, `**/*.css`

- **Custom Labels Pattern** — Never hardcode strings
- Utility Pattern (shared utility component)
- **Timezone Handling** — Critical for date/time operations
- @api Properties in Flow Screen Components
- Error Handling, Component Communication

### [flow-lwc.instructions.md](./instructions/flow-lwc.instructions.md)

**Applies to:** `force-app/main/default/flows/**/*.flow-meta.xml`, `**/*.js-meta.xml`

- Complete guide for passing data from List View Flows to LWC
- Selected Record IDs pattern
- Flow variable naming requirements
- LWC meta configuration

### [unit-tests.instructions.md](./instructions/unit-tests.instructions.md)

**Applies to:** `force-app/main/default/classes/tests/**/*.cls`

- **Testing Philosophy** — Test controllers only, coverage through invocation
- **Naming Convention** — `[methodName]Test_[optionalCase]`
- **TestFactory Pattern** — Check if exists, create if not
- **MIXED_DML Solution** — TestFactory wraps User/PermissionSetAssignment inserts in `System.runAs(new User(Id = UserInfo.getUserId()))` internally
- **Assert Class Usage** — Modern assertions with descriptive messages

---

## Essential Quick Rules

### Response Style

- Keep responses short and direct
- List affected files after completion
- **Never commit changes unless explicitly asked to commit**

### Apex Documentation (CRITICAL)

**All public classes and methods MUST have ApexDoc comments:**

```apex
/**
 * @description Brief description of what the class/method does
 * @param paramName `Type` Description of the parameter
 * @return `ReturnType` Description of what is returned (omit if void)
 */
```

See [detailed guidelines](./instructions/apex-patterns.instructions.md#apex-documentation-apexdoc)

### Class Organization (CRITICAL)

All Apex classes must be in subdirectories - **never in root `/classes/` folder**:

```
classes/
 controllers/   # @AuraEnabled, UI controllers
 handlers/      # Trigger handlers (extend BaseTriggerHandler)
 helpers/       # Utilities, Batch, Queueable, Schedulable
 services/      # Business logic layer
 selectors/     # Data access (SOQL queries)
 tests/         # All @isTest classes
 wrappers/      # DTO classes
 constants/     # Constants
```

### Custom Labels (CRITICAL)

**Never hardcode user-facing text** — always use Custom Labels:

- Apex: `System.Label.LabelName`
- LWC: Create `labels.js` module, import and use
- Use component prefixes: `ComponentName_Description`
- Use placeholders: `{0}`, `{1}` for dynamic values

### Exception Handling (CRITICAL)

**Wrap all externally-callable methods in try-catch.** This applies to:

- `@AuraEnabled` methods — called from LWC/Aura components
- `global` / `public` methods — called from integrations or external APIs
- `@InvocableMethod` methods — called from Flow

```apex
@AuraEnabled
public static MyResponse myMethod(Id recordId) {
    try {
        // business logic
        return new MyResponse(result);
    } catch (Exception e) {
        ExceptionHandlingService.handleException(e);
        return null;
    }
}
```

**ExceptionHandlingService** — check before writing:

- **If a class named `ExceptionHandlingService`, `ErrorHandlingService`, or similar already exists** in `classes/services/` → use it
- **If no such class exists** → create `classes/services/ExceptionHandlingService.cls` with:
  - `handleException(Exception e)` — sync context: logs error, throws `AuraHandledException`
  - `handleAsyncException(String context, Exception e)` — async context (Queueable/Batch/Future/Scheduled): logs, notifies
  - `logException(Exception e)` — silent logging only, does not throw

Never throw `AuraHandledException` directly — always route through the service.

### Timezone Handling

- Apex: Use `.dateGMT()` not `.date()`
- JavaScript: Never use `lightning-formatted-date-time` for Date fields
- Use utility component's `formatDate(value, userTimezone)` for consistent formatting
- Always wire user timezone in date-displaying LWC components

---

## How Instructions Work

GitHub Copilot automatically applies the relevant `.instructions.md` files based on the `applyTo` glob patterns defined in each file's frontmatter. When you work on:

- **An Apex class** → `apex-patterns.instructions.md` applies
- **An LWC component** → `lwc-patterns.instructions.md` applies
- **A Flow** → `flow-lwc.instructions.md` applies
- **A test class** → `unit-tests.instructions.md` applies

This ensures context-appropriate guidance without manual switching between documentation files.
