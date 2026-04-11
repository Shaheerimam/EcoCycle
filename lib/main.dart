import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/login_screen.dart';
// import 'screens/login.dart' hide LoginScreen;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Uncomment and add your Supabase project credentials.
  await Supabase.initialize(
    url: 'https://pikjsadlmqscfbuahjcn.supabase.co',
    anonKey: 'sb_publishable__Q8d0fZQe4T3CGneFlEDIg_mFZaNUJw',
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _themeProvider = ThemeProvider();

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onThemeChanged);
    _themeProvider.dispose();
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoCycle',
      debugShowCheckedModeBanner: false,
      themeMode: _themeProvider.mode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: LoginScreen(themeProvider: _themeProvider),
    );
  }
}
