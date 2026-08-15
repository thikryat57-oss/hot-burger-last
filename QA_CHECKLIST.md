# Hot Burger — Release QA Checklist

## POS
- [ ] Login succeeds with the configured manager account.
- [ ] Product search and category filters work.
- [ ] Adding/removing products updates the cart correctly.
- [ ] Quantities cannot become invalid.
- [ ] Cash/card payment selection is preserved.
- [ ] Completing a sale creates exactly one invoice.
- [ ] Invoice number remains sequential after deleting an older invoice.
- [ ] Raw-material stock is deducted once.
- [ ] Insufficient stock blocks the sale.
- [ ] Low-stock warning appears when appropriate.

## Invoices & reports
- [ ] Invoice details show the correct payment method.
- [ ] Invoice totals and item totals match.
- [ ] Historical cost/profit remains unchanged after ingredient price changes.
- [ ] Daily/monthly/profit reports match the underlying invoices and expenses.

## Inventory
- [ ] Manual quantity changes are reflected in inventory history.
- [ ] Purchases increase stock.
- [ ] Deleted sales restore the deducted stock correctly.
- [ ] Recipe quantities affect stock deduction and product cost.

## Backup
- [ ] Backup can be created.
- [ ] Backup can be shared.
- [ ] Restore rejects invalid database files.
- [ ] Restore preserves products, invoices and inventory.

## Release
- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] `flutter build apk --release` succeeds.
- [ ] Tested on at least one physical Android device.
