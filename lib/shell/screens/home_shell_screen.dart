import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_item_data.dart';
import '../widgets/vertical_carousel_menu.dart';
import '../../core/constants/app_constants.dart';
import '../../features/sensors/screens/sensors_screen.dart';

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
  ];

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
          MaterialPageRoute(builder: (context) => const SensorsScreen()),
        );
        break;
      case 'run':
        _showModuleMessage('Run Tracker');
        break;
      case 'routes':
        _showModuleMessage('Local Route Finder');
        break;
      case 'race':
        _showModuleMessage('Race Prep');
        break;
      case 'academy':
        _showModuleMessage('Academy');
        break;
      case 'profile':
        _showModuleMessage('Profile');
        break;
      case 'settings':
        _showModuleMessage('Settings');
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
              child: _mainContent,
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
                  _buildFooterButton(Icons.home, 'Home'),
                  _buildFooterButton(Icons.favorite_border, 'Favorites'),
                  _buildFooterButton(Icons.history, 'History'),
                  _buildFooterButton(Icons.support_agent, 'Support'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterButton(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.grey[400],
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }
}
