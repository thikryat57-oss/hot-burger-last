# HOT BURGER — Phase 3 Remaining Risks Reassessment

**نوع المهمة:** READ-ONLY Reassessment فقط — لا كود، لا اختبارات، لا schema، لا migrations، لا commits، لا push.
**تاريخ التنفيذ:** 19 أغسطس 2026 (Manus AI)
**المرجع الأساسي (Baseline):** `HOT_BURGER_PHASE0_BASELINE.md`
**حالة المستودع المفحوصة:** HEAD `8ca0dda` — `docs: Phase 2.3.1 migration v4 hardening final report`
**أداة التحقق:** فحص الكود المصدري في `lib/` و`test/` + سجلات GitHub Actions حتى Run `32230057100` (59/59 tests pass, analyze 0 errors).

---

## Executive Summary

أُعيد تقييم كل findings الأصلية الموثقة في Baseline Phase 0 مقابل الكود الحالي بعد إنجاز خمس مراحل إصلاح (Phase 1 → 2.3.1). النتيجة الإجمالية: **أربعة findings حُلّت بالكامل (C, D, K, Q)**، و**خامسة ما زالت مفتوحة بالكامل (E — Shift Detail Gap)**، و**اثنتان حُلّتا جزئيًا فقط (A — Async Pop Risk، I — Stock Audit Gap)**، و**ثلاث ما زالت قوية كما وثّقت (B, F, M)**.

المكسب الأكبر في هذه الدورة هو **السلامة المالية التاريخية**: طبقة `financial_calculator.dart` الموحدة حسمت Finding C (BI يتجاهل الخصم) وFinding D (التقرير اليومي يتجاهل COGS)، و`recipe_snapshot` حسم الفجوة التاريخية للمخزون التي اكتشفت في Phase 2.0 (تغيير الوصفة يفسد مرتجعات الفواتير القديمة)، وHardening الـ migration v4 حسم Finding K (CREATE TABLE بدون `IF NOT EXISTS`).

الخطر الأكثر أهمية **المتبقي وغير المُصلح** لم يأتِ من Baseline أصلًا، بل اكتُشف في هذه المراجعة: **المسار اليدوي لحذف المكوّنات من المخزون (`deleteIngredient`) يُنفَّذ بدون أي سجل تدقيق، والـ foreign key `ON DELETE CASCADE` على `product_ingredients` يمسح وصفات المنتجات المرتبطة تلقائيًا وصمتًا** — أي أن عملية تعديل مخزون بريئة ظاهريًا يمكن أن تشوّه تركيب المنتجات بلا عودة وبلا أثر. هذاfinding مصنّف P1 ومُصنَّف 🔴 URGENT على مستوى الفساد المحتمل (inventory corruption + unrecoverable state)، وهو المرشح رقم #1 للمرحلة التالية.

---

## Current Repository State

| البند | القيمة |
|---|---|
| Commit المفحوص | `8ca0dda` (HEAD = `main` = `origin/main`) |
| DB version | 16 (Migration v16: `recipe_snapshot` على `invoice_items`) |
| `flutter analyze` | 0 errors (أحدث Run `32230057100`) |
| الاختبارات | 59/59 PASS (0 failure, 0 skipped) — `financial_calculator_test`: 28، `recipe_snapshot_test`: 18، `db_integration_test`: 12، `cost_snapshot_test`: 1 (باقي suite قديمة) |
| APK Release | armv7a 9.1MB / arm64 9.3MB / x86_64 9.5MB (مرفوع على GitHub Actions) |
| ملفات معدّلة أثناء هذه المهمة | **صفر** — `git status` يعرض فقط ملف التقرير القديم غير الملتزم `HOT_BURGER_PHASE2_3_FAILURE_ANALYSIS.md` من مهمة سابقة |
| ملفات جديدة في `lib/` منذ Baseline | `lib/core/utils/financial_calculator.dart` (طبقة مالية موحدة — Phase 1) |
| ملفات اختبار جديدة منذ Baseline | `test/financial_calculator_test.dart`, `test/recipe_snapshot_test.dart`, `test/db_integration_test.dart`, `test/helpers/db_integration_helpers.dart` |

---

## Baseline Reference

المرجع المعتمد هو `HOT_BURGER_PHASE0_BASELINE.md` الموجود في جذر المستودع. **ملاحظة منهجية مهمة:** هذا الملف يوثّق فعليًا عشرة findings بعرف A–Q متقطعًا (A, B, C, D, E, F, I, K, M, Q) ولا يحتوي على Findings بالحروف G, H, J, L. التقرير لن يلفّق findings غير موجودة؛ الحروف الناقصة مُصرَّح بها أدناه، وإعادة التقييم تشمل كل ما هو موثق أصلًا.

