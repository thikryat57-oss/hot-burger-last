# HOT BURGER — Phase 5.1.0: Business Intelligence & Operational Analytics Readiness Audit

**المؤلف:** Manus AI
**التاريخ:** 20 أغسطس 2026
**النطاق:** Audit READ-ONLY — لا تعديلات على كود الإنتاج، الاختبارات، قاعدة البيانات، الـ Schema، الترحيلات (migrations)، أو CI/CD
**خط الأساس:** commit `65113e6` (main) — تقرير Phase 5.0 فقط
**قرار الجاهزية:** **B — STABLE, ONE P2 FIX RECOMMENDED** (BI-F-01)

---

## 1. الملخص التنفيذي (Executive Summary)

هذا التقرير هو نتيجة تدقيق READ-ONLY شامل لطبقة التحليلات المالية والتشغيلية في تطبيق HOT BURGER (Flutter / SQLite / Provider)، شمل 22 فئة من فئات الجاهزية: أداء مالي، KPI، مصدر SQL والدوال الكنسية، التصفية، المصروفات، الورديات، طرق الدفع، المرتجعات، البيانات التاريخية، التوفيق (Reconciliation)، المصدر الوحيد للحقيقة، تقريب وأصفار، الأداء، الأمن، offline، الاختبارات، التراجع، وتصنيف كل Finding.

**النتيجة المركزية:** البنية التحليلية للتطبيق **سليمة وجاهزة للإنتاج** كطبقة تقريرية. جميع مؤشرات الإيرادات والأرباح وCOGS تُحسب عبر طبقة كنسية واحدة (`financial_calculator.dart`) بتصفيات متسقة للمرتجعات والملغى، مع تجميد (snapshot) القيم المالية عند لحظة البيع ما يجعل التقارير التاريخية موثوقة. تم تأكيد finding واحد حقيقي من الدرجة P2:

> **BI-F-01 (P2):** توزيع طرق الدفع في شاشة Business Intelligence (نقدًا / بطاقة / تحويل) يعرض أصفارًا في كل الحالات، لأن `getBusinessIntelligence` يستدعي الدالة الكنسية `aggregateSummary` دون تمرير وسيط `paymentSplits`، بينما توجد القيم الحقيقية محسوبة بالفعل في استعلام SQL الخام وغير مستخدمة.

التصحيح المقترح بسيط جدًا (نحو 3 أسطر) ولا يتطلب أي تغيير schema أو اختبار. جميع findings الأخرى موثقة كفجوات من الدرجة P3 لا تتطلب إصلاحًا في الوقت الحالي.

**Production Modified = NO | Tests Modified = NO | Database Modified = NO | Schema = NO | Migrations = NO | CI = NO | Commit = YES (تقرير فقط) | Push = YES**

---

## 2. نتيجة بوابة خط الأساس (Baseline Gate Results)

| البند | القيمة | الحالة |
|---|---|---|
| الفرع | `main` | ✓ |
| HEAD (الرمز البصري المختصر) | `65113e6` | ✓ |
| شجرة العمل | نظيفة (0 ملفات معدلة؛ artifacts بناء فقط) | ✓ |
| `Constants.dbVersion` | **16** (لا ترحيلات جديدة) | ✓ |
| `flutter test` | **143/143** كل الاختبارات PASS (SQLite حقيقي) | ✓ |
| `flutter analyze` | **0 أخطاء**، 5 تحذيرات موجودة مسبقًا (Phase 4.7.2)، 253 infos | ✓ |
| CI (آخر 4 عمليات) | 3231106 / 3231035 / 3230976 / 3230615 — جميعها SUCCESS | ✓ |
| Health Score عند القفل | **97/100** (P0=0، P1=0، P2=0، P3=8) | ✓ |

**ملاحظة توثيقية:** مواصفة المرحلة تشير إلى خط أساس `9d13e57` (commit كود Phase 4.7.2)، بينما HEAD الفعلي هو `65113e6` = `9d13e57` + commitا تقرير فقط (`21a876b` تقرير 4.7.2، `65113e6` تقرير 5.0). **لا يوجد أي commit كود بينهما**، وبالتالي لا فرق تشغيلي إطلاقًا؛ تم اعتماد `65113e6` كخط الأساس الموثق لهذه المرحلة.

---

## 3. جرد التحليلات الحالية (Analytics Inventory)

جرى تعداد جميع دوال التحليلات في طبقة `app_provider.dart` (الطبقة الموفرة الوحيدة للبيانات التحليلية):

