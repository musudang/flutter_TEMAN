import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/university_constants.dart';
import '../services/firestore_service.dart';
import '../providers/feed_state_provider.dart';
import '../models/user_model.dart' as app_models;
import '../widgets/teman_logo.dart';

/// A beautifully styled sidebar drawer listing ALL feed + 9 university feeds.
/// The user's own university is highlighted with a pin icon.
/// Tapping "ALL" closes the drawer and returns to the main feed.
/// Tapping a university navigates to its dedicated feed page.
class UniversityDrawer extends StatelessWidget {
  const UniversityDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    return StreamBuilder<app_models.User?>(
      stream: uid.isEmpty ? const Stream.empty() : firestoreService.getUserStream(uid),
      builder: (context, snapshot) {
        final currentUser = snapshot.data;
        final pinnedUniId = currentUser?.universityId ?? '';

        return Drawer(
          backgroundColor: const Color(0xFFF8F9FA),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // ── Header ──────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const TemanLogoWidget(size: 32),
                          const SizedBox(width: 10),
                          const Text(
                            'TEMAN',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'University Communities',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Connect with students from your university',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── ALL Feed Tile ───────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _AllFeedTile(
                    onTap: () {
                      Provider.of<FeedStateProvider>(context, listen: false).setUniversity(null);
                      Navigator.pop(context); // close drawer, stay on feed
                    },
                  ),
                ),

                const SizedBox(height: 4),

                // ── Pinned University (if set) ──────
                if (pinnedUniId.isNotEmpty) ...[
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    child: Builder(
                      builder: (context) {
                        final uni =
                            UniversityConstants.getById(pinnedUniId);
                        if (uni == null) return const SizedBox.shrink();
                        final color = Color(uni.colorValue);
                        return _UniversityTile(
                          university: uni,
                          color: color,
                          isPinned: true,
                          onTap: () {
                            Provider.of<FeedStateProvider>(context, listen: false).setUniversity(uni);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: Colors.grey[200],
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'Other Universities',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: Colors.grey[200],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── University List ──────────────────
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    itemCount: UniversityConstants.universities
                        .where((u) => u.id != pinnedUniId)
                        .length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final filteredList = UniversityConstants
                          .universities
                          .where((u) => u.id != pinnedUniId)
                          .toList();
                      final uni = filteredList[index];
                      final color = Color(uni.colorValue);
                      return _UniversityTile(
                        university: uni,
                        color: color,
                        isPinned: false,
                        onTap: () {
                          Provider.of<FeedStateProvider>(context, listen: false).setUniversity(uni);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),

                // ── Footer ──────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '🌏 All universities in Seoul, Korea',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── ALL Feed Tile ──────────────────────────────────────
class _AllFeedTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AllFeedTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.teal.shade50,
                Colors.blue.shade50,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.teal.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D9488), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'ALL',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All Communities',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1A1F36),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'General · Meetups · Events · Q&A · Market · Jobs',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── University Tile ──────────────────────────────────────
class _UniversityTile extends StatelessWidget {
  final University university;
  final Color color;
  final bool isPinned;
  final VoidCallback onTap;

  const _UniversityTile({
    required this.university,
    required this.color,
    required this.onTap,
    this.isPinned = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isPinned ? color.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: isPinned
                ? Border.all(color: color.withValues(alpha: 0.25), width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // University icon badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.15),
                      color.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Image.asset(
                    university.badgePath,
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Text(
                      university.shortName,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize:
                            university.shortName.length > 3 ? 10 : 12,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // University info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            university.nameEn,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF1A1F36),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPinned) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.push_pin_rounded,
                            size: 14,
                            color: color,
                          ),
                        ],
                      ],
                    ),

                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
