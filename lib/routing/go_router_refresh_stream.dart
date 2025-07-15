import 'dart:async';

import 'package:flutter/foundation.dart';

/// This class was created by watching a video by Andrea Bizzotto
/// It's a wrapper around a [Stream] that notifies listeners when the stream
/// emits a new value.
/// This is useful for refreshing the UI when the stream emits a new value.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