| # | الدالة | السطور التقريبية | نوع الاستعلام | الحالة |
|---|---|---|---|---|
| 1 | `getDailyReport` | 1125–1154 | مختلط (SQL + كنسي) | ✓ |
| 2 | `getMonthlyReport` | 1156–1188 | مختلط | ✓ |
| 3 | `getShiftSummary` | 1190–1278 | 4 استعلامات خام + كنسي | ✓ (ملاحظة أداء) |
| 4 | `getProfitAndLossSummary` (P&L) | 1280–1352 | مختلط | ✓ (فجوة توفيق موثقة) |
| 5 | `getDashboardDailySales` | 1354–1365 | SQL خام (سلسلة) | ✓ |
| 6 | `getDashboardDailyNetSales` | 1367–1378 | SQL خام (سلسلة) | ✓ |
| 7 | `getTopProductsByQuantity` | 1380–1391 | SQL خام (GROUP BY) | ✓ (توثيق: إجمالي ما قبل الخصم) |
| 8 | `getTopProductsByProfit` | 1393–1410 | كنسي كامل | ✓ |
| 9 | `getExpenseSummary` | 1412–1423 | SQL خام | ✓ |
| 10 | `getBusinessIntelligence` | 1433–1520 | مختلط (aggregator) | ✓ **BI-F-01 (P2)** |
| 11 | `getCurrentShiftCashSummary` | 160–174 | SQL خام (نقد الوردية) | ✓ (فجوة دلالية F-02) |

---

## 4. التحقق من الطبقة الكنسية (Canonical Layer Verification)

الملف `lib/core/utils/financial_calculator.dart` (472 سطرًا) هو **مصدر الحقيقة المالي الوحيد** الموثق في الكود، ويتكون من:

- **الفئات:** `FinancialLineItem`، `InvoiceFinancials`، `FinancialSummary`، `InvoiceSummaryResult`، `_ProductAccum`
- **الدوال الساكنة:** `summarizeInvoices`، `aggregateSummary`، `topProductsByDiscountedProfit`

الخصائص الهندسية الموثقة في التدقيق:

| الخاصية | السلوك المؤكد |
|---|---|
| تجميد التكلفة | `InvoiceFinancials.cogs` من عمود `cost_snapshot` المجمّد (>0) فقط |
| الاسترجاع للصفوف القديمة | `cogsWithFallback` = cost_snapshot أو إعادة إعمار من `unit_profit` المجمّد: `max(price − unit_profit, 0)` |
| توزيع الخصم | pro-rata حسب حجم كل سطر، بمصفوفة `discountAllocations` بمُدخل **لكل سطر** (نفس productId يكرر حصته) — Phase 1.1 hardening |
| المشابك (Clamps) | `effectiveDiscount` في [0, subtotal]؛ `_clean()` يحيد NaN/Infinity → 0.0 |
| طرق الدفع | `cashTotal/bankTotal/cardTotal/transferTotal` تُعبأ من وسيط `paymentSplits` فقط |
| الأصفار الآمنة | `profitMargin` = 0 عند revenue = 0؛ `totalItemsSold` بـ `max(quantity,0)` |
| المرتجعات | التصفية على مستوى الفاتورة (cancelled/returned مستبعدة في `summarizeInvoices`) |

**قاعدة المصدر الوحيد للحقيقة محققة:** كل تقارير الإنتاج تسلك المسار الكنسي باستثناء استعلامات SQL الخام البسيطة (عد/جمع/توزيع دفع/سلاسل يومية) الموثقة أدناه.

---

## 5. اتساق تعريفات KPI عبر التقارير (KPI Consistency)

| التعريف | المصدر | الاتساق |
|---|---|---|
| `netSales` (totalSales) | `total_amount` (صافٍ بعد الخصم) | متسق في كل التقارير ✓ |
| `grossSales` | `subtotal_amount` | متسق ✓ |
| `discountTotal` | `discount_amount` | متسق ✓ |
| `invoiceCount` | عد الفواتير غير الملغاة/المرتجعة | متسق ✓ |
| `averageTicket` | netRevenue ÷ invoiceCount (0 عند الصفر) | آمن ✓ |
| `netProfit` يومي/شهري | `grossProfitWithFallback − totalExpenses` | متسق بين daily/monthly ✓ |
| `netProfit` في P&L | `grossProfit (snapshot) − totalExpenses` | **انحراف موثق** (القسم 12) |
| `cogs` | cost_snapshot المجمّد | ثابت ✓ |
| `cogsFallback` | إعادة إعمار legacy أو وصفة اليوم (SQL) | موثق ثنائي المسار ✓ |

