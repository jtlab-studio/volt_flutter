import 'package:flutter/material.dart';
import '../models/menu_item_data.dart';

class VerticalCarouselMenu extends StatefulWidget {
  final List<MenuItemData> menuItems;
  final Function(int) onItemSelected;
  final int initialIndex;

  const VerticalCarouselMenu({
    super.key,
    required this.menuItems,
    required this.onItemSelected,
    this.initialIndex = 0,
  });

  @override
  State<VerticalCarouselMenu> createState() => _VerticalCarouselMenuState();
}

class _VerticalCarouselMenuState extends State<VerticalCarouselMenu> {
  late final PageController _pageController;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    // Initialize PageController with viewportFraction to show 4 items
    _pageController = PageController(
      initialPage: _selectedIndex,
      viewportFraction: 0.25, // Show 4 items at a time
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: RotatedBox(
        quarterTurns: 1, // Rotate to make horizontal PageView appear vertical
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.menuItems.length *
              3, // Triple the items for infinite scrolling effect
          scrollDirection:
              Axis.horizontal, // This becomes vertical after rotation
          onPageChanged: _onItemChanged,
          padEnds: false,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            // Calculate actual index with wrapping for infinite scrolling effect
            final wrappedIndex = index % widget.menuItems.length;
            return _buildMenuItem(
                widget.menuItems[wrappedIndex], wrappedIndex == _selectedIndex);
          },
        ),
      ),
    );
  }

  Widget _buildMenuItem(MenuItemData item, bool isSelected) {
    return RotatedBox(
      quarterTurns: 3, // Rotate back to normal orientation
      child: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              item.color.withAlpha(230), // All buttons bright and highlighted
          boxShadow: [
            BoxShadow(
              color: item.color.withAlpha(153),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Icon(
            item.icon,
            color: Colors.white,
            size: 30, // All icons same size
          ),
        ),
      ),
    );
  }

  void _onItemChanged(int index) {
    final wrappedIndex = index % widget.menuItems.length;
    setState(() {
      _selectedIndex = wrappedIndex;
    });
    widget.onItemSelected(wrappedIndex);

    // Handling infinite scroll behavior
    if (index == widget.menuItems.length * 2 - 1) {
      // If we're at the end of the tripled list, jump to the middle set
      _pageController.jumpToPage(wrappedIndex + widget.menuItems.length);
    } else if (index == 0) {
      // If we're at the start, jump to the middle set
      _pageController.jumpToPage(wrappedIndex + widget.menuItems.length);
    }
  }
}
