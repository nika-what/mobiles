import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const String _userIdKey = 'user_id';

  /// Сохраняет ID пользователя
  static Future<void> saveUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, userId);
  }

  /// Получает сохраненный ID пользователя
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  /// Очищает сохраненные данные авторизации
  static Future<void> clearUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
  }
}







