# Hot Burger Professional v3.2 — Release Notes

## Production Hardening & Release Candidate Preparation

- Synchronized application/package version to 3.2.0+11.
- Database upgraded from v14 to v15.
- Added production indexes for customer lookup, loyalty invoice history, and invoice audit actions.
- Hardened SQLite backups with WAL checkpointing and SQLite signature validation.
- Hardened restore flow with temporary replacement, rollback copy, validation, and immediate database reopen.
- Preserved all v3.1 functionality and migrations.

## Validation note
Flutter SDK execution is required to run `flutter analyze`, `flutter test`, and `flutter build apk --release`.