الأصفار والفراغات محصّنة: `COALESCE` في كل مجاميع SQL، لا يوجد NaN/Inf (طبقة `_clean` عدوانية)، ولا انقسام صفر (division-by-zero) لأن المقامات تحرس بـ `revenue==0 → margin 0` و`invoiceCount==0 → averageTicket 0`.

---

## 6. البيانات التاريخية وسلامة اللقطات (Historical Data Integrity)

تصميم `invoice_items` يجمّد **جميع** القيم المالية عند لحظة البيع: `cost_snapshot` (v14→v15)، `unit_profit`، `total_profit`، `recipe_snapshot` (v15→v16)، مع `product_name` واسم المنتج النصي. هذا يعني:

- حذف منتج أو مكون من الكتالوج لا يؤثر على التقارير التاريخية (الاسم والقيم محفوظة).
- تغيير `inventory.cost_price` لاحقًا لا يغيّر COGS الفواتير الملتقطة (`cost_snapshot > 0`).
- استرجاع المخزون عند الإلغاء/المرتجع (Phase 4.6.1) يكتب في `inventory_audit_log` فقط — **الأعمدة المالية المجمّدة في invoice_items غير ممسوسة** (تأكيد Phase 5.0).

**تصنيف موثوقية KPI عبر الزمن:**

| الفئة | المؤشرات | الدلالة |
|---|---|---|
| **A — موثوق كليًا** | grossSales، discountTotal، netRevenue، invoiceCount، averageTicket، توزيع طرق الدفع | مباشر من جدول invoices (v1–v16) |
| **B — موثوق بحد legacy موثق** | cogs، grossProfit، netProfit للصفوف pre-snapshot (`cost_snapshot=0`) | صيغتان: إعادة إعمار من unit_profit المجمّد (كنسي) أو وصفة اليوم × `inventory.cost_price` الحالية (SQL) — قد تختلفان قليلًا |
| **C — غير دقيق بالصف** | دقة COGS على مستوى الصنف للصفوف pre-v14 | `unit_profit` القديم قد يكون gross (قبل توزيع الخصم) في بعض البيانات التراثية |

الصفوف المُنشأة بعد v16 (Phase 2.1) جميعها تلتقط `cost_snapshot` و`recipe_snapshot` عند الكتابة — موثوقة كليًا.

---

## 7. تصفية المرتجعات والملغى (Returns/Voids Filtering)

الفلاتر `status NOT IN ('cancelled','returned')` مُطبقة في **جميع** استعلامات SQL التحليلية: daily، monthly، shift (الإجمالي + نقد + بنك + بطاقة + item-join)، P&L، dashboard ×2، top-by-quantity، BI sales، الساعاتية، والعملاء. وفي المسار الكنسي تُستبعد على مستوى الفاتورة.

**تأكيد سلوك التيم (Orphan) الآمن:** `summarizeInvoices` يبني خريطة من `invoiceRows` فقط، وتجاهل صف العنصر الذي لا يجد فاتورة أم: `if (invoice == null) continue`. أي أن صفوف عناصر الفواتير الملغاة/المرتجعة (المجلبَة بدون فلتر في `getDailyReport`/`getMonthlyReport`/P&L) **تُسقط صامتًا بأمان** — سلوك مقصود ومثبت، وليس تسريبًا.

**المرتجعات الجزئية:** غير مدعومة بنموذج البيانات (status على مستوى الفاتورة كاملة) — لا يوجد افتراض خاطئ لأن المفهوم غير موجود أصلًا.

---

## 8. تحليل المصروفات (Expense Analytics)

- جدول `expenses`: حقل `date TEXT NOT NULL` (ISO format) + فهرس `idx_expenses_date`.
- التقارير (يومي/شهري/P&L/BI): الفلترة على `expenses.date` بدلالة "اليوم"؛ مقارنة `BETWEEN` نصية صحيحة لأن التواريخ ISO ذات طول ثابت ومعبأة أصفارًا.
- `getExpenseSummary`: `SUM(amount) ... GROUP BY name ORDER BY amount DESC` — بسيط وسليم.

> **F-02 (سابق، معاد تأكيده — P3):** ملخص النقدية للوردية `getCurrentShiftCashSummary` يفلتر المصروفات بـ `expenses.created_at >= shift.openedAt` (دلالة زمنية/طابع زمني)، بينما التقارير تستخدم `expenses.date` (دلالة يومية). لكل مسار اتساق داخلي، لكن مصالحة "وردية مقابل يوم" تتأثر بالفجوة الدلالية. موثق منذ Phase 4.7.0 ولا يتطلب إصلاحًا في هذه المرحلة.

---

## 9. طرق الدفع (Payment Methods)

