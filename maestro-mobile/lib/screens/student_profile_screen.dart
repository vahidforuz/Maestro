import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/course_note.dart';
import '../models/payment.dart';
import '../models/student.dart';
import '../models/student_course.dart';
import '../models/student_project.dart';
import '../services/api_client.dart';
import '../services/maestro_api.dart';
import '../theme/maestro_theme.dart';
import '../widgets/maestro_card.dart';
import '../widgets/status_badge.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({
    super.key,
    required this.api,
    required this.studentId,
    required this.onBack,
    this.initialCourseId,
  });

  final MaestroApi api;
  final int studentId;
  final VoidCallback onBack;
  final int? initialCourseId;

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  late Future<_ProfileData> _future;
  int _selectedTab = 0;
  final Set<int> _openCourses = {};
  final Set<int> _creatingCourseProjectIds = {};
  final Map<int, int> _selectedCourseIdsByProject = {};
  _ProfileData? _profileData;

  static const _tabs = ['Courses', 'Projects / Pieces', 'Payments'];

  @override
  void initState() {
    super.initState();
    if (widget.initialCourseId != null) {
      _openCourses.add(widget.initialCourseId!);
    }
    _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: FutureBuilder<_ProfileData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(
                message: _friendlyError(snapshot.error),
                onRetry: _refresh,
              );
            }
            final data = snapshot.data;
            if (data == null) {
              return const Center(child: Text('Student profile not found.'));
            }
            return _content(data);
          },
        ),
      ),
    );
  }

  Widget _content(_ProfileData data) {
    _profileData = data;
    final student = data.student;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(student: student, onBack: widget.onBack),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < _tabs.length; index++)
              ChoiceChip(
                label: Text(_tabs[index]),
                selected: _selectedTab == index,
                onSelected: (_) => setState(() => _selectedTab = index),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: IndexedStack(
            index: _selectedTab,
            children: [
              _CoursesSection(
                student: student,
                payments: data.payments,
                openCourses: _openCourses,
                creatingCourseProjectIds: _creatingCourseProjectIds,
                selectedCourseIdsByProject: _selectedCourseIdsByProject,
                onAddCourse: _addCourse,
                onSelectCourse: _selectCourse,
                onEditSelectedCourse: _editSelectedCourse,
                onDeleteSelectedCourse: _deleteSelectedCourse,
                onEditCourse: _editCourse,
                onDeleteCourse: _deleteCourse,
                onDeleteProject: _deleteProject,
                onAddPiece: _addPiece,
                onEditPiece: _editPiece,
                onDeletePiece: _deletePiece,
                onSaveNote: _saveNote,
                onDeleteNote: _deleteNote,
                onMarkReviewReviewed: _markReviewReviewed,
                onKeepReview: _keepReview,
              ),
              _ProjectsSection(
                student: student,
                onAddProject: _addProject,
                onEditProject: _editProject,
                onDeleteProject: _deleteProject,
                onAddPiece: _addPiece,
                onEditPiece: _editPiece,
                onDeletePiece: _deletePiece,
              ),
              _PaymentsSection(
                student: student,
                payments: data.payments,
                errorMessage: data.paymentsError == null
                    ? null
                    : _friendlyError(data.paymentsError),
                onAddPayment: _addPayment,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<_ProfileData> _load() async {
    debugPrint('Opening student: ${widget.studentId}');
    final student = await widget.api.fetchStudent(widget.studentId);
    List<Payment> payments = const [];
    Object? paymentsError;
    try {
      payments = await widget.api.fetchStudentPayments(widget.studentId);
    } catch (error) {
      paymentsError = error;
    }
    return _ProfileData(
      student: student,
      payments: payments,
      paymentsError: paymentsError,
    );
  }

  void _refresh() {
    setState(() {
      _profileData = null;
      _future = _load();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) _refresh();
    } catch (error) {
      debugPrint('Student profile update failed: $error');
      if (mounted) _showMessage(_friendlyError(error));
    }
  }

  Future<void> _addProject(Student student) async {
    final name = await _textDialog('Add Project', 'Project name',
        initialValue: 'Project ${student.projects.length + 1}');
    if (name == null || name.trim().isEmpty) return;
    await _run(() async {
      await widget.api.addProject(student.id, {'name': name.trim()});
    });
  }

  Future<void> _editProject(Student student, StudentProject project) async {
    final name = await _textDialog('Edit Project', 'Project name',
        initialValue: project.name);
    if (name == null || name.trim().isEmpty) return;
    await _run(() async {
      await widget.api
          .updateProject(student.id, project.id, {'name': name.trim()});
    });
  }

  Future<void> _deleteProject(Student student, StudentProject project) async {
    final confirmed = await _confirm(
      'Delete Project',
      'Delete ${project.name}? Courses in this project will be removed.',
    );
    if (!confirmed) return;
    await _run(() async {
      await widget.api.deleteProject(student.id, project.id);
    });
  }

  Future<void> _addPiece(Student student, StudentProject project) async {
    final title = await _textDialog('Add Piece', 'Piece title');
    if (title == null || title.trim().isEmpty) return;
    await _run(() async {
      await widget.api
          .addPiece(student.id, project.id, {'title': title.trim()});
    });
  }

  Future<void> _editPiece(
      Student student, StudentProject project, int pieceIndex) async {
    final title = await _textDialog('Edit Piece', 'Piece title',
        initialValue: project.pieces[pieceIndex]);
    if (title == null || title.trim().isEmpty) return;
    await _run(() async {
      await widget.api.updatePiece(
          student.id, project.id, pieceIndex, {'title': title.trim()});
    });
  }

  Future<void> _deletePiece(
      Student student, StudentProject project, int pieceIndex) async {
    final confirmed =
        await _confirm('Delete Piece', 'Delete ${project.pieces[pieceIndex]}?');
    if (!confirmed) return;
    await _run(() async {
      await widget.api.deletePiece(student.id, project.id, pieceIndex);
    });
  }

  Future<void> _addCourse(Student student, StudentProject project) async {
    if (_creatingCourseProjectIds.contains(project.id)) return;
    setState(() => _creatingCourseProjectIds.add(project.id));
    try {
      final updatedStudent = await widget.api.addCourse(student.id, project.id);
      if (!mounted) return;
      setState(() {
        _creatingCourseProjectIds.remove(project.id);
        _profileData =
            (_profileData ?? _ProfileData(student: student, payments: const []))
                .copyWith(student: updatedStudent);
        _future = Future.value(_profileData);
      });
    } catch (error) {
      debugPrint(
          'Add course failed for student ${student.id}, project ${project.id}: $error');
      if (!mounted) return;
      setState(() => _creatingCourseProjectIds.remove(project.id));
      _showMessage(_friendlyError(error));
    }
  }

  void _selectCourse(StudentProject project, StudentCourse course) {
    setState(() => _selectedCourseIdsByProject[project.id] = course.id);
  }

  Future<void> _editSelectedCourse(
      Student student, StudentProject project) async {
    final selected = _selectedCourse(student, project);
    if (selected == null) return;
    await _editCourse(student, project, selected);
  }

  Future<void> _deleteSelectedCourse(
      Student student, StudentProject project) async {
    final selected = _selectedCourse(student, project);
    if (selected == null) return;
    await _deleteCourse(student, project, selected);
  }

  StudentCourse? _selectedCourse(Student student, StudentProject project) {
    final selectedId = _selectedCourseIdsByProject[project.id];
    if (selectedId == null) return null;
    for (final course in project.courses) {
      if (course.id == selectedId) return course;
    }
    return null;
  }

  Future<void> _editCourse(
      Student student, StudentProject project, StudentCourse course) async {
    final request = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CourseDialog(course: course),
    );
    if (request == null) return;
    await _run(() async {
      await widget.api.updateCourse(student.id, project.id, course.id, request);
    });
  }

  Future<void> _deleteCourse(
      Student student, StudentProject project, StudentCourse course) async {
    final courseNumber =
        project.courses.indexWhere((item) => item.id == course.id) + 1;
    final confirmed = await _confirm(
      'Delete Course',
      'Delete Course $courseNumber?\n\nThis will delete the selected course and its related course data.',
    );
    if (!confirmed) return;
    await _run(() async {
      await widget.api.deleteCourse(student.id, project.id, course.id);
    });
  }

  Future<void> _saveNote(Student student, StudentProject project,
      StudentCourse course, CourseNote? note) async {
    final request = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _NoteDialog(project: project, note: note),
    );
    if (request == null) return;
    await _run(() async {
      if (note == null) {
        await widget.api.addNote(student.id, project.id, course.id, request);
      } else {
        await widget.api
            .updateNote(student.id, project.id, course.id, note.id, request);
      }
    });
  }

  Future<void> _deleteNote(Student student, StudentProject project,
      StudentCourse course, CourseNote note) async {
    final confirmed = await _confirm('Delete Note', 'Delete this note?');
    if (!confirmed) return;
    await _run(() async {
      await widget.api.deleteNote(student.id, project.id, course.id, note.id);
    });
  }

  Future<void> _markReviewReviewed(
      Student student, StudentCourse course, CourseNote note) async {
    await _run(() async {
      await widget.api.markReviewReviewed(student.id, note.id, course.id);
    });
  }

  Future<void> _keepReview(
      Student student, StudentCourse course, CourseNote note) async {
    await _run(() async {
      await widget.api.keepReviewForNextCourse(student.id, note.id, course.id);
    });
  }

  Future<void> _addPayment(Student student) async {
    final request = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _PaymentDialog(),
    );
    if (request == null) return;
    await _run(() async {
      await widget.api.createPayment(student.id, request);
    });
  }

  Future<String?> _textDialog(String title, String label,
      {String initialValue = ''}) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (_) => Navigator.pop(context, controller.text),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save')),
        ],
      ),
    );
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyError(Object? error) {
    if (error is ApiException) {
      if (error.statusCode == 404) {
        return 'The requested profile was not found.';
      }
      return 'The profile could not be updated. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.student, required this.onBack});

  final Student student;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return MaestroCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: MaestroColors.subtleBlue,
            foregroundColor: MaestroColors.primary,
            child: Text(
              _initials(student),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.displayName,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${student.instrument ?? 'No instrument'} Student',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${student.level ?? 'No level'} - ${student.courseDay ?? 'No day'} ${student.courseHour ?? ''}',
                  style: const TextStyle(color: MaestroColors.muted),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
          ),
        ],
      ),
    );
  }

  String _initials(Student student) {
    final first =
        student.firstName.isNotEmpty ? student.firstName : student.displayName;
    final last = student.familyName;
    final firstInitial =
        first.isEmpty ? '' : first.substring(0, 1).toUpperCase();
    final lastInitial = last.isEmpty ? '' : last.substring(0, 1).toUpperCase();
    return '$firstInitial$lastInitial';
  }
}

