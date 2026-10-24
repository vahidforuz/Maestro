import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'messaging_service.dart';

/// One summary cache and Realtime subscription for a signed-in portal.
class MessagingInbox extends ChangeNotifier with WidgetsBindingObserver {
  MessagingInbox(this.service);

  final MessagingService service;
  List<Map<String, dynamic>> conversations = const [];
  bool loading = true;
  String? error;
  RealtimeChannel? _channel;
  Timer? _refreshTimer;
  bool _disposed = false;
  bool _refreshing = false;
  bool _refreshAgain = false;

  int get unreadCount => conversations.fold<int>(
      0, (total, row) => total + (row['unreadCount'] as num? ?? 0).toInt());

  void start() {
    if (_channel != null) return;
    WidgetsBinding.instance.addObserver(this);
    refresh();
    _channel = service.watchSummaries(scheduleRefresh, refresh);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  void scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 250), refresh);
  }

  Future<void> refresh() async {
    if (_disposed) return;
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      final rows = await service.summaries();
      if (_disposed) return;
      conversations = rows;
      loading = false;
      error = null;
      notifyListeners();
    } catch (e) {
      if (_disposed) return;
      loading = false;
      error = '$e';
      notifyListeners();
    } finally {
      _refreshing = false;
      if (_refreshAgain && !_disposed) {
        _refreshAgain = false;
        unawaited(refresh());
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    if (_channel != null) unawaited(service.unwatch(_channel!));
    super.dispose();
  }
}
