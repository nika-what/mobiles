import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../screens/recipe_detail_screen.dart';

Widget _buildRecipeImage(String? imageUrl, {double? iconSize}) {
  final defaultIconSize = iconSize ?? 48;
  if (imageUrl == null || imageUrl.isEmpty) {
    return Container(
      color: AppColors.chip,
      child: Icon(Icons.restaurant_menu, size: defaultIconSize, color: AppColors.textPrimary),
    );
  }
  
  // Проверяем, является ли это base64 изображением
  if (imageUrl.startsWith('data:image')) {
    try {
      // Разделяем data URI на части
      final parts = imageUrl.split(',');
      if (parts.length < 2) {
        throw Exception('Invalid data URI format');
      }
      final base64String = parts.sublist(1).join(','); // На случай, если в base64 есть запятые
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
          debugPrint('Error loading base64 image: $error');
          return Container(
            color: AppColors.chip,
            child: Icon(Icons.broken_image, size: defaultIconSize, color: AppColors.textPrimary),
          );
        },
      );
    } catch (e) {
      debugPrint('Error decoding base64 image: $e');
      return Container(
        color: AppColors.chip,
        child: Icon(Icons.broken_image, size: defaultIconSize, color: AppColors.textPrimary),
      );
    }
  }
  
  // Обычный URL
  return Image.network(
    imageUrl,
    fit: BoxFit.cover,
    width: double.infinity,
    height: double.infinity,
    loadingBuilder: (context, child, loadingProgress) {
      if (loadingProgress == null) return child;
      return Container(
        color: AppColors.chip,
        child: Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                : null,
            color: AppColors.accent,
          ),
        ),
      );
    },
    errorBuilder: (context, error, stackTrace) {
      debugPrint('Error loading network image: $error');
      return Container(
        color: AppColors.chip,
        child: Icon(Icons.broken_image, size: defaultIconSize, color: AppColors.textPrimary),
      );
    },
  );
}

class FeaturedRecipeCard extends StatefulWidget {
  final Recipe recipe;
  final int userId;
  final bool isSaved;
  final VoidCallback? onSavedChanged;
  final VoidCallback? onAuthorTap;
  const FeaturedRecipeCard({
    super.key,
    required this.recipe,
    required this.userId,
    this.isSaved = false,
    this.onSavedChanged,
    this.onAuthorTap,
  });

  @override
  State<FeaturedRecipeCard> createState() => _FeaturedRecipeCardState();
}

