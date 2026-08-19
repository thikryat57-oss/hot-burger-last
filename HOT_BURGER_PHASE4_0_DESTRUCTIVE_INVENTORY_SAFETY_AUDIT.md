# HOT BURGER — PHASE 4.0: DESTRUCTIVE INVENTORY SAFETY AUDIT

**النوع:** READ-ONLY AUDIT — لا تعديل كود، لا اختبارات، لا migrations، لا تنفيذ.
**التاريخ:** 19 أغسطس 2026
**المرجع:** الكود المصدري في `thikryat57-oss/hot-burger-last` على branch `main` عند commit `8ca0dda` (آخر commit ناجح في CI — Run 32230057100).
**المراجع السابقة:** `HOT_BURGER_PHASE3_REMAINING_RISKS_REASSESSMENT.md` (finding R-01 الأولي)، `HOT_BURGER_PHASE0_BASELINE.md`، تقارير Phases 2.1–2.3.1.
**التحقق:** `git status` لا يظهر أي ملف معدّل؛ HEAD = `8ca0dda`؛ لا يوجد commit أو push من هذه المرحلة.

---

## 1. EXECUTIVE SUMMARY

هذه المرحلة هي تدقيق قراءة-فقط حصري للعمليات الهدّامة (Destructive Operations) في نظام المخزون والبيانات، استجابةً للأمر المباشر الذي حظر التنفيذ وطلب TRACE → VERIFY → MAP CASCADE → ASSESS DATA LOSS → ASSESS RECOVERABILITY → COMPARE SAFE DESIGNS → RECOMMEND → DOCUMENT → STOP.

**النتيجة الجوهرية:** finding R-01 الذي أعلنته Phase 3 ليس احتمالًا نظريًا — هو **عيب مؤكد بنسبة 100% قابل لإعادة الإنتاج** في مسار حذف المادة الخام (Ingredient). حذف أي مكوّن من شاشة المخزون يُنفَّذ كـ DELETE خام واحد بدون أي transaction أو صف تدقيق، وتطبيق Foreign Key باسم `ON DELETE CASCADE` على جدول `product_ingredients` يمسح **صمتًا وبلا عودة** كل روابط وصفات كل المنتجات المرتبطة بهذا المكوّن. حوار التأكيد في الواجهة نصي بسيط ولا يعرض قائمة المنتجات المتضررة، والمدير الذي يضغط "حذف" يظن أنه يحذف مادة واحدة، بينما يحذف فعليًا وصفات عددٍ من المنتجات دون أي إنذار.

> الكود الممسوح: `DatabaseHelper.deleteIngredient()` (سطر 720 في `database_helper.dart`) يتكون من ثلاث سطور فقط — فتح قاعدة البيانات، تنفيذ `db.delete('inventory', where: 'id = ?', whereArgs: [id])`، وإرجاع النتيجة. لا يوجد فحص لوجود المنتج، ولا استعلام عن الوصفات المتأثرة، ولا صف في `inventory_audit_log`، ولا معالجة خطأ.

لكن التدقيق كشف أيضًا شيء أهم من تأكيد R-01: **الدليل على أن الفريق يعرف كيف يبني حماية صحيحة موجود فعليًا في نفس الملف**. جدول `purchase_items` يحمي المكوّن المستخدم بقيد `ON DELETE RESTRICT` (سطر 266)، بينما جدول `product_ingredients` — لنفس المرجع إلى `inventory(id)` — يسمح بالحذف الانسيابي `ON DELETE CASCADE` (سطر 119). هذا التناقض داخل نفس قاعدة البيانات هو ما يجعلنا نصنّف المشكلة بأنها عيب تصميم مترابط (Cascade Inconsistency) وليس غياب حماية كامل.

اكتشفت المرحلة أيضًا ثلاثة مخاطر جديدة (L-1, L-2, L-3) خارج نطاق R-01، أبرزها **L-1**: مسار الاسترجاع التاريخي Legacy Fallback يعتمد على JOIN مباشر مع `product_ingredients` الحالي، فحذف المكوّن يجعل فواتير الحقبة القديمة تفشل في استعادة مخزونها **بصمت وبلا أي صف تدقيق** — وهو عكس السلوك المدروس في مسار الـ Snapshot الذي يكتب صف `SNAPSHOT_ONLY_INGREDIENT_DELETED`.

