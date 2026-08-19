# HOT BURGER — Phase 4.2.1 Test-Fix-Only Report

| حقل | قيمة |
|---|---|
| Phase | 4.2.1 — Shift Financial Disclosure: إكمال الإفصاح + Test-Fix-Only |
| Scope | Test files only (`test/db_integration_test.dart`) |
| Repo | `thikryat57-oss/hot-burger-last`، branch `main` |
| Final CI run | `32254208327` (commit `c1b4109`) — **90/90 tests passed, 0 errors, Release APK built** |
| Author | Manus AI |
| Date | 2026-08-19 |

---

## 1. Root Cause

بعد تنفيذ الإفصاح المالي لتقرير الوردية (إعادة استخدام `financial_calculator` داخل `getShiftSummary`) أُضيفت 14 اختبارًا تكامليًا جديدًا (مجموعة `Phase 4.2.1 - shift financial disclosure`). فشل أربعة منها في أول تشغيل CI (`32248864997`-era run `32252411608`)، والتحقيق.READ-ONLY السابق (تقرير `HOT_BURGER_PHASE4_2_1_FAILURE_INVESTIGATION.md`) صنّف الفشل **C — Fixture/Seed Test Bug**، وسببه الجذري مؤكد بالأدلة:

1. **TEST 2 وTEST 8** زرعتا كميات برجر (40 و10 وحدات) تستهلكان لحمًا (100 لكل برجر) يفوق المخزون المزروع (1000) — **بوابة المخزون في الإنتاج** (`app_provider.dart` سطر 620: "المادة الخام غير كافية") ترفض الفاتورة **قبل أي عملية مالية**، وهذا هو السلوك الصحيح الموثق.
2. **TEST 9 وTEST 14** مرّرتا خصمًا أكبر من الـsubtotal (999 و50 مقابل subtotal = 25) — **بوابة التحقق من المدخلات** (`app_provider.dart` سطر 561: "قيمة الخصم غير صالحة") ترفض هذا المدخل أيضًا. لا يجوز اختبار الحساب المالي بمدخل غير قانوني.

لم يكن هناك أي خلل في `getShiftSummary` أو `financial_calculator` أو أي منطق مالي.

## 2. Test 2 Fix — invoice with discount uses the centralized calculator semantics

**المشكلة:** fixture بيع 40 برجرًا يحتاج 4000 وحدة لحم مقابل 1000 مزروعة.

**الإصلاح (test-setup فقط):** بيع برجر واحد بسعر 2500.0 مع خصم 100.0 — كمية تستهلك 100 لحم (بحدود الـseed 1000) دون أن تلمس هدف الاختبار: إثبات أن ملخص الوردية يكشف gross/discount/net/COGS/gross-profit عبر الحساب المركزي.

| Metric | القيمة في الاختبار |
|---|---|
| grossSales | 2500.0 |
| discountTotal | 100.0 |
| totalSales | 2400.0 |
| cogs | 102.0 (2×1 خبز + 100×1 لحم) |
| grossProfit | 2400.0 − 102.0 |

**النتيجة:** ✅ PASS في run `32252967980`.

## 3. Test 8 Fix — repeated productId in one invoice keeps discount allocation correct

**المشكلة:** عنصرا برجر × 5 وحدات = 10 برجر تحتاج 1000 لحم بالضبط مع أي هامش — وكانت تُرفض (4000).

**الإصلاح (test-setup فقط):** كميتان 5 وحدات (مجموع 10 برجر = 1000 لحم بالضبط ضمن الـseed)، خصم 20.0 على subtotal 250.0 — الهدف يبقى إثبات صحة توزيع الخصم عند تكرار `productId` داخل فاتورة واحدة.

| Metric | القيمة في الاختبار |
|---|---|
| grossSales | 250.0 |
| discountTotal | 20.0 |
| totalSales | 230.0 |
| cogs | 10 × 102.0 = 1020.0 |

**النتيجة:** ✅ PASS في run `32252967980`.

## 4. Test 9 Fix — discount equal to gross cannot make net revenue negative

**المشكلة:** الخصم 999.0 > subtotal 25.0 — مدخل غير قانوني ترفضه بوابة التحقق في الإنتاج، وهو **سلوك إنتاجي صحيح لا يُغيَّر**.

**إعادة التصميم (فصل validation عن calculation كما طلب المستخدم):** الاختبار لم يعد يطلب من `createInvoice` قبول خصم غير قانوني؛ أصبح يمرر **الخصم الأقصى القانوني = الـsubtotal بالضبط** (25.0)، ويثبت أن صافي الإيرادات لا يصبح سالبًا حتى عند الحد الأقصى، وأن ملخص الوردية يعكس نفس القيم المخزنة:

| Metric | القيمة في الاختبار |
|---|---|
| grossSales | 25.0 |
| discountTotal | 25.0 |
| totalSales | 0.0 |
| cogs | 102.0 |
| grossProfit | −102.0 |

**النتيجة:** ✅ PASS في run `32252967980`.

## 5. Test 14 Fix — shift consumes the centralized calculator (no duplicate engine)

**المشكلة:** نفس مشكلة TEST 9 (خصم غير قانوني) داخل اختبار كان يثبت أن ملخص الوردية يستهلك `financial_calculator` نفسه (ولا يكرر الحساب بمحرك مستقل).