---

## Finding A — Async Pop Risk (Navigator Pop Pattern)

**الوضع الأصلي:** Partial — حوارات تأكيد البيع كانت تُفتح بدون `useRootNavigator: true`، وأدت إلى خطإ النوع `Map<String, num>` → `Map<String, double>` وتجميد `Navigator` (Black Screen).

**الحالة الحالية:** **Partially Resolved (B)**. نواة مسار البيع محصّنة: حوار التأكيد في `sales_screen.dart` (النقطة المسببة للـ Black Screen) ومعه 7 حوارات أخرى في 8 ملفات تلقت نمط `useRootNavigator: true` + `WidgetsBinding.instance.addPostFrameCallback` ضمن Dialog Pattern Audit. اختبارات CI لا تكشف أي failure في هذا النمط.

**ما زال غير مغطى:** 30+ موقع `showDialog` في 14 شاشة إدارية (categories, expenses, inventory, products, recipe_management, purchases, shifts, suppliers, users, more, backup, invoices) لا تحوي `useRootNavigator` على سطر الدعوة نفسها. الخطر العملي فيها منخفض (ليست حوارات البيع الحيوية)، لكن عدم التوحيد يعني أن نفس علة النوع التي سببت الـ Black Screen يمكن نظريًا أن تتكرر في أي حوار إداري مستقبل.

**المراجع:** `lib/screens/sales/sales_screen.dart`، `lib/core/utils/pdf_helper.dart:467`، 14 ملف شاشة إدارية.

---

## Finding B — context.mounted Safety

**الوضع الأصلي:** Strong — استخدام واسع لـ `if (mounted)` بعد الفجوات غير المتزامنة.

**الحالة الحالية:** **Still Strong (A)**. تبيّن في هذه المراجعة أن `AppProvider` نفسه لا يحتوي على أي `mounted` check (0 occurrences) — وهذا ليس ضعفًا لأن Provider ليس widget ولا يحتاجه؛ النمط الصحيح فيه هو رمي الاستثناء ورفض العملية، وهو ما يطبَّق حرفيًا (مثل `throw Exception('هذه العملية متاحة للمدير فقط')`). الشاشات (`dashboard_screen`, `inventory_screen`, وغيرهما) تستخدم `mounted` قبل `setState` بعد الفجوات غير المتزامنة. لا تدهور عن Baseline.

**المراجع:** `lib/providers/app_provider.dart`، `lib/screens/dashboard/dashboard_screen.dart`.

---

## Finding C — BI Profit Discrepancy (يتجاهل discount_amount)

**الوضع الأصلي:** High — تقارير الذكاء التجاري تتجاهل الخصم فيظهر الربح أعلى من الفعلي.

**الحالة الحالية:** **Resolved (A)**. `getDailyReport` (سطر 1066)، `getMonthlyReport` (1097)، و`getProfitAndLossSummary` (1177) في `app_provider.dart` تستدعي جميعها `summarizeInvoices()` ثم `aggregateSummary()` من `lib/core/utils/financial_calculator.dart`، حيث تُوزَّع قيمة الخصم على أسطر الفاتورة نسبةً إلى إيراد كل سطر، ويُحسب `netRevenue = gross − allocatedDiscount` بحارس clamp يمنع الخصم من تجاوز الإجمالي. الاختبار `financial_calculator_test.dart` (28 اختبارًا) يثبت ذلك في CI.

**المراجع:** `lib/providers/app_provider.dart:1080-1081, 1113-1114, 1192-1193, 1368-1370`؛ `lib/core/utils/financial_calculator.dart`.

---

## Finding D — Daily Report Profit (يتجاهل COGS)

**الوضع الأصلي:** High — التقرير اليومي يتجاهل تكلفة البضاعة المباعة فيُبالغ الربح بشدة.

**الحالة الحالية:** **Resolved (A)**. `getProfitAndLossSummary` و`getDailyReport` يحسبان COGS من `cost_snapshot` المجمّد عند وقت البيع (وليس التكلفة الحالية)، مع fallback موثق للفواتير القديمة ذات `cost_snapshot = 0` عبر قراءة الوصفة الحالية (تُقبل كحدود معروفة للبيانات القديمة). الصيغة النهائية: `grossProfit = netRevenue − cogs` ثم `netProfit = grossProfit − expenses`. لا مبالغة في الربح بعد الآن.

**المراجع:** `lib/providers/app_provider.dart:1204-1230` (COGS query)، `HOT_BURGER_PHASE1_FINANCIAL_INTEGRITY_REPORT.md`.

