import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'device_journal.dart';
import '../models/crm.dart';
import '../models/daybook.dart';
import '../models/enums.dart';
import '../models/inventory.dart';
import '../models/invoice.dart';
import '../models/item.dart';
import '../models/shop_settings.dart';
import 'sync_identity.dart';

class BillingSnapshot {
  BillingSnapshot({
    required this.items,
    required this.inventory,
    required this.movements,
    required this.invoices,
    required this.loads,
    required this.customers,
    required this.payments,
    required this.expenses,
    required this.promos,
    this.settlements = const [],
    this.visits = const [],
    this.returnRequests = const [],
    this.daybook = const [],
    required this.settings,
    required this.usingSupabase,
    this.session,
    this.localeCode = 'en',
    this.pendingCloudSync = false,
  });

  final List<CatalogItem> items;
  final Map<String, InventoryRow> inventory;
  final List<StockMovement> movements;
  final List<Invoice> invoices;
  final List<VanLoad> loads;
  final List<Customer> customers;
  final List<LedgerPayment> payments;
  final List<VanExpense> expenses;
  final List<PromoRule> promos;
  final List<CashSettlement> settlements;
  final List<VisitLog> visits;
  final List<StockReturnRequest> returnRequests;
  final List<DaybookEntry> daybook;
  final ShopSettings settings;
  final bool usingSupabase;
  final UserSession? session;
  final String localeCode;
  final bool pendingCloudSync;
}

class BillingRepository {
  bool pendingCloudSync = false;

  BillingRepository._({
    required this.prefs,
    required this.client,
    required this.usingSupabase,
  });

  final SharedPreferences? prefs;
  SupabaseClient? client;
  bool usingSupabase;

  static const _cacheKey = 'uk_billing_cache_v4';
  static const _sessionKey = 'uk_session_v1';
  static const _localeKey = 'uk_locale_v1';

  Map<String, dynamic>? _memory;
  UserSession? _memorySession;
  bool _live = false;
  int localRevision = 0;
  int saveEpoch = 0;

  factory BillingRepository.memory() {
    return BillingRepository._(
      prefs: null,
      client: null,
      usingSupabase: false,
    ).._memory = _emptyStore();
  }

