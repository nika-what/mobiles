import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/recipe.dart';
import '../widgets/recipe_card.dart';
import '../theme.dart';
import 'recipe_detail_screen.dart';
import 'profile_screen.dart';

class SavedScreen extends StatefulWidget {
  final int userId;
  const SavedScreen({super.key, required this.userId});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final ApiService api = ApiService();
  late final int userId;
  
  late Future<List<Recipe>> _future;

  @override
  void initState() {
    super.initState();
    userId = widget.userId;
    _future = api.fetchSaved(userId);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async => setState(() => _future = api.fetchSaved(userId)),
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
              return const Center(child: Text('Нет сохранённых рецептов', style: TextStyle(color: Colors.white)));
            }
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: const Text('Сохранённые рецепты', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => CompactRecipeTile(
                      recipe: recipes[index],
                      showHeart: true,
                      userId: userId,
                      isSaved: true,
                      onSavedChanged: () => setState(() => _future = api.fetchSaved(userId)),
                      onAuthorTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileScreen(userId: recipes[index].authorId, currentUserId: userId),
                          ),
                        );
                      },
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecipeDetailScreen(
                              recipe: recipes[index],
                              userId: userId,
                              isSaved: true,
                              onSavedChanged: () => setState(() => _future = api.fetchSaved(userId)),
                            ),
                          ),
                        );
                        // Обновляем список после возврата, чтобы показать обновленный рейтинг
                        setState(() => _future = api.fetchSaved(userId));
                      },
                    ),
                    childCount: recipes.length,
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }
}


