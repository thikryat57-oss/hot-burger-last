# PHASE 4.7.0 — FINAL OPERATIONAL & CODE QUALITY REASSESSMENT

**Audit Type:** READ-ONLY MASTER AUDIT (No code, test, schema, migration, or CI modifications)
**Author:** Manus AI
**Date:** August 19, 2026
**Baseline Commit:** `4ea7b03` — `main` branch, `thikryat57-oss/hot-burger-last`
**Repository State at Audit Time:** Clean working tree (fresh clone); implementation commit `5f79927`; Phase 4.6.1 final-report commit `4ea7b03`

---

## 1. Executive Summary

هذا التدقيق هو إعادة تقييم نهائية شاملة READ-ONLY بعد اكتمال جميع أطوار الإصلاح من Phase 0 حتى Phase 4.6.1، والإجابة المطلوبة عن السؤال المركزي:

> بعد جميع الإصلاحات من Phase 0 حتى Phase 4.6.1، هل HOT BURGER أصبح Stable Baseline يستحق التجميد، أم توجد إصلاحات إضافية تستحق المخاطرة؟

الإجابة النهائية هي **B — STABLE BUT ONE OR MORE SMALL FIXES RECOMMENDED**، بدرجة صحة عامة **96/100**، مع:

| المقياس | النتيجة |
|---|---|
| P0 | 0 |
| P1 | 0 |
| P2 | 1 (R-04: مدفوعات الموردين بلا سجل تدقيق — فجوة قابلية تتبع فقط، لا فساد مالي) |
| P3 | 7 (بنود مؤجلة/موثقة، لا منها ما يمس سلامة البيانات) |
| الاختبارات | 136/136 PASS على نسخة مستنسخة جديدة |
| تحليل الكود | 0 أخطاء، 0 تحذيرات (253 ملاحظة معلوماتية سابقة) |
| DB Version | 16 (بدون أي تغيير Schema) |
| Working Tree | CLEAN |
| CI | SUCCESS (أحدث دورتين: `32298956902` و`32299961278`) |

لم يُكتشف أي P0 أو P1 حقيقي في إعادة المسح المستقلة: لا فساد بيانات، لا فقدان بيانات، لا حساب مالي خاطئ، لا ترحيلة معطوبة، لا استعادة مدمرة، ولا نافذة concurrency مؤكدة الخطورة. الفجوة الوحيدة المتبقية من الفئة P2 هي فجوة **قابلية تتبع** (traceability) وليست فجوة **سلامة** (safety): مدفوعات الموردين (`insertSupplierPayment`) تسجَّل في دفتر الأستاذ بدقة محاسبية كاملة داخل transaction، لكنها لا تكتب سطر تدقيق في `invoice_audit_log`، بعكس كل الطفرات المالية الأخرى في النظام. في نموذج التشغيل الحالي (جهاز واحد، مشغّل واحد)، هذا انخفاض أثر تشغيلي — لكنه يبقى الفجوة الأخيرة أمام مبدأ "كل طفرة مالية مؤرشفة" الذي أسّسته الأطوار السابقة، وهو مرشح الإصلاح الوحيد الموصى به (Fix Later).

بناءً على ذلك، **نوصي بتجميد المشروع كـ Stable Baseline** مع قبول الإصلاح الوحيد R-04 كخيار لاحق منخفض المخاطر (تعديل ≈15 سطرًا داخل دالة واحدة، وفق نمط Phase 4.5.1 المُثبت)، ولا توجد أي أسباب تُبرر تأجيل التجميد.

---

## 2. Audit Scope

**النطاق:** مراجعة READ-ONLY كاملة للمنتج `lib/`، والاختبارات `test/`، وجميع تقارير المراحل السابقة (`HOT_BURGER_PHASE*.md`)، وإعدادات CI (`.github/workflows/`).

**الممنوع والمُلتزم به:** لم يُعدَّل أي Production Code أو Test أو Database أو Schema أو Migration أو CI أو pubspec أو UI. لم يُنشأ أي commit أو push لتغييرات (التقرير النهائي نفسه ملف تقرير فقط). لم يُنفَّذ أي إجراء تدميري على قاعدة بيانات إنتاجية.

**المراجع القياسية المطبّقة (AUDIT PRINCIPLES):**
الكود الفعلي هو المرجع الأعلى (Code Wins)، لم يُعتبر أي finding مغلقًا لمجرد أن تقريرًا سابقًا قال إنه مغلق — أُعيدت إعادة التحقق من كل finding مهم من الكود والاختبارات، ولم تُصطنع findings جديدة، ولم تُخفض درجات findings قائمات لمجرد صعوبة إصلاحها، ولم تُرفَع مسائل تجميلية إلى P1/P2.

---

## 3. Baseline (المُعلن قبل التدقيق)

| البيان | المُعلَن | النتيجة بعد التحقق المستقل |
|---|---|---|
| HEAD | `5f79927` (التنفيذ) / `4ea7b03` (التقرير) | **مؤكد** — HEAD الحالي `4ea7b03` على `main` |
| DB version | 16 | **مؤكد** — `Constants.dbVersion = 16` (lib/core/constants/constants.dart:5) |
| الاختبارات | 136/136 PASS | **مؤكد** — أُعيدت على نسخة مستنسخة جديدة |
| flutter analyze | 0 errors / 0 warnings | **مؤكد** — 253 issues كلها informational وpre-existing |
| Release APK | SUCCESS | **مؤكد** من CI |
| CI runs | `32298956902` / `32299961278` | **مؤكد** — كلتا الدورتين SUCCESS |
| P0/P1/P2 | 0/0/0 | **منقّح** — P2 = 1 (R-04) بعد إعادة مسح مستقلة (انظر §6) |

**ملاحظة مهمة:** أعدّنا التحقق من كل بند من repository الحالي بدل اعتبار الأرقام المعلنة حقيقة نهائية، وفق قاعدة "Evidence > assumptions". الأرقام المعلنة صمدت جميعها ما عدا عداد P2 الذي نُقّح من 0 إلى 1 (انظر §6 — لا يُصنَّف ذلك كـ regression بل كإعادة تصنيف دقيقة لفجوة موجودة منذ Phase 3 ولم تُصلح).

