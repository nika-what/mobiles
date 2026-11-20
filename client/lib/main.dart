import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/saved_screen.dart';
import 'screens/my_recipes_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/add_recipe_screen.dart';
import 'screens/login_screen.dart';
import 'theme.dart';
import 'services/auth_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Загружаем сохраненный userId при запуске
  final savedUserId = await AuthStorage.getUserId();
  runApp(RecipesApp(userId: savedUserId));
}

class RecipesApp extends StatefulWidget {
  final int? userId; // ID авторизованного пользователя
  const RecipesApp({super.key, this.userId});

  @override
  State<RecipesApp> createState() => _RecipesAppState();
}

class _RecipesAppState extends State<RecipesApp> {
  int _currentIndex = 0;
  int _refreshKey = 0; // Ключ для принудительного обновления
  int? _userId;

  @override
  void initState() {
    super.initState();
    _userId = widget.userId; // Используем переданный userId или null (показываем экран входа)
  }

  List<Widget> get screens {
    if (_userId == null) return [];
    return [
      HomeScreen(key: ValueKey('home_$_refreshKey'), userId: _userId!),
      SavedScreen(key: ValueKey('saved_$_refreshKey'), userId: _userId!),
      AddRecipeScreen(key: ValueKey('add_$_refreshKey'), userId: _userId!, onRecipeAdded: refreshScreens),
      MyRecipesScreen(key: ValueKey('my_$_refreshKey'), userId: _userId!),
      ProfileScreen(
        key: ValueKey('profile_$_refreshKey'),
        userId: _userId,
        currentUserId: _userId,
        onLogout: handleLogout,
      ),
    ];
  }
  
  void refreshScreens() {
    setState(() {
      _refreshKey++;
    });
  }

  void handleLogout() async {
    // БЕЗОПАСНЫЙ выход: очищаем сохраненные данные авторизации
    // Выход происходит ТОЛЬКО при явном нажатии кнопки "Выйти"
    await AuthStorage.clearUserId();
    setState(() {
      _userId = null;
    });
  }


  @override
  Widget build(BuildContext context) {
    // Если пользователь не авторизован, показываем экран входа
    if (_userId == null) {
      return MaterialApp(
        title: 'Recipes MVP',
        theme: buildAppTheme(),
        home: LoginScreen(
          onLoginSuccess: (userId) {
            setState(() {
              _userId = userId;
            });
          },
        ),
      );
    }

    return MaterialApp(
      title: 'Recipes MVP',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: screens[_currentIndex],
        bottomNavigationBar: NavigationBar(
          height: 68,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
            // Обновляем списки при переключении на главную или "Мои рецепты"
            if (index == 0 || index == 3) {
              refreshScreens();
            }
          },
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Главная'),
            NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Сохранено'),
            NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Добавить'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Мои'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Профиль'),
          ],
        ),
      ),
    );
  }
}


