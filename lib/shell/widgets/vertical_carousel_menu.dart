import 'package:flutter/material.dart';
import '../models/menu_item_data.dart';

class VerticalCarouselMenu extends StatefulWidget {
  final List<MenuItemData> menuItems;
  final Function(int) onItemSelected;
  final int initialIndex;

  const VerticalCarouselMenu({
    super.key, // Fixed: Using super parameter
    required this.menuItems,
    required this.onItemSelected,
    this.initialIndex = 0,
  });

  @override
  State<VerticalCarouselMenu> createState() => _VerticalCarouselMenuState();
}

class _VerticalCarouselMenuState extends State<VerticalCarouselMenu> {
  late final FixedExtentScrollController _controller;
  late int _selectedIndex;

  // Removed the unused field

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _controller = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: ListWheelScrollView.useDelegate(
          controller: _controller,
          itemExtent: 80, // Height of each item
          perspective: 0.005,
          diameterRatio: 2.0,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: _onItemChanged,
          childDelegate: ListWheelChildLoopingListDelegate(
            children:
                widget.menuItems.map((item) => _buildMenuItem(item)).toList(),
          ),
          // Configure to show approximately 4 items at a time
          magnification: 1.1, // Slightly enlarges the selected item
          useMagnifier: true,
          overAndUnderCenterOpacity: 0.7, // Fades the non-selected items
        ),
      ),
    );
  }

  Widget _buildMenuItem(MenuItemData item) {
    final isSelected = widget.menuItems[_selectedIndex].id == item.id;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected
            ? item.color.withAlpha(230) // ~0.9 opacity
            : item.color.withAlpha(153), // ~0.6 opacity
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? item.color.withAlpha(153) // ~0.6 opacity
                : item.color.withAlpha(77), // ~0.3 opacity
            blurRadius: isSelected ? 12 : 8,
            spreadRadius: isSelected ? 2 : 0,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          item.icon,
          color: Colors.white,
          size: isSelected ? 32 : 26,
        ),
      ),
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // Can be used to handle custom scroll behavior if needed
    return true;
  }

  void _onItemChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
    widget.onItemSelected(index);
  }
}