class _CoursesSection extends StatelessWidget {
  const _CoursesSection({
    required this.student,
    required this.payments,
    required this.openCourses,
    required this.creatingCourseProjectIds,
    required this.selectedCourseIdsByProject,
    required this.onAddCourse,
    required this.onSelectCourse,
    required this.onEditSelectedCourse,
    required this.onDeleteSelectedCourse,
    required this.onEditCourse,
    required this.onDeleteCourse,
    required this.onDeleteProject,
    required this.onAddPiece,
    required this.onEditPiece,
    required this.onDeletePiece,
    required this.onSaveNote,
    required this.onDeleteNote,
    required this.onMarkReviewReviewed,
    required this.onKeepReview,
  });

  final Student student;
  final List<Payment> payments;
  final Set<int> openCourses;
  final Set<int> creatingCourseProjectIds;
  final Map<int, int> selectedCourseIdsByProject;
  final Future<void> Function(Student, StudentProject) onAddCourse;
  final void Function(StudentProject, StudentCourse) onSelectCourse;
  final Future<void> Function(Student, StudentProject) onEditSelectedCourse;
  final Future<void> Function(Student, StudentProject) onDeleteSelectedCourse;
  final Future<void> Function(Student, StudentProject, StudentCourse)
      onEditCourse;
  final Future<void> Function(Student, StudentProject, StudentCourse)
      onDeleteCourse;
  final Future<void> Function(Student, StudentProject) onDeleteProject;
  final Future<void> Function(Student, StudentProject) onAddPiece;
  final Future<void> Function(Student, StudentProject, int) onEditPiece;
  final Future<void> Function(Student, StudentProject, int) onDeletePiece;
  final Future<void> Function(
      Student, StudentProject, StudentCourse, CourseNote?) onSaveNote;
  final Future<void> Function(
      Student, StudentProject, StudentCourse, CourseNote) onDeleteNote;
  final Future<void> Function(Student, StudentCourse, CourseNote)
      onMarkReviewReviewed;
  final Future<void> Function(Student, StudentCourse, CourseNote) onKeepReview;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (final project in student.projects) ...[
          Builder(builder: (context) {
            final creatingCourse =
                creatingCourseProjectIds.contains(project.id);
            final selectedCourseId = selectedCourseIdsByProject[project.id];
            final hasSelectedCourse =
                project.courses.any((course) => course.id == selectedCourseId);
            return MaestroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          project.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Pieces:',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  if (project.pieces.isEmpty)
                    const Text('No pieces yet')
                  else
                    for (var index = 0; index < project.pieces.length; index++)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(project.pieces[index]),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Edit piece',
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  onEditPiece(student, project, index),
                            ),
                            IconButton(
                              tooltip: 'Delete piece',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  onDeletePiece(student, project, index),
                            ),
                          ],
                        ),
                      ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => onAddPiece(student, project),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Piece'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: creatingCourse
                            ? null
                            : () => onAddCourse(student, project),
                        icon: creatingCourse
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add),
                        label: const Text('+ New Course'),
                      ),
                      OutlinedButton.icon(
                        onPressed: hasSelectedCourse
                            ? () => onEditSelectedCourse(student, project)
                            : null,
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Course'),
                      ),
                      OutlinedButton.icon(
                        onPressed: hasSelectedCourse
                            ? () => onDeleteSelectedCourse(student, project)
                            : null,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete Course'),
                      ),
                      OutlinedButton.icon(
                        onPressed: student.projects.length <= 1
                            ? null
                            : () => onDeleteProject(student, project),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete Project'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (project.courses.isEmpty)
                    const _EmptyState(message: 'No courses yet')
                  else
                    for (var index = 0; index < project.courses.length; index++)
                      _CourseTile(
                        student: student,
                        project: project,
                        course: project.courses[index],
                        index: index,
                        selected: project.courses[index].id == selectedCourseId,
                        priceLeft: _priceLeft(project.courses, payments),
                        dueReviews: _dueReviewsForCourse(
                            student, project.courses[index]),
                        onSelect: onSelectCourse,
                        initiallyOpen:
                            openCourses.contains(project.courses[index].id),
                        onOpenChanged: (open) {
                          if (open) {
                            openCourses.add(project.courses[index].id);
                          } else {
                            openCourses.remove(project.courses[index].id);
                          }
                        },
                        onEdit: onEditCourse,
                        onDelete: onDeleteCourse,
                        onSaveNote: onSaveNote,
                        onDeleteNote: onDeleteNote,
                        onMarkReviewReviewed: onMarkReviewReviewed,
                        onKeepReview: onKeepReview,
                      ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
        ],
        if (student.projects.isEmpty)
          const MaestroCard(child: _EmptyState(message: 'No projects yet')),
      ],
    );
  }

  List<CourseNote> _dueReviewsForCourse(Student student, StudentCourse course) {
    final due = <CourseNote>[];
    final courseDate = course.date;
    for (final project in student.projects) {
      for (final sourceCourse in project.courses) {
        if (sourceCourse.id == course.id) continue;
        for (final note in sourceCourse.notes) {
          if (note.reviewStatus != 'PENDING') continue;
          if (note.targetCourseId == course.id) {
            due.add(note);
          } else if (note.targetCourseId == null &&
              note.reviewDate != null &&
              courseDate != null &&
              !note.reviewDate!.isAfter(courseDate)) {
            due.add(note);
          }
        }
      }
    }
    return due;
  }

  double _priceLeft(List<StudentCourse> courses, List<Payment> payments) {
    var total =
        payments.fold<double>(0, (sum, payment) => sum + payment.amount);
    for (final course in courses) {
      if (course.status == 'PRESENT' || course.status == 'ABSENT') {
        total -= course.price;
      }
    }
    return total;
  }
}

