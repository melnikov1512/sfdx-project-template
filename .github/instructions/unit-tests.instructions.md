---
applyTo: "force-app/main/default/classes/tests/**/*.cls"
---

# Unit Testing Patterns & Best Practices

## Testing Philosophy

**Target Coverage Strategy**: Test at two levels:

1. **Entry-point classes** — everything callable from outside the Salesforce platform boundary: controllers (`@AuraEnabled`/`@RemoteAction`), `global` classes, REST/SOAP API handlers, Batch Apex, Schedulers, Queueables, and Invocable methods. These tests verify end-to-end user scenarios and ensure integration contracts are met.

2. **Individual modules** — DML/SOQL processors (Selectors, Repositories), Service classes, and any standalone utility logic with non-trivial behaviour. These unit tests isolate module contracts and make regression-spotting faster and more precise.

**Key Principles**:
- Test entry-point classes through their public/global interface (real user scenarios)
- Test service and selector/DML modules independently when they contain logic worth isolating
- Use `System.runAs()` to test under specific user contexts
- Use dynamic test data creation via TestFactory
- Use Assert class for all validations
- Follow consistent naming conventions

---

## Test Method Naming Convention

**Format**: `[methodName]Test[OptionalCase]`

> PMD MethodNamingConventions enforces `[a-z][a-zA-Z0-9]*` — underscores are **not allowed**.

**Examples**:
```apex
@isTest
static void getRecordDataTestSuccess() { }

@isTest
static void getRecordDataTestInvalidId() { }

@isTest
static void processRecordTestSuccess() { }

@isTest
static void processRecordTestBulkOperation() { }
```

**Rules**:
- Start with the exact method name being tested
- Add `Test` suffix
- Optionally append the case in PascalCase directly (e.g., `Success`, `WithRelatedRecord`, `BulkOperation`)
- **No underscores** — PMD rejects them

---

## TestFactory Pattern

### Check Before Writing

Before creating test data helpers, check whether a `TestFactory` class already exists in the project:
- Look in `force-app/main/default/classes/tests/TestFactory.cls`
- **If found** → use its existing methods according to its API
- **If not found** → create `classes/tests/TestFactory.cls` following the structure below

### TestFactory Structure (create if missing)

```apex
/**
 * @description Factory class for creating test data.
 * Provides reusable methods for generating SObjects and users in test context.
 * All user/permission-set creation is wrapped in System.runAs to prevent MIXED_DML errors.
 */
@isTest
public class TestFactory {

    /**
     * @description Creates an admin user with full permissions.
     * Wraps insert in System.runAs to avoid MIXED_DML errors.
     * @return `User` The created admin user
     */
    public static User createAdminUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User(
            Alias            = 'admtest',
            Email            = 'admintest@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName         = 'Test Admin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey     = 'en_US',
            ProfileId        = p.Id,
            TimeZoneSidKey   = 'America/Los_Angeles',
            UserName         = 'admintest@example.com.' + System.currentTimeMillis()
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }
        return u;
    }

    /**
     * @description Retrieves the admin user created in @TestSetup.
     * @return `User` The admin test user
     */
    public static User getAdminUser() {
        return [SELECT Id FROM User WHERE Email = 'admintest@example.com' LIMIT 1];
    }

    /**
     * @description Creates a MyObject__c record for testing.
     * @param name `String` Record name
     * @return `MyObject__c` The created record
     */
    public static MyObject__c createMyObject(String name) {
        MyObject__c obj = new MyObject__c(Name = name);
        insert obj;
        return obj;
    }

    // Add more factory methods as needed for your data model
}
```

### MIXED_DML Solution

Salesforce prohibits mixing setup objects (User, PermissionSetAssignment) and non-setup objects (SObjects) in the same transaction. **TestFactory solves this internally** by wrapping User and PermissionSetAssignment inserts in `System.runAs(new User(Id = UserInfo.getUserId()))`, which creates a new transaction context:

```apex
// Inside TestFactory — the pattern that prevents MIXED_DML
public static User createAdminUser() {
    // ...
    System.runAs(new User(Id = UserInfo.getUserId())) {
        insert testUser;
        insert permSetAssignment;
    }
    return testUser;
}
```

This means **`@TestSetup` can create data in any order** without worrying about MIXED_DML errors.

---

## Test Structure

### Standard Test Class Template

```apex
/**
 * @description Test class for [ControllerName] covering all public methods.
 */
@isTest
private class ControllerNameTest {

    @TestSetup
    static void setupData() {
        // Create admin user (TestFactory handles MIXED_DML internally)
        TestFactory.createAdminUser();

        // Create SObjects in logical order
        MyObject__c myObj = TestFactory.createMyObject('Test Object');
        // ... other shared data
    }

    /**
     * @description Tests [methodName] with [scenario description].
     * Verifies that [expected behavior].
     */
    @isTest
    static void methodNameTestCase() {
        User adminUser = TestFactory.getAdminUser();

        // ✅ Test-specific data setup BEFORE System.runAs()
        // Data unique to this test method must live here, outside runAs.
        MyObject__c testRecord = TestFactory.createMyObject('Specific Record');

        System.runAs(adminUser) {
            // Only test execution lives inside runAs — no data creation here.
            Test.startTest();
            ControllerName.Response resp = ControllerName.methodName(testRecord.Id);
            Test.stopTest();

            Assert.isNotNull(resp, 'Response should not be null');
            Assert.areEqual(expectedValue, resp.someField, 'Field should match expected value');
        }
    }
}
```

### Required Elements

