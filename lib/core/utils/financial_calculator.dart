// ignore_for_file: constant_identifier_names

import 'dart:math' as math;

/// Financial Calculation Layer — Unified Core for Hot Burger.
///
/// Phase 1 (Financial Integrity Core): the single source of truth for all
/// monetary computations consumed by the reporting surfaces (Daily/Monthly
/// Report, Profit & Loss, Business Intelligence, Top Products).
///
/// Design rules (see HOT_BURGER_PHASE1_FINANCIAL_INTEGRITY_REPORT.md):
///   - Pure Dart; no Flutter/Provider/sqflite dependency. All inputs arrive
///     as plain [Map<String, dynamic>] rows produced by queries.
///   - Revenue is ALWAYS the net total (after discount). Gross sales and the
///     discount are reported alongside, never substituted.
///   - Discounts are allocated to line items via Proportional Allocation
///     (pro rata by item total) with the last penny assigned to the largest
///     item so allocations sum exactly to the invoice discount.
///   - COGS uses the frozen `cost_snapshot` captured at the moment of sale.
///     Pre-snapshot (legacy) invoices fall back to the recipe cost at query
///     time, and the two COGS figures are tracked separately (`cogs` vs
///     `cogsWithFallback`) so history is never silently rewritten.
///   - The per-item `total_profit` stored at invoice creation is the GROSS
///     (pre-discount) profit. Discounted (allocated) profit is always
///     computed by this layer and never assumed equal to the stored value.
///   - All arithmetic guards against `NaN` / `Infinity`; negative quantities
///     clamp to zero instead of throwing (defensive policy from the Phase 0
///     baseline audit).

/// A single line item as stored in `invoice_items`.
class FinancialLineItem {
  const FinancialLineItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.total,
    required this.costSnapshot,
    required this.unitProfit,
    required this.totalProfit,
  });

  final int productId;
  final String productName;
  final double quantity;
  final double price;
  final double total;
  final double costSnapshot;
  final double unitProfit;
  final double totalProfit;

  factory FinancialLineItem.fromRow(Map<String, dynamic> row) =>
      FinancialLineItem(
        productId: _int(row['product_id']),
        productName: (row['product_name'] as String?) ?? '',
        quantity: _num(row['quantity']),
        price: _num(row['price']),
        total: _num(row['total']),
        costSnapshot: _num(row['cost_snapshot']),
        unitProfit: _num(row['unit_profit']),
        totalProfit: _num(row['total_profit']),
      );

  /// True when the frozen cost snapshot is missing or zero and a legacy
  /// recipe-cost fallback would be used.
  bool get hasLegacyCost => costSnapshot <= 0;
}

/// The financial view of a single invoice, with the discount allocated to
/// each line and the per-invoice COGS computed from frozen snapshots.
class InvoiceFinancials {
  const InvoiceFinancials({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.status,
    required this.createdAt,
    required this.subtotal,
    required this.discount,
    required this.netRevenue,
    required this.lines,
    required this.cogs,
    required this.cogsWithFallback,
    required this.discountAllocations,
  });

  final int invoiceId;
  final String invoiceNumber;
  final String status;
  final String createdAt;
  final double subtotal;
  final double discount;
  final double netRevenue;

  /// Line items belonging to this invoice.
  final List<FinancialLineItem> lines;

  /// COGS computed strictly from frozen `cost_snapshot` (> 0).
  final double cogs;

  /// COGS including the legacy recipe-cost fallback for pre-snapshot items.
  final double cogsWithFallback;

  /// Discount allocated to each line item (sum == [discount]).
  final Map<int, double> discountAllocations;

  /// Discounted gross profit for the invoice: net revenue minus COGS.
  double get grossProfit => netRevenue - cogs;

  /// Discounted gross profit when legacy fallback costs are included.
  double get grossProfitWithFallback => netRevenue - cogsWithFallback;