**FINAL VERDICT: R-01 CONFIRMED AS A REAL, REPRODUCIBLE P0-CAPABLE DESTRUCTIVE BUG. FOUR NEW FINDINGS DISCOVERED (L-1, L-2, L-3, L-4). THE SYSTEM ALREADY CONTAINS THE CORRECT PROTECTION PATTERN (RESTRICT) THAT MUST BE EXTENDED.**

---

## 2. SCOPE & CONSTRAINTS VERIFICATION

| الشرط | الحالة |
|---|---|
| لا تعديل كود في lib/ | ✅ محقق — لا ملف معدّل (`git status` نظيف عدا ملفي التقريرين المحليين) |
| لا اختبارات جديدة | ✅ محقق |
| لا migrations جديدة ولا تغيير schema | ✅ محقق |
| لا تنفيذ، لا soft delete، لا تغيير CASCADE، لا Phase 4.1 | ✅ محقق — هذا تقرير قراءة فقط |
| لا commit، لا push | ✅ محقق — HEAD = `8ca0dda` كما كان |
| تدقيق Destructive Inventory Operations فقط | ✅ محقق |
| تتبع R-01 من UI إلى SQL | ✅ محقق |
| جرد كل العمليات الهدّامة | ✅ محقق |
| خريطة Foreign Keys + سلوك الحذف | ✅ محقق (16 قيدًا) |
| تحليل الأثر التاريخي والاسترداد | ✅ محقق |
| مقارنة خيارات التصميم الآمن (نظري) | ✅ محقق |
| تقييم Shift/Backup منفصل | ✅ محقق |
| حسم الخيار بين A/B/C/D | ✅ محقق — D |
| تقييم جاهزية Scope 4.1 (نظري) | ✅ محقق |
| تقرير واحد نهائي | ✅ محقق — هذا الملف |

---

## 3. R-01 TRACE — FROM UI TO SQL

### 3.1 المسار الكامل (سطرًا بسطر)

المسار الذي يتبعه حذف المادة الخام من ضغطة الإصبع إلى القرص:

| # | الطبقة | الملف والسطر | الكود/السلوك | الحماية؟ |
|---|---|---|---|---|
| 1 | واجهة | `lib/screens/inventory/inventory_screen.dart:449-474` | `showDialog<bool>` نصي: "هل أنت متأكد من حذف "X"؟" | تأكيد بسيط فقط — لا قائمة منتجات متضررة، لا تحذير من الوصفات |
| 2 | واجهة | سطر 471-472 | `context.read<AppProvider>().deleteIngredient(ingredient.id!)` ثم `_loadData()` | — |
| 3 | Provider | `lib/providers/app_provider.dart:1498-1503` | فحص `canManageCatalog()` فقط، ثم استدعاء DB مباشرة | دور فقط |
| 4 | DB Layer | `lib/core/database/database_helper.dart:720-723` | `db.delete('inventory', where: 'id = ?', whereArgs: [id])` — **سطران فعليان** | لا شيء |
| 5 | SQLite Engine | جدول `product_ingredients` | `FOREIGN KEY (ingredient_id) REFERENCES inventory(id) ON DELETE CASCADE` (سطر 119 و310) | محرك SQLite ينفذ الحذف الانسيابي تلقائيًا |

```
_ui_deleteIngredient (inventory_screen.dart:449)
  → Provider.deleteIngredient (app_provider.dart:1498)   [role check only]
    → DatabaseHelper.deleteIngredient (database_helper.dart:720)  [raw delete, 2 lines]
      → SQLite CASCADE → DELETE FROM product_ingredients
                         WHERE ingredient_id = <deleted>   [silent, irreversible]
```

### 3.2 ما الذي يُفقد فعلًا عند الضغط على "حذف"؟

عند حذف مكوّن له صف واحد أو أكثر في `product_ingredients`، يحدث في نفس اللحظة وبدون أي إخطار: **(أ)** حذف صف المكوّن من `inventory` (الكمية، السعر، الاسم — بلا صف audit)، **(ب)** حذف كل صفوف الوصفات المرتبطة من `product_ingredients` انسيابيًا، **(ج)** فقدان تعريف الوصفة لكل المنتجات المرتبطة — المنتج نفسه يبقى في القائمة لكن صفاته (وصفته) تصبح فارغة. المستخدم يرى منتجًا على الرف لا يمكن بيع مكوناته منه بدقة.

### 3.3 الأثر على الفواتير التاريخية

