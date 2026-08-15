# QA Checklist — v2.8

## KDS
- [ ] New completed invoice appears as "جديد".
- [ ] "بدء التحضير" changes it to "قيد التحضير".
- [ ] "جاهز" changes it to "جاهز".
- [ ] "تسليم" removes it from the active queue.
- [ ] Filters show correct counts.
- [ ] Auto-refresh discovers newly created tickets.
- [ ] Pull-to-refresh works.
- [ ] Ticket items and quantities match the invoice.
- [ ] Returned/cancelled invoices do not appear.
- [ ] Kitchen status changes create audit entries.

## POS / Orientation
- [ ] POS works in portrait.
- [ ] POS works in landscape on tablets.
- [ ] KDS is readable in landscape.
- [ ] Existing v2.7 sales, shifts, returns and parked orders remain functional.

## Database
- [ ] Fresh install creates database v12.
- [ ] Existing v11 database upgrades without data loss.
- [ ] Historical invoices receive kitchen_status = done.
