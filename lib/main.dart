import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'servergy_app.dart';

void main() {
  // Flutter-Plugins (z. B. der sichere Schlüsselspeicher) müssen gebunden
  // sein, bevor sie aus dem Widget-Baum heraus verwendet werden können.
  WidgetsFlutterBinding.ensureInitialized();
  // ProviderScope stellt Riverpod-Providern ihren gemeinsamen Container bereit.
  runApp(const ProviderScope(child: ServergyApp()));
}