---

## Finding E — Shift Detail Gap

**الوضع الأصلي:** Medium — تقارير الورديات تفتقر لمقاييس الربح/COGS.

**الحالة الحالية:** **Still Open (C) — لم يُمس**. `getShiftSummary` (سطر 1131) لا يزال يستخرج فقط `totalSales` (إجمالي gross من `total_amount`) وتوزيع النقدية/البنك/البطاقة وعدد الفواتير. لا خصم، لا COGS، لا ربح، ولا استخدام لطبقة `financial_calculator.dart` إطلاقًا. أي مقارَنة وردية بوردية تعتمد اليوم على أرقام gross مضللة في الأيام التي تكثر فيها الخصومات أو ترتفع فيها تكاليف المكوّنات. `getCurrentShiftCashSummary` (سطر 160) كذلك نقدي فقط.

**المراجع:** `lib/providers/app_provider.dart:1131-1168`.

---

## Finding F — Access Control

**الوضع الأصلي:** Strong — فحوصات `isManager` للأدوار.

**الحالة الحالية:** **Still Strong (A)**. الدوال الحساسة في `AppProvider` ترمي استثناء صريحًا لغير المدير: `addUser`, `updateUser`, `deleteUser`, `deleteCustomer` (سطر 504: 'حذف العملاء متاح للمدير فقط')، والوصول عبر `canManageCatalog() / canManageFinance() / canManageUsers() / canVoidInvoice()`. عرض سجل التحويلات المالي مقيد بالمرشّح `isManager ? null : 'user_id = ?'`. الحماية على مستوى Provider (مستوى واحد من التطبيق)، وهو مقبول لنموذج جهاز واحد؛ تبقى ملاحظة عامة أن SQLite نفسه غير مشفر وأن من يملك الجهاز يملك البيانات (انظر R-10).

**المراجع:** `lib/providers/app_provider.dart:80-120, 504`.

---

## Finding I — Stock Audit Gap

**الوضع الأصلي:** Medium — التعديلات اليدوية للمخزون عبر `updateIngredient` تتجاوز سجل التدقيق.

**الحالة الحالية:** **Partially Resolved (B)**. المسارات التشغيلية كلها مغطاة الآن: بيع (`createInvoice`)، مرتجع (`returnInvoice`)، إلغاء (`voidInvoice`)، شراء (`insertPurchaseInvoice`)، وتعديل يدوي للكمية (`updateIngredientQuantity`) — كلها تكتب في `inventory_audit_log` داخل transaction، واختبارات Phase 2.3 تراقب ذلك (12 اختبارًا). **لكن** `updateIngredient` (سطر 714) ما زال `db.update` خامًا بدون أي سجل تدقيق، و`deleteIngredient` (سطر 720) حذف كامل بدون تدقيق — وكلاهما مُتاح في `inventory_screen.dart` (السطران 358 و451). والأخطر: حذف المكوّن يفعّل `ON DELETE CASCADE` فيجدول `product_ingredients` فيمسح توصيلات الوصفات صمتًا (انظر R-01).

**المراجع:** `lib/core/database/database_helper.dart:714-723, 728+`؛ `lib/screens/inventory/inventory_screen.dart:358, 451, 684`.

---

## Finding K — Migration Safety

**الوضع الأصلي:** Medium — migration v4 يستخدم `CREATE TABLE` مباشر بدون `IF NOT EXISTS`.

**الحالة الحالية:** **Resolved (A)**. تم الإصلاح في Phase 2.3.1 (commit `c7777b9`): `CREATE TABLE IF NOT EXISTS` لأربع جداول داخل `_createVersion4Tables()` (`suppliers, purchase_invoices, purchase_items, supplier_payments`). الفحص الحالي يؤكد أن جميع خطوات السلم من v2 حتى v15 محمية بـ `IF NOT EXISTS`، وأن اختبار `Group A — v1 -> v16 identical full schema` يثبت اكتمال السلم من جهاز v1 نظيف إلى v16 في CI (Run `32230057100`). ملاحظة تقبلت كقيود تصميمية: `_onCreate` ينشئ جداول v1 بدون حماية (لا يتكرر أبدًا على أجهزة جديدة)، و`ALTER TABLE ADD COLUMN` في السلم غير idempotent يدويًا لكن السلم لا يُعاد تشغيله على نفس الإصدار في SQLite (مقبول).

**المراجع:** `lib/core/database/database_helper.dart:225-284`، `HOT_BURGER_PHASE2_3_1_MIGRATION_V4_HARDENING_REPORT.md`.

---

## Finding M — Rebuild Safety

