import 'package:flutter/material.dart';

import '../widgets/maestro_card.dart';
import '../widgets/section_header.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: title, subtitle: subtitle),
            const SizedBox(height: 18),
            const MaestroCard(
              child: Text(
                  'This section is reserved for the next API-backed increment.'),
            ),
          ],
        ),
      ),
    );
  }
}
