# v3.9.0+18 — Stage 8

- Synchronized in-app version metadata with package version.
- Documented first-run credential consideration for production release.

# v3.8.0+17 — Stage 7

- Hardened async date-picker flows against setState-after-dispose errors.
- No feature or schema changes.

# Changelog

## 3.7.0+16
- Stage 6: loyalty reversal now uses the points actually awarded to the invoice.

## [3.5.0] - Security & Permissions Hardening

- Restricted user roles to manager/cashier.
- Added authentication guard for deleting parked orders.
- Restricted finance-sensitive expense and BI data at the service layer.
- Limited cashier shift history to the authenticated cashier.
- No database migration.

## [3.4.0] - Financial Integrity Hardening

- Added service-layer validation for invoice subtotal, discount, total, payment and change values.
- Rejected invalid payment methods and inconsistent non-cash payment amounts.
- Fixed invalid Dart SQL string literals in shift and profit/revenue reporting queries.
- No database schema migration.
- No UI or unrelated feature changes.

## [3.3.0] - Release Candidate

- تثبيت نسخة RC وتجهيز بوابة الإطلاق.
- تحديث README والتوثيق ليعكسا الميزات الحالية.
- إضافة Release Candidate Gate للاختبارات الحرجة.
- لا توجد Migration جديدة لقاعدة البيانات في هذه المرحلة.

# Hot Burger Changelog

## 3.2.0 — Production Hardening
- Safe SQLite backup/restore flow with validation and rollback.
- Database v15 indexes for customer, loyalty and invoice audit lookups.
- Version/package metadata synchronized.

## 3.0.0 - Business Intelligence
- Added Business Intelligence dashboard.
- Added KPI, payment, peak-hour, customer, and stock analytics.
- Added shortcuts from Dashboard and Administration.
- No database migration.

## v2.9.0 — العملاء والولاء
- إدارة العملاء وربطهم بالفواتير.
- سجل مشتريات العميل ونقاط الولاء.
- اختيار العميل من شاشة POS.
- ترقية قاعدة البيانات إلى v13.


## 2.8.0
- Added Kitchen Display System (KDS) workflow.
- Added invoice kitchen status and audit tracking.
- Added responsive kitchen ticket board and filters.
- Enabled landscape orientation for tablet/wide POS and KDS use.

2.7.0+8 - POS Pro UI

- Redesigned the POS workspace for responsive phone, tablet and desktop layouts.
- Added compact product cards with live cart quantity badges.
- Added faster cart controls and a clearer checkout summary.
- Restored payment method selection directly in the checkout panel.
- Added clearer empty states and touch-friendly product interactions.
- Kept parked orders, discounts, returns, shifts, permissions and payment tracking intact.
- Updated app version to 2.7.0+8.

## 2.6.0 — Operational Dashboard

- Added dashboard operational center for shift and parked-order status.
- Added quick navigation to shift management and POS.

# Hot Burger - Changelog

## 2.5.0+6 - POS Pro

- Added parked/pending orders without affecting inventory.
- Added resume/delete pending orders from the POS.
- Added full invoice return for managers with inventory restoration and audit trail.
- Returned invoices are excluded from sales and profit reports.
- Added returned invoice status in invoice list/details.
- Database upgraded from v10 to v11 with pending order tables and indexes.
- Updated Android/Flutter app version to 2.5.0+6.

# CHANGELOG

## [1.0.0] - 2026-08-03

### MVP v1.0 - النسخة الأولى الرسمية

تم تطوير التطبيق على 3 مراحل تنفيذ:

---

### المرحلة الأولى: إصلاح الأخطاء الوظيفية

- إصلاح اختيار التصنيف في نموذج إضافة منتج (`products_screen.dart`)
- إضافة اختيار التصنيف وحالة التوفر في نموذج تعديل المنتج (`products_screen.dart`)
- إصلاح الشرط المنطقي المعكوس في استيراد النسخة الاحتياطية (`backup_screen.dart`)
- تنسيق التواريخ في شاشة الفواتير وتفاصيلها (`invoices_screen.dart`, `invoice_detail_screen.dart`)

---

### المرحلة الثانية: تحسينات الواجهة

- إضافة مفتاح تفعيل/تعطيل التصنيف في شاشة التصنيفات (`categories_screen.dart`)
- إضافة زر تعديل المصروف في شاشة المصروفات (`expenses_screen.dart`)
- تنسيق رقم الإجمالي بفاصل الآلاف في شاشة الفواتير (`invoices_screen.dart`)

---

### المرحلة الثالثة: تحسينات الأداء والنظافة

- إزالة التحميل المتكرر للتصنيفات في شاشة المبيعات باستخدام تخزين مؤقت (`sales_screen.dart`)
- إصلاح 20 رسالة `prefer_const_constructors` في شاشة المبيعات (`sales_screen.dart`)

---

### الحالة النهائية

| المقياس | القيمة |
|---------|--------|
| أخطاء بناء (errors) | 0 |
| تحذيرات (warnings) | 0 |
| رسائل معلوماتية (info) | 87 (prefer_const / prefer_final_fields) |
| ملفات الكود | 16 ملف |
| الشاشات | 10 شاشات |
| الجداول | 7 جداول |
| Offline First | 100% |
| بيانات تجريبية | لا يوجد |

## 2.4.0
- Professional POS checkout with discounts and payment handling.
- Cash received/change calculation.
- Card payment method.
- Invoice and receipt detail improvements.
- Database migration to v10.

## 3.1.0 — Production Hardening
- Enabled SQLite foreign-key enforcement.
- Added salted, iterated password hashing with legacy upgrade path.
- Improved invoice number generation.
- Enforced sequential KDS state transitions.
- Database schema upgraded to v14.


## 3.6.0 — Inventory & Recipes Hardening
- Validate recipe quantities and purchase values.
- Keep recipe stock deduction and audit logging atomic on one transaction.