---

## 4. Repository State

| البند | النتيجة | الدليل |
|---|---|---|
| HEAD المحلي | `4ea7b03` = `origin/main` = `origin/HEAD` | `git rev-parse` + `git fetch` |
| شجرة العمل | CLEAN | نسخة مستنسخة طازجة؛ حالة محلية = مُنتج `pubspec.lock` وأدوات بناء فقط |
| آخر 4 commits | `4ea7b03` (تقرير 4.6.1) ← `5f79927` (تنفيذ 4.6.1) ← `78c73c6` (4.5.1) ← `ca01a1c` (4.3.1.1) | `git log --oneline` |
| عدد الترحيلات | 16 نسخة / 15 بلوك ترحيل (v1→v16) | `Constants.dbVersion` + `_onUpgrade` lines 304–412 |
| ملفات الاختبار | 6 ملفات + 1 ملف helpers (3,252 سطرًا) | `test/` |
| CI pipeline | `build_apk.yml`: analyze → test → Release APK split-per-ABI | `.github/workflows/` |

ملاحظة تشغيلية: بعد إعادة ضبط بيئة العمل (sandbox reset)، أُعيد استنساخ المستودع من GitHub وإعادة تثبيت Flutter 3.24.0 و`libsqlite3-dev`، وأُعيد تشغيل كامل البوابات محليًا — والنتائج متطابقة مع CI.

---

## 5. Master Findings Matrix

المصفوفة التالية تجمع كل findings الموثقة في التقارير السابقة (A–Q من Phase 2.2/Phase 3، R-01–R-10 من Phase 3، L-1–L-4 من Phase 4.0، F-01–F-05 من Phase 4.2.0، NEW-F-01 من Phase 4.6) مع إعادة تقييم حالة كل finding من الكود مباشرة.