  /// Net profit for the invoice after subtracting its share of expenses.
  double netProfit(double expensesShare) => grossProfit - expensesShare;

  /// Gross (pre-discount) item profit, as stored at invoice creation time.
  double get storedGrossItemProfit =>
      lines.fold(0.0, (acc, line) => acc + line.totalProfit);
}

/// Aggregated financials over a set of invoices.
class FinancialSummary {
  const FinancialSummary({
    required this.invoices,
    required this.grossSales,
    required this.discountTotal,
    required this.netRevenue,
    required this.cogs,
    required this.cogsWithFallback,
    required this.grossProfit,
    required this.grossProfitWithFallback,
    required this.expenses,
    required this.cashTotal,
    required this.bankTotal,
    required this.cardTotal,
    required this.transferTotal,
    required this.invoiceCount,
    required this.totalItemsSold,
  });

  final List<InvoiceFinancials> invoices;
  final double grossSales;
  final double discountTotal;
  final double netRevenue;
  final double cogs;
  final double cogsWithFallback;
  final double grossProfit;
  final double grossProfitWithFallback;
  final double expenses;
  final double cashTotal;
  final double bankTotal;
  final double cardTotal;
  final double transferTotal;
  final int invoiceCount;
  final int totalItemsSold;

  double get netProfit => grossProfit - expenses;

  double get netProfitWithFallback => grossProfitWithFallback - expenses;

  /// Profit margin as a percentage of net revenue (0 when revenue is zero).
  double get profitMargin =>
      netRevenue > 0 ? (grossProfit / netRevenue) * 100.0 : 0.0;

