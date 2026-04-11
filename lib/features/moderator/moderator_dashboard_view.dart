import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';

class ModeratorDashboardView extends StatefulWidget {
  const ModeratorDashboardView({super.key});

  @override
  State<ModeratorDashboardView> createState() => _ModeratorDashboardViewState();
}

class _ModeratorDashboardViewState extends State<ModeratorDashboardView> {
  List<PendingDispute> _disputes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDisputes();
  }

  Future<void> _loadDisputes() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await Supabase.instance.client
          .from('pending_disputes')
          .select('''
            id,
            user_id,
            item_name,
            category_label,
            confidence,
            image_data,
            created_at
          ''')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final disputeRows = (response as List).cast<Map<String, dynamic>>();
      final userIds = disputeRows
          .map((row) => row['user_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      final profilesById = <String, Map<String, dynamic>>{};
      if (userIds.isNotEmpty) {
        final profileResponse = await Supabase.instance.client
            .from('user_profiles')
            .select('id, display_name, username')
            .inFilter('id', userIds);

        for (final profileRow
            in (profileResponse as List).cast<Map<String, dynamic>>()) {
          final id = profileRow['id'] as String?;
          if (id != null) {
            profilesById[id] = profileRow;
          }
        }
      }

      final disputes = disputeRows.map((row) {
        final profile =
            profilesById[row['user_id'] as String] ?? <String, dynamic>{};
        return PendingDispute(
          id: row['id'] as String,
          userId: row['user_id'] as String,
          userDisplayName: profile['display_name'] as String? ?? 'Unknown User',
          userUsername: profile['username'] as String? ?? 'unknown',
          itemName: row['item_name'] as String,
          categoryLabel: row['category_label'] as String,
          confidence: (row['confidence'] as num).toDouble(),
          imageData: row['image_data'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _disputes = disputes;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load disputes: $error';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _approveDispute(String disputeId) async {
    try {
      await Supabase.instance.client.rpc(
        'approve_dispute',
        params: {'p_dispute_id': disputeId},
      );

      // Remove from local list
      setState(() {
        _disputes.removeWhere((d) => d.id == disputeId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispute approved successfully')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve dispute: $error')),
        );
      }
    }
  }

  Future<void> _rejectDispute(String disputeId) async {
    try {
      await Supabase.instance.client.rpc(
        'reject_dispute',
        params: {'p_dispute_id': disputeId},
      );

      // Remove from local list
      setState(() {
        _disputes.removeWhere((d) => d.id == disputeId);
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Dispute rejected')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject dispute: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: GlassContainer(
                  sigma: 24,
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.amber.withValues(alpha: 0.1),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.gavel_rounded,
                          color: Colors.amber,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dispute Queue',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Review low-confidence AI classifications',
                              style: GoogleFonts.inter(
                                fontSize: 12,
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
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          color: Colors.amber.withValues(alpha: 0.15),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${_disputes.length} Pending',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Loading/Error states
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Center(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else if (_disputes.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Center(
                    child: Text(
                      'No pending disputes to review',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                )
              else
                // Queue Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 700 ? 2 : 1;
                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ).copyWith(bottom: 40),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        childAspectRatio: constraints.maxWidth > 700
                            ? 1.4
                            : 1.2,
                      ),
                      itemCount: _disputes.length,
                      itemBuilder: (context, index) {
                        return _DisputeCard(
                          dispute: _disputes[index],
                          onApprove: () => _approveDispute(_disputes[index].id),
                          onReject: () => _rejectDispute(_disputes[index].id),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PendingDispute {
  const PendingDispute({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.userUsername,
    required this.itemName,
    required this.categoryLabel,
    required this.confidence,
    required this.imageData,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String userDisplayName;
  final String userUsername;
  final String itemName;
  final String categoryLabel;
  final double confidence;
  final String? imageData;
  final DateTime createdAt;
}

class _DisputeCard extends StatefulWidget {
  const _DisputeCard({
    required this.dispute,
    required this.onApprove,
    required this.onReject,
  });

  final PendingDispute dispute;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  State<_DisputeCard> createState() => _DisputeCardState();
}

class _DisputeCardState extends State<_DisputeCard> {
  bool _hovered = false;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      hoverable: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top info row
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 16,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : AppColors.lightTextSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pending from: ${widget.dispute.userDisplayName} (@${widget.dispute.userUsername})',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : AppColors.lightTextSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              MouseRegion(
                onEnter: (_) => setState(() => _hovered = true),
                onExit: (_) => setState(() => _hovered = false),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Colors.amber.withValues(alpha: _hovered ? 1.0 : 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Image and Guess row
          Expanded(
            child: Row(
              children: [
                // Image
                Expanded(
                  flex: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.amber.withValues(alpha: 0.15),
                          Colors.amber.withValues(alpha: 0.05),
                        ],
                      ),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: widget.dispute.imageData != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              base64Decode(
                                widget.dispute.imageData!.split(',').last,
                              ),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.broken_image_rounded,
                                    size: 48,
                                    color: Colors.amber,
                                  ),
                            ),
                          )
                        : const Icon(
                            Icons.broken_image_rounded,
                            size: 48,
                            color: Colors.amber,
                          ),
                  ),
                ),
                const SizedBox(width: 20),
                // Prediction info
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Prediction:',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.dispute.itemName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          'Score: ${(widget.dispute.confidence * 100).toInt()}%',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Category: ${widget.dispute.categoryLabel}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.6)
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Actions
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isProcessing ? null : widget.onReject,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          setState(() => _isProcessing = true);
                          try {
                            widget.onApprove();
                          } finally {
                            if (mounted) {
                              setState(() => _isProcessing = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