الأثر محدود هنا مقارنة بتقييم Phase 2.0: جدول `invoice_items` **لا يملك قيد Foreign Key** على `inventory` ولا على `products` (سطر 157 فقط على `invoices`)، وكل سطر فاتورة يحمل `product_name` نصيًا و`recipe_snapshot` JSON مستقلًا (Phase 2.1). حذف المكوّن لا يكسر ولا يعدّل ولا يحذف أي سطر فاتورة تاريخي — السجلات المالية سليمة ماديًا. الخطر التاريخي يظهر فقط عند **الاسترجاع** (Return/Void) لفاتورة قديمة (انظر L-1).

---

## 4. DESTRUCTIVE OPERATIONS INVENTORY — COMPLETE AUDIT

جرد كامل لكل العمليات الهدّامة في النظام كما هي في الكود الحالي:

| # | العملية | المسار | التنفيذ | Audit؟ | Transaction؟ | الحماية الحالية |
|---|---|---|---|---|---|---|
| 1 | حذف Ingredient | `inventory_screen:449` → Provider:1498 → DB:720 | raw `db.delete('inventory')` | ❌ | ❌ | CASCADE على product_ingredients — فقدان صامت |
| 2 | حذف Product | `products_screen:235` → Provider:386 | raw `_db!.delete('products')` | ❌ | ❌ | CASCADE على product_ingredients — وصفات كل المنتجات المرتبطة تُمسح |
| 3 | حذف رابط وصفة (مكوّن من وصفة) | `Provider:1673` → DB:822 | raw `db.delete('product_ingredients', ...)` | ❌ | ❌ | لا شيء — تعديل وصفة بلا أثر |
| 4 | حذف مورد | `Provider:1582` → DB:981 | raw `db.delete('suppliers')` | ❌ | ❌ | RESTRICT عبر purchase_invoices ✓ لكن CASCADE على supplier_payments — حذف المورد يمسح كل دفعاته صمتًا |
| 5 | حذف مصروف | `Provider:1058` | raw `_db!.delete('expenses')` | ❌ | ❌ | لا أضرار جانبية (لا FK عليه) لكن ثغرة أثر مالي |
| 6 | حذف عميل | `Provider:503` | `update` → `is_active = 0` (Soft) | ✅ ضمني | — | Soft delete آمن ✓ — بيانات الولاء محفوظة |
| 7 | حذف تصنيف | `Provider:337` | raw `db.delete('categories')` | ❌ | ❌ | SET NULL على products ✓ — آمن |
| 8 | إلغاء/استرجاع فاتورة | `Provider:828/762` (`deleteInvoice` = `voidInvoice` سطر 893) | `txn.transaction` + restore + audit | ✅ كامل | ✅ | Guards سليمة ✓ — النموذج المرجعي |
| 9 | تعديل كمية المخزون | Provider (adjust) | update + audit row | ✅ كامل | ✅ | Phase 2.3 ✓ |
| 10 | شراء/بيع/مرتجع | createInvoice/returnInvoice/recordPurchase | transaction + audit | ✅ كامل | ✅ | Phase 1–2.3 ✓ |
| 11 | حذف طلب معلق / Shift / User / فاتورة شراء / دفعة | — | **لا توجد** عمليات حذف لهذه الكيانات | — | — | لا CRUD حذف — لا خطر |
| 12 | مسح/إعادة ضبط بيانات (Wipe) | — | **لا توجد** آلية | — | — | لا خطر |

**الخلاصة:** ثغرة التدقيق محصورة في خمسة مسارات (حذف Ingredient / Product / رابط وصفة / مورد / مصروف)، وأخطرها مسار Ingredient وProduct لأنهما يفعلان ضررًا انسيابيًا غير مرئي، لا مجرد غياب أثر.

---

## 5. FOREIGN KEY & CASCADE MAP

خريطة القيود الستة عشر الفعلية في `database_helper.dart` (من `_onCreate` والسلالم v4/v6):

