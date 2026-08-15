# Hot Burger Professional v2.7

## POS Pro UI — Responsive Cashier Experience

This release focuses on the cashier-facing experience and responsive behavior.

### Improvements

- Responsive POS workspace:
  - Desktop/tablet: products and cart side-by-side.
  - Phone/small tablet: products above a dedicated cart panel.
- Product cards are larger, clearer and touch-friendly.
- Live quantity badges show how many units of a product are already in the cart.
- Improved cart hierarchy and quantity controls.
- Checkout summary is always visible with:
  - Total.
  - Discount.
  - Payment method.
  - One-tap completion.
- Payment method selection remains directly available in the POS: cash, bank transfer and card.
- Improved empty/search states.
- Existing parked orders, invoice returns, shifts, permissions, audit logs and inventory behavior are preserved.

### Compatibility

No database schema migration is required. v2.7 builds on the v11 database from v2.5/v2.6.

### Verification

A structural Dart source check was performed on the modified POS screen. Flutter SDK is not available in this execution environment, so `flutter analyze`, `flutter test`, and release APK compilation must be run on a Flutter development machine.
