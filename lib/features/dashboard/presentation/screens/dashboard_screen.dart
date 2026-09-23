import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChargeX Vision'),
        actions: [
          IconButton(
            onPressed: () => context.push('/history'),
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overview',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.25,
                children: const [
                  _StatCard(
                    title: 'Active chargers',
                    value: '148',
                    trend: '+12%',
                  ),
                  _StatCard(
                    title: 'Health score',
                    value: '94.2%',
                    trend: '+1.8',
                  ),
                  _StatCard(title: 'Open faults', value: '23', trend: '-7'),
                  _StatCard(
                    title: 'Predicted failures',
                    value: '6',
                    trend: 'Low',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Operations',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ActionChip(
                    label: 'Inspection',
                    icon: Icons.search_rounded,
                    route: '/inspection',
                  ),
                  _ActionChip(
                    label: 'AI Recognition',
                    icon: Icons.camera_alt_rounded,
                    route: '/ai-recognition',
                  ),
                  _ActionChip(
                    label: 'Digital Twin',
                    icon: Icons.auto_awesome_rounded,
                    route: '/digital-twin',
                  ),
                  _ActionChip(
                    label: 'Health',
                    icon: Icons.monitor_heart_rounded,
                    route: '/health',
                  ),
                  _ActionChip(
                    label: 'Maintenance',
                    icon: Icons.build_rounded,
                    route: '/maintenance',
                  ),
                  _ActionChip(
                    label: 'Reports',
                    icon: Icons.analytics_rounded,
                    route: '/reports',
                  ),
                  _ActionChip(
                    label: 'Settings',
                    icon: Icons.settings_rounded,
                    route: '/settings',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.trend,
  });

  final String title;
  final String value;
  final String trend;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(trend),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon),
      label: Text(label),
      onPressed: () => context.push(route),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