| البند | النتيجة |
|---|---|
| عدد الطرق | 3: `cash` / `card` / `bank` (bank = تحويل) |
| النموذج | عمود واحد `payment_method TEXT NOT NULL DEFAULT 'cash'` لكل فاتورة — **لا دعم للتقسيم (split payment)** |
| العد المزدوج | مستحيل بنائيًا (قيمة واحدة لكل فاتورة) |
| الاتساق | كل استعلامات الدفع تتضمن `NOT IN ('cancelled','returned')` |
| التحليل بالوردية | `getShiftSummary` يعيد `cashTotal/bankTotal/cardTotal` للنافذة الزمنية — متوفر ✓ |

---

## 10. شاشة Business Intelligence (نطاق BI-F-01)

`getBusinessIntelligence` (1433–1520) هي دالة المجمّع (aggregator) الوحيدة في التطبيق وتشمل:

- **حارس الأمان:** أول سطر تشغيلي `if (!canManageFinance()) throw Exception(...)` — **محمية** ✓ (الدالة التحليلية الوحيدة المحمية داخليًا).
- `sales` (SQL خام): مجاميع `total_amount`/`subtotal`/`discounts` + عد + توزيع طرق الدفع عبر `CASE payment_method WHEN 'cash' ... WHEN 'card' ... WHEN 'bank'` — **يُحسب صحيحًا** مع فلتر NOT IN.
- المسار الكنسي: `invoiceRows + itemRows → summarizeInvoices → aggregateSummary(expensesTotal:)` → `netRevenue/grossSales/discountTotal/cogsWithFallback/netProfitWithFallback`.
- `grossProfit = agg.grossProfitWithFallback`، الهامش 0 عند revenue صفر، averageTicket 0 عند invoiceCount صفر — **آمن**.
- `hourly`: سلاسل ساعاتية بفلتر NOT IN ✓
- `customers`: أعلى 8 عملاء إنفاقًا بربط customers↔invoices بفلتر NOT IN ✓
- `lowStock`: `inventory WHERE qty <= min_quantity` (ضمن خريطة BI المحمية ✓)

**الخلل المؤكد BI-F-01 (مفصل في القسم 13):** قائمة `payment` المبنية من `agg.cashTotal/cardTotal/bankTotal` تساوي صفرًا دائمًا لأن `aggregateSummary` لم يُمرَّ له `paymentSplits`، رغم وجود القيم الحقيقية محسوبة في خريطة `sales` الخام غير المستغلة.

---

## 11. سلسلة المبيعات اليومية (Dashboard Series)

`getDashboardDailySales` و`getDashboardDailyNetSales` هما استعلاما SQL خامان يعيدان سلسلة `SUM(total_amount)/SUM(subtotal_amount)/SUM(discount_amount), COUNT(*)` حسب `DATE(created_at)` مع فلتر NOT IN و`ORDER BY DATE ASC`. لا COGS ولا أرباح فيهما (سلاسل صافي/إجمالي فقط) — اتساق فلاترهما مع P&L والتقارير اليومية **مؤكد**، ولا توجد مخاطر دلالية.

---

## 12. مصفوفة التوفيق (Reconciliation Matrix)

| الزوج المرصود | النتيجة |
|---|---|
| shift cogs/grossProfit **مقابل** P&L cogs/grossProfit | **متساويان** (نفس SQL CASE والفلتر) — مثبت باختبار db_integration |
| daily netProfit **مقابل** monthly netProfit | متسق (نفس الصيغة `grossProfitWithFallback − expenses`) |
| P&L netProfit **مقابل** daily/monthly netProfit | **فجوة توثيقية:** P&L يستخدم `grossProfit` (snapshot cogs فقط) بينما اليومية/الشهرية تستخدم `grossProfitWithFallback` — الفرق يظهر فقط للصفوف legacy (`cost_snapshot=0`) |
| `getTopProductsByQuantity.total` | **إجمالي ما قبل الخصم** (`SUM(total)` الخام، غير موزع pro-rata) — لا يوائم `discountTotal`؛ موثق وليس خطأ |
| `getTopProductsByProfit.profit` | المسار الكنسي الكامل مع توزيع خصم pro-rata — **صحيح ويوائم** |
| BI `sales` raw **مقابل** dashboard series | نفس الدلالات (NOT IN، مجاميع total_amount) — متسق |

**خلاصة التوفيق:** لا يوجد أي تضارب إيرادات أو عدّات؛ الفجوة الوحيدة القابلة للرصد بين التقارير هي أساس COGS في صافي الربح للصفوف القديمة (Legacy basis mismatch)، وهي موثقة في القسم 6 (فئة B) ومحلولة بنائيًا لبيانات v16+.

---

