import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tez_trader_app/widgets/edit_profile_screen.dart';
import 'package:tez_trader_app/widgets/self_post_feed.dart';
import '../services/api_client.dart';
import '../services/token_storage.dart';
import 'mentor_profile_screen.dart' show PagedApiList, ReplyCard;
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

  /// Mentors can change their profile photo (the backend rejects everyone
  /// else with 403). Saves the refreshed access token so the new image shows
  /// up everywhere.
  Future<void> _changePhoto(BuildContext context) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    if (await picked.length() > 5 * 1024 * 1024) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image must be 5MB or smaller.')),
        );
      }
      return;
    }
    try {
      final res = await ApiClient.dio.post(
        '/user/upload-image',
        data: FormData.fromMap({
          'type': 'profile',
          'image': await MultipartFile.fromFile(picked.path, filename: picked.name),
        }),
      );
      final token = res.data['token'] as String?;
      if (token != null) await TokenStorage.saveTokens(accessToken: token);
      if (mounted) setState(() {});
    } on DioException catch (e) {
      final data = e.response?.data;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data is Map && data['message'] != null
                ? data['message'].toString()
                : 'Failed to upload image.'),
          ),
        );
      }
    }
  }

  /// +91 ******1234
  String _maskedMobile(String? mobile) {
    if (mobile == null || mobile.length < 4) return '+91 ******0000';
    final digits = mobile.replaceAll(RegExp(r'\D'), '');
    final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
    return '+91 ******$last4';
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
          length: 2,
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
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildPersonalInfoTab(user),
                    _buildMyFeedTab(user),
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
          GestureDetector(
            onTap: user?.isMentor == true ? () => _changePhoto(context) : null,
            child: CircleAvatar(
              radius: 28,
              backgroundColor: _accentColor,
              backgroundImage: user?.profileImage != null ? NetworkImage(user.profileImage) : null,
              child: user?.profileImage == null
                  ? Text(
                      _getInitials(user),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
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
                    if (user?.isMentor == true)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.verified, size: 16, color: Colors.greenAccent),
                      ),
                    if (user != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          (user.planName as String).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: _accentColor,
      backgroundColor: _cardColor,
      child: ListView(
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
            value: _maskedMobile(user?.mobile),
            isLocked: true, // Cannot edit mobile
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.workspace_premium_outlined,
            title: 'Plan',
            value: (user?.planName ?? 'pro').toString().toUpperCase(),
          ),
          if (user?.createdAt != null) ...[
            const SizedBox(height: 16),
            _buildInfoCard(
              icon: Icons.calendar_month_outlined,
              title: 'Member Since',
              value:
                  '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              // Navigate to the edit screen and wait for a result
              final bool? wasUpdated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(user: user),
                ),
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
      ),
    );
  }

  // --- TAB 2: MY FEED ---
  Widget _buildMyFeedTab(dynamic user) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: _accentColor,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            dividerColor: Colors.transparent,
            tabs: [Tab(text: 'Posts'), Tab(text: 'Replies')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                SelfPostFeed(currentUserId: user?.id),
                PagedApiList(
                  path: '/community/me/replies',
                  emptyText: "You haven't replied to any posts yet.",
                  itemBuilder: (item) => ReplyCard(reply: item),
                ),
              ],
            ),
          ),
        ],
      ),
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
        color: Colors.white.withOpacity(0.05),
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
