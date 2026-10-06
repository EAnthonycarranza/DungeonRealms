import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'client/app.dart';

/// Set with `--dart-define=QUICKSTART=true` (or `?quickstart` on web) to skip
/// the menus and drop straight into Goblinwood with a fresh Ranger.
const _quickstartDefine = bool.fromEnvironment('QUICKSTART');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final quickstart = _quickstartDefine || (kIsWeb && Uri.base.queryParameters.containsKey('quickstart'));
  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  runApp(DungeonRealmsApp(quickstart: quickstart));
}
