---
applyTo:
  - "force-app/main/default/classes/**/*.cls"
  - "force-app/main/default/triggers/**/*.trigger"
---

# Apex Architecture Patterns & Code Organization

## Response Style

- Keep responses short and direct
- Proceed without asking when task is clear
- List affected files after completion
- No lengthy summaries or detailed breakdowns

---

## Apex Documentation (ApexDoc)

**CRITICAL**: All public classes and methods MUST have ApexDoc comments.

Quick format:
```apex
/**
 * @description Brief description of what the method does
 * @param paramName `Type` Description of the parameter
 * @return `ReturnType` Description of what is returned (omit if void)
 */
```

---

## Project Structure & Class Organization

**CRITICAL**: All Apex classes must be in subdirectories. Never create classes directly in the root `/force-app/main/default/classes/` directory.

### Directory Structure

```
force-app/main/default/classes/
├── controllers/      # @AuraEnabled and UI-facing controllers
├── handlers/         # Trigger handlers (extend BaseTriggerHandler)
├── helpers/          # Utility classes, batch jobs, schedulers
├── services/         # Business logic and service layer classes
├── selectors/        # Data access layer (SOQL queries)
├── tests/            # All test classes (@isTest)
├── wrappers/         # DTO classes for data transfer
└── constants/        # Constants and configuration classes
```

### Class Placement Rules

#### Controllers (`/controllers/`)
- Classes with `@AuraEnabled` methods for LWC/Aura components
- Example: `MyObjectController.cls`

#### Handlers (`/handlers/`)
- Trigger handler classes (must extend `BaseTriggerHandler`)
- Example: `MyObjectTriggerHandler.cls`

#### Helpers (`/helpers/`)
- Batch, Queueable, Schedulable, and utility classes
- Example: `MyObjectBatch.cls`, `MyObjectQueueable.cls`

#### Services (`/services/`)
- Business logic layer; reusable service classes
- Example: `MyObjectService.cls`, `ExceptionHandlingService.cls`

#### Selectors (`/selectors/`)
- All SOQL query logic
- Example: `MyObjectSelector.cls`

#### Tests (`/tests/`)
- All `@isTest` classes and TestFactory
- Example: `MyObjectControllerTest.cls`, `TestFactory.cls`

#### Wrappers (`/wrappers/`)
- DTO classes, JSON serialization wrappers
- Example: `MyObjectWrapper.cls`

#### Constants (`/constants/`)
- Constant values and configuration
- Example: `Constants.cls`

---

## Trigger Handler Pattern

**✅ CORRECT**
```apex
// MyObjectTrigger.trigger
trigger MyObjectTrigger on MyObject__c (before insert, before update, before delete,
                                        after insert, after update, after delete, after undelete) {
    BaseTriggerHandler.triggerHandler(MyObjectTriggerHandler.class);
}

// MyObjectTriggerHandler.cls
public class MyObjectTriggerHandler extends BaseTriggerHandler {

    public override void onBeforeInsert() {
        List<MyObject__c> newRecords = (List<MyObject__c>) Trigger.new;
    }

    public override void onAfterInsert() { }

    public override void onBeforeUpdate() {
        Map<Id, MyObject__c> oldMap = (Map<Id, MyObject__c>) Trigger.oldMap;
    }
    // onAfterUpdate(), onBeforeDelete(), onAfterDelete(), onAfterUndelete()
}
```

**❌ INCORRECT: No business logic in trigger files**

---

## Selector Pattern (Data Access Layer)

**✅ CORRECT: All SOQL in selector classes**
```apex
List<MyObject__c> records = MyObjectSelector.getByParentId(parentId);
```

```apex
public with sharing class MyObjectSelector {

    /**
     * @description Returns records by parent ID
     * @param parentId `Id` Parent record ID
     * @return `List<MyObject__c>` Matching records
     */
    public static List<MyObject__c> getByParentId(Id parentId) {
        return [
            SELECT Id, Name, Status__c, ParentObject__c
            FROM MyObject__c
            WHERE ParentObject__c = :parentId
        ];
    }
}
```

**❌ INCORRECT: No ad-hoc SOQL scattered across controllers/services**

---

## Service Layer Pattern

```apex
public with sharing class MyObjectService {

    /**
     * @description Processes a list of records
     * @param recordIds `List<Id>` IDs to process
     */
    public static void processRecords(List<Id> recordIds) {
        List<MyObject__c> records = MyObjectSelector.getByIds(recordIds);
        // business logic
        update records;
    }
}
```

---

## Exception Handling Pattern