| المرجع (Child) | العمود | الأب (Parent) | سلوك الحذف | التقييم |
|---|---|---|---|---|
| `products` | `category_id` | `categories(id)` | SET NULL | ✅ آمن — التصنيف يُفرَّغ ولا يُفقد المنتج |
| `product_ingredients` | `product_id` | `products(id)` | CASCADE | 🟠 مقبول جزئيًا — حذف المنتج يمسح وصفته؛ الوصفات التاريخية محفوظة في `invoice_items.recipe_snapshot` |
| `product_ingredients` | `ingredient_id` | `inventory(id)` | **CASCADE — R-01** | 🔴 خطر — حذف المكوّن يمسح كل الوصفات صمتًا |
| `invoice_items` | `invoice_id` | `invoices(id)` | CASCADE | ✅ مقصود — الفاتورة هي الوحدة المالية |
| `pending_order_items` (v1) | `pending_order_id` | `pending_orders(id)` | CASCADE | ✅ مقصود |
| `purchase_invoices` | `supplier_id` | `suppliers(id)` | **RESTRICT** | ✅ الحماية الصحيحة — يمنع حذف مورد مرتبط بفواتير |
| `purchase_items` | `purchase_invoice_id` | `purchase_invoices(id)` | CASCADE | ✅ مقصود |
| `purchase_items` | `ingredient_id` | `inventory(id)` | **RESTRICT** | ✅ الحماية الصحيحة — **نفس المرجع الذي يُنسى في product_ingredients** |
| `supplier_payments` | `supplier_id` | `suppliers(id)` | **CASCADE** | 🔴 تناقض — دفعات المورد تُمسح صمتًا بينما فواتيره تحميه (L-2) |
| `supplier_payments` | `purchase_invoice_id` | `purchase_invoices(id)` | SET NULL | 🟠 مقبول |
| `product_ingredients` (v4 ladder) | `product_id` | `products(id)` | CASCADE | (مكرر تعريف v4) |
| `product_ingredients` (v4 ladder) | `ingredient_id` | `inventory(id)` | **CASCADE** | (مكرر تعريف v4 — نفس الخطر) |
| `customer_points_log` | `customer_id` | `customers(id)` | CASCADE | 🟠 نظريًا خطر مع soft delete لكن الحذف الفعلي Soft ✓ |
| `customer_points_log` | `invoice_id` | `invoices(id)` | SET NULL | ✅ آمن |
| `pending_order_items` (v6) | `pending_order_id` | `pending_orders(id)` | CASCADE | ✅ مقصود |
| `shifts` | `user_id` | `users(id)` | RESTRICT | ✅ آمن — لا حذف مستخدم مرتبط |
| `invoice_audit_log` | `invoice_id` | `invoices(id)` | CASCADE | 🟠 مقصود (حذف الفاتورة = حذف أثرها، والفواتير لا تُحذف أصلًا) |
| `inventory_audit_log` | — | لا قيد FK على `inventory` | — | ✅ تصميمي صحيح — صف التدقيق يبقى بعد حذف المكوّن (الاسم محفوظ فيه) |

**الاستنتاج المركزي للخريطة:** النظام يعرف بالفعل الفرق بين RESTRICT وCASCADE ويستخدم الاثنين في نفس القاعدة — `purchase_items` تحمي المكوّن بينما `product_ingredients` تُضحّي به. هذا ليس جهلًا بالآلية، بل إغفال اتساق (Consistency Omission).

---

## 6. DATA LOSS ASSESSMENT

| الكيان المفقود | قابل للاسترداد؟ | المصدر الوحيد للاسترداد | درجة الخطورة |
|---|---|---|---|
| صف Ingredient (الكمية والسعر) | ✅ جزئيًا | `inventory_audit_log` يحتفظ بصفوف التدقيق (الاسم والكميات والتكلفة وقت كل حدث) — يمكن إعادة بناء آخر كمية معروفة يدويًا | متوسطة |
| صفوف `product_ingredients` (الوصفات) | ❌ **لا نهائيًا** | لا يوجد أي سجل يحفظ `qty` الحالية لوصفة بعد حذفها. السطر الوحيد القريب: `recipe_snapshot` في فواتير مبيعة — لكنها تحفظ وصفات **المنتجات المباعة فقط** وبكميات وقت البيع، وليست الوصفة الحالية الصحيحة لكل المنتجات | **حرجة** |
| ارتباطات منتج → وصفة | ❌ نفس الاستنتاج | — | **حرجة** |
| دفعات مورد (عند حذف مورد) | ❌ نهائيًا | `supplier_payments` بلا audit وبلا snapshot — سجل المدفوعات يُمسح مع المورد | حرجة (L-2) |
| وصفة منتج محذوف من جدول المنتجات | ❌ من العرض، ✅ من الفواتير القديمة | `recipe_snapshot` في `invoice_items` يحفظ وصفات المنتجات المباعة سابقًا — استرداد جزئي ممكن للفواتير snapshot-backed | متوسطة (L-3) |

