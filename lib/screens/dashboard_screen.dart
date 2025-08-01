import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../navigation.dart';
import 'distressfinder.dart';
import 'gps_screen.dart';
import 'distresslog.dart';
import '../services/apis.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService apiService = ApiService();

  List<dynamic> _projects = [];
  List<dynamic> _chainages = [];

  Map<String, dynamic>? _selectedProject;
  Map<String, dynamic>? _selectedChainage;

  int totalDetected = 0;
  int totalReported = 0;

  String _userName = '';

  @override
  void initState() {
    super.initState();
    loadUserName();
    fetchProjects();
  }

  Future<void> loadUserName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final firstName = prefs.getString('first_name') ?? '';
    final lastName = prefs.getString('last_name') ?? '';
    setState(() {
      _userName = '$firstName $lastName'.trim();
    });
  }

  Future<void> fetchProjects() async {
    final projects = await apiService.getProjects();
    if (projects != null) {
      setState(() {
        _projects = projects;
      });
    }
  }

  Future<void> fetchChainages(int projectId) async {
    final chainageFeatures = await apiService.getChainages();
    if (chainageFeatures != null) {
      final filtered =
          chainageFeatures.where((feature) {
            final props = feature['properties'] as Map<String, dynamic>?;
            return props != null && props['project'] == projectId;
          }).toList();

      setState(() {
        _chainages = filtered;
        _selectedChainage = null;
      });
    }
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      drawer: const MainDrawer(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _userName.isNotEmpty
                    ? 'Welcome, $_userName'
                    : 'Welcome to the Dashboard',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1, color: Colors.grey),
            const SizedBox(height: 16),

            // Project Dropdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonFormField<Map<String, dynamic>>(
                hint: const Text('Select Project'),
                value: _selectedProject,
                isExpanded: true,
                items:
                    _projects.map<DropdownMenuItem<Map<String, dynamic>>>((
                      project,
                    ) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: project,
                        child: Text('${project['name']} (${project['code']})'),
                      );
                    }).toList(),
                onChanged: (project) {
                  setState(() {
                    _selectedProject = project;
                    if (project?['id'] != null) {
                      fetchChainages(project!['id']);
                    } else {
                      _chainages = [];
                      _selectedChainage = null;
                    }
                  });
                },
              ),
            ),

            // Chainage Dropdown
            if (_chainages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: DropdownButtonFormField<Map<String, dynamic>>(
                  hint: const Text('Select Chainage'),
                  value: _selectedChainage,
                  isExpanded: true,
                  items:
                      _chainages.map<DropdownMenuItem<Map<String, dynamic>>>((
                        feature,
                      ) {
                        final props =
                            feature['properties'] as Map<String, dynamic>;
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: feature,
                          child: Text(
                            '${props['name']} (${props['segment_id']})',
                          ),
                        );
                      }).toList(),
                  onChanged: (feature) {
                    setState(() {
                      _selectedChainage = feature;
                      totalDetected = 0;
                      totalReported = 0;
                    });
                  },
                ),
              )
            else if (_selectedProject != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  'No chainages found for this project',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),

            const SizedBox(height: 16),

            // Summary Cards
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSummaryCard(
                    icon: Icons.remove_red_eye,
                    label: 'Detected',
                    count: totalDetected,
                    color: Colors.orange,
                  ),
                  _buildSummaryCard(
                    icon: Icons.report,
                    label: 'Reported',
                    count: totalReported,
                    color: Colors.green,
                  ),
                ],
              ),
            ),

            // Navigation Grid
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildNavCard(
                    icon: Icons.warning,
                    label: 'Distress Detector',
                    onTap:
                        () =>
                            _navigateTo(context, const DistressFinderScreen()),
                  ),
                  _buildNavCard(
                    icon: Icons.map,
                    label: 'Location Map',
                    onTap: () => _navigateTo(context, const GPSScreen()),
                  ),
                  _buildNavCard(
                    icon: Icons.list,
                    label: 'Distress Logs',
                    onTap:
                        () => _navigateTo(context, const DistressLogScreen()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Card(
      color: color.withOpacity(0.1),
      child: SizedBox(
        width: 140,
        height: 100,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(icon, size: 48), Text(label)],
        ),
      ),
    );
  }
}
