# Hot Burger v2.2

- Added invoice audit trail.
- Invoice numbers are protected by a unique database index.
- Invoice creation now uses a transaction for invoice + inventory writes.
- Invoice deletion is replaced by cancellation with inventory restoration.
- Cancelled invoices are excluded from sales and profit analytics.
- Database upgraded to v8.