  static Future<BillingRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    SupabaseClient? client;
    var usingSupabase = false;
    if (SupabaseConfig.isConfigured) {
      try {
        await Supabase.initialize(
          url: SupabaseConfig.url,
          publishableKey: SupabaseConfig.anonKey,
        ).timeout(const Duration(seconds: 6));
        client = Supabase.instance.client;
        usingSupabase = true;
      } catch (_) {
        usingSupabase = false;
      }
    }
    return BillingRepository._(
      prefs: prefs,
      client: client,
      usingSupabase: usingSupabase,
    );
  }

  /// Attach Supabase after a boot that had no network. Safe to call repeatedly.
  Future<bool> ensureCloud() async {
    if (usingSupabase && client != null) return true;
    if (!SupabaseConfig.isConfigured) return false;
    try {
      client = Supabase.instance.client;
      usingSupabase = true;
      return true;
    } catch (_) {}
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
      ).timeout(const Duration(seconds: 6));
      client = Supabase.instance.client;
      usingSupabase = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<UserSession?> readSession() async {
    try {
      if (prefs == null) return _memorySession;
      final raw = prefs?.getString(_sessionKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return UserSession.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> writeSession(UserSession? session) async {
    if (prefs == null) {
      _memorySession = session;
      return;
    }
    if (session == null) {
      await prefs?.remove(_sessionKey);
      return;
    }
    await prefs?.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<void> writeLocale(String code) async {
    await prefs?.setString(_localeKey, code);
  }

  Future<String> readLocale() async => prefs?.getString(_localeKey) ?? 'en';

  Future<BillingSnapshot> load() async {
    final local = await _loadLocal();
    if (!usingSupabase || client == null || pendingCloudSync) return local;
    try {
      return await _loadRemote(localRevision).timeout(const Duration(seconds: 8));
    } catch (_) {
      return local;
    }
  }

  Future<BillingSnapshot> _loadRemote(int seenRevision) async {
    final sb = client!;
    final itemRows = await sb.from('items').select().order('name');
    final stockRows = await sb.from('stock').select();
    final moveRows = await sb
        .from('stock_movements')
        .select()
        .order('created_at', ascending: false)
        .limit(400);
    final invoiceRows =
        await sb.from('invoices').select().order('created_at', ascending: false);
    final lineRows = await sb.from('invoice_lines').select();
    final loadRows =
        await sb.from('van_loads').select().order('created_at', ascending: false);
    final loadLineRows = await sb.from('van_load_lines').select();
    final settingRows = await sb.from('shop_settings').select().limit(1);
    List customerRows = const [];
    List paymentRows = const [];
    List expenseRows = const [];
    List promoRows = const [];
    List visitRows = const [];
    try {
      customerRows = await sb.from('customers').select() as List;
      paymentRows = await sb.from('payments').select() as List;
      expenseRows = await sb.from('van_expenses').select() as List;
      promoRows = await sb.from('promo_rules').select() as List;
    } catch (_) {}
    try {
      visitRows = await sb.from('visit_logs').select() as List;
    } catch (_) {}

    final items = CatalogItem.unique(
      (itemRows as List)
          .map((row) => CatalogItem.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(),
    );

    final inventory = <String, InventoryRow>{};
    for (final row in stockRows as List) {
      final rec = InventoryRow.fromJson(Map<String, dynamic>.from(row as Map));
      inventory[rec.key] = rec;
    }
    for (final item in items) {
      for (final loc in StockLocation.values) {
        inventory.putIfAbsent(
          stockKey(loc, item.id),
          () => InventoryRow(
            itemId: item.id,
            location: loc,
            quantity: 0,
            reorderLevel: loc == StockLocation.warehouse ? 10 : 2,
          ),
        );
      }
    }

    final movements = (moveRows as List)
        .map((row) => StockMovement.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();

    final linesByInvoice = <String, List<InvoiceLine>>{};
    for (final row in lineRows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      linesByInvoice
          .putIfAbsent(map['invoice_id'].toString(), () => [])
          .add(InvoiceLine.fromJson(map));
    }
    final invoices = (invoiceRows as List).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      map['lines'] = (linesByInvoice[map['id'].toString()] ?? [])
          .map((line) => line.toJson())
          .toList();
      return Invoice.fromJson(map);
    }).toList();

    final loadLines = <String, List<VanLoadLine>>{};
    for (final row in loadLineRows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      loadLines
          .putIfAbsent(map['load_id'].toString(), () => [])
          .add(VanLoadLine.fromJson(map));
    }
    final loads = (loadRows as List).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      map['lines'] = (loadLines[map['id'].toString()] ?? [])
          .map((l) => l.toJson())
          .toList();
      return VanLoad.fromJson(map);
    }).toList();

    ShopSettings settings = ShopSettings.defaults();
    if ((settingRows as List).isNotEmpty) {
      settings = ShopSettings.fromJson(
        Map<String, dynamic>.from(settingRows.first as Map),
      );
    }

    final snapshot = BillingSnapshot(
      items: items,
      inventory: inventory,
      movements: movements,
      invoices: invoices,
      loads: loads,
      customers: customerRows
          .map((row) => Customer.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(),
      payments: paymentRows
          .map((row) => LedgerPayment.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(),
      expenses: expenseRows
          .map((row) => VanExpense.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(),
      promos: promoRows
          .map((row) => PromoRule.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(),
      settlements: await _remoteSettlements(),
      visits: visitRows
          .map((row) => VisitLog.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(),
      returnRequests: await _remoteReturnRequests(),
      settings: settings,
      usingSupabase: true,
      session: await readSession(),
      localeCode: await readLocale(),
    );
    await _persistLocal(snapshot, ifRevision: seenRevision);
    return snapshot;
  }

  Future<BillingSnapshot> _loadLocal() async {
    final candidates = <String?>[];
    if (prefs != null) {
      try {
        await prefs!.reload();
      } catch (_) {}
      candidates.add(prefs!.getString(_cacheKey));
    }
    candidates.add(DeviceJournal.readSync(_cacheKey));
    try {
      candidates.add(await DeviceJournal.readDurable(_cacheKey));
    } catch (_) {}
    final best = pickNewestJson(candidates);
    if (best != null) {
      _memory = best;
      final rev = best['revision'];
      if (rev is int && rev > localRevision) localRevision = rev;
      pendingCloudSync = best['pending_cloud_sync'] == true || pendingCloudSync;
      return _fromCache(best);
    }
    if (prefs == null) return _fromCache(_memory ?? _emptyStore());
    final data = _emptyStore();
    _memory = data;
    return _fromCache(data);
  }

  Future<List<StockReturnRequest>> _remoteReturnRequests() async {
    final body = await _remoteOpsBody();
    final rows = body?['return_requests'];
    if (rows is List) {
      return rows
          .map((row) => StockReturnRequest.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    }
    return (_memory?['return_requests'] as List? ?? [])
        .map((row) => StockReturnRequest.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<CashSettlement>> _remoteSettlements() async {
    final body = await _remoteOpsBody();
    final rows = body?['settlements'];
    if (rows is List) {
      return rows
          .map((row) => CashSettlement.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    }
    return (_memory?['settlements'] as List? ?? [])
        .map((row) => CashSettlement.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<Map<String, dynamic>?> _remoteOpsBody() async {
    final sb = client;
    if (sb == null) return null;
    try {
      final rows = await sb.from('ops_sync').select().eq('id', 'live').limit(1);
      if (rows.isEmpty) return null;
      final body = rows.first['body'];
      if (body is Map) return Map<String, dynamic>.from(body);
      if (body is String && body.isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  BillingSnapshot _fromCache(Map<String, dynamic> data) {
    final items = CatalogItem.unique(
      _decodeRows(data['items'], CatalogItem.fromJson),
    );
    final inventory = <String, InventoryRow>{};
    for (final parsed in _decodeRows(data['inventory'], InventoryRow.fromJson)) {
      inventory[parsed.key] = parsed;
    }
    ShopSettings settings = ShopSettings.defaults();
    if (data['settings'] is Map) {
      try {
        settings = ShopSettings.fromJson(Map<String, dynamic>.from(data['settings'] as Map));
      } catch (_) {}
    }
    return BillingSnapshot(
      items: items,
      inventory: inventory,
      movements: _decodeRows(data['movements'], StockMovement.fromJson),
      invoices: _decodeRows(data['invoices'], Invoice.fromJson),
      loads: _decodeRows(data['loads'], VanLoad.fromJson),
      customers: _decodeRows(data['customers'], Customer.fromJson),
      payments: _decodeRows(data['payments'], LedgerPayment.fromJson),
      expenses: _decodeRows(data['expenses'], VanExpense.fromJson),
      promos: _decodeRows(data['promos'], PromoRule.fromJson),
      settlements: _decodeRows(data['settlements'], CashSettlement.fromJson),
      visits: _decodeRows(data['visits'], VisitLog.fromJson),
      returnRequests: _decodeRows(data['return_requests'], StockReturnRequest.fromJson),
      daybook: _decodeRows(data['daybook'], DaybookEntry.fromJson),
      settings: settings,
      usingSupabase: usingSupabase && client != null,
      session: null,
      localeCode: 'en',
      pendingCloudSync: pendingCloudSync,
    );
  }

  List<T> _decodeRows<T>(dynamic raw, T Function(Map<String, dynamic>) parse) {
    if (raw is! List) return <T>[];
    final out = <T>[];
    for (final row in raw) {
      if (row is! Map) continue;
      try {
        out.add(parse(Map<String, dynamic>.from(row)));
      } catch (_) {}
    }
    return out;
  }

  Future<void> saveAll(BillingSnapshot snapshot) async {
    saveEpoch++;
    localRevision++;
    final cloudReady = usingSupabase && client != null;
    if (!cloudReady && SupabaseConfig.isConfigured && prefs != null) {
      pendingCloudSync = true;
    } else if (!cloudReady) {
      pendingCloudSync = false;
    }
    await _persistLocal(_deduped(snapshot));
    if (!cloudReady) return;
    final ready = _deduped(snapshot);
    final sb = client!;
    try {
      for (final item in ready.items) {
        await sb.from('items').upsert(item.toJson(), onConflict: 'id');
      }
      for (final row in ready.inventory.values) {
        await sb.from('stock').upsert(row.toJson());
      }
      for (final movement in ready.movements.take(300)) {
        await sb.from('stock_movements').upsert(movement.toJson(), onConflict: 'id');
      }
      for (final invoice in ready.invoices) {
        await sb.from('invoices').upsert(invoice.toHeaderJson(), onConflict: 'id');
        for (final line in invoice.lines) {
          await sb.from('invoice_lines').upsert(line.toJson(invoiceId: invoice.id), onConflict: 'id');
        }
      }
      for (final load in ready.loads) {
        final header = {
          'id': load.id,
          'van': load.van.name,
          'total_cost': load.totalCost,
          'total_sell': load.totalSell,
          'created_at': load.createdAt.toIso8601String(),
          'inbound': load.inbound,
        };
        try {
          await sb.from('van_loads').upsert(header, onConflict: 'id');
        } catch (_) {
          header.remove('inbound');
          await sb.from('van_loads').upsert(header, onConflict: 'id');
        }
        for (final line in load.lines) {
          await sb.from('van_load_lines').upsert({
            'id': '${load.id}-${line.itemId}',
            'load_id': load.id,
            ...line.toJson(),
          }, onConflict: 'id');
        }
      }
      await sb.from('shop_settings').upsert(ready.settings.toJson());
      for (final c in ready.customers) {
        final row = c.toJson();
        try {
          await sb.from('customers').upsert(row, onConflict: 'id');
        } catch (_) {
          if (!row.containsKey('shop_photo')) rethrow;
          row.remove('shop_photo');
          await sb.from('customers').upsert(row, onConflict: 'id');
        }
      }
      for (final p in ready.payments) {
        await sb.from('payments').upsert(p.toJson(), onConflict: 'id');
      }
      for (final e in ready.expenses) {
        await sb.from('van_expenses').upsert(e.toJson(), onConflict: 'id');
      }
      for (final p in ready.promos) {
        await sb.from('promo_rules').upsert(p.toJson(), onConflict: 'id');
      }
      for (final v in ready.visits) {
        await sb.from('visit_logs').upsert(v.toJson(), onConflict: 'id');
      }
      try {
        await sb.from('ops_sync').upsert({
          'id': 'live',
          'body': {
            'return_requests': ready.returnRequests.map((e) => e.toJson()).toList(),
            'settlements': ready.settlements.map((e) => e.toJson()).toList(),
          },
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
      pendingCloudSync = false;
      await _persistLocal(ready);
    } catch (_) {
      pendingCloudSync = true;
      await _persistLocal(ready);
    }
  }

  BillingSnapshot _deduped(BillingSnapshot snapshot) {
    return BillingSnapshot(
      items: uniqueById(snapshot.items, (row) => row.id),
      inventory: snapshot.inventory,
      movements: uniqueById(snapshot.movements, (row) => row.id),
      invoices: uniqueById(snapshot.invoices, (row) => row.id),
      loads: uniqueById(snapshot.loads, (row) => row.id),
      customers: uniqueById(snapshot.customers, (row) => row.id),
      payments: uniqueById(snapshot.payments, (row) => row.id),
      expenses: uniqueById(snapshot.expenses, (row) => row.id),
      promos: uniqueById(snapshot.promos, (row) => row.id),
      settlements: uniqueById(snapshot.settlements, (row) => row.id),
      visits: uniqueById(snapshot.visits, (row) => row.id),
      returnRequests: uniqueById(snapshot.returnRequests, (row) => row.id),
      daybook: uniqueById(snapshot.daybook, (row) => row.id),
      settings: snapshot.settings,
      usingSupabase: snapshot.usingSupabase,
      session: snapshot.session,
      localeCode: snapshot.localeCode,
      pendingCloudSync: snapshot.pendingCloudSync,
    );
  }

  Future<void> _persistLocal(BillingSnapshot snapshot, {int? ifRevision}) async {
    if (ifRevision != null && ifRevision != localRevision) return;
    final data = <String, dynamic>{
      'revision': localRevision,
      'pending_cloud_sync': pendingCloudSync,
      'items': snapshot.items.map((e) => e.toJson()).toList(),
      'inventory': snapshot.inventory.values.map((e) => e.toJson()).toList(),
      'movements': snapshot.movements.map((e) => e.toJson()).toList(),
      'invoices': snapshot.invoices.map((e) => e.toLocalJson()).toList(),
      'loads': snapshot.loads.map((e) => e.toJson()).toList(),
      'customers': snapshot.customers.map((e) => e.toJson()).toList(),
      'payments': snapshot.payments.map((e) => e.toJson()).toList(),
      'expenses': snapshot.expenses.map((e) => e.toJson()).toList(),
      'promos': snapshot.promos.map((e) => e.toJson()).toList(),
      'settlements': snapshot.settlements.map((e) => e.toJson()).toList(),
      'visits': snapshot.visits.map((e) => e.toJson()).toList(),
      'return_requests': snapshot.returnRequests.map((e) => e.toJson()).toList(),
      'daybook': snapshot.daybook.map((e) => e.toJson()).toList(),
      'settings': snapshot.settings.toJson(),
    };
    _memory = data;
    final encoded = jsonEncode(data);
    DeviceJournal.writeSync(_cacheKey, encoded);
    try {
      await prefs?.setString(_cacheKey, encoded);
    } catch (_) {}
    try {
      await DeviceJournal.writeDurable(_cacheKey, encoded);
    } catch (_) {}
  }

  static Map<String, dynamic> _emptyStore() {
    return {
      'items': <Map<String, dynamic>>[],
      'inventory': <Map<String, dynamic>>[],
      'movements': <Map<String, dynamic>>[],
      'invoices': <Map<String, dynamic>>[],
      'loads': <Map<String, dynamic>>[],
      'customers': <Map<String, dynamic>>[],
      'payments': <Map<String, dynamic>>[],
      'expenses': <Map<String, dynamic>>[],
      'promos': <Map<String, dynamic>>[],
      'settlements': <Map<String, dynamic>>[],
      'visits': <Map<String, dynamic>>[],
      'return_requests': <Map<String, dynamic>>[],
      'settings': ShopSettings.defaults().toJson(),
    };
  }

  void subscribeLive(void Function() onChange) {
    if (!usingSupabase || client == null || _live) return;
    _live = true;
    try {
      const tables = [
        'invoices',
        'invoice_lines',
        'payments',
        'stock',
        'stock_movements',
        'van_expenses',
        'items',
        'customers',
        'shop_settings',
        'van_loads',
        'van_load_lines',
        'promo_rules',
        'visit_logs',
        'ops_sync',
      ];
      var channel = client!.channel('uk-live');
      for (final table in tables) {
        channel = channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (_) => onChange(),
        );
      }
      channel.subscribe();
    } catch (_) {}
  }
}

/// Newest saved JSON wins. Unreadable copies are ignored.
Map<String, dynamic>? pickNewestJson(Iterable<String?> raws) {
  Map<String, dynamic>? best;
  var bestRev = -1;
  for (final raw in raws) {
    if (raw == null || raw.isEmpty) continue;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) continue;
      final map = Map<String, dynamic>.from(decoded);
      final rev = map['revision'] is int ? map['revision'] as int : 0;
      if (rev >= bestRev) {
        best = map;
        bestRev = rev;
      }
    } catch (_) {}
  }
  return best;
}

String nextDocNo(
  List<Invoice> invoices,
  DocType type, {
  String prefix = 'INV',
  bool auto = true,
}) {
  var maxSeq = 0;
  final taken = <String>{};
  for (final inv in invoices.where((i) => i.docType == type)) {
    taken.add(inv.invoiceNo.trim());
    final nums = RegExp(r'\d+').allMatches(inv.invoiceNo);
    if (nums.isEmpty) continue;
    final n = int.tryParse(nums.last.group(0)!) ?? 0;
    if (n > maxSeq) maxSeq = n;
  }
  var seq = maxSeq + 1;
  String body() => type == DocType.creditNote ? 'CN-$seq' : '$seq';
  if (!auto && type == DocType.taxInvoice) return body();
  while (taken.contains(body())) {
    seq++;
  }
  return body();
}
