# QA Checklist — v2.6

## Dashboard
- [ ] Dashboard opens without exceptions.
- [ ] Today/week/month/custom filters still load correctly.
- [ ] Operational center shows open/closed shift state.
- [ ] Open shift owner is displayed when available.
- [ ] Pending order count matches POS parked orders.
- [ ] Shift tile opens shift management.
- [ ] Pending-order tile opens POS.

## Regression
- [ ] POS sale requires an open shift.
- [ ] Discounts and payment methods work.
- [ ] Parked orders can be resumed/deleted.
- [ ] Invoice return restores inventory once.
- [ ] Cancelled/returned invoices remain excluded from reports.
- [ ] User permissions remain enforced.
- [ ] Backup/restore remains functional.

## Release
- [ ] flutter pub get
- [ ] flutter analyze
- [ ] flutter test
- [ ] flutter build apk --release