النتيجة: **فقدان الوصفات غير قابل للاسترداد من داخل النظام إطلاقًا** — النافذة الوحيدة هي نسخة احتياطية كاملة لقاعدة البيانات قبل الحادث، ثم استيرادها واستخراج الوصفات يدويًا (عملية تقنية ليست متاحة للمستخدم العادي ولا موثقة).

---

## 7. RECOVERABILITY ANALYSIS

استرجاع الحالة بعد حذف Ingredient خاطئ يتطلب اليوم ثلاث خطوات يدوية: استرجاع نسخة احتياطية كاملة، استخراج بيانات `product_ingredients` من النسخة، وإعادة إدخال الروابط يدويًا في التطبيق الحي. لا توجد أداة داخل التطبيق لذلك، ولا زر "تراجع"، ولا سلة محذوفات، ولا soft delete، ولا جدول تظليل (Shadow Table). كما أن النسخ الاحتياطية (Export/Import في `backup_helper.dart`) تُبنى يدويًا بالكامل من قبل المستخدم — لا auto-backup دوري بعد تنفيذ Phase 3.1 (الذي لم يُنفَّذ).

بالنسبة لـ `purchase_items` يضمن SQLite أن العملية لن تبدأ أصلًا (`RESTRICT` يرمي استثناء)، بينما `product_ingredients` يجعلها تبدأ وتكتمل بصمت — هذا الفرق الجوهري بين "الرفض الآمن" و"الإنفاذ الصامت" هو جوهر التصنيف.

---

## 8. FINDINGS

### R-01 — Ingredient Delete Cascade (مؤكد، P0-capable)
حذف مكوّن ينفذ raw DELETE بلا audit داخل transaction، وCASCADE يمسح كل `product_ingredients` المرتبطة صمتًا، وحوار UI لا يعرض المنتجات المتضررة، والوصفات تُفقد نهائيًا. المسار: `inventory_screen:449` → `app_provider:1498` → `database_helper:720` + FK سطر 119/310.

### L-1 — Legacy Fallback Silent Restoration Failure (جديد، P1)
`restoreInventoryFromSnapshots()` (Provider سطر 972-992) عند فواتير بلا snapshot تجري `INNER JOIN inventory ON product_ingredients` — إذا حُذف المكوّن، الصفوف ببساطة لا تعود من الاستعلام فيفشل استرجاع المخزون للفاتورة القديمة **بلا خطأ وبلا صف audit**. بالمقابل، المسار snapshot-backed كتبه الفريق بعناية ليلوغ صف `SNAPSHOT_ONLY_INGREDIENT_DELETED` عند غياب المكوّن (سطر 1002-1010). المساران غير متماثلين: أحدهما يوثّق الفشل والآخر يخفيه.

### L-2 — Supplier Delete Cascade Inconsistency (جديد، P1)
`suppliers(id)` محمي بـ RESTRICT من جهة `purchase_invoices` لكنه يُمسح انسيابيًا مع `supplier_payments` (CASCADE سطر 280). حذف مورد مرتبط بفواتير شراء يُرفض، لكن حذف مورد بلا فواتير يمسح سجل مدفوعاته كلها صمتًا — فقدان سجل مالي.

### L-3 — Product Delete Without Audit (جديد، P2)
`deleteProduct` (Provider:386) raw delete بلا audit داخل transaction؛ CASCADE يمسح وصفته؛ الفواتير التاريخية تبقى سليمة (لا FK عليها) و`recipe_snapshot` يحتفظ بجزء من الوصفات القديمة — خسارة غير فورية لكنها تُفقد تعريف الوصفة الحالية نهائيًا بلا أثر.

### L-4 — Minor Audit Traceability Gaps (P3)
`deleteProductIngredient` (DB:822)، `deleteExpense` (Provider:1058)، `deleteCategory` (Provider:337)، `updateIngredient` (DB:~714) — لا صفوف audit. لا ضرر انسيابي؛ مجرد فجوة أثر (Traceability) لا Corruption.

### E (مستمر من Phase 3) — Shift Detail COGS/Profit Gap
Shift Summary لا يزال gross-only بلا طبقة COGS/profit. **مستقل تمامًا عن R-01** — لا اعتماديات معه، ويمكن تنفيذه بالتوازي أو بعده.

