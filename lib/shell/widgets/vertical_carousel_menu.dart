import 'package:flutter/material.dart';
import '../models/menu_item_data.dart';

class VerticalCarouselMenu extends StatefulWidget {
  final List<MenuItemData> menuItems;
  final Function(String) onModuleSelected;
  final double bottomPadding;

  const VerticalCarouselMenu({
    super.key,
    required this.menuItems,
    required this.onModuleSelected,
    this.bottomPadding = 80.0,
  });

  @override
  State<VerticalCarouselMenu> createState() => _VerticalCarouselMenuState();
}

class _VerticalCarouselMenuState extends State<VerticalCarouselMenu> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    // Initialize PageController with viewportFraction to show 4 items
    _pageController = PageController(
      initialPage: widget.menuItems.length,
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
      // Fixed: Using SizedBox instead of Container for whitespace
      width: 70, // Narrower width for the carousel
      child: RotatedBox(
        quarterTurns: 1, // Rotate to make horizontal PageView appear vertical
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.menuItems.length *
              3, // Triple the items for infinite scrolling effect
          scrollDirection:
              Axis.horizontal, // This becomes vertical after rotation
          onPageChanged: _onPageChanged,
          padEnds: false,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            // Calculate actual index with wrapping for infinite scrolling effect
            final wrappedIndex = index % widget.menuItems.length;
            return _buildMenuItem(widget.menuItems[wrappedIndex]);
          },
        ),
      ),
    );
  }

  Widget _buildMenuItem(MenuItemData item) {
    return GestureDetector(
      onTap: () => widget.onModuleSelected(item.id),
      child: RotatedBox(
        quarterTurns: 3, // Rotate back to normal orientation
        child: Container(
          margin: const EdgeInsets.symmetric(
              vertical: 4,
              horizontal: 10), // Reduce vertical margin to bring buttons closer
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: item.color.withAlpha(230), // Bright and highlighted
            boxShadow: [
              BoxShadow(
                color: item.color.withAlpha(153),
                blurRadius: 8,
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
      ),
    );
  }

  void _onPageChanged(int index) {
    // Handling infinite scroll behavior
    if (index == widget.menuItems.length * 2 - 1) {
      // If we're at the end of the tripled list, jump to the middle set
      _pageController.jumpToPage(widget.menuItems.length - 1);
    } else if (index == 0) {
      // If we're at the start, jump to the middle set
      _pageController.jumpToPage(widget.menuItems.length);
    }
  }
}
