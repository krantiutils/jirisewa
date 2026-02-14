import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/core/routing/app_router.dart';
import 'package:jirisewa_mobile/core/services/session_service.dart';
import 'package:jirisewa_mobile/core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'http://localhost:54321',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
    ),
  );

  final sessionService = SessionService(Supabase.instance.client);

  runApp(JiriSewaApp(sessionService: sessionService));
}

class JiriSewaApp extends StatefulWidget {
  final SessionService sessionService;

  const JiriSewaApp({super.key, required this.sessionService});

  @override
  State<JiriSewaApp> createState() => _JiriSewaAppState();
}

class _JiriSewaAppState extends State<JiriSewaApp> {
  late final _router = buildRouter(widget.sessionService);

  @override
  Widget build(BuildContext context) {
    return SessionProvider(
      service: widget.sessionService,
      child: MaterialApp.router(
        title: 'JiriSewa',
        theme: buildAppTheme(),
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