**إعادة التصميم:** الخصم = الـsubtotal = 25.0 (قانوني)، والإثبات صار أقوى وأدق من النسخة الأصلية: **clamp الخاصية المشتركة** (صافي الإيرادات ≥ 0 يُطبَّق داخل `createInvoice` عبر المسار المركزي قبل التخزين) يجب أن ينعكس في ملخص الوردية **دون أن يحتوي أي كود خاص بالوردية على هذا clamp** — فإذا كرر `getShiftSummary` الحساب بمحرك مستقل لانكسر هذا الاختبار عند أي تغيير في الحاسب المركزي.

| Metric | القيمة في الاختبار |
|---|---|
| grossSales | 25.0 |
| discountTotal | 25.0 |
| totalSales | 0.0 |
| cogs | 102.0 |
| grossProfit | −102.0 |

**النتيجة:** ✅ PASS في run `32252967980`.

## 6. Why Production Code Was Not Changed

- سلوك الإنتاج المُبلَّغ بالفشل (رفض الخصم الأكبر من الـsubtotal، ورفض البيع غير الكافي للمخزون، وعدم سلبية صافي الإيرادات) **سلوك إنتاجي صحيح وموثق** — تغييره كان سيُدخل ثغرة مالية حقيقية في نظام مبيعات.
- الأرقام المرفوضة في الاختبارات الأصلية **لا يمكن أن تظهر في الاستخدام الحقيقي للتطبيق** (واجهة "إتمام البيع" تفرض الخصم ≤ الإجمالي أصلًا)، لذا لا يوجد سيناريو إنتاجي يغطي الاختبار الأصلي أصلًا.
- `financial_calculator.dart` **لم تُلمس إطلاقًا** في هذه المرحلة — الإفصاح المالي للوردية هو مجرد **إعادة استخدام** `summarizeInvoices`/`aggregateSummary` داخل `getShiftSummary` (إضافة 44 سطرًا في commit سابق من Phase 4.2.1 قبل طلب الفحص).
- لم يتغير أي شيء في `createInvoice`/`returnInvoice`/`voidInvoice`/منطق المخزون/قاعدة البيانات/الـschema/الـmigrations/CI.

## 7. Test Results

| Run | Commit | Result |
|---|---|---|
| 32252411608 | `adc2a4c` | 88 tests passed, **4 failed** (TEST 2/8/9/14 — fixture/seed) |
| 32252967980 | `94c565f` | **88 tests passed**, 0 failed |
| 32253691836 | `4a84817` | 88 tests passed, 2 failed (TEST 15/16 — second open shift; أُصلحت فورًا) |
| 32254208327 | `c1b4109` | **90 tests passed**, 0 failed — **FINAL** |

التغطية النهائية: الـ74 اختبارًا السابقة (Phase 1 + 2.1 + cost_snapshot + Phase 4.1) + 16 اختبار Phase 4.2.1 (14 أصلية + TEST 15 وTEST 16 كاختباري validation مستقلين) = **90 اختبارًا**. لا اختبار حُذف ولا عُطّل ولا skip.

## 8. Analyze Results

`flutter analyze --no-fatal-infos --no-fatal-warnings`: **0 errors** في كل runs. 250 issues كلها info/warning موجودة مسبقًا (قبل Phase 4.2.1) في ملفات خارج نطاق هذه المرحلة، وworkflow يعتبرها غير مُفشلة.

## 9. Diff Audit

| فحص | نتيجة |
|---|---|
| `git diff c1b4109 -- lib/` | **فارغ (0 سطر)** — لا تغيير في Production منذ commit `94c565f` |
| commits الثلاثة الأخيرة | `94c565f`، `4a84817`، `c1b4109` — كلها عدّلت `test/db_integration_test.dart` فقط |
| `financial_calculator.dart` | **UNCHANGED** — commit diff منذ بداية Phase 4.2.1 لا يلمسها |
| schema/migrations | **UNCHANGED** — dbVersion = 16، لا CREATE/ALTER منذ Phase 2.1 |
| CI workflow | **UNCHANGED** — `.github/workflows/build_apk.yml` لم يتغير |
| Release APK | بُني بنجاح في run النهائي (27.4 MB) |

## 10. Final Verdict

> **PASS — TEST FIX ONLY**
>
> Production Code = UNCHANGED · financial_calculator.dart = UNCHANGED · Database = UNCHANGED · Schema = UNCHANGED · Migrations = UNCHANGED · CI = UNCHANGED · Existing 74 tests = PASS · New Phase 4.2.1 tests = PASS

**إثباتات:**
- 90/90 tests passed في CI run `32254208327` (0 ❌، 90 ✅).
- `flutter analyze`: 0 errors.
- `git diff c1b4109 -- lib/` فارغ تمامًا؛ آخر commits عدّلت ملف اختبار واحد فقط.
- هدف كل اختبار من الأربعة الفاشلة **بقي كما هو** (اختبار خصم صحيح، خصم موزع مع productId مكرر، عدم سلبية صافي الإيرادات، إثبات استهلاك الحاسب المركزي) مع إضافة TEST 15/16 كاختباري validation مستقلين صريحين (رفض الخصم غير القانوني، ورفض البيع غير الكافي للمخزون مع Zero Mutations) — فصل validation عن financial calculation كما طلب المستخدم.

**STOP** — لم يبدأ Phase 4.2.2 ولا Phase 4.3.