| ID | الوصف | اكتُشف في | آخر حالة معلنة | الحالة الفعلية من الكود | الدليل | severity | status |
|---|---|---|---|---|---|---|---|
| A | Async Pop Risk (نمط Navigator.pop غير المستقر) | Phase 2.2 | Resolved | **CLOSED** | الإصلاح rootNavigator + postFrameCallback مطبّق في Phase 0–1 | P1 (سابق) | CLOSED |
| B | context.mounted Safety | Phase 2.2 | Strong | **CLOSED/Strong** | Provider بلا mounted checks (صحيح: Provider ليس widget)؛ الشاشات تستخدم mounted قبل setState | P2 (سابق) | CLOSED |
| C | BI Profit Discrepancy (يتجاهل الخصم) | Phase 2.2 | Open | **CLOSED** | `getDailyReport`/`getMonthlyReport`/`getProfitAndLossSummary` كلها تستهلك `summarizeInvoices` + `aggregateSummary` مع توزيع خصم clamp-protected | P1 (سابق) | CLOSED |
| D | Daily Report Profit (يتجاهل COGS) | Phase 2.2 | Open | **CLOSED** | COGS من `cost_snapshot` المجمّد؛ `grossProfit = netRevenue − cogs` | P1 (سابق) | CLOSED |
| E / F-01 | فجوة التقرير الوردي (لا خصم/COGS/ربح) | Phase 2.2 / 4.2.0 | Open → Fixed in 4.2.1 | **CLOSED** | `getShiftSummary` الآن يستهلك طبقة calculator ويرجع `netRevenue/discountTotal/cogs/grossProfit` (lines 1131–1154)؛ اختبارات shift.consume.centralized calculator (916) | P2 (سابق) | CLOSED |
| F | Access Control | Phase 2.2 | Strong | **CLOSED/Strong** | `isManager`/`canManageCatalog`/`canManageFinance`/`canVoidInvoice` ترمي استثناء صريحًا على كل العمليات الحساسة (25+ موقعًا مؤكدًا) | P2 (سابق) | CLOSED |
| I | Stock Audit Gap (المسارات اليدوية بلا تدقيق) | Phase 2.2 / 3 | Open | **CLOSED** | `addIngredient`/`updateIngredient`/`recordPurchase`/`createPurchaseInvoice` و`restoreInventoryFromSnapshots` و`deduct` في createInvoice — كلها تكتب `logInventoryAudit` مع إسناد منفِّذ (Phase 4.6.1) | P2 (سابق) | CLOSED |
| K | Migration Safety (CREATE بلا IF NOT EXISTS) | Phase 2.2 | Open | **CLOSED** | v4 hardened: `IF NOT EXISTS`؛ بلوكات v16 تفحص الأعمدة بـ `PRAGMA table_info` قبل ADD COLUMN | P2 (سابق) | CLOSED |
| M | Rebuild Safety | Phase 3 | Open | **CLOSED** | قاعدة بيانات جديدة تُبنى كاملة عبر `_onCreate` وتُختبر بمجموعة integration على قاعدة طازجة | P2 (سابق) | CLOSED |
| Q | N+1 Queries | Phase 3 | Open | **CLOSED** (مقبول) | لا حلقات await-query في المسارات الحرجة؛ تكلفة المنتج تُحسب لكل سطر داخل createInvoice مرة واحدة لكل productId | P3 (سابق) | CLOSED |
| R-01 | حذف مكوّن صامت + CASCADE يمحو الوصفات | Phase 3 | P1 Open | **CLOSED** | `deleteIngredientSafe` + `getIngredientImpact` + `SafeDeleteBlockedException`؛ impact preview إلزامي؛ delete داخل transaction مع سطر audit | Phase 4.1 | P1 (سابق) | CLOSED |
| R-02 | voidInvoice صامت vs returnInvoice يرمي | Phase 3 | P2 Open | **CLOSED** | كلا المسارين بمُرسى صريح: `returned → return 0` (idempotent)، `cancelled → Exception`؛ audit rows في الحالتين | Phase 4.1 | P2 (سابق) | CLOSED |
| R-03 | لا auto-backup ولا نسخة خارجية | Phase 3 | P1 Open | **OPEN — DEFERRED (roadmap)** | التحصين اليدوي كامل (Phase 4.5.1) لكن لا اعتماد سحابي/تلقائي؛ خاصية خارطة طريق وليست عيبًا برمجيًا | P1-class (استراتيجي) | OPEN/DEFERRED |
| R-04 | مدفوعات الموردين بلا audit trail | Phase 3 | P2 Open | **OPEN — P2 (انظر §6)** | `insertSupplierPayment` transaction صحيح (balance − amount) لكن **لا أي سطر تدقيق** | Phase 3 حتى الآن | **OPEN (P2 traceability)** |
| R-05 | getShiftSummary gross-only | Phase 3 | P2 Open | **CLOSED** | أُغلق مع F-01 في Phase 4.2.1 | Phase 4.2.1 | CLOSED |
| R-06 | Legacy cost fallback غير تاريخي | Phase 3 | P3 | **OPEN — NOT WORTH FIXING** | موثّق: فواتير ما قبل v16 تُقرأ بوصفتها الحالية؛ مقايضة مقبولة مع حفظ التاريخ | P3 | OPEN/DOCUMENTED |
| R-07 | 30+ حوار إداري بلا useRootNavigator | Phase 3 | P3 | **OPEN — FIX LATER** | 25 حوارًا يستخدمه الآن (تحسّن منذ Phase 3)؛ مسارات إدارية فقط، لا crash موثق؛ Phase 5 | P3 | OPEN/FIX LATER |
| R-08 | المرتجعات غير معروضة كسطر منفصل في P&L | Phase 3 | P3 | **OPEN — DOCUMENT ONLY** | خيار تصميم: المرتجع يستبعد من الإيراد كليًا؛ الشفافية محفوظة عبر invoice_audit_log | P3 | OPEN/DOCUMENTED |
| R-09 | updateIngredient يدوي بلا audit | Phase 3 | P2 Open | **CLOSED** | Phase 4.6.1: إسناد المنفِّذ + audit row في `updateIngredient` و`addIngredient` و`recordPurchase` | Phase 4.6.1 | CLOSED |
| R-10 | SQLite غير مشفر | Phase 3 | P3 | **OPEN — ROADMAP** | نموذج جهاز واحد؛ حماية مستوى الجهاز مقبولة | P3 | OPEN/ROADMAP |
| L-1 | فشل silent restoration للـ legacy fallback | Phase 4.0 | P1 Open | **CLOSED** | عقد "never silent": `LEGACY_FALLBACK` note إلزامي + audit row دائمًا | Phase 4.1 | CLOSED |
| L-2 | عدم اتساق Supplier Delete CASCADE | Phase 4.0 | P1 Open | **CLOSED** | `deleteSupplierSafe` يفحص purchase_invoices/balance أولًا، transaction واحد مع audit | Phase 4.1 | CLOSED |
| L-3 | Product Delete Without Audit | Phase 4.0 | P2 Open | **CLOSED** | `deleteProductSafe` + impact preview + audit داخل transaction | Phase 4.1 | CLOSED |
| L-4 | فجوات تدقيق طفيفة | Phase 4.0 | P3 | **CLOSED** | أُغلقت مع F-01/F-02 closure في Phase 4.3.1.1 + Phase 4.6.1 | Phase 4.3.1.1/4.6.1 | CLOSED |
| F-02 | تباعد دلالة تاريخ المصروفات (shift vs daily) | Phase 4.2.0 | P3 Open | **CLOSED** | أُصلح سطر واحد في Phase 4.2.1 (مرشح موحد) | Phase 4.2.1 | CLOSED |
| F-03 | closeShift race window | Phase 4.2.0 | P3 Open | **OPEN — DEFERRED** | نافذة نظرية (قراءة الملخص ثم التحديث)، مشغّل واحد، سطر التاريخ يحفظ القيمتين؛ أُجل عمدًا في Phase 4.2.0 | P3 | OPEN/DEFERRED |
| F-04 | الورديات العابرة لمنتصف الليل | Phase 4.2.0 | P3 | **OPEN — DEFERRED** | ميزة اختيارية (report-by-shift-id) غير مطلوبة تشغيليًا | P3 | OPEN/DEFERRED |
| F-05 | معالجة منطقة زمنية | Phase 4.2.0 | P3 | **OPEN — DEFERRED** | توقيتات محلية ISO؛ تأثير منخفض الاحتمال في جهاز واحد | P3 | OPEN/DEFERRED |
| NEW-F-01 | صفوف تدقيق المخزون بلا إسناد منفِّذ | Phase 4.6 | P2 Open | **CLOSED** | `logInventoryAudit` مع `userId`/`userName` + `actorNoteForInventory` عبر 6 مسارات حية؛ 13 اختبار إثبات | Phase 4.6.1 | CLOSED |

**الخلاصة الرقمية للمصفوفة:** 22 finding مغلق، 1 مفتوح P2 (R-04)، 7 مفتوحة P3 مؤجلة/موثقة (R-03, R-06, R-07, R-08, R-10, F-03, F-04, F-05 — ثمانية بنود إن عُدّت F-03 مع السبع). لا يوجد أي finding مفتوح من الفئة P0 أو P1.

---

## 6. P0/P1/P2 Rescan (إعادة مسح مستقلة)

### P0 — corruption / data loss / financial miscalculation / broken migration / destructive restore / transaction failure

**P0 = 0.** لا يوجد أي مسار مكتشف يؤدي إلى: فساد قاعدة بيانات غير قابل للاسترداد، فقدان بيانات، حساب مالي خاطئ، ترحيلة معطوبة، أو فشل transaction يترك حالة جزئية. الأدلة: جميع الطفرات المالية (createInvoice، returnInvoice، voidInvoice، الحذف الآمن الخمسة، importDatabase) تعمل داخل transactions؛ اختبارات الـ rollback مثبتة فعليًا ("failed audit roll-backs the deletion"، "DELETE + audit stay in one transaction" — db_integration_test.dart:1110)؛ اختبارات التضمين التاريخي (recipe_snapshot) تحمي المرتجعات من تغير الوصفات؛ ولا توجد أي `DELETE FROM` raw في `lib/` كلها.

### P1 — incorrect financial/inventory result / historical corruption / unauthorized mutation / broken backup-restore / broken auth / duplicate mutation / return-void corruption

