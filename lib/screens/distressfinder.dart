// lib/screens/distressfinder.dart

import 'package:flutter/material.dart';
import 'image_picker_screen.dart';
import '../navigation.dart';

class DistressFinderScreen extends StatelessWidget {
  const DistressFinderScreen({super.key});

  void _navigateToImagePickerScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImagePickerScreen()),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.image_search,
          size: 100,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 20),
        Text(
          'Distress Finder',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          icon: const Icon(Icons.photo_library),
          label: const Text('Select types of distress'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          ),
          onPressed: () => _navigateToImagePickerScreen(context),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Distress Finder'),
        centerTitle: true,
        elevation: 0,
      ),
      drawer: const MainDrawer(),
      body: Center(child: _buildActionButtons(context)),
    );
  }
}
