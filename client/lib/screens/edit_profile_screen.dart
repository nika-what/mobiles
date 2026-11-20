import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../theme.dart';

class EditProfileScreen extends StatefulWidget {
  final User user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final ApiService api = ApiService();
  
  bool _submitting = false;
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.user.username; // Используем username как имя
    _usernameCtrl.text = widget.user.username;
    _bioCtrl.text = widget.user.bio ?? '';
    _avatarUrl = widget.user.avatarUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
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
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось загрузить изображение. Используйте URL изображения вместо выбора файла.')),
          );
          return;
        }

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

        final base64Image = base64Encode(bytes);
        String mimeType = 'image/jpeg';

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

        _avatarUrl = 'data:$mimeType;base64,$base64Image';
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
      _avatarUrl = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await api.updateUser(
        widget.user.id,
        username: _usernameCtrl.text.trim(),
        bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        avatarUrl: _avatarUrl,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Профиль обновлен'),
          backgroundColor: Colors.green,
        ),
      );
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Редактировать профиль'),
        backgroundColor: AppColors.card,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: AppColors.chip,
                            backgroundImage: _imageBytes != null
                                ? MemoryImage(_imageBytes!)
                                : (_avatarUrl != null && _avatarUrl!.startsWith('data:image'))
                                    ? _buildImageFromBase64(_avatarUrl!)
                                    : (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                        ? NetworkImage(_avatarUrl!)
                                        : null,
                            child: _imageBytes == null && (_avatarUrl == null || _avatarUrl!.isEmpty)
                                ? const Icon(Icons.person, size: 60, color: AppColors.textPrimary)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.accent,
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, size: 20, color: Colors.black),
                                onPressed: _pickImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_imageBytes != null || (_avatarUrl != null && _avatarUrl!.startsWith('data:image')))
                        TextButton(
                          onPressed: _clearImage,
                          child: const Text('Удалить фото', style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Имя',
                    hintText: 'Введите ваше имя',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Введите имя' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'UserName',
                    hintText: 'Введите username',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Введите username' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Обратная связь',
                    hintText: 'Расскажите о себе',
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 24),
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
                        : const Icon(Icons.save),
                    label: const Text('Сохранить'),
                  ),
                ),
              ],
            ),
          ),
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

