# Hot Burger Professional v2.6

## Operational Dashboard & Production Polish

- Added an operational center to the dashboard.
- Shows whether a cashier shift is currently open and who opened it.
- Shows the number of parked/pending POS orders.
- Added direct navigation from the dashboard to shift management and POS.
- Dashboard now refreshes operational status together with analytics.
- Version updated to 2.6.0+7.
- No database schema migration was required in this release; v2.6 builds on the v11 schema from v2.5.

## Compatibility

All v2.5 functionality is retained, including parked orders, invoice returns, audit logs, shifts, permissions, discounts and payment tracking.

## Verification

A structural Dart source check was performed on modified files. Flutter SDK is not available in this execution environment, so `flutter analyze`, `flutter test`, and release APK compilation must be run on a Flutter development machine.
