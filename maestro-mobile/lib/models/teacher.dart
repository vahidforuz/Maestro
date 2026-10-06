class Teacher {
  const Teacher({
    required this.id,
    required this.name,
    this.telephone,
    this.email,
    this.address,
    this.status,
    this.firstName = '',
    this.lastName = '',
    this.studioName = '',
    this.city = '',
    this.postalCode = '',
    this.mainInstrument = '',
    this.otherInstruments = '',
    this.defaultLessonDuration = 60,
    this.defaultLessonPrice = 0,
    this.currency = 'CAD',
    this.profileImagePath = '',
  });

  final int id;
  final String name;
  final String? telephone;
  final String? email;
  final String? address;
  final String? status;
  final String firstName;
  final String lastName;
  final String studioName;
  final String city;
  final String postalCode;
  final String mainInstrument;
  final String otherInstruments;
  final int defaultLessonDuration;
  final double defaultLessonPrice;
  final String currency;
  final String profileImagePath;

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Teacher',
      telephone: json['telephone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      status: json['status'] as String?,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      studioName: json['studioName'] as String? ?? '',
      city: json['city'] as String? ?? '',
      postalCode: json['postalCode'] as String? ?? '',
      mainInstrument: json['mainInstrument'] as String? ?? '',
      otherInstruments: json['otherInstruments'] as String? ?? '',
      defaultLessonDuration: json['defaultLessonDuration'] as int? ?? 60,
      defaultLessonPrice: (json['defaultLessonPrice'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'CAD',
      profileImagePath: json['profileImagePath'] as String? ?? '',
    );
  }

  String get displayName => name.trim().isEmpty ? 'Teacher $id' : name;
}
