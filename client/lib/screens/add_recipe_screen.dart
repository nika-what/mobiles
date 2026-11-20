import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../models/recipe.dart';
import '../theme.dart';

class AddRecipeScreen extends StatefulWidget {
  final int userId;
  final VoidCallback? onRecipeAdded;
  const AddRecipeScreen({super.key, required this.userId, this.onRecipeAdded});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _instrCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _servingsCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  final ApiService api = ApiService();
  late final int userId;
  bool _submitting = false;
  
  @override
  void initState() {
    super.initState();
    userId = widget.userId;
  }
  XFile? _selectedImage;
  Uint8List? _imageBytes;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _instrCtrl.dispose();
    _tagsCtrl.dispose();
    _imageCtrl.dispose();
    _timeCtrl.dispose();
    _servingsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        Uint8List bytes;
        
        try {
          bytes = await image.readAsBytes();
        } catch (e) {
          // Если не удалось прочитать байты (например, blob URL на веб)
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось загрузить изображение. Используйте URL изображения вместо выбора файла.')),
          );
          return;
        }
        
        // Ограничиваем размер изображения (максимум 2MB для base64)
        if (bytes.length > 2 * 1024 * 1024) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Изображение слишком большое. Максимальный размер: 2MB')),
          );
          return;
        }
        
        setState(() {
          _selectedImage = image;
          _imageBytes = bytes;
        });
        
        // Конвертируем изображение в base64
        final base64Image = base64Encode(bytes);
        
        // Определяем MIME-тип по первым байтам (magic numbers)
        String mimeType = 'image/jpeg'; // По умолчанию
        
        if (bytes.length >= 4) {
          if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
            mimeType = 'image/jpeg';
          } else if (bytes.length >= 8 && 
                     bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 &&
                     bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A) {
            mimeType = 'image/png';
          } else if (bytes.length >= 3 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
            mimeType = 'image/gif';
          } else if (bytes.length >= 12 && 
                     bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
                     bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
            mimeType = 'image/webp';
          }
        }
        
        _imageCtrl.text = 'data:$mimeType;base64,$base64Image';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при выборе изображения: $e')),
      );
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
      _imageBytes = null;
      _imageCtrl.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final draft = Recipe(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        instructions: _instrCtrl.text.trim(),
        imageUrl: _imageCtrl.text.trim().isEmpty ? null : _imageCtrl.text.trim(),
        cookTimeMinutes: _timeCtrl.text.isEmpty ? null : int.tryParse(_timeCtrl.text),
        servings: _servingsCtrl.text.isEmpty ? null : int.tryParse(_servingsCtrl.text),
        tags: _tagsCtrl.text.trim().isEmpty ? null : _tagsCtrl.text.trim(),
        authorId: userId,
      );
      final createdRecipe = await api.createRecipe(draft);
      if (!mounted) return;
      
      // Очищаем форму
      _formKey.currentState!.reset();
      _titleCtrl.clear();
      _descCtrl.clear();
      _instrCtrl.clear();
      _tagsCtrl.clear();
      _imageCtrl.clear();
      _timeCtrl.clear();
      _servingsCtrl.clear();
      setState(() {
        _selectedImage = null;
        _imageBytes = null;
      });
      
      // Показываем сообщение об успехе
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Рецепт успешно добавлен!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Добавить рецепт', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: 'Название'),
                    validator: (value) => (value == null || value.isEmpty) ? 'Введите название' : null,
                  ),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(labelText: 'Краткое описание'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Изображение',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedImage != null)
                    Container(
                      height: 150,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _imageBytes != null
                                ? Image.memory(
                                    _imageBytes!,
                                    width: double.infinity,
                                    height: 150,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: AppColors.chip,
                                    child: const Icon(Icons.image, size: 48, color: AppColors.textPrimary),
                                  ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: _clearImage,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image),
                          label: const Text('Выбрать изображение'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.muted),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _imageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Или введите URL изображения',
                      hintText: 'https://example.com/image.jpg',
                    ),
                    readOnly: _selectedImage != null,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _timeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Время (мин)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _servingsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Порции'),
                        ),
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: _tagsCtrl,
                    decoration: const InputDecoration(labelText: 'Теги (через запятую)'),
                  ),
                  TextFormField(
                    controller: _instrCtrl,
                    decoration: const InputDecoration(labelText: 'Инструкции'),
                    maxLines: 4,
                    validator: (value) => (value == null || value.isEmpty) ? 'Введите инструкцию' : null,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                      ),
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.add),
                      label: const Text('Добавить'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

