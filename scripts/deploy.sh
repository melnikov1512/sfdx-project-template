#!/usr/bin/env bash
# scripts/deploy.sh — Salesforce metadata deploy wrapper
#
# Usage:
#   bash scripts/deploy.sh --target-org <alias> [options]
#
# Options:
#   --target-org, -o  (required) Authenticated org alias
#   --tests,      -t  Add --test-level RunLocalTests
#   --validate-only   Run sf project deploy validate instead of start
#   --source-dir      Metadata source directory (default: force-app)
#   --wait            Minutes to wait for the operation (default: 30)

set -euo pipefail

TARGET_ORG=""
TESTS=false
VALIDATE_ONLY=false
SOURCE_DIR="force-app"
WAIT=30

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-org | -o)
      TARGET_ORG="${2:?'--target-org requires a value'}"
      shift 2
      ;;
    --tests | -t)
      TESTS=true
      shift
      ;;
    --validate-only)
      VALIDATE_ONLY=true
      shift
      ;;
    --source-dir)
      SOURCE_DIR="${2:?'--source-dir requires a value'}"
      shift 2
      ;;
    --wait)
      WAIT="${2:?'--wait requires a value'}"
      shift 2
      ;;
    *)
      echo "Error: unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$TARGET_ORG" ]]; then
  echo "Error: --target-org is required" >&2
  exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Error: source directory '$SOURCE_DIR' not found" >&2
  exit 1
fi

ARTIFACTS_DIR=".artifacts/deploy"
mkdir -p "$ARTIFACTS_DIR/results"

SF_ARGS=(
  --source-dir "$SOURCE_DIR"
  --target-org "$TARGET_ORG"
  --wait "$WAIT"
  --results-dir "$ARTIFACTS_DIR/results"
  --verbose
)

if [[ "$TESTS" == true ]]; then
  SF_ARGS+=(--test-level RunLocalTests)
fi

if [[ "$VALIDATE_ONLY" == true ]]; then
  echo "▶ Validating: org=$TARGET_ORG source=$SOURCE_DIR wait=${WAIT}m tests=$TESTS"
  sf project deploy validate "${SF_ARGS[@]}" 2>&1 | tee "$ARTIFACTS_DIR/deploy.log"
else
  echo "▶ Deploying: org=$TARGET_ORG source=$SOURCE_DIR wait=${WAIT}m tests=$TESTS"
  sf project deploy start "${SF_ARGS[@]}" 2>&1 | tee "$ARTIFACTS_DIR/deploy.log"
fi