class _CourseTile extends StatefulWidget {
  const _CourseTile({
    required this.student,
    required this.project,
    required this.course,
    required this.index,
    required this.selected,
    required this.priceLeft,
    required this.dueReviews,
    required this.onSelect,
    required this.initiallyOpen,
    required this.onOpenChanged,
    required this.onEdit,
    required this.onDelete,
    required this.onSaveNote,
    required this.onDeleteNote,
    required this.onMarkReviewReviewed,
    required this.onKeepReview,
  });

  final Student student;
  final StudentProject project;
  final StudentCourse course;
  final int index;
  final bool selected;
  final double priceLeft;
  final List<CourseNote> dueReviews;
  final void Function(StudentProject, StudentCourse) onSelect;
  final bool initiallyOpen;
  final ValueChanged<bool> onOpenChanged;
  final Future<void> Function(Student, StudentProject, StudentCourse) onEdit;
  final Future<void> Function(Student, StudentProject, StudentCourse) onDelete;
  final Future<void> Function(
      Student, StudentProject, StudentCourse, CourseNote?) onSaveNote;
  final Future<void> Function(
      Student, StudentProject, StudentCourse, CourseNote) onDeleteNote;
  final Future<void> Function(Student, StudentCourse, CourseNote)
      onMarkReviewReviewed;
  final Future<void> Function(Student, StudentCourse, CourseNote) onKeepReview;

