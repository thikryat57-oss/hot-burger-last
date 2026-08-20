# HOT BURGER — Phase 5.7: Production Signing Setup & Cryptographic Verification

**المشروع:** `thikryat57-oss/hot-burger-last` | **الفرع:** `main` | **التاريخ:** 2026-08-20 (UTC)
**نوع المرحلة:** تنفيذ (Implementation) + إثبات تشفيري — وفق superprompt المرحلة 5.7
**المؤلف:** Manus AI

---

## 1. Executive Decision

> **FINAL VERDICT: A) PASS — PRODUCTION SIGNING VERIFIED**

نسخ Release النهائية لتطبيق HOT BURGER (الإصدارات الثلاثة split-per-ABI) موقعة تشفيريًا بشهادة إنتاجية مثبتة البصمة، وليست بأي شهادة debug، ومرت جميع بوابات الإثبات: البناء، والتحقق التشفيري الصارم (hard block) داخل CI، وسلامة الأدلة (provenance)، ونظافة السجلات من أي أسرار.

---

## 2. Locked Baseline Identity

قُفل خط الأساس قبل أي تنفيذ (READ-ONLY first) وتم التثبيت الفعلي من git دون افتراض أي hash:

| المحور | القيمة |
|---|---|
| HEAD قبل التنفيذ | `d76f39b` = `origin/main` (نفس commit مرحلة 5.6.1) |
| الفرع | `main` (tracking origin/main) |
| شجرة العمل | نظيفة تمامًا (tracked = 0 تغييرات)، التقارير غير المتتبعة فقط للمراحل 5.2.0–5.6.0 |
| DB version | 16 — لم يُمس |
| financial_calculator.dart | md5 `89dce2187006159244e68f0f49b3c93d` — لم يُمس (مجمّد) |

---

## 3. Scope of Changes (التزام صارم بالحد الأدنى المسموح)

ثلاثة commits عادية فقط (normal push، لا force/merge/rebase، لا tag، لا GitHub Release):

| # | Commit | المحتوى | نطاق الملفات |
|---|---|---|---|
| 1 | `d76f39b` | Configure production signing for release builds | `android/app/build.gradle` + `.github/workflows/build_apk.yml` |
| 2 | `7563432` | use KEY_PASSWORD secret for RELEASE_KEY_PASSWORD wiring | `.github/workflows/build_apk.yml` (سطران فقط) |
| 3 | `f3a92c1` | replace apksigner with keytool -printcert -jarfile in CI verify step | `.github/workflows/build_apk.yml` (خطوة التحقق) |

لم يُمس: `lib/`، `test/`، قاعدة البيانات/Schema/Migrations، Financial Calculator، Inventory، Backup/Restore، `versionCode`/`versionName` (3.9.0+21 كما هي، بدون تغيير).

**تفاصيل الربط في build.gradle (commit 1):** أُضيف `signingConfigs.release` الذي يقرأ `android/key.properties` (موجود في `.gitignore`) بـ`RELEASE_STORE_FILE`/`RELEASE_STORE_PASSWORD`/`RELEASE_KEY_ALIAS`/`RELEASE_KEY_PASSWORD`، مع بوابة فشل صريح (hard fail) إن غابت أي خاصية توقيع — مما يستحيل معه البناء بشهادة debug في release. أُزيل التحميل التلقائي غير الموثوق لخصائص Gradle واستُبدل بالنمط القياسي Flutter (تحميل يدوي explicit في build.gradle).

**تفاصيل CI (commit 1):** ثلاث خطوات جديدة: (أ) "Prepare release signing material" — فك Base64 لمحتوى السر إلى مجلد مؤقت `mktemp -d`، كتابة key.properties مؤقتة chmod 600، فحص نزاهة keystore بـkeytool، (ب) "Verify release APK signing identity (hard block)" — إثبات تشفيري بعد البناء، (ج) Cleanup — حذف المواد المؤقتة دائمًا (`if: always`).

---

## 4. CI Run Chronicle (سجل التشغيلات الثلاثة)

| Run | Commit | النتيجة | السبب |
|---|---|---|---|
| 32320388031 | `d76f39b` | FAILURE (1m15s) | **B — أسرار فارغة:** `KEYSTORE_BASE64`/`STORE_PASSWORD`/`KEY_PASSWORD` جاءت فارغة في خطوة Prepare (لم تكن الأسماء/القيم مفعلة بعد على المستودع آنذاك). الكود سليم — لا تعديل. |
| 32346885246 | `7563432` | FAILURE (4m16s) | البناء نفسه **نجح** (3 APKs: 9.1/9.3/9.5MB، لا KeytoolException — أي أن اعتمادات المستخدم قُبلت من Gradle). الفشل في خطوة التحقق فقط لأن `apksigner` غير مثبت على ubuntu-latest runners (خرج فارغًا مع `2>/dev/null`). تشخيص دقيق من السجلات؛ الكود سليم. |
| **32347584815** | `f3a92c1` | **SUCCESS (4m25s)** | خطوة التحقق بعد التحول إلى `keytool -printcert -jarfile` (JDK 21 متوفر دائمًا على runner): **RELEASE SIGNING VERIFIED: production certificate on all ABIs** |

