import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider global qui suit l'état de la connexion internet
final connectivityProvider = StreamNotifierProvider<ConnectivityNotifier, bool>(() {
  return ConnectivityNotifier();
});

class ConnectivityNotifier extends StreamNotifier<bool> {
  @override
  Stream<bool> build() {
    return Connectivity().onConnectivityChanged.map((results) {
      // connectivity_plus v6 renvoie une List<ConnectivityResult>
      return results.any((r) => r != ConnectivityResult.none);
    });
  }
}
