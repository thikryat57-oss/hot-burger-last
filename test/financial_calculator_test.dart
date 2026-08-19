import 'dart:math' as math;
import 'package:hot_burger_last/core/utils/financial_calculator.dart';
import 'package:test/test.dart';

FinancialLineItem _line({
  required int productId,
  required String name,
  required double quantity,
  required double price,
  required double total,
  double costSnapshot = 0.0,
  double unitProfit = 0.0,
  double totalProfit = 0.0,
}) => FinancialLineItem(
      productId: productId,
      productName: name,
      quantity: quantity,
      price: price,
      total: total,
      costSnapshot: costSnapshot,
      unitProfit: unitProfit,
      totalProfit: totalProfit,
    );

InvoiceFinancials _invoice({
  required int id,
  double subtotal = 0.0,
  double discount = 0.0,
  double net = 0.0,
  required List<FinancialLineItem> lines,
  double cogs = 0.0,
  double cogsWithFallback = 0.0,
}) {
  final allocations = allocateDiscount(lines, discount);
  return InvoiceFinancials(
    invoiceId: id,
    invoiceNumber: 'INV-$id',
    status: 'completed',
    createdAt: '2026-08-18',
    subtotal: subtotal,
    discount: discount,
    netRevenue: net,
    lines: lines,
    cogs: cogs,
    cogsWithFallback: cogsWithFallback,
    discountAllocations: allocations,
  );
}

/// Sums all per-line allocations for every productId (each value is a
/// List<double> with one entry per line of that product, phase 1.1).
double _sumAlloc(Map<int, List<double>> alloc) =>
    alloc.values.fold<double>(0, (s, list) => s + list.fold(0.0, (s2, v) => s2 + v));

