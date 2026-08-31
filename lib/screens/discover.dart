import 'package:flutter/material.dart';
import 'tabs/community_tab.dart'; // We will create this below

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0F19), // Match your Dark Theme
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Discover',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 14,
            ),
            tabs: [
              Tab(text: "Community"),
              Tab(text: "News"),
              Tab(text: "Blogs"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            // 1. The Actual Community Feed
            CommunityTab(),

            // 2. News (Coming Soon)
            _ComingSoonPlaceholder(
              icon: Icons.newspaper_rounded,
              title: "News",
            ),

            // 3. Blogs (Coming Soon)
            _ComingSoonPlaceholder(icon: Icons.article_rounded, title: "Blogs"),
          ],
        ),
      ),
    );
  }
}

// Reusable "Coming Soon" Widget
class _ComingSoonPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ComingSoonPlaceholder({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        // Nothing to fetch yet — this is just here so the pull gesture is
        // consistent across every tab, and it's a one-line no-op to wire
        // up real data once News/Blogs exist.
        await Future.delayed(const Duration(milliseconds: 400));
      },
      color: Colors.blueAccent,
      backgroundColor: const Color(0xFF111827),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 50, color: Colors.white24),
                const SizedBox(height: 16),
                Text(
                  '$title Coming Soon',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We are working hard to bring this feature to you.',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
