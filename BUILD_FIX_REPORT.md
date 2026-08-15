# Hot Burger Professional v3.9.1 — Build Fix

## Scope
Only the three compile blockers reported by the GitHub Actions `flutter build apk --release` log were addressed.

## Fixed
1. `lib/screens/auth/login_screen.dart`
   - Added the missing `../../models/models.dart` import so `User` resolves correctly.
2. `lib/screens/more/more_screen.dart`
   - Removed the invalid `RecipeManagementScreen()` construction because its `product` parameter is required.
   - The existing Products screen is used as the entry point for recipe management; recipe editing is already available from each product card.
   - Removed the now-unused RecipeManagementScreen import.
3. `lib/screens/sales/sales_screen.dart`
   - Removed unsupported `minCrossAxisSpacing` from `SliverGridDelegateWithMaxCrossAxisExtent`.
   - Existing supported spacing parameters remain unchanged.

## Verification
Source-level verification completed for the three reported blockers.
Flutter build was not executed in this environment because the Flutter SDK is unavailable here.

## Next step
Push this version to GitHub and run `flutter build apk --release` in the existing GitHub Actions workflow.
