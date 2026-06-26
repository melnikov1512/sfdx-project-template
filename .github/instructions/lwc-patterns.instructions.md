---
applyTo:
  - "force-app/main/default/lwc/**/*.js"
  - "force-app/main/default/lwc/**/*.html"
  - "force-app/main/default/lwc/**/*.css"
---

# LWC Patterns & Best Practices

## Custom Labels Pattern

**CRITICAL**: Never use inline string literals for user-facing text. Always use Custom Labels for internationalization and maintainability.

### Label Naming Convention

**Use component-specific prefixes** to organize labels and avoid naming conflicts:
- **Pattern**: `<ComponentName>_<Description>`
- **Examples**: `MyComponent_SuccessMessage`, `MyComponent_Refresh`, `MyComponent_ExportToCSV`

### Placeholder Pattern for Dynamic Messages

**✅ CORRECT: Use {0}, {1}, {2} placeholders in label values**

```xml
<!-- In CustomLabels.labels-meta.xml -->
<labels>
    <fullName>MyComponent_SuccessMessage</fullName>
    <language>en_US</language>
    <protected>true</protected>
    <shortDescription>MyComponent - Success message</shortDescription>
    <value>{0} records were successfully processed.</value>
</labels>
```

```javascript
// In component.js - Replace placeholders with .replace()
const message = labels.MyComponent_SuccessMessage.replace('{0}', count);
utility.showSuccessToast(message);
```

### LWC Implementation Pattern

**✅ CORRECT: Create a labels.js file for each component**
```javascript
// In componentName/labels.js
import Cancel from '@salesforce/label/c.Cancel';
import Save from '@salesforce/label/c.Save';
import ComponentName_SuccessMessage from '@salesforce/label/c.ComponentName_SuccessMessage';

export default {
    Cancel,
    Save,
    ComponentName_SuccessMessage
};
```

```javascript
// In componentName.js
import { LightningElement } from 'lwc';
import labels from './labels';
import utility from 'c/utility';

export default class ComponentName extends LightningElement {
    labels = { ...labels };
    
    handleSuccess() {
        utility.showSuccessToast(this.labels.ComponentName_SuccessMessage);
    }
    
    handleDynamicMessage(count) {
        const message = this.labels.ComponentName_PlaceholderWithVariable.replace('{0}', count);
        utility.showInfoToast(message);
    }
}
```

```html
<!-- In componentName.html -->
<template>
    <lightning-button label={labels.Cancel}></lightning-button>
    <lightning-button label={labels.ComponentName_Refresh}></lightning-button>
</template>
```

**❌ INCORRECT: Don't use inline string literals**
```javascript
// BAD - Hardcoded strings
utility.showSuccessToast('Operation completed successfully');

// BAD - Hardcoded in template
<lightning-button label="Cancel"></lightning-button>
```

---

## Constants Pattern

**CRITICAL**: Never use business values or configuration strings as literals in JavaScript or HTML templates. Always extract to named constants.

### Decision: where to define a constant

| Scope | Where to define |
|---|---|
| Reused across multiple components or business domains | `constants` export in `c/utility` |
| Used only within one component | `const` at the top of the component's `.js` file |

### Shared constants — `c/utility`

Export a `constants` object from the utility component for values shared across multiple components.

```javascript
// lwc/utility/utility.js
export const constants = {
    STATUS_ACTIVE:   'Active',
    STATUS_INACTIVE: 'Inactive',
    MAX_PAGE_SIZE:   200,
};
```

```javascript
// In any component:
import { constants } from 'c/utility';

if (this.record.Status__c === constants.STATUS_ACTIVE) { }
```

### Local constants — within a component

If a constant is only needed within one component, define it as a module-level `const` at the top of the `.js` file — before the class declaration.

```javascript
// myComponent.js
import { LightningElement } from 'lwc';

const ORDER_STATUS_DRAFT    = 'Draft';
const ORDER_STATUS_APPROVED = 'Approved';
const MAX_ITEMS             = 50;

export default class MyComponent extends LightningElement {

    isEditable(order) {
        return order.Status__c === ORDER_STATUS_DRAFT;
    }
}
```

### No string literals rule

**Every business value and configuration string in JS and HTML must be a named constant or Custom Label — no exceptions.**
This applies to: record statuses, types, codes, API names, limits, keys.
CSS selectors used purely as DOM references within a single component are exempt.

```javascript
// ❌ BAD — business values as string literals
if (this.record.Type__c === 'Partner') { }
if (this.record.Status__c === 'Active') { }
const url = '/apex/MyPage?id=' + recordId;

// ✅ CORRECT
if (this.record.Type__c === constants.ACCOUNT_TYPE_PARTNER) { }
if (this.record.Status__c === constants.STATUS_ACTIVE) { }
const url = PAGE_URL_MY_PAGE + '?id=' + recordId;
```

```html
<!-- ❌ BAD — hardcoded business value passed to logic -->
<c-my-component status="Active"></c-my-component>

<!-- ✅ CORRECT — value comes from JS constant -->
<c-my-component status={defaultStatus}></c-my-component>
```

---

## Utility Pattern

**Before using `c/utility`, check if a shared utility LWC component already exists in the project:**
- Look for `force-app/main/default/lwc/utility/` in the project
- **If found** → import and use it as shown below
- **If not found** → create `lwc/utility/` with `utility.js` exporting the shared helper functions

