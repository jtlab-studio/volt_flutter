import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RunTrackerScreen extends ConsumerWidget {
  const RunTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RunTracker'),
      ),
      body: Center(
        child: Text('RunTracker Screen Content'),
      ),
    );
  }
}