## 13. finding المؤكد — BI-F-01: توزيع طرق الدفع أصفار في شاشة BI (P2)

| البند | التفصيل |
|---|---|
| **الملف** | `lib/providers/app_provider.dart` (سطر الاستدعاء ~1473) |
| **الجذر** | `getBusinessIntelligence` يستدعي `aggregateSummary(..., expensesTotal: totalExpenses)` **دون وسيط** `paymentSplits` |
| **الآلية** | القيمة الافتراضية `paymentSplits = const {}` في `aggregateSummary` → `agg.cashTotal/cardTotal/bankTotal = 0` دائمًا |
| **الأثر المرئي** | `business_intelligence_screen.dart` سطر ~151 يعرض `_data!['payment']` (نقدًا/بطاقة/تحويل) → **المستخدم يرى أصفارًا** في كل نافذة BI |
| **القيم الحقيقية** | محسوبة فعلًا في خريطة `sales` الخام (`cash`/`card`/`transfer`) لكن غير مستخدمة |
| **الخطورة** | **P2** — عرض KPI مالي خاطئ على الشاشة، دون فقد بيانات ودون تأثير على أي KPI آخر (الإيرادات والأرباح صحيحة) |
| **الإصلاح المقترح** | تمرير `paymentSplits: {'cash': salesRow['cash'], 'card': salesRow['card'], 'bank': salesRow['transfer']}` إلى `aggregateSummary` — نحو 3 أسطر، خطر أدنى، لا schema ولا هجرة |
| **التصنيف** | خلل KPI عرضي حقيقي، وليس فجوة مواصفات |

هذا الخلل هو الدليل العملي على فجوة الاختبار الموثقة في القسم 15: لا يوجد اختبار end-to-end لـ `getBusinessIntelligence`، فلولا التدقيق المصدري لظل الخلل مخفيًا.

---

## 14. فجوات P3 الموثقة (لا تتطلب إصلاحًا فوريًا)

| الكود | الوصف | السبب/الأثر |
|---|---|---|
| F-02 (مؤكد) | فجوة دلالية نافذة المصروفات: الوردية بـ `created_at` والتقارير بـ `date` | سابق منذ 4.7.0؛ اتساق داخلي لكل مسار؛ P3 |
| REC-01 | صافي ربح P&L مقابل daily/monthly للصفوف legacy (أساس COGS مختلف) | يظهر فقط لبيانات pre-snapshot؛ v16+ متطابق؛ P3 موثق |
| COGS-01 | صيغتا legacy COGS (SQL وصفة اليوم × cost_price الحالي مقابل إعادة إعمار `max(price−unit_profit,0)` من unit_profit المجمّد) | قد تختلفان قليلًا للصفوف القديمة؛ كلاهما آمن وموثق؛ P3 |
| PERF-01 | `getShiftSummary`: 4 استعلامات خام + 1 مسار كنسي = 7 استعلامات بشاشة واحدة (تكرار netRevenue/invoiceCount/سplits) | ازدواجية جهد قابلة للتوفيق؛ P3 |
| PERF-02 | استعلامات `DATE(created_at)` / `strftime` بدون فهارس تعبيرية (expression indexes) | فحص شامل للجداول الكبيرة؛ أحجام POS أوفلاين تبقى صغيرة؛ P3 |
| AUTH-01 | دوال قراءة التحليلات غير محمية في طبقة provider (BI هي الوحيدة المحمية بـ `canManageFinance`)؛ الاعتماد على حراس مستوى الشاشة | سياق جهاز واحد أوفلاين؛ P3 — لا خطر سلامة بيانات |
| TEST-01 | لا اختبار end-to-end لـ `getBusinessIntelligence` → BI-F-01 مرَّ بدون اكتشاف | مرشح للإصلاح في 5.1.1 مع BI-F-01 |
| RPT-01 | `getTopProductsByQuantity` total هو pre-discount | عرضي لا محاسبي؛ P3 موثق |

---

## 15. تغطية الاختبارات (Test Coverage)

| الحزمة | المحتوى | النتيجة |
|---|---|---|
| `financial_calculator_test.dart` (494 سطرًا، ~24 اختبارًا) | مشابك السالب/NaN، سلامة `fromRow`، `hasLegacyCost`، أصفار التوزيع، مجموع التوزيعات = الخصم بالضبط، التوزيع حسب حجم السطر، تجاهل UNKNOWN INVOICE_ID (يثبت orphan-drop)، التكلفة المُعادة الإعمار دون إعادة تشغيل الوصفات، كلا أسس COGS، المدخلات الفارغة، مجاميع التجميع + حياد NaN/Inf، الترتيب بربحية الخصم، تكرار نفس productId بخصم مستقل، التقريب الكسري بقاعدة "آخر قرش" | 143/143 ✓ |
| `db_integration_test.dart` | مساواة shift↔P&L cogs/grossProfit، إثبات لا-ازدواجية المحرك (TEST 14: خصم كامل → totalSales=0 مع cogs مجمّد)، بوابتا التحقق (خصم >subtotal وندرة مخزون → صفر صفوف مكتوبة) | ✓ |
| **الفجوة** | لا اختبار لـ `getBusinessIntelligence` (المجمّع وشاشته) ولا لـ `getTopProductsByQuantity` (GROUP BY خام) | **BI-F-01 لم يكتشف** |