**الوضع الأصلي:** Strong — `context.select` في `HomeScreen` و`activeListenable` في `Dashboard`.

**الحالة الحالية:** **Still Strong (A)**. `home_screen.dart:56` ما يزال يستخدم `context.select<AppProvider, int>` لمنع إعادة بناء جميع الشاشات، ونمط `activeListenable` للتحميل عند تفعيل التبويب مطبّق على `dashboard_screen` و`invoices_screen` وغيرهما. لا Regression مكتشف في هذه المراجعة.

**المراجع:** `lib/screens/home/home_screen.dart:56`.

---

## Finding Q — N+1 Queries

**الوضع الأصلي:** Fixed — `calculateProductCost` أصبح JOIN.

**الحالة الحالية:** **Resolved (A)** — لم يُرصد أي نكوص. المسارات التي استُبدلت بـ JOIN/RAW تبقى على حالها.

---

## Findings G, H, J, L

**غير موجودة في Baseline.** ملف `HOT_BURGER_PHASE0_BASELINE.md` يوثّق عشرة findings فقط بأحرف متقطعة (A, B, C, D, E, F, I, K, M, Q) ولا يحتوي على أي محتوى بالحروف G, H, J, L. إعمالًا لقاعدة "لا تدعي دقة تاريخية غير موجودة"، تُترك هذه الأحرف فارغة عمداً ولا تُلفَّق لها findings.

---

## Financial Integrity Reassessment

الوضع المالي الآن **قوي بدرجة عالية**. الخصم موزّع نسبيًا على الأسطر ويُخصم من الإيراد الصافي في كل التقارير (C, D محسومتان)، والربح يُحسب من COGS تاريخي مجمّد (`cost_snapshot` + `recipe_snapshot`) فلا يتغير بأثر رجعي عند تغيير أسعار المكوّنات أو الوصفات، و`effectiveDiscount` محصور بـ clamp بين 0 والإجمالي مع حراس NaN/Infinity. فواتير المرتجعة والملغاة تُستبعد كليًا من كل مقاييس الإيراد والربح (status NOT IN)، مع عكس نقاط الولاء في المرتجعات داخل transaction. **الحدود المتبقية:** الفواتير القديمة قبل v16 ذات `cost_snapshot = 0` تعتمد على fallback الوصفة الحالية (غير تاريخي — موثق ولا يُصلح)، ولا يوجد سطر منفصل "مبالغ مرتجعة" في P&L (المبالغ المستردة تستبعد كليًا بدل أن تظهر كخصم معروض)، و`getShiftSummary` gross-only (E).

---

## Inventory Integrity Reassessment

**الإنجاز المركزي:** فساد المخزون التاريخي المكتشف في Phase 2.0 (تغيير الوصفة يفسد مخزون مرتجعات الفواتير القديمة) **مغلق** عبر `recipe_snapshot` المحفوظ عند البيع واستعادته عند المرتجع/الإلغاء، مع سياسة Legacy Fallback موثقة وصريحة (`LEGACY_FALLBACK`). المسارات الخمسة (بيع، مرتجع، إلغاء، شراء، تعديل يدوي كمي) تكتب كلها في `inventory_audit_log` ذريًا داخل transaction. **الفجوة المتبقية الجوهرية:** الحذف اليدوي للمكوّن (`deleteIngredient` + `ON DELETE CASCADE`) لا يدوَّن في أي سجل ولا يمنع تشوه الوصفات — هذا أعلى خطر مفتوح في المشروع (R-01).

---

## Database & Migration Reassessment

السلم v1→v16 متكامل ومحكم (`IF NOT EXISTS` في كل خطوات ladder)، والـ DB version الحالية 16. Index على `ingredient_id` في `product_ingredients` موجود منذ Phase 0-era optimizations. لا schema جديد أُضيف في هذه المهمة. **ملاحظة تقنية تقبلت:** ADD COLUMN في السلم غير idempotent على إعادة تشغيل يدوية غير موجودة عمليًا.

---

## Transaction Integrity Reassessment

كل عمليات الكتابة المتعددة الجداول مغلفة في transaction: `createInvoice` (فواتير + أصناف + مخزون + تدقيق + ولاء)، `returnInvoice`، `voidInvoice`، `insertPurchaseInvoice` (فاتورة + أصناف + متوسط مرجح + رصيد مورد)، `insertSupplierPayment` (دفعة + خصم رصيد)، `updateIngredientQuantity`. **الاستثناء الوحيد:** `updateIngredient` و`deleteIngredient` (المسار اليدوي للإدارة) ينفذان خارج transaction وتدقيق.

---

## Audit Integrity Reassessment

