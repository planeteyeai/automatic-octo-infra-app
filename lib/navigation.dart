import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/gps_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/distressfinder.dart';
import 'screens/distresslog.dart';
import 'login/login.dart'; // <-- Add this import for redirecting on logout

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  void _navigateToScreen(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  Future<void> _logout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all saved user data

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.deepPurple),
            child: Text(
              'NHIT',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () => _navigateToScreen(context, const DashboardScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.warning),
            title: const Text('Distress'),
            onTap:
                () => _navigateToScreen(context, const DistressFinderScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Distress Log'),
            onTap: () => _navigateToScreen(context, const DistressLogScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Location Map GPS'),
            onTap: () => _navigateToScreen(context, const GPSScreen()),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