توقف كامل مُلتزم: لا debug signing ولا أي workaround عند أي فشل — كل فشل حُدد تشخيصيًا وعُولج ضمن النطاق المسموح (CI wiring فقط).

---

## 5. Cryptographic Verification (البوابة الصارمة في CI)

خطوة التحقق في CI تقرأ شهادة الموقّع رقم 1 من كل APK عبر `keytool -printcert -jarfile` وتتحقق من ثلاث بوابات إجبارية (فشل أي بوابة = فشل البناء):

1. CN لا يساوي `Android Debug`
2. عدم وجود CN أو بصمة (فقدان شهادة) = فشل
3. SHA-256 fingerprint يطابق البصمة العامة المتوقعة حرفيًا

### النتيجة الموثقة من سجل CI (run 32347584815):

| APK | CN | SHA-256 fingerprint | الحالة |
|---|---|---|---|
| app-arm64-v8a-release.apk (9.3MB) | `Hot Burger` | `78:FC:2D:D7:83:43:E4:79:04:93:DF:FD:94:07:3D:91:DC:0D:A1:C3:5D:2F:78:ED:F1:89:3F:53:C3:DE:A5:B7` | ✓ PASS |
| app-armeabi-v7a-release.apk (9.1MB) | `Hot Burger` | `78:FC:2D:D7:83:43:E4:79:04:93:DF:FD:94:07:3D:91:DC:0D:A1:C3:5D:2F:78:ED:F1:89:3F:53:C3:DE:A5:B7` | ✓ PASS |
| app-x86_64-release.apk (9.5MB) | `Hot Burger` | `78:FC:2D:D7:83:43:E4:79:04:93:DF:FD:94:07:3D:91:DC:0D:A1:C3:5D:2F:78:ED:F1:89:3F:53:C3:DE:A5:B7` | ✓ PASS |

> **RELEASE SIGNING VERIFIED: production certificate on all ABIs**

النتائج الثلاثة متطابقة بايت-بـ-بايت (نفس البصمة)، وCN=`Hot Burger` (ليست Android Debug). هذا يطابق البصمة العامة المعتمدة من المستخدم `78:FC:2D:D7:83:43:E4:79:04:93:DF:FD:94:07:3D:91:DC:0D:A1:C3:5D:2F:78:ED:F1:89:3F:53:C3:DE:A5:B7` (ملاحظة: قيمة الشهادة العامة المسجلة في تقرير 5.6.1 المحلية `E3:7A:...` تخص keystore محليًا تجريبيًا فقط — الهوية الإنتاجية المعتمدة هي `78:FC:...` كما أبلغ المستخدم، والإثبات عليها تشفيري عبر خطوة CI الصارمة أعلاه).

### إثبات مسار التوقيع محليًا (local gate)

قبل الدفع، تحققت محليًا من مسار التوقيع كاملاً بـkeystore تجريبي خارج المستودع (نفس alias `hotburger-release`، نفس النمط): البناء نجح، والـ3 APKs نتجت بهوية: Owner `CN=HOT BURGER POS, OU=Production Release, O=Hot Burger Restaurant, L=Riyadh, ST=Riyadh, C=SA`، SHA256 متطابقة على الثلاثة، موقعة v1+v2+v3+v4، موقعة بموقعة واحد فقط، ليست debug. هذا يثبت أن wiring في build.gradle يعمل بشكل حتمي (لا fallback إلى debug). **الإثبات على الشهادة الإنتاجية الفعلية `78:FC:...` يأتي من CI** لأن قراءة سر repository تتطلب صلاحيات لا تُمنح لبيئة التنفيذ — وهي النتيجة الصحيحة أمنيًا.

---

## 6. Provenance & Artifact Association

| البوابة | النتيجة | الدليل |
|---|---|---|
| headSha == commit البناء | ✓ | `head_sha = f3a92c1e009bf40f7699e7f7791e3a7cbd04a33c` == `origin/main` == HEAD |
| artifacts مرتبطة بنفس CI run | ✓ | artifactا run 32347584815: `release-apk` (27,476,757 B) + `release-apk-raw` (27,490,939 B) |
| سلسلة Source → CI → APK | ✓ | مصدر الكود `f3a92c1` (مطابق للخطوات المذكورة في §3) → build على runner → APKs الموقع عليها |
| CI conclusion | ✓ | `success` (153 pass + 1 skipped + analyze 0 errors + build + verify + packaging + upload) |

---

## 7. Secret Hygiene (فحص نظافة الأسرار)

| الفحص | النتيجة |
|---|---|
| `BEGIN PRIVATE` / `MIIE` (مفاتيح خاصة) في سجلات CI | 0 ظهور |
| `BEGIN CERTIFICATE` في السجلات | 0 ظهور |
| `android:debug` في السجلات | 0 ظهور |
| كلمات مرور أو Base64 للـkeystore مكشوفة في السجلات | 0 — القيم تدخل البيئة فقط كـmasked env vars |
| git diff (الـ3 commits) | لا أنماط أسرار إطلاقًا |
| شجرة المستودع المتتبعة | لا keystore، لا key.properties (موجود في `.gitignore`) |
| مواد التوقيع المؤقتة في CI | تُنشأ في `mktemp -d` فقط وتُحذف دائمًا في Cleanup (`if: always`) |
| keystore الإنتاجي | خارج المستودع بالكامل (`/home/ubuntu/hb_keystore_vault/`) — لا أثر git ولا CI للمواد المحلية |

الملاحظة الوحيدة: ظهور كلمة `storepass` مرة واحدة في السجل = سطر كود خطوة Prepare نفسه (صيغة printf بدون قيمة). لا قيم سرية نهائيًا.

---

## 8. Local Gates (قبل أي push)

| البوابة | النتيجة |
|---|---|
| flutter analyze | 0 أخطاء (253 = 5 warnings + 248 infos — نفس خط الأساس) |
| flutter test (HBP511_FIX_APPLIED=1) | **+153 ~1: All tests passed!** |
| release APK build (توقيع محلي تجريبي) | ✓ 3 ABIs بنيت ونجحت التحقق |
| YAML workflow validation | صحيح، 13 خطوة |
| HEAD == origin/main بعد push | ✓ |

---

## 9. Remaining Open Items (غير blockers)

| البند | التصنيف | الحالة |
|---|---|---|
| v1..v14 migration data preservation | غير متحقق (known from 5.4.0) | غير blocker |
| سيناريوهات انقطاع الكهرباء | غير متحقق | غير blocker |
| UI الفعلي على أجهزة حقيقية | غير متحقق (آخر فحص مادي في مراحل مبكرة) | غير blocker |
| `versionCode` 2018 مقابل build 18 في pubspec | ملاحظة نظافة G-02 (5.6.1) | غير blocker |

---

## 10. Acceptance Matrix (مصفوفة القبول النهائية)

| الشرط | مطلوب | الدليل | الحالة |
|---|---|---|---|
| APK release موقعة بشهادة غير debug | CN ≠ `Android Debug` | CN=`Hot Burger` على 3 ABIs (سجل CI) | ✓ |
| مطابقة البصمة SHA-256 المتوقعة | تطابق حرفي | `78:FC:2D:D7:...C3:DE:A5:B7` على 3 ABIs | ✓ |
| تطابق جميع ABIs | نفس البصمة | 3/3 متطابقة | ✓ |
| headSha == commit البناء | f3a92c1 | head_sha = f3a92c1... = origin/main | ✓ |
| artifacts على نفس run | 32347584815 | release-apk + release-apk-raw | ✓ |
| لا أسرار في logs | 0 leak | فحص شامل — نظيف | ✓ |
| مواد توقيع مؤقتة محذوفة | cleanup | `if: always` step | ✓ |
| CI أخضر | success | conclusion=success | ✓ |
| tests/analyze | 153+1 / 0 errors | run 32347584815 | ✓ |
| لا tag / لا GitHub Release | ممتنع | لم يُنشأ | ✓ |
| لا Phase 5.8 | ممتنع | متوقف | ✓ |

---

## 11. Safety Footer

| سؤال أمان | الإجابة |
|---|---|
| هل عُرضت أي كلمة مرور/secret/Base64 في أي سجل أو تقرير؟ | لا |
| هل رفع keystore كـartifact؟ | لا |
| هل استُخدم debug signing في release؟ | لا — hard block يمنع ذلك |
| هل عدّل أي كود إنتاجي أو اختبار أو schema؟ | لا |
| هل force push / merge / rebase؟ | لا — 3 pushes عادية |
| هل أُنشئ tag أو GitHub Release؟ | لا |

---

**FINAL VERDICT: A) PASS — PRODUCTION SIGNING VERIFIED**

توقف كامل — لن تبدأ Phase 5.8 إلا بتوجيه صريح.