توصية: في أي جولة إصلاح قادمة (5.1.1) يُضاف اختبار end-to-end لـ `getBusinessIntelligence` يتضمن التحقق من قيم payment غير صفرية.

---

## 16. تغطية الأمن (Auth Coverage)

- `getBusinessIntelligence`: **محمية** بحارس `canManageFinance()` داخليًا — الاستثناء يُرمي قبل أي قراءة.
- CRUD المصروفات (`addExpense`/`getExpenses`/`updateExpense`/`deleteExpense`/`deleteExpenseSafe`): محمية بالكامل مع توثيق الفاعل والسبب (Phase 4.3.1.1).
- دوال القراءة التحليلية الأخرى (`getDailyReport`, `getMonthlyReport`, `getShiftSummary`, `getProfitAndLossSummary`, الدوال السبع للـ dashboard والمنتجات والمصروفات): **غير محمية في طبقة provider** — الحماية تتم على مستوى الشاشات/القوائم (مدراء فقط). في سياق أوفلاين بجهاز واحد (نموذج النشر الحالي) الخطر عملي منخفض، لكنه يوثَّق كفجوة AUTH-01 (P3) لأن قاعدة "حرس كل دالة بيانات حساسة عند المصدر" تبقى الممارسة الأصح.

---

## 17. الأداء (Performance Notes)

التحليلات تُنفَّذ محليًا على SQLite embedded مع استعلامات مختارة بعناية (فلتر NOT IN موحّد، فهارس `idx_invoices_payment_method` و`idx_expenses_date` وPKs مستغلة في حدود SQLite). الملاحظات:

1. `getShiftSummary` بـ 7 استعلامات هو أثقل شاشة (PERF-01) — قابل للتوحيد على النتائج الكنسية دون كسر توافق الخرائط.
2. استعلامات `DATE(created_at)`/`strftime` تجتاح الجدول كاملًا (لا expression indexes) — غير مؤثر عند أحجام POS أوفلاين النموذجية (<10 آلاف فاتورة)، ويُراجع عند النمو (PERF-02).
3. لا توجد بطاقات ن+1 في مسار الكتل؛ الاستعلامات مجمّعة (bulk) دائمًا.

---

## 18. جدوى الميزات المستقبلية (Future Feature Feasibility)

- **Split payment (دفع مقسّم):** غير مدعوم بنموذج البيانات (عمود واحد) — يتطلب schema migration (جدول invoice_payments أو عمود JSON) وهجرة بيانات + إعادة كتابة توزيع الدفع في كل التقارير؛ غير موصى به في المدى القريب، والتصميم الحالي يوثّق القيود صراحة.
- **المرتجعات الجزئية (partial returns):** غير ممكنة ببنية status الحالية؛ تتطلب خط صنف منفصل لكل المرتجعات؛ مؤجلة عمدًا.
- **تقارير متعددة الفروع/العملاء المتقدم:** بنية `customers↔invoices` الحالية (أعلى 8 إنفاقًا) تصلح كأساس لتوسيع ولاء دون تغيير جوهري.
- **Dashboards/تصدير:** السلاسل اليومية وBI aggregator جاهزة كركائز تصدير CSV/PDF دون إعادة بناء.

---

## 19. البنية الدنيا (Minimal Viable Architecture)

الطبقة التحليلية الحالية تحقق الحد الأدنى المهني: طبقة كنسية نقية قابلة للاختبار (financial_calculator)، دوال provider رقيقة (استرجاع صفوف + استدعاء كنسي + بناء خريطة)، فلاتر مرتجعات موحدة، وتجميد مالي عند البيع. لا يوجد ازدواج محرك حسابي (TEST 14 يثبت أن أي كسر لنمط "الدالة الكنسية الوحيدة" يفشل الاختبار فورًا)، ولا منطق مالي في طبقة UI. أي توسع مستقبلي يُبنى فوق نفس البنية دون تغيير جذري.

---

## 20. سجل findings (Findings History)