  FinancialSummary copyWith({double? expenses}) {
    if (expenses == null || expenses == this.expenses) return this;
    return FinancialSummary(
      invoices: invoices,
      grossSales: grossSales,
      discountTotal: discountTotal,
      netRevenue: netRevenue,
      cogs: cogs,
      cogsWithFallback: cogsWithFallback,
      grossProfit: grossProfit,
      grossProfitWithFallback: grossProfitWithFallback,
      expenses: expenses,
      cashTotal: cashTotal,
      bankTotal: bankTotal,
      cardTotal: cardTotal,
      transferTotal: transferTotal,
      invoiceCount: invoiceCount,
      totalItemsSold: totalItemsSold,
    );
  }
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Allocates [discount] across [lines] proportionally to each line's
/// contribution to [gross] (the sum of the lines' totals), rounding each
/// allocation to [decimals] places and assigning the remaining last penny
/// to the line with the largest total. The returned map sums exactly to
/// [discount].
///
/// When [gross] is zero (or the discount is zero/negative), all allocations
/// are zero. Negative quantities clamp to zero.
Map<int, double> allocateDiscount(List<FinancialLineItem> lines, double discount,
    {double gross = 0.0, int decimals = 2}) {
  if (lines.isEmpty) return <int, double>{};
  discount = _clean(discount);
  if (discount <= 0) {
    return {for (final line in lines) line.productId: 0.0};
  }
  final g = gross > 0 ? _clean(gross) : _lineGrossTotal(lines);
  if (g <= 0) {
    return {for (final line in lines) line.productId: 0.0};
  }

  final scale = math.pow(10, decimals).toDouble();
  var remaining = (discount * scale).round();
  final allocations = <int, int>{};

  // Sort-by-weight assignment order: largest items first for deterministic
  // last-penny tie-breaking.
  final sorted = lines.toList()
    ..sort((a, b) => b.total.compareTo(a.total));
  for (final line in sorted) {
    final contribution = _clean(line.total) / g;
    final raw = discount * contribution;
    final assigned = (raw * scale).round();
    final actual = math.min(assigned, math.max(remaining, 0));
    allocations[line.productId] = actual;
    remaining -= actual;
  }
  // Last-penny assignment to the largest line (first in sorted order).
  if (remaining != 0 && sorted.isNotEmpty) {
    allocations[sorted.first.productId] =
        allocations[sorted.first.productId]! + remaining;
  }

  return allocations.map((productId, units) =>
      MapEntry(productId, units / scale));
}

/// Builds a per-invoice financial view for a batch of invoice rows.
///
/// [invoiceRows] must contain per-invoice columns: `id`, `invoice_number`,
/// `status`, `created_at`, `subtotal_amount`, `discount_amount`,
/// `total_amount`, `payment_method` (may be null).
/// [itemRows] must contain the flat join columns of invoice_items:
/// `invoice_id`, `product_id`, `product_name`, `quantity`, `price`, `total`,
/// `cost_snapshot`, `unit_profit`, `total_profit`.
/// Rows whose `invoice_id` does not match a known invoice are ignored, and
/// invoices without item rows yield zero COGS (defensive, not an error).
InvoiceSummaryResult summarizeInvoices(
  List<Map<String, dynamic>> invoiceRows,
  List<Map<String, dynamic>> itemRows, {
  double expensesTotal = 0.0,
}) {
  final invoices = <int, InvoiceFinancials>{};
  for (final row in invoiceRows) {
    final id = _int(row['id']);
    invoices[id] = InvoiceFinancials(
      invoiceId: id,
      invoiceNumber: (row['invoice_number'] as String?) ?? '',
      status: (row['status'] as String?) ?? 'completed',
      createdAt: (row['created_at'] as String?) ?? '',
      subtotal: _num(row['subtotal_amount']),
      discount: _num(row['discount_amount']),
      netRevenue: _num(row['total_amount']),
      lines: const [],
      cogs: 0,
      cogsWithFallback: 0,
      discountAllocations: const {},
    );
  }

  final grouped = <int, List<FinancialLineItem>>{};
  for (final row in itemRows) {
    final invoiceId = _int(row['invoice_id']);
    final invoice = invoices[invoiceId];
    if (invoice == null) continue;
    grouped.putIfAbsent(invoiceId, () => []).add(FinancialLineItem.fromRow(row));
  }

  var expensesRemainingUnits = _clean(expensesTotal);
  final results = <int, InvoiceFinancials>{};
  for (final entry in invoices.entries) {
    final id = entry.key;
    final invoice = entry.value;
    final lines = grouped[id] ?? const [];
    final gross = _lineGrossTotal(lines);
    final allocations = allocateDiscount(lines, invoice.discount, gross: gross);

    // Per-line fallback cost: the recipe cost at invoice time is not stored
    // for pre-snapshot items. Reconstruct it from the stored unit profit
    // (unit_profit = price - costAtSale), which was computed the same way at
    // sale time and is frozen in the row. This keeps history deterministic
    // without re-running the recipe graph against today's prices.
    double cogs = 0.0;
    double cogsWithFallback = 0.0;
    for (final line in lines) {
      final q = math.max(line.quantity, 0);
      if (line.costSnapshot > 0) {
        cogs += q * line.costSnapshot;
        cogsWithFallback += q * line.costSnapshot;
      } else {
        final reconstructedCost = math.max(line.price - line.unitProfit, 0.0);
        cogsWithFallback += q * reconstructedCost;
      }
    }

    results[id] = InvoiceFinancials(
      invoiceId: id,
      invoiceNumber: invoice.invoiceNumber,
      status: invoice.status,
      createdAt: invoice.createdAt,
      subtotal: invoice.subtotal,
      discount: invoice.discount,
      netRevenue: invoice.netRevenue,
      lines: lines,
      cogs: cogs,
      cogsWithFallback: cogsWithFallback,
      discountAllocations: allocations,
    );
  }

  return InvoiceSummaryResult(invoices: results);
}

/// Result holder returned by [summarizeInvoices].
class InvoiceSummaryResult {
  const InvoiceSummaryResult({required this.invoices});
  final Map<int, InvoiceFinancials> invoices;
}

/// Aggregates [InvoiceFinancials] into a [FinancialSummary].
///
/// Payment-method splits use `payment_method` from the invoice row when
/// provided via [methodForRow] (defaults to `total_amount` per method when
/// [paymentRows] is supplied as `payment_method`/`method_total` rows).
FinancialSummary aggregateSummary(
  List<InvoiceFinancials> financials, {
  double expensesTotal = 0.0,
  Map<String, double> paymentSplits = const {},
}) {
  double gross = 0;
  double discount = 0;
  double net = 0;
  double cogs = 0;
  double cogsFallback = 0;
  var itemsSold = 0;
  for (final f in financials) {
    gross += _clean(f.subtotal);
    discount += _clean(f.discount);
    net += _clean(f.netRevenue);
    cogs += _clean(f.cogs);
    cogsFallback += _clean(f.cogsWithFallback);
    itemsSold += f.lines.fold(0, (acc, line) => acc + math.max(line.quantity, 0).round());
  }

  return FinancialSummary(
    invoices: financials,
    grossSales: gross,
    discountTotal: discount,
    netRevenue: net,
    cogs: cogs,
    cogsWithFallback: cogsFallback,
    grossProfit: net - cogs,
    grossProfitWithFallback: net - cogsFallback,
    expenses: _clean(expensesTotal),
    cashTotal: paymentSplits['cash'] ?? 0,
    bankTotal: paymentSplits['bank'] ?? 0,
    cardTotal: paymentSplits['card'] ?? 0,
    transferTotal: paymentSplits['transfer'] ?? 0,
    invoiceCount: financials.length,
    totalItemsSold: itemsSold,
  );
}

// ---------------------------------------------------------------------------
// Top products by discounted profit
// ---------------------------------------------------------------------------

/// Aggregates product profitability with the discount allocated pro rata.
/// Returns a list of `{'product_id', 'product_name', 'qty', 'grossProfit',
/// 'discountedProfit'}` sorted descending by `discountedProfit`.
List<Map<String, dynamic>> topProductsByDiscountedProfit(
  List<InvoiceFinancials> financials, {
  int limit = 5,
}) {
  final byProduct = <int, _ProductAccum>{};
  for (final f in financials) {
    final lineGross = _lineGrossTotal(f.lines);
    final discount = f.discount;
    for (final line in f.lines) {
      final alloc =
          lineGross > 0 && discount > 0 ? discount * (_clean(line.total) / lineGross) : 0.0;
      final entry = byProduct.putIfAbsent(line.productId, () => _ProductAccum(line.productId, line.productName));
      entry.qty += math.max(line.quantity, 0);
      entry.grossProfit += _clean(line.totalProfit);
      entry.discountedProfit +=
          math.max(line.quantity, 0) * math.max(line.unitProfit, 0) - alloc;
    }
  }
  final ranked = byProduct.values.toList()
    ..sort((a, b) => b.discountedProfit.compareTo(a.discountedProfit));
  return ranked.take(limit).map((p) => <String, dynamic>{
        'product_id': p.productId,
        'product_name': p.productName,
        'qty': p.qty.round(),
        'grossProfit': p.grossProfit,
        'discountedProfit': p.discountedProfit,
      }).toList();
}

class _ProductAccum {
  _ProductAccum(this.productId, this.productName);
  final int productId;
  final String productName;
  double qty = 0;
  double grossProfit = 0;
  double discountedProfit = 0;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

double _lineGrossTotal(List<FinancialLineItem> lines) =>
    lines.fold(0.0, (acc, line) => acc + _clean(line.total));

double _num(Object? value) {
  if (value == null) return 0.0;
  if (value is num) return _clean(value.toDouble());
  if (value is String) {
    final parsed = double.tryParse(value);
    return parsed == null ? 0.0 : _clean(parsed);
  }
  return 0.0;
}

int _int(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _clean(double value) {
  if (value.isNaN || value.isInfinite) return 0.0;
  return value;
}
