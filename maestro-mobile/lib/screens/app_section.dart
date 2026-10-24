enum AppSection {
  dashboard('Dashboard'),
  students('Students'),
  calendar('Calendar'),
  messages('Messages'),
  payments('Payments'),
  settings('Settings');

  const AppSection(this.label);

  final String label;
}
