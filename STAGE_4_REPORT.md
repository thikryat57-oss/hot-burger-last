# STAGE 4 REPORT — Security & Permissions

Files inspected: 4 primary security/auth/permission files, plus navigation references.

P0 found: 0
P1 found: 4

## Fixed

- P1: `addUser` now rejects arbitrary roles and accepts only `manager` or `cashier`.
- P1: `deletePendingOrder` now requires an authenticated user.
- P1: `getExpenses` and Business Intelligence are protected at the service layer for finance managers.
- P1: Cashiers can only read their own shift history; managers retain access to all shift history.

## Deferred

- The app still contains a first-install default manager credential in source (`1234`). Removing it safely requires a first-run credential setup/change flow or an equivalent deployment strategy; this was deliberately not introduced in this low-risk stage to avoid breaking existing installations or adding a new schema/UI flow.

## Not changed

- No database schema/migration changes.
- No UI redesign.
- No dependency changes.
- No password hashing algorithm rewrite.
- No unrelated refactoring.

## Verification

- Static source inspection: PASS.
- Flutter/Dart analyzer: NOT RUN.

Reason:
- Flutter/Dart SDK is not available in the current environment.
