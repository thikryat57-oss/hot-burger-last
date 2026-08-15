# هيكل المشروع

## المجلدات الرئيسية

```
hot_burger/
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   └── constants.dart
│   │   ├── database/
│   │   │   └── database_helper.dart
│   │   └── theme/
│   │       └── app_theme.dart
│   ├── models/
│   │   └── models.dart
│   ├── providers/
│   │   └── app_provider.dart
│   ├── screens/
│   │   ├── auth/
│   │   │   └── login_screen.dart
│   │   ├── backup/
│   │   │   └── backup_screen.dart
│   │   ├── categories/
│   │   │   └── categories_screen.dart
│   │   ├── expenses/
│   │   │   └── expenses_screen.dart
│   │   ├── home/
│   │   │   └── home_screen.dart
│   │   ├── invoices/
│   │   │   ├── invoices_screen.dart
│   │   │   └── invoice_detail_screen.dart
│   │   ├── products/
│   │   │   └── products_screen.dart
│   │   ├── reports/
│   │   │   └── reports_screen.dart
│   │   └── sales/
│   │       └── sales_screen.dart
│   └── main.dart
├── android/
├── ios/
├── test/
├── pubspec.yaml
├── README.md
├── CHANGELOG.md
└── PROJECT_STRUCTURE.md
```

---

## مسؤولة كل مجلد

### `lib/core/constants/`
**الملف:** `constants.dart`
**المسؤولية:** تعريف الثوابت العامة للتطبيق (اسم المدير، كلمة المرور الافتراضية، الألوان الأساسية، الإعدادات العامة).

---

### `lib/core/database/`
**الملف:** `database_helper.dart`
**المسؤولية:** إدارة قاعدة البيانات المحلية بالكامل. يتضمن:
- إنشاء قاعدة البيانات
- تعريف الجداول السبعة (users, categories, products, invoices, invoice_items, expenses, raw_materials)
- عمليات CRUD لكل جدول
- إدخال المستخدم الافتراضي الوحيد

---

### `lib/core/theme/`
**الملف:** `app_theme.dart`
**المسؤولية:** تعريف ثيم التطبيق والألوان المستخدمة في جميع الشاشات (اللون الأساسي، ألوان الخلفية، ألوان النصوص، ألوان الخطأ والنجاح).

---

### `lib/models/`
**الملف:** `models.dart`
**المسؤولية:** تعريف نماذج البيانات (Data Models) لجميع الكيانات مع دوال `toMap` و `fromMap` للتحويل بين الكائنات وقاعدة البيانات.

---

### `lib/providers/`
**الملف:** `app_provider.dart`
**المسؤولية:** إدارة الحالة المركزية للتطبيق. يتضمن:
- تهيئة قاعدة البيانات
- منطق تسجيل الدخول
- جميع عمليات CRUD للمنتجات والتصنيفات والفواتير والمصروفات
- حساب التقارير (يومي وشهري)
- إدارة السلة المؤقتة للمبيعات

---

### `lib/screens/auth/`
**الملف:** `login_screen.dart`
**المسؤولية:** شاشة تسجيل الدخول للمستخدم الواحد (المدير).

---

### `lib/screens/home/`
**الملف:** `home_screen.dart`
**المسؤولية:** القائمة الرئيسية مع شريط التنقل السفلي (Bottom Navigation) للوصول إلى جميع الشاشات.

---

### `lib/screens/products/`
**الملف:** `products_screen.dart`
**المسؤولية:** إدارة المنتجات (إضافة، تعديل، حذف) مع ربطها بالتصنيفات.

---

### `lib/screens/categories/`
**الملف:** `categories_screen.dart`
**المسؤولية:** إدارة التصنيفات (إضافة، تعديل، تفعيل/تعطيل، حذف).

---

### `lib/screens/sales/`
**الملف:** `sales_screen.dart`
**المسؤولية:** شاشة المبيعات الاحترافية مع سلة المشتريات، فلترة التصنيفات، البحث، وحفظ الفاتورة.

---

### `lib/screens/invoices/`
**الملفات:** `invoices_screen.dart`, `invoice_detail_screen.dart`
**المسؤولية:** عرض قائمة الفواتير مع البحث برقم الفاتورة، وعرض تفاصيل كل فاتورة (البنود والإجمالي).

---

### `lib/screens/expenses/`
**الملف:** `expenses_screen.dart`
**المسؤولية:** إدارة المصروفات (إضافة، تعديل، حذف).

---

### `lib/screens/reports/`
**الملف:** `reports_screen.dart`
**المسؤولية:** عرض التقارير اليومية والشهرية (إجمالي المبيعات، عدد الفواتير، إجمالي المصروفات، صافي الربح).

---

### `lib/screens/backup/`
**الملف:** `backup_screen.dart`
**المسؤولية:** تصدير واستيراد قاعدة البيانات كملف `.db` مع إمكانية المشاركة.

---

## المبادئ المعمارية المتبعة

| المبدأ | التطبيق |
|--------|---------|
| **Clean Architecture** | فصل الطبقات (core → models → providers → screens) |
| **Offline First** | كل البيانات محلية عبر sqflite |
| **Single Responsibility** | كل ملف مسؤول عن وظيفة واحدة |
| **Provider Pattern** | إدارة الحالة المركزية |
| **RTL Support** | واجهة عربية كاملة |
