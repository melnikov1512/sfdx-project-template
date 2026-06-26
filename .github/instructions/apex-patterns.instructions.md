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
├── exceptions/       # Custom exception classes (extend Exception)
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

#### Exceptions (`/exceptions/`)
- Custom exception classes
- Must end with `Exception` and extend `Exception`
- Example: `MyObjectException.cls`, `IntegrationException.cls`

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

## Public Methods as Thin Orchestrators

**CRITICAL**: Public methods are entry points and orchestrators — not the place for business logic.
Business logic lives in private methods. This enforces readability, Single Responsibility, and keeps try-catch cleanly at the boundary.

### Rules

- Public method body should read like a description of the process (~5–7 lines)
- Private methods named in `verbNoun` format: `validateInput`, `buildResponse`, `persistRecord`
- One private method = one responsibility
- `try-catch` only in public methods (boundary layer); private methods just throw
- If a method is hard to name in a single phrase — it needs to be split

```apex
// ❌ Public method doing everything
@AuraEnabled
public static OrderResponse createOrder(OrderRequest req) {
    try {
        if (req.accountId == null) { throw new OrderException('...'); }
        List<Product2> products = [SELECT Id FROM Product2 WHERE Id IN :req.productIds];
        Order__c order = new Order__c(Account__c = req.accountId, Status__c = 'Draft');
        insert order;
        List<OrderItem__c> items = new List<OrderItem__c>();
        for (Product2 p : products) {
            items.add(new OrderItem__c(Order__c = order.Id, Product__c = p.Id));
        }
        insert items;
        return new OrderResponse(order.Id);
    } catch (Exception e) {
        ExceptionHandlingService.handleException(e);
        return null;
    }
}

// ✅ Public method as thin orchestrator
@AuraEnabled
public static OrderResponse createOrder(OrderRequest req) {
    try {
        validateRequest(req);
        List<Product2> products = fetchProducts(req.productIds);
        Order__c order = createOrderRecord(req.accountId);
        createOrderItems(order.Id, products);
        return buildResponse(order.Id);
    } catch (Exception e) {
        ExceptionHandlingService.handleException(e);
        return null;
    }
}

private static void validateRequest(OrderRequest req) {
    if (req.accountId == null) {
        throw new OrderException(System.Label.Order_AccountRequired);
    }
}

private static List<Product2> fetchProducts(List<Id> productIds) {
    return ProductSelector.getByIds(productIds);
}

private static Order__c createOrderRecord(Id accountId) {
    Order__c order = new Order__c(Account__c = accountId, Status__c = 'Draft');
    insert order;
    return order;
}

private static void createOrderItems(Id orderId, List<Product2> products) {
    List<OrderItem__c> items = new List<OrderItem__c>();
    for (Product2 p : products) {
        items.add(new OrderItem__c(Order__c = orderId, Product__c = p.Id));
    }
    insert items;
}

private static OrderResponse buildResponse(Id orderId) {
    return new OrderResponse(orderId);
}
```

---

## Exception Handling Pattern

**CRITICAL**: All externally-callable methods must be wrapped in try-catch. This applies to:
- `@AuraEnabled` methods — called from LWC/Aura
- `global` / `public` methods — called from integrations
- `@InvocableMethod` methods — called from Flow

### Fail Fast vs Graceful Degradation

Each layer of the application has a different error-handling responsibility:

| Layer | Strategy | Why |
|---|---|---|
| Business logic (service, selector) | **Fail fast** — throw immediately | The caller must know about the problem |
| Boundary (controller, @InvocableMethod) | **Graceful** — catch, log, return user-friendly response | The user must not see stack traces |
| Async (Queueable, Batch, Future, Scheduled) | **Graceful** — catch, log, **never throw** | No caller exists to catch — transaction is already committed |

```apex
// ✅ Service — fail fast, no try-catch
public static void validateRecord(MyObject__c record) {
    if (record.Amount__c < 0) {
        throw new MyObjectException(System.Label.MyObject_AmountNegative);
    }
}

// ✅ Controller — boundary, catches everything
@AuraEnabled
public static void save(MyObject__c record) {
    try {
        MyObjectService.validateRecord(record);
        insert record;
    } catch (Exception e) {
        ExceptionHandlingService.handleException(e);
    }
}
```

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
     * @description Handles exceptions in synchronous context.
     * Logs the error and throws AuraHandledException for the client.
     * @param e `Exception` The caught exception
     */
    public static void handleException(Exception e) {
        System.debug(LoggingLevel.ERROR, e.getMessage() + '\n' + e.getStackTraceString());
        throw new AuraHandledException(e.getMessage());
    }

    /**
     * @description Handles DmlException in synchronous context.
     * Extracts per-record DML error details before throwing AuraHandledException.
     * @param e `DmlException` The caught DML exception
     */
    public static void handleException(DmlException e) {
        System.debug(LoggingLevel.ERROR, buildDmlDetails(e) + '\n' + e.getStackTraceString());
        throw new AuraHandledException(e.getMessage());
    }

    /**
     * @description Handles exceptions in asynchronous context.
     * Logs the error — does not throw.
     * @param context `String` Description of the operation that failed
     * @param e `Exception` The caught exception (may be null)
     */
    public static void handleAsyncException(String context, Exception e) {
        String message = context + (e != null ? ': ' + e.getMessage() : '');
        System.debug(LoggingLevel.ERROR, message);
    }

    /**
     * @description Handles DmlException in asynchronous context.
     * Extracts per-record DML error details and logs without throwing.
     * @param context `String` Description of the operation that failed
     * @param e `DmlException` The caught DML exception
     */
    public static void handleAsyncException(String context, DmlException e) {
        String message = context + ':\n' + buildDmlDetails(e);
        System.debug(LoggingLevel.ERROR, message);
    }

    /**
     * @description Silently logs an exception without throwing or notifying.
     * Use for non-critical background operations.
     * @param e `Exception` The caught exception
     */
    public static void logException(Exception e) {
        System.debug(LoggingLevel.ERROR, e.getMessage() + '\n' + e.getStackTraceString());
    }

    private static String buildDmlDetails(DmlException e) {
        List<String> errors = new List<String>();
        for (Integer i = 0; i < e.getNumDml(); i++) {
            errors.add(
                'Record ' + i + ': ' +
                String.join(e.getDmlFieldNames(i), ', ') +
                ' — ' + e.getDmlMessage(i)
            );
        }
        return String.join(errors, '\n');
    }
}
```

### Custom Exception Types

**CRITICAL**: Create custom exceptions for business validation errors, integration failures, and invariant violations — not generic `Exception`.

**Rules:**
- Class name **must end with `Exception`** (Salesforce requirement)
- Class **must extend `Exception`**
- Stored as a separate file in `classes/exceptions/` — not as inner classes
- Use Custom Labels for exception messages

```apex
// classes/exceptions/MyObjectException.cls
public class MyObjectException extends Exception {}