`inventory_audit_log` يغطي الآن كل حركة كمية تشغيلية. **الثغرات المتبقية:** (1) التعديل اليدوي للمكوّنات بدون audit (I/R-09)، (2) حذف المكوّنات بدون audit + تشوه CASCADE للوصفات (R-01)، (3) دفعات الموردين `insertSupplierPayment` لا تُسجل في أي سجل تدقيق (R-04)، (4) `invoice_audit_log` موجود للفواتير لكن تعديل/حذف الفواتير بعد الحفظ غير متاح أصلًا (لا `updateInvoice` في الكود — مقبول).

---

## Security Reassessment

كلمات المرور SHA-256 مع salt + تكرار 1000 مرة، مع ترقية تلقائية للهاشات القديمة عند تسجيل الدخول. الأدوار (`manager`/`cashier`) مفروضة في Provider على كل العمليات الحساسة. **القيود المتبقية:** قاعدة SQLite غير مشفرة (R-10)، ولا يوجد OAuth/سحابة أصلًا (ما ذُكر في Phase 0 عن Google Drive لم يكن موجودًا في الكود — النسخ الاحتياطي محلي فقط، R-03).

---

## Backup & Recovery Reassessment

`BackupHelper` ناضج محليًا: تصدير بنقطة WAL checkpoint + تحقق من توقيع SQLite + مشاركة، واستيراد بعكس rollback (`before_restore`) وإعادة فتح فورية لإظهار أخطاء schema فورًا. **الغياب الجوهري:** لا جدول auto-backup ولا نسخة خارجية/سحابية — كل البيانات تعيش على جهاز واحد؛ فقدان أو عطل الجهاز يعني فقدان البيانات رغم وجود آلية يدوية سليمة (R-03).

---

## Legacy Data Reassessment

الفواتير قبل v16 (قبل `recipe_snapshot`) تُعالج بسياسة `LEGACY_FALLBACK` صريحة: استعادة المخزون من الوصفة الحالية + صف audit موثق بـ `note='LEGACY_FALLBACK'` — موثق بوضوح ولا يُدّعى له دقة تاريخية. التكاليف القديمة (`cost_snapshot = 0`) في P&L تُحل بالفallback نفسه (غير تاريخي — مقبول وموثق). البيانات القديمة قبل v4 محمية الآن بـ `IF NOT EXISTS` على السلم بالكامل.

---

## Test Coverage Reassessment

59/59 تمر في CI، موزعة على أربعة ملفات. **المثبت فعليًا:** الطبقة المالية (28)، codec الـ snapshot (18)، والسلم v1→v16 + بيع + مرتجع + إلغاء + guards + atomicity + legacy fallback + duplicate productId + bad totals + insufficient stock (12). **ما زال غير مختبر:** إنتاج DB فعلي (لا اختبار على production database حقيقية — اختبارات FFI محاكاة)، مسارات شاشات UI، backup/export/import، دفعات الموردين audit، delete/update يدوي للمخزون (لا يوجد اختبار يراقب absence of audit لأن السلوك غير موجود أصلًا)، shift summary مع COGS (E)، وvoid-after-return inconsistency. عدد الاختبارات ليس مؤشر جودة وحده، وهذا التقييم يفرّق بين "مختبر" و"مثبت في الإنتاج".

---

## Newly Discovered Risks

