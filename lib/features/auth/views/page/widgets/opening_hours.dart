class OpeningHours {
  final Map<String, Map<String, String>> hours;

  OpeningHours({required this.hours});

  Map<String, dynamic> toMap() => hours;

  factory OpeningHours.fromMap(Map<String, dynamic> map) {
    final typedHours = <String, Map<String, String>>{};
    map.forEach((day, hourMap) {
      if (hourMap is Map) {
        typedHours[day] = Map<String, String>.from(
          hourMap.map((key, value) => MapEntry(key.toString(), value.toString())),
        );
      }
    });
    return OpeningHours(hours: typedHours);
  }

  OpeningHours copyWith({Map<String, Map<String, String>>? hours}) {
    return OpeningHours(hours: hours ?? this.hours);
  }

  @override
  String toString() => hours.toString();
}