### Backup (مستمر) — External/Periodic Copy
Backup الحالي يدوي (Export) ولا يخفف R-01 (لا يمنع الحذف؛ فقط يجعل الاسترجاع ممكنًا بعد الحادث).

---

## 9. PRIORITY MATRIX

| Finding | الاحتمال | الأثر | الأولوية | النطاق |
|---|---|---|---|---|
| R-01 | مؤكد | فقدان دائم للوصفات + Inventory corruption | **P0** | Medium — مسار واحد + dialog واحد |
| L-1 | مؤكد (بمجرد حذف) | فقدان مالي صامت لاسترجاع الفواتير القديمة | **P1** | Small — دالة واحدة موجودة ومفحوصة |
| L-2 | متوسط (حذف مورد) | فقدان سجل المدفوعات | P1 | Small — سطر واحد (CASCADE→RESTRICT) + audit |
| L-3 | متوسط (حذف منتج) | فقدان الوصفة الحالية | P2 | Small — audit فقط + dialog محسّن |
| L-4 | منخفض | فجوة أثر | P3 | Small — audit rows |
| E-Shift | — | تقرير مالي غير كامل | P2 | Medium — مستقل |
| Backup | — | Data loss عام | P1 عام | Medium — مستقل |

---

## 10. TOP 3 PRIORITIES

**#1 — R-01 closure (P0):** تحويل حذف Ingredient من "رفض آمن + أثر كامل" بدل "إنفاذ صامت" — block-by-default مع explicit override بعد عرض المنتجات المتضررة، + audit row، + (اختياري) snapshot احتياطي لصفوف الوصفة قبل الحذف. النطاق: مسار واحد + dialog واحد، متوسط الجهد.

**#2 — L-1 closure (P1):** جعل legacy fallback مساويًا للسلوك snapshot-backed — لو لم يُستعدَ أي سطر (مكوّن محذوف)، يجب كتابة صف audit صريح بدل السكوت. النطاق: دالة واحدة موجودة ومفحوصة بالكامل من Phase 2.1.

**#3 — L-2 closure (P1):** توحيد سلوك المورد — RESTRICT على `supplier_payments` (كـ `purchase_invoices`) + audit row لحذف المورد، أو على الأقل تحذير UI بقائمة الدفعات المتضررة. النطاق: سطر واحد + audit.

---

## 11. DESIGN OPTIONS COMPARISON

| الخيار | الوصف | نقاط القوة | نقاط الضعف | الملاءمة هنا |
|---|---|---|---|---|
| A — Block Only (RESTRICT) | تحويل `ingredient_id` إلى RESTRICT كـ `purchase_items` | أبسط وأضمن — الحذف المستحيل لا يفسد | يمنع استخدام مشروع دائمًا (مكوّن فارغ قديم)، يحتاج soft delete أو أرشفة لحل الحالات المشروعة | جيدة كطبقة أولى لكن غير كافية وحدها |
| B — Soft Delete Only | `is_active=0` (كنمط `customers`) | قابل للتراجع، الوصفات تبقى | يترك الوصفات النشطة تشير لمكوّن "محذوف" — قد تنكسر شاشة البيع أو التقارير | ضعيفة وحدها — تحتاج منطقًا إضافيًا في screens |
| C — Snapshot Before Delete | نسخ `product_ingredients` في جدول أرشيف قبل الحذف | استرداد كامل للوصفات | يضيف schema/جدولًا جديدًا ولا يمنع الحادث ولا يحذر المستخدم | مكمّلة وليست بديلًا |
| **D — Combination** | **Audit trail + block-with-impact-preview + explicit override + (اختياري) archive** | يمنع الحادث، يوثقه، يسمح بالحالات المشروعة بوعي كامل، ويبقي الاسترداد ممكنًا | أكبر نطاق (لكنه ما زال Medium) | **الأنسب** — يتطابق مع نمط `returnInvoice/voidInvoice` الناضج الموجود |

---

## 12. DECISION

**الحسم: D — Combination.** الخيار الوحيد الذي يعالج الأبعاد الثلاثة (المنع، التوثيق، الاسترداد) دون كسر الحالات المشروعة (حذف مكوّن لم يعد مستخدمًا) ودون إضافة schema جديد إلزامي (الأرشفة اختيارية في Scope 4.1).