| ID | الوصف | الدليل | التأثير | الاحتمال | الكشف | الشدة | المرحلة الموصى بها | الاستعجال |
|---|---|---|---|---|---|---|---|---|
| R-01 | حذف مكوّن يدوي بدون audit + CASCADE صامت يمسح روابط الوصفات لكل المنتجات المتأثرة | `database_helper.dart:720-723`؛ FK lines 119/266/310 `ON DELETE CASCADE`؛ `inventory_screen.dart:451` | inventory corruption + unrecoverable recipe loss | Medium (يحتاج قرار حذف يدويًا) | Low (صامت، لا تنبيه) | **P1** | Phase 4 | 🔴 URGENT |
| R-02 | عدم اتساق API بين `voidInvoice` (returns 0 صامتًا للـ returned) و`returnInvoice` (throws Exception للـ cancelled) — callers قد يسيئون تفسير الصمت كنجاح | `app_provider.dart:762-827` | silent no-op يُخلط بنجاح العملية | Medium | Medium | **P2** | Phase 4 | 🟡 LOW |
| R-03 | لا auto-backup ولا نسخة خارجية؛ كل البيانات على جهاز واحد | `lib/core/utils/backup_helper.dart` محلي فقط؛ لا `google_sign_in` في pubspec/lib | data loss غير قابل للاسترداد عند فقدان الجهاز | Medium | Medium | **P1** | Phase 4 أو خارطة طريق | 🟠 MEDIUM |
| R-04 | `insertSupplierPayment` داخل transaction لكن بدون أي سجل تدقيق لدفعات الموردين | `database_helper.dart:1127-1142` | financial audit gap | Medium | Medium | **P2** | Phase 4 | 🟡 LOW |
| R-05 | `getShiftSummary` gross-only — لا خصم/COGS/ربح | `app_provider.dart:1131-1168` | تقارير وردية مضللة عند كثرة الخصومات | Medium | High | **P2** | Phase 4 (سهل: إعادة استخدام layer) | 🟠 MEDIUM |
| R-06 | Legacy cost fallback غير تاريخي (`cost_snapshot = 0`) | P&L query fallback في 1204-1230 | دقة هامشية للتقارير القديمة | Low | High | **P3** | لا يُصلح (موثق) | 🟡 LOW |
| R-07 | 30+ `showDialog` إداري بدون `useRootNavigator` | grep lib (33 موقعًا بلا السطر؛ 24 useRootNavigator) | تكرار محتمل لعلّة Black Screen في شاشات إدارة | Low | Medium | **P3** | Phase 5 (توحيد) | 🟡 LOW |
| R-08 | المبالغ المرتجعة لا تظهر كسطر منفصل في P&L (تُستبعد كليًا) | `status NOT IN ('cancelled','returned')` في كل queries المالية | شفافية محاسبية أقل | Low | High | **P3** | Phase 5 | 🟡 LOW |
| R-09 | `updateIngredient` يدوي بلا audit | `database_helper.dart:714-718`؛ `inventory_screen.dart:358` | inventory audit gap (امتداد I) | Medium | Medium | **P2** | Phase 4 (مع R-01) | 🟠 MEDIUM |
| R-10 | SQLite غير مشفّرة على الجهاز؛ من يملك الجهاز يملك البيانات | SQLite default | security breach عند سرقة الجهاز | Low | High | **P3** | خارطة طريق (SQLCipher) | 🟡 LOW |

---

## Master Findings Matrix

| ID | Original Finding | Original Severity | Current Status | Current Severity | Affected Area | Evidence | Previous Fix | Remaining Risk | Recommended Phase | Urgency |
|---|---|---|---|---|---|---|---|---|---|---|
| A | Async Pop Risk | Partial | Partially Resolved | Low | Dialogs (sales + admin) | sales_screen checkout fixed; 30+ admin dialogs unprotected | Dialog Pattern Audit (8 files) | تكرار محتمل لعلّة Black Screen في شاشات إدارة | 5 (Admin Dialog Unification) | 🟡 LOW |
| B | context.mounted Safety | Strong | Still Strong | Low | Provider/screens | 0 mounted in provider (by design); screens guard setState | — (no fix needed) | None | — | — |
| C | BI Profit Discrepancy | High | **Resolved** | Low | BI/daily/monthly/P&L reports | summarizeInvoices + aggregateSummary | Phase 1 financial_calculator | None (legacy fallback موثق) | — | — |
| D | Daily Report Profit (COGS) | High | **Resolved** | Low | Daily/monthly/P&L | COGS from frozen cost_snapshot + fallback | Phase 1 + Phase 2.1 snapshot | Legacy cost accuracy (R-06) | — | — |
| E | Shift Detail Gap | Medium | **Still Open** | Medium | Shifts | getShiftSummary gross-only | — (لم يُمس) | تقارير وردية مضللة | **4** | 🟠 MEDIUM |
| F | Access Control | Strong | Still Strong | Low | Users/customers/finance | isManager throws في 6+ دوال | — (no fix needed) | مستوى Provider فقط (لا DB-level) | خارطة طريق | — |
| G | — | — | — | — | غير موثق في Baseline | — | — | — | — | — |
| H | — | — | — | — | غير موثق في Baseline | — | — | — | — | — |
| I | Stock Audit Gap | Medium | Partially Resolved | **Medium-High** | Manual inventory edits | Operational paths audited; updateIngredient/deleteIngredient خامان | Phase 2.3 updateIngredientQuantity | حذف يدوي يشوه الوصفات بلا أثر (R-01) | **4** | 🔴 URGENT |
| J | — | — | — | — | غير موثق في Baseline | — | — | — | — | — |
| K | Migration Safety | Medium | **Resolved** | Low | Migrations v1-v16 | ladder كله IF NOT EXISTS | Phase 2.3.1 c7777b9 | None | — | — |
| L | — | — | — | — | غير موثق في Baseline | — | — | — | — | — |
| M | Rebuild Safety | Strong | Still Strong | Low | Home/Dashboard rebuilds | context.select + activeListenable | Earlier rebuild fixes | None | — | — |
| Q | N+1 Queries | Fixed | Resolved | Low | calculateProductCost | JOIN path مستمر | Earlier optimization | None | — | — |
| R-01 | *(جديد)* حذف مكوّن صامت بلا audit | — | Open | **P1** | Inventory + recipes | CASCADE + raw delete | — (لم يُلمس في أي Phase) | inventory corruption + unrecoverable | **4** | 🔴 URGENT |
| R-02–R-10 | *(جديدة)* انظر جدول Newly Discovered Risks | — | Open | P2–P3 | انظر الجدول | انظر الجدول | — | انظر الجدول | 4–5/خارطة | 🟡–🟠 |

