import 'package:flutter/material.dart';
import 'tabs/community_tab.dart';
import 'tabs/mentors_tab.dart';
import 'tabs/news_tab.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent, // Match your Dark Theme
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
              Tab(text: "Mentors"),
              Tab(text: "News"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            // 1. The Actual Community Feed
            CommunityTab(),

            // 1b. Mentors
            MentorsTab(),

            // 2. News (Coming Soon)
            NewsTab(),

          ],
        ),
      ),
    );
  }
}
