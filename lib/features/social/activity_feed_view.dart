import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';

class ActivityFeedView extends StatefulWidget {
  const ActivityFeedView({super.key});

  @override
  State<ActivityFeedView> createState() => _ActivityFeedViewState();
}

class _ActivityFeedViewState extends State<ActivityFeedView> {
  late final Stream<List<Map<String, dynamic>>> _feedStream;

  @override
  void initState() {
    super.initState();
    _feedStream = Supabase.instance.client
        .from('community_feed_items')
        .stream(primaryKey: ['id'])
        .eq('is_anonymous', false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;

        return Padding(
          padding: EdgeInsets.all(wide ? 40 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassContainer(
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
                          Icons.public_rounded,
                          color: AppColors.neonGreen.withValues(alpha: 0.8),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Live Community Feed',
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
                        'Recent activity from the community',
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
              SizedBox(height: wide ? 32 : 20),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _feedStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _FeedStateCard(
                        title: 'Feed unavailable',
                        message:
                            'Database stream error: ${snapshot.error}. Check table, RLS, and policies.',
                        icon: Icons.error_outline_rounded,
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final items = _mapFeedItems(snapshot.data ?? const []);

                    if (items.isEmpty) {
                      return _FeedStateCard(
                        title: 'No activity yet',
                        message:
                            'Start scanning items and the live community feed will populate automatically.',
                        icon: Icons.dynamic_feed_outlined,
                      );
                    }

                    return wide
                        ? _buildTwoColumnFeed(items)
                        : _buildSingleColumnFeed(items);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_FeedEntry> _mapFeedItems(List<Map<String, dynamic>> rows) {
    final sortedRows = [...rows]
      ..sort(
        (a, b) => _parseDateTime(
          b['created_at'],
        ).compareTo(_parseDateTime(a['created_at'])),
      );

    return sortedRows.take(20).map((row) {
      final confirmed = (row['confirmed'] as bool?) ?? false;
      final points = (row['points_awarded'] as num?)?.toInt() ?? 0;
      final confidenceValue = (row['confidence'] as num?)?.toDouble() ?? 0.0;
      final isAnonymous = (row['is_anonymous'] as bool?) ?? false;
      final displayUsername = _stringValue(
        row['display_username'],
        fallback: 'Anonymous Citizen',
      );
      final username = isAnonymous ? 'Anonymous Citizen' : displayUsername;
      final avatarInitial = _stringValue(
        row['avatar_initial'],
        fallback: username.isNotEmpty ? username[0].toUpperCase() : 'E',
      );

      return _FeedEntry(
        feedItemId: _toInt(row['id']),
        username: username,
        avatarInitial: avatarInitial,
        timeAgo: _formatTimeAgo(_parseDateTime(row['created_at'])),
        category: _stringValue(
          row['category_label'],
          fallback: 'Uncategorized',
        ),
        itemName: _stringValue(row['item_name'], fallback: 'Unknown Item'),
        points: confirmed ? '+$points' : 'Pending',
        confidence: '${(confidenceValue * 100).toStringAsFixed(0)}%',
        isAnonymous: isAnonymous,
        isPriority: confirmed,
      );
    }).toList();
  }

  Widget _buildTwoColumnFeed(List<_FeedEntry> items) {
    final left = <_FeedEntry>[];
    final right = <_FeedEntry>[];

    for (var i = 0; i < items.length; i++) {
      if (i.isEven) {
        left.add(items[i]);
      } else {
        right.add(items[i]);
      }
    }

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < left.length; i++) ...[
                  _FeedItemCard(data: left[i]),
                  if (i < left.length - 1) const SizedBox(height: 24),
                ],
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < right.length; i++) ...[
                  _FeedItemCard(data: right[i]),
                  if (i < right.length - 1) const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleColumnFeed(List<_FeedEntry> items) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 40),
      itemCount: items.length,
      itemBuilder: (context, index) => _FeedItemCard(data: items[index]),
      separatorBuilder: (context, index) => const SizedBox(height: 16),
    );
  }

  DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatTimeAgo(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }

  String _stringValue(dynamic value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _FeedStateCard extends StatelessWidget {
  const _FeedStateCard({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: GlassContainer(
          hoverable: true,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 44,
                color: AppColors.neonGreen.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.55)
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedEntry {
  const _FeedEntry({
    required this.feedItemId,
    required this.username,
    required this.avatarInitial,
    required this.timeAgo,
    required this.category,
    required this.itemName,
    required this.points,
    required this.confidence,
    required this.isAnonymous,
    required this.isPriority,
  });

  final int feedItemId;
  final String username;
  final String avatarInitial;
  final String timeAgo;
  final String category;
  final String itemName;
  final String points;
  final String confidence;
  final bool isAnonymous;
  final bool isPriority;
}

class _FeedItemCard extends StatefulWidget {
  const _FeedItemCard({required this.data});

  final _FeedEntry data;

  @override
  State<_FeedItemCard> createState() => _FeedItemCardState();
}

class _FeedItemCardState extends State<_FeedItemCard> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categoryColor = widget.data.category == 'E-Waste'
        ? const Color(0xFFFFA726)
        : widget.data.category == 'Compost'
        ? const Color(0xFF66BB6A)
        : AppColors.neonGreen;

    return GlassContainer(
      hoverable: true,
      padding: const EdgeInsets.all(24),
      borderColor: widget.data.isPriority ? categoryColor : null,
      borderWidth: widget.data.isPriority ? 1.3 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                ),
                child: Center(
                  child: widget.data.isAnonymous
                      ? Icon(
                          Icons.shield_outlined,
                          size: 20,
                          color: AppColors.neonGreen.withValues(alpha: 0.7),
                        )
                      : Text(
                          widget.data.avatarInitial,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.data.username,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.data.timeAgo,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.4)
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.data.isAnonymous) const _FollowButton(),
              SizedBox(width: widget.data.isAnonymous ? 0 : 12),
              Icon(
                Icons.more_horiz_rounded,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      categoryColor.withValues(alpha: 0.15),
                      categoryColor.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Icon(
                  widget.data.category == 'E-Waste'
                      ? Icons.bolt_rounded
                      : widget.data.category == 'Compost'
                      ? Icons.eco_rounded
                      : Icons.recycling_rounded,
                  size: 32,
                  color: categoryColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        color: categoryColor.withValues(alpha: 0.1),
                      ),
                      child: Text(
                        widget.data.category,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: categoryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Item: ${widget.data.itemName}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Confidence: ${widget.data.confidence}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.neonGreen.withValues(alpha: 0.1),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.data.points,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.neonGreen,
                      ),
                    ),
                    Text(
                      'PTS',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.neonGreen.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _EngagementBar(
                feedItemId: widget.data.feedItemId,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _InteractionBtn(
                icon: Icons.share_outlined,
                label: 'Share',
                color: isDark ? Colors.white : Colors.black,
                isDark: isDark,
              ),
              const Spacer(),
              _InteractionBtn(
                icon: Icons.bookmark_border_rounded,
                label: '',
                color: isDark ? Colors.white : Colors.black,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EngagementBar extends StatefulWidget {
  const _EngagementBar({required this.feedItemId, required this.isDark});

  final int feedItemId;
  final bool isDark;

  @override
  State<_EngagementBar> createState() => _EngagementBarState();
}

class _EngagementBarState extends State<_EngagementBar> {
  bool _loading = true;
  bool _likedByMe = false;
  int _loveCount = 0;
  int _commentCount = 0;

  @override
  void initState() {
    super.initState();
    _loadEngagement();
  }

  Future<void> _loadEngagement() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      final loves = await Supabase.instance.client
          .from('community_feed_loves')
          .select('user_id')
          .eq('feed_item_id', widget.feedItemId);

      final comments = await Supabase.instance.client
          .from('community_feed_comments')
          .select('id')
          .eq('feed_item_id', widget.feedItemId);

      if (!mounted) {
        return;
      }

      setState(() {
        _loveCount = (loves as List).length;
        _commentCount = (comments as List).length;
        _likedByMe = (loves).any((e) => e['user_id'] == user.id);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _toggleLove() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      if (_likedByMe) {
        await Supabase.instance.client
            .from('community_feed_loves')
            .delete()
            .eq('feed_item_id', widget.feedItemId)
            .eq('user_id', user.id);
      } else {
        await Supabase.instance.client.from('community_feed_loves').insert({
          'feed_item_id': widget.feedItemId,
          'user_id': user.id,
        });
      }
      await _loadEngagement();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update reaction: $error')),
      );
    }
  }

  Future<void> _openComments() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsSheet(feedItemId: widget.feedItemId),
    );
    await _loadEngagement();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 50,
        height: 24,
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    return Row(
      children: [
        _InteractionBtn(
          icon: _likedByMe
              ? Icons.favorite_rounded
              : Icons.favorite_outline_rounded,
          label: '$_loveCount',
          color: Colors.redAccent,
          isDark: widget.isDark,
          onTap: _toggleLove,
        ),
        const SizedBox(width: 8),
        _InteractionBtn(
          icon: Icons.chat_bubble_outline_rounded,
          label: '$_commentCount',
          color: Colors.blueAccent,
          isDark: widget.isDark,
          onTap: _openComments,
        ),
      ],
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.feedItemId});

  final int feedItemId;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  List<Map<String, dynamic>> _comments = const [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final rows = await Supabase.instance.client
          .from('community_feed_comments')
          .select(
            'id, commenter_display_name, commenter_avatar_initial, content, created_at',
          )
          .eq('feed_item_id', widget.feedItemId)
          .order('created_at', ascending: true);

      if (!mounted) {
        return;
      }

      setState(() {
        _comments = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _submitComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _submitting) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final profile = await Supabase.instance.client
          .from('user_profiles')
          .select(
            'display_name, full_name, username, avatar_initial, is_private_profile',
          )
          .eq('id', user.id)
          .maybeSingle();

      final isPrivate = (profile?['is_private_profile'] as bool?) ?? false;
      final displayName = isPrivate
          ? 'Anonymous Citizen'
          : ((profile?['display_name'] ??
                    profile?['full_name'] ??
                    profile?['username'] ??
                    'Eco User')
                .toString());
      final avatarInitial = isPrivate
          ? 'A'
          : ((profile?['avatar_initial'] ?? 'E').toString());

      await Supabase.instance.client.from('community_feed_comments').insert({
        'feed_item_id': widget.feedItemId,
        'commenter_id': user.id,
        'commenter_display_name': displayName,
        'commenter_avatar_initial': avatarInitial,
        'content': text,
      });

      _controller.clear();
      await _loadComments();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to post comment: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 60, 16, bottom + 16),
      child: GlassContainer(
        hoverable: true,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Comments',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                  ? Center(
                      child: Text(
                        'No comments yet',
                        style: GoogleFonts.inter(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.6)
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final row = _comments[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                child: Text(
                                  (row['commenter_avatar_initial'] ?? 'E')
                                      .toString()
                                      .substring(0, 1)
                                      .toUpperCase(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (row['commenter_display_name'] ??
                                              'Community User')
                                          .toString(),
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.darkText
                                            : AppColors.lightText,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      (row['content'] ?? '').toString(),
                                      style: GoogleFonts.inter(
                                        color: isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.8,
                                              )
                                            : AppColors.lightText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: 2,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _submitting ? null : _submitComment,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InteractionBtn extends StatelessWidget {
  const _InteractionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
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
