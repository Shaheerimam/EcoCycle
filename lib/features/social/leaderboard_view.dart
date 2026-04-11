import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';

class LeaderboardView extends StatefulWidget {
  const LeaderboardView({super.key});

  @override
  State<LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends State<LeaderboardView> {
  bool _loading = true;
  String? _error;
  List<_LeaderboardEntry> _entries = const [];
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await _fetchLeaderboardRows();
      final sorted = [...rows]
        ..sort((a, b) {
          final weekly = b.weeklyPoints.compareTo(a.weeklyPoints);
          if (weekly != 0) {
            return weekly;
          }
          final total = b.totalPoints.compareTo(a.totalPoints);
          if (total != 0) {
            return total;
          }
          return b.weeklyScans.compareTo(a.weeklyScans);
        });

      final ranked = <_LeaderboardEntry>[];
      for (var i = 0; i < sorted.length; i++) {
        ranked.add(sorted[i].copyWith(rank: i + 1));
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _entries = ranked;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Failed to load leaderboard: $error';
      });
    }
  }

  Future<List<_LeaderboardEntry>> _fetchLeaderboardRows() async {
    final client = Supabase.instance.client;

    try {
      final rpc = await client.rpc('get_weekly_leaderboard');
      final list = (rpc as List?) ?? const [];
      return list
          .map((row) => _entryFromRpc(Map<String, dynamic>.from(row as Map)))
          .where((entry) => entry != null)
          .cast<_LeaderboardEntry>()
          .toList();
    } catch (_) {
      final fallback = await client
          .from('user_profiles')
          .select(
            'id, display_name, full_name, username, avatar_initial, total_points, classification_count, is_private_profile',
          )
          .eq('is_private_profile', false)
          .order('total_points', ascending: false)
          .order('classification_count', ascending: false)
          .limit(50);

      return (fallback as List)
          .map((row) => _entryFromProfile(Map<String, dynamic>.from(row)))
          .where((entry) => entry != null)
          .cast<_LeaderboardEntry>()
          .toList();
    }
  }

  _LeaderboardEntry? _entryFromRpc(Map<String, dynamic> row) {
    final id = _string(row['user_id'] ?? row['id'], fallback: '');
    if (id.isEmpty) {
      return null;
    }

    final isPrivate = (row['is_private_profile'] as bool?) ?? false;
    if (isPrivate) {
      return null;
    }

    final displayName = _displayNameFromRow(row);
    final avatarInitial = _avatarInitialFromRow(row, displayName);

    return _LeaderboardEntry(
      rank: 0,
      userId: id,
      username: displayName,
      avatarInitial: avatarInitial,
      weeklyPoints: _toInt(row['weekly_points']),
      totalPoints: _toInt(row['total_points']),
      weeklyScans: _toInt(row['weekly_scans']),
      isMe: id == _currentUserId,
    );
  }

  _LeaderboardEntry? _entryFromProfile(Map<String, dynamic> row) {
    final id = _string(row['id'], fallback: '');
    if (id.isEmpty) {
      return null;
    }

    final displayName = _displayNameFromRow(row);
    final avatarInitial = _avatarInitialFromRow(row, displayName);
    final totalPoints = _toInt(row['total_points']);
    final scans = _toInt(row['classification_count']);

    return _LeaderboardEntry(
      rank: 0,
      userId: id,
      username: displayName,
      avatarInitial: avatarInitial,
      weeklyPoints: totalPoints,
      totalPoints: totalPoints,
      weeklyScans: scans,
      isMe: id == _currentUserId,
    );
  }

  String _displayNameFromRow(Map<String, dynamic> row) {
    return _string(
      row['display_name'],
      fallback: _string(
        row['full_name'],
        fallback: _string(row['username'], fallback: 'Eco User'),
      ),
    );
  }

  String _avatarInitialFromRow(Map<String, dynamic> row, String displayName) {
    final initial = _string(row['avatar_initial'], fallback: '');
    if (initial.isNotEmpty) {
      return initial.substring(0, 1).toUpperCase();
    }
    if (displayName.isEmpty) {
      return 'E';
    }
    return displayName.substring(0, 1).toUpperCase();
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _string(dynamic value, {required String fallback}) {
    final s = value?.toString().trim() ?? '';
    return s.isEmpty ? fallback : s;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: GlassContainer(
                sigma: 24,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          color: AppColors.neonGreen.withValues(alpha: 0.8),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Community Leaderboard',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : AppColors.lightText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Text(
                        'Top scanners this week',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: GlassContainer(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.75)
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadLeaderboard,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _entries.isEmpty
                  ? Center(
                      child: GlassContainer(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No public users to show right now.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.75)
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadLeaderboard,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(
                          bottom: 40,
                          left: 16,
                          right: 16,
                        ),
                        itemCount: _entries.length,
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _LeaderboardRow(data: entry),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatefulWidget {
  const _LeaderboardRow({required this.data});

  final _LeaderboardEntry data;

  @override
  State<_LeaderboardRow> createState() => _LeaderboardRowState();
}

class _LeaderboardRowState extends State<_LeaderboardRow> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Medals colors
    Color? medalColor;
    if (widget.data.rank == 1) medalColor = const Color(0xFFFFD700);
    if (widget.data.rank == 2) medalColor = const Color(0xFFC0C0C0);
    if (widget.data.rank == 3) medalColor = const Color(0xFFCD7F32);

    final isTop3 = medalColor != null;

    // Custom shadows for Top 3 (Prestige Glowing)
    final List<BoxShadow>? prestigeShadows = isTop3
        ? [
            BoxShadow(
              color: medalColor.withValues(alpha: 0.15),
              blurRadius: 20,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ]
        : null;

    return GlassContainer(
      hoverable: true,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      borderColor: isTop3 ? medalColor : null,
      borderWidth: isTop3 ? 1.5 : 1.0,
      customShadows: prestigeShadows,
      child: Row(
        children: [
          // Rank + Trend
          SizedBox(
            width: 54,
            child: Row(
              children: [
                Text(
                  '#${widget.data.rank}',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: isTop3 ? FontWeight.w800 : FontWeight.w600,
                    color: isTop3
                        ? medalColor
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : AppColors.lightTextSecondary),
                  ),
                ),
                const SizedBox(width: 4),
                // Mock trend icon
                Icon(
                  widget.data.rank % 3 == 0
                      ? Icons.remove_rounded
                      : Icons.arrow_upward_rounded,
                  size: 12,
                  color: widget.data.rank % 3 == 0
                      ? (isDark
                            ? Colors.white.withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.3))
                      : AppColors.neonGreen.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),

          // Avatar
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(left: 12, right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            child: Center(
              child: Text(
                widget.data.avatarInitial,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ),
          ),

          // Username
          Expanded(
            child: Text(
              widget.data.isMe
                  ? '${widget.data.username} (You)'
                  : widget.data.username,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: widget.data.isMe
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: widget.data.isMe
                    ? AppColors.neonGreen
                    : (isDark ? AppColors.darkText : AppColors.lightText),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Points
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              color: isTop3
                  ? medalColor.withValues(alpha: 0.1)
                  : AppColors.neonGreen.withValues(alpha: 0.08),
            ),
            child: Text(
              '${widget.data.weeklyPoints} pts',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isTop3 ? medalColor : AppColors.neonGreen,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Follow Action
          if (!widget.data.isMe)
            const _FollowButton()
          else
            const SizedBox(width: 80),
        ],
      ),
    );
  }
}

class _LeaderboardEntry {
  const _LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    required this.avatarInitial,
    required this.weeklyPoints,
    required this.totalPoints,
    required this.weeklyScans,
    required this.isMe,
  });

  final int rank;
  final String userId;
  final String username;
  final String avatarInitial;
  final int weeklyPoints;
  final int totalPoints;
  final int weeklyScans;
  final bool isMe;

  _LeaderboardEntry copyWith({int? rank}) {
    return _LeaderboardEntry(
      rank: rank ?? this.rank,
      userId: userId,
      username: username,
      avatarInitial: avatarInitial,
      weeklyPoints: weeklyPoints,
      totalPoints: totalPoints,
      weeklyScans: weeklyScans,
      isMe: isMe,
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {},
      child: Text(
        'Follow',
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.neonGreen,
        ),
      ),
    );
  }
}
