import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/network/supabase_service.dart';
import '../../core/services/reader_navigation_service.dart';
import '../home/home_screen.dart';
import '../reader/reader_screen.dart';
import '../search/search_screen.dart';
import '../study/study_hub_screen.dart';
import '../profile/profile_screen.dart';

class MainNavScaffold extends StatefulWidget {
  final ApiClient apiClient;
  final SupabaseService supabaseService;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const MainNavScaffold({
    super.key,
    required this.apiClient,
    required this.supabaseService,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<MainNavScaffold> createState() => _MainNavScaffoldState();
}

class _MainNavScaffoldState extends State<MainNavScaffold> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    ReaderNavigationService().switchToReadTab = () {
      if (mounted) {
        setState(() => _currentIndex = 1);
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;

    final screens = [
      HomeScreen(
        apiClient: widget.apiClient,
        supabaseService: widget.supabaseService,
        onNavigateToRead: () => setState(() => _currentIndex = 1),
        onNavigateToStudy: () => setState(() => _currentIndex = 3),
      ),
      ReaderScreen(apiClient: widget.apiClient),
      SearchScreen(apiClient: widget.apiClient),
      StudyHubScreen(
        apiClient: widget.apiClient,
        supabaseService: widget.supabaseService,
        onNavigateToRead: () => setState(() => _currentIndex = 1),
      ),
      ProfileScreen(
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
        supabaseService: widget.supabaseService,
        apiClient: widget.apiClient,
      ),
    ];

    return Scaffold(
      backgroundColor: ext.paper,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF16251E),
          border: Border(top: BorderSide(color: Color(0xFF24362C), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: const Color(0xFF16251E),
          selectedItemColor: const Color(0xFFD4AF37),
          unselectedItemColor: const Color(0xFF8A9A86),
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book),
              label: 'Read',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_stories_outlined),
              activeIcon: Icon(Icons.auto_stories),
              label: 'Study',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
