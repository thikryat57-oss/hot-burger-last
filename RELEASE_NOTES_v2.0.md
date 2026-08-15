# Hot Burger v2.0 — Professional Edition

## What changed

### UI / UX
- Redesigned the global Material 3 theme with a cleaner POS-oriented visual system.
- Improved cards, forms, dialogs, buttons, navigation, spacing and typography.
- Added a professional RTL administration center.
- Replaced the crowded 8-item bottom navigation with a focused 5-section navigation bar.
- Added a dashboard shortcut for starting a new sale.
- Improved the login screen with clearer hierarchy, validation and loading feedback.

### Navigation
- Sales, invoices, dashboard, inventory and administration are now the primary sections.
- Products, categories, expenses, recipes, suppliers, purchases, reports and backups are grouped under Administration.
- Added a clear logout action with confirmation.

### Database performance
- Database version upgraded to 7.
- Added indexes for invoices, invoice items, expenses, inventory, audit history and recipes.
- Existing databases are upgraded automatically through the existing migration system.
- Fresh installations receive the same indexes.

### Compatibility
- The project remains offline-first.
- Existing business logic, SQLite data model, reports, inventory audit trail, recipes, purchases and backups are preserved.

## Validation note

The build environment used for this delivery does not contain the Flutter SDK, so `flutter analyze` / `flutter test` could not be executed locally. The changes were kept within the existing Flutter architecture and dependency set.