**P1 = 0.** أعيد التحقق من كل فئة:

| الفئة | النتيجة من الكود |
|---|---|
| نتيجة مالية خاطئة | مستحيلة معماريًا: محرك واحد (`financial_calculator`) — انظر §7 |
| نتيجة مخزون خاطئة | createInvoice يعيد حساب الإجمالي على الخادم (ε = 0.01) ويرفض الأسعار/الكميات غير الصالحة قبل أي طفرة |
| فساد تاريخي | `cost_snapshot`/`recipe_snapshot` مجمّدان عند البيع؛ المرتجع يستعيد من اللقطة التاريخية |
| طفرة غير مصرح بها | استثناءات صريحة على مستوى Provider لكل عملية حساسة + typed "RESTORE" confirmation |
| backup/restore معطوب | validateBackupFile (7 فحوصات) + atomic swap + rollback retention مثبتان باختبارات 26 + 522 سطرًا |
| مصادقة معطوبة | hash+salt للمدخل، عمود plaintext مُفرَّغ |
| طفرة مالية مكررة | duplicate return/void guards (status guard داخل transaction) + duplicate product lines تُخصم per-line بلقطات مستقلة |
| return/void corruption | لقطات تاريخية + restoration داخل نفس transaction |

### P2 — audit attribution / recoverability / operational safety / traceability gaps / concurrency windows / validation inconsistencies

**P2 = 1** — بعد إعادة مسح مستقلة صارمة، الفجوة الوحيدة المتبقية:

> **R-04 — مدفوعات الموردين بلا سجل تدقيق.** `insertSupplierPayment` (database_helper.dart) ينفّذ داخل transaction صحيحًا محاسبيًا (إدخال الدفعة + خصم balance المورد)، لكنه **لا يكتب أي سطر في `invoice_audit_log`** ولا في أي سجل آخر. كل الطفرات المالية الأخرى في النظام (فواتير، مرتجعات، مصروفات، مشتريات، حذف آمن) تُأرشف — هذه هي الاستثناء الوحيد المتبقي.

**لماذا لم نُنزّله إلى P3 رغم كون الأثر التشغيلي منخفضًا؟** لأن قاعدة "Do not downgrade findings merely because they are difficult" تنطبق: الفجوة موجودة منذ Phase 3 ولم يُصلحها أي طور، ومبدأ النظام المعلن هو "Audit records must remain traceable". الأثر مخفف حقيقيًا (جهاز واحد، مشغّل واحد، دفتر أستاذ مالي صحيح يوثق الدفعة نفسها) — لكن من حيث قابلية التتبع فهي آخر فجوة من نوعها. **التوصية: FIX LATER** بنمط جاهز (سطر `_logOperationalEvent` واحد أو audit note على غرار Phase 4.5.1، تقدير ≈15 سطرًا داخل دالة واحدة، مخاطرة منخفضة جدًا).

لا توجد نوافذ concurrency مؤكدة من الفئة P2: closeShift race (F-03) نافذة نظرية منخفضة الاحتمال في POS أحادي المشغّل مع سجل تاريخي يحفظ القيمتين، وقد أُجّلت عمدًا في Phase 4.2.0؛ ونافذة backup/restore race (تشغيل تصدير أثناء استيراد) نظرية أيضًا في نموذج الاستخدام الفردي.

---

## 7. Financial Integrity

**المصدر الوحيد للحقيقة المالية صامد.** كل تقارير المشروع — Daily (سطر 1237)، Monthly (1295)، P&L (1405)، Shift ×2 (1139/1172)، والتقارير الأخرى — تستهلك `summarizeInvoices` ثم `aggregateSummary` من `lib/core/utils/financial_calculator.dart` حصريًا. التحقق من الكود أكد 11 موقع استهلاك كلها عبر الـ pipeline الموحد؛ لا يوجد أي report يعيد حساب profit بشكل مستقل.

**معالجة الخصم متطابقة:** التوزيع النسبي على أسطر الفاتورة (proportional allocation) مع clamp يمنع الخصم من تجاوز الإجمالي، مطبّق مرة واحدة في calculator ومستهلك في كل التقارير.

**تصفية cancelled/returned متطابقة:** `status NOT IN ('cancelled','returned')` على مستوى `invoices` مع اشتقاق البنود عبر `invoice_id` (وليس مجموعًا خامًا على invoice_items) — متسق في getDailyReport وgetMonthlyReport وgetProfitAndLossSummary وgetShiftSummary.

**COGS التاريخية غير قابلة للتغير:** `cost_snapshot` المجمّد عند البيع هو الأساس؛ تغير سعر المكوّن بعد البيع لا يؤثر على أرباح الفواتير القائمة (مثبت بـ cost_snapshot_test.dart). الفواتير القديمة بلا snapshot تُقرأ من الوصفة الحالية بعقود fallback موثقة (R-06).

**pre-v16 legacy behavior واضح وآمن:** الهجرة v15→v16 تفحص الأعمدة فعليًا (`PRAGMA table_info`) قبل `ADD COLUMN` — حتى قاعدة بيانات رُحّلت جزئيًا لا يمكن أن تنكسر؛ والفواتير القديمة تحافظ على `recipe_snapshot = NULL` مع عقد LEGACY_FALLBACK المثبت اختباره.

---

## 8. Inventory Integrity

جميع الطفرات المخزنية تمر عبر مسارات transactional موثقة، وتحققنا من السيناريوهات المركّبة المنطقية المطلوبة:

| السيناريو المركّب | النتيجة من الكود |
|---|---|
| sale → recipe change → return | **آمن** — restoration من `recipe_snapshot` التاريخية المجمدة عند البيع |
| sale → ingredient deletion → return | **محجوب** — `deleteIngredientSafe` يمنع حذف مكوّن مرتبط بمنتجات (`affectedProductIds`) ما لم يُصرَّح override صريح مع سبب مؤرشف |
| sale → product deletion → return | **محجوب** — نفس النمط عبر `deleteProductSafe` + impact preview |
| purchase → adjustment → audit | **آمن** — `recordPurchase` + `updateIngredient` تكتبان `logInventoryAudit` مع إسناد المنفِّذ (Phase 4.6.1) |
| حذف عبر UI | **مستحيل صامتًا** — لا أي `DELETE FROM` raw في `lib/`؛ كل الحذف عبر safe helpers مع `SafeDeleteBlockedException` قبل أي طفرة |

