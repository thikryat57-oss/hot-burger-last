import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  List<User> _users = [];
  int? _selectedUserId;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await context.read<AppProvider>().getActiveUsers();
    if (!mounted) return;
    setState(() {
      _users = users;
      if (users.length == 1) _selectedUserId = users.first.id;
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final success = await context.read<AppProvider>().login(_passwordController.text.trim(), userId: _selectedUserId);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      return;
    }

    _passwordController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('كلمة المرور غير صحيحة'), backgroundColor: AppTheme.errorColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF7F7), AppTheme.scaffoldBackground],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildBrand(),
                      const SizedBox(height: 32),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                          child: Column(
                            children: [
                              const Align(
                                alignment: Alignment.centerRight,
                                child: Text('تسجيل الدخول', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                              ),
                              const SizedBox(height: 6),
                              const Align(
                                alignment: Alignment.centerRight,
                                child: Text('أدخل رمز الدخول للمتابعة إلى النظام', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                              ),
                              const SizedBox(height: 22),
                              if (_users.isNotEmpty) ...[
                                DropdownButtonFormField<int>(
                                  value: _selectedUserId,
                                  decoration: const InputDecoration(
                                    labelText: 'المستخدم',
                                    prefixIcon: Icon(Icons.person_outline_rounded),
                                  ),
                                  items: _users.map((user) => DropdownMenuItem<int>(
                                    value: user.id,
                                    child: Text('${user.name} • ${user.role == 'manager' ? 'مدير' : 'كاشير'}'),
                                  )).toList(),
                                  onChanged: (value) => setState(() => _selectedUserId = value),
                                  validator: (value) => value == null ? 'اختر المستخدم' : null,
                                ),
                                const SizedBox(height: 14),
                              ],
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 22, letterSpacing: 7, fontWeight: FontWeight.w800),
                                keyboardType: TextInputType.number,
                                autofillHints: const [AutofillHints.password],
                                decoration: InputDecoration(
                                  labelText: 'رمز الدخول',
                                  hintText: '••••',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword ? 'إظهار الرمز' : 'إخفاء الرمز',
                                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) return 'الرجاء إدخال رمز الدخول';
                                  if (value.trim().length < 4) return 'يجب أن يتكون الرمز من 4 أرقام على الأقل';
                                  return null;
                                },
                                onFieldSubmitted: (_) => _isLoading ? null : _handleLogin(),
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: _isLoading ? null : _handleLogin,
                                icon: _isLoading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.login_rounded),
                                label: Text(_isLoading ? 'جارٍ التحقق...' : 'دخول آمن'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text('المستخدمون النشطون: ${_users.length}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(height: 5),
                      Text('الإصدار ${Constants.appVersion} • يعمل بدون إنترنت', style: const TextStyle(fontSize: 10, color: AppTheme.textHint)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Column(
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [AppTheme.primaryColor, AppTheme.primaryDark]),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.22), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: const Icon(Icons.local_dining_rounded, color: Colors.white, size: 46),
        ),
        const SizedBox(height: 18),
        const Text(Constants.appName, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.primaryColor)),
        const SizedBox(height: 4),
        const Text('نظام إدارة الكافتيريا الذكي', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
