import 'dart:async';
import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/logging/app_logger.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      final logger = AppLogger.instance;
      try {
        await logger.initialize();
      } catch (error, stackTrace) {
        debugPrint('xinPOS logger initialization failed: $error\n$stackTrace');
      }

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        logger.error(
          'Flutter framework error',
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      PlatformDispatcher.instance.onError = (error, stackTrace) {
        logger.fatal(
          'Uncaught platform error',
          error: error,
          stackTrace: stackTrace,
        );
        return true;
      };

      logger.info('Starting xinPOS');
      runApp(const ProviderScope(child: XinPosApp()));
    },
    (error, stackTrace) {
      AppLogger.instance.fatal(
        'Uncaught asynchronous error',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );
}
