# Hot Burger v2.1 — Stability & Professional Polish

## This release
v2.1 builds on the Professional v2.0 UI/UX release and focuses on correctness in the POS flow.

### POS / Invoices
- Invoice numbering no longer depends on the number of existing invoices.
- Deleted invoices no longer cause the next invoice number to be reused.
- Invoice details now preserve the original payment method when loaded for printing/viewing.
- The sales screen uses the centralized invoice-number generator.

### Quality
- Version bumped to `2.1.0+2`.
- App version constant updated to `2.1.0`.
- Local import and brace sanity checks were performed on the Dart source tree.
- Flutter/Dart SDK is not installed in this execution environment, so `flutter analyze`, `flutter test`, and an Android release build still need to be run on a Flutter development machine.

## Required final verification
```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Then perform a real-device smoke test for login, product management, sale, invoice printing, inventory deduction, expenses, reports, backup and restore.
