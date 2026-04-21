import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:trailify/trailify.dart';

import '../router.dart';

@RoutePage()
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TrailifyMagicalTap(
          child: Text(
            'Trailify Example',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_rounded),
            tooltip: 'Open Trailify Console',
            onPressed: () => Trailify.instance.openConsole(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _NavCard(
            icon: Icons.science_rounded,
            title: 'Playground',
            subtitle: 'Test all Trailify event types',
            color: Colors.deepPurple,
            onTap: () => context.pushRoute(const PlaygroundRoute()),
          ),
          const SizedBox(height: 12),
          _NavCard(
            icon: Icons.settings_rounded,
            title: 'Settings',
            subtitle: 'Mock settings page (navigation tracking)',
            color: Colors.teal,
            onTap: () => context.pushRoute(const SettingsRoute()),
          ),
          const SizedBox(height: 12),
          _NavCard(
            icon: Icons.shopping_bag_rounded,
            title: 'Product Detail',
            subtitle: 'Route with path parameters',
            color: Colors.orange,
            onTap: () => context.pushRoute(ProductDetailRoute(id: '42')),
          ),
          const SizedBox(height: 24),
          _NavCard(
            icon: Icons.terminal_rounded,
            title: 'Trailify Console',
            subtitle: 'View all captured events',
            color: Colors.blueGrey,
            onTap: () => Trailify.instance.openConsole(context),
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
