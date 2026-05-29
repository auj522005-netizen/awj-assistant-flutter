/// ═══════════════════════════════════════════════════════════════════════════════
/// 🚀 OWJ Assistant — Main Entry Point
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Initializes flutter_dotenv, StorageService, and wraps the app
/// with MultiProvider. Supports RTL Arabic as primary language.
/// Main screen uses bottom navigation with 5 tabs.
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'package:owj_assistant/config/app_config.dart';
import 'package:owj_assistant/config/theme.dart';
import 'package:owj_assistant/providers/chat_provider.dart';
import 'package:owj_assistant/providers/app_provider.dart';
import 'package:owj_assistant/screens/home_screen.dart';
import 'package:owj_assistant/screens/chat_screen.dart';
import 'package:owj_assistant/screens/pillars_screen.dart';
import 'package:owj_assistant/screens/skills_screen.dart';
import 'package:owj_assistant/screens/memory_screen.dart';
import 'package:owj_assistant/services/storage_service.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: OwjColors.background,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  // Initialize dotenv (load .env if available, merge with environment)
  try {
    await dotenv.load(fileName: '.env', mergeWith: Platform.environment);
  } catch (_) {
    // .env file is optional — env vars from system/Codemagic will be used
    try {
      await dotenv.load(mergeWith: Platform.environment);
    } catch (_) {
      debugPrint('ملاحظة: ملف .env مش موجود');
    }
  }

  // Initialize storage service
  await StorageService.instance.init();

  // Run the app
  runApp(const OwjApp());
}

/// Root widget for the OWJ Assistant app.
class OwjApp extends StatelessWidget {
  const OwjApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => AppProvider()..loadAll()),
      ],
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(
        title: AppConfig.appNameAr,
        debugShowCheckedModeBanner: false,
        theme: owjDarkTheme,

        // RTL support for Arabic
        locale: const Locale('ar', 'EG'),
        supportedLocales: const [
          Locale('ar', 'EG'),
          Locale('en', 'US'),
        ],

        // Home is the main navigation shell
        home: const MainNavigation(),
        ),
      ),
    );
  }
}

/// Main navigation shell with 5 bottom navigation tabs.
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  /// Tab screens — lazy initialized
  final List<Widget> _screens = const [
    HomeScreen(),
    ChatScreen(),
    PillarsScreen(),
    SkillsScreen(),
    MemoryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Load chat history on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadChatHistory();
    });
  }

  /// Tab configuration data
  static const List<_TabConfig> _tabs = [
    _TabConfig(
      label: 'الرئيسية',
      icon: Icons.home_rounded,
      activeIcon: Icons.home,
    ),
    _TabConfig(
      label: 'محادثة',
      icon: Icons.chat_outlined,
      activeIcon: Icons.chat,
    ),
    _TabConfig(
      label: 'المحاور',
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart,
    ),
    _TabConfig(
      label: 'المهارات',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view,
    ),
    _TabConfig(
      label: 'الذاكرة',
      icon: Icons.psychology_outlined,
      activeIcon: Icons.psychology,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: OwjColors.border, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: _tabs.map((tab) {
            final isSelected = _tabs.indexOf(tab) == _currentIndex;
            return BottomNavigationBarItem(
              icon: Icon(
                isSelected ? tab.activeIcon : tab.icon,
                size: isSelected ? 26 : 24,
              ),
              label: tab.label,
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Configuration for a bottom navigation tab.
class _TabConfig {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _TabConfig({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
