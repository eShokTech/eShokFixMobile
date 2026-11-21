part of '../app.dart';

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({
    super.key,
    required this.store,
    required this.open,
    required this.query,
  });
  final LocalStore store;
  final ValueChanged<String> open;
  final String query;

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  Future<List<Map<String, Object?>>> _results = Future.value([]);
  late String _query;

  @override
  void initState() {
    super.initState();
    _query = widget.query.trim();
    _results = widget.store.globalSearch(_query);
  }

  @override
  void didUpdateWidget(covariant GlobalSearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _query = widget.query.trim();
      _results = widget.store.globalSearch(_query);
    }
  }

  IconData _icon(String type) => switch (type) {
    'CLIENTE' => Icons.person_outline,
    'EQUIPO' => Icons.smartphone_outlined,
    'ORDEN' => Icons.assignment_outlined,
    'PRODUCTO' => Icons.inventory_2_outlined,
    'PROVEEDOR' => Icons.local_shipping_outlined,
    'COMPRA' => Icons.shopping_bag_outlined,
    'VENTA' => Icons.point_of_sale_outlined,
    'GARANTIA' => Icons.verified_user_outlined,
    _ => Icons.search,
  };

  @override
  Widget build(BuildContext context) => PageFrame(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeading(
        'Búsqueda global',
        subtitle: 'Busca clientes, equipos, IMEI, órdenes, productos, compras y garantías',
      ),
      const SizedBox(height: 12),
      Expanded(
        child: _query.length < 2
            ? const Center(
                child: EmptyState(
                  title: 'Busca en todo el taller',
                  message: 'Escribe al menos dos caracteres en la barra superior para comenzar.',
                ),
              )
            : FutureBuilder<List<Map<String, Object?>>>(
                future: _results,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return EmptyState(
                      title: 'No se pudo completar la búsqueda',
                      message: '${snapshot.error}',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rows = snapshot.data!;
                  if (rows.isEmpty) {
                    return const Center(
                      child: EmptyState(
                        title: 'Sin coincidencias',
                        message: 'Prueba con otro nombre, folio, teléfono, IMEI o código.',
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final type = _str(row['type']);
                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => widget.open(_str(row['target_view'])),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                          child: Row(children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: eShokPurpleLight.withValues(alpha: .28),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(_icon(type), color: eShokPurple),
                            ),
                            const SizedBox(width: 11),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_str(row['title']),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                const SizedBox(height: 3),
                                Text(_str(row['subtitle']),
                                  maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0xFF81778D), fontSize: 10)),
                                const SizedBox(height: 5),
                                Text(type,
                                  style: const TextStyle(color: eShokPurple, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .8)),
                              ],
                            )),
                            const Icon(Icons.chevron_right, color: Color(0xFF9B91A5)),
                          ]),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    ]),
  );
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.store,
    required this.open,
    required this.onChanged,
  });
  final LocalStore store;
  final ValueChanged<String> open;
  final VoidCallback onChanged;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _unreadOnly = false;
  late Future<List<Map<String, Object?>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, Object?>>> _load() async {
    await widget.store.refreshOperationalNotifications();
    return widget.store.notifications(unreadOnly: _unreadOnly);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
    widget.onChanged();
  }

  Future<void> _markAllRead() async {
    try {
      await widget.store.markAllNotificationsRead();
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    }
  }

  Future<void> _openNotification(Map<String, Object?> row) async {
    final id = row['id'];
    if (id is int) await widget.store.markNotificationRead(id);
    widget.onChanged();
    final view = _str(row['target_view']);
    if (view.isNotEmpty && mounted) widget.open(view);
  }

  IconData _icon(String type) => switch (type) {
    'ORDER_OVERDUE' => Icons.schedule_outlined,
    'LOW_STOCK' => Icons.inventory_2_outlined,
    'PURCHASE_BALANCE' => Icons.receipt_long_outlined,
    _ => Icons.notifications_outlined,
  };

  Color _severityColor(String severity) => switch (severity) {
    'CRITICAL' => const Color(0xFFC33D55),
    'WARNING' => const Color(0xFFB47A2C),
    _ => const Color(0xFF6E62A5),
  };

  @override
  Widget build(BuildContext context) => PageFrame(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeading(
        'Notificaciones',
        subtitle: 'Alertas operativas generadas desde los datos locales del taller',
        trailing: TextButton(
          onPressed: _markAllRead,
          child: const Text('Marcar leídas'),
        ),
      ),
      const SizedBox(height: 8),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Todas')),
          ButtonSegment(value: true, label: Text('No leídas')),
        ],
        selected: {_unreadOnly},
        onSelectionChanged: (value) {
          setState(() {
            _unreadOnly = value.first;
            _future = _load();
          });
          widget.onChanged();
        },
      ),
      const SizedBox(height: 10),
      Expanded(
        child: FutureBuilder<List<Map<String, Object?>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return EmptyState(
                title: 'No se pudieron cargar las notificaciones',
                message: '${snapshot.error}',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final rows = snapshot.data!;
            if (rows.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    EmptyState(
                      title: _unreadOnly ? 'Todo está leído' : 'Sin notificaciones',
                      message: 'Aquí aparecerán atrasos, existencias bajas y saldos de compras.',
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final severity = _str(row['severity'], 'INFO');
                  final isRead = row['read_at'] != null;
                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _openNotification(row),
                    child: GlassCard(
                      padding: const EdgeInsets.all(13),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _severityColor(severity).withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_icon(_str(row['type'])), color: _severityColor(severity), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(child: Text(_str(row['title']),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                              if (!isRead) const Icon(Icons.circle, size: 8, color: eShokPurple),
                            ]),
                            const SizedBox(height: 4),
                            Text(_str(row['message']),
                              style: const TextStyle(fontSize: 10, color: Color(0xFF756B81), height: 1.35)),
                            const SizedBox(height: 6),
                            Text(_date(row['created_at']),
                              style: const TextStyle(fontSize: 9, color: Color(0xFF9A91A4))),
                          ],
                        )),
                        const Icon(Icons.chevron_right, color: Color(0xFF9B91A5)),
                      ]),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ]),
  );
}
