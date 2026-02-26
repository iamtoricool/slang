class LanguageModel {
  final String code;
  final String name;
  final String nativeName;
  final String hash;
  final DateTime updatedAt;

  const LanguageModel({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.hash,
    required this.updatedAt,
  });

  factory LanguageModel.fromJson(Map<String, dynamic> json) {
    return LanguageModel(
      code: json['code'] as String,
      name: json['name'] as String,
      nativeName: json['nativeName'] as String? ?? '',
      hash: json['hash'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'nativeName': nativeName,
      'hash': hash,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  LanguageModel copyWith({
    String? code,
    String? name,
    String? nativeName,
    String? hash,
    DateTime? updatedAt,
  }) {
    return LanguageModel(
      code: code ?? this.code,
      name: name ?? this.name,
      nativeName: nativeName ?? this.nativeName,
      hash: hash ?? this.hash,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'LanguageModel(code: $code, name: $name)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LanguageModel && other.code == code;
  }

  @override
  int get hashCode => code.hashCode;
}
