import 'package:flutter/material.dart';
import '../theme.dart';

class RecipeFilters {
  double? minRating;
  RangeValues? cookTimeRange;
  List<String> selectedDishTypes;
  String? temperature; // "hot" or "cold" or null

  RecipeFilters({
    this.minRating,
    this.cookTimeRange,
    this.selectedDishTypes = const [],
    this.temperature,
  });

  RecipeFilters copyWith({
    double? minRating,
    RangeValues? cookTimeRange,
    List<String>? selectedDishTypes,
    String? temperature,
  }) {
    return RecipeFilters(
      minRating: minRating ?? this.minRating,
      cookTimeRange: cookTimeRange ?? this.cookTimeRange,
      selectedDishTypes: selectedDishTypes ?? this.selectedDishTypes,
      temperature: temperature ?? this.temperature,
    );
  }

  bool get hasActiveFilters {
    return minRating != null ||
        cookTimeRange != null ||
        selectedDishTypes.isNotEmpty ||
        temperature != null;
  }

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};
    if (minRating != null && minRating! > 0) {
      params['min_rating'] = minRating!.toStringAsFixed(1);
    }
    if (cookTimeRange != null) {
      params['min_cook_time'] = cookTimeRange!.start.round().toString();
      params['max_cook_time'] = cookTimeRange!.end.round().toString();
    }
    if (selectedDishTypes.isNotEmpty) {
      // Для множественного выбора отправляем первый тип (можно расширить API)
      params['dish_type'] = selectedDishTypes.first.toLowerCase();
    }
    if (temperature != null) {
      params['temperature'] = temperature;
    }
    return params;
  }
}

class FiltersScreen extends StatefulWidget {
  final RecipeFilters initialFilters;
  final Function(RecipeFilters) onApplyFilters;

  const FiltersScreen({
    super.key,
    required this.initialFilters,
    required this.onApplyFilters,
  });

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  late RecipeFilters _filters;

  final List<String> _dishTypes = [
    'Завтрак',
    'Обед',
    'Ужин',
    'Десерт',
  ];

  final double _minCookTime = 5;
  final double _maxCookTime = 180;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
    // Инициализируем диапазон времени готовки, если не задан
    if (_filters.cookTimeRange == null) {
      _filters = _filters.copyWith(
        cookTimeRange: RangeValues(_minCookTime, _maxCookTime),
      );
    }
  }

  void _resetFilters() {
    setState(() {
      _filters = RecipeFilters(
        cookTimeRange: RangeValues(_minCookTime, _maxCookTime),
      );
    });
  }

  void _applyFilters() {
    widget.onApplyFilters(_filters);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Фильтры',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _filters.hasActiveFilters ? _resetFilters : null,
            child: Text(
              'Сбросить',
              style: TextStyle(
                color: _filters.hasActiveFilters
                    ? AppColors.accent
                    : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Рейтинг
            _buildSection(
              title: 'Минимальный рейтинг',
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _filters.minRating != null
                            ? '${_filters.minRating!.toStringAsFixed(1)} ⭐'
                            : 'Не выбран',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_filters.minRating != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          color: AppColors.muted,
                          onPressed: () {
                            setState(() {
                              _filters = _filters.copyWith(minRating: null);
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: _filters.minRating ?? 0.0,
                    min: 0.0,
                    max: 5.0,
                    divisions: 50,
                    activeColor: AppColors.accent,
                    inactiveColor: AppColors.muted,
                    label: _filters.minRating != null
                        ? '${_filters.minRating!.toStringAsFixed(1)} ⭐'
                        : null,
                    onChanged: (value) {
                      setState(() {
                        _filters = _filters.copyWith(
                          minRating: value > 0 ? value : null,
                        );
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0', style: TextStyle(color: AppColors.muted)),
                      Text('5', style: TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Время готовки
            _buildSection(
              title: 'Время готовки',
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_filters.cookTimeRange!.start.round()} мин',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_filters.cookTimeRange!.end.round()} мин',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RangeSlider(
                    values: _filters.cookTimeRange!,
                    min: _minCookTime,
                    max: _maxCookTime,
                    divisions: 35,
                    activeColor: AppColors.accent,
                    inactiveColor: AppColors.muted,
                    labels: RangeLabels(
                      '${_filters.cookTimeRange!.start.round()} мин',
                      '${_filters.cookTimeRange!.end.round()} мин',
                    ),
                    onChanged: (values) {
                      setState(() {
                        _filters = _filters.copyWith(cookTimeRange: values);
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('5 мин', style: TextStyle(color: AppColors.muted)),
                      Text('180 мин', style: TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Тип блюда
            _buildSection(
              title: 'Тип блюда',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _dishTypes.map((type) {
                  final isSelected = _filters.selectedDishTypes.contains(type);
                  return FilterChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        final newTypes = List<String>.from(_filters.selectedDishTypes);
                        if (selected) {
                          newTypes.add(type);
                        } else {
                          newTypes.remove(type);
                        }
                        _filters = _filters.copyWith(selectedDishTypes: newTypes);
                      });
                    },
                    selectedColor: AppColors.accent,
                    checkmarkColor: Colors.black,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: AppColors.card,
                    side: BorderSide(
                      color: isSelected ? AppColors.accent : AppColors.muted,
                      width: 1.5,
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 32),

            // Температура
            _buildSection(
              title: 'Температура',
              child: Row(
                children: [
                  Expanded(
                    child: _buildTemperatureChip(
                      label: 'Горячее',
                      value: 'hot',
                      icon: Icons.local_fire_department,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTemperatureChip(
                      label: 'Холодное',
                      value: 'cold',
                      icon: Icons.ac_unit,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _filters.hasActiveFilters ? _resetFilters : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                      color: _filters.hasActiveFilters
                          ? AppColors.accent
                          : AppColors.muted,
                    ),
                  ),
                  child: Text(
                    'Сбросить',
                    style: TextStyle(
                      color: _filters.hasActiveFilters
                          ? AppColors.accent
                          : AppColors.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _applyFilters,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Применить (${_getActiveFiltersCount()})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildTemperatureChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _filters.temperature == value;
    return InkWell(
      onTap: () {
        setState(() {
          _filters = _filters.copyWith(
            temperature: isSelected ? null : value,
          );
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.muted,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.black : Colors.white,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getActiveFiltersCount() {
    int count = 0;
    if (_filters.minRating != null && _filters.minRating! > 0) count++;
    if (_filters.cookTimeRange != null &&
        (_filters.cookTimeRange!.start > _minCookTime ||
            _filters.cookTimeRange!.end < _maxCookTime)) count++;
    if (_filters.selectedDishTypes.isNotEmpty) count++;
    if (_filters.temperature != null) count++;
    return count;
  }
}







