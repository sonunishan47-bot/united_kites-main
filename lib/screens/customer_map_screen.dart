import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/crm.dart';
import '../models/enums.dart';
import '../services/analytics_engine.dart';
import '../services/map_customers.dart';
import '../services/whatsapp_share.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/collect_payment_sheet.dart';
import '../widgets/common.dart';
import '../widgets/glow_shop_pin.dart';
import '../widgets/hd_map.dart';
import 'invoice_editor_screen.dart';
import 'shell.dart';

class CustomerMapScreen extends StatefulWidget {
  const CustomerMapScreen({super.key});

  @override
  State<CustomerMapScreen> createState() => _CustomerMapScreenState();
}

class RouteScreen extends CustomerMapScreen {
  const RouteScreen({super.key});
}

class _CustomerMapScreenState extends State<CustomerMapScreen>
    with TickerProviderStateMixin {
  static const _buildingZoom = 17.2;

  final _search = TextEditingController();
  final _map = MapController();
  String _query = '';
  String? _selectedId;
  LatLng? _me;
  bool _locating = false;
  List<Customer> _routeStops = const [];
  MapImagery _imagery = MapImagery.road;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _warmLocation();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _warmLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppScope.of(context).s.t(
                'Turn on GPS / location services, then try again.',
                'فعّل خدمة الموقع ثم أعد المحاولة.',
              ),
            ),
          ),
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final last = await Geolocator.getLastKnownPosition();
      final pos = last ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
          );
      if (!mounted) return;
      setState(() => _me = LatLng(pos.latitude, pos.longitude));
    } catch (_) {}
  }

  List<Customer> _visible(BuildContext context) {
    return filterMappedCustomers(AppScope.of(context).customers, _query);
  }

  Future<void> _flyTo(LatLng dest, double zoom) async {
    LatLng from;
    double fromZoom;
    try {
      from = _map.camera.center;
      fromZoom = _map.camera.zoom;
    } catch (_) {
      try {
        _map.move(dest, zoom);
      } catch (_) {}
      return;
    }
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    final curve = CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
    final latT = Tween(begin: from.latitude, end: dest.latitude);
    final lngT = Tween(begin: from.longitude, end: dest.longitude);
    final zoomT = Tween(begin: fromZoom, end: zoom);
    controller.addListener(() {
      final t = curve.value;
      try {
        _map.move(LatLng(latT.transform(t), lngT.transform(t)), zoomT.transform(t));
      } catch (_) {}
    });
    await controller.forward();
    controller.dispose();
  }

  Future<void> _openShop(Customer customer) async {
    setState(() => _selectedId = customer.id);
    await _flyTo(LatLng(customer.lat, customer.lng), _buildingZoom);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _CustomerInfoSheet(customer: customer),
    );
  }

  Future<void> _goMyLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppScope.of(context).s.t(
                'Turn on GPS / location services, then try again.',
                'فعّل خدمة الموقع ثم أعد المحاولة.',
              ),
            ),
          ),
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppScope.of(context).s.t(
                'Location permission is required.',
                'يلزم السماح بالموقع.',
              ),
            ),
          ),
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() => _me = here);
      await _flyTo(here, 16.4);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppScope.of(context).s.t(
              'Could not read GPS. Enable location and try again.',
              'تعذر قراءة الموقع. فعّل الـ GPS ثم أعد المحاولة.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  LatLng get _routeStart => _me ?? HdMapTiles.riyadh;

  Future<void> _planBestRoute() async {
    var start = _routeStart;
    if (_me == null) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          start = LatLng(last.latitude, last.longitude);
          setState(() => _me = start);
        }
      } catch (_) {}
    }
    if (!mounted) return;
    final shops = _visible(context);
    final ordered = const AnalyticsEngine().optimizeRoute(
      shops,
      startLat: start.latitude,
      startLng: start.longitude,
    );
    if (ordered.isEmpty) return;
    setState(() => _routeStops = ordered);
    final points = [
      start,
      ...ordered.map((c) => LatLng(c.lat, c.lng)),
    ];
    try {
      _map.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.fromLTRB(56, 120, 56, 140),
          maxZoom: 16.2,
        ),
      );
    } catch (_) {}
    if (!mounted) return;
    final s = AppScope.of(context).s;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.t(
            'Best route: ${ordered.length} stops (1 → ${ordered.length}).',
            'أفضل مسار: ${ordered.length} توقف (1 ← ${ordered.length}).',
          ),
        ),
        action: SnackBarAction(
          label: s.t('Google Maps', 'خرائط جوجل'),
          onPressed: () => const WhatsAppShare().openGoogleRoute(ordered),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    if (!billing.canAccessMaps) {
      return Scaffold(
        appBar: AppBar(title: Text(s.routes)),
        body: EmptyHint(
          icon: Icons.map_outlined,
          message: s.t(
            'Maps, GPS tracking, and routes are not available for the Partner role.',
            'الخرائط وتتبع GPS والمسارات غير متاحة لدور الشريك.',
          ),
        ),
      );
    }
    final visible = _visible(context);

    return Scaffold(
      backgroundColor: const Color(0xFFE8EEF4),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        title: Text(s.routes),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: HdMapTiles.ksaCenter,
                initialZoom: HdMapTiles.initialZoom,
                minZoom: 3,
                maxZoom: HdMapTiles.maxZoomFor(_imagery),
                backgroundColor: const Color(0xFFD4E4F0),
                interactionOptions: HdMapTiles.interaction,
                onTap: (tapPosition, point) => setState(() => _selectedId = null),
              ),
              children: [
                ...HdMapTiles.layers(context, _imagery),
                RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  attributions: [
                    TextSourceAttribution(HdMapTiles.attributionFor(_imagery)),
                  ],
                ),
                if (_routeStops.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [
                          _routeStart,
                          ..._routeStops.map((c) => LatLng(c.lat, c.lng)),
                        ],
                        strokeWidth: 5,
                        color: const Color(0xFF1A73E8),
                        borderStrokeWidth: 2,
                        borderColor: Colors.white,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (_me != null)
                      Marker(
                        point: _me!,
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A73E8),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(color: Color(0x661A73E8), blurRadius: 10),
                            ],
                          ),
                        ),
                      ),
                    for (final customer in visible)
                      Marker(
                        point: LatLng(customer.lat, customer.lng),
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: GestureDetector(
                          onTap: () => _openShop(customer),
                          child: GlowShopPin(
                            selected: _selectedId == customer.id,
                            color: billing.customerDue(customer.id) > 0.05
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    for (var i = 0; i < _routeStops.length; i++)
                      Marker(
                        point: LatLng(_routeStops[i].lat, _routeStops[i].lng),
                        width: 22,
                        height: 22,
                        alignment: Alignment.topCenter,
                        child: IgnorePointer(
                          child: _StopBadge(n: i + 1),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 56,
            left: 12,
            right: 12,
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: s.t(
                    'Search shop, customer, or city…',
                    'بحث بالمحل أو العميل أو المدينة…',
                  ),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  filled: false,
                ),
                onChanged: (value) async {
                  setState(() => _query = value);
                  final hits = filterMappedCustomers(billing.customers, value);
                  if (hits.length == 1) {
                    setState(() => _selectedId = hits.first.id);
                    await _flyTo(LatLng(hits.first.lat, hits.first.lng), _buildingZoom);
                  }
                },
                onSubmitted: (value) {
                  final hits = filterMappedCustomers(billing.customers, value);
                  if (hits.isNotEmpty) _openShop(hits.first);
                },
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 118,
            left: 12,
            child: _ImageryToggle(
              imagery: _imagery,
              onChanged: (mode) => setState(() => _imagery = mode),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 118,
            right: 12,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.navy,
                foregroundColor: Colors.white,
                elevation: 3,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onPressed: _planBestRoute,
              icon: const Icon(Icons.route, size: 18),
              label: Text(
                s.t('Plan Best Route', 'أفضل مسار'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 20,
            child: Column(
              children: [
                _MapFab(
                  icon: _locating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, color: Color(0xFF1A73E8)),
                  tooltip: s.t('My Location', 'موقعي'),
                  onPressed: _locating ? null : _goMyLocation,
                ),
                const SizedBox(height: 8),
                _MapFab(
                  icon: const Icon(Icons.public, color: AppTheme.navy),
                  tooltip: s.t('Saudi Arabia view', 'عرض السعودية'),
                  onPressed: () {
                    setState(() => _routeStops = const []);
                    _flyTo(HdMapTiles.ksaCenter, HdMapTiles.initialZoom);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageryToggle extends StatelessWidget {
  const _ImageryToggle({required this.imagery, required this.onChanged});

  final MapImagery imagery;
  final ValueChanged<MapImagery> onChanged;

  @override
  Widget build(BuildContext context) {
    const modes = MapImagery.values;
    const labels = ['Road', 'Satellite', 'Hybrid', 'Terrain'];
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < modes.length; i++)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onChanged(modes[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: imagery == modes[i] ? const Color(0xFF1A73E8) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: imagery == modes[i] ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StopBadge extends StatelessWidget {
  const _StopBadge({required this.n});
  final int n;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFF1A73E8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$n',
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _MapFab extends StatelessWidget {
  const _MapFab({required this.icon, required this.onPressed, required this.tooltip});

  final Widget icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        elevation: 3,
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: 44, height: 44, child: Center(child: icon)),
        ),
      ),
    );
  }
}

class _CustomerInfoSheet extends StatelessWidget {
  const _CustomerInfoSheet({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final due = billing.customerDue(customer.id);
    final billed = billing.customerBilled(customer.id);
    final last = billing.latestInvoiceFor(customer.id);
    final now = DateTime.now();
    final monthOrders = billing.invoices.where((i) {
      if (i.customerId != customer.id || i.docType != DocType.taxInvoice) return false;
      return i.createdAt.year == now.year && i.createdAt.month == now.month;
    }).length;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            customer.shopName.isEmpty ? customer.name : customer.shopName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3),
          ),
          const SizedBox(height: 2),
          Text(
            customer.name,
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
          if (customer.phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(customer.phone, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ],
          if (customer.address.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place_outlined, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(child: Text(customer.address)),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: s.t('Outstanding', 'المستحق'),
                  value: sar.format(due),
                  color: due > 0.05 ? AppTheme.fabRed : const Color(0xFF16A34A),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: s.t('Last order', 'آخر طلب'),
                  value: last == null ? '—' : sar.format(last.grandTotal),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: s.t('This month', 'هذا الشهر'),
                  value: '$monthOrders',
                ),
              ),
            ],
          ),
          if (last != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${last.invoiceNo} · ${dayTime.format(last.createdAt)} · ${s.t('Billed', 'مفوتر')} ${sar.format(billed)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.fabRed),
              onPressed: () => const WhatsAppShare().openDirections(customer),
              icon: const Icon(Icons.navigation_rounded),
              label: Text(
                s.t('Navigate', 'انتقال'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
          if (!billing.isPartner) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => InvoiceEditorScreen(
                            controller: billing,
                            forCustomer: customer,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.point_of_sale_outlined),
                    label: Text(s.t('Add New Sale', 'بيع جديد')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () async {
                      final host = Navigator.of(context).context;
                      Navigator.pop(context);
                      await Future<void>.delayed(Duration.zero);
                      if (!host.mounted) return;
                      await CollectPaymentSheet.open(host, billing: billing, customer: customer);
                    },
                    icon: const Icon(Icons.payments_outlined),
                    label: Text(s.t('Receive Payment', 'استلام دفعة')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
