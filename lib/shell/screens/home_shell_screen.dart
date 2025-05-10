// Updated import for the enhanced sensors screen
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_item_data.dart';
import '../widgets/vertical_carousel_menu.dart';
import '../../core/constants/app_constants.dart';
import '../../features/sensors/screens/sensors_screen.dart';
import '../../features/sensors/screens/gps_hub_screen.dart'; // Added GPS Hub import
import '../../features/run_tracker/screens/activity_tracker_screen.dart';
import '../../features/academy/screens/academy_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/race_prep/screens/race_prep_screen.dart';
import '../../features/route_finder/screens/route_finder_screen.dart';
import '../../features/settings/screens/settings_screen.dart';

class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key});

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> {
  // Menu items
  final List<MenuItemData> menuItems = [
    MenuItemData(
        id: 'run',
        title: AppConstants.runTracker,
        icon: Icons.directions_run,
        color: Colors.blue),
    MenuItemData(
        id: 'routes',
        title: AppConstants.routeFinder,
        icon: Icons.map,
        color: Colors.green),
    MenuItemData(
        id: 'race',
        title: AppConstants.racePrep,
        icon: Icons.flag,
        color: Colors.orange),
    MenuItemData(
        id: 'academy',
        title: AppConstants.academy,
        icon: Icons.school,
        color: Colors.purple),
    MenuItemData(
        id: 'profile',
        title: AppConstants.profile,
        icon: Icons.person,
        color: Colors.indigo),
    MenuItemData(
        id: 'settings',
        title: AppConstants.settings,
        icon: Icons.settings,
        color: Colors.blueGrey),
    MenuItemData(
        id: 'sensors',
        title: AppConstants.sensors,
        icon: Icons.bluetooth,
        color: Colors.teal),
    MenuItemData(
        id: 'gps_hub',
        title: AppConstants.gpsHub,
        icon: Icons.gps_fixed,
        color: Colors.amber),
  ];

  // Current selected tab index for bottom navigation
  int _currentTabIndex = 0;

  // Fixed: Made _mainContent final
  final Widget _mainContent = const Center(
    child: Text(
      'Welcome to Volt Running Tracker',
      style: TextStyle(
        fontSize: 24,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  void _navigateToModule(String moduleId) {
    // Handle navigation to different modules
    switch (moduleId) {
      case 'sensors':
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  const SensorsScreen()), // Updated to use enhanced screen
        );
        break;
      case 'gps_hub':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GpsHubScreen()),
        );
        break;
      case 'run':
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const ActivityTrackerScreen()),
        );
        break;
      case 'routes':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RouteFinderScreen()),
        );
        break;
      case 'race':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RacePrepScreen()),
        );
        break;
      case 'academy':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AcademyScreen()),
        );
        break;
      case 'profile':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
        break;
      case 'settings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
        break;
    }
  }

  void _showModuleMessage(String moduleName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening $moduleName module'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // Handle tab change in bottom navigation
  void _onTabTapped(int index) {
    setState(() {
      _currentTabIndex = index;
    });

    // Show message for tabs other than home
    if (index != 0) {
      String tabName = '';
      switch (index) {
        case 1:
          tabName = 'Favorites';
          break;
        case 2:
          tabName = 'History';
          break;
        case 3:
          tabName = 'Support';
          break;
      }
      _showModuleMessage(tabName);
    }
  }

  // Get the active content based on selected tab
  Widget _getTabContent() {
    // For now, only home tab has content
    // In a full implementation, you would return different screens based on index
    switch (_currentTabIndex) {
      case 0:
        return _mainContent;
      default:
        return Center(
          child: Text(
            'Tab $_currentTabIndex Content Coming Soon',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white70,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final footerHeight = 64.0;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF121212),
          ),

          // Main content area
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.only(right: 80.0), // Space for the carousel
              child: _getTabContent(),
            ),
          ),

          // Vertical carousel menu on the right edge - positioned in lower half
          Positioned(
            right: 0,
            bottom: footerHeight + bottomPadding, // Position above the footer
            height: screenHeight *
                0.4, // Take up roughly lower half of screen above footer
            child: VerticalCarouselMenu(
              menuItems: menuItems,
              onModuleSelected: _navigateToModule,
              bottomPadding: footerHeight + bottomPadding,
            ),
          ),

          // Footer area
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: footerHeight + bottomPadding,
              padding: EdgeInsets.only(bottom: bottomPadding),
              decoration: BoxDecoration(
                color: Colors.black,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(128),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFooterButton(Icons.home, 'Home', 0),
                  _buildFooterButton(Icons.favorite_border, 'Favorites', 1),
                  _buildFooterButton(Icons.history, 'History', 2),
                  _buildFooterButton(Icons.support_agent, 'Support', 3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterButton(IconData icon, String label, int index) {
    final isSelected = _currentTabIndex == index;

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.blue : Colors.grey[400],
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.blue : Colors.grey[400],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // Method to update tab programmatically (useful for deep linking)
  void setCurrentTab(int index) {
    if (mounted) {
      setState(() {
        _currentTabIndex = index;
      });
    }
  }

  // Method to show quick actions - can be called from other parts of the app
  void showQuickActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickActionButton(
                  icon: Icons.directions_run,
                  label: 'New Run',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToModule('run');
                  },
                ),
                _buildQuickActionButton(
                  icon: Icons.gps_fixed,
                  label: 'GPS Hub',
                  color: Colors.amber,
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToModule('gps_hub');
                  },
                ),
                _buildQuickActionButton(
                  icon: Icons.bluetooth,
                  label: 'Sensors',
                  color: Colors.teal,
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToModule('sensors');
                  },
                ),
                _buildQuickActionButton(
                  icon: Icons.settings,
                  label: 'Settings',
                  color: Colors.blueGrey,
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToModule('settings');
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(128),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(
              icon,
              color: color,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
