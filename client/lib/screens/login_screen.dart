import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../theme.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  final Function(int)? onLoginSuccess;
  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  final _registerEmailCtrl = TextEditingController();
  final _registerPasswordCtrl = TextEditingController();
  final _registerPasswordConfirmCtrl = TextEditingController();
  final _registerUsernameCtrl = TextEditingController();
  
  final ApiService api = ApiService();
  bool _isLoading = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _registerEmailCtrl.dispose();
    _registerPasswordCtrl.dispose();
    _registerPasswordConfirmCtrl.dispose();
    _registerUsernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = await api.login(_loginEmailCtrl.text.trim(), _loginPasswordCtrl.text);
      if (!mounted) return;
      // Сохраняем userId для автоматического входа при следующем запуске
      await AuthStorage.saveUserId(user.id);
      // Вызываем callback или переходим в приложение
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!(user.id);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => RecipesApp(userId: user.id)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      String errorMessage = 'Ошибка входа';
      if (e.toString().contains('Неверный email или пароль')) {
        errorMessage = 'Неверный email или пароль';
      } else if (e.toString().contains('detail')) {
        errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('detail', '');
      } else {
        errorMessage = 'Ошибка входа: ${e.toString().replaceAll('Exception: ', '')}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_registerPasswordCtrl.text != _registerPasswordConfirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароли не совпадают')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final user = await api.register(
        email: _registerEmailCtrl.text.trim(),
        password: _registerPasswordCtrl.text,
        username: _registerUsernameCtrl.text.trim(),
      );
      if (!mounted) return;
      // Сохраняем userId для автоматического входа при следующем запуске
      await AuthStorage.saveUserId(user.id);
      // После регистрации автоматически входим
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!(user.id);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => RecipesApp(userId: user.id)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      String errorMessage = 'Ошибка регистрации';
      if (e.toString().contains('Email уже зарегистрирован')) {
        errorMessage = 'Email уже зарегистрирован';
      } else if (e.toString().contains('Username already exists')) {
        errorMessage = 'Имя пользователя уже занято';
      } else if (e.toString().contains('Пароли не совпадают')) {
        errorMessage = 'Пароли не совпадают';
      } else if (e.toString().contains('detail')) {
        errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('detail', '');
      } else {
        errorMessage = 'Ошибка регистрации: ${e.toString().replaceAll('Exception: ', '')}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Рецепты',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        labelColor: Colors.white,
                        unselectedLabelColor: AppColors.muted,
                        indicatorColor: AppColors.accent,
                        tabs: const [
                          Tab(text: 'Вход'),
                          Tab(text: 'Регистрация'),
                        ],
                      ),
                      SizedBox(
                        height: 400,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Вкладка входа
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: _loginEmailCtrl,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: const InputDecoration(
                                        labelText: 'Почта',
                                        hintText: 'example@mail.com',
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Введите почту';
                                        }
                                        if (!value.contains('@')) {
                                          return 'Введите корректную почту';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _loginPasswordCtrl,
                                      obscureText: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Пароль',
                                      ),
                                      validator: (value) =>
                                          value == null || value.isEmpty ? 'Введите пароль' : null,
                                    ),
                                    const SizedBox(height: 24),
                                    FilledButton(
                                      onPressed: _isLoading ? null : _handleLogin,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.accent,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                            )
                                          : const Text('Войти'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Вкладка регистрации
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: _registerEmailCtrl,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: const InputDecoration(
                                        labelText: 'Почта',
                                        hintText: 'example@mail.com',
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Введите почту';
                                        }
                                        if (!value.contains('@')) {
                                          return 'Введите корректную почту';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _registerUsernameCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Имя пользователя',
                                      ),
                                      validator: (value) =>
                                          value == null || value.isEmpty ? 'Введите имя пользователя' : null,
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _registerPasswordCtrl,
                                      obscureText: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Пароль',
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Введите пароль';
                                        }
                                        if (value.length < 6) {
                                          return 'Пароль должен быть не менее 6 символов';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _registerPasswordConfirmCtrl,
                                      obscureText: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Повторите пароль',
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Повторите пароль';
                                        }
                                        if (value != _registerPasswordCtrl.text) {
                                          return 'Пароли не совпадают';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 24),
                                    FilledButton(
                                      onPressed: _isLoading ? null : _handleRegister,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.accent,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                            )
                                          : const Text('Зарегистрироваться'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

