import 'package:flutter/foundation.dart';

/// In-memory diagnostic status shown by the persistent debug overlay.
final ValueNotifier<String> debugStatus = ValueNotifier<String>('idle');

void updateDebugStatus(String status) {
  debugStatus.value = status;
}
