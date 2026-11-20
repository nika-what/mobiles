import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/star_rating.dart';
import 'edit_recipe_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  final int userId;
  final bool isSaved;
  final VoidCallback? onSavedChanged;
  final VoidCallback? onRecipeUpdated;
  final VoidCallback? onRecipeDeleted;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    required this.userId,
    this.isSaved = false,
    this.onSavedChanged,
    this.onRecipeUpdated,
    this.onRecipeDeleted,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final ApiService _api = ApiService();
  double? _userRating;
  double? _currentRating;
  bool _loadingRating = false;
  bool _submittingRating = false;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.recipe.rating;
    _loadUserRating();
  }

  Future<void> _loadUserRating() async {
    if (widget.recipe.id == null) return;
    setState(() => _loadingRating = true);
    try {
      final rating = await _api.getUserRating(widget.recipe.id!, widget.userId);
      setState(() {
        _userRating = rating;
        _loadingRating = false;
      });
    } catch (e) {
      setState(() => _loadingRating = false);
    }
  }

  Future<void> _onRatingChanged(double rating) async {
    if (widget.recipe.id == null) return;
    // Сразу показываем выбранную оценку для лучшего UX
    setState(() {
      _submittingRating = true;
      _userRating = rating;
    });
    try {
      final avgRating = await _api.rateRecipe(widget.recipe.id!, widget.userId, rating);
      // После успешного сохранения обновляем средний рейтинг и сохраняем оценку пользователя
      setState(() {
        _currentRating = avgRating;
        _userRating = rating; // Явно сохраняем оценку пользователя
        _submittingRating = false;
      });
      // Перезагружаем оценку пользователя с сервера для подтверждения
      await _loadUserRating();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Оценка сохранена'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // При ошибке перезагружаем оценку пользователя с сервера
      setState(() {
        _submittingRating = false;
      });
      await _loadUserRating(); // Перезагружаем, чтобы показать актуальное состояние
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при сохранении оценки: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 250,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildRecipeImage(widget.recipe.imageUrl),
                title: Text(
                  widget.recipe.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 3,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (widget.recipe.authorId == widget.userId) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () async {
                      final updated = await Navigator.push<Recipe>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditRecipeScreen(recipe: widget.recipe),
                        ),
                      );
                      if (updated != null && context.mounted) {
                        widget.onRecipeUpdated?.call();
                        Navigator.pop(context);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Удалить рецепт?'),
                          content: const Text('Вы уверены, что хотите удалить этот рецепт?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Отмена'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Удалить'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        try {
                          await _api.deleteRecipe(widget.recipe.id!);
                          widget.onRecipeDeleted?.call();
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ошибка: $e')),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
                IconButton(
                  icon: Icon(
                    widget.isSaved ? Icons.favorite : Icons.favorite_border,
                    color: widget.isSaved ? Colors.red : Colors.white,
                  ),
                  onPressed: () async {
                    try {
                      if (widget.isSaved) {
                        await _api.unsaveRecipe(widget.userId, widget.recipe.id!);
                      } else {
                        await _api.saveRecipe(widget.userId, widget.recipe.id!);
                      }
                      widget.onSavedChanged?.call();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ошибка: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.recipe.description != null && widget.recipe.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          widget.recipe.description!,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.white,
                              ),
                        ),
                      ),
                    Row(
                      children: [
                        if (widget.recipe.cookTimeMinutes != null) ...[
                          const Icon(Icons.timer, size: 20, color: AppColors.muted),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.recipe.cookTimeMinutes} мин',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(width: 20),
                        ],
                        if (widget.recipe.servings != null) ...[
                          const Icon(Icons.people, size: 20, color: AppColors.muted),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.recipe.servings} порций',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(width: 20),
                        ],
                        const Icon(Icons.star, size: 20, color: Colors.amber),
                        const SizedBox(width: 6),
                        Text(
                          (_currentRating ?? widget.recipe.rating ?? 0.0).toStringAsFixed(1),
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Оцените рецепт',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_loadingRating)
                            const Center(child: CircularProgressIndicator())
                          else
                            StarRating(
                              rating: _currentRating ?? widget.recipe.rating ?? 0.0,
                              userRating: _userRating,
                              onRatingChanged: _onRatingChanged,
                              starSize: 40,
                            ),
                          if (_submittingRating)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.recipe.tags != null && widget.recipe.tags!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.recipe.tags!.split(',').map((tag) {
                          final trimmedTag = tag.trim();
                          if (trimmedTag.isEmpty) return const SizedBox.shrink();
                          return Chip(
                            label: Text(trimmedTag),
                            backgroundColor: AppColors.chip,
                            labelStyle: const TextStyle(color: AppColors.textPrimary),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Инструкции',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.recipe.instructions,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: AppColors.chip,
        child: const Center(
          child: Icon(Icons.restaurant_menu, size: 80, color: AppColors.textPrimary),
        ),
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
        );
      } catch (e) {
        return Container(
          color: AppColors.chip,
          child: const Center(
            child: Icon(Icons.broken_image, size: 80, color: AppColors.textPrimary),
          ),
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
          child: const Center(
            child: Icon(Icons.broken_image, size: 80, color: AppColors.textPrimary),
          ),
        );
      },
    );
  }
}

