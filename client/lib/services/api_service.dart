import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/recipe.dart';
import '../models/user.dart';

class ApiService {
  // Adjust when running on device/emulator
  // Убедитесь, что URL сервера доступен с вашего устройства
  static const String baseUrl = 'https://662d0bd5-11ca-4dae-b061-3f7d7b023522-00-1pniluegz7xbx.spock.replit.dev';
  
  // Создаем HTTP клиент, который игнорирует ошибки SSL для разработки
  static http.Client _createHttpClient() {
    // Для Android/iOS используем кастомный клиент, который игнорирует SSL ошибки
    if (Platform.isAndroid || Platform.isIOS) {
      final httpClient = HttpClient();
      // Игнорируем ошибки сертификата для разработки
      httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      return IOClient(httpClient);
    }
    // Для других платформ используем стандартный клиент
    return http.Client();
  }
  
  // Используем кастомный клиент для всех запросов
  static final http.Client _client = _createHttpClient();

  /// Обрезает пароль до 72 байт для совместимости с bcrypt
  String _truncatePassword(String password) {
    final passwordBytes = utf8.encode(password);
    if (passwordBytes.length > 72) {
      final truncatedBytes = passwordBytes.sublist(0, 72);
      return utf8.decode(truncatedBytes, allowMalformed: true);
    }
    return password;
  }

  Future<List<Recipe>> fetchRecommended() async {
    final res = await _client.get(Uri.parse('$baseUrl/recipes/recommended'));
    _ensureSuccess(res);
    final data = jsonDecode(res.body) as List;
    return data.map((e) => Recipe.fromJson(e)).toList();
  }

  Future<List<Recipe>> searchRecipes(String query, {Map<String, dynamic>? filters}) async {
    final queryParams = <String, String>{
      'search': query,
      'limit': '50',
    };
    if (filters != null) {
      filters.forEach((key, value) {
        if (value != null) {
          queryParams[key] = value.toString();
        }
      });
    }
    final uri = Uri.parse('$baseUrl/recipes').replace(queryParameters: queryParams);
    final res = await _client.get(uri);
    _ensureSuccess(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = data['items'] as List;
    return items.map((e) => Recipe.fromJson(e)).toList();
  }

  Future<List<Recipe>> fetchRecipesWithFilters(Map<String, dynamic> filters) async {
    final queryParams = <String, String>{
      'limit': '50',
    };
    filters.forEach((key, value) {
      if (value != null) {
        queryParams[key] = value.toString();
      }
    });
    final uri = Uri.parse('$baseUrl/recipes').replace(queryParameters: queryParams);
    final res = await _client.get(uri);
    _ensureSuccess(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = data['items'] as List;
    return items.map((e) => Recipe.fromJson(e)).toList();
  }

  Future<List<String>> getSearchSuggestions(String query) async {
    if (query.trim().length < 2) {
      return [];
    }
    final uri = Uri.parse('$baseUrl/recipes/search/suggestions').replace(
      queryParameters: {'q': query, 'limit': '10'},
    );
    final res = await _client.get(uri);
    _ensureSuccess(res);
    final data = jsonDecode(res.body) as List;
    return data.map((e) => e.toString()).toList();
  }

  Future<List<Recipe>> fetchSaved(int userId) async {
    final res = await _client.get(Uri.parse('$baseUrl/users/$userId/saved'));
    _ensureSuccess(res);
    final data = jsonDecode(res.body) as List;
    return data.map((e) => Recipe.fromJson(e)).toList();
  }

  Future<List<Recipe>> fetchUserRecipes(int userId) async {
    final res = await _client.get(Uri.parse('$baseUrl/users/$userId/recipes'));
    _ensureSuccess(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = data['items'] as List;
    return items.map((e) => Recipe.fromJson(e)).toList();
  }

  Future<User> fetchUser(int userId) async {
    final res = await _client.get(Uri.parse('$baseUrl/users/$userId'));
    _ensureSuccess(res);
    return User.fromJson(jsonDecode(res.body));
  }

  Future<User> login(String email, String password) async {
    try {
      final truncatedPassword = _truncatePassword(password);
      final res = await _client.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': truncatedPassword,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (res.statusCode >= 400) {
        String errorMessage = 'Ошибка входа';
        try {
          final errorBody = jsonDecode(res.body);
          errorMessage = errorBody['detail'] ?? errorBody['message'] ?? errorMessage;
        } catch (_) {
          errorMessage = res.body.isNotEmpty ? res.body : 'Ошибка ${res.statusCode}';
        }
        throw Exception(errorMessage);
      }
      
      try {
        return User.fromJson(jsonDecode(res.body));
      } catch (e) {
        throw Exception('Ошибка при обработке ответа сервера');
      }
    } catch (e) {
      String errorMessage = 'Ошибка подключения';
      
      if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        errorMessage = 'Превышено время ожидания ответа от сервера. Проверьте интернет-соединение';
      } else if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        errorMessage = 'Не удалось подключиться к серверу. Проверьте интернет-соединение и URL сервера';
      } else if (e.toString().contains('HandshakeException') || e.toString().contains('Certificate')) {
        errorMessage = 'Ошибка SSL сертификата. Сервер может быть недоступен';
      } else if (e is Exception && e.toString().contains('Exception:')) {
        // Если уже есть сообщение об ошибке, используем его
        final message = e.toString().replaceAll('Exception: ', '');
        if (message.isNotEmpty && message != 'null') {
          errorMessage = message;
        }
      }
      
      throw Exception(errorMessage);
    }
  }

