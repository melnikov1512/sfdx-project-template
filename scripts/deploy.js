#!/usr/bin/env node
// scripts/deploy.js — Salesforce metadata deploy wrapper
//
// Usage:
//   node scripts/deploy.js --target-org <alias> [options]
//   npm run deploy -- --target-org <alias> [options]
//
// Options:
//   --target-org, -o   (required) Authenticated org alias
//   --tests,      -t   Add --test-level RunLocalTests (validate) / RunRelevantTests (deploy)
//   --validate-only    Run sf project deploy validate instead of start
//   --source-dir       Metadata source directory (default: force-app)
//   --wait             Minutes to wait for the operation (default: 30)

'use strict';

const { spawnSync } = require('node:child_process');
const { mkdirSync, existsSync } = require('node:fs');
const path = require('node:path');

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------

const args = process.argv.slice(2);

let targetOrg = '';
let tests = false;
let validateOnly = false;
let sourceDir = 'force-app';
let wait = 30;

for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    switch (arg) {
        case '--target-org':
        case '-o':
            targetOrg = args[++i];
            if (!targetOrg) fatal('--target-org requires a value');
            break;
        case '--tests':
        case '-t':
            tests = true;
            break;
        case '--validate-only':
            validateOnly = true;
            break;
        case '--source-dir':
            sourceDir = args[++i];
            if (!sourceDir) fatal('--source-dir requires a value');
            break;
        case '--wait':
            wait = args[++i];
            if (!wait) fatal('--wait requires a value');
            break;
        default:
            fatal(`unknown option: ${arg}`);
    }
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

if (!targetOrg) fatal('--target-org is required');
if (!existsSync(sourceDir)) fatal(`source directory '${sourceDir}' not found`);

// ---------------------------------------------------------------------------
// Setup artifacts dir
// ---------------------------------------------------------------------------

const artifactsDir = '.artifacts/deploy';
mkdirSync(path.join(artifactsDir, 'results'), { recursive: true });

// ---------------------------------------------------------------------------
// Build sf command
// ---------------------------------------------------------------------------

const subcommand = validateOnly ? 'validate' : 'start';

const sfArgs = [
    'project',
    'deploy',
    subcommand,
    '--source-dir',
    sourceDir,
    '--target-org',
    targetOrg,
    '--wait',
    String(wait),
    '--verbose'
];

if (tests) {
    // validate-only must use RunLocalTests to enforce org-wide 75% coverage;
    // RunRelevantTests skips classes with no test references, silently passing uncovered code.
    const testLevel = validateOnly ? 'RunLocalTests' : 'RunRelevantTests';
    sfArgs.push('--test-level', testLevel, '--results-dir', path.join(artifactsDir, 'results'), '--junit');
}

if (!validateOnly) {
    sfArgs.push('--ignore-conflicts');
}

const action = validateOnly ? 'Validating' : 'Deploying';
console.log(`▶ ${action}: org=${targetOrg} source=${sourceDir} wait=${wait}m tests=${tests}`);
console.log(`▶ Command: sf ${sfArgs.join(' ')}`);

// ---------------------------------------------------------------------------
// Run
// ---------------------------------------------------------------------------

const result = spawnSync('sf', sfArgs, {
    stdio: 'inherit',
    shell: false
});

if (result.error) fatal(`failed to run sf: ${result.error.message}`);

process.exit(result.status ?? 1);

// ---------------------------------------------------------------------------

function fatal(msg) {
    console.error(`Error: ${msg}`);
    process.exit(1);
}