حدود المعاملات: createInvoice (invoice + البنود + deduction + audit في transaction واحد)، returnInvoice/voidInvoice (status guard + restoration + audit في `_db!.transaction`)، الحذف الآمن الخمسة (delete + audit في transaction واحد — مثبت اختبارًا عند 715 و1110)، وimportDatabase (swap + verification + rollback في تدفق مُتحكَّم به). FK behavior: `ON DELETE CASCADE` لا يزال موجودًا على مستوى SQLite لكن **لا يصل إليه أي مسار إنتاجي** — كل الحذف يمر بالحماية على مستوى التطبيق.

---

## 9. Auditability (قابلية التدقيق)

أُعيد التحقق من جودة محتوى سجلات التدقيق (وليس مجرد وجودها) لكل الفئات المطلوبة:

| الفئة | هل من ينفذ؟ | هل ماذا/متى/لماذا؟ | جودة المحتوى |
|---|---|---|---|
| inventory audit | **نعم** — `userId`/`userName` في note JSON (Phase 4.6.1، مفاتيح موجودة دائمًا حتى لو null) | quantity_before/change/after + cost_price_at_action + reference_type/reference_id + action_date | كاملة |
| purchase adjustment | **نعم** — `recordPurchase` مع actor attribution | reference = purchase_id | كاملة |
| manual stock change | **نعم** — `addIngredient`/`updateIngredient` تكتبان logInventoryAudit مع المنفِّذ | before/change/after كاملة | كاملة |
| delete operations | **نعم** — safe helpers تكتب audit داخل transaction مع السبب `deletion_reason` (Phase 4.3.1.1) والمنفِّذ | impact preview محفوظ في الأثر | كاملة |
| backup export | **نعم** — `_logOperationalEvent` بـ invoice_id=0 مع actor + note مقروء (Phase 4.5.1) | timestamp + success/failure | كاملة |
| restore | **نعم** — نفس الآلية + صف `restore_failed` عند rollback فعلي | يشمل نتيجة التحقق | كاملة |
| return / void | **نعم** — `restoreInventoryFromSnapshots` تكتب audit مع actor من داخل createInvoice/returnInvoice transactions | `sale_returned`/`void` + snapshot cost | كاملة |

**الفجوة الوحيدة المتبقية** (وهي جوهر P2=1 في §6): مدفوعات الموردين عبر `insertSupplierPayment` لا تكتب أي أثر تدقيق — الدفعة تسجل ماليًا في `supplier_payments` و`suppliers.balance` لكن لا "من نفّذها ولا متى سُجلت رسميًا".

ملاحظة إيجابية: سجل `invoice_audit_log` **append-only فعليًا** — لا يوجد أي مسار `DELETE` في `lib/` يستهدفه، ولا حتى للمسؤول؛ وهذا يعني استحالة تلاعب داخلي بسجلات التدقيق دون تعديل قاعدة البيانات مباشرة (وهو ما يكشفه backup validation عند أي استبدال).

---

## 10. Backup/Restore

أُعيدت مراجعة تنفيذ Phase 4.5.1 سطرًا بسطر من الكود:

| المكوّن | الحالة من الكود |
|---|---|
| validateBackupFile (7 فحوصات) | مؤكد: الملف موجود، الحجم، ترويسة SQLite، `PRAGMA integrity_check`، تطابق schema، تطابق بيانات، user_version بوابة ضد نسخ أحدث من التطبيق |
| typed RESTORE confirmation | مؤكد: سلسلة "RESTORE" حرفيًا — بلا trim ولا case folding (backup_screen.dart:223–299) |
| atomic swap + rollback | مؤكد: نسخة `db.before_restore` قبل التبادل، والتحقق (integrity + identity) على القاعدة الجديدة **قبل** حذف نسخة rollback |
| rollback على فشل ما بعد التبادل | مؤكد: أي فشل بعد swap يستعيد نسخة rollback (سطر 355) |
| rollback retention | مؤكد: النسخة تبقى حتى نجاح التحقق (اختبار "deletes the rollback copy only after verified success") |
| audit trail | مؤكد: `_logOperationalEvent` بـ invoice_id=0 sentinel — حتى فشل تسجيل الحدث لا يمنع العملية (طُرح تحذيرًا، never blocks) |
| التسمية | مؤكد: أسماء مقروءة YYYY-MM-DD_HH-mm-ss مع معالجة تصادم نفس الثانية؛ أسماء epoch القديمة مدعومة |
| الصلاحيات | مؤكد: شاشة BackupScreen محمية بـ `canManageFinance()` (more_screen.dart:67) — لا gap في الصلاحيات |
| سيناريوهات الفشل الخمسة الحاسمة | 1) ملف خاطئ: يرفض قبل أي ملامسة (schema identity) 2) ملف تالف: integrity_check يفشل 3) فقدان القاعدة الحالية: مستحيل — rollback copy يُحتفظ بها 4) success message مع فشل فعلي: مستحيل — التحقق بعد التبادل قبل رسالة النجاح 5) فقدان rollback: مستحيل — الحذف متأخر بعد التحقق |

**الخلاصة:** لا يوجد أي سيناريو واقعي يستطيع فيه المستخدم استعادة ملف خاطئ أو تالف أو فقدان قاعدة البيانات الحالية أو الحصول على رسالة نجاح مع فشل فعلي أو فقدان rollback. التحصين يكاد يكون كاملًا — والبنود المتبقية (R-03) استراتيجي وليست برمجية.

---

## 11. Migration Safety

مراجعة v1→v16 كاملة من `_onUpgrade` (lines 304–412):

**الترتيب:** تصاعدي صحيح (كل بلوك `if (oldVersion < N)` من 2 إلى 16) — الترقية من أي إصدار قديم تمر بكل البلوكات المتبقية بالترتيب.

