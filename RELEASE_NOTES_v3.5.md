# Hot Burger Professional v3.5.0

## Security & Permissions Hardening

- Added service-layer validation for user roles (`manager` / `cashier` only).
- Prevented unauthenticated deletion of parked/pending POS orders.
- Restricted expense history to finance managers.
- Restricted Business Intelligence access at the service layer.
- Limited cashier shift history to the currently authenticated cashier; managers retain full shift history.
- No database schema migration.
- No new features or UI redesign.
