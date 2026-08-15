# Hot Burger Professional v2.4

## Professional POS & Payments

- Added invoice subtotal, discount, paid amount and change amount fields.
- Added discount entry during checkout with validation against the subtotal.
- Added cash received and automatic change calculation for cash payments.
- Added card payment as a first-class payment method alongside cash and bank transfer.
- Improved invoice detail screen to show payment method, discount, amount received and change.
- Improved thermal receipt PDF to show subtotal, discount, total, amount received and change.
- Preserved existing shift controls, invoice cancellation, audit logging and inventory transactions.

## Database

- Database version upgraded from v9 to v10.
- Existing databases are migrated non-destructively.
- Existing invoices keep their historical total; subtotal defaults to the stored total for legacy records.

## Notes

Flutter SDK is required to run `flutter pub get`, `flutter analyze`, `flutter test` and release builds.