---

## Top 10 Remaining Risks

1. **R-01 — حذف المكوّنات الصامت بلا تدقيق + CASCADE يشوه الوصفات** (P1، 🔴): أعلى خطر فساد/فقدان غير قابل للاسترداد متبقٍ في النظام.
2. **R-03 — لا نسخ احتياطي تلقائي ولا خارجي** (P1، 🟠): فقدان الجهاز = فقدان كل البيانات؛ الآلية اليدوية سليمة لكنها تعتمد انضباط المستخدم.
3. **E / R-05 — Shift Summary بلا COGS أو خصم أو ربح** (P2، 🟠): فجوة مالية قابلة للقياس في مسار الورديات اليومي.
4. **I / R-09 — `updateIngredient` اليدوي بلا audit** (P2، 🟠): امتداد مباشر لفجوة التدقيق اليدوي، يُعالج مع R-01 في مسار واحد.
5. **R-02 — عدم اتساق silent-vs-throw بين void/returnInvoice** (P2، 🟡): caller قد يظن أن إلغاء فاتورة مرتجعة "نجح" بينما لم يحدث شيء.
6. **R-04 — دفعات الموردين بلا سجل تدقيق** (P2، 🟡): ledger سليم محاسبيًا لكن لا أثر قابل للتدقيق لكل دفعة.
7. **R-06 — Legacy cost fallback غير تاريخي** (P3، 🟡): دقة هامشية للتقارير القديمة؛ مقبول وموثق، لا يُصلح.
8. **A / R-07 — حوارات إدارية بلا useRootNavigator** (P3، 🟡): 30+ موقعًا؛ خطر علة Black Screen متكرر في شاشات إدارة.
9. **R-08 — لا سطر مرتجعات منفصل في P&L** (P3، 🟡): شفافية محاسبية.
10. **R-10 — SQLite غير مشفرة على الجهاز** (P3، 🟡): خطر security عند سرقة الجهاز؛ يتطلب SQLCipher.

---

## Top 3 Priorities

### #1 — R-01 + I/R-09: سد فجوة التدقيق للمسار اليدوي للمخزون (وحماية CASCADE)

**لماذا الآن؟** هو خطر الفساد/الفقدان غير القابل للاسترداد الوحيد المفتوح في كل النظام؛ كل مخاطر Baseline الأخرى صارت reporting/UI، وهذا الوحيد inventory corruption + unrecoverable state. **ما الذي قد يسوء؟** حذف مكوّن من شاشة المخزون يمسح توصيلات وصفات كل المنتجات المرتبطة صمتًا (CASCADE) — المنتجات تفقد مكوناتها بلا أثر ولا إنذار، ولا يمكن إعادة بناء الوصفات التاريخية. **المتأثر:** منتجات البيع، المطبخ، التقارير، وتاريخ التدقيق. **أصغر إصلاح آمن:** (1) إدخال `deleteIngredient` عبر transaction يسجل صف audit قبل الحذف، (2) منع الحذف إذا كان المكوّن مستخدمًا في وصفات إلا بعد تأكيد صريح يعرض قائمة المنتجات المتأثرة، (3) audit لـ `updateIngredient` أيضًا. **قابل للاختبار؟** نعم — اختبارات FFI جديدة لمراقبة audit rows عند الحذف/التعديل اليدوي + منع التشوه. **التعقيد التقديري:** MEDIUM.

### #2 — R-03: استمرارية النسخ الاحتياطي (auto-backup + external copy)

