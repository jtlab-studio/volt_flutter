import 'package:flutter/material.dart';

/// Represents a menu item in the vertical carousel
class MenuItemData {
  /// Unique identifier for the menu item
  final String id;
  
  /// Display title for the menu item
  final String title;
  
  /// Icon to display in the menu button
  final IconData icon;
  
  /// Primary color for the menu item
  final Color color;
  
  /// Route name for navigation (optional)
  final String? routeName;

  MenuItemData({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    this.routeName,
  });
}