  Future<User> register({required String email, required String password, required String username}) async {
    try {
      final truncatedPassword = _truncatePassword(password);
      final res = await _client.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': truncatedPassword,
          'password_confirm': truncatedPassword,
          'username': username,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (res.statusCode >= 400) {
        String errorMessage = 'Ошибка регистрации';
        try {
          final errorBody = jsonDecode(res.body);
          errorMessage = errorBody['detail'] ?? errorBody['message'] ?? errorMessage;
        } catch (_) {
          errorMessage = res.body.isNotEmpty ? res.body : 'Ошибка ${res.statusCode}';
        }
        throw Exception(errorMessage);
      }
      
      try {
        return User.fromJson(jsonDecode(res.body));
      } catch (e) {
        throw Exception('Ошибка при обработке ответа сервера');
      }
    } catch (e) {
      String errorMessage = 'Ошибка подключения';
      
      if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        errorMessage = 'Превышено время ожидания ответа от сервера. Проверьте интернет-соединение';
      } else if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        errorMessage = 'Не удалось подключиться к серверу. Проверьте интернет-соединение и URL сервера';
      } else if (e.toString().contains('HandshakeException') || e.toString().contains('Certificate')) {
        errorMessage = 'Ошибка SSL сертификата. Сервер может быть недоступен';
      } else if (e is Exception && e.toString().contains('Exception:')) {
        // Если уже есть сообщение об ошибке, используем его
        final message = e.toString().replaceAll('Exception: ', '');
        if (message.isNotEmpty && message != 'null') {
          errorMessage = message;
        }
      }
      
      throw Exception(errorMessage);
    }
  }

  Future<User> updateUser(int userId, {String? username, String? bio, String? avatarUrl}) async {
    final jsonData = <String, dynamic>{};
    if (username != null) jsonData['username'] = username;
    if (bio != null) jsonData['bio'] = bio;
    if (avatarUrl != null) jsonData['avatar_url'] = avatarUrl;
    
    final res = await _client.put(
      Uri.parse('$baseUrl/users/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(jsonData),
    );
    _ensureSuccess(res);
    return User.fromJson(jsonDecode(res.body));
  }

  Future<Recipe> createRecipe(Recipe draft) async {
    // Создаем JSON без id для создания нового рецепта
    final jsonData = {
      'title': draft.title,
      'description': draft.description,
      'instructions': draft.instructions,
      'image_url': draft.imageUrl,
      'cook_time_minutes': draft.cookTimeMinutes,
      'servings': draft.servings,
      'tags': draft.tags,
      'author_id': draft.authorId,
    };
    
    final res = await _client.post(
      Uri.parse('$baseUrl/recipes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(jsonData),
    );
    _ensureSuccess(res);
    return Recipe.fromJson(jsonDecode(res.body));
  }

  Future<void> saveRecipe(int userId, int recipeId) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/users/$userId/saved/$recipeId'),
    );
    _ensureSuccess(res);
  }

  Future<void> unsaveRecipe(int userId, int recipeId) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/users/$userId/saved/$recipeId'),
    );
    _ensureSuccess(res);
  }

  Future<Recipe> getRecipe(int recipeId) async {
    final res = await _client.get(Uri.parse('$baseUrl/recipes/$recipeId'));
    _ensureSuccess(res);
    return Recipe.fromJson(jsonDecode(res.body));
  }

  Future<Recipe> updateRecipe(int recipeId, Recipe recipe) async {
    final jsonData = {
      'title': recipe.title,
      'description': recipe.description,
      'instructions': recipe.instructions,
      'image_url': recipe.imageUrl,
      'cook_time_minutes': recipe.cookTimeMinutes,
      'servings': recipe.servings,
      'tags': recipe.tags,
    };
    
    final res = await _client.put(
      Uri.parse('$baseUrl/recipes/$recipeId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(jsonData),
    );
    _ensureSuccess(res);
    return Recipe.fromJson(jsonDecode(res.body));
  }

  Future<void> deleteRecipe(int recipeId) async {
    final res = await _client.delete(Uri.parse('$baseUrl/recipes/$recipeId'));
    _ensureSuccess(res);
  }

  Future<double?> getUserRating(int recipeId, int userId) async {
    final res = await _client.get(Uri.parse('$baseUrl/recipes/$recipeId/rating/$userId'));
    _ensureSuccess(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['rating'] as double?;
  }

  Future<double> rateRecipe(int recipeId, int userId, double rating) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/recipes/$recipeId/rate?user_id=$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'rating': rating}),
    );
    _ensureSuccess(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    // Возвращаем средний рейтинг
    return (data['average_rating'] as num?)?.toDouble() ?? rating;
  }

  void _ensureSuccess(http.Response res) {
    if (res.statusCode >= 400) {
      try {
        final errorBody = jsonDecode(res.body);
        final errorMessage = errorBody['detail'] ?? errorBody['message'] ?? res.body;
        throw Exception(errorMessage);
      } catch (e) {
        if (e is Exception && e.toString().contains('detail') || e.toString().contains('message')) {
          rethrow;
        }
        throw Exception('Request failed: ${res.statusCode} ${res.body}');
      }
    }
  }
}


