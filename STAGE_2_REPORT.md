Files inspected: 5

P0 found: 1
P1 found: 2

Fixed:
- P0: Fixed `voidInvoice` in `app_provider.dart` to prevent duplicate inventory restoration if the invoice is already in 'returned' status.
- P1: Wrapped `updateIngredientQuantity` in `database_helper.dart` in a transaction to ensure atomic inventory updates and audit logging.
- P1: Wrapped `deductProductIngredients` in `database_helper.dart` in a transaction to ensure all recipe ingredients are deducted as a single unit of work.

Not changed:
- Database schema and migrations (v1 to v15) were found to be safe and consistent.
- Invoice creation logic in `createInvoice` is correctly implemented with transactions.
- Backup and Restore logic in `backup_helper.dart` follows best practices (WAL checkpointing, rollback copies, and header validation).

Verification:
- NOT RUN

Reason:
- Flutter SDK is not available in the current environment to run integration tests. A thorough static code analysis was performed on the database and transaction logic as requested.