| الكود | الوصف | الحالة |
|---|---|---|
| F-02 (4.7.0) | فجوة دلالية نافذة المصروفات بين الوردية والتقارير | **مؤكد مجددًا — P3 موثق، مفتوح** |
| BI-F-01 (هذه المرحلة) | توزيع طرق الدفع أصفار في شاشة BI (paymentSplits غير ممرر) | **مؤكد — P2، مرشح إصلاح 5.1.1** |
| REC-01 | أساس COGS في netProfit يختلف بين P&L والتقارير للصفوف legacy | **موثق — P3** |
| COGS-01 | صيغتا legacy COGS مزدوجتان | **موثق — P3** |
| PERF-01/02 | تكرار 7 استعلامات في shift + فحص شامل بدون expression indexes | **P3** |
| AUTH-01 | دوال قراءة التحليلات غير محمية عند provider | **P3** |
| TEST-01 | غياب اختبار end-to-end لـ getBusinessIntelligence | **P3** |
| RPT-01 | total في top-by-quantity هو pre-discount | **P3 موثق** |

جميع findings السابقة من Phase 5.0 (والمراحل الأقدم) التي كانت مغلقة/موثقة تبقى على حالها؛ لا تراجع لأي finding مغلق في هذه المرحلة.

---

## 21. مصفوفة المخاطر (Risk Matrix)

| الخطر | الاحتمال | الأثر | الدرجة | التخفيف |
|---|---|---|---|---|
| استمرار عرض توزيع دفع خاطئ في BI | مؤكد حاليًا | **P2** (إرباك إداري؛ الإيرادات صحيحة) | مرتفعة | إصلاح 3 أسطر في 5.1.1 |
| اختلاف netProfit بين P&L والتقارير للصفوف القديمة | منخفض (بيانات pre-snapshot فقط) | P3 (مصالحة دقيقة) | منخفضة | موثق، v16+ مطابق |
| نمو جداول invoices فوق 10 آلاف | متوسط (طويل المدى) | P3 (فحوص كاملة) | منخفضة | expression indexes مستقبلًا |
| وصول غير مصرح لدوال قراءة تحليلية من كود شاشات جديدة | منخفض (سياق جهاز واحد) | P3 | منخفضة | حراس provider مستقبلًا |
| تكرار finding بياني مشابه (مجمّع يحجب وسيطًا) | متوسط | P2–P3 | متوسطة | اختبار end-to-end لكل مجمّع (TEST-01) |

---

## 22. خطة التراجع (Rollback Plan)

هذه المرحلة READ-ONLY بالكامل، وبالتالي: لا يوجد شيء للتراجع عنه. إذا وُجد لاحقًا أي خطأ في محتوى التقرير، الحذف/التصحيح يتم عبر commit توثيقي جديد على main (لا force push، لا merge، لا rebase) — بنفس قواعد المراحل السابقة.

---

## 23. التحقق من عدم التعديل (No-Modification Verification)

| البند | التحقق | النتيجة |
|---|---|---|
| ملفات lib/ | 0 ملفات تتبعها git معدلة قبل وبعد | ✓ لا تعديل |
| ملفات test/ | 143/143 بدون تغيير أي اختبار | ✓ |
| database_helper.dart / schema | المخطط v16، لا ADD COLUMN | ✓ |
| migrations | لا ترحيلات جديدة | ✓ |
| CI (.github/workflows/build_apk.yml) | غير ممسوس | ✓ |
| financial_calculator.dart | لم يُفتح للتحرير؛ قراءة فقط | ✓ |
| منطق المخزون | لم يُلمس | ✓ |
| git history | HEAD = `65113e6` + commit التقرير فقط بعد الكتابة | ✓ |

---

## 24. ما جرى التحقق منه وما لم يُتحقق (In-Scope / Out-of-Scope)

**داخل النطاق (تم):** 22 فئة من التحليلات المالية والتشغيلية، كل دوال provider التحليلية العشر + ملخص نقد الوردية، الطبقة الكنسية سطرًا سطرًا، التصفيات، التجميد التاريخي، المصالحة، الأمن، الأداء، الاختبارات، وسجل findings.

**خارج النطاق (عمدًا):** مراجعة واجهات UI غير التحليلية، أمان التشفير والتخزين العام، تجربة المستخدم، الأداء العام خارج وظائف التحليلات، بناء APK (غير مطلوب في مرحلة READ-ONLY).

---

## 25. الدروس المكتسبة (Lessons Learned)

