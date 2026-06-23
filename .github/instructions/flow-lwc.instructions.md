---
applyTo:
  - "force-app/main/default/flows/**/*.flow-meta.xml"
  - "force-app/main/default/lwc/**/*.js-meta.xml"
---

# Flow → LWC Integration Guide

Complete guide for passing selected record IDs from a List View mass action button through a Screen Flow into an LWC component.

---

## The Key Rules

1. **Flow variable MUST be named `ids`** — Salesforce uses this exact name to auto-populate selected row IDs when the flow is launched from a List View button. Any other name and it stays empty.
2. **Flow variable MUST be `isCollection>true`** — Salesforce passes an array of IDs.
3. **The LWC `@api` property name can be anything** (e.g. `selectedRecordIds`) — use a different name than `recordIds` to avoid the Flow validation error.
4. **LWC meta MUST declare `type="String[]"`** — this is what allows Flow to bind a collection variable to the LWC property. Without it, Flow throws an error.

---

## Flow XML Configuration

```xml
<!-- Variable auto-populated by Salesforce with selected List View record IDs -->
<variables>
    <name>ids</name>                    <!-- MUST be exactly "ids" -->
    <dataType>String</dataType>
    <isCollection>true</isCollection>   <!-- MUST be true -->
    <isInput>true</isInput>             <!-- MUST be true -->
    <isOutput>false</isOutput>
</variables>

<!-- Pass collection to the LWC using a DIFFERENT input parameter name -->
<inputParameters>
    <name>selectedRecordIds</name>      <!-- Different name avoids Flow validation error -->
    <value>
        <elementReference>ids</elementReference>
    </value>
</inputParameters>
```

---

## LWC Meta XML Configuration

```xml
<targetConfigs>
    <targetConfig targets="lightning__FlowScreen">
        <property
            name="selectedRecordIds"
            type="String[]"             <!-- String[] is REQUIRED for collection binding -->
            label="Selected Record IDs"
            description="Collection of record IDs passed from the List View mass action."/>
    </targetConfig>
</targetConfigs>
```

---

## LWC JavaScript Implementation

```javascript
_recordIds;

@api
get selectedRecordIds() {
    return this._recordIds;
}

set selectedRecordIds(value) {
    // Flow injects @api properties AFTER connectedCallback, so use getter/setter
    // value will be a String[] e.g. ["001XXXX", "001YYYY"]
    this._recordIds = value;
    const hasValue = Array.isArray(value) ? value.length > 0 : !!value;
    if (hasValue) {
        this.loadRecordData();
    }
}

_parseRecordIds(raw) {
    if (!raw) return [];
    if (Array.isArray(raw)) {
        return raw.map(id => id.trim()).filter(id => id.length > 0);
    }
    // fallback: comma-separated string
    return raw.split(/[\s,;]+/).map(id => id.trim()).filter(id => id.length > 0);
}
```

---

## Why the Name Mismatch Works

| Layer | Name | Why |
|---|---|---|
| Flow variable | `ids` | Salesforce reserved name — auto-populated from List View selection |
| Flow input parameter | `selectedRecordIds` | Can be anything; maps the collection to the LWC |
| LWC `@api` property | `selectedRecordIds` | Must match the input parameter name |

Using `ids` as both the flow variable and the LWC input parameter name does **not** work — Flow throws a validation error when both the variable and the bound property share the same name with `isCollection>true`.

---

## Why `connectedCallback` Is Too Early

In LWC Flow Screen components, `@api` properties are injected **after** `connectedCallback` fires. A plain `@api selectedRecordIds` will always be `undefined` in `connectedCallback`. Use a getter/setter to react the moment the value arrives.

---

## Checklist

| | Requirement |
|---|---|
| Flow variable name | `ids` (exactly) |
| Flow variable `isCollection` | `true` |
| Flow variable `isInput` | `true` |
| Flow input parameter name | anything **except** `recordIds` |
| LWC meta property `type` | `String[]` |
| LWC `@api` | getter/setter (not plain property) |
| LWC `connectedCallback` | do NOT try to read `@api` values here |

---

## Common Pitfalls

### ❌ WRONG: Using wrong variable name
```xml
<!-- BAD - Salesforce won't populate this -->
<variables>
    <name>recordIds</name>  <!-- Must be "ids" -->
</variables>
```

### ❌ WRONG: Using plain @api property
```javascript
// BAD - Will be undefined in connectedCallback
@api selectedRecordIds;

connectedCallback() {
    console.log(this.selectedRecordIds); // undefined!
}
```

### ✅ CORRECT: Use getter/setter pattern
```javascript
// GOOD - Reacts when Flow injects the value
_recordIds;

@api
get selectedRecordIds() {
    return this._recordIds;
}

set selectedRecordIds(value) {
    this._recordIds = value;
    if (value && value.length > 0) {
        this.processRecords();
    }
}
```
