enum AppSection {
  dashboard('Dashboard'),
  students('Students'),
  calendar('Calendar'),
  payments('Payments'),
  settings('Settings');

  const AppSection(this.label);

  final String label;
}