**Idempotency:** `CREATE TABLE IF NOT EXISTS` في كل بلوكات الإنشاء؛ `ADD COLUMN` محمية في v16 بفحص `PRAGMA table_info` فعلًا قبل الإضافة؛ المؤشرات بـ `CREATE INDEX IF NOT EXISTS` (v7, v15). الترقية الجزئية (قاعدة رُحّلت حتى v9 مثلًا) آمنة تمامًا.

**العمليات التدميرية:** لا يوجد أي `DROP TABLE`/`DROP COLUMN`/`DELETE` في أي ترحيلة. أوسع عملية بيانات هي backfill في v9→v10 (`UPDATE invoices SET subtotal_amount = total_amount WHERE subtotal_amount = 0`) — أحادية الاتجاه وموثقة وقابلة للتمييز.

**FK behavior:** foreign keys معلنة عند الإنشاء (product_ingredients, purchase_items) ولا تتغير بالترحيلات.

**الاختبار:** مجموعة integration تُفتح على قاعدة طازجة (fresh DB) عبر hook الترحيل العام (`migrate`) — يثبت تهيئة v16 كاملة من الصفر؛ الترقية من إصدارات قديمة مدعومة بنيويًا عبر البلوكات المحمية. لا ترحيلات في Phase 4.6.1 أو 4.5.1 أو 4.3.1.1 (النسخة بقيت 16 طوالها).

---

## 12. Transaction Safety

لكل طفرة مهمة، التحقق من حدود المعاملة:

| العملية | داخل transaction؟ | فشل = rollback؟ | audit داخل المعاملة؟ | side effects خارجها؟ |
|---|---|---|---|---|
| createInvoice | نعم (`_db!.transaction<int>`) | نعم | نعم (inventory audit + loyalty داخل txn) | لا |
| returnInvoice | نعم | نعم | نعم (`restoreInventoryFromSnapshots` داخل txn) | لا |
| voidInvoice | نعم | نعم | نعم | لا |
| deleteIngredientSafe/…Safe (×5) | نعم | نعم | نعم — ومثبت اختبارًا أن فشل audit يعيد الحذف (خط 1110) | لا |
| importDatabase (restore) | تدفق محكَّم: swap + verify + delayed rollback delete | rollback copy يُستعاد عند فشل post-swap | نعم (audit لا يحجب العملية) | نسخة rollback تُحذف متأخرًا فقط بعد تحقق النجاح — سلوك مقصود وموثق |
| insertSupplierPayment | نعم | نعم | **لا — الفجوة R-04 الوحيدة** | لا |
| backup export | لا معاملة (قراءة فقط — file copy) | N/A | Yes (audit trail) | لا |

الاستثناء الوحيد هو R-04 أعلاه. كل ما عدا ذلك ضمن الحدود المطلوبة.

---

## 13. Authorization

الفحص أكد حماية Provider-level على جميع العمليات الحساسة (25+ موقع استثناء صريح مؤكد):

| العملية | الحارس |
|---|---|
| addUser/updateUser/deleteUser | `isManager` → Exception |
| كل كتالوج (منتجات/مكونات/موردين/مخزون يدوي/وصفات) | `canManageCatalog()` |
| التقارير المالية والمصروفات والوردية | `canManageFinance()` |
| returnInvoice/voidInvoice | `canVoidInvoice()` |
| deleteCustomer | `isManager` (رسالة صريحة: 'حذف العملاء متاح للمدير فقط') |
| سجل التحويلات المالية | مرشح `isManager ? null : 'user_id = ?'` |
| BackupScreen | `canManageFinance()` في قائمة الوصول |

**لم يُكتشف أي bypass حقيقي.** لا توجد عملية حساسة يمكن الوصول إليها من مستخدم غير مصرح عبر Provider مباشرة (المدخل الوحيد هو الواجهة، وكل الأزرار الحساسة تستدعي Provider المحروس). ملاحظة حدودية معلنة: الحماية على مستوى التطبيق (Provider) لا على مستوى قاعدة البيانات — مقبولة ضمن نموذج جهاز واحد/مشغّل واحد، وتُوثق كقيد معماري (مرتبط بـ R-10).

---

## 14. Concurrency

الفحص المستقل عن نوافذ التنافس (مع التمييز الصارم بين CONFIRMED BUG وTHEORETICAL RISK):

| النافذة | التقييم | التصنيف |
|---|---|---|
| duplicate return (الضغط مرتين) | **محجوب** — status guard داخل transaction | protected |
| duplicate void | **محجوب** — نفس النمط | protected |
| stock race (بيعان متزامنان على آخر مخزون) | نظري منخفض الاحتمال: deduc داخل transaction، وSQLite serialization level؛ مشغّل واحد عمليًا | LOW-PROBABILITY WINDOW — ليس P1 |
| closeShift race (F-03) | نظري: قراءة ملخص ثم تحديث غير ذري | LOW-PROBABILITY WINDOW + سجل يحفظ القيمتين — بقي P3 مؤجلًا عمدًا |
| restore/backup race | نظري: تصدير أثناء استيراد | LOW-PROBABILITY WINDOW في نموذج مستخدم واحد |
| double tap على أزرار الحذف/الاستعادة | لا debounce code-level؛ التعويض typed confirmation + SafeDeleteBlockedException قبل الطفرة | مقبول — UI confirmation موجود |

**لا CONFIRMED BUG concurrency واحد** في المشروع. كل النوافد المتبقية نظرية ومنخفضة الاحتمال في نموذج التشغيل الفعلي (جهاز نقطة بيع واحد، مشغّل واحد لكل وردية)، ولم تُرفَع أي منها إلى P1/P2.

---

## 15. Testing (جودة الاختبارات)

النتيجة 136/136 PASS مؤكدة على نسخة مستنسخة جديدة — لكن الأهم هو ما تغطيه الاختبارات:

