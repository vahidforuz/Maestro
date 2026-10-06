import 'package:flutter/material.dart';

import 'screens/maestro_app.dart';
import 'services/api_client.dart';
import 'services/maestro_api.dart';
import 'theme/maestro_theme.dart';

void main() {
  const apiBaseUrl = String.fromEnvironment(
    'MAESTRO_API_BASE_URL',
    defaultValue: 'http://localhost:8080/api',
  );

  runApp(
    MaestroMobileApp(
      api: MaestroApi(ApiClient(baseUrl: apiBaseUrl)),
    ),
  );
}

class MaestroMobileApp extends StatelessWidget {
  const MaestroMobileApp({super.key, required this.api});

  final MaestroApi api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maestro',
      debugShowCheckedModeBanner: false,
      theme: MaestroTheme.light(),
      home: MaestroApp(api: api),
    );
  }
}
