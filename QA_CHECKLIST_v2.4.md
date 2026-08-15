# QA Checklist — v2.4

## POS checkout
- [ ] Open a cashier shift.
- [ ] Add multiple products to cart.
- [ ] Select cash, enter exact amount, verify change = 0.
- [ ] Enter an amount greater than total, verify correct change.
- [ ] Try an amount lower than total and confirm checkout is blocked.
- [ ] Select bank transfer and confirm no cash-change requirement.
- [ ] Select card and confirm no cash-change requirement.
- [ ] Apply a discount smaller than subtotal.
- [ ] Try a discount larger than subtotal and confirm it is capped.
- [ ] Complete sale and verify invoice stores subtotal, discount, total, paid and change.

## Invoice and printing
- [ ] Open invoice details and verify payment method.
- [ ] Verify discount and payment summary are displayed.
- [ ] Print/preview the receipt and verify the same totals appear.

## Accounting / inventory
- [ ] Confirm invoice cancellation still restores ingredient inventory.
- [ ] Confirm cancelled invoices remain excluded from sales reports.
- [ ] Confirm shift cash totals use the final invoice total.
- [ ] Confirm audit records remain intact.

## Migration
- [ ] Upgrade an existing v2.3 database and confirm data remains available.
- [ ] Create a fresh v2.4 database and verify invoice creation.
