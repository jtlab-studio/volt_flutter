import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_item_data.dart';
import '../widgets/vertical_carousel_menu.dart';
import '../../core/constants/app_constants.dart';

class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key});

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen>
    with SingleTickerProviderStateMixin {
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

  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onMenuItemSelected(int index) {
    if (_selectedIndex != index) {
      _animationController.reverse().then((_) {
        setState(() {
          _selectedIndex = index;
        });
        _animationController.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentMenuItem = menuItems[_selectedIndex];
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient/pattern
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF121212),
                  Color.lerp(const Color(0xFF121212), currentMenuItem.color,
                          0.1) ??
                      const Color(0xFF121212),
                ],
              ),
            ),
          ),

          // Main content area
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App header
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'VOLT',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentMenuItem.title,
                            style: TextStyle(
                              fontSize: 18,
                              color: currentMenuItem.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      // Top-right status icons (example)
                      Row(
                        children: [
                          Icon(
                            Icons.bluetooth_connected,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.notifications_none,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Selected menu item content area with fade animation
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                        left: 24.0, bottom: 24.0, right: 90.0),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildScreenContent(currentMenuItem),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Vertical carousel menu on the right edge
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.only(bottom: 80.0), // Space for footer
                child: Container(
                  height: screenHeight * 0.6, // Limited height for 4 items
                  alignment: Alignment.center,
                  child: VerticalCarouselMenu(
                    // This is a widget, not a method
                    menuItems: menuItems,
                    onItemSelected: _onMenuItemSelected,
                    initialIndex: _selectedIndex,
                  ),
                ),
              ),
            ),
          ),

          // Footer area
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 64,
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
              child: SafeArea(
                top: false,
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

  Widget _buildScreenContent(MenuItemData menuItem) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: menuItem.color.withAlpha(77),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            // Header section for the content area
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: menuItem.color.withAlpha(25),
                border: Border(
                  bottom: BorderSide(
                    color: menuItem.color.withAlpha(77),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    menuItem.icon,
                    color: menuItem.color,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    menuItem.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Onboarding content for each menu item
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      menuItem.icon,
                      size: 80,
                      color: menuItem.color.withAlpha(128),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '${menuItem.title} Module',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _getModuleDescription(menuItem.id),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[300],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _buildFeatureList(menuItem),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to the actual module screen
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: menuItem.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        'Open ${menuItem.title}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureList(MenuItemData menuItem) {
    final features = _getModuleFeatures(menuItem.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Key Features:',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        ...features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: menuItem.color,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[300],
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  String _getModuleDescription(String moduleId) {
    switch (moduleId) {
      case 'run':
        return 'Track your runs with GPS, monitor your pace, distance, and calories burned. Get real-time audio feedback during your runs.';
      case 'routes':
        return 'Discover running routes in your area, filter by distance, elevation, and difficulty. Save your favorite routes for quick access.';
      case 'race':
        return 'Prepare for your upcoming races with specialized training plans, race day checklists, and performance prediction tools.';
      case 'academy':
        return 'Learn running techniques, nutrition strategies, and injury prevention with expert-created video courses and guides.';
      case 'profile':
        return 'View your running stats, achievements, and progress. Set goals and track your improvement over time.';
      case 'settings':
        return 'Customize your app experience, connect devices, manage notifications, and set your preferences.';
      case 'sensors':
        return 'Connect and manage your fitness devices, heart rate monitors, and other sensors to enhance your running data.';
      default:
        return 'Explore this feature to enhance your running experience with Volt Running Tracker.';
    }
  }

  List<String> _getModuleFeatures(String moduleId) {
    switch (moduleId) {
      case 'run':
        return [
          'Real-time GPS tracking with accurate pace and distance metrics',
          'Voice coach provides updates during your run',
          'Heart rate zone monitoring and calorie tracking',
          'Auto-pause when you stop at intersections',
          'Post-run analytics with detailed performance insights'
        ];
      case 'routes':
        return [
          'Discover popular running routes in your neighborhood',
          'Filter routes by distance, elevation, terrain, and difficulty',
          'Create and share your own custom routes',
          'View detailed elevation profiles and safety ratings',
          'Download routes for offline use'
        ];
      case 'race':
        return [
          'Custom training plans for 5K, 10K, half marathon, and marathon',
          'Race day preparation checklists and nutrition guides',
          'Performance prediction based on your training data',
          'Pace strategy calculator for optimal race performance',
          'Recovery plans after race completion'
        ];
      case 'academy':
        return [
          'Video tutorials on proper running techniques',
          'Nutrition guides for runners at all levels',
          'Injury prevention exercises and rehabilitation guides',
          'Training methodology articles from professional coaches',
          'Mental training and race strategy courses'
        ];
      case 'profile':
        return [
          'Comprehensive running history and statistics dashboard',
          'Achievement badges and milestone tracking',
          'Personal records and progress visualization',
          'Goal setting and progress tracking',
          'Share achievements on social media'
        ];
      case 'settings':
        return [
          'Customize app appearance and theme',
          'Manage notification preferences',
          'Connect and sync with other fitness apps',
          'Adjust voice coach settings and preferences',
          'Backup and restore your running data'
        ];
      case 'sensors':
        return [
          'Connect heart rate monitors and chest straps',
          'Pair with foot pods for improved running metrics',
          'Integration with smart watches and fitness trackers',
          'Support for Bluetooth and ANT+ devices',
          'Calibration tools for improved accuracy'
        ];
      default:
        return [
          'Feature 1',
          'Feature 2',
          'Feature 3',
          'Feature 4',
          'Feature 5',
        ];
    }
  }
}
