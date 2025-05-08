import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RouteFinderScreen extends ConsumerWidget {
  const RouteFinderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RouteFinder'),
      ),
      body: Center(
        child: Text('RouteFinder Screen Content'),
      ),
    );
  }
}
