# QA Checklist — v3.2

## Critical
- [ ] `flutter pub get`
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `flutter build apk --release`
- [ ] Login as manager and cashier
- [ ] Open/close shift and verify cash difference
- [ ] Complete sale and verify inventory deduction
- [ ] Cancel/return invoice and verify inventory restoration
- [ ] Verify KDS status transitions
- [ ] Verify customer points earn/reversal
- [ ] Export backup while a sale is being written
- [ ] Restore a valid backup and reopen the application
- [ ] Restore an invalid/non-SQLite file and confirm it is rejected
- [ ] Verify reports exclude cancelled/returned invoices
- [ ] Verify invoice numbers remain unique after cancellations
- [ ] Test portrait and landscape on tablet
