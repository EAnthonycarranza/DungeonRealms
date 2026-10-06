import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'client/app.dart';

/// Set with `--dart-define=QUICKSTART=true` (or `?quickstart` on web) to skip
/// the menus and drop straight into Goblinwood with a fresh Ranger.
const _quickstartDefine = bool.fromEnvironment('QUICKSTART');

/// Dev-only (ignored in release builds): `?at=<waypoint id>&level=<n>` on
/// web, or `--dart-define=START_AT=<waypoint id>` / `START_LEVEL=<n>`.
const _startAtDefine = String.fromEnvironment('START_AT');
const _startLevelDefine = int.fromEnvironment('START_LEVEL');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final query = kIsWeb ? Uri.base.queryParameters : const <String, String>{};
  final dev = kReleaseMode
      ? const DevStart()
      : DevStart(
          waypoint: query['at'] ?? (_startAtDefine.isEmpty ? null : _startAtDefine),
          level: int.tryParse(query['level'] ?? '') ?? (_startLevelDefine > 0 ? _startLevelDefine : null),
        );
  final quickstart = _quickstartDefine || query.containsKey('quickstart') || !dev.isEmpty;
  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  runApp(DungeonRealmsApp(quickstart: quickstart, devStart: dev));
}
