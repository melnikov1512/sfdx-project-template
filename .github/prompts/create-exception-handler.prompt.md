---
mode: agent
description: Create ExceptionHandlingService if one does not exist in the project
---

Create `ExceptionHandlingService` in `force-app/main/default/classes/services/`.

## Step 1 — Check for existing implementation

Search `force-app/main/default/classes/services/` for any file matching:
- `ExceptionHandlingService.cls`
- `ErrorHandlingService.cls`
- `ExceptionService.cls`
- any class whose name contains both "Exception" and "Service"

**If found → STOP.** Use the existing class according to its current API.
**If not found → proceed with Step 2.**

## Step 2 — Create the class

**File:** `force-app/main/default/classes/services/ExceptionHandlingService.cls`
**Meta:** `force-app/main/default/classes/services/ExceptionHandlingService.cls-meta.xml`
**Access:** `public with sharing`
**ApexDoc:** required on the class and every public method

### Required methods (all five)

**1. `handleException(Exception e)` — synchronous, generic**
- Contract: **always throws** `AuraHandledException`, never returns normally
- Log: `System.debug(LoggingLevel.ERROR, message + stacktrace)`
- Throw: `new AuraHandledException(e.getMessage())`
- Used by: `@AuraEnabled`, `@InvocableMethod`, `global`/`public` methods

**2. `handleException(DmlException e)` — synchronous, DML overload**
- Contract: **always throws** `AuraHandledException`, never returns normally
- Extract per-record details via `getNumDml()`, `getDmlFieldNames(i)`, `getDmlMessage(i)`
- Format each error as: `Record N: field1, field2 — error message`
- Log formatted details + stack trace
- Throw: `new AuraHandledException(e.getMessage())`
- Used by: `catch (DmlException e)` blocks in synchronous context

**3. `handleAsyncException(String context, Exception e)` — asynchronous, generic**
- Contract: **never throws** — async transaction is already committed
- Log: `System.debug(LoggingLevel.ERROR, context + ': ' + message)`
- Parameter `e` may be `null`
- Used by: `Queueable.execute()`, `Batch.execute()/finish()`, `@future`, `Schedulable.execute()`

**4. `handleAsyncException(String context, DmlException e)` — asynchronous, DML overload**
- Contract: **never throws**
- Extract per-record details (same as method 2)
- Log: `System.debug(LoggingLevel.ERROR, context + ':\n' + dmlDetails)`
- Used by: `catch (DmlException e)` blocks in asynchronous context

**5. `logException(Exception e)` — silent logging**
- Contract: only logs, does not throw, does not notify
- Log: `System.debug(LoggingLevel.ERROR, message + stacktrace)`
- Used by: non-critical background operations

### Private helper

Extract DML detail formatting into a **private static** `buildDmlDetails(DmlException e)` method
to avoid duplication between methods 2 and 4.

### Caller pattern (include as inline comment in the class)

```apex
// Synchronous:
// try {
//     insert records;
// } catch (DmlException e) {
//     ExceptionHandlingService.handleException(e);
// } catch (Exception e) {
//     ExceptionHandlingService.handleException(e);
// }

// Asynchronous:
// try {
//     insert records;
// } catch (DmlException e) {
//     ExceptionHandlingService.handleAsyncException('MyClass.myMethod', e);
// } catch (Exception e) {
//     ExceptionHandlingService.handleAsyncException('MyClass.myMethod', e);
// }
```

## Constraints

- No static state variables
- No dependencies on other project classes
- No specific logging implementations (Platform Event, Custom Object, etc.)
- No TODO comments
- No methods beyond the five listed above
