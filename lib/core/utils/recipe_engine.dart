
import '../../models/models.dart';

class RecipeEngine {
  /// Detects if adding a dependency creates a circular reference.
  /// A cycle exists if [targetMaterialId] (the one being added as a component)
  /// eventually depends on [parentMaterialId] (the prepared material being defined).
  static bool detectsCycle({
    required int parentMaterialId,
    required int targetMaterialId,
    required Map<int, List<RecipeModel>> allRecipes,
  }) {
    if (parentMaterialId == targetMaterialId) return true;

    // DFS to find if targetMaterialId depends on parentMaterialId
    final visited = <int>{};
    final stack = [targetMaterialId];

    while (stack.isNotEmpty) {
      final currentId = stack.removeLast();
      if (visited.contains(currentId)) continue;
      visited.add(currentId);

      final components = allRecipes[currentId] ?? [];
      for (final comp in components) {
        if (comp.materialId == parentMaterialId) return true;
        stack.add(comp.materialId);
      }
    }

    return false;
  }

  /// Calculates the total cost of a prepared material based on its recipe.
  /// Uses current cost prices of all component materials.
  static double calculatePreparedMaterialCost({
    required int materialId,
    required Map<int, List<RecipeModel>> allRecipes,
    required Map<int, MaterialModel> allMaterials,
  }) {
    final components = (allRecipes[materialId] ?? [])
        .where((r) => r.parentType == 'material')
        .toList();
    if (components.isEmpty) return 0;

    double totalCost = 0;
    for (final comp in components) {
      final material = allMaterials[comp.materialId];
      if (material == null) continue;

      double unitCost = material.costPrice;
      
      // If component is also prepared, calculate its cost recursively (assuming no cycles)
      if (material.isPrepared) {
        unitCost = calculatePreparedMaterialCost(
          materialId: material.id!,
          allRecipes: allRecipes,
          allMaterials: allMaterials,
        );
      }
      
      totalCost += unitCost * comp.quantity;
    }

    return totalCost;
  }

  /// Calculates Weighted Average Cost (WAC) for a new batch.
  static double calculateWAC({
    required double currentQty,
    required double currentAvgCost,
    required double newQty,
    required double newBatchCost,
  }) {
    if (currentQty + newQty <= 0) return newBatchCost;
    
    final totalQty = currentQty + newQty;
    final totalCost = (currentQty * currentAvgCost) + (newQty * newBatchCost);
    
    return totalCost / totalQty;
  }

  /// Expands a product or material recipe.
  /// If [deductPreparedStock] is true, prepared materials are treated as leaf stock.
  /// If false, they are recursively expanded to their raw leaf components.
  static Map<int, double> expandRecipe({
    required String parentType,
    required int parentId,
    required Map<int, List<RecipeModel>> allRecipes,
    required Map<int, MaterialModel> allMaterials,
    double multiplier = 1.0,
    bool deductPreparedStock = true,
  }) {
    final result = <int, double>{};
    
    // Scoped filtering by parentType to prevent ID collisions between products and materials
    final components = (allRecipes[parentId] ?? [])
        .where((r) => r.parentType == parentType)
        .toList();
    
    for (final comp in components) {
      final material = allMaterials[comp.materialId];
      if (material == null) continue;

      final totalNeeded = comp.quantity * multiplier;

      if (material.isPrepared && !deductPreparedStock) {
        // Recursive expansion to raw leaves
        final subExpansion = expandRecipe(
          parentType: 'material',
          parentId: material.id!,
          allRecipes: allRecipes,
          allMaterials: allMaterials,
          multiplier: totalNeeded,
          deductPreparedStock: false,
        );
        
        // Merge sub-expansion
        for (final entry in subExpansion.entries) {
          result[entry.key] = (result[entry.key] ?? 0) + entry.value;
        }
      } else {
        // Leaf stock (raw OR prepared material treated as stock)
        result[comp.materialId] = (result[comp.materialId] ?? 0) + totalNeeded;
      }
    }

    return result;
  }

  /// Calculates the total cost of a product based on its recipe (including multi-level).
  static double calculateProductCost({
    required int productId,
    required Map<int, List<RecipeModel>> allRecipes,
    required Map<int, MaterialModel> allMaterials,
  }) {
    final components = (allRecipes[productId] ?? [])
        .where((r) => r.parentType == 'product')
        .toList();
    double totalCost = 0;

    for (final comp in components) {
      final material = allMaterials[comp.materialId];
      if (material == null) continue;

      double unitCost = material.costPrice;
      if (material.isPrepared) {
        unitCost = calculatePreparedMaterialCost(
          materialId: material.id!,
          allRecipes: allRecipes,
          allMaterials: allMaterials,
        );
      }
      totalCost += unitCost * comp.quantity;
    }

    return totalCost;
  }
}
