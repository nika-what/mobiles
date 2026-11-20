import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../theme.dart';
import '../screens/recipe_detail_screen.dart';
import '../screens/edit_recipe_screen.dart';
import '../screens/profile_screen.dart';

class EditableRecipeTile extends StatelessWidget {
  final Recipe recipe;
  final int userId;
  final VoidCallback? onRecipeUpdated;
  final VoidCallback? onRecipeDeleted;

  const EditableRecipeTile({
    super.key,
    required this.recipe,
    required this.userId,
    this.onRecipeUpdated,
    this.onRecipeDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecipeDetailScreen(
                    recipe: recipe,
                    userId: userId,
                    onRecipeUpdated: onRecipeUpdated,
                    onRecipeDeleted: onRecipeDeleted,
                  ),
                ),
              );
              // Обновляем список после возврата, чтобы показать обновленный рейтинг
              onRecipeUpdated?.call();
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 86,
                height: 86,
                child: _buildRecipeImage(recipe.imageUrl),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecipeDetailScreen(
                      recipe: recipe,
                      userId: userId,
                      onRecipeUpdated: onRecipeUpdated,
                      onRecipeDeleted: onRecipeDeleted,
                    ),
                  ),
                );
                // Обновляем список после возврата, чтобы показать обновленный рейтинг
                onRecipeUpdated?.call();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (recipe.authorName != null && recipe.authorName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(userId: recipe.authorId, currentUserId: userId),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline, size: 12, color: AppColors.muted),
                            const SizedBox(width: 4),
                            Text(
                              recipe.authorName!,
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
                  if (recipe.description != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        recipe.description!,
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
                        '${recipe.cookTimeMinutes ?? 30} мин',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        (recipe.rating ?? 0.0).toStringAsFixed(1),
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            onSelected: (value) async {
              if (value == 'edit') {
                final updated = await Navigator.push<Recipe>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditRecipeScreen(recipe: recipe),
                  ),
                );
                if (updated != null && context.mounted) {
                  onRecipeUpdated?.call();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Рецепт обновлен'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Удалить рецепт?'),
                    content: const Text('Вы уверены, что хотите удалить этот рецепт? Это действие нельзя отменить.'),
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
                  onRecipeDeleted?.call();
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 8),
                    Text('Редактировать'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Удалить', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: AppColors.chip,
        child: const Icon(Icons.restaurant_menu, size: 40, color: AppColors.textPrimary),
      );
    }

    if (imageUrl.startsWith('data:image')) {
      try {
        final parts = imageUrl.split(',');
        if (parts.length < 2) return _buildPlaceholder();
        final base64String = parts.sublist(1).join(',');
        final bytes = base64Decode(base64String);
        if (bytes.isEmpty) return _buildPlaceholder();
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (e) {
        return _buildPlaceholder();
      }
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.chip,
      child: const Icon(Icons.broken_image, size: 40, color: AppColors.textPrimary),
    );
  }
}

