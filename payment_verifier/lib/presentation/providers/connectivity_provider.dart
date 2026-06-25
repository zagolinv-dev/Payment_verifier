import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectionQuality { good, slow, none }

class ConnectionState {
  final ConnectionQuality quality;
  final String message;
  final bool wasGood;
  final DateTime lastChecked;

  ConnectionState({
    this.quality = ConnectionQuality.good,
    this.message = '',
    this.wasGood = true,
    DateTime? lastChecked,
  }) : lastChecked = lastChecked ?? DateTime.now();

  ConnectionState copyWith({
    ConnectionQuality? quality,
    String? message,
    bool? wasGood,
    DateTime? lastChecked,
  }) {
    return ConnectionState(
      quality: quality ?? this.quality,
      message: message ?? this.message,
      wasGood: wasGood ?? this.wasGood,
      lastChecked: lastChecked ?? DateTime.now(),
    );
  }
}

class ConnectivityNotifier extends StateNotifier<ConnectionState> {
  ConnectivityNotifier() : super(ConnectionState()) {
    _monitor();
  }

  StreamSubscription? _connSub;
  Timer? _pingTimer;
  final _connectivity = Connectivity();

  void _monitor() {
    _connSub = _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (!hasConnection) {
        state = state.copyWith(
          quality: ConnectionQuality.none,
          message: 'No internet connection',
          wasGood: false,
        );
      } else {
        _checkLatency();
        _startPinging();
      }
    });

    _checkLatency();
    _startPinging();
  }

  void _startPinging() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (state.quality != ConnectionQuality.none) {
        _checkLatency();
      }
    });
  }

  Future<void> _checkLatency() async {
    try {
      final stopwatch = Stopwatch()..start();
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      stopwatch.stop();

      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        state = state.copyWith(
          quality: ConnectionQuality.none,
          message: 'No internet connection',
          wasGood: false,
        );
        return;
      }

      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed > 3000) {
        state = state.copyWith(
          quality: ConnectionQuality.slow,
          message: 'Network is lagging — slow response (${elapsed}ms)',
          wasGood: false,
        );
      } else if (elapsed > 1500) {
        state = state.copyWith(
          quality: ConnectionQuality.slow,
          message: 'Network is slow — try a better connection',
          wasGood: false,
        );
      } else {
        state = state.copyWith(
          quality: ConnectionQuality.good,
          message: '',
          wasGood: true,
        );
      }
    } on SocketException {
      state = state.copyWith(
        quality: ConnectionQuality.none,
        message: 'No internet connection',
        wasGood: false,
      );
    } on TimeoutException {
      state = state.copyWith(
        quality: ConnectionQuality.slow,
        message: 'Network is lagging — connection timed out',
        wasGood: false,
      );
    }
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _pingTimer?.cancel();
    super.dispose();
  }
}

final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, ConnectionState>((ref) {
  return ConnectivityNotifier();
});
