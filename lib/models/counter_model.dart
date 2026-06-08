class CounterModel {
  final String id;
  String name;
  int value;
  int target; // 0 means no target
  int themeIndex; // maps to AppColors.counterThemes
  final DateTime createdAt;
  List<DateTime> history;

  CounterModel({
    required this.id,
    required this.name,
    this.value = 0,
    this.target = 0,
    this.themeIndex = 0,
    DateTime? createdAt,
    List<DateTime>? history,
  })  : createdAt = createdAt ?? DateTime.now(),
        history = history ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'value': value,
      'target': target,
      'themeIndex': themeIndex,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'history': history.map((e) => e.millisecondsSinceEpoch).toList(),
    };
  }

  factory CounterModel.fromJson(Map<String, dynamic> json) {
    return CounterModel(
      id: json['id'] as String,
      name: json['name'] as String,
      value: json['value'] as int? ?? 0,
      target: json['target'] as int? ?? 0,
      themeIndex: json['themeIndex'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
          : null,
      history: json['history'] != null
          ? (json['history'] as List)
              .map((e) => DateTime.fromMillisecondsSinceEpoch(e as int))
              .toList()
          : null,
    );
  }

  CounterModel copyWith({
    String? name,
    int? value,
    int? target,
    int? themeIndex,
    List<DateTime>? history,
  }) {
    return CounterModel(
      id: id,
      name: name ?? this.name,
      value: value ?? this.value,
      target: target ?? this.target,
      themeIndex: themeIndex ?? this.themeIndex,
      createdAt: createdAt,
      history: history ?? List.from(this.history),
    );
  }
}