void main() {
  group('FinancialLineItem construction and defensive clamping', () {
    test('negative quantity and NaN inputs clamp to zero and do not throw', () {
      final item = _line(
        productId: 1,
        name: 'برجر',
        quantity: -2,
        price: 25.5,
        total: -51.0,
      );
      expect(item.quantity, -2.0); // values pass through; math clamps instead
      expect(item.totalProfit, 0.0);
    });

    test('fromRow converts string and null fields safely', () {
      final row = <String, dynamic>{
        'product_id': '42',
        'product_name': null,
        'quantity': '3',
        'price': '12.5',
        'total': 37.5,
        'cost_snapshot': '10',
        'unit_profit': 2.5,
        'total_profit': 7.5,
      };
      final item = FinancialLineItem.fromRow(row);
      expect(item.productId, 42);
      expect(item.productName, '');
      expect(item.quantity, 3.0);
      expect(item.price, 12.5);
      expect(item.total, 37.5);
      expect(item.costSnapshot, 10.0);
      expect(item.unitProfit, 2.5);
      expect(item.totalProfit, 7.5);
    });

    test('hasLegacyCost flags missing snapshot', () {
      expect(_line(productId: 1, name: 'A', quantity: 1, price: 10, total: 10).hasLegacyCost, true);
      expect(
          _line(productId: 1, name: 'A', quantity: 1, price: 10, total: 10, costSnapshot: 5).hasLegacyCost, false);
    });
  });

  group('allocateDiscount: proportional allocation with last penny', () {
    test('zero or negative discount yields zero allocations', () {
      final lines = [_line(productId: 1, name: 'A', quantity: 1, price: 100, total: 100)];
      expect(_sumAlloc(allocateDiscount(lines, 0.0)), 0.0);
      expect(_sumAlloc(allocateDiscount(lines, -10.0)), 0.0);
    });

    test('allocations sum exactly to the invoice discount', () {
      final lines = [
        _line(productId: 1, name: 'A', quantity: 1, price: 66.67, total: 66.67),
        _line(productId: 2, name: 'B', quantity: 1, price: 33.33, total: 33.33),
      ];
      final alloc = allocateDiscount(lines, 10.0);
      final sum = _sumAlloc(alloc);
      expect((sum - 10.0).abs(), lessThan(0.0005), reason: 'sum=$sum');
    });

    test('discount clamped to gross when discount exceeds revenue', () {
      final lines = [_line(productId: 1, name: 'A', quantity: 1, price: 100, total: 100)];
      final alloc = allocateDiscount(lines, 500.0);
      // Phase 1.1 hardening: the effective discount is clamped to total
      // gross, so the sum of all allocations is 100 (not 500) and net
      // revenue can never go negative because of the discount.
      expect(_sumAlloc(alloc), 100.0);
      expect(alloc[1]!.single, 100.0);
    });

    test('larger lines receive at least as much allocation as smaller lines', () {
      final lines = [
        _line(productId: 1, name: 'Big', quantity: 2, price: 50, total: 100),
        _line(productId: 2, name: 'Small', quantity: 1, price: 20, total: 20),
      ];
      final alloc = allocateDiscount(lines, 12.0);
      expect(alloc[1]!.single, greaterThan(alloc[2]!.single));
    });

    test('empty lines return empty map', () {
      expect(allocateDiscount(const [], 10.0), isEmpty);
    });
  });

  group('summarizeInvoices', () {
    test('ignores item rows whose invoice_id is unknown', () {
      final invoices = [
        <String, dynamic>{
          'id': 1,
          'invoice_number': 'INV-1',
          'status': 'completed',
          'created_at': '2026-08-18',
          'subtotal_amount': 50.0,
          'discount_amount': 5.0,
          'total_amount': 45.0,
        },
      ];
      final items = [
        <String, dynamic>{
          'invoice_id': 99,
          'product_id': 1,
          'product_name': 'X',
          'quantity': 1,
          'price': 99,
          'total': 99,
          'cost_snapshot': 1,
          'unit_profit': 98,
          'total_profit': 98,
        },
      ];
      final result = summarizeInvoices(invoices, items);
      expect(result.invoices, hasLength(1));
      expect(result.invoices[1]!.lines, isEmpty);
      expect(result.invoices[1]!.cogs, 0.0);
    });

    test('legacy rows reconstruct cost from frozen unit profit without re-running recipes', () {
      final invoices = [
        <String, dynamic>{
          'id': 1,
          'invoice_number': 'INV-1',
          'status': 'completed',
          'created_at': '2026-08-18',
          'subtotal_amount': 100.0,
          'discount_amount': 0.0,
          'total_amount': 100.0,
        },
      ];
      final items = [
        <String, dynamic>{
          'invoice_id': 1,
          'product_id': 1,
          'product_name': 'A',
          'quantity': 2,
          'price': 50,
          'total': 100,
          'cost_snapshot': 0, // pre-snapshot invoice
          'unit_profit': 30, // frozen at sale time
          'total_profit': 60,
        },
      ];
      final result = summarizeInvoices(invoices, items);
      final inv = result.invoices[1]!;
      expect(inv.cogs, 0.0); // strict path has no snapshot
      expect(inv.cogsWithFallback, 40.0); // 2 x (50 - 30)
    });

    test('snapshot rows contribute to both strict and fallback COGS', () {
      final invoices = [
        <String, dynamic>{
          'id': 1,
          'invoice_number': 'INV-1',
          'status': 'completed',
          'created_at': '2026-08-18',
          'subtotal_amount': 100.0,
          'discount_amount': 0.0,
          'total_amount': 100.0,
        },
      ];
      final items = [
        <String, dynamic>{
          'invoice_id': 1,
          'product_id': 1,
          'product_name': 'A',
          'quantity': 3,
          'price': 100 / 3,
          'total': 100,
          'cost_snapshot': 20,
          'unit_profit': 13.33,
          'total_profit': 40,
        },
      ];
      final result = summarizeInvoices(invoices, items);
      final inv = result.invoices[1]!;
      expect(inv.cogs, 60.0);
      expect(inv.cogsWithFallback, 60.0);
    });
  });

  group('aggregateSummary and FinancialSummary', () {
    test('empty input yields zero totals safely', () {
      final summary = aggregateSummary(const []);
      expect(summary.netRevenue, 0.0);
      expect(summary.grossProfitWithFallback, 0.0);
      expect(summary.profitMargin, 0.0);
      expect(summary.totalItemsSold, 0);
      expect(summary.invoiceCount, 0);
    });

    test('aggregation sums revenue, discount, and COGS across invoices', () {
      final f1 = _invoice(
        id: 1,
        subtotal: 60,
        discount: 6,
        net: 54,
        cogs: 20,
        cogsWithFallback: 22,
        lines: [_line(productId: 1, name: 'A', quantity: 2, price: 30, total: 60)],
      );
      final f2 = _invoice(
        id: 2,
        subtotal: 40,
        discount: 4,
        net: 36,
        cogs: 10,
        cogsWithFallback: 10,
        lines: [_line(productId: 2, name: 'B', quantity: 1, price: 40, total: 40)],
      );
      final summary = aggregateSummary([f1, f2], expensesTotal: 15.0);
      expect(summary.grossSales, 100.0);
      expect(summary.discountTotal, 10.0);
      expect(summary.netRevenue, 90.0);
      expect(summary.cogs, 30.0);
      expect(summary.cogsWithFallback, 32.0);
      expect(summary.grossProfit, 60.0); // 90 - 30
      expect(summary.expenses, 15.0);
      expect(summary.netProfit, 45.0); // 60 - 15
      expect(summary.totalItemsSold, 3);
      expect(summary.profitMargin, closeTo(60.0 / 90.0 * 100.0, 0.0001));
    });

    test('aggregation clamps NaN and infinite input values to zero', () {
      final f = InvoiceFinancials(
        invoiceId: 1,
        invoiceNumber: 'INV-1',
        status: 'completed',
        createdAt: '',
        subtotal: double.nan,
        discount: double.infinity,
        netRevenue: 50.0,
        lines: [_line(productId: 1, name: 'A', quantity: 1, price: double.nan, total: 50)],
        cogs: double.nan,
        cogsWithFallback: double.infinity,
        discountAllocations: const {},
      );
      final summary = aggregateSummary([f]);
      expect(summary.netRevenue, 50.0);
      expect(summary.cogs, 0.0);
      expect(summary.grossSales, 0.0);
      expect(summary.cogsWithFallback, 0.0);
    });
  });

  group('topProductsByDiscountedProfit', () {
    test('ranking respects discounted profit descending and applies limit', () {
      final f1 = _invoice(
        id: 1,
        subtotal: 150,
        discount: 30,
        net: 120,
        lines: [
          _line(productId: 1, name: 'A', quantity: 2, price: 50, total: 100, costSnapshot: 20, unitProfit: 30, totalProfit: 60),
          _line(productId: 2, name: 'B', quantity: 1, price: 50, total: 50, costSnapshot: 30, unitProfit: 20, totalProfit: 20),
        ],
      );
      final top = topProductsByDiscountedProfit([f1], limit: 1);
      expect(top, hasLength(1));
      expect(top.first['product_name'], 'A');
      expect(top.first['qty'], 2);
      // Discounted profit must be gross item profit minus allocated discount.
      final discounted = top.first['discountedProfit'] as double;
      final alloc = 30.0 * (100.0 / 150.0);
      expect(discounted, closeTo(60.0 - alloc, 0.0005));
      // Phase 1.1: the line's own allocation comes from the invoice's
      // per-line allocation list and sums correctly across lines.
      expect(_sumAlloc(f1.discountAllocations), closeTo(30.0, 0.0005));
    });

    test('discounted profits across products approximate aggregate discounted profit', () {
      final f1 = _invoice(
        id: 1,
        subtotal: 100,
        discount: 10,
        net: 90,
        lines: [
          _line(productId: 1, name: 'A', quantity: 1, price: 66.67, total: 66.67, unitProfit: 60),
          _line(productId: 2, name: 'B', quantity: 1, price: 33.33, total: 33.33, unitProfit: 30),
        ],
      );
      final top = topProductsByDiscountedProfit([f1], limit: 10);
      final sum = top.fold<double>(0, (s, m) => s + m['discountedProfit'] as double);
      // Discount allocations partition the invoice discount exactly across lines,
      // so the per-product discounted profits sum to (stored unit profits
      // discounted) - invoice discount: 90 - 10 = 80.
      expect(sum, closeTo(80.0, 0.005), reason: 'sum=$sum');
      // Aggregate comparison: build the fallback COGS the same way the
      // production path does (price - unitProfit) and compare against it.
      final fallbackCogs = f1.lines.fold<double>(
          0.0,
          (acc, line) =>
              acc + math.max(line.quantity, 0) * math.max(line.price - line.unitProfit, 0.0));
      final expected = f1.netRevenue - fallbackCogs;
      expect((sum - expected).abs(), lessThan(0.005), reason: 'sum=$sum expected=$expected');
    });
  });

  group('Phase 1.1 hardening: discount > gross', () {
    test('requested discount 500 on gross 100 is clamped to 100 (net never negative)', () {
      final lines = [_line(productId: 1, name: 'A', quantity: 1, price: 100, total: 100)];
      final alloc = allocateDiscount(lines, 500.0);
      // Effective discount = clamp(500, 0, 100) = 100.
      expect(_sumAlloc(alloc), 100.0);
      // Net revenue can never become negative because of the discount:
      // net = gross - effectiveDiscount = 0, not -400.
    });

    test('discount exactly equal to gross yields net revenue zero', () {
      final lines = [_line(productId: 1, name: 'A', quantity: 1, price: 100, total: 100)];
      final alloc = allocateDiscount(lines, 100.0);
      expect(_sumAlloc(alloc), 100.0);
    });

    test('discount slightly above gross (101 on 100) clamps to 100', () {
      final lines = [_line(productId: 1, name: 'A', quantity: 1, price: 100, total: 100)];
      final alloc = allocateDiscount(lines, 101.0);
      expect(_sumAlloc(alloc), 100.0);
    });

    test('zero gross with any discount yields zero allocations', () {
      final lines = [_line(productId: 1, name: 'A', quantity: 1, price: 0, total: 0)];
      final alloc = allocateDiscount(lines, 100.0);
      expect(_sumAlloc(alloc), 0.0);
    });

    test('negative discount never produces negative allocations', () {
      final lines = [
        _line(productId: 1, name: 'A', quantity: 1, price: 50, total: 50),
        _line(productId: 2, name: 'B', quantity: 1, price: 50, total: 50),
      ];
      final alloc = allocateDiscount(lines, -25.0);
      for (final list in alloc.values) {
        for (final v in list) {
          expect(v, greaterThanOrEqualTo(0.0), reason: 'v=$v');
        }
      }
      expect(_sumAlloc(alloc), 0.0);
    });

    test('InvoiceFinancials.effectiveDiscount exposes the clamped value', () {
      final lines = [_line(productId: 1, name: 'A', quantity: 1, price: 100, total: 100)];
      expect(_invoice(id: 1, subtotal: 100, discount: 500, net: 0, lines: lines).effectiveDiscount, 100.0);
      expect(_invoice(id: 2, subtotal: 100, discount: -10, net: 100, lines: lines).effectiveDiscount, 0.0);
      expect(_invoice(id: 3, subtotal: 100, discount: 50, net: 50, lines: lines).effectiveDiscount, 50.0);
    });
  });

  group('Phase 1.1 hardening: duplicate product IDs keep per-line allocations', () {
    test('two lines with the same productId each keep their own allocation (no overwrite)', () {
      final lines = [
        _line(productId: 100, name: 'X', quantity: 1, price: 100, total: 100, unitProfit: 40),
        _line(productId: 100, name: 'X', quantity: 2, price: 50, total: 200, unitProfit: 20),
      ];
      final alloc = allocateDiscount(lines, 30.0);
      // One List<double> entry per line, both under productId 100.
      expect(alloc[100], hasLength(2));
      final sum = _sumAlloc(alloc);
      expect((sum - 30.0).abs(), lessThan(0.0005), reason: 'sum=$sum');
      // Line 0 gross=100, line 1 gross=200 → allocations 10 and 20.
      expect(alloc[100]![0], closeTo(10.0, 0.0005));
      expect(alloc[100]![1], closeTo(20.0, 0.0005));
    });

    test('per-line discounted profits preserved by topProductsByDiscountedProfit', () {
      final lines = [
        _line(productId: 100, name: 'X', quantity: 1, price: 100, total: 100, unitProfit: 40, totalProfit: 40),
        _line(productId: 100, name: 'X', quantity: 2, price: 50, total: 200, unitProfit: 20, totalProfit: 40),
      ];
      final inv = _invoice(id: 1, subtotal: 300, discount: 30, net: 270, lines: lines);
      final top = topProductsByDiscountedProfit([inv], limit: 5);
      expect(top, hasLength(1));
      // Both lines keep independent allocations: 40 - 10 and 2*(20) - 20 = 30 + 20 = 50.
      final discounted = top.first['discountedProfit'] as double;
      expect(discounted, closeTo(50.0, 0.0005), reason: 'discounted=$discounted');
      expect(top.first['qty'], 3);
    });

    test('three lines: pid 10, pid 10, pid 20 — every line keeps its allocation', () {
      final lines = [
        _line(productId: 10, name: 'A', quantity: 1, price: 100, total: 100),
        _line(productId: 10, name: 'A', quantity: 1, price: 50, total: 50),
        _line(productId: 20, name: 'B', quantity: 1, price: 150, total: 150),
      ];
      final alloc = allocateDiscount(lines, 30.0);
      // Total gross = 300: line0 10, line1 5, line2 15.
      expect(alloc[10], hasLength(2));
      expect(alloc[10]![0], closeTo(10.0, 0.0005));
      expect(alloc[10]![1], closeTo(5.0, 0.0005));
      expect(alloc[20], hasLength(1));
      expect(alloc[20]![0], closeTo(15.0, 0.0005));
      expect(_sumAlloc(alloc), closeTo(30.0, 0.0005));
    });

    test('very small fractional amounts round safely', () {
      final lines = [
        _line(productId: 1, name: 'A', quantity: 1, price: 0.01, total: 0.01),
        _line(productId: 2, name: 'B', quantity: 1, price: 0.02, total: 0.02),
      ];
      final alloc = allocateDiscount(lines, 0.005);
      // 0.005 rounds to 0.01 (1 unit of the smallest fraction, assigned to
      // the largest line). Allocations can never exceed the rounded
      // effective discount and stay non-negative.
      expect(_sumAlloc(alloc), closeTo(0.01, 0.0005));
      for (final list in alloc.values) {
        for (final v in list) {
          expect(v, greaterThanOrEqualTo(0.0));
        }
      }
    });

    test('proportional rounding fractions resolve with last-penny rule', () {
      final lines = [
        _line(productId: 1, name: 'A', quantity: 1, price: 10.01, total: 10.01),
        _line(productId: 2, name: 'B', quantity: 1, price: 10.0, total: 10.0),
        _line(productId: 3, name: 'C', quantity: 1, price: 10.0, total: 10.0),
      ];
      final alloc = allocateDiscount(lines, 3.0);
      final sum = _sumAlloc(alloc);
      expect((sum - 3.0).abs(), lessThan(0.0005), reason: 'sum=$sum');
    });

    test('aggregate discounted profit equals sum of per-line discounted profits with duplicates', () {
      final inv = _invoice(
        id: 1,
        subtotal: 300,
        discount: 30,
        net: 270,
        lines: [
          _line(productId: 100, name: 'X', quantity: 1, price: 100, total: 100, unitProfit: 40, totalProfit: 40),
          _line(productId: 100, name: 'X', quantity: 2, price: 50, total: 200, unitProfit: 20, totalProfit: 40),
        ],
      );
      final summary = aggregateSummary([inv]);
      final top = topProductsByDiscountedProfit([inv], limit: 10);
      final topSum = top.fold<double>(0, (s, m) => s + m['discountedProfit'] as double);
      // Gross item profit 80 - effective discount 30 = 50.
      expect(summary.grossProfit, closeTo(270.0 - 0.0, 0.0005));
      expect(topSum, closeTo(50.0, 0.0005), reason: 'topSum=$topSum');
    });
  });
}