**✅ CORRECT: Use c/utility for common LWC functions**
```javascript
import utility from 'c/utility';
import { constants } from 'c/utility';

// Format dates consistently (handles both Date and DateTime fields)
const formattedDate = utility.formatDate(invoice.DueDate__c, this.userTimezone);
const formattedCreatedDate = utility.formatDate(transaction.CreatedDate, this.userTimezone);

// Format datetime with time component
const formattedSentDate = utility.formatDateTime(reminder.Sent_Date__c, this.userTimezone);

// Show toast messages
utility.showSuccessToast('Operation completed successfully');
utility.showErrorToast('An error occurred');
utility.showInfoToast('Please note...');

// Handle errors
try {
    // ... operation
} catch (error) {
    utility.handleError(error);
}
```

---

## Timezone Handling in JavaScript

**CRITICAL**: When creating any LWC component that displays dates on the UI, you MUST implement user timezone support.

### Complete Pattern for Date-Displaying Components

**✅ CORRECT: Wire user timezone**
```javascript
import { LightningElement, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import TIMEZONE_FIELD from '@salesforce/schema/User.TimeZoneSidKey';
import utility from 'c/utility';

export default class MyComponent extends LightningElement {
    // Default to PST
    userTimezone = 'America/Los_Angeles';
    
    // Wire user timezone (cached by LWC framework)
    @wire(getRecord, { recordId: USER_ID, fields: [TIMEZONE_FIELD] })
    wiredUser({ error, data }) {
        if (data) {
            this.userTimezone = data.fields.TimeZoneSidKey.value;
        }
    }
    
    // Use utility functions with timezone parameter
    get formattedDueDate() {
        return utility.formatDate(this.record.DueDate__c, this.userTimezone);
    }
    
    get formattedSentDate() {
        return utility.formatDateTime(this.record.Sent_Date__c, this.userTimezone);
    }
    
    // For arrays, pass timezone in map functions
    get formattedTransactions() {
        return this.transactions.map(t => ({
            ...t,
            formattedDate: utility.formatDate(t.CreatedDate, this.userTimezone)
        }));
    }
}
```

### Why This Matters

- Users can have different Salesforce timezone settings (PST, JST, GMT, etc.)
- Browser timezone ≠ Salesforce timezone
- Without timezone parameter, dates may shift (e.g., Feb 11 in Salesforce shows as Feb 10 in UI)
- The `@wire(getRecord)` is cached by LWC framework - no performance impact

### ❌ CRITICAL: Never use `lightning-formatted-date-time` for date fields

```html
<!-- BAD - Applies timezone conversion, causes date shifts -->
<lightning-formatted-date-time 
    value={invoicedetails.dueDate} 
    year="numeric" 
    month="short" 
    day="2-digit">
</lightning-formatted-date-time>
```

### How formatDate Works

The `utility.formatDate()` function automatically handles:
- **Date fields** (YYYY-MM-DD): Direct string parsing
- **DateTime fields** (ISO strings with 'T'): Converts to user's timezone, then extracts date
- **Date objects**: Uses UTC methods

```javascript
// Handles both types automatically
const formattedDueDate = utility.formatDate(invoice.DueDate__c, this.userTimezone);          // Date field
const formattedCreatedDate = utility.formatDate(transaction.CreatedDate, this.userTimezone); // DateTime field
```

### Setting Default Dates

```javascript
// ✅ CORRECT
const today = new Date();
const year = today.getUTCFullYear();
const month = String(today.getUTCMonth() + 1).padStart(2, '0');
const day = String(today.getUTCDate()).padStart(2, '0');
this.dueDate = `${year}-${month}-${day}`;
```

---

## @api Properties in Flow Screen Components

**CRITICAL**: When creating LWC components for Flow screens, `@api` properties are injected AFTER `connectedCallback`.

### ✅ CORRECT: Use getter/setter pattern

```javascript
_recordIds;

@api
get selectedRecordIds() {
    return this._recordIds;
}

set selectedRecordIds(value) {
    // Flow injects @api properties AFTER connectedCallback
    this._recordIds = value;
    if (value && value.length > 0) {
        this.loadRecordData();
    }
}
```

### ❌ INCORRECT: Don't access @api in connectedCallback

```javascript
// BAD - Will be undefined
@api selectedRecordIds;

connectedCallback() {
    console.log(this.selectedRecordIds); // undefined!
}
```

---

## Error Handling

**✅ CORRECT: Use utility.handleError**
```javascript
try {
    const result = await processData({ recordId: this.recordId });
    utility.showSuccessToast('Success');
} catch (error) {
    utility.handleError(error);
}
```

**❌ INCORRECT: Don't write custom error handling**
```javascript
// BAD - Inconsistent error handling
catch (error) {
    console.error(error);
    this.error = error.body?.message || 'Something went wrong';
}
```

---

## Component Communication

### Use Lightning Message Service for cross-component communication

```javascript
import { LightningElement, wire } from 'lwc';
import { publish, MessageContext } from 'lightning/messageService';
import RECORD_UPDATED from '@salesforce/messageChannel/RecordUpdated__c';

export default class Publisher extends LightningElement {
    @wire(MessageContext)
    messageContext;

    handleUpdate() {
        const payload = { recordId: this.recordId };
        publish(this.messageContext, RECORD_UPDATED, payload);
    }
}
```

---

## Best Practices Summary

- ✅ Always use Custom Labels (never hardcode text)
- ✅ Always implement user timezone support for dates
- ✅ Always use utility.formatDate() / utility.formatDateTime()
- ✅ Always use getter/setter for @api properties in Flow components
- ✅ Always use utility functions (showToast, handleError, etc.)
- ❌ Never use lightning-formatted-date-time for Date fields
- ❌ Never hardcode strings in templates or JavaScript
- ❌ Never access @api properties in connectedCallback