**لماذا الآن؟** كل البيانات المالية والتشغيلية على جهاز واحد؛ نجاح كل المراحل المالية السابقة يفقده جهاز واحد فاشل. **ما الذي قد يسوء؟** عطل/فقدان الجهاز يعيد العمل للصفر حتى مع آلية الاستيراد السليمة. **المتأثر:** استمرارية النشاط بالكامل. **أصغر إصلاح آمن:** جدولة تصدير تلقائي (Periodic task) لملف `.db` إلى مجلد قابل للمشاركة + تذكير المستخدم للمشاركة/النقل، أو دمج Google Drive إذا فُعّل OAuth مستقبلًا. **قابل للاختبار؟** جزئيًا (آلية التصدير مجدولة). **التعقيد التقديري:** MEDIUM–HIGH (يتوقف على قرار التكامل السحابي).

### #3 — E / R-05: ترقية Shift Summary بالطبقة المالية الموحدة

**لماذا الآن؟** الورديات دورة عمل يومية، وأي قراءة وردية اليوم gross-only مضللة؛ والإصلاح يعيد استخدام طبقة مثبتة ومختبرة (28 اختبارًا) بدل كتابة منطق جديد. **ما الذي قد يسوء؟** مقارنة وردية بوردية بخصومات متغيرة تُظهر فروقًا يُفسَّر خطأً على أنها سرقة أو أخطاء صناديق. **المتأثر:** إدارة الوردية وصناديق الموظفين. **أصغر إصلاح آمن:** استدعاء `summarizeInvoices + aggregateSummary` داخل `getShiftSummary` بدل rawQuery الـ gross، وإضافة `cogs`, `discountTotal`, `netProfit` للنتيجة. **قابل للاختبار؟** نعم — Unit test جديد على getShiftSummary عبر test hook (نفس نمط Phase 2.3). **التعقيد التقديري:** LOW.

---

## Recommended Next Phase

**Phase 4 — Stock Audit Closure & Financial Reporting Completion**
**السبب الأساسي:** اختيار المرحلة التالية مبني على **مخاطر الإنتاج الحقيقية** لا على سهولة البرمجة أو رفع عدد الاختبارات: R-01 هو خطر الفساد الوحيد المفتوح (inventory corruption + unrecoverable) ويجب أن يسبق أي ميزة جديدة، يليه E/R-05 كمخاطر مالية قابلة للقياس وسهلة الإغلاق عبر طبقة مثبتة.

---

## Risks Not Yet Fixed

وفقًا لقاعدة "لا تصلح أي شيء حتى P0/P1"، **لم يُصلح أي شيء في هذه المهمة**. المخاطر المفتوحة المتبقية بعد هذا التقييم هي R-01 (P1)، R-03 (P1)، E/R-05 (P2)، I/R-09 (P2)، R-02 (P2)، R-04 (P2)، R-06 (P3 — موثق، لا يُصلح)، A/R-07 (P3)، R-08 (P3)، R-10 (P3).

---

## Files Inspected

| المسار | الغرض من الفحص |
|---|---|
| `HOT_BURGER_PHASE0_BASELINE.md` | المرجع الأساسي لـ Findings A–Q |
| `lib/core/database/database_helper.dart` | schema, migrations v1–v16, _createVersion4Tables, audit paths, CRUD يدوي |
| `lib/providers/app_provider.dart` | createInvoice/returnInvoice/voidInvoice guards, reports (daily/monthly/P&L/shift), role checks |
| `lib/core/utils/financial_calculator.dart` | طبقة التقارير المالية الموحدة |
| `lib/core/utils/backup_helper.dart` | export/import/rollback |
| `lib/screens/backup/backup_screen.dart` | UI الاحتياطي |
| `lib/screens/inventory/inventory_screen.dart` | مسارات التعديل/الحذف اليدوي |
| `lib/screens/sales/sales_screen.dart` | نمط showDialog/Navigator في مسار البيع |
| `lib/screens/home/home_screen.dart` | rebuild safety (context.select) |
| `pubspec.yaml` + `lib/` | التحقق من غياب OAuth/سحابة |
| `test/` (4 ملفات) | عداد الاختبارات وتوزيع التغطية |
| GitHub Actions Runs 32225438871→32230057100 | نتائج analyze/تست/APK عبر الدورة |

---

## Final Verdict

```
PHASE 3 STATUS

PASS — READ-ONLY REASSESSMENT COMPLETE

Files Modified = 0
Database Modified = NO
Schema Modified = NO
Migrations Modified = NO
Tests Added = NO
Tests Deleted = NO
Production Logic Modified = NO
Commit Created = NO
Push = NO

NEXT RECOMMENDED PHASE:

Phase 4 — Stock Audit Closure & Financial Reporting Completion

PRIMARY REASON:

R-01 (manual ingredient deletion silently cascades recipe corruption with no audit
trail) is the only open inventory-corruption risk in the system, and E/R-05 leaves
daily shift reporting financially misleading; both are production-risk-driven,
not feature-driven.
```
