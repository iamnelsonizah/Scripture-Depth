import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/network/api_client.dart';
import 'core/network/supabase_service.dart';
import 'core/services/audio_bible_service.dart';
import 'core/services/app_settings_service.dart';
import 'core/services/reading_plan_service.dart';
import 'core/services/study_journal_service.dart';
import 'features/navigation/main_nav_scaffold.dart';
import 'features/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = ApiClient(baseUrl: 'http://127.0.0.1:8000/api/v1');
  final supabaseService = SupabaseService(apiClient: apiClient);

  // Initialize Supabase with dart-define environment keys if passed at build time
  await supabaseService.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  // Initialize Audio Bible Service, App Settings, Reading Plans & Study Journal
  await AudioBibleService().initialize();
  await AppSettingsService().initialize();
  await ReadingPlanService().initialize();
  await StudyJournalService().initialize();

  // Load saved theme preference
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('theme_mode') ?? 'system';
  ThemeMode initialMode = ThemeMode.system;
  if (savedTheme == 'light') initialMode = ThemeMode.light;
  if (savedTheme == 'dark') initialMode = ThemeMode.dark;

  runApp(ScriptureDepthApp(
    apiClient: apiClient,
    supabaseService: supabaseService,
    initialThemeMode: initialMode,
  ));
}

class ScriptureDepthApp extends StatefulWidget {
  final ApiClient apiClient;
  final SupabaseService supabaseService;
  final ThemeMode initialThemeMode;
  final bool? showOnboarding;

  const ScriptureDepthApp({
    super.key,
    required this.apiClient,
    required this.supabaseService,
    this.initialThemeMode = ThemeMode.system,
    this.showOnboarding,
  });

  @override
  State<ScriptureDepthApp> createState() => _ScriptureDepthAppState();
}

class _ScriptureDepthAppState extends State<ScriptureDepthApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
  }

  bool get _needsOnboarding {
    if (widget.showOnboarding != null) return widget.showOnboarding!;
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    return !AppSettingsService().hasCompletedOnboarding && !isTest;
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    final prefs = await SharedPreferences.getInstance();
    String val = 'system';
    if (mode == ThemeMode.light) val = 'light';
    if (mode == ThemeMode.dark) val = 'dark';
    await prefs.setString('theme_mode', val);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScriptureDepth',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: _needsOnboarding
          ? OnboardingScreen(
              onComplete: () {
                setState(() {});
              },
            )
          : MainNavScaffold(
              apiClient: widget.apiClient,
              supabaseService: widget.supabaseService,
              themeMode: _themeMode,
              onThemeModeChanged: _setThemeMode,
            ),
    );
  }
}
