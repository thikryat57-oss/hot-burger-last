# Hot Burger Professional v3.8

## Stage 7 — UI/UX & Stability Hardening

### Fixed
- Added mounted-state guards after asynchronous date-picker operations across Dashboard, Reports, Profit Report, Shift Report, and Business Intelligence screens.
- Prevents `setState()` after widget disposal when a screen is closed while a date picker is active.

### Scope
No database, financial, inventory, security, KDS, dependency, architecture, or feature changes.