1. **المجمّعات (aggregators) أخطر نقاط العمى:** `getBusinessIntelligence` أعاد استخدام الدالة الكنسية الصحيحة لكنه حذف وسيطًا واحدًا (`paymentSplits`) دون أن يلحظه أي مستعرض كود سابق — المجمّعات التي تدمج أكثر من مصدر تحتاج اختبارًا end-to-end خاصًا بها.
2. **الفهارس التعبيرية غير موجودة في SQLite الافتراضي** — قرارات الأداء يجب أن تراعي حدود SQLite لا PostgreSQL.
3. **التوثيق التفصيلي لصيغ legacy** (COGS-01) حوّل "خطأ محتمل" إلى "سلوك معروف موثق" — قيمة التدقيق التوثيقي تفوق قيمة الإصلاح القسري أحيانًا.
4. **قفل خط الأساس برمزيًا** (commit + رقم CI) يمنع الانزلاق الصامت للجدول الزمني للمراحل.

---

## 26. توصيات المرحلة التالية (Recommendations for 5.1.1)

بترتيب الأولوية:

1. **إصلاح BI-F-01:** تمرير `paymentSplits` من خريطة `sales` الخام إلى `aggregateSummary` داخل `getBusinessIntelligence` (نحو 3 أسطر).
2. **إغلاق TEST-01:** إضافة اختبار end-to-end لـ `getBusinessIntelligence` يتحقق من payment غير صفرية + قيم KPI الأساسية.
3. **التنظيف الاختياري P3:** توحيد `getShiftSummary` على النتائج الكنسية (تقليل 7→3 استعلامات تقريبًا) عند وجود وقت.
4. **الترحيب بالحراس:** إضافة حارس `canManageFinance()` لباقي دوال قراءة التحليلات في provider.

---

## 27. قرار الجاهزية النهائي (Readiness Decision)

**الدرجة الصحية:** 97/100 → **96/100** (خصم نقطة واحدة لـ BI-F-01 لأنه finding P2 مؤكد فعال على شاشة إنتاجية).

> **READINESS DECISION: B — STABLE, ONE P2 FIX RECOMMENDED**

- جميع KPI الإيرادات والأرباح وCOGS **صحيحة وموثوقة**.
- الخلل الوحيد المؤثر: توزيع طرق الدفع في شاشة BI يعرض أصفارًا (BI-F-01) — عرضي، لا فقد بيانات، لا أثر على أي KPI آخر.
- التطبيق **جاهز للاستمرار في التشغيل والإنتاج**؛ ويوصى بأخذ إصلاح BI-F-01 كمرحلة تالية فورية منخفضة الخطورة (5.1.1).

---

## 28. مصفوفة التحقق النهائية (Verification Matrix)

| البند | الحالة |
|---|---|
| Production Modified | **NO** |
| Tests Modified | **NO** |
| Database | **NO** |
| Schema | **NO** |
| Migrations | **NO** |
| CI | **NO** |
| Financial Calculator | **NO** (قراءة فقط) |
| Inventory Logic | **NO** |
| Commit | **YES** (ملف تقرير فقط) |
| Push | **YES** إلى `thikryat57-oss/hot-burger-last`/main |

---

## 29. ملخص النتائج للمالك (Owner Summary)

التطبيق سليم تحليليًا: الأرقام التي يراها المدير في التقارير اليومية والشهرية والوردية وP&L ولوحة الأعمال وأعلى المنتجات ربحية **صحيحة ومجمّدة عند لحظة البيع** حتى لو تغيّرت أسعار المخزون لاحقًا أو حُذفت منتجات. يوجد عيب واحد مرئي في شاشة "ذكاء الأعمال": نسبة الدفع نقدًا/بطاقة/تحويل تظهر **صفرًا دائمًا** — قيمها الحقيقية موجودة في قاعدة البيانات وتُحسب فعلًا، والخطأ في سطر الربط فقط. إصلاحه يستغرق دقائق ولا يمس أي شيء آخر. يُوصى بتنفيذ الإصلاح في المرحلة 5.1.1 وإرفاق اختبار يؤكد عدم تكرار العيب.

---

## 30. التذييل (Safety Footer)

**Production Modified = NO | Tests Modified = NO | Database = NO | Schema = NO | Migrations = NO | CI = NO | Financial Calculator = NO | Inventory Logic = NO | Commit = YES (report only) | Push = YES**

**FINAL VERDICT: SAFE — CONDITIONAL GO (BI-F-01 P2 fix recommended before any BI-dependent decision)**

> هذا تقرير READ-ONLY. لا ينفّذ أي إصلاح. لا يبدأ Phase 5.1.1 أو أي عمل لاحق دون توجيه صريح من المالك.

---

*من إعداد Manus AI — 20 أغسطس 2026 — HOT BURGER Phase 5.1.0*