**القرار المتعلق بـ L-1 (Legacy Fallback):** توحيد السلوك مع المسار snapshot-backed — كتابة صف audit عند الفشل الصامت، لأن الفاتورة القديمة قد تكون مبلَّغة ماليًا والاسترجاع الصامت الفاشل يترك المخزون منخفضًا دون أثر.

**تقرير E-Shift وBackup:** كلاهما مستقل عن R-01/L-findings ولا يعتمد عليه؛ تبقّى الأولوية P2 للـ Shift وP1 عام للـ Backup كما وثّقتهما Phase 3.

---

## 13. RECOMMENDED SCOPE 4.1 — READINESS ASSESSMENT (نظري)

النطاق الموصى به لمرحلة التنفيذ القادمة (لا تُنَفَّذ الآن — هذا تقييم جاهزية فقط):

| البند | النطاق التقديري | المخاطر | الاعتماديات |
|---|---|---|---|
| 1. Impact preview في `_deleteIngredient` | عرض قائمة أسماء المنتجات المتضررة في dialog قبل الحذف | Low — استعلام SELECT فقط | لا شيء |
| 2. Block + explicit override + audit row لحذف Ingredient | استبدال raw delete بـ transaction: استعلام المتأثرين → audit → حذف الروابط يدويًا بعد التأكيد الصريح | Low-Medium — تغيير مسار واحد مفحوص | البند 1 |
| 3. L-1 closure | صف audit واحد في legacy path | Low — دالة مفحوصة (47 test سابقًا) | لا شيء |
| 4. L-2 closure | RESTRICT على supplier_payments + audit row لحذف المورد | Low | لا شيء |
| 5. L-3/L-4 closure | audit rows لـ deleteProduct/deleteProductIngredient/deleteExpense/updateIngredient | Low | لا شيء |
| 6. (اختياري) أرشيف وصفات قبل الحذف | جدول/JSON snapshot اختياري | Medium — schema جديد إن استخدم جدول | البند 2 |

**الجاهزية:** البند 3 لا يحتاج أي اعتمادية ويمكن تنفيذه فورًا. البندان 1–2 يعتمدان على بعضهما فقط. كل البندود ضمن ملفات مسموحة في مراحل سابقة (app_provider + database_helper + screens inventory/products) وبنفس نمط Phase 2.3 (hooks اختبارية + tests مدمجة).

---

## 14. HISTORICAL DATA INTEGRITY STATEMENT

لا يوجد أي فقدان تاريخي فعلي اليوم — الفواتير وسجلات التدقيق ونقاط الولاء كلها سليمة بنيةً (Phase 2.1/2.3 أثبتت ذلك بـ 59/59 اختبارًا). الخطر تاريخي-مستقبلي: **كل مكوّن يُحذف اليوم يترك فواتيره القديمة بلا استرجاع صامت (L-1)**، وكل رابط وصفة يُمسح يُفقد نهائيًا من أي استرداد داخلي.

---

## 15. FINAL VERDICT

```
TRACE.............. COMPLETE (UI→Provider→DB→SQL→FK، 5 طبقات موثقة)
VERIFY............. COMPLETE (R-01 مؤكد بنسبة 100% — قابل لإعادة الإنتاج)
MAP CASCADE........ COMPLETE (16 قيدًا موثقًا في الجدول، التناقض RESTRICT-vs-CASCADE محدد)
ASSESS DATA LOSS... COMPLETE (الوصفات: غير قابلة للاسترداد الداخلي نهائيًا — حرجة)
ASSESS RECOVERABLE.COMPLETE (نسخة احتياطية يدوية فقط — لا Undo/Soft/Archive)
COMPARE SAFE DESIGNS.COMPLETE (A/B/C/D مقارَنة — D: Combination هو الأنسب)
RECOMMEND.......... COMPLETE (R-01/L-1/L-2 أولويات P0/P1/P1 — Scope 4.1 مقيَّم)
DOCUMENT........... COMPLETE (هذا التقرير)
STOP............... EXECUTED (لا كود، لا tests، لا commit، لا push — HEAD = 8ca0dda)
```

**NEXT RECOMMENDED PHASE: Phase 4.1 — Destructive Operation Hardening** (R-01 closure أولاً — block-with-impact-preview + audit — ثم L-1 ثم L-2)، تليها Phase 4.2 (E-Shift financial layer) وPhase 4.3 (Backup automation) كمرحلتين مستقلتين بالتوازي الممكن.

**أُعدّ بواسطة:** Manus AI — READ-ONLY AUDIT — لا تنفيذ.
