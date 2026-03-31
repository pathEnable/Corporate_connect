import 'package:flutter/material.dart';
import '../services/admin_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _adminService = AdminService();
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final stats = await _adminService.getStats();
      final usersData = await _adminService.getUsers();
      if (mounted) {
        setState(() {
          _stats = stats;
          _users = List<Map<String, dynamic>>.from(usersData['users'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Administration', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF004D40),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // -- Section Stats --
                  const Text('Vue d\'ensemble', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildStatsGrid(),
                  const SizedBox(height: 32),
                  // -- Section Utilisateurs --
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Utilisateurs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('${_users.length} total', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._users.map((user) => _buildUserCard(user)),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsGrid() {
    if (_stats == null) return const SizedBox.shrink();
    final items = [
      _StatItem('Utilisateurs', _stats!['total_users'] ?? 0, Icons.people, const Color(0xFF1565C0)),
      _StatItem('En ligne', _stats!['active_users'] ?? 0, Icons.circle, const Color(0xFF2E7D32)),
      _StatItem('Bannis', _stats!['banned_users'] ?? 0, Icons.block, const Color(0xFFC62828)),
      _StatItem('Messages', _stats!['total_messages'] ?? 0, Icons.message, const Color(0xFF6A1B9A)),
      _StatItem('Salons', _stats!['total_rooms'] ?? 0, Icons.chat_bubble, const Color(0xFFE65100)),
      _StatItem('Groupes', _stats!['total_groups'] ?? 0, Icons.group_work, const Color(0xFF00838F)),
      _StatItem('Statuts', _stats!['total_statuses'] ?? 0, Icons.amp_stories, const Color(0xFF4527A0)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(item.icon, color: item.color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item.label, style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
                ],
              ),
              Text('${item.value}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: item.color)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isActive = user['is_active'] == true;
    final isAdmin = user['is_admin'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isActive ? const Color(0xFF004D40) : Colors.grey,
          backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
          child: user['avatar_url'] == null
              ? Text(
                  (user['full_name'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(child: Text(user['full_name'] ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.w600))),
            if (isAdmin) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF004D40), borderRadius: BorderRadius.circular(12)),
              child: const Text('Admin', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text('@${user['username'] ?? ''}', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isActive ? 'Actif' : 'Banni',
                  style: TextStyle(color: isActive ? Colors.green[700] : Colors.red[700], fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'toggle') {
              await _adminService.toggleUserActive(user['id']);
              _loadData();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle',
              child: Text(isActive ? 'Bannir' : 'Réactiver'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  _StatItem(this.label, this.value, this.icon, this.color);
}
