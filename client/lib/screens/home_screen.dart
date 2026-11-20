import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/recipe.dart';
import '../widgets/recipe_card.dart';
import '../theme.dart';
import 'recipe_detail_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'filters_screen.dart';

class HomeScreen extends StatefulWidget {
  final int userId;
  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService api = ApiService();
  late final int userId;
  late Future<List<Recipe>> _future;
  late Future<List<Recipe>> _savedFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Future<List<Recipe>>? _searchFuture;
  Timer? _searchDebounce;
  RecipeFilters _filters = RecipeFilters();

  @override
  void initState() {
    super.initState();
    userId = widget.userId;
    _future = api.fetchRecommended();
    _savedFuture = api.fetchSaved(userId);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Отменяем предыдущий таймер
    _searchDebounce?.cancel();
    
    final query = _searchController.text.trim();
    
    // Если запрос пустой, сразу очищаем поиск
    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchFuture = null;
      });
      return;
    }
    
    // Устанавливаем задержку перед поиском (debounce)
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted && query != _searchQuery) {
        setState(() {
          _searchQuery = query;
          _searchFuture = api.searchRecipes(query);
        });
      }
    });
  }

  void _refreshSaved() {
    setState(() {
      _savedFuture = api.fetchSaved(userId);
    });
  }

  void _refreshRecipes() {
    setState(() {
      if (_filters.hasActiveFilters) {
        _future = api.fetchRecipesWithFilters(_filters.toQueryParams());
      } else {
        _future = api.fetchRecommended();
      }
      _savedFuture = api.fetchSaved(userId);
    });
  }


  bool _isRecipeSaved(Recipe recipe, List<Recipe> savedRecipes) {
    return savedRecipes.any((saved) => saved.id == recipe.id);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async {
          setState(() {
            _future = api.fetchRecommended();
            _savedFuture = api.fetchSaved(userId);
          });
        },
        child: FutureBuilder<List<Recipe>>(
          future: _savedFuture,
          builder: (context, savedSnapshot) {
            final savedRecipes = savedSnapshot.data ?? [];
            
            // Если есть поисковый запрос, показываем результаты поиска
            if (_searchQuery.isNotEmpty) {
              return FutureBuilder<List<Recipe>>(
                future: _searchFuture,
                builder: (context, searchSnapshot) {
                  if (searchSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (searchSnapshot.hasError) {
                    return Center(child: Text('Ошибка: ${searchSnapshot.error}', style: const TextStyle(color: Colors.white)));
                  }
                  final searchResults = searchSnapshot.data ?? [];
                  
                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Рецепты', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                                  SizedBox(height: 4),
                                  Text('Найди свой идеальный рецепт', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                                ],
                              ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SearchScreen(userId: userId),
                                        ),
                                      );
                                    },
                                    child: TextField(
                                      enabled: false,
                                      decoration: InputDecoration(
                                        hintText: 'Поиск рецептов',
                                        prefixIcon: const Icon(Icons.search),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            'Найдено рецептов: ${searchResults.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => CompactRecipeTile(
                            recipe: searchResults[index],
                            showHeart: true,
                            userId: userId,
                            isSaved: _isRecipeSaved(searchResults[index], savedRecipes),
                            onSavedChanged: _refreshRecipes,
                            onAuthorTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProfileScreen(userId: searchResults[index].authorId, currentUserId: userId),
                                ),
                              );
                            },
                          ),
                          childCount: searchResults.length,
                        ),
                      ),
                      if (searchResults.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: Text('Рецепты не найдены', style: TextStyle(color: Colors.white))),
                        ),
                    ],
                  );
                },
              );
            }
            
            // Обычный режим - показываем рекомендуемые рецепты
            return FutureBuilder<List<Recipe>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
                }
                final recipes = snapshot.data ?? [];
                final featured = recipes.isNotEmpty ? recipes.first : null;
                final list = recipes.length > 1 ? recipes.sublist(1) : <Recipe>[];
                
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Рецепты', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                                SizedBox(height: 4),
                                Text('Найди свой идеальный рецепт', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SearchScreen(userId: userId),
                                  ),
                                );
                              },
                              child: TextField(
                                controller: _searchController,
                                enabled: false,
                                decoration: InputDecoration(
                                  hintText: 'Поиск рецептов',
                                  prefixIcon: const Icon(Icons.search),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (featured != null)
                      SliverToBoxAdapter(
                        child: FeaturedRecipeCard(
                          recipe: featured,
                          userId: userId,
                          isSaved: _isRecipeSaved(featured, savedRecipes),
                          onSavedChanged: _refreshRecipes,
                          onAuthorTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(userId: featured.authorId, currentUserId: userId),
                              ),
                            );
                          },
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('Популярные рецепты', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                            Text('Все', style: TextStyle(color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => CompactRecipeTile(
                          recipe: list[index],
                          showHeart: true,
                          userId: userId,
                          isSaved: _isRecipeSaved(list[index], savedRecipes),
                          onSavedChanged: _refreshRecipes,
                          onAuthorTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(userId: list[index].authorId, currentUserId: userId),
                              ),
                            );
                          },
                        ),
                        childCount: list.length,
                      ),
                    ),
                    if (list.isEmpty && featured == null)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: Text('Нет рецептов', style: TextStyle(color: Colors.white))),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}


