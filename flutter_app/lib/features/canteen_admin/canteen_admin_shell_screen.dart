import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/widgets/animated_reveal.dart';
import '../../core/widgets/app_async_view.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_status_badge.dart';
import '../../data/models/canteen_admin_session.dart';
import '../../data/services/app_preferences.dart';
import '../../data/services/canteen_admin_service.dart';
import '../home/home_screen.dart';

class CanteenAdminShellScreen extends StatefulWidget {
  const CanteenAdminShellScreen({
    super.key,
    required this.initialSession,
    required this.onLogout,
    this.onSessionUpdated,
  });

  final CanteenAdminSession initialSession;
  final VoidCallback onLogout;
  final ValueChanged<CanteenAdminSession>? onSessionUpdated;

  @override
  State<CanteenAdminShellScreen> createState() => _CanteenAdminShellScreenState();
}

class _CanteenAdminShellScreenState extends State<CanteenAdminShellScreen> {
  late CanteenAdminSession _session;
  int _selectedIndex = 0;

  static const _navItems = <_AdminNavItem>[
    _AdminNavItem('Dashboard', Icons.dashboard_rounded, AppColors.tabHome),
    _AdminNavItem('Orders', Icons.receipt_long_rounded, AppColors.tabCart),
    _AdminNavItem('Menu Items', Icons.restaurant_menu_rounded, AppColors.tabWallet),
    _AdminNavItem('Reports', Icons.bar_chart_rounded, AppColors.primary),
    _AdminNavItem('Reviews', Icons.reviews_rounded, AppColors.warning),
    _AdminNavItem('Wallet', Icons.account_balance_wallet_rounded, AppColors.success),
    _AdminNavItem('Settings', Icons.settings_rounded, AppColors.textSecondary),
    _AdminNavItem('Customer', Icons.storefront_rounded, AppColors.primaryBright),
  ];

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
  }

  Future<void> _logout() async {
    await context.read<AppPreferences>().clearCanteenAdminSession();
    if (!mounted) {
      return;
    }
    widget.onLogout();
  }

  Future<void> _persistSession(CanteenAdminSession session) async {
    _session = session;
    await context.read<AppPreferences>().saveCanteenAdminSession(session);
    widget.onSessionUpdated?.call(session);
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Widget _buildCurrentPage() {
    return switch (_selectedIndex) {
      0 => _DashboardTab(session: _session),
      1 => _OrdersTab(session: _session),
      2 => _MenuItemsTab(session: _session),
      3 => _ReportsTab(session: _session),
      4 => _ReviewsTab(session: _session),
      5 => _WalletTab(session: _session),
      6 => _SettingsTab(
          session: _session,
          onSessionChanged: _persistSession,
        ),
      _ => const HomeScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final responsive = _AdminResponsive.of(context);
    final page = _buildCurrentPage();
    final item = _navItems[_selectedIndex];
    final headerHeight = responsive.headerContentHeight + MediaQuery.paddingOf(context).top;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(headerHeight),
        child: _AdminHeader(
          item: item,
          session: _session,
          onLogout: _logout,
          responsive: responsive,
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.darkBackgroundGradient
              : AppColors.backgroundGradient,
        ),
        child: Stack(
          children: <Widget>[
            const _CreativeAdminCanvas(),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  responsive.pageHorizontalInset,
                  responsive.topContentInset,
                  responsive.pageHorizontalInset,
                  2,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final slideAnimation = Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: slideAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_selectedIndex),
                    child: AnimatedReveal(
                      delayMs: 40,
                      child: page,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _AdminBottomNavBar(
        items: _navItems,
        selectedIndex: _selectedIndex,
        onSelected: (index) {
          if (_selectedIndex == index) {
            return;
          }
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

class _DashboardTab extends StatefulWidget {
  const _DashboardTab({required this.session});

  final CanteenAdminSession session;

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = context.read<CanteenAdminService>();
      final data = await service.getDashboard(widget.session);
      if (!mounted) {
        return;
      }
      setState(() {
        _data = data;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stats = _asMap(_data['stats']);
    final orders = _asList(_data['recentOrders']);

    return RefreshIndicator(
      onRefresh: _load,
      child: AppAsyncView(
        isLoading: _loading,
        error: _error,
        onRetry: _load,
        child: ListView(
          padding: _tabPadding(context),
          children: <Widget>[
            LayoutBuilder(
              builder: (context, constraints) {
                final w = (constraints.maxWidth - 12) / 2;
                final cards = <Widget>[
                  _StatCard(label: 'Pending', value: '${_asInt(stats['pendingOrders'])}'),
                  _StatCard(label: 'Active', value: '${_asInt(stats['activeOrders'])}'),
                  _StatCard(label: 'Completed Today', value: '${_asInt(stats['completedOrdersToday'])}'),
                  _StatCard(label: 'Revenue Today', value: _currency(stats['revenueToday'])),
                  _StatCard(label: 'Total Revenue', value: _currency(stats['totalRevenue'])),
                  _StatCard(label: 'Menu Items', value: '${_asInt(stats['totalMenuItems'])}'),
                ];
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: cards.map((c) => SizedBox(width: w, child: c)).toList(),
                );
              },
            ),
            const SizedBox(height: 22),
            const _AdminSectionHeader(
              title: 'Recent Orders',
              subtitle: 'Latest activity from your canteen',
            ),
            const SizedBox(height: 10),
            if (orders.isEmpty)
              const AppEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No Recent Orders',
                subtitle: 'New orders will appear here once students place them.',
                compact: true,
              )
            else
              ...orders.take(10).toList(growable: false).asMap().entries.map((entry) {
                final index = entry.key;
                final order = _asMap(entry.value);
                final status = order['status']?.toString() ?? 'pending';
                final statusColor = _statusColor(status);
                return _StaggeredReveal(
                  index: index,
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(left: BorderSide(color: statusColor, width: 4)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          title: Text(
                            order['orderNumber']?.toString().isNotEmpty == true
                                ? '#${order['orderNumber']}'
                                : 'Order #${order['id']}',
                            style: AppTypography.label.copyWith(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${order['customerName'] ?? 'Customer'}  •  ${order['itemsSummary'] ?? ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                              ),
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                _currency(order['total']),
                                style: AppTypography.priceSm.copyWith(
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              AppStatusBadge.fromString(status, small: true),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _OrdersTab extends StatefulWidget {
  const _OrdersTab({required this.session});

  final CanteenAdminSession session;

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  bool _loading = true;
  String? _error;
  String _status = 'all';
  List<Map<String, dynamic>> _orders = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = context.read<CanteenAdminService>();
      final orders = await service.getOrders(widget.session, status: _status, limit: 300);
      if (!mounted) {
        return;
      }
      setState(() {
        _orders = orders;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showUpdateSheet(Map<String, dynamic> order) async {
    var nextStatus = (order['status'] ?? 'pending').toString();
    final service = context.read<CanteenAdminService>();
    final estimatedController = TextEditingController(
      text: '${_asInt(order['estimatedTime'] ?? 15)}',
    );

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Update Order Status', style: AppTypography.heading3),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: nextStatus,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const <String>['pending', 'confirmed', 'preparing', 'ready', 'completed', 'cancelled']
                    .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) {
                  nextStatus = value ?? nextStatus;
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: estimatedController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Estimated Time (minutes)'),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Update'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await service.updateOrderStatus(
            widget.session,
            orderId: _asInt(order['id']),
            status: nextStatus,
            estimatedTime: _asInt(estimatedController.text),
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order updated successfully.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '').trim())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppAsyncView(
      isLoading: _loading,
      error: _error,
      onRetry: _load,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: _tabPadding(context),
          children: <Widget>[
            const _AdminSectionHeader(
              title: 'Orders',
              subtitle: 'Manage incoming and in-progress orders',
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: InputDecoration(
                      labelText: 'Filter by status',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const <String>[
                      'all',
                      'pending',
                      'confirmed',
                      'preparing',
                      'ready',
                      'completed',
                      'cancelled',
                    ]
                        .map((s) => DropdownMenuItem<String>(
                              value: s,
                              child: Text(s),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _status = value ?? 'all';
                      });
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 46,
                  height: 46,
                  child: Material(
                    color: isDark ? AppColors.darkCardRaised : AppColors.bgSoft,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _load,
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 22,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_orders.isEmpty)
              const AppEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No Orders Found',
                subtitle:
                    'Try a different filter or refresh to fetch new orders.',
                compact: true,
              )
            else
              ..._orders.asMap().entries.map((entry) {
                final index = entry.key;
                final order = entry.value;
                final items = _asList(order['items']).map(_asMap).toList(
                      growable: false,
                    );
                final orderStatus = (order['status'] ?? 'pending').toString();
                final orderStatusColor = _statusColor(orderStatus);

                return _StaggeredReveal(
                  index: index,
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 1.5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: orderStatusColor, width: 4),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      '#${order['orderNumber'] ?? order['id']}',
                                      style: AppTypography.label.copyWith(
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.textPrimary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _currency(order['total']),
                                    style: AppTypography.priceSm.copyWith(
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${order['customerName'] ?? 'Customer'} • ${order['customerPhone'] ?? ''}',
                                style: AppTypography.bodySm.copyWith(
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              AppStatusBadge.fromString(orderStatus, small: true),
                              if (items.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 8),
                                ...items.take(3).map(
                                      (item) => Text(
                                        '- ${item['itemName'] ?? 'Item'} x${_asInt(item['quantity'])}',
                                        style: AppTypography.bodySm.copyWith(
                                          color: isDark
                                              ? AppColors.darkTextMuted
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _showUpdateSheet(order),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Update Status'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _MenuItemsTab extends StatefulWidget {
  const _MenuItemsTab({required this.session});

  final CanteenAdminSession session;

  @override
  State<_MenuItemsTab> createState() => _MenuItemsTabState();
}

class _MenuItemsTabState extends State<_MenuItemsTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _categories = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = context.read<CanteenAdminService>();
      final categories = await service.getMenuCategories(widget.session);
      final items = await service.getMenuItems(widget.session);
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = categories;
        _items = items;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openItemForm({Map<String, dynamic>? item}) async {
    final service = context.read<CanteenAdminService>();
    final nameController = TextEditingController(text: item?['name']?.toString() ?? '');
    final descriptionController = TextEditingController(text: item?['description']?.toString() ?? '');
    final priceController = TextEditingController(text: item?['price']?.toString() ?? '0');
    final imageUrlController = TextEditingController(text: item?['imageUrl']?.toString() ?? '');
    final picker = ImagePicker();

    var selectedCategory = item?['category']?.toString() ??
        (_categories.isNotEmpty ? _categories.first['name']?.toString() ?? '' : '');
    var isAvailable = item?['isAvailable'] == true;
    var isVegetarian = item?['isVegetarian'] == true;
    var isUploadingImage = false;
    String? imageUploadNote;

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setLocalState) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(item == null ? 'Add Menu Item' : 'Edit Menu Item',
                        style: AppTypography.heading3),
                    const SizedBox(height: 10),
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Price'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory.isNotEmpty ? selectedCategory : null,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categories
                          .map((row) => row['name']?.toString() ?? '')
                          .where((name) => name.isNotEmpty)
                          .map((name) => DropdownMenuItem<String>(value: name, child: Text(name)))
                          .toList(),
                      onChanged: (value) {
                        setLocalState(() {
                          selectedCategory = value ?? selectedCategory;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isUploadingImage
                                ? null
                                : () async {
                                    try {
                                      final picked = await picker.pickImage(
                                        source: ImageSource.gallery,
                                        maxWidth: 1600,
                                        imageQuality: 85,
                                      );
                                      if (picked == null) {
                                        return;
                                      }

                                      setLocalState(() {
                                        isUploadingImage = true;
                                        imageUploadNote = 'Uploading image...';
                                      });

                                      final bytes = await picked.readAsBytes();
                                      final uploadedUrl = await service.uploadMenuItemImage(
                                        widget.session,
                                        fileName: picked.name.trim().isEmpty ? 'menu_item.jpg' : picked.name,
                                        bytes: bytes,
                                      );

                                      imageUrlController.text = uploadedUrl;
                                      setLocalState(() {
                                        isUploadingImage = false;
                                        imageUploadNote = 'Image uploaded successfully.';
                                      });
                                    } catch (e) {
                                      setLocalState(() {
                                        isUploadingImage = false;
                                        imageUploadNote = e.toString().replaceFirst('Exception: ', '').trim();
                                      });
                                    }
                                  },
                            icon: isUploadingImage
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.upload_file_rounded),
                            label: Text(isUploadingImage ? 'Uploading...' : 'Upload Image'),
                          ),
                        ),
                      ],
                    ),
                    if (imageUploadNote != null && imageUploadNote!.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        imageUploadNote!,
                        style: AppTypography.caption,
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: imageUrlController,
                      decoration: const InputDecoration(labelText: 'Image Url (optional - auto-filled after upload)'),
                    ),
                    if (imageUrlController.text.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            imageUrlController.text.trim(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return Container(
                                color: AppColors.bgSoft,
                                alignment: Alignment.center,
                                child: const Text('Image preview unavailable'),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isAvailable,
                      onChanged: (value) {
                        setLocalState(() {
                          isAvailable = value;
                        });
                      },
                      title: const Text('Available'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isVegetarian,
                      onChanged: (value) {
                        setLocalState(() {
                          isVegetarian = value;
                        });
                      },
                      title: const Text('Vegetarian'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (submitted != true) {
      return;
    }

    try {
      final payload = (
        name: nameController.text.trim(),
        description: descriptionController.text.trim(),
        price: double.tryParse(priceController.text.trim()) ?? 0,
        category: selectedCategory,
        isAvailable: isAvailable,
        isVegetarian: isVegetarian,
        imageUrl: imageUrlController.text.trim(),
      );

      if (payload.name.isEmpty) {
        throw Exception('Item name is required.');
      }

      if (item == null) {
        await service.addMenuItem(
          widget.session,
          name: payload.name,
          description: payload.description,
          price: payload.price,
          category: payload.category,
          isAvailable: payload.isAvailable,
          isVegetarian: payload.isVegetarian,
          imageUrl: payload.imageUrl.isEmpty ? null : payload.imageUrl,
        );
      } else {
        await service.updateMenuItem(
          widget.session,
          itemId: _asInt(item['id']),
          name: payload.name,
          description: payload.description,
          price: payload.price,
          category: payload.category,
          isAvailable: payload.isAvailable,
          isVegetarian: payload.isVegetarian,
          imageUrl: payload.imageUrl.isEmpty ? null : payload.imageUrl,
        );
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(item == null ? 'Item added.' : 'Item updated.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '').trim())),
      );
    }
  }

  Future<void> _toggleAvailability(Map<String, dynamic> item, bool value) async {
    try {
      await context.read<CanteenAdminService>().toggleMenuAvailability(
            widget.session,
            itemId: _asInt(item['id']),
            isAvailable: value,
          );
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '').trim())),
      );
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final service = context.read<CanteenAdminService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Item'),
          content: Text('Delete ${item['name'] ?? 'this item'}?'),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await service.deleteMenuItem(
            widget.session,
            itemId: _asInt(item['id']),
          );
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '').trim())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppAsyncView(
      isLoading: _loading,
      error: _error,
      onRetry: _load,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: _tabPadding(context),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Menu Items (${_items.length})',
                    style: AppTypography.heading3.copyWith(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openItemForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_items.isEmpty)
              const AppEmptyState(
                icon: Icons.restaurant_menu_outlined,
                title: 'No Menu Items',
                subtitle: 'Tap Add to create your first menu item.',
                compact: true,
              )
            else
              ..._items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _StaggeredReveal(
                  index: index,
                  child: Card(
                    child: ListTile(
                      title: Text(
                        item['name']?.toString() ?? 'Item',
                        style: AppTypography.label.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${item['category'] ?? 'Uncategorized'} • ${_currency(item['price'])}',
                            style: AppTypography.caption.copyWith(
                              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                            ),
                          ),
                          if ((item['description'] ?? '').toString().trim().isNotEmpty)
                            Text(
                              item['description']?.toString() ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySm.copyWith(
                                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                              ),
                            ),
                          const SizedBox(height: 6),
                          AppStatusBadge(
                            item['isAvailable'] == true ? AppStatus.active : AppStatus.inactive,
                            small: true,
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Switch(
                            value: item['isAvailable'] == true,
                            onChanged: (value) => _toggleAvailability(item, value),
                          ),
                          IconButton(
                            onPressed: () => _openItemForm(item: item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () => _deleteItem(item),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ReportsTab extends StatefulWidget {
  const _ReportsTab({required this.session});

  final CanteenAdminSession session;

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  bool _loading = true;
  String? _error;
  String _period = 'weekly';
  String _status = 'all';
  DateTime _from = DateTime.now().subtract(const Duration(days: 6));
  DateTime _to = DateTime.now();
  Map<String, dynamic> _data = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  ({String fromDate, String toDate}) _resolveRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_period == 'daily') {
      final date = _to;
      return (fromDate: _isoDate(date), toDate: _isoDate(date));
    }
    if (_period == 'weekly') {
      return (
        fromDate: _isoDate(today.subtract(const Duration(days: 6))),
        toDate: _isoDate(today),
      );
    }
    if (_period == 'monthly') {
      return (
        fromDate: _isoDate(DateTime(today.year, today.month, 1)),
        toDate: _isoDate(today),
      );
    }

    return (fromDate: _isoDate(_from), toDate: _isoDate(_to));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final range = _resolveRange();
      final data = await context.read<CanteenAdminService>().getReports(
            widget.session,
            fromDate: range.fromDate,
            toDate: range.toDate,
            status: _status,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _data = data;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final current = start ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      if (start) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = _asMap(_data['summary']);
    final topItems = _asList(_data['topItems']).map(_asMap).toList(growable: false);
    final daily = _asList(_data['dailyTrend']).map(_asMap).toList(growable: false);

    return AppAsyncView(
      isLoading: _loading,
      error: _error,
      onRetry: _load,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: _tabPadding(context),
          children: <Widget>[
            const _AdminSectionHeader(
              title: 'Reports',
              subtitle: 'Analyze sales, trends, and top-performing items',
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _period,
                    decoration: const InputDecoration(labelText: 'Period'),
                    items: const <String>['daily', 'weekly', 'monthly', 'custom']
                        .map((value) => DropdownMenuItem<String>(value: value, child: Text(value)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _period = value ?? _period;
                      });
                      if (_period != 'custom') {
                        _load();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const <String>['all', 'pending', 'confirmed', 'preparing', 'ready', 'completed', 'cancelled']
                        .map((value) => DropdownMenuItem<String>(value: value, child: Text(value)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _status = value ?? _status;
                      });
                      _load();
                    },
                  ),
                ),
              ],
            ),
            if (_period == 'custom') ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(start: true),
                      icon: const Icon(Icons.date_range_outlined),
                      label: Text('From ${_isoDate(_from)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(start: false),
                      icon: const Icon(Icons.date_range_outlined),
                      label: Text('To ${_isoDate(_to)}'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.filter_alt_outlined),
                label: const Text('Apply Filters'),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final w = (constraints.maxWidth - 12) / 2;
                final cards = <Widget>[
                  _StatCard(label: 'Orders', value: '${_asInt(summary['totalOrders'])}'),
                  _StatCard(label: 'Revenue', value: _currency(summary['totalRevenue'])),
                  _StatCard(label: 'Avg Order', value: _currency(summary['avgOrderValue'])),
                  _StatCard(label: 'Items Sold', value: '${_asInt(summary['totalItemsSold'])}'),
                ];
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: cards.map((c) => SizedBox(width: w, child: c)).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            const _AdminSectionHeader(
              title: 'Top Items',
              subtitle: 'Best sellers in the selected period',
            ),
            const SizedBox(height: 10),
            if (topItems.isEmpty)
              const AppEmptyState(
                icon: Icons.insights_outlined,
                title: 'No Item Sales',
                subtitle: 'No sold items found for the selected filters.',
                compact: true,
              )
            else
              ...topItems.take(10).toList(growable: false).asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _StaggeredReveal(
                  index: index,
                  child: Card(
                    child: ListTile(
                      title: Text(
                        item['itemName']?.toString() ?? 'Item',
                        style: AppTypography.label.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        'Qty: ${_asInt(item['quantitySold'])} • ${item['category'] ?? 'Uncategorized'}',
                        style: AppTypography.caption.copyWith(
                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                        ),
                      ),
                      trailing: Text(
                        _currency(item['revenue']),
                        style: AppTypography.priceSm.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 20),
            const _AdminSectionHeader(
              title: 'Daily Breakdown',
              subtitle: 'Day-by-day order and revenue summary',
            ),
            const SizedBox(height: 10),
            if (daily.isEmpty)
              const AppEmptyState(
                icon: Icons.calendar_month_outlined,
                title: 'No Daily Records',
                subtitle: 'No daily activity found for this time range.',
                compact: true,
              )
            else
              ...daily.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                return _StaggeredReveal(
                  index: index,
                  child: Card(
                    child: ListTile(
                      title: Text(
                        row['date']?.toString() ?? '',
                        style: AppTypography.label.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        'Orders: ${_asInt(row['totalOrders'])}',
                        style: AppTypography.caption.copyWith(
                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                        ),
                      ),
                      trailing: Text(
                        _currency(row['revenue']),
                        style: AppTypography.priceSm.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ReviewsTab extends StatefulWidget {
  const _ReviewsTab({required this.session});

  final CanteenAdminSession session;

  @override
  State<_ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<_ReviewsTab> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = const <String, dynamic>{};
  List<Map<String, dynamic>> _reviews = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await context.read<CanteenAdminService>().getReviews(widget.session);
      if (!mounted) {
        return;
      }
      setState(() {
        _stats = _asMap(data['stats']);
        _reviews = _asList(data['reviews']).map(_asMap).toList(growable: false);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _reply(Map<String, dynamic> review) async {
    final service = context.read<CanteenAdminService>();
    final controller = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Respond to Review'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Write your response'),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Send')),
          ],
        );
      },
    );

    if (accepted != true) {
      return;
    }

    final text = controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    try {
      await service.respondToReview(
            widget.session,
            reviewId: _asInt(review['id']),
            responseText: text,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Response saved.')));
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '').trim())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppAsyncView(
      isLoading: _loading,
      error: _error,
      onRetry: _load,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: _tabPadding(context),
          children: <Widget>[
            const _AdminSectionHeader(
              title: 'Reviews',
              subtitle: 'See feedback and respond to students',
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final w = (constraints.maxWidth - 12) / 2;
                final cards = <Widget>[
                  _StatCard(label: 'Total Reviews', value: '${_asInt(_stats['totalReviews'])}'),
                  _StatCard(label: 'Average Rating', value: _asDouble(_stats['avgRating']).toStringAsFixed(1)),
                  _StatCard(label: '5 Star', value: '${_asInt(_stats['fiveStarCount'])}'),
                  _StatCard(label: 'Pending Response', value: '${_asInt(_stats['pendingResponse'])}'),
                ];
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: cards.map((c) => SizedBox(width: w, child: c)).toList(),
                );
              },
            ),
            const SizedBox(height: 18),
            if (_reviews.isEmpty)
              const AppEmptyState(
                icon: Icons.reviews_outlined,
                title: 'No Reviews Yet',
                subtitle: 'Customer ratings and comments will appear here.',
                compact: true,
              )
            else
              ..._reviews.asMap().entries.map((entry) {
                final index = entry.key;
                final review = entry.value;
                final rating = _asInt(review['rating']).clamp(1, 5);
                final response = (review['adminResponse'] ?? '').toString();
                return _StaggeredReveal(
                  index: index,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  review['userName']?.toString().isNotEmpty == true
                                      ? review['userName'].toString()
                                      : 'Anonymous',
                                  style: AppTypography.label.copyWith(
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Text(
                                '★' * rating,
                                style: AppTypography.label.copyWith(
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            review['reviewText']?.toString() ?? '',
                            style: AppTypography.bodySm.copyWith(
                              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                            ),
                          ),
                          if (response.trim().isNotEmpty) ...<Widget>[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isDark ? AppColors.primaryOnDark : AppColors.primary)
                                    .withValues(alpha: isDark ? 0.16 : 0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Response: $response',
                                style: AppTypography.bodySm.copyWith(
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ] else ...<Widget>[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: () => _reply(review),
                                icon: const Icon(Icons.reply_outlined),
                                label: const Text('Reply'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _WalletTab extends StatefulWidget {
  const _WalletTab({required this.session});

  final CanteenAdminSession session;

  @override
  State<_WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<_WalletTab> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await context.read<CanteenAdminService>().getWallet(widget.session);
      if (!mounted) {
        return;
      }
      setState(() {
        _data = data;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final revenue = _asMap(_data['revenue']);
    final breakdown = _asList(_data['paymentBreakdown']).map(_asMap).toList(growable: false);
    final transactions = _asList(_data['recentTransactions']).map(_asMap).toList(growable: false);

    return AppAsyncView(
      isLoading: _loading,
      error: _error,
      onRetry: _load,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: _tabPadding(context),
          children: <Widget>[
            const _AdminSectionHeader(
              title: 'Wallet',
              subtitle: 'Track your revenue and payment activity',
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final w = (constraints.maxWidth - 12) / 2;
                final cards = <Widget>[
                  _StatCard(label: 'Today', value: _currency(revenue['today'])),
                  _StatCard(label: 'Week', value: _currency(revenue['week'])),
                  _StatCard(label: 'Month', value: _currency(revenue['month'])),
                  _StatCard(label: 'All Time', value: _currency(revenue['allTime'])),
                ];
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: cards.map((c) => SizedBox(width: w, child: c)).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            const _AdminSectionHeader(
              title: 'Payment Breakdown',
              subtitle: 'Revenue by payment method',
            ),
            const SizedBox(height: 10),
            if (breakdown.isEmpty)
              const AppEmptyState(
                icon: Icons.payments_outlined,
                title: 'No Payment Data',
                subtitle: 'Payment insights will appear once orders are completed.',
                compact: true,
              )
            else
              ...breakdown.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                return _StaggeredReveal(
                  index: index,
                  child: Card(
                    child: ListTile(
                      title: Text(
                        row['method']?.toString() ?? 'method',
                        style: AppTypography.label.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        'Orders: ${_asInt(row['orderCount'])}',
                        style: AppTypography.caption.copyWith(
                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                        ),
                      ),
                      trailing: Text(
                        _currency(row['revenue']),
                        style: AppTypography.priceSm.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 20),
            const _AdminSectionHeader(
              title: 'Recent Transactions',
              subtitle: 'Most recent wallet-related order payments',
            ),
            const SizedBox(height: 10),
            if (transactions.isEmpty)
              const AppEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No Transactions Yet',
                subtitle: 'Transactions will be listed after successful payments.',
                compact: true,
              )
            else
              ...transactions.take(20).toList(growable: false).asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                return _StaggeredReveal(
                  index: index,
                  child: Card(
                    child: ListTile(
                      title: Text(
                        '#${row['orderNumber'] ?? row['id']}',
                        style: AppTypography.label.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '${row['customerName'] ?? 'Customer'} • ${row['paymentMethod'] ?? 'cash'}',
                        style: AppTypography.caption.copyWith(
                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                        ),
                      ),
                      trailing: Text(
                        _currency(row['total']),
                        style: AppTypography.priceSm.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _SettingsTab extends StatefulWidget {
  const _SettingsTab({
    required this.session,
    required this.onSessionChanged,
  });

  final CanteenAdminSession session;
  final ValueChanged<CanteenAdminSession> onSessionChanged;

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  bool _loading = true;
  String? _error;

  final _canteenNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _openingController = TextEditingController();
  final _closingController = TextEditingController();

  final _adminNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminImageController = TextEditingController();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _canteenNameController.dispose();
    _phoneController.dispose();
    _openingController.dispose();
    _closingController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminImageController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await context.read<CanteenAdminService>().getSettings(widget.session);
      final canteen = _asMap(data['canteen']);
      final admin = _asMap(data['admin']);

      if (!mounted) {
        return;
      }

      setState(() {
        _canteenNameController.text = (canteen['name'] ?? '').toString();
        _phoneController.text = (canteen['phone'] ?? '').toString();
        _openingController.text = (canteen['openingTime'] ?? '08:00').toString();
        _closingController.text = (canteen['closingTime'] ?? '20:00').toString();

        _adminNameController.text = (admin['name'] ?? '').toString();
        _adminEmailController.text = (admin['email'] ?? '').toString();
        _adminImageController.text = (admin['imageUrl'] ?? '').toString();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveCanteen() async {
    final name = _canteenNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Canteen name is required.')));
      return;
    }

    try {
      await context.read<CanteenAdminService>().updateCanteenInfo(
            widget.session,
            name: name,
            phone: _phoneController.text.trim(),
            openingTime: _openingController.text.trim().isEmpty ? '08:00' : _openingController.text.trim(),
            closingTime: _closingController.text.trim().isEmpty ? '20:00' : _closingController.text.trim(),
          );

      final nextSession = widget.session.copyWith(canteenName: name);
      widget.onSessionChanged(nextSession);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Canteen info updated.')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '').trim())),
      );
    }
  }

  Future<void> _saveProfile() async {
    final name = _adminNameController.text.trim();
    final email = _adminEmailController.text.trim();
    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and email are required.')));
      return;
    }

    try {
      await context.read<CanteenAdminService>().updateProfile(
            widget.session,
            name: name,
            email: email,
            imageUrl: _adminImageController.text.trim().isEmpty ? null : _adminImageController.text.trim(),
          );

      final nextSession = widget.session.copyWith(
        name: name,
        email: email,
        imageUrl: _adminImageController.text.trim(),
      );
      widget.onSessionChanged(nextSession);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '').trim())),
      );
    }
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Future<void> _changePassword() async {
    final current = _currentPasswordController.text;
    final next = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All password fields are required.')));
      return;
    }

    if (next != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New passwords do not match.')));
      return;
    }

    if (next.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New password must be at least 6 characters.')));
      return;
    }

    try {
      await context.read<CanteenAdminService>().changePassword(
            widget.session,
            currentPassword: current,
            newPassword: next,
            confirmPassword: confirm,
          );

      if (!mounted) {
        return;
      }
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed.')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '').trim())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppAsyncView(
      isLoading: _loading,
      error: _error,
      onRetry: _load,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: _tabPadding(context),
          children: <Widget>[
            const _AdminSectionHeader(
              title: 'Settings',
              subtitle: 'Manage canteen profile, account, and security',
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              icon: Icons.store_outlined,
              iconColor: AppColors.primary,
              title: 'Canteen Info',
              child: Column(
                children: <Widget>[
                  TextField(controller: _canteenNameController, decoration: _fieldDecoration('Canteen Name')),
                  const SizedBox(height: 12),
                  TextField(controller: _phoneController, decoration: _fieldDecoration('Phone Number')),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(child: TextField(controller: _openingController, decoration: _fieldDecoration('Opening (HH:mm)'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: _closingController, decoration: _fieldDecoration('Closing (HH:mm)'))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saveCanteen, child: const Text('Save Canteen Info'))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              icon: Icons.person_outline,
              iconColor: AppColors.tabProfile,
              title: 'Admin Profile',
              child: Column(
                children: <Widget>[
                  TextField(controller: _adminNameController, decoration: _fieldDecoration('Full Name')),
                  const SizedBox(height: 12),
                  TextField(controller: _adminEmailController, decoration: _fieldDecoration('Email')),
                  const SizedBox(height: 12),
                  TextField(controller: _adminImageController, decoration: _fieldDecoration('Profile Image URL (optional)')),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saveProfile, child: const Text('Save Profile'))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              icon: Icons.lock_outline,
              iconColor: AppColors.danger,
              title: 'Change Password',
              child: Column(
                children: <Widget>[
                  TextField(controller: _currentPasswordController, obscureText: true, decoration: _fieldDecoration('Current Password')),
                  const SizedBox(height: 12),
                  TextField(controller: _newPasswordController, obscureText: true, decoration: _fieldDecoration('New Password')),
                  const SizedBox(height: 12),
                  TextField(controller: _confirmPasswordController, obscureText: true, decoration: _fieldDecoration('Confirm New Password')),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _changePassword, child: const Text('Change Password'))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaggeredReveal extends StatelessWidget {
  const _StaggeredReveal({
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = (index * 45).clamp(0, 360);
    final duration = Duration(milliseconds: 250 + delay);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _CreativeAdminCanvas extends StatelessWidget {
  const _CreativeAdminCanvas();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: Stack(
        children: <Widget>[
          // Blob 1 — top-right
          Positioned(
            top: -60,
            right: -40,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.blobDark1 : AppColors.blobLight1,
                ),
              ),
            ),
          ),
          // Blob 2 — bottom-left
          Positioned(
            bottom: 60,
            left: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.blobDark2 : AppColors.blobLight2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminNavItem {
  const _AdminNavItem(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({
    required this.item,
    required this.session,
    required this.onLogout,
    required this.responsive,
  });

  final _AdminNavItem item;
  final CanteenAdminSession session;
  final VoidCallback onLogout;
  final _AdminResponsive responsive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppColors.headerBgDark : AppColors.headerBgLight,
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppColors.darkGlassBorder : AppColors.glassBevelTop,
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              responsive.headerHorizontalPadding,
              responsive.headerVerticalPadding,
              responsive.headerTrailingPadding,
              responsive.headerVerticalPadding,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: responsive.headerLeadingSize,
                  height: responsive.headerLeadingSize,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkGlassMid
                        : Colors.white.withValues(alpha: 0.60),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.darkGlassBorder : AppColors.glassBevelTop,
                    ),
                  ),
                  child: Icon(
                    item.icon,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    size: responsive.headerLeadingIconSize,
                  ),
                ),
                SizedBox(width: responsive.headerGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        item.label,
                        style: AppTypography.heading2.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          fontSize: responsive.compact ? 18 : 20,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: responsive.compact ? 4 : 5),
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isDark ? AppColors.darkSuccess : AppColors.success)
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.bolt_rounded,
                                  size: responsive.compact ? 9 : 10,
                                  color: isDark ? AppColors.darkSuccess : AppColors.success,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Live',
                                  style: AppTypography.badge.copyWith(
                                    color: isDark ? AppColors.darkSuccess : AppColors.success,
                                    fontSize: responsive.compact ? 9 : 9.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              session.canteenName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySm.copyWith(
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.textMuted,
                                fontSize: responsive.compact ? 11.5 : 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Logout',
                  onPressed: onLogout,
                  style: IconButton.styleFrom(
                    minimumSize: Size.square(responsive.compact ? 38 : 42),
                    backgroundColor: (isDark ? AppColors.darkDanger : AppColors.danger)
                        .withValues(alpha: 0.12),
                    foregroundColor: isDark ? AppColors.darkDanger : AppColors.danger,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(Icons.logout_rounded, size: responsive.compact ? 18 : 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminBottomNavBar extends StatefulWidget {
  const _AdminBottomNavBar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_AdminNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<_AdminBottomNavBar> createState() => _AdminBottomNavBarState();
}

class _AdminBottomNavBarState extends State<_AdminBottomNavBar> {
  late List<bool> _pressed;

  @override
  void initState() {
    super.initState();
    _pressed = List<bool>.filled(widget.items.length, false);
  }

  @override
  void didUpdateWidget(_AdminBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _pressed = List<bool>.filled(widget.items.length, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final responsive = _AdminResponsive.of(context);
    final unselectedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          responsive.pageHorizontalInset,
          0,
          responsive.pageHorizontalInset,
          responsive.bottomNavBottomInset,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: responsive.bottomNavHeight,
              padding: EdgeInsets.symmetric(
                horizontal: responsive.bottomNavInnerPadding,
                vertical: responsive.bottomNavInnerPadding,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.navBgDark : AppColors.navBgLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkGlassBorder : AppColors.glassBevelTop,
                  width: 0.8,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                    blurRadius: 22,
                    spreadRadius: -2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: widget.items.length,
                separatorBuilder: (_, __) => SizedBox(width: responsive.compact ? 5 : 6),
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final selected = widget.selectedIndex == index;

                  return GestureDetector(
                    onTapDown: (_) => setState(() => _pressed[index] = true),
                    onTapUp: (_) => setState(() => _pressed[index] = false),
                    onTapCancel: () => setState(() => _pressed[index] = false),
                    onTap: () {
                      setState(() => _pressed[index] = false);
                      widget.onSelected(index);
                    },
                    child: AnimatedScale(
                      scale: _pressed[index] ? 0.93 : 1.0,
                      duration: const Duration(milliseconds: 110),
                      curve: Curves.easeOut,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOutCubic,
                        width: selected
                            ? responsive.bottomNavSelectedWidth
                            : responsive.bottomNavCollapsedWidth,
                        decoration: BoxDecoration(
                          gradient: selected
                              ? LinearGradient(
                                  colors: <Color>[
                                    item.color.withValues(alpha: isDark ? 0.25 : 0.20),
                                    item.color.withValues(alpha: isDark ? 0.12 : 0.07),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: selected
                              ? null
                              : (isDark ? AppColors.darkSurface : AppColors.bgSoft)
                                  .withValues(alpha: 0.60),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: selected
                                ? item.color.withValues(alpha: 0.50)
                                : (isDark ? AppColors.darkBorder : AppColors.border)
                                    .withValues(alpha: 0.70),
                            width: selected ? 1.5 : 0.8,
                          ),
                          boxShadow: selected
                              ? <BoxShadow>[
                                  BoxShadow(
                                    color: item.color.withValues(alpha: 0.20),
                                    blurRadius: 10,
                                    spreadRadius: -2,
                                  ),
                                ]
                              : null,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: responsive.bottomNavItemPadding,
                            vertical: responsive.bottomNavItemPadding,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              AnimatedScale(
                                scale: selected ? 1.10 : 1.0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutBack,
                                child: Icon(
                                  item.icon,
                                  size: selected
                                      ? (responsive.compact ? 19 : 20)
                                      : (responsive.compact ? 17 : 18),
                                  color: selected ? item.color : unselectedColor,
                                  shadows: selected
                                      ? <Shadow>[
                                          Shadow(
                                            color: item.color.withValues(alpha: 0.45),
                                            blurRadius: 10,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                              SizedBox(height: responsive.compact ? 2 : 3),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeInOutCubic,
                                child: selected
                                    ? Text(
                                        item.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: AppTypography.labelSm.copyWith(
                                          color: item.color,
                                          fontSize: responsive.compact ? 10 : 10.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.1,
                                        ),
                                      )
                                    : Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: unselectedColor.withValues(alpha: 0.45),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminSectionHeader extends StatelessWidget {
  const _AdminSectionHeader({
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: AppTypography.heading3.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: AppTypography.bodySm.copyWith(
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final responsive = _AdminResponsive.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.compact ? 12 : 14,
        vertical: responsive.compact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? <Color>[AppColors.darkCard, AppColors.darkCardRaised]
              : const <Color>[AppColors.card, AppColors.surfaceRaised],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? AppColors.darkBorder : AppColors.border)
              .withValues(alpha: 0.65),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.navy.withValues(alpha: isDark ? 0.16 : 0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: AppTypography.label.copyWith(
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.heading2.copyWith(
              fontSize: responsive.compact ? 22 : 24,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final responsive = _AdminResponsive.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1.5,
      child: Padding(
        padding: EdgeInsets.all(responsive.compact ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: responsive.compact ? 30 : 34,
                  height: responsive.compact ? 30 : 34,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: responsive.compact ? 16 : 18, color: iconColor),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: AppTypography.heading3.copyWith(
                    fontSize: responsive.compact ? 15 : 16,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}


class _AdminResponsive {
  const _AdminResponsive({
    required this.compact,
    required this.tiny,
  });

  factory _AdminResponsive.of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return _AdminResponsive(
      compact: width < 390,
      tiny: width < 350,
    );
  }

  final bool compact;
  final bool tiny;

  double get headerContentHeight => compact ? 82 : 88;
  double get pageHorizontalInset => tiny ? 8 : (compact ? 9 : 10);
  double get topContentInset => compact ? 8 : 10;

  double get headerHorizontalPadding => compact ? 12 : 16;
  double get headerTrailingPadding => compact ? 10 : 12;
  double get headerVerticalPadding => compact ? 12 : 14;
  double get headerLeadingSize => compact ? 40 : 46;
  double get headerLeadingIconSize => compact ? 20 : 22;
  double get headerGap => compact ? 10 : 14;

  double get bottomNavHeight => compact ? 72 : 78;
  double get bottomNavBottomInset => compact ? 8 : 10;
  double get bottomNavInnerPadding => compact ? 5 : 6;
  double get bottomNavSelectedWidth => tiny ? 92 : (compact ? 100 : 112);
  double get bottomNavCollapsedWidth => compact ? 54 : 58;
  double get bottomNavItemPadding => compact ? 5 : 6;
}

EdgeInsets _tabPadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 350) {
    return const EdgeInsets.all(12);
  }
  if (width < 390) {
    return const EdgeInsets.all(14);
  }
  return const EdgeInsets.all(16);
}
Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

List<dynamic> _asList(dynamic value) {
  if (value is List) {
    return value;
  }
  return const <dynamic>[];
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  return int.tryParse((value ?? '0').toString()) ?? 0;
}

double _asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse((value ?? '0').toString()) ?? 0;
}

String _currency(dynamic value) {
  return '₹${_asDouble(value).toStringAsFixed(2)}';
}

String _isoDate(DateTime value) {
  final date = DateTime(value.year, value.month, value.day);
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  return '${date.year}-$mm-$dd';
}

Color _statusColor(String status) {
  switch (status.trim().toLowerCase()) {
    case 'completed':
      return AppColors.success;
    case 'cancelled':
      return AppColors.danger;
    case 'preparing':
      return AppColors.primary;
    case 'ready':
      return AppColors.accent;
    case 'confirmed':
      return AppColors.info;
    default:
      return AppColors.warning;
  }
}