// Usage in service:
public static void validateRecord(MyObject__c record) {
    if (record.Status__c == null) {
        throw new MyObjectException(System.Label.MyObject_StatusRequired);
    }
}
```

### Usage Examples

**✅ Synchronous controller — DML + generic catch**
```apex
@AuraEnabled
public static MyResponse myMethod(Id recordId) {
    try {
        MyObject__c record = MyObjectSelector.getById(recordId);
        MyObjectService.processRecord(record);
        return new MyResponse(record);
    } catch (DmlException e) {
        ExceptionHandlingService.handleException(e);
        return null;
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
    } catch (DmlException e) {
        ExceptionHandlingService.handleException(e);
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
    } catch (DmlException e) {
        ExceptionHandlingService.handleAsyncException('MyQueueable.execute', e);
    } catch (Exception e) {
        ExceptionHandlingService.handleAsyncException('MyQueueable.execute', e);
    }
}
```

**✅ Rethrow with context between layers**
```apex
// Wrap with context when re-throwing across layers — preserves original stack trace
try {
    Database.insert(records);
} catch (DmlException e) {
    throw new MyObjectException(
        'Failed to insert MyObject for parent: ' + parentId + '. ' + e.getMessage(),
        e // inner exception — getCause() retrieves the original
    );
}
```

**✅ Finally for resource/state cleanup**
```apex
// finally always executes — even if catch re-throws
try {
    HttpResponse res = new Http().send(req);
    processResponse(res);
} catch (CalloutException e) {
    ExceptionHandlingService.handleException(e);
} finally {
    MyState.isProcessing = false;
}
```

**❌ INCORRECT: Don't throw AuraHandledException directly**
```apex
// BAD — bypasses logging, fails in async context
throw new AuraHandledException(e.getMessage());
```

### Anti-patterns

```apex
// ❌ Swallowing — error disappears silently
try {
    process(record);
} catch (Exception e) { }

// ❌ Swallowing with debug — exception is still lost
try {
    process(record);
} catch (Exception e) {
    System.debug(e.getMessage()); // use ExceptionHandlingService instead
}

// ❌ Exceptions for flow control — use explicit condition checks
try {
    result = records[100];
} catch (Exception e) {
    result = null; // correct: records.size() > 100 ? records[100] : null
}
```

---

## Constants Pattern

**CRITICAL**: Never use string literals anywhere in code. Always extract to constants or Custom Labels.

### Decision: where to define a constant

| Scope | Where to define |
|---|---|
| Reused across multiple classes or business domains | `classes/constants/Constants.cls` (global) |
| Used only within one class or one service | Private constant in that class/service |

### Global constants — `Constants.cls`

Before writing any string literal, check for `Constants.cls` in `classes/constants/`:
- **If found** → use its defined constants or add new ones
- **If not found** → create `classes/constants/Constants.cls`

```apex
public class Constants {
    public static final String STATUS_ACTIVE   = 'Active';
    public static final String STATUS_INACTIVE = 'Inactive';
    public static final String RT_STANDARD     = 'Standard';
}
```

```apex
// ✅ CORRECT
if (record.Status__c == Constants.STATUS_ACTIVE) { }

// ❌ BAD — magic string
if (record.Status__c == 'Active') { }
```

### Local constants — within a class

If a constant is only needed within one class, define it as a `private static final` field in that class.
Do not pollute `Constants.cls` with values that have no meaning outside a single context.

```apex
public class OrderService {

    private static final String ORDER_STATUS_DRAFT    = 'Draft';
    private static final String ORDER_STATUS_APPROVED = 'Approved';
    private static final Integer MAX_LINE_ITEMS       = 100;

    public static void approveOrder(Order__c order) {
        if (order.Status__c != ORDER_STATUS_DRAFT) {
            throw new OrderException(System.Label.Order_MustBeDraft);
        }
        order.Status__c = ORDER_STATUS_APPROVED;
    }
}
```

### No string literals rule

**Every string value in code must be a named constant or Custom Label — no exceptions.**

```apex
// ❌ BAD — string literals everywhere
if (record.Type__c == 'Partner' && record.Region__c == 'EMEA') { }
sendEmail('noreply@company.com', 'Welcome!');

// ✅ CORRECT
if (record.Type__c == Constants.ACCOUNT_TYPE_PARTNER && record.Region__c == Constants.REGION_EMEA) { }
sendEmail(Constants.EMAIL_NOREPLY, System.Label.Email_WelcomeSubject);
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
