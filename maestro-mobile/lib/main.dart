import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_environment.dart';
import 'screens/maestro_app.dart';
import 'screens/public_availability_screen.dart';
import 'services/maestro_data_source.dart';
import 'services/supabase_maestro_data_source.dart';
import 'services/teacher_auth.dart';
import 'theme/maestro_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseEnvironment.validate();
  if (!SupabaseEnvironment.isConfigured) {
    runApp(const MaterialApp(
        home: Scaffold(
            body: Center(
      child: Text(
          'Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY to start Maestro.'),
    ))));
    return;
  }
  await Supabase.initialize(
    url: SupabaseEnvironment.url,
    publishableKey: SupabaseEnvironment.publishableKey,
  );
  final client = Supabase.instance.client;
  final segments =
      Uri.base.pathSegments.where((part) => part.isNotEmpty).toList();
  if (segments.length == 2 && segments.first == 'availability') {
    runApp(MaterialApp(
      title: 'Maestro availability',
      theme: MaestroTheme.light(),
      debugShowCheckedModeBanner: false,
      home: PublicAvailabilityScreen(client: client, token: segments.last),
    ));
    return;
  }
  runApp(
    MaestroMobileApp(
      api: SupabaseMaestroDataSource(client),
      auth: SupabaseTeacherAuth(client),
    ),
  );
}

class MaestroMobileApp extends StatelessWidget {
  const MaestroMobileApp({super.key, required this.api, required this.auth});

  final MaestroDataSource api;
  final TeacherAuth auth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maestro',
      debugShowCheckedModeBanner: false,
      theme: MaestroTheme.light(),
      home: MaestroApp(api: api, auth: auth),
    );
  }
}
