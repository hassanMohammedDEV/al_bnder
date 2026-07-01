import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/player_ad_repository_impl.dart';
import '../../../facilities/providers/selected_group_provider.dart';

class BannedUsersScreen extends ConsumerStatefulWidget {
  const BannedUsersScreen({super.key});

  @override
  ConsumerState<BannedUsersScreen> createState() => _BannedUsersScreenState();
}

class _BannedUsersScreenState extends ConsumerState<BannedUsersScreen> {
  List<Map<String, dynamic>> _banned = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _loading = true;
  String? _error;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String? get _groupId => ref.read(selectedGroupProvider);

  Future<void> _load() async {
    final groupId = _groupId;
    if (groupId == null) {
      if (_loading) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final result = await ref.read(playerAdRepositoryProvider).getBannedUsers(groupId, '');
    if (!mounted) return;
    result.when(
      success: (data) => setState(() { _banned = data; _loading = false; _error = null; }),
      failure: (e) => setState(() { _loading = false; _error = e.message; }),
    );
  }

  Future<void> _search(String q) async {
    final groupId = _groupId;
    if (groupId == null || q.length < 2) return;
    final result = await ref.read(playerAdRepositoryProvider).searchUsersToBan(groupId, q);
    if (!mounted) return;
    result.when(
      success: (data) => setState(() => _searchResults = data),
      failure: (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      },
    );
  }

  Future<void> _ban(String userId, String reason) async {
    final groupId = _groupId;
    if (groupId == null) return;
    final result = await ref.read(playerAdRepositoryProvider).banUser(userId, groupId, reason);
    if (!mounted) return;
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحظر')),
        );
        _load();
                _searchResults = [];
                _showSearch = false;
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      },
    );
  }

  Future<void> _unban(String userId) async {
    final groupId = _groupId;
    if (groupId == null) return;
    final result = await ref.read(playerAdRepositoryProvider).unbanUser(userId, groupId);
    if (!mounted) return;
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء الحظر')),
        );
        _load();
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      },
    );
  }

  void _showBanDialog(String userId, {String? name, String? phone}) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حظر ${name ?? 'مستخدم'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (phone != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(phone, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'سبب الحظر (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _ban(userId, reasonCtrl.text.trim());
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حظر'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(selectedGroupProvider, (_, __) => _load());
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_showSearch ? 'بحث عن مستخدم' : 'المحظورين'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () => setState(() { _showSearch = !_showSearch; _searchResults = []; }),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'ابحث برقم الجوال أو الاسم...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) => _search(v),
              ),
            ),
          if (_showSearch && _searchResults.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('نتائج البحث', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _searchResults.length,
                itemBuilder: (_, i) {
                  final u = _searchResults[i];
                  final isBanned = u['is_banned'] == true;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isBanned ? Colors.red.withValues(alpha: 0.15) : scheme.primaryContainer,
                        child: Icon(isBanned ? Icons.block : Icons.person, color: isBanned ? Colors.red : scheme.primary),
                      ),
                      title: Text(u['full_name'] as String? ?? 'مستخدم'),
                      subtitle: Text('${u['phone']}${isBanned ? ' — محظور' : ''}', style: TextStyle(color: isBanned ? Colors.red : scheme.onSurfaceVariant)),
                      trailing: isBanned
                          ? TextButton(
                              onPressed: () => _unban(u['user_id'] as String),
                              child: const Text('إلغاء الحظر'),
                            )
                          : TextButton(
                              onPressed: () => _showBanDialog(u['user_id'] as String, name: u['full_name'] as String?, phone: u['phone'] as String?),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('حظر'),
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (!_showSearch) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('المحظورون حالياً (${_banned.length})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: TextStyle(color: scheme.error)),
                      const SizedBox(height: 8),
                      FilledButton.tonal(onPressed: _load, child: const Text('إعادة المحاولة')),
                    ],
                  ),
                ),
              )
            else if (_banned.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.block, size: 48, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 8),
                      Text('لا يوجد محظورون', style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _banned.length,
                    itemBuilder: (_, i) {
                      final b = _banned[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red.withValues(alpha: 0.15),
                            child: const Icon(Icons.block, color: Colors.red),
                          ),
                          title: Text(b['full_name'] as String? ?? 'مستخدم'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b['phone'] as String? ?? '', style: TextStyle(color: scheme.onSurfaceVariant)),
                              if ((b['reason'] as String?)?.isNotEmpty == true)
                                Text('السبب: ${b['reason']}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                            ],
                          ),
                          trailing: TextButton(
                            onPressed: () => _unban(b['user_id'] as String),
                            child: const Text('إلغاء الحظر'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