class _FeaturedRecipeCardState extends State<FeaturedRecipeCard> {
  late bool _isSaved;
  bool _isToggling = false;
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _isSaved = widget.isSaved;
  }

  @override
  void didUpdateWidget(FeaturedRecipeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSaved != widget.isSaved) {
      _isSaved = widget.isSaved;
    }
  }

  Future<void> _toggleSaved() async {
    if (_isToggling || widget.recipe.id == null) return;
    setState(() {
      _isToggling = true;
    });
    try {
      if (_isSaved) {
        await _api.unsaveRecipe(widget.userId, widget.recipe.id!);
        setState(() => _isSaved = false);
      } else {
        await _api.saveRecipe(widget.userId, widget.recipe.id!);
        setState(() => _isSaved = true);
      }
      widget.onSavedChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isToggling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailScreen(
              recipe: widget.recipe,
              userId: widget.userId,
              isSaved: _isSaved,
              onSavedChanged: widget.onSavedChanged,
            ),
          ),
        );
        // Обновляем состояние после возврата, чтобы показать обновленный рейтинг
        widget.onSavedChanged?.call();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
                child: SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: _buildRecipeImage(widget.recipe.imageUrl),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.recipe.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.recipe.authorName != null && widget.recipe.authorName!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: GestureDetector(
                              onTap: widget.onAuthorTap,
                              child: Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 14, color: AppColors.muted),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.recipe.authorName!,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (widget.recipe.description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          widget.recipe.description!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.timer, size: 16, color: AppColors.muted),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.recipe.cookTimeMinutes ?? 45} мин',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(width: 14),
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 6),
                        Text(
                          (widget.recipe.rating ?? 0.0).toStringAsFixed(1),
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 14,
            right: 14,
            child: Material(
              color: AppColors.chip,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: _isToggling ? null : _toggleSaved,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: _isToggling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
                        )
                      : Icon(
                          _isSaved ? Icons.favorite : Icons.favorite_border,
                          color: _isSaved ? Colors.red : AppColors.textPrimary,
                          size: 20,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class CompactRecipeTile extends StatefulWidget {
  final Recipe recipe;
  final bool showHeart;
  final int? userId;
  final bool isSaved;
  final VoidCallback? onSavedChanged;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onTap;
  const CompactRecipeTile({
    super.key,
    required this.recipe,
    this.showHeart = false,
    this.userId,
    this.isSaved = false,
    this.onSavedChanged,
    this.onAuthorTap,
    this.onTap,
  });

  @override
  State<CompactRecipeTile> createState() => _CompactRecipeTileState();
}

class _CompactRecipeTileState extends State<CompactRecipeTile> {
  late bool _isSaved;
  bool _isToggling = false;
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _isSaved = widget.isSaved;
  }

  @override
  void didUpdateWidget(CompactRecipeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSaved != widget.isSaved) {
      _isSaved = widget.isSaved;
    }
  }

  Future<void> _toggleSaved() async {
    if (_isToggling || widget.userId == null || widget.recipe.id == null) return;
    setState(() {
      _isToggling = true;
    });
    try {
      if (_isSaved) {
        await _api.unsaveRecipe(widget.userId!, widget.recipe.id!);
        setState(() => _isSaved = false);
      } else {
        await _api.saveRecipe(widget.userId!, widget.recipe.id!);
        setState(() => _isSaved = true);
      }
      widget.onSavedChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isToggling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap ?? () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailScreen(
              recipe: widget.recipe,
              userId: widget.userId ?? 1,
              isSaved: _isSaved,
              onSavedChanged: widget.onSavedChanged,
            ),
          ),
        );
        // Обновляем состояние после возврата, чтобы показать обновленный рейтинг
        widget.onSavedChanged?.call();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 86,
                height: 86,
                child: _buildRecipeImage(widget.recipe.imageUrl, iconSize: 40),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipe.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.recipe.authorName != null && widget.recipe.authorName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: GestureDetector(
                        onTap: widget.onAuthorTap,
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline, size: 12, color: AppColors.muted),
                            const SizedBox(width: 4),
                            Text(
                              widget.recipe.authorName!,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (widget.recipe.description != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        widget.recipe.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 14, color: AppColors.muted),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.recipe.cookTimeMinutes ?? 30} мин',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        (widget.recipe.rating ?? 4.8).toStringAsFixed(1),
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  )
                ],
              ),
            ),
            if (widget.showHeart && widget.userId != null)
              IconButton(
                onPressed: _isToggling ? null : _toggleSaved,
                icon: _isToggling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
                      )
                    : Icon(
                        _isSaved ? Icons.favorite : Icons.favorite_border,
                        color: _isSaved ? Colors.red : AppColors.textPrimary,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Карточка рецепта для отображения в сетке (Pinterest-style)
class RecipeGridCard extends StatelessWidget {
  final Recipe recipe;

  const RecipeGridCard({
    super.key,
    required this.recipe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Изображение
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildRecipeImage(recipe.imageUrl, iconSize: 40),
                  // Градиент снизу для читаемости текста
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Рейтинг
                  if (recipe.rating != null && recipe.rating! > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              recipe.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Информация
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Название
                    Text(
                      recipe.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Время приготовления
                    if (recipe.cookTimeMinutes != null)
                      Row(
                        children: [
                          const Icon(Icons.timer, size: 14, color: AppColors.muted),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.cookTimeMinutes} мин',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
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
}


