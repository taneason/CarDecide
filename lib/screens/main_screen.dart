import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../services/snap_identify_helper.dart';
import 'dashboard_screen.dart';
import 'car_comparison_screen.dart';
import 'ai_chat_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  MainScreen({Key? key}) : super(key: key ?? globalKey);

  static final GlobalKey<MainScreenState> globalKey = GlobalKey<MainScreenState>();

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey<DashboardScreenState>();
  final GlobalKey<CarComparisonScreenState> _compareKey = GlobalKey<CarComparisonScreenState>();
  final GlobalKey<AiChatScreenState> _aiChatKey = GlobalKey<AiChatScreenState>();
  final GlobalKey<ProfileScreenState> _profileKey = GlobalKey<ProfileScreenState>();

  List<Widget> get _pages => [
    DashboardScreen(key: _dashboardKey),
    CarComparisonScreen(key: _compareKey, selectedCars: const []),
    AiChatScreen(key: _aiChatKey),
    ProfileScreen(key: _profileKey),
  ];

  void setTabIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
    _triggerRefreshForTab(index);
  }

  void _triggerRefreshForTab(int index) {
    if (index == 0) {
      _dashboardKey.currentState?.refresh();
    } else if (index == 3) {
      _profileKey.currentState?.refresh();
    }
  }

  void navigateToCompare(List<Map<String, dynamic>> cars) {
    Navigator.popUntil(context, (route) => route.isFirst);
    setState(() {
      _currentIndex = 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _compareKey.currentState?.setCars(cars);
    });
  }

  void navigateToAiChat(String message) {
    Navigator.popUntil(context, (route) => route.isFirst);
    setState(() {
      _currentIndex = 2;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _aiChatKey.currentState?.sendDirectMessage(message);
    });
  }

  Widget _buildNavItem(int index, IconData unselectedIcon, IconData selectedIcon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.primary : Colors.grey.shade400;

    return Expanded(
      child: InkWell(
        onTap: () => setTabIndex(index),
        splashColor: AppColors.primary.withValues(alpha: 0.1),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? selectedIcon : unselectedIcon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      floatingActionButton: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF00897B), AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => SnapIdentifyHelper.handleSnapIdentify(context),
            child: const Center(
              child: Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: const _LoweredDockedFabLocation(offsetY: 10.0),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
              _buildNavItem(1, Icons.bar_chart_outlined, Icons.bar_chart, 'Compare'),
              const SizedBox(width: 64),
              _buildNavItem(2, Icons.chat_bubble_outline, Icons.chat_bubble, 'Advisor'),
              _buildNavItem(3, Icons.person_outline, Icons.person, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoweredDockedFabLocation extends FloatingActionButtonLocation {
  final double offsetY;
  const _LoweredDockedFabLocation({this.offsetY = 10.0});

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final Offset standardOffset = FloatingActionButtonLocation.centerDocked.getOffset(scaffoldGeometry);
    return Offset(standardOffset.dx, standardOffset.dy + offsetY);
  }
}
