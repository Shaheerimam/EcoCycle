import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_container.dart';
import '../moderator/moderator_dashboard_view.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  int _selectedTab = 0; // 0 = Disputes, 1 = Users, 2 = Tickets

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
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Colors.redAccent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin Control Center',
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
                              'Manage disputes, users, and support tickets',
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
                    ],
                  ),
                ),
              ),

              // Tab Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _TabButton(
                      label: 'Disputes',
                      isActive: _selectedTab == 0,
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                    const SizedBox(width: 16),
                    _TabButton(
                      label: 'Users',
                      isActive: _selectedTab == 1,
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                    const SizedBox(width: 16),
                    _TabButton(
                      label: 'Tickets',
                      isActive: _selectedTab == 2,
                      onTap: () => setState(() => _selectedTab = 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Tab Content
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _selectedTab == 0
                    ? const _DisputesTab()
                    : _selectedTab == 1
                    ? const _UsersTab()
                    : const _TicketsTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? (isDark ? Colors.white : AppColors.lightText)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : AppColors.lightTextSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DisputesTab extends StatelessWidget {
  const _DisputesTab();
  @override
  Widget build(BuildContext context) {
    return const ModeratorDashboardView();
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  bool _isLoading = true;
  String? _error;
  List<AdminUser> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client.rpc(
        'get_admin_user_profiles',
      );

      final rows = (response as List).cast<Map<String, dynamic>>();
      final users = rows.map((row) {
        return AdminUser(
          id: row['id'] as String,
          displayName: row['display_name'] as String? ?? 'Unnamed',
          username: row['username'] as String? ?? 'unknown',
          role: row['role'] as String? ?? 'citizen',
          totalPoints: (row['total_points'] as num?)?.toInt() ?? 0,
          classificationCount:
              (row['classification_count'] as num?)?.toInt() ?? 0,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load users: $error';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleModeratorRole(AdminUser user) async {
    final newRole = user.role == 'moderator' ? 'citizen' : 'moderator';

    try {
      await Supabase.instance.client
          .from('user_profiles')
          .update({'role': newRole})
          .eq('id', user.id);

      if (!mounted) return;

      setState(() {
        _users = _users.map((entry) {
          if (entry.id != user.id) return entry;
          return entry.copyWith(role: newRole);
        }).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Role updated to $newRole for ${user.username}'),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update role: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Text(
            _error!,
            style: TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Text(
            '${_users.length} users',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ),
        ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ).copyWith(bottom: 40),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _users.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final user = _users[index];
            final isModerator = user.role == 'moderator';

            return GlassContainer(
              hoverable: true,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.neonGreen.withValues(alpha: 0.12),
                        ),
                        child: Center(
                          child: Text(
                            user.displayName.isNotEmpty
                                ? user.displayName[0].toUpperCase()
                                : user.username[0].toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.neonGreen,
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
                              user.displayName,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '@${user.username}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          color: isModerator
                              ? Colors.blue.withValues(alpha: 0.12)
                              : Colors.grey.withValues(alpha: 0.12),
                        ),
                        child: Text(
                          user.role.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isModerator ? Colors.blue : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${user.totalPoints} points • ${user.classificationCount} scans',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _toggleModeratorRole(user),
                        child: Text(
                          isModerator ? 'Demote' : 'Promote',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: isModerator
                                ? Colors.redAccent
                                : AppColors.neonGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.displayName,
    required this.username,
    required this.role,
    required this.totalPoints,
    required this.classificationCount,
  });

  final String id;
  final String displayName;
  final String username;
  final String role;
  final int totalPoints;
  final int classificationCount;

  AdminUser copyWith({String? role}) {
    return AdminUser(
      id: id,
      displayName: displayName,
      username: username,
      role: role ?? this.role,
      totalPoints: totalPoints,
      classificationCount: classificationCount,
    );
  }
}

class _TicketsTab extends StatefulWidget {
  const _TicketsTab();

  @override
  State<_TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<_TicketsTab> {
  bool _isLoading = true;
  String? _error;
  List<SupportTicket> _tickets = [];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('support_tickets')
          .select(
            'id, user_id, subject, description, status, priority, created_at',
          )
          .order('created_at', ascending: false);

      final rows = (response as List).cast<Map<String, dynamic>>();
      final userIds = rows
          .map((row) => row['user_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      final profilesById = <String, String>{};
      if (userIds.isNotEmpty) {
        final profileResponse = await Supabase.instance.client
            .from('user_profiles')
            .select('id, display_name, username')
            .inFilter('id', userIds);

        for (final profileRow
            in (profileResponse as List).cast<Map<String, dynamic>>()) {
          final id = profileRow['id'] as String?;
          if (id != null) {
            profilesById[id] =
                profileRow['display_name'] as String? ??
                profileRow['username'] as String? ??
                'Unknown';
          }
        }
      }

      final tickets = rows.map((row) {
        return SupportTicket(
          id: row['id'] as String,
          userId: row['user_id'] as String,
          userName: profilesById[row['user_id'] as String] ?? 'Unknown User',
          subject: row['subject'] as String? ?? 'No subject',
          description: row['description'] as String? ?? '',
          status: row['status'] as String? ?? 'open',
          priority: row['priority'] as String? ?? 'medium',
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _tickets = tickets;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load tickets: $error';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resolveTicket(SupportTicket ticket) async {
    try {
      await Supabase.instance.client
          .from('support_tickets')
          .update({
            'status': 'resolved',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', ticket.id);

      if (!mounted) return;

      setState(() {
        _tickets = _tickets.map((entry) {
          if (entry.id != ticket.id) return entry;
          return entry.copyWith(status: 'resolved');
        }).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket marked as resolved')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resolve ticket: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Text(
            _error!,
            style: TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_tickets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Text(
            'No open tickets found.',
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.6)
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 16,
      ).copyWith(bottom: 40),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _tickets.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        final resolved = ticket.status == 'resolved';
        return GlassContainer(
          hoverable: true,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.support_agent_rounded,
                    size: 20,
                    color: ticket.priority == 'high'
                        ? Colors.redAccent
                        : ticket.priority == 'medium'
                        ? Colors.orangeAccent
                        : AppColors.neonGreen,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ticket.subject,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      color: resolved
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.orangeAccent.withValues(alpha: 0.12),
                    ),
                    child: Text(
                      ticket.status.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: resolved ? Colors.green : Colors.orangeAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'From ${ticket.userName}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                ticket.description,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: resolved ? null : () => _resolveTicket(ticket),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: resolved
                        ? Colors.grey.withValues(alpha: 0.2)
                        : AppColors.neonGreen.withValues(alpha: 0.2),
                    foregroundColor: resolved
                        ? Colors.white70
                        : AppColors.neonGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  icon: Icon(
                    resolved ? Icons.check_circle_outline_rounded : Icons.check,
                    size: 18,
                  ),
                  label: Text(resolved ? 'Resolved' : 'Resolve'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.userId,
    required this.userName,
    required this.subject,
    required this.description,
    required this.status,
    required this.priority,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String subject;
  final String description;
  final String status;
  final String priority;
  final DateTime createdAt;

  SupportTicket copyWith({String? status}) {
    return SupportTicket(
      id: id,
      userId: userId,
      userName: userName,
      subject: subject,
      description: description,
      status: status ?? this.status,
      priority: priority,
      createdAt: createdAt,
    );
  }
}
