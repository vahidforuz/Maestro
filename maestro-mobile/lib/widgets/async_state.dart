import 'package:flutter/material.dart';

class AsyncState<T> extends StatelessWidget {
  const AsyncState({
    super.key,
    required this.snapshot,
    required this.builder,
    this.emptyMessage,
    this.onRetry,
  });

  final AsyncSnapshot<T> snapshot;
  final Widget Function(T data) builder;
  final String? emptyMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              snapshot.error.toString(),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      );
    }
    final data = snapshot.data;
    if (data == null) {
      return Center(child: Text(emptyMessage ?? 'No data found.'));
    }
    return builder(data);
  }
}
