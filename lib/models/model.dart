class RAMSDataPost {
  final String id;
  final String projectId;
  final String chainageStart;
  final String chainageEnd;
  final String distressType;
  final String distressId;
  final String distressUnit;
  final String unit;
  final String? area;
  final String? volume;
  final String? latitude;
  final String? longitude;
  final String? dimensions;
  final String? note;
  final String? imagePath;
  final String timestamp; // ✅ Add this

  RAMSDataPost({
    required this.id,
    required this.projectId,
    required this.chainageStart,
    required this.chainageEnd,
    required this.distressType,
    required this.distressId,
    required this.distressUnit,
    required this.unit,
    this.area,
    this.volume,
    this.latitude,
    this.longitude,
    this.dimensions,
    this.note,
    this.imagePath,
    required this.timestamp, // ✅ Add this
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'chainageStart': chainageStart,
    'chainageEnd': chainageEnd,
    'distressType': distressType,
    'distressId': distressId,
    'distressUnit': distressUnit,
    'unit': unit,
    'area': area,
    'volume': volume,
    'latitude': latitude,
    'longitude': longitude,
    'dimensions': dimensions,
    'note': note,
    'imagePath': imagePath,
    'timestamp': timestamp, // ✅ Add this
  };

  factory RAMSDataPost.fromJson(Map<String, dynamic> json) {
    return RAMSDataPost(
      id: json['id'],
      projectId: json['projectId'],
      chainageStart: json['chainageStart'],
      chainageEnd: json['chainageEnd'],
      distressType: json['distressType'],
      distressId: json['distressId'],
      distressUnit: json['distressUnit'],
      unit: json['unit'],
      area: json['area'],
      volume: json['volume'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      dimensions: json['dimensions'],
      note: json['note'],
      imagePath: json['imagePath'],
      timestamp: json['timestamp'], // ✅ Add this
    );
  }
}
