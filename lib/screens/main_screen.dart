import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
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
    // Add small delay to ensure the widget is built if it hasn't been yet
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey.shade400,
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            _triggerRefreshForTab(index);
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Compare'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Advisor'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
