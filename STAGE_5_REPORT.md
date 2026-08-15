# STAGE 5 — Inventory & Recipes

## Scope
Focused review of inventory quantity movements, recipe quantities, purchase quantities/costs, and recipe-to-product cost flow.

## Findings
- P0: 0
- P1: 2

## Fixed
1. Prevented non-positive recipe quantities from being inserted or replaced.
2. Prevented non-positive purchase quantities and negative purchase unit costs.
3. Removed nested transaction usage in `deductProductIngredients`; recipe lookup, stock deduction, and audit logging now execute on the same transaction.

## Not changed
No UI redesign, dependency changes, schema changes, or unrelated refactoring.

## Verification
Static source review completed. Flutter SDK is not available in this environment, so `flutter analyze`/runtime tests were not executed.
