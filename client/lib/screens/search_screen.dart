import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/recipe.dart';
import '../widgets/recipe_card.dart';
import '../theme.dart';
import 'recipe_detail_screen.dart';
import 'profile_screen.dart';
import 'dart:convert';

class SearchScreen extends StatefulWidget {
  final int userId;
  const SearchScreen({super.key, required this.userId});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  String _searchQuery = '';
  Future<List<Recipe>>? _searchFuture;
  Future<List<String>>? _suggestionsFuture;
  Timer? _searchDebounce;
  Timer? _suggestionsDebounce;
  
  // Популярные запросы
  final List<String> _popularSearches = [
    'Пирог',
    'Салат',
    'Суп',
    'Десерт',
    'Завтрак',
    'Обед',
    'Ужин',
    'Выпечка',
  ];
  
  // Недавние поиски (можно сохранять в SharedPreferences)
  final List<String> _recentSearches = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _suggestionsDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() {
      _showSuggestions = _searchFocusNode.hasFocus && _searchController.text.isEmpty;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    
    // Отменяем предыдущие таймеры
    _searchDebounce?.cancel();
    _suggestionsDebounce?.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchFuture = null;
        _suggestionsFuture = null;
        _showSuggestions = _searchFocusNode.hasFocus;
      });
      return;
    }
    
    // Загружаем предложения с небольшой задержкой
    _suggestionsDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted && query.length >= 2) {
        setState(() {
          _suggestionsFuture = api.getSearchSuggestions(query);
        });
      }
    });
    
    // Выполняем поиск с задержкой
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted && query != _searchQuery) {
        setState(() {
          _searchQuery = query;
          _searchFuture = api.searchRecipes(query);
          _showSuggestions = false;
          // Добавляем в недавние поиски
          if (!_recentSearches.contains(query)) {
            _recentSearches.insert(0, query);
            if (_recentSearches.length > 10) {
              _recentSearches.removeLast();
            }
          }
        });
      }
    });
  }

  void _performSearch(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    _searchFocusNode.unfocus();
    setState(() {
      _searchQuery = query;
      _searchFuture = api.searchRecipes(query);
      _showSuggestions = false;
      if (!_recentSearches.contains(query)) {
        _recentSearches.insert(0, query);
        if (_recentSearches.length > 10) {
          _recentSearches.removeLast();
        }
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.requestFocus();
    setState(() {
      _searchQuery = '';
      _searchFuture = null;
      _suggestionsFuture = null;
      _showSuggestions = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Поисковая строка
            _buildSearchBar(),
            
            // Контент
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Поиск рецептов...',
                hintStyle: TextStyle(color: AppColors.muted),
                prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.muted),
                        onPressed: _clearSearch,
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            TextButton(
              onPressed: () {
                _searchFocusNode.unfocus();
                setState(() {
                  _showSuggestions = false;
                });
              },
              child: const Text('Отмена', style: TextStyle(color: AppColors.accent)),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // Если есть поисковый запрос, показываем результаты
    if (_searchQuery.isNotEmpty) {
      return _buildSearchResults();
    }
    
    // Если показываем предложения
    if (_showSuggestions) {
      return _buildSuggestions();
    }
    
    // Пустое состояние
    return _buildEmptyState();
  }

  Widget _buildSearchResults() {
    return FutureBuilder<List<Recipe>>(
      future: _searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.muted, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Ошибка при поиске',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _searchFuture = api.searchRecipes(_searchQuery);
                    });
                  },
                  child: const Text('Повторить', style: TextStyle(color: AppColors.accent)),
                ),
              ],
            ),
          );
        }
        
        final results = snapshot.data ?? [];
        
        if (results.isEmpty) {
          return _buildEmptyResults();
        }
        
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Найдено: ${results.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: _clearSearch,
                      child: const Text(
                        'Очистить',
                        style: TextStyle(color: AppColors.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final recipe = results[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecipeDetailScreen(
                              recipe: recipe,
                              userId: widget.userId,
                            ),
                          ),
                        );
                      },
                      child: RecipeGridCard(recipe: recipe),
                    );
                  },
                  childCount: results.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSuggestions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Автодополнение
          if (_searchController.text.isNotEmpty && _searchController.text.length >= 2)
            FutureBuilder<List<String>>(
              future: _suggestionsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Предложения',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...snapshot.data!.map((suggestion) => _buildSuggestionItem(
                        suggestion,
                        Icons.search,
                        () => _performSearch(suggestion),
                      )),
                      const SizedBox(height: 24),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          
          // Недавние поиски
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Недавние поиски',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _recentSearches.clear();
                    });
                  },
                  child: const Text(
                    'Очистить',
                    style: TextStyle(color: AppColors.accent, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._recentSearches.map((search) => _buildSuggestionItem(
              search,
              Icons.history,
              () => _performSearch(search),
            )),
            const SizedBox(height: 24),
          ],
          
          // Популярные запросы
          const Text(
            'Популярные запросы',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _popularSearches.map((search) => _buildChip(
              search,
              () => _performSearch(search),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(String text, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.muted, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: AppColors.muted, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.muted.withOpacity(0.3)),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, color: AppColors.muted, size: 64),
          const SizedBox(height: 16),
          Text(
            'Начните поиск рецептов',
            style: TextStyle(color: AppColors.muted, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, color: AppColors.muted, size: 64),
          const SizedBox(height: 16),
          Text(
            'Ничего не найдено',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Попробуйте изменить запрос',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _clearSearch,
            child: const Text('Очистить поиск', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeImageForGrid(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: AppColors.chip,
        child: const Icon(Icons.restaurant_menu, size: 40, color: AppColors.textPrimary),
      );
    }
    
    if (imageUrl.startsWith('data:image')) {
      try {
        final parts = imageUrl.split(',');
        if (parts.length < 2) {
          throw Exception('Invalid data URI format');
        }
        final base64String = parts.sublist(1).join(',');
        final bytes = base64Decode(base64String);
        
        if (bytes.isEmpty) {
          throw Exception('Empty image data');
        }
        
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: AppColors.chip,
              child: const Icon(Icons.broken_image, size: 40, color: AppColors.textPrimary),
            );
          },
        );
      } catch (e) {
        return Container(
          color: AppColors.chip,
          child: const Icon(Icons.broken_image, size: 40, color: AppColors.textPrimary),
        );
      }
    }
    
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: AppColors.chip,
          child: const Icon(Icons.broken_image, size: 40, color: AppColors.textPrimary),
        );
      },
    );
  }
}

