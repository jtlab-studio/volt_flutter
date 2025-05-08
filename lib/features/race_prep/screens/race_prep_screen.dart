import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RacePrepScreen extends ConsumerWidget {
  const RacePrepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RacePrep'),
      ),
      body: Center(
        child: Text('RacePrep Screen Content'),
      ),
    );
  }
}
