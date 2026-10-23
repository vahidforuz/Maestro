import 'student.dart';
import 'student_course.dart';
import 'student_project.dart';

enum CourseFilter { all, current, month, upcoming, past }

class CourseListing {
  const CourseListing(this.project, this.course);

  final StudentProject project;
  final StudentCourse course;
}

/// Lesson dates are calendar dates from Supabase, so compare their calendar
/// components with the device's local calendar rather than UTC instants.
DateTime courseCalendarDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

List<CourseListing> filteredCourseListings(
  Student student,
  CourseFilter filter, {
  required DateTime today,
  required DateTime month,
}) {
  final localToday = courseCalendarDate(today);
  final weekStart = DateTime(localToday.year, localToday.month,
      localToday.day - localToday.weekday + 1);
  final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
  final listings = <CourseListing>[
    for (final project in student.projects)
      for (final course in project.courses) CourseListing(project, course),
  ];

  final matching = listings.where((listing) {
    final date = listing.course.date;
    if (filter == CourseFilter.all) return true;
    if (date == null) return false;
    final day = courseCalendarDate(date);
    return switch (filter) {
      CourseFilter.all => true,
      CourseFilter.current => !day.isBefore(weekStart) && day.isBefore(weekEnd),
      CourseFilter.month => day.year == month.year && day.month == month.month,
      CourseFilter.upcoming => day.isAfter(localToday),
      CourseFilter.past => day.isBefore(localToday) ||
          (day == localToday &&
              (listing.course.status == 'PRESENT' ||
                  listing.course.status == 'ABSENT' ||
                  listing.course.status == 'CANCELED')),
    };
  }).toList();

  matching.sort((a, b) {
    final aDate = a.course.date;
    final bDate = b.course.date;
    if (aDate == null || bDate == null) {
      if (aDate == null && bDate == null) {
        return a.course.id.compareTo(b.course.id);
      }
      return aDate == null ? 1 : -1;
    }
    final byDate =
        courseCalendarDate(aDate).compareTo(courseCalendarDate(bDate));
    if (byDate != 0) {
      return filter == CourseFilter.past ? -byDate : byDate;
    }
    return a.course.id.compareTo(b.course.id);
  });
  return matching;
}

CourseFilter defaultCourseFilter(Student student, DateTime today) {
  final month = DateTime(today.year, today.month);
  if (filteredCourseListings(student, CourseFilter.current,
          today: today, month: month)
      .isNotEmpty) {
    return CourseFilter.current;
  }
  if (filteredCourseListings(student, CourseFilter.upcoming,
          today: today, month: month)
      .isNotEmpty) {
    return CourseFilter.upcoming;
  }
  return CourseFilter.current;
}