  @override
  State<_CourseTile> createState() => _CourseTileState();
}

class _CourseTileState extends State<_CourseTile> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => widget.onSelect(widget.project, course),
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.selected
                ? MaestroColors.subtleBlue
                : const Color(0xFFF8FBFF),
            border: Border.all(
              color: widget.selected
                  ? MaestroColors.primary
                  : MaestroColors.border,
              width: widget.selected ? 1.6 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            widget.selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: widget.selected
                                ? MaestroColors.primary
                                : MaestroColors.muted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Course ${widget.index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(label: course.status),
                    IconButton(
                      tooltip: _open ? 'Close lesson' : 'Open lesson',
                      onPressed: () {
                        setState(() => _open = !_open);
                        widget.onOpenChanged(_open);
                      },
                      icon: Icon(_open ? Icons.expand_less : Icons.expand_more),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 18,
                  runSpacing: 6,
                  children: [
                    _Meta(label: 'Date', value: _date(course.date)),
                    _Meta(label: 'Time', value: course.hour ?? 'No time'),
                    _Meta(
                        label: 'Price',
                        value:
                            NumberFormat.simpleCurrency().format(course.price)),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _open = !_open);
                    widget.onOpenChanged(_open);
                    debugPrint('Open lesson courseId=${course.id}');
                  },
                  icon: Icon(_open ? Icons.expand_less : Icons.open_in_new),
                  label: Text(_open ? 'Close Lesson' : 'Open Lesson'),
                ),
                if (course.homeworkNextLesson.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Homework: ${course.homeworkNextLesson}'),
                ],
                if (_open) ...[
                  const Divider(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => widget.onEdit(
                            widget.student, widget.project, course),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Course'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _markPresent(context),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('Change Status'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => widget.onDelete(
                            widget.student, widget.project, course),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      _Meta(label: 'Day', value: course.day ?? 'No day'),
                      _Meta(
                          label: 'Price left',
                          value: NumberFormat.simpleCurrency()
                              .format(widget.priceLeft)),
                      _Meta(label: 'Assignment', value: course.assignment),
                    ],
                  ),
                  if (course.comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Description: ${course.comment}'),
                  ],
                  const SizedBox(height: 14),
                  if (widget.dueReviews.isNotEmpty) ...[
                    _ReviewSection(
                      student: widget.student,
                      course: course,
                      reviews: widget.dueReviews,
                      onReviewed: widget.onMarkReviewReviewed,
                      onKeep: widget.onKeepReview,
                      onEdit: (note) => _editReviewSource(note),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _Notes(
                    student: widget.student,
                    project: widget.project,
                    course: course,
                    onSaveNote: widget.onSaveNote,
                    onDeleteNote: widget.onDeleteNote,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editReviewSource(CourseNote note) async {
    final source = _findCourseForNote(widget.student, note);
    if (source == null) return;
    await widget.onSaveNote(widget.student, source.$1, source.$2, note);
  }

  Future<void> _markPresent(BuildContext context) async {
    await widget.onEdit(widget.student, widget.project, _copyWithStatus());
  }

  StudentCourse _copyWithStatus() {
    final course = widget.course;
    return StudentCourse(
      id: course.id,
      title: course.title,
      day: course.day,
      date: course.date,
      hour: course.hour,
      price: course.price,
      status: 'PRESENT',
      assignment: course.assignment,
      comment: course.comment,
      homeworkNextLesson: course.homeworkNextLesson,
      notes: course.notes,
    );
  }

  String _date(DateTime? value) {
    return value == null ? 'Not set' : DateFormat.yMMMd().format(value);
  }
}

class _Notes extends StatelessWidget {
  const _Notes({
    required this.student,
    required this.project,
    required this.course,
    required this.onSaveNote,
    required this.onDeleteNote,
  });

  final Student student;
  final StudentProject project;
  final StudentCourse course;
  final Future<void> Function(
      Student, StudentProject, StudentCourse, CourseNote?) onSaveNote;
  final Future<void> Function(
      Student, StudentProject, StudentCourse, CourseNote) onDeleteNote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Lesson Notes',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: project.pieces.isEmpty
                  ? null
                  : () => onSaveNote(student, project, course, null),
              icon: const Icon(Icons.add),
              label: const Text('Add Note'),
            ),
          ],
        ),
        if (project.pieces.isEmpty)
          const Text('Add a project piece before adding course notes.')
        else if (course.notes.isEmpty)
          const _EmptyState(message: 'No course notes yet')
        else
          for (final note in course.notes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title:
                  Text(note.piece.isEmpty ? 'No piece selected' : note.piece),
              subtitle: Text([
                if (note.comment.isNotEmpty) note.comment,
                if (note.reviewDate != null)
                  'Review ${DateFormat.yMMMd().format(note.reviewDate!)}',
                if (note.createdDate != null)
                  'Added ${DateFormat.yMMMd().format(note.createdDate!)}',
              ].join(' - ')),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Edit note',
                    icon: const Icon(Icons.edit),
                    onPressed: () => onSaveNote(student, project, course, note),
                  ),
                  IconButton(
                    tooltip: 'Delete note',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        onDeleteNote(student, project, course, note),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.student,
    required this.course,
    required this.reviews,
    required this.onReviewed,
    required this.onKeep,
    required this.onEdit,
  });

  final Student student;
  final StudentCourse course;
  final List<CourseNote> reviews;
  final Future<void> Function(Student, StudentCourse, CourseNote) onReviewed;
  final Future<void> Function(Student, StudentCourse, CourseNote) onKeep;
  final Future<void> Function(CourseNote) onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review from previous lessons',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        for (final note in reviews)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MaestroColors.warningBg,
              border: Border.all(color: MaestroColors.warningText),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.piece.isNotEmpty)
                  Text(note.piece,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(note.comment.isEmpty ? 'No note text' : note.comment),
                const SizedBox(height: 6),
                Text(
                  [
                    'From: Course ${_courseNumberForId(student, note.sourceCourseId) ?? note.sourceCourseId}',
                    if (note.createdDate != null)
                      'Added: ${DateFormat.yMMMd().format(note.createdDate!)}',
                  ].join(' - '),
                  style: const TextStyle(color: MaestroColors.muted),
                ),
                if (note.reviewHistory.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note.reviewHistory,
                    style: const TextStyle(
                      color: MaestroColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => onReviewed(student, course, note),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Reviewed'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => onKeep(student, course, note),
                      icon: const Icon(Icons.redo),
                      label: const Text('Keep for next course'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => onEdit(note),
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

(StudentProject, StudentCourse)? _findCourseForNote(
    Student student, CourseNote note) {
  for (final project in student.projects) {
    for (final course in project.courses) {
      if (course.id == note.sourceCourseId ||
          course.notes.any((candidate) => candidate.id == note.id)) {
        return (project, course);
      }
    }
  }
  return null;
}

int? _courseNumberForId(Student student, int courseId) {
  for (final project in student.projects) {
    for (var index = 0; index < project.courses.length; index++) {
      if (project.courses[index].id == courseId) {
        return index + 1;
      }
    }
  }
  return null;
}

class _ProjectsSection extends StatelessWidget {
  const _ProjectsSection({
    required this.student,
    required this.onAddProject,
    required this.onEditProject,
    required this.onDeleteProject,
    required this.onAddPiece,
    required this.onEditPiece,
    required this.onDeletePiece,
  });

  final Student student;
  final Future<void> Function(Student) onAddProject;
  final Future<void> Function(Student, StudentProject) onEditProject;
  final Future<void> Function(Student, StudentProject) onDeleteProject;
  final Future<void> Function(Student, StudentProject) onAddPiece;
  final Future<void> Function(Student, StudentProject, int) onEditPiece;
  final Future<void> Function(Student, StudentProject, int) onDeletePiece;

  @override
  Widget build(BuildContext context) {
    return MaestroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Projects / Pieces',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => onAddProject(student),
                icon: const Icon(Icons.add),
                label: const Text('Add Project'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (student.projects.isEmpty)
            const _EmptyState(message: 'No projects yet')
          else
            Expanded(
              child: ListView.separated(
                itemCount: student.projects.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final project = student.projects[index];
                  return _ProjectEditor(
                    student: student,
                    project: project,
                    onEditProject: onEditProject,
                    onDeleteProject: onDeleteProject,
                    onAddPiece: onAddPiece,
                    onEditPiece: onEditPiece,
                    onDeletePiece: onDeletePiece,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ProjectEditor extends StatelessWidget {
  const _ProjectEditor({
    required this.student,
    required this.project,
    required this.onEditProject,
    required this.onDeleteProject,
    required this.onAddPiece,
    required this.onEditPiece,
    required this.onDeletePiece,
  });

  final Student student;
  final StudentProject project;
  final Future<void> Function(Student, StudentProject) onEditProject;
  final Future<void> Function(Student, StudentProject) onDeleteProject;
  final Future<void> Function(Student, StudentProject) onAddPiece;
  final Future<void> Function(Student, StudentProject, int) onEditPiece;
  final Future<void> Function(Student, StudentProject, int) onDeletePiece;

  @override
  Widget build(BuildContext context) {
    final completed = project.courses.isNotEmpty &&
        project.courses.every((course) => course.status == 'PRESENT');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  project.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              StatusBadge(label: completed ? 'Completed' : 'Active'),
              IconButton(
                tooltip: 'Edit project',
                icon: const Icon(Icons.edit),
                onPressed: () => onEditProject(student, project),
              ),
              IconButton(
                tooltip: 'Delete project',
                icon: const Icon(Icons.delete_outline),
                onPressed: student.projects.length <= 1
                    ? null
                    : () => onDeleteProject(student, project),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (project.pieces.isEmpty)
            const Text('No pieces yet')
          else
            for (var index = 0; index < project.pieces.length; index++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(project.pieces[index]),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Edit piece',
                      icon: const Icon(Icons.edit),
                      onPressed: () => onEditPiece(student, project, index),
                    ),
                    IconButton(
                      tooltip: 'Delete piece',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => onDeletePiece(student, project, index),
                    ),
                  ],
                ),
              ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => onAddPiece(student, project),
              icon: const Icon(Icons.add),
              label: const Text('Add Piece'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentsSection extends StatelessWidget {
  const _PaymentsSection({
    required this.student,
    required this.payments,
    required this.errorMessage,
    required this.onAddPayment,
  });

  final Student student;
  final List<Payment> payments;
  final String? errorMessage;
  final Future<void> Function(Student) onAddPayment;

  @override
  Widget build(BuildContext context) {
    final total =
        payments.fold<double>(0, (sum, payment) => sum + payment.amount);
    return MaestroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Payments',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(NumberFormat.simpleCurrency().format(total)),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => onAddPayment(student),
                icon: const Icon(Icons.add),
                label: const Text('Add Payment'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Summary(
                label: 'Credit balance',
                value: NumberFormat.simpleCurrency()
                    .format(student.paymentCreditBalance),
              ),
              _Summary(
                label: 'Lessons remaining',
                value: student.coursePrice <= 0
                    ? '0'
                    : '${(total / student.coursePrice).floor()}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (errorMessage != null)
            _EmptyState(message: errorMessage!)
          else if (payments.isEmpty)
            const _EmptyState(message: 'No payments yet')
          else
            Expanded(
              child: ListView.separated(
                itemCount: payments.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final payment = payments[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                        NumberFormat.simpleCurrency().format(payment.amount)),
                    subtitle: Text([
                      if (payment.paymentDate != null)
                        DateFormat.yMMMd().format(payment.paymentDate!),
                      if (payment.method?.isNotEmpty == true) payment.method!,
                      if (payment.note?.isNotEmpty == true) payment.note!,
                    ].join(' - ')),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CourseDialog extends StatefulWidget {
  const _CourseDialog({required this.course});

  final StudentCourse course;

  @override
  State<_CourseDialog> createState() => _CourseDialogState();
}

class _CourseDialogState extends State<_CourseDialog> {
  late final _date = TextEditingController(
      text: widget.course.date == null
          ? ''
          : DateFormat('yyyy-MM-dd').format(widget.course.date!));
  late final _hour = TextEditingController(text: widget.course.hour ?? '');
  late final _price = TextEditingController(text: '${widget.course.price}');
  late final _assignment =
      TextEditingController(text: widget.course.assignment);
  late final _comment = TextEditingController(text: widget.course.comment);
  late final _homework =
      TextEditingController(text: widget.course.homeworkNextLesson);
  late String _day = widget.course.day ?? 'MONDAY';
  late String _status = widget.course.status;

  static const _days = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY'
  ];
  static const _statuses = [
    'NOTHING',
    'PRESENT',
    'ABSENT',
    'CANCELED',
    'MOVED'
  ];

  @override
  void dispose() {
    _date.dispose();
    _hour.dispose();
    _price.dispose();
    _assignment.dispose();
    _comment.dispose();
    _homework.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Course'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _day,
                items: _days
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() => _day = value ?? _day),
                decoration: const InputDecoration(labelText: 'Day'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _date,
                decoration:
                    const InputDecoration(labelText: 'Date (yyyy-MM-dd)'),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: _hour,
                  decoration: const InputDecoration(labelText: 'Start time')),
              const SizedBox(height: 10),
              TextField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _status,
                items: _statuses
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _status = value ?? _status),
                decoration: const InputDecoration(labelText: 'Status'),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: _homework,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Homework / Next Lesson')),
              const SizedBox(height: 10),
              TextField(
                  controller: _assignment,
                  decoration: const InputDecoration(labelText: 'Assignment')),
              const SizedBox(height: 10),
              TextField(
                  controller: _comment,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  void _save() {
    final price = double.tryParse(_price.text.trim());
    final dateText = _date.text.trim();
    if (price == null) return;
    Navigator.pop(context, {
      'title': widget.course.title,
      'day': _day,
      'date': dateText.isEmpty ? null : dateText,
      'hour': _hour.text.trim().isEmpty ? null : _hour.text.trim(),
      'price': price,
      'status': _status,
      'assignment': _assignment.text.trim(),
      'comment': _comment.text.trim(),
      'homeworkNextLesson': _homework.text.trim(),
    });
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.project, this.note});

  final StudentProject project;
  final CourseNote? note;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late String _piece = widget.note?.piece.isNotEmpty == true
      ? widget.note!.piece
      : widget.project.pieces.first;
  late final _comment = TextEditingController(text: widget.note?.comment ?? '');
  late int _reviewWeeks = widget.note?.reviewWeeks ?? 0;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.note == null ? 'Add Note' : 'Edit Note'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _piece,
              items: widget.project.pieces
                  .map((piece) =>
                      DropdownMenuItem(value: piece, child: Text(piece)))
                  .toList(),
              onChanged: (value) => setState(() => _piece = value ?? _piece),
              decoration: const InputDecoration(labelText: 'Piece'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _comment,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Comment'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _reviewWeeks,
              items: const [
                DropdownMenuItem(value: 0, child: Text('No review')),
                DropdownMenuItem(value: 1, child: Text('Next course')),
                DropdownMenuItem(value: 2, child: Text('In 2 courses')),
                DropdownMenuItem(value: 3, child: Text('In 3 courses')),
                DropdownMenuItem(value: 4, child: Text('In 4 courses')),
              ],
              onChanged: (value) =>
                  setState(() => _reviewWeeks = value ?? _reviewWeeks),
              decoration: const InputDecoration(labelText: 'Review'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {
            'piece': _piece,
            'comment': _comment.text.trim(),
            'reviewWeeks': _reviewWeeks == 0 ? null : _reviewWeeks,
            'targetCourseId': null,
          }),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog();

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _amount = TextEditingController();
  final _method = TextEditingController(text: 'Cash');
  final _note = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _method.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Payment'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 10),
            TextField(
                controller: _method,
                decoration: const InputDecoration(labelText: 'Method')),
            const SizedBox(height: 10),
            TextField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Note')),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(DateFormat.yMMMd().format(_date)),
              trailing: const Icon(Icons.calendar_month),
              onTap: _pickDate,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _date,
    );
    if (value != null) setState(() => _date = value);
  }

  void _save() {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null) return;
    Navigator.pop(context, {
      'amount': amount,
      'paymentDate': DateFormat('yyyy-MM-dd').format(_date),
      'method': _method.text.trim(),
      'note': _note.text.trim(),
    });
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: MaestroColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value == null || value!.trim().isEmpty ? 'Not set' : value!,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: MaestroColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 160,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: MaestroColors.muted)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(message, style: const TextStyle(color: MaestroColors.muted)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MaestroCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ProfileData {
  const _ProfileData({
    required this.student,
    required this.payments,
    this.paymentsError,
  });

  final Student student;
  final List<Payment> payments;
  final Object? paymentsError;

  _ProfileData copyWith({
    Student? student,
    List<Payment>? payments,
    Object? paymentsError,
  }) {
    return _ProfileData(
      student: student ?? this.student,
      payments: payments ?? this.payments,
      paymentsError: paymentsError ?? this.paymentsError,
    );
  }
}