1. **ApexDoc for test class**: Brief description of what's being tested
2. **ApexDoc for each test method**: Describes scenario and expected behavior
3. **@TestSetup**: Call `TestFactory.createAdminUser()` then create shared SObjects
4. **System.runAs()**: Run tests as the admin user. Contains **only the test execution** (startTest/stopTest + assertions). Test-specific data creation must be **before** the `System.runAs()` block.
5. **Test.startTest/stopTest**: Proper governor limit reset
6. **Assert class**: Use modern Assert methods (not System.assert)

---

## Assertion Guidelines

### Use Assert Class (Not System.assert)

**✅ Correct**:
```apex
Assert.isNotNull(result, 'Result should not be null');
Assert.areEqual(5000, record.Amount__c, 'Amount should match expected value');
Assert.isTrue(items.size() >= 2, 'Should return at least 2 items');
Assert.isFalse(list.isEmpty(), 'List should contain items');
```

**❌ Incorrect**:
```apex
System.assert(result != null);         // Don't use
System.assertEquals(5000, record.Amount__c); // Don't use
```

### Common Assertions

```apex
// Null checks
Assert.isNotNull(obj, 'Message');
Assert.isNull(obj, 'Message');

// Equality
Assert.areEqual(expected, actual, 'Message');
Assert.areNotEqual(expected, actual, 'Message');

// Boolean
Assert.isTrue(condition, 'Message');
Assert.isFalse(condition, 'Message');

// Collections
Assert.areEqual(3, list.size(), 'List should have 3 items');
Assert.isFalse(list.isEmpty(), 'List should not be empty');
```

**Always provide descriptive messages** to help identify failures quickly.

---

## Testing Patterns

### Testing Controller Methods

```apex
@isTest
static void getRecordDataTestSuccess() {
    User adminUser = TestFactory.getAdminUser();

    System.runAs(adminUser) {
        Id recordId = [SELECT Id FROM MyObject__c LIMIT 1].Id;

        Test.startTest();
        ControllerName.Response resp = ControllerName.getRecordData(recordId);
        Test.stopTest();

        Assert.isNotNull(resp, 'Response should not be null');
        Assert.areEqual(expectedValue, resp.someField, 'Field should match');
    }
}
```

### Testing Exception Handling

```apex
@isTest
static void methodNameTestExceptionCase() {
    User adminUser = TestFactory.getAdminUser();

    System.runAs(adminUser) {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            ControllerName.methodName(null);
        } catch (Exception e) {
            exceptionThrown = true;
            Assert.isTrue(
                e.getMessage().contains('expected text'),
                'Exception message should contain expected text'
            );
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Should throw exception for invalid input');
    }
}
```

### Testing Bulk Operations

```apex
@isTest
static void methodNameTestBulkOperation() {
    User adminUser = TestFactory.getAdminUser();

    List<MyObject__c> records = new List<MyObject__c>();
    for (Integer i = 0; i < 5; i++) {
        records.add(TestFactory.createMyObject('Record ' + i));
    }
    List<Id> recordIds = new List<Id>(new Map<Id, MyObject__c>(records).keySet());

    System.runAs(adminUser) {
        Test.startTest();
        ControllerName.Response resp = ControllerName.methodName(recordIds);
        Test.stopTest();

        Assert.areEqual(5, resp.resultIds.size(), 'Should process all 5 records');
    }
}
```

---

## DO's and DON'Ts

### ✅ DO

- Call `TestFactory.createAdminUser()` in @TestSetup (it handles MIXED_DML internally)
- Use `System.runAs(adminUser)` in every test method
- Place **test-specific data creation BEFORE `System.runAs()`** — only the actual test execution (startTest/stopTest + assertions) should live inside runAs
- Use Assert class with descriptive messages
- Test entry-point classes (controllers, global classes, APIs, batches, schedulers, queueables, invocables) through their public interface
- Test service and selector/DML module classes independently when they contain isolated logic
- Use overloaded TestFactory methods for different scenarios
- Follow naming convention: `[methodName]Test[Case]` (camelCase, no underscores)
- Add ApexDoc to test class and every test method

### ❌ DON'T

- Don't use `System.assert()` or `System.assertEquals()` — use Assert class
- Don't skip tests for service/selector/DML classes — test them independently when they contain non-trivial logic
- Don't use `test` prefix in method names — use `Test` suffix
- Don't skip ApexDoc on test methods
- Don't create User/PermissionSetAssignment with plain `insert` outside TestFactory — always go through TestFactory methods which handle MIXED_DML
- Don't put data creation logic inside `System.runAs()` — data setup unique to a test method belongs **before** runAs, not inside it

---

## Quick Reference

**@TestSetup Structure**:
```apex
@TestSetup
static void setupData() {
    TestFactory.createAdminUser();   // handles MIXED_DML internally
    MyObject__c obj = TestFactory.createMyObject('Shared Object');
    // ... create other shared test data
}
```

**Test Method Structure**:
```apex
@isTest
static void [methodName]TestCase() {
    User adminUser = TestFactory.getAdminUser();

    // Test-specific data setup BEFORE runAs
    MyObject__c testRecord = TestFactory.createMyObject('Specific Record');

    System.runAs(adminUser) {
        Test.startTest();
        // Act - call controller method
        Test.stopTest();
        // Assert
    }
}
```

**Minimum TestFactory Methods to Create**:
- `createAdminUser()` — admin user with permissions (MIXED_DML safe)
- `getAdminUser()` — retrieves the admin user created in @TestSetup
- `createMyObject(String name)` — creates your primary SObject(s) for testing
- Add more factory methods as your data model requires
