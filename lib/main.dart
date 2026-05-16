import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/medical_search_service.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Must run before runApp; flutter_gemma requires the framework before initialization.
  await FlutterGemma.initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF070714),
    ),
  );

  // Portrait lock: single-hand use on budget phones is the primary rural UX constraint.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Parsed before runApp so the 28.5 MB JSON doesn't block the UI thread post-launch.
  await MedicalSearchService.instance.init();

  runApp(const GemOneApp());
}