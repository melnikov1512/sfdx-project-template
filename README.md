# Salesforce DX Project Template

`sfdx-project-template` - минимальный шаблон Salesforce DX проекта с Node-инструментами качества для Aura/LWC.

В репозитории:

- задан package directory `force-app` в `sfdx-project.json`;
- настроены ESLint (flat config), Prettier и `@salesforce/sfdx-lwc-jest`;
- подготовлен scratch org baseline в `config/project-scratch-def.json`;
- бизнес-метаданные пока не добавлены.

## Current Project Layout

- `sfdx-project.json` - SFDX-конфигурация проекта (`sourceApiVersion`: `66.0`)
- `config/project-scratch-def.json` - базовая конфигурация scratch org
- `eslint.config.js` - правила lint для Aura/LWC/Jest mocks
- `jest.config.js` - конфигурация LWC Jest
- `package.json` - npm scripts, lint-staged, dev tooling

## Quick Start

### Prerequisites

- Node.js 20+ and npm
- (Optional for Apex validation) Salesforce CLI (`sf`) in `PATH`
- (Optional for Apex validation) authenticated default target org
- (For GitHub Actions metadata validation) repository secret `SF_AUTH_URL`

Проверка доступности org:

```bash
sf org display --json
```

```bash
npm install
```

## Daily Development Commands

Lint JS для Aura/LWC:

```bash
npm run lint
```

Полный тестовый прогон (LWC Jest + Apex tests при доступном org):

```bash
npm run test
```

Форматирование файлов:

```bash
npm run prettier
```

Полная локальная проверка перед PR:

```bash
npm run validate
```

`npm run validate` выполняет `lint`, `prettier:verify`, `test:lwc:ci` и затем `test:apex`.
Apex-часть пропускается без падения пайплайна шаблона, если:

- в `force-app/main/default/classes` нет локальных Apex test-классов (`@isTest`);
- `sf` CLI не установлен;
- default target org не настроен.

## CI Expectations

PR workflow `.github/workflows/pr-check.yml` всегда запускает:

- `npm run lint`
- `npm run prettier:verify`
- `npm run test:lwc:ci`

Если PR меняет файлы под `force-app/` (или под каталогом из repository variable `SFDX_METADATA_DIR`), workflow дополнительно запускает Salesforce metadata validate-only check.

Для этого check нужны:

- repository secret `SF_AUTH_URL` с SFDX auth URL для CI org;
- workflow использует фиксированное ожидание `--wait 30`, синхронизированное с `timeout-minutes: 30` у job.

Поведение metadata check:

- если в PR нет изменений под metadata root, check завершается без ошибки и пишет skip message;
- если metadata root еще не создан в ветке, check тоже skip-ится без ложного падения шаблона;
- если metadata changes есть, но `SF_AUTH_URL` не задан, PR check падает с явной ошибкой;
- логи и список измененных файлов сохраняются в GitHub Actions artifact `salesforce-validate-<run_id>`.

## Additional Test Modes

Только LWC unit tests (Jest):

```bash
npm run test:lwc
```

Apex tests (если доступен org):

```bash
npm run test:apex
```

CI-режим тестов:

```bash
npm run test:lwc:ci
```

Watch-режим:

```bash
npm run test:lwc:watch
```

Coverage:

```bash
npm run test:lwc:coverage
```

## Notes for Template Usage

- Источник для Salesforce metadata - `force-app/` (по `sfdx-project.json`).
- При добавлении первой метадаты создайте стандартный путь `force-app/main/default/`.
- Для работы со scratch org используйте `config/project-scratch-def.json` как базовый definition file.
- Для CI metadata validation используйте отдельный low-privilege org user и храните его auth URL только в `SF_AUTH_URL` secret.
