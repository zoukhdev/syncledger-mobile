import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  
  // Yield initial state
  final initialStatus = await connectivity.checkConnectivity();
  yield initialStatus.contains(ConnectivityResult.none) == false;

  // Listen to changes
  await for (final status in connectivity.onConnectivityChanged) {
    yield status.contains(ConnectivityResult.none) == false;
  }
});
