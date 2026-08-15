# STAGE 6 REPORT — KDS + Customers + Loyalty

## Scope
Focused review of Kitchen Display System, customers, and loyalty only.

## Finding
P1: Loyalty reversal for returned/cancelled invoices was recalculated from the invoice total at the time of reversal. This could become inconsistent if the loyalty earning rule changes after the original sale.

## Fix
Return/cancel now reverses the positive loyalty points actually logged against the invoice (`customer_points_log`) instead of recalculating them from the current formula.

## Preserved
- Existing KDS transition rules.
- Existing customer statistics behavior.
- Existing database schema.
- No UI redesign.
- No new features.
- No dependency changes.

## Verification
Static source inspection performed. Flutter SDK is not available in the environment, so `flutter analyze`, tests, and APK build were not run.
