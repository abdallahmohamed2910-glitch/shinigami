import 'dart:convert';

class AppSettings {
  final bool soundOn;
  final bool vibrationOn;

  AppSettings({required this.soundOn, required this.vibrationOn});

  AppSettings copyWith({bool? soundOn, bool? vibrationOn}) {
    return AppSettings(
      soundOn: soundOn ?? this.soundOn,
      vibrationOn: vibrationOn ?? this.vibrationOn,
    );
  }

  Map<String, dynamic> toJson() => {
        'soundOn': soundOn,
        'vibrationOn': vibrationOn,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      soundOn: json['soundOn'] ?? true,
      vibrationOn: json['vibrationOn'] ?? true,
    );
  }
}

class GameCategory {
  final String name;
  final List<String> words;

  GameCategory({required this.name, required this.words});

  factory GameCategory.fromJson(Map<String, dynamic> json) {
    return GameCategory(
      name: json['name'] as String,
      words: List<String>.from(json['words'] as List),
    );
  }
}

class GameDatabase {
  final List<GameCategory> categories;

  GameDatabase({required this.categories});

  factory GameDatabase.fromJson(Map<String, dynamic> json) {
    var list = json['categories'] as List;
    List<GameCategory> cats = list.map((i) => GameCategory.fromJson(i)).toList();
    return GameDatabase(categories: cats);
  }
}

// Player model for the Spy (بكاسة) game
class SpyPlayer {
  final String id;
  final String name;
  final String role; // 'CITIZEN' | 'SPY'
  final bool isAlive;

  SpyPlayer({
    required this.id,
    required this.name,
    required this.role,
    this.isAlive = true,
  });

  SpyPlayer copyWith({String? id, String? name, String? role, bool? isAlive}) {
    return SpyPlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      isAlive: isAlive ?? this.isAlive,
    );
  }
}

// Player model for the Wink (الغمزة) game
class WinkPlayer {
  final String id;
  final String name;
  final String role; // 'CITIZEN' | 'KILLER'
  final bool isAlive;

  WinkPlayer({
    required this.id,
    required this.name,
    required this.role,
    this.isAlive = true,
  });

  WinkPlayer copyWith({String? id, String? name, String? role, bool? isAlive}) {
    return WinkPlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      isAlive: isAlive ?? this.isAlive,
    );
  }
}