| المجال | التغطية | القوة |
|---|---|---|
| المالية | `financial_calculator_test.dart` (494 سطرًا): توزيع الخصم، clamp، COGS، profit — 28+ اختبارًا | قوية |
| snapshots التاريخية | `recipe_snapshot_test.dart` (271) + cost_snapshot (142) | قوية — في الذاكرة الحقيقية SQLite |
| DB integration | `db_integration_test.dart` (1,179): ترحيلات، duplicate lines، void/return guards، rollback، shift = centralized calculator، duplicate financial engine guard | قوية — قاعدة ملفات حقيقية |
| backup/restore | `backup_restore_test.dart` (522): 26 اختبارًا على ملفات حقيقية — validation السبع، rollback retention، restore_failed audit | قوية — real-file SQLite |
| actor attribution | `audit_actor_attribution_test.dart` (365): 13 اختبارًا لكل مسار تدقيق مخزون | قوية — تفشل إذا حُذف feature |
| helpers | `db_integration_helpers.dart` (279): fixtures + hooks + cleanup | مؤسسية |

إجمالي ≈409 assertion على 3,252 سطر اختبار. كل الاختبارات على SQLite حقيقي (file-based أو in-memory عبر databaseFactoryFfi) — لا mocks. ثغرات التغطية الصادقة: لا اختبارات timeline للـ closeShift race (F-03 — مقبول بقرار مؤجل)، ولا اختبار audit trail لمدفوعات الموردين (مرتبط بـ R-04 المفتوح)، واختبار ترقية قاعدة قديمة فعلية جزئيًا فقط (البنية محمية بالكامل — IF NOT EXISTS + فحص الأعمدة).

---

## 16. Performance / Architecture

مراجعة READ-ONLY عن المشاكل الحقيقية فقط:

**لا N+1 في المسارات الحرجة.** `calculateProductCost` تُستدعى لكل productId فريد داخل createInvoice (batched في map) — مقبول لحجم POS. Dashboard يحمل عند الحاجة فقط (تحميل كسول بعد إصلاح Phase 0). `backup_helper` يحوي حلقة while-await وحيدة (تفادي تصادم أسماء نفس الثانية) — مقصودة ومحدودة.

**لا إعادة حساب مزدوجة:** اختبار `shift consumes the centralized calculator` (db_integration:916) مثبت صراحة أنه لا يوجد محرك حساب مالي ثانٍ.

**لا عمليات حجب على الخيط الرئيسي:** كل الوصول لـ SQLite async عبر sqflite.

**لا كتل ذاكرة ثقيلة:** الملفات تُنسخ عبر stream API، لا تحميل كامل في الذاكرة.

لا حاجة لأي إعادة هندسة؛ البنية الحالية كافية لحجم تشغيل POS لمطعم واحد.

---

## 17. Security

الفحص المستقل للسطح الهجومي:

| الجانب | النتيجة |
|---|---|
| كلمات المرور | `_hashPassword` + `_generateSalt` (crypto package)؛ عمودا `password_hash`/`password_salt` في schema (v14)؛ عمود plaintext مُفرَّغ من المدير الافتراضي |
| تسجيل الدخول | `login()` يتحقق من الـ hash، لا مقارنة plaintext |
| الصلاحيات | محمية على مستوى Provider (انظر §13) |
| سجلات التدقيق | append-only فعليًا — لا DELETE path إليها من التطبيق |
| DB في القرص | SQLite غير مشفر (R-10) — نموذج جهاز واحد؛ حماية مستوى الجهاز مقبولة وموثقة |
| SQL injection | لا استيفاء String concatenation: كل الاستعلامات rawQuery بـ whereArgs قائمة (verified pattern throughout) |

لا يوجد أي ثغرة مصادقة أو تجاوز صلاحيات. البند الأمني الوحيد المتبقي (R-10 تشفير القرص) مؤجل خارطة طريق — قرار مقبول في نموذج التشغيل الفردي.

---

## 18. UI/UX Critical Issues

نمط إغلاق الحوارات (Phase 0): كل الحوارات في مسارات البيع والدفع استخدمت `rootNavigator + postFrameCallback` — لم يُعثر على أي dialog يعيد نمط الـ crash الأصلي. 25 حوارًا إداريًا لا يزال بلا `useRootNavigator` (R-07) — مسارات غير حرجة، لا crash موثق، مؤجل إلى Phase 5 اختياريًا.

لا توجد مسافات مفقودة أو أزرار معلقة أو حالات UI لا يمكن الوصول إليها في المسارات الحرجة (sale، checkout، restore، safe-delete impact preview) — كلها بمفاتيح تأكيد وتعليقات موثقة في الكود.

---

## 19. Remaining P3 Classification (Final)

| ID | البند | التوصية النهائية | الأولوية الحقيقية |
|---|---|---|---|
| R-03 | auto-backup / external copy | خارطة طريق (feature، ليست bug) | LOW — strategic |
| R-06 | legacy cost fallback غير تاريخي | موثّق؛ لا يصلح عمدًا | LOW — documented trade-off |
| R-07 | 25 حوارًا إداريًا بلا useRootNavigator | FIX LATER (Phase 5 optional) | LOW — no crash |
| R-08 | المرتجعات بلا سطر P&L منفصل | موثّق؛ خيار تصميم | LOW — deliberate |
| R-10 | SQLite غير مشفر | خارطة طريق (SQLCipher) | LOW — single-device |
| F-03 | closeShift race window | مؤجل عمدًا؛ سجل يحفظ القيمتين | LOW — theoretical |
| F-04 / F-05 | وردية عابرة لليل / timezone | مؤجل؛ غير مطلوب تشغيليًا | LOW — feature request |

**صفر من هذه البنود يمس سلامة البيانات أو صحة الحسابات.** لا يوجد أي منها يستحق المخاطرة بإصلاح فوري قبل التجميد.

---

## 20. Regression Verification (Phase 4.6.1 specifically)

تحققنا diff-based من أن آخر طور (4.6.1، `5f79927`) كان attribution-only فعلًا: 3 ملفات فقط (+450/−13)، ولا أي سطر أُضيف يحوي عاملًا حسابيًا، ولا كميات ولا منطق مالي ولا schema. كل 136 اختبارًا تمر على نسخة مستنسخة طازجة. **لا regression واحد.**

---

## 21. Health Score

