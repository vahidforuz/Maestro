class CourseNote {
  const CourseNote({
    required this.id,
    required this.piece,
    required this.comment,
    this.createdDate,
    this.reviewWeeks,
    this.reviewDate,
    this.reviewStatus,
    required this.sourceCourseId,
    this.acceptedCourseId,
    this.targetCourseId,
    this.reviewedDate,
    this.reviewHistory = '',
  });

  final int id;
  final String piece;
  final String comment;
  final DateTime? createdDate;
  final int? reviewWeeks;
  final DateTime? reviewDate;
  final String? reviewStatus;
  final int sourceCourseId;
  final int? acceptedCourseId;
  final int? targetCourseId;
  final DateTime? reviewedDate;
  final String reviewHistory;

  factory CourseNote.fromJson(Map<String, dynamic> json) {
    return CourseNote(
      id: json['id'] as int? ?? 0,
      piece: json['piece'] as String? ?? '',
      comment: json['comment'] as String? ?? '',
      createdDate: _parseDate(json['createdDate']),
      reviewWeeks: json['reviewWeeks'] as int?,
      reviewDate: _parseDate(json['reviewDate']),
      reviewStatus: json['reviewStatus'] as String?,
      sourceCourseId: json['sourceCourseId'] as int? ?? 0,
      acceptedCourseId: json['acceptedCourseId'] as int?,
      targetCourseId: json['targetCourseId'] as int?,
      reviewedDate: _parseDate(json['reviewedDate']),
      reviewHistory: json['reviewHistory'] as String? ?? '',
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
