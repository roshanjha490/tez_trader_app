import 'package:flutter/material.dart';
import 'package:tez_trader_app/widgets/edit_profile_screen.dart';
import 'package:tez_trader_app/widgets/self_post_feed.dart';
import '../services/token_storage.dart';
import 'auth/login_screen.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _accentColor = Color(0xFF6C63FF);
  static const _cardColor = Color(0xFF1E1E2A);

  Future<void> _handleLogout(BuildContext context) async {
    await TokenStorage.clearTokens();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _getInitials(dynamic user) {
    if (user == null) return '?';
    final f = user.firstName?.isNotEmpty == true
        ? user.firstName[0].toUpperCase()
        : '';
    final l = user.lastName?.isNotEmpty == true
        ? user.lastName[0].toUpperCase()
        : '';
    final initials = '$f$l';
    return initials.isNotEmpty ? initials : '?';
  }

  String _getFullName(dynamic user) {
    if (user == null) return 'Profile';
    final f = user.firstName ?? '';
    final l = user.lastName ?? '';
    final fullName = '$f $l'.trim();
    return fullName.isNotEmpty ? fullName : 'Profile';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: TokenStorage.getCurrentUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _accentColor),
          );
        }

        final user = snapshot.data;

        return DefaultTabController(
          length: 3,
          child: Column(
            children: [
              _buildHeader(user, context),
              const TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 14,
                ),
                dividerColor: Colors.white10,
                tabs: [
                  Tab(text: 'Details'),
                  Tab(text: 'My Feed'),
                  Tab(text: 'Security'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildPersonalInfoTab(user),
                    _buildMyFeedTab(user),
                    _buildSecurityTab(user),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- HEADER SECTION ---
  Widget _buildHeader(dynamic user, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: _accentColor,
            child: Text(
              _getInitials(user),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _getFullName(user),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? 'No email provided',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => _handleLogout(context),
              icon: const Icon(Icons.logout_rounded),
              color: Colors.redAccent,
              tooltip: 'Logout',
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: PERSONAL INFO ---
  Widget _buildPersonalInfoTab(dynamic user) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildInfoCard(
          icon: Icons.person_outline,
          title: 'Full Name',
          value: _getFullName(user),
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          icon: Icons.email_outlined,
          title: 'Email Address',
          value: user?.email ?? 'Not set',
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          icon: Icons.phone_android,
          title: 'Mobile Number',
          value: user?.mobile ?? '+91 ******0000',
          isLocked: true, // Cannot edit mobile
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () async {
            // Navigate to the edit screen and wait for a result
            final bool? wasUpdated = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
            );

            // If the modal returned 'true' (OTP verified), force the profile to re-fetch!
            if (wasUpdated == true) {
              setState(
                () {},
              ); // Assuming ProfileScreen is a StatefulWidget, this triggers FutureBuilder to run again
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.edit, color: Colors.white),
          label: const Text(
            'Edit Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // --- TAB 2: MY FEED ---
  Widget _buildMyFeedTab(dynamic user) {
    return SelfPostFeed(
      currentUserId: user?.id,
    );
  }

  // --- TAB 3: SECURITY ---
  Widget _buildSecurityTab(dynamic user) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildInfoCard(
          icon: Icons.shield_outlined,
          title: 'Two-Factor Authentication',
          value: 'Enabled via Authenticator App',
          valueColor: Colors.greenAccent,
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          icon: Icons.fingerprint,
          title: 'Biometric Unlock',
          value: 'Tap to configure FaceID/TouchID',
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          icon: Icons.history,
          title: 'Last Login',
          value: 'Today at 10:45 AM (Delhi, IN)', // Will come from API
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          icon: Icons.devices,
          title: 'Connected Devices',
          value: 'iPhone 15 Pro (Active)\nMacBook Pro (Web)',
        ),
      ],
    );
  }

  // --- REUSABLE CARD WIDGET ---
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    bool isLocked = false,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (isLocked)
            const Icon(Icons.lock_outline, color: Colors.white24, size: 18),
        ],
      ),
    );
  }
}