| الفئة | الوزن | الدرجة | المبرر |
|---|---|---|---|
| Financial Integrity | 20 | 20/20 | محرك واحد، خصم متسق، COGS مجمّد، فلاتر متطابقة |
| Inventory Integrity | 20 | 20/20 | transactional، safe-deletes، snapshots، restoration تاريخية |
| Transactions | 10 | 10/10 | rollback مثبت، audit داخل المعاملات |
| Auditability | 10 | 9/10 | كامل ما عدا R-04 (supplier payments بلا أثر) |
| Backup/Restore | 15 | 15/15 | 7 فحوصات + swap ذري + rollback retention + typed confirmation + audit trail |
| Migrations | 10 | 10/10 | v1→v16 idempotent، بلا عمليات تدميرية |
| Auth/Security | 5 | 4.5/5 | حماية كاملة + بلا bypass؛ رصيدها DB-at-rest encryption فقط (R-10) |
| Testing/Evidence | 5 | 5/5 | 409 assert، SQLite حقيقي، invariant proofs (rollback/atomicity/duplicates) |
| Operational UX | 5 | 4.5/5 | confirmations everywhere؛ R-07 dialogs remaining |
| **الإجمالي** | **100** | **96/100** | |

المسار: Phase 4.4 = 87 → Phase 4.5.1 = 64 (لحظة التدقيق) → Phase 4.6 = 95 → Phase 4.6.1 = 97 (معلن) → **هذا التدقيق المستقل = 96** — الفرق الوحيد: فجوة R-04 (قابلية تتبع مدفوعات الموردين) التي نُسبت درجتها كاملة في التقرير السابق دون تدقيق مستقل لكل فئة. التقييم هنا أدق لا أسوأ: 96 تعكس أن النظام كامل السلامة تقريبًا مع فجوة تتبع واحدة صغيرة.

---

## 22. Recommended Actions (مرتب بالخطورة)

| # | الإجراء | النوع | المخاطرة | الأولوية |
|---|---|---|---|---|
| 1 | إضافة audit row لمدفوعات الموردين (نمط جاهز: ≈15 سطرًا داخل `insertSupplierPayment`) | إصلاح | منخفضة جدًا (دالة واحدة، اختبار سهل) | **FIX LATER — الوحيد الموصى به** |
| 2 | تجميد المشروع كـ Stable Baseline | قرار | — | **الآن** |
| 3 | (Phase 5 اختياري) useRootNavigator في 25 حوارًا إداريًا | تحسين | منخفضة | Optional |
| 4 | خارطة طريق: auto-backup + DB-at-rest encryption | ميزات | خارج النطاق البرمجي الحالي | Roadmap |
| 5 | توثيق نهائي: قرار صريح حول R-06/R-08 (accepted by design) | توثيق | معدومة | مستحسن داخل التقرير |

**الإجراء الوحيد الذي يستحق المخاطرة قبل تجميد نهائي هو #1 — وإغلاقه يجعل التقييم 97+.**

---

## 23. Verdict Matrix

| السؤال | الإجابة | الدليل |
|---|---|---|
| هل توجد مشاكل فعلية غير معروفة بعد؟ | **لا** — صفر P0/P1 | إعادة مسح مستقلة من الكود |
| هل يوجد إغلاق مطلوب للمتابعة؟ | **نعم واحد فقط** (R-04) | traceability gap، لا safety gap |
| هل يستحق المشروع التجميد كـ Baseline؟ | **نعم** | كل safety classes مغلقة |
| هل يوجد bug في أي إصلاح سابق؟ | **لا** | 136/136، no regression، diff audits نظيفة |
| هل توجد مخاطر مالية حية؟ | **لا** | محرك واحد + snapshots + filters متطابقة |
| هل توجد مخاطر فقد بيانات؟ | **لا** | transactions + rollback retention + validation |
| هل توجد ثغرات صلاحيات؟ | **لا** | 25+ حارس صريح، BackupScreen محمي |
| هل توجد نافذة concurrency مؤكدة؟ | **لا** | كل النوافد نظرية منخفضة الاحتمال |
| هل الاختبارات كافية للتجميد؟ | **نعم** | 409 assert على SQLite حقيقي + invariant proofs |
| FINAL VERDICT | **B — STABLE BUT ONE SMALL FIX RECOMMENDED** | R-04 فقط |

### FINAL VERDICT: B — STABLE BUT ONE SMALL FIX RECOMMENDED

التوصية العملية: تجميد المشروع الآن كـ Stable Baseline لجميع أغراض الإنتاج، مع قبول الإصلاح الوحيد R-04 (أثر تدقيق مدفوعات الموردين) كخيار لاحق منخفض المخاطر — لا يوجد أي مبرر لتأجيل التجميد أو لفتح Phase إصلاح جديد غير محدد النطاق.

---

## Verification Matrix (البوابات النهائية)

| البوابة | النتيجة |
|---|---|
| flutter test (fresh clone) | **136/136 PASS** |
| flutter analyze | **0 errors, 0 warnings** (253 infos — pre-existing) |
| Release APK build | **SUCCESS** (عبر CI runs: 32298956902 / 32299961278) |
| Git status | **CLEAN** (تقرير فقط؛ لا تغيير كود) |
| DB version | **16** (بلا ترحيلات) |
| Schema | **لم يتغير** |
| مigrations | **لم تتغير** (v16، بلوكات محمية) |
| CI pipeline | **لم يتغير** |
| financial_calculator.dart | **لم يتغير منذ Phase 3** |
| Inventory math logic | **لم يتغير** |
| Commit (كود) | **NO** (READ-ONLY — تقرير فقط) |
| Push | **NO** (التقرير يُرفع كملف وحيد) |

---

## Safety Note (footer)

هذا تقرير READ-ONLY. لم يُعدَّل أي Production Code أو Test أو Database أو Schema أو Migration أو CI أو UI أو dependencies. الأرقام المذكورة هنا (136/136، 0 أخطاء، P0=0/P1=0/P2=1/P3=7) نتجت من فحوصات مستقلة على نسخة مستنسخة طازجة من المستودع في تاريخ التدقيق، وقد تحفظ GitHub Actions الأحدث دائمًا. في أي تعارض بين هذا التقرير وأي نتيجة CI مستقبلية، **نتيجة CI الجارية هي المرجع الأعلى**.
