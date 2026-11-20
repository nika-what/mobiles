import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/recipe.dart';
import '../widgets/editable_recipe_tile.dart';
import '../theme.dart';
import 'profile_screen.dart';

class MyRecipesScreen extends StatefulWidget {
  final int userId;
  const MyRecipesScreen({super.key, required this.userId});

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen> {
  final ApiService api = ApiService();
  late final int userId;
  
  late Future<List<Recipe>> _future;

  @override
  void initState() {
    super.initState();
    userId = widget.userId;
    _future = api.fetchUserRecipes(userId);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async => setState(() => _future = api.fetchUserRecipes(userId)),
        child: FutureBuilder<List<Recipe>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Ошибка: ${snapshot.error}', style: TextStyle(color: Colors.white)));
            }
            final recipes = snapshot.data ?? [];
            if (recipes.isEmpty) {
              return const Center(child: Text('Пока нет рецептов', style: TextStyle(color: Colors.white)));
            }
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Мои рецепты', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                        Text('Все', style: TextStyle(color: AppColors.muted)),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => EditableRecipeTile(
                      recipe: recipes[index],
                      userId: userId,
                      onRecipeUpdated: () => setState(() => _future = api.fetchUserRecipes(userId)),
                      onRecipeDeleted: () async {
                        final api = ApiService();
                        try {
                          await api.deleteRecipe(recipes[index].id!);
                          if (mounted) {
                            setState(() => _future = api.fetchUserRecipes(userId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Рецепт удален'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ошибка при удалении: $e')),
                            );
                          }
                        }
                      },
                    ),
                    childCount: recipes.length,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}


