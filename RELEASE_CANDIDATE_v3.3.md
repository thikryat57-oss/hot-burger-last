# Release Candidate Gate — Hot Burger v3.3

## Blockers
- [ ] flutter analyze = 0 errors
- [ ] flutter test = PASS
- [ ] Android release build = PASS
- [ ] Fresh install + first login
- [ ] Login with manager/cashier permissions
- [ ] Open shift / sale / inventory deduction / close shift
- [ ] Invoice cancellation and return
- [ ] KDS: new → preparing → ready → delivered only
- [ ] Customer points earn and reversal
- [ ] Backup during normal operation
- [ ] Restore valid backup
- [ ] Reject invalid backup
- [ ] Verify reports against manually calculated sample data
- [ ] Portrait + landscape tablet test
- [ ] Reopen application after restore
- [ ] Upgrade from an existing v3.2 database

## Release rule
أي فشل في البيانات المالية أو المخزون أو الاستعادة أو الصلاحيات = Blocker ولا يسمح بإصدار الإنتاج.