**CRITICAL**: All externally-callable methods must be wrapped in try-catch. This applies to:
- `@AuraEnabled` methods — called from LWC/Aura
- `global` / `public` methods — called from integrations
- `@InvocableMethod` methods — called from Flow

### ExceptionHandlingService — Check Before Writing

Before implementing exception handling, check whether a service class already exists:
- Look in `force-app/main/default/classes/services/` for `ExceptionHandlingService.cls`, `ErrorHandlingService.cls`, or similar
- **If found** → use it according to its existing API
- **If not found** → create `classes/services/ExceptionHandlingService.cls` following the structure below

### ExceptionHandlingService Structure (create if missing)

```apex
/**
 * @description Centralized exception handling service.
 * Routes exceptions to logging and user notification depending on context.
 */
public with sharing class ExceptionHandlingService {

    /**
     * @description Handles exceptions in synchronous context (controllers, services).
     * Logs the error and throws AuraHandledException for the client.
     * @param e `Exception` The caught exception
     */
    public static void handleException(Exception e) {
        // TODO: add your logging mechanism (Platform Event, Custom Object, etc.)
        System.debug(LoggingLevel.ERROR, e.getMessage() + '\n' + e.getStackTraceString());
        throw new AuraHandledException(e.getMessage());
    }

    /**
     * @description Handles exceptions in asynchronous context (Queueable, Batch, Future, Scheduled).
     * Logs the error and sends a notification — does not throw.
     * @param context `String` Description of the operation that failed
     * @param e `Exception` The caught exception
     */
    public static void handleAsyncException(String context, Exception e) {
        String message = context + (e != null ? ': ' + e.getMessage() : '');
        System.debug(LoggingLevel.ERROR, message);
        // TODO: add async notification (e.g., send email, create log record)
    }

    /**
     * @description Silently logs an exception without throwing or notifying.
     * Use for non-critical background operations.
     * @param e `Exception` The caught exception
     */
    public static void logException(Exception e) {
        System.debug(LoggingLevel.ERROR, e.getMessage() + '\n' + e.getStackTraceString());
        // TODO: add your logging mechanism
    }
}
```

### Usage Examples

**✅ Synchronous controller method**
```apex
@AuraEnabled
public static MyResponse myMethod(Id recordId) {
    try {
        MyObject__c record = MyObjectSelector.getById(recordId);
        MyObjectService.processRecord(record);
        return new MyResponse(record);
    } catch (Exception e) {
        ExceptionHandlingService.handleException(e);
        return null;
    }
}
```

**✅ InvocableMethod (Flow)**
```apex
@InvocableMethod(label='Process Records')
public static void processFromFlow(List<Id> recordIds) {
    try {
        MyObjectService.processRecords(recordIds);
    } catch (Exception e) {
        ExceptionHandlingService.handleException(e);
    }
}
```

**✅ Async context (Queueable / Batch / Future)**
```apex
public void execute(QueueableContext context) {
    try {
        // async business logic
    } catch (Exception e) {
        ExceptionHandlingService.handleAsyncException('MyQueueable.execute', e);
    }
}
```

**❌ INCORRECT: Don't throw AuraHandledException directly**
```apex
// BAD — bypasses logging, fails in async context
throw new AuraHandledException(e.getMessage());
```

---

## Constants Usage

Before writing string literals, check for a `Constants.cls` in `classes/constants/`:
- **If found** → use its defined constants
- **If not found** → create `classes/constants/Constants.cls`

```apex
public class Constants {
    public static final String STATUS_ACTIVE   = 'Active';
    public static final String STATUS_INACTIVE = 'Inactive';
    public static final String RT_STANDARD     = 'Standard';
}
```

```apex
// CORRECT
if (record.Status__c == Constants.STATUS_ACTIVE) { }

// BAD — magic string
if (record.Status__c == 'Active') { }
```

---

## Custom Labels in Apex

**CRITICAL**: Never use inline string literals for user-facing text. Always use Custom Labels.

```apex
// CORRECT
ExceptionHandlingService.handleException(new AuraHandledException(System.Label.MyLabel_ValidationError));

// BAD
ExceptionHandlingService.handleException(new AuraHandledException('Validation failed'));
```

---

## Timezone Handling in Apex

**CRITICAL**: All date/time operations must be timezone-aware.

**✅ CORRECT: Use `.dateGMT()` for DateTime to Date conversion**
```apex
Date recordDate = record.CreatedDate.dateGMT();
DateTime now    = DateTime.now();
Date today      = now.dateGMT();
```

**❌ INCORRECT: Don't use `.date()` or `Date.today()`**
```apex
// BAD — applies user's timezone, causes date shifts
Date recordDate = record.CreatedDate.date();
Date today      = Date.today();
```
