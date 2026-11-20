import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../models/recipe.dart';
import '../widgets/recipe_card.dart';
import '../theme.dart';
import 'edit_profile_screen.dart';
import 'recipe_detail_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final int? userId; // ID профиля для просмотра (если null, используется currentUserId)
  final int? currentUserId; // ID текущего авторизованного пользователя
  final VoidCallback? onLogout;
  const ProfileScreen({super.key, this.userId, this.currentUserId, this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService api = ApiService();
  late int? currentUserId; // ID текущего пользователя
  late Future<User> _futureUser;
  late Future<List<Recipe>> _futureRecipes;
  late Future<List<Recipe>> _futureSavedRecipes;
  late int _displayUserId;

  @override
  void initState() {
    super.initState();
    // currentUserId - это ID авторизованного пользователя
    currentUserId = widget.currentUserId;
    // _displayUserId - это ID профиля, который мы просматриваем
    _displayUserId = widget.userId ?? currentUserId ?? 1;
    _futureUser = api.fetchUser(_displayUserId);
    _futureRecipes = api.fetchUserRecipes(_displayUserId);
    if (currentUserId != null) {
      _futureSavedRecipes = api.fetchSaved(currentUserId!);
    } else {
      _futureSavedRecipes = Future.value(<Recipe>[]);
    }
  }

  void _refreshSaved() {
    setState(() {
      if (currentUserId != null) {
        _futureSavedRecipes = api.fetchSaved(currentUserId!);
      } else {
        _futureSavedRecipes = Future.value(<Recipe>[]);
      }
    });
  }

  void _refreshProfile() {
    setState(() {
      _futureUser = api.fetchUser(_displayUserId);
      _futureRecipes = api.fetchUserRecipes(_displayUserId);
      if (currentUserId != null) {
        _futureSavedRecipes = api.fetchSaved(currentUserId!);
      } else {
        _futureSavedRecipes = Future.value(<Recipe>[]);
      }
    });
  }

  bool _isRecipeSaved(Recipe recipe, List<Recipe> savedRecipes) {
    return savedRecipes.any((saved) => saved.id == recipe.id);
  }


  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Выход', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppColors.card,
                    title: const Text('Выход', style: TextStyle(color: Colors.white)),
                    content: const Text(
                      'Вы уверены, что хотите выйти?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Отмена'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // Закрываем меню
                          // Вызываем callback выхода
                          widget.onLogout?.call();
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Выход'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<User>(
          future: _futureUser,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(child: Text('Ошибка: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
            }
            final user = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Кнопка "Назад" - НЕ выходит из профиля, только закрывает экран
                      IconButton(
                        onPressed: () {
                          // Безопасный возврат - НЕ влияет на авторизацию
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const Spacer(),
                      const Text('Профиль', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (currentUserId != null && _displayUserId == currentUserId)
                        IconButton(
                          onPressed: () => _showSettingsMenu(context),
                          icon: const Icon(Icons.settings, color: Colors.white),
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: AppColors.chip,
                          backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                              ? (user.avatarUrl!.startsWith('data:image')
                                  ? _buildImageFromBase64(user.avatarUrl!)
                                  : NetworkImage(user.avatarUrl!))
                              : null,
                          child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                              ? const Icon(Icons.person, size: 44)
                              : null,
                        ),
                        const SizedBox(height: 10),
                        Text(user.username, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        if (user.bio != null && user.bio!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              user.bio!,
                              style: const TextStyle(color: AppColors.muted),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 14),
                        if (currentUserId != null && _displayUserId == currentUserId)
                          SizedBox(
                            width: 220,
                            child: FilledButton(
                              onPressed: () async {
                                final updated = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditProfileScreen(user: user),
                                  ),
                                );
                                if (updated != null) {
                                  setState(() {
                                    _futureUser = api.fetchUser(_displayUserId);
                                    _futureRecipes = api.fetchUserRecipes(_displayUserId);
                                  });
                                }
                              },
                              style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
                              child: const Text('Редактировать'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Рецепты автора',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<dynamic>>(
                    future: Future.wait([_futureRecipes, _futureSavedRecipes]),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Ошибка загрузки рецептов: ${snapshot.error}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }
                      final recipes = snapshot.data![0] as List<Recipe>;
                      final savedRecipes = snapshot.data![1] as List<Recipe>;
                      if (recipes.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              'У этого автора пока нет рецептов',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: recipes.map<Widget>((recipe) {
                          return CompactRecipeTile(
                            recipe: recipe,
                            showHeart: true,
                            userId: currentUserId ?? 1,
                            isSaved: _isRecipeSaved(recipe, savedRecipes),
                            onSavedChanged: _refreshSaved,
                            onAuthorTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProfileScreen(userId: recipe.authorId, currentUserId: currentUserId),
                                ),
                              );
                            },
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RecipeDetailScreen(
                                    recipe: recipe,
                                    userId: currentUserId ?? 1,
                                    isSaved: _isRecipeSaved(recipe, savedRecipes),
                                    onSavedChanged: _refreshSaved,
                                  ),
                                ),
                              );
                              _refreshSaved();
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  ImageProvider _buildImageFromBase64(String base64String) {
    try {
      final parts = base64String.split(',');
      if (parts.length < 2) throw Exception('Invalid data URI format');
      final bytes = base64Decode(parts.sublist(1).join(','));
      return MemoryImage(bytes);
    } catch (e) {
      return const AssetImage(''); // Fallback
    }
  }
}


