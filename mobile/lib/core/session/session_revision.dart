import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_controller.dart';

/// Synchronous identity boundary for private state and late request results.
final sessionRevisionProvider = NotifierProvider<SessionRevision, int>(
  SessionRevision.new,
);

class SessionRevision extends Notifier<int> {
  int _revision = 0;
  @override
  int build() {
    final session = ref.watch(sessionControllerProvider);
    void changed() {
      if (ref.mounted) state = ++_revision;
    }

    session.addListener(changed);
    ref.onDispose(() => session.removeListener(changed));
    return _revision;
  }
}
