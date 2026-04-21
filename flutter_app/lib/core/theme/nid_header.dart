// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

/// A reusable unified green header banner.
///
/// On authenticated screens (Apply / Track) it shows a thin user-strip at the
/// top containing the user avatar, name, email, optional tracking pill, and
/// logout button – all inside the same dark-green surface.
///
/// On the auth screen (Login / Signup) it shows only the org crest + title.
class NidHeader extends StatelessWidget {
  const NidHeader({
    super.key,
    required this.title,
    required this.subtitle,
    // Optional – set on authenticated screens
    this.userName,
    this.userEmail,
    this.latestReference,
    this.onTrackTap,
    this.onLogout,
  });

  final String title;
  final String subtitle;
  final String? userName;
  final String? userEmail;
  final String? latestReference;
  final VoidCallback? onTrackTap;
  final VoidCallback? onLogout;

  bool get _isAuthenticated => userName != null;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kBrandGreen,
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                  width: 40,
                ),
              ),
            ),
          ),
          Positioned(
            right: 60,
            bottom: -30,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.04),
                  width: 24,
                ),
              ),
            ),
          ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isAuthenticated) _buildUserStrip(),
              _buildHeroZone(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserStrip() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.13),
              border:
                  Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(userName ?? ''),
              style: const TextStyle(
                color: kPaleText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Name + email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  userEmail ?? '',
                  style: const TextStyle(color: kMintText, fontSize: 11),
                ),
              ],
            ),
          ),
          // Tracking pill (only if reference exists)
          if (latestReference != null && latestReference!.isNotEmpty)
            GestureDetector(
              onTap: onTrackTap,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.13)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF4ED896),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4ED896).withOpacity(0.6),
                            blurRadius: 6,
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      latestReference!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('›',
                        style:
                            TextStyle(color: kMintText, fontSize: 13)),
                  ],
                ),
              ),
            ),
          // Logout button
          if (onLogout != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onLogout,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withOpacity(0.07),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Icon(Icons.logout_rounded,
                      size: 16, color: kMintText),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroZone() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withOpacity(0.11),
                ),
                child: const Icon(Icons.shield_outlined,
                    color: kPaleText, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REPUBLIC OF UGANDA',
                      style: TextStyle(
                        color: kMintText,
                        fontSize: 10,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'National Identification & Registration Authority',
                      style: TextStyle(color: kPaleText, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.dmSerifDisplay(
              color: Colors.white,
              fontSize: 25,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: kMintText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Section label with a hairline divider – used inside all form bodies.
class NidSectionLabel extends StatelessWidget {
  const NidSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              color: kAccentGreen,
              fontSize: 10,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Divider(height: 1, color: Color(0xFFE0EEEA)),
          ),
        ],
      ),
    );
  }
}

/// Reusable info / alert banner inside form bodies.
class NidInfoBanner extends StatelessWidget {
  const NidInfoBanner(this.text, {super.key, this.isError = false});
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isError
            ? const Color(0xFFFEE4E4)
            : const Color(0xFFF0FAF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError
              ? const Color(0xFFE8B4B4)
              : const Color(0xFFC0E8D4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            size: 16,
            color: isError
                ? const Color(0xFFC31C1C)
                : kAccentGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isError
                    ? const Color(0xFFC31C1C)
                    : kAccentGreen,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
