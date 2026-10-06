import 'package:flutter/material.dart';

class AsyncState<T> extends StatelessWidget {
  const AsyncState({
    super.key,
    required this.snapshot,
    required this.builder,
    this.emptyMessage,
  });

  final AsyncSnapshot<T> snapshot;
  final Widget Function(T data) builder;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(
        child: Text(
          snapshot.error.toString(),
          textAlign: TextAlign.center,
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
