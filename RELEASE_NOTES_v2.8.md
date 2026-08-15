# Hot Burger Professional v2.8

## Kitchen Display System (KDS)

- Added a dedicated kitchen workflow: New → Preparing → Ready → Delivered.
- Added kitchen status tracking to invoices.
- Added a responsive kitchen ticket board for phones, tablets and wide screens.
- Added automatic refresh every 8 seconds plus pull-to-refresh.
- Added status filters and ticket age indicators.
- Added audit entries for kitchen status changes.
- Existing invoices are migrated to `done` so historical sales are not placed into the kitchen queue.
- Database upgraded from v11 to v12.
- Removed the portrait-only orientation lock so POS/KDS can use landscape on tablets and larger displays.

## Safety

Kitchen workflow does not modify inventory. Inventory is still affected only when a sale is completed, and restored on invoice cancellation/return.
