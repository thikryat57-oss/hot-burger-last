# QA Checklist — v2.7

## POS layout
- [ ] POS renders correctly on a phone portrait screen.
- [ ] POS renders correctly on a tablet.
- [ ] POS renders correctly on a desktop/windowed layout.
- [ ] Product cards remain tappable without overflow.
- [ ] Cart remains accessible on compact layouts.

## Product and cart
- [ ] Search filters products correctly.
- [ ] Category filters still work.
- [ ] Tapping a product adds it to the cart.
- [ ] Quantity badge updates immediately.
- [ ] Plus/minus controls work.
- [ ] Removing an item works.
- [ ] Empty cart state is clear.

## Checkout
- [ ] Discount can be added/changed.
- [ ] Cash payment allows received amount and calculates change.
- [ ] Bank transfer and card payment complete without cash-change validation.
- [ ] Parked orders can be saved and resumed.
- [ ] Completed sales still require an open shift.
- [ ] Invoice printing remains available after a sale.

## Regression
- [ ] Invoice returns restore inventory once.
- [ ] Cancelled/returned invoices remain excluded from reports.
- [ ] Permissions remain enforced.
- [ ] Backup/restore remains functional.

## Release
- [ ] flutter pub get
- [ ] flutter analyze
- [ ] flutter test
- [ ] flutter build apk --release
