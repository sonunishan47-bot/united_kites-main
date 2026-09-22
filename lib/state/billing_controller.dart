import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../l10n/strings.dart';
import '../models/app_options.dart';
import '../models/crm.dart';
import '../models/daybook.dart';
import '../models/enums.dart';
import '../models/inventory.dart';
import '../models/invoice.dart';
import '../models/item.dart';
import '../models/shop_settings.dart';
import '../services/accounting_engine.dart';
import '../services/analytics_engine.dart';
import '../services/billing_repository.dart';
import '../utils/formatters.dart';

class RbacException implements Exception {
  RbacException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BillingController extends ChangeNotifier {
  BillingController(this.repository);

  final BillingRepository repository;

  List<CatalogItem> items = [];
  Map<String, InventoryRow> inventory = {};
  List<StockMovement> movements = [];
  List<Invoice> invoices = [];
  List<VanLoad> loads = [];
  List<Customer> customers = [];
  List<LedgerPayment> payments = [];
  List<VanExpense> expenses = [];
  List<PromoRule> promos = [];
  List<CashSettlement> settlements = [];
  List<VisitLog> visits = [];
  List<StockReturnRequest> returnRequests = [];
  List<DaybookEntry> daybook = [];
  ShopSettings settings = ShopSettings.defaults();
  UserSession? session;
  bool usingSupabase = false;
  bool pendingCloudSync = false;
  bool syncing = false;
  bool loading = true;
  String? error;
  String localeCode = 'en';
  Timer? _poll;
  Timer? _reloadDebounce;
  bool _liveStarted = false;
  bool _notifyQueued = false;
  bool _disposing = false;
  int _writes = 0;

  S get s => S(localeCode);
  bool get isAdmin => session?.isAdmin == true;
  bool get isSalesman => session?.isSalesman == true;
  bool get isPartner => session?.isPartner == true;
  bool get canEditPostedInvoices => isAdmin;
  bool get canDeleteInvoices => isAdmin;
  bool get canMutateStock => isAdmin;
  bool get canChangeCreditLimits => isAdmin;
  bool get canSeeCosts => isAdmin || isPartner;
  bool get canAccessMaps => !isPartner;
  bool get canEditAppSettings => isAdmin;
  bool get canSeePartnerMetrics => isAdmin || isPartner;
  bool get canOverrideSellPrice => isAdmin;
  bool get canOpenMasterAdmin => isAdmin;
  StockLocation? get scopedVan => isSalesman ? session?.sellingLocation : null;
  List<Invoice> get scopedInvoices {
    final van = scopedVan;
    if (van == null) return invoices;
    return invoices.where((i) => i.location == van).toList();
  }

  List<VanExpense> get scopedExpenses {
    final van = scopedVan;
    if (van == null) return expenses;
    return expenses.where((e) => e.van == van.name).toList();
  }

  List<StockReturnRequest> get scopedReturnRequests {
    final van = scopedVan;
    if (van == null) return returnRequests;
    return returnRequests.where((r) => r.van == van).toList();
  }

  List<StockReturnRequest> get pendingReturnRequests =>
      returnRequests.where((r) => r.isPending).toList();

  int get pendingReturnCount => pendingReturnRequests.length;
  bool sessionLocked = false;

  AppOptions get opt => settings.options;

  Future<void> load({bool silent = false}) async {
    if (silent && _writes > 0) return;
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    final seen = repository.saveEpoch;
    final before = _syncStamp;
    try {
      final snap = await repository.load();
      if (_disposing) return;
      if (silent && (_writes > 0 || repository.saveEpoch != seen)) return;
      _apply(snap);
      session = await repository.readSession() ?? snap.session ?? session;
      localeCode = snap.localeCode.isEmpty ? localeCode : snap.localeCode;
      if (settings.options.language.isNotEmpty) localeCode = settings.options.language;
      await _revokeStaleSession();
      _listenLive();
      if (silent && _syncStamp == before) return;
    } catch (e) {
      error = e.toString();
    } finally {
      if (!silent || _syncStamp != before) {
        loading = false;
        notifyListeners();
      } else {
        loading = false;
      }
    }
  }

  String get _syncStamp {
    final stock = inventory.values.fold<double>(0, (sum, row) => sum + row.quantity);
    final prices = items.fold<double>(0, (sum, item) => sum + item.sellingPerPiece + item.purchaseCost);
    final pending = returnRequests.where((row) => row.isPending).length;
    return '${items.length}|${customers.length}|${invoices.length}|${payments.length}|${expenses.length}|$pending|${loads.length}|${stock.toStringAsFixed(3)}|${prices.toStringAsFixed(2)}|${settings.adminPin}|${settings.van1Pin}|${settings.van2Pin}|${settings.partnerPin}|${movements.length}|${daybook.length}';
  }

  void _apply(BillingSnapshot snap) {
    items = CatalogItem.unique(snap.items)..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    inventory = Map.of(snap.inventory);
    movements = [...snap.movements]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    invoices = [...snap.invoices]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    loads = [...snap.loads]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    customers = [...snap.customers]..sort((a, b) => a.shopName.compareTo(b.shopName));
    payments = [...snap.payments]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    expenses = [...snap.expenses]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    promos = [...snap.promos];
    settlements = [...snap.settlements]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    visits = [...snap.visits]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    returnRequests = [...snap.returnRequests]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    daybook = [...snap.daybook]..sort((a, b) => b.at.compareTo(a.at));
    settings = snap.settings.normalized();
    usingSupabase = snap.usingSupabase;
    pendingCloudSync = snap.pendingCloudSync || repository.pendingCloudSync;
  }

  Future<void> _commit() async {
    _writes++;
    try {
      await repository.saveAll(_snap());
      pendingCloudSync = repository.pendingCloudSync;
    } finally {
      _writes--;
    }
  }

  @override
  void notifyListeners() {
    if (_disposing) return;
    if (_notifyQueued) return;
    _notifyQueued = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyQueued = false;
      if (_disposing || !hasListeners) return;
      super.notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposing = true;
    _poll?.cancel();
    _reloadDebounce?.cancel();
    super.dispose();
  }

  Future<bool> syncNow() async {
    if (syncing) return !pendingCloudSync;
    syncing = true;
    notifyListeners();
    try {
      await repository.saveAll(_snap());
      pendingCloudSync = repository.pendingCloudSync;
      return !pendingCloudSync;
    } catch (_) {
      pendingCloudSync = usingSupabase;
      return false;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  BillingSnapshot _snap() => BillingSnapshot(
        items: items,
        inventory: inventory,
        movements: movements,
        invoices: invoices,
        loads: loads,
        customers: customers,
        payments: payments,
        expenses: expenses,
        promos: promos,
        settlements: settlements,
        visits: visits,
        returnRequests: returnRequests,
        daybook: daybook,
        settings: settings,
        usingSupabase: usingSupabase,
        session: session,
        localeCode: localeCode,
      );

  Future<void> setSession(UserSession? value) async {
    if (value != null) {
      value = value.copyWith(credentialStamp: expectedCredentialStamp(value));
    }
    session = value;
    sessionLocked = value != null && settings.options.lockEnabled;
    await repository.writeSession(value);
    _listenLive();
    notifyListeners();
  }

  String _stampRoleKey(UserSession value) {
    if (value.isAdmin) return 'admin';
    if (value.isPartner) return 'partner';
    if (value.van == StockLocation.van2) return 'van2';
    return 'van1';
  }

  String pinForSession(UserSession value) {
    switch (_stampRoleKey(value)) {
      case 'admin':
        return settings.adminPin;
      case 'partner':
        return settings.partnerPin;
      case 'van2':
        return settings.van2Pin;
      default:
        return settings.van1Pin;
    }
  }

  String expectedCredentialStamp(UserSession value) =>
      credentialStamp(_stampRoleKey(value), pinForSession(value));

  Future<void> _revokeStaleSession() async {
    final current = session;
    if (current == null) return;
    if (current.credentialStamp == expectedCredentialStamp(current)) return;
    session = null;
    sessionLocked = false;
    await repository.writeSession(null);
  }

  bool unlockMasterAdmin(String pin) =>
      pin.trim() == settings.masterAdminPin.trim() ||
      (settings.masterAdminPin.trim().isEmpty && unlockAdmin(pin));

  String get _actor {
    final current = session;
    if (current == null) return 'System';
    if (current.isAdmin) return 'Admin';
    if (current.isPartner) return 'Partner';
    if (current.van == StockLocation.van2) return 'V2';
    if (current.isSalesman) return 'V1';
    return current.label;
  }

  void _audit({
    required String action,
    required String reference,
    double amount = 0,
    String note = '',
  }) {
    daybook = [
      DaybookEntry(
        id: newId(),
        action: action,
        reference: reference,
        actor: _actor,
        amount: moneyRound(amount),
        note: note,
      ),
      ...daybook,
    ];
  }

  StockLocation? unlockVan(String pin) {
    final p = pin.trim();
    if (p.isEmpty) return null;
    final v1 = settings.van1Pin.trim();
    final v2 = settings.van2Pin.trim();
    if (p == v1 && p != v2) return StockLocation.van1;
    if (p == v2 && p != v1) return StockLocation.van2;
    if (p == v1 && p == v2) return StockLocation.van1;
    return null;
  }

  String nextUniqueAccessPin() {
    final used = {
      settings.adminPin.trim(),
      settings.partnerPin.trim(),
      settings.van1Pin.trim(),
      settings.van2Pin.trim(),
      settings.masterAdminPin.trim(),
    };
    for (var i = 0; i < 40; i++) {
      final pin = generateAccessPin();
      if (!used.contains(pin)) return pin;
    }
    return generateAccessPin();
  }

  Future<void> updateAccessPins({
    String? partnerPin,
    String? van1Pin,
    String? van2Pin,
    String? masterAdminPin,
    String? adminPin,
  }) async {
    _requireAdmin();
    settings = settings.copyWith(
      partnerPin: partnerPin,
      van1Pin: van1Pin,
      van2Pin: van2Pin,
      masterAdminPin: masterAdminPin,
      adminPin: adminPin,
    );
    notifyListeners();
    await _commit();
    await _revokeStaleSession();
    notifyListeners();
  }

  bool unlockApp(String pin) {
    final expected = settings.options.lockPin.trim().isEmpty
        ? settings.adminPin.trim()
        : settings.options.lockPin.trim();
    if (pin.trim() != expected) return false;
    sessionLocked = false;
    notifyListeners();
    return true;
  }

  Future<void> setLocale(String code) async {
    localeCode = code;
    settings = settings.copyWith(options: settings.options.copyWith(language: code));
    await repository.writeLocale(code);
    notifyListeners();
    await _commit();
  }

  void _scheduleReload() {
    if (_disposing) return;
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 400), () {
      if (_disposing) return;
      load(silent: true);
    });
  }

  void _listenLive() {
    if (_liveStarted) return;
    _liveStarted = true;
    _poll = Timer.periodic(const Duration(seconds: 8), (_) {
      _backgroundSync();
    });
    if (usingSupabase) repository.subscribeLive(_scheduleReload);
  }

  /// Push books that were saved while offline, then refresh when the cloud is up.
  Future<void> _backgroundSync() async {
    if (_disposing || _writes > 0 || syncing) return;
    if (pendingCloudSync || repository.pendingCloudSync) {
      final ready = await repository.ensureCloud();
      if (_disposing || !ready) return;
      usingSupabase = true;
      repository.subscribeLive(_scheduleReload);
      await syncNow();
      return;
    }
    if (!usingSupabase) {
      final ready = await repository.ensureCloud();
      if (!ready || _disposing) return;
      usingSupabase = true;
      repository.subscribeLive(_scheduleReload);
    }
    await load(silent: true);
  }

  bool unlockAdmin(String pin) {
    final p = pin.trim();
    return p == settings.adminPin.trim() || p == settings.masterAdminPin.trim();
  }

  bool unlockPartner(String pin) => pin.trim() == settings.partnerPin.trim();

  void _requireWrite() {
    if (isPartner) {
      throw RbacException(s.t('Partner view is read-only.', 'عرض الشريك للقراءة فقط.'));
    }
  }

  void _requireAdmin() {
    _requireWrite();
    if (!isAdmin) {
      throw RbacException(
        s.t(
          'Admin only. Salesmen cannot edit posted invoices, stock, or credit limits.',
          'للمدير فقط. لا يمكن للمندوب تعديل الفواتير المرحلة أو المخزون أو حد الائتمان.',
        ),
      );
    }
  }

  CatalogItem? itemById(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  InventoryRow stockAt(StockLocation location, String itemId) =>
      inventory[stockKey(location, itemId)] ??
      InventoryRow(
        itemId: itemId,
        location: location,
        quantity: 0,
        reorderLevel: location == StockLocation.warehouse ? 10 : 2,
      );

  double itemOnHand(String itemId) {
    if (isSalesman && session != null) {
      return stockAt(session!.sellingLocation, itemId).quantity;
    }
    var total = 0.0;
    for (final loc in StockLocation.values) {
      if (loc == StockLocation.damage) continue;
      total += stockAt(loc, itemId).quantity;
    }
    return moneyRound(total);
  }

  List<ItemTxn> itemTransactions(String itemId) {
    final rows = <ItemTxn>[];
    final sku = (itemById(itemId)?.sku ?? '').trim().toLowerCase();
    for (final inv in scopedInvoices) {
      for (final line in inv.lines) {
        final byId = line.itemId == itemId;
        final bySku = sku.isNotEmpty && line.sku.trim().toLowerCase() == sku;
        if (!byId && !bySku) continue;
        final sale = !inv.isCreditNote;
        final shop = inv.shopName.trim();
        final party = shop.isNotEmpty ? shop : inv.customerName.trim();
        rows.add(
          ItemTxn(
            at: inv.createdAt,
            label: sale ? 'Sale' : 'Return',
            qty: line.stockPieces,
            amount: line.lineTotal,
            party: party.isEmpty ? (sale ? 'Sale' : 'Return') : party,
            rate: line.unitPrice,
            unit: line.billingUnit.shortLabel,
            billedQty: line.quantity,
            sale: sale,
          ),
        );
      }
    }
    for (final m in movements.where((m) => m.itemId == itemId)) {
      final r = m.reason.toLowerCase();
      String label = 'Stock';
      if (r.contains('returned')) {
        label = m.reason.trim().isEmpty ? 'Returned from Invoice' : m.reason;
      } else if ((r.contains('invoice') || r.contains('credit')) && !r.contains('return')) {
        continue;
      } else if (r.contains('opening')) {
        label = 'Opening Stock';
      } else if (r.contains('load')) {
        label = 'Van Load';
      } else if (r.contains('damage')) {
        label = 'Damage';
      } else if (m.reason.trim().isNotEmpty) {
        label = m.reason;
      }
      final item = itemById(itemId);
      rows.add(
        ItemTxn(
          at: m.createdAt,
          label: label,
          qty: m.delta.abs(),
          amount: item == null ? 0 : item.stockValueOf(m.delta.abs()),
        ),
      );
    }
    rows.sort((a, b) => b.at.compareTo(a.at));
    return rows;
  }

  double vanStockValue(StockLocation van, {required bool atCost}) {
    var total = 0.0;
    for (final item in items) {
      final qty = stockAt(van, item.id).quantity;
      total += atCost ? item.stockValueOf(qty) : item.stockSellValueOf(qty);
    }
    return moneyRound(total);
  }

  StockMetrics stockMetrics(StockLocation loc) => StockMetrics(
        quantity: stockPieceCount(loc),
        purchaseValue: vanStockValue(loc, atCost: true),
        sellingValue: vanStockValue(loc, atCost: false),
      );

  int stockedProductCount(StockLocation loc) =>
      items.where((item) => stockAt(loc, item.id).quantity > 0.001).length;

  double stockPieceCount(StockLocation loc) => moneyRound(
        items.fold(0.0, (sum, item) => sum + stockAt(loc, item.id).quantity),
      );

  int get lowStockCount => items.where((item) => isLowAt(StockLocation.warehouse, item.id)).length;

  bool isLowAt(StockLocation loc, String itemId) {
    final row = stockAt(loc, itemId);
    final floor = row.reorderLevel > 0 ? row.reorderLevel : settings.options.lowStockThreshold;
    return row.quantity <= floor;
  }

  double salesFor(StockLocation? van, {bool todayOnly = false}) {
    final today = DateTime.now();
    return moneyRound(invoices.where((inv) {
      if (inv.docType != DocType.taxInvoice) return false;
      if (van != null && inv.location != van) return false;
      if (todayOnly &&
          (inv.createdAt.year != today.year ||
              inv.createdAt.month != today.month ||
              inv.createdAt.day != today.day)) {
        return false;
      }
      return true;
    }).fold(0.0, (sum, inv) => sum + inv.grandTotal));
  }

  double creditsFor(StockLocation? van, {bool todayOnly = false}) {
    final today = DateTime.now();
    final total = invoices.where((inv) {
      if (inv.docType != DocType.creditNote) return false;
      if (van != null && inv.location != van) return false;
      if (todayOnly &&
          (inv.createdAt.year != today.year ||
              inv.createdAt.month != today.month ||
              inv.createdAt.day != today.day)) {
        return false;
      }
      return true;
    }).fold(0.0, (sum, inv) => sum + inv.grandTotal);
    return moneyRound(total);
  }

  Invoice _withZatca(Invoice invoice) {
    final prior = invoices.where((row) => row.id != invoice.id && row.submitted).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final icv = invoice.icv > 0 ? invoice.icv : prior.length + 1;
    final pih = invoice.pih.isNotEmpty
        ? invoice.pih
        : (prior.isEmpty
            ? zatcaZeroPih
            : (prior.last.invoiceHash.isEmpty ? zatcaZeroPih : prior.last.invoiceHash));
    final uuid = invoice.uuid.isEmpty ? invoice.id : invoice.uuid;
    final chained = invoice.copyWith(uuid: uuid, icv: icv, pih: pih, submitted: true);
    final digest = ZatcaQr.digestOf(
      uuid: uuid,
      invoiceNo: chained.invoiceNo,
      icv: icv,
      pih: pih,
      totalWithVat: chained.grandTotal,
      vatAmount: chained.taxTotal,
      timestamp: chained.createdAt,
    );
    final qr = ZatcaQr.encode(
      sellerName: chained.sellerName.isEmpty ? settings.shopName : chained.sellerName,
      vatNumber: chained.vatTrn.isEmpty ? settings.vatTrn : chained.vatTrn,
      timestamp: chained.createdAt,
      totalWithVat: chained.grandTotal,
      vatAmount: chained.taxTotal,
      invoiceHash: digest.bytes,
    );
    return chained.copyWith(invoiceHash: digest.hex, zatcaQr: qr, submitted: true);
  }

  Future<void> saveItem(CatalogItem item, {Map<StockLocation, double>? opening}) async {
    _requireAdmin();
    var ready = item;
    for (final row in items) {
      final sameSku =
          item.sku.trim().isNotEmpty && row.sku.trim().toLowerCase() == item.sku.trim().toLowerCase();
      final sameName = row.name.trim().toLowerCase() == item.name.trim().toLowerCase() &&
          row.volume.trim().toLowerCase() == item.volume.trim().toLowerCase() &&
          row.department == item.department;
      if (row.id != item.id && (sameSku || sameName)) {
        ready = CatalogItem(
          id: row.id,
          sku: item.sku.trim().isEmpty ? row.sku : item.sku,
          name: item.name,
          department: item.department,
          size: item.size,
          color: item.color,
          volume: item.volume,
          unit: item.unit,
          purchaseCost: item.purchaseCost,
          sellingPrice: item.sellingPrice,
          unitsPerCarton: item.unitsPerCarton,
          cartonPrice: item.cartonPrice,
          taxRate: item.taxRate,
        );
        break;
      }
    }
    final exists = items.any((row) => row.id == ready.id);
    items = CatalogItem.unique([
      ...[for (final row in items) if (row.id != ready.id) row],
      ready,
    ])..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    for (final loc in StockLocation.values) {
      final current = stockAt(loc, ready.id);
      final target = moneyRound(opening?[loc] ?? current.quantity);
      final delta = moneyRound(target - current.quantity);
      if (delta.abs() > 0.001) {
        _move(ready.id, loc, delta, exists ? 'Stock adjustment' : 'Opening stock');
      } else if (!inventory.containsKey(current.key)) {
        inventory[current.key] = current;
      }
    }
    notifyListeners();
    await _commit();
  }

  Future<void> deleteItem(String id) async {
    _requireAdmin();
    items = items.where((item) => item.id != id).toList();
    inventory.removeWhere((key, _) => key.endsWith('::$id'));
    notifyListeners();
    await _commit();
  }

  Future<void> adjustStock({
    required String itemId,
    required StockLocation location,
    required double delta,
    required String reason,
  }) async {
    _requireAdmin();
    _move(itemId, location, delta, reason);
    _audit(action: 'Stock adjustment', reference: itemId, amount: delta, note: reason);
    notifyListeners();
    await _commit();
  }

  void _move(String itemId, StockLocation location, double delta, String reason) {
    final current = stockAt(location, itemId);
    final nextQty = moneyRound(current.quantity + delta);
    if (nextQty < -0.001) {
      throw RbacException(
        s.t(
          'Not enough stock at ${location.label}.',
          'لا يوجد مخزون كافٍ في ${location.label}.',
        ),
      );
    }
    final next = current.copyWith(
      quantity: nextQty.clamp(0, 999999).toDouble(),
      updatedAt: DateTime.now(),
    );
    inventory = {...inventory, next.key: next};
    movements = [
      StockMovement(
        id: newId(),
        itemId: itemId,
        location: location,
        delta: delta,
        reason: reason,
      ),
      ...movements,
    ];
  }

  Future<VanLoad> loadVan({
    required StockLocation van,
    required List<VanLoadLine> lines,
  }) async {
    _requireAdmin();
    if (!van.isVan) throw RbacException('Pick Van 1 or Van 2.');
    for (final line in lines) {
      final qty = moneyRound(line.quantity);
      if (qty <= 0) continue;
      final warehouse = stockAt(StockLocation.warehouse, line.itemId);
      if (warehouse.quantity + 0.001 < qty) {
        throw RbacException(
          s.t(
            'Not enough warehouse stock for ${line.name}. Available ${warehouse.quantity.toStringAsFixed(2)}, requested ${qty.toStringAsFixed(2)}.',
            'مخزون المستودع غير كافٍ لـ ${line.name}. المتاح ${warehouse.quantity.toStringAsFixed(2)} والمطلوب ${qty.toStringAsFixed(2)}.',
          ),
        );
      }
      _move(line.itemId, StockLocation.warehouse, -qty, 'Load ${van.label}');
      _move(line.itemId, van, qty, 'Load ${van.label}');
    }
    final load = VanLoad(
      id: newId(),
      van: van,
      lines: [
        for (final line in lines)
          if (moneyRound(line.quantity) > 0)
            VanLoadLine(
              itemId: line.itemId,
              sku: line.sku,
              name: line.name,
              quantity: moneyRound(line.quantity),
              purchaseCost: moneyRound(line.purchaseCost),
              sellingPrice: moneyRound(line.sellingPrice),
            ),
      ],
    );
    loads = [load, ...loads];
    _audit(action: 'Stock transfer', reference: load.id, amount: load.lines.fold(0.0, (sum, line) => sum + line.quantity), note: 'Load ${van.label}');
    notifyListeners();
    await _commit();
    return load;
  }

  Future<VanLoad> unloadVan({
    required StockLocation van,
    required List<VanLoadLine> lines,
  }) async {
    _requireAdmin();
    if (!van.isVan) throw RbacException('Pick Van 1 or Van 2.');
    for (final line in lines) {
      final qty = moneyRound(line.quantity);
      if (qty <= 0) continue;
      final onVan = stockAt(van, line.itemId);
      if (onVan.quantity + 0.001 < qty) {
        throw RbacException(
          s.t(
            'Not enough ${van.label} stock for ${line.name}. Available ${onVan.quantity.toStringAsFixed(2)}, requested ${qty.toStringAsFixed(2)}.',
            'مخزون ${van.label} غير كافٍ لـ ${line.name}. المتاح ${onVan.quantity.toStringAsFixed(2)} والمطلوب ${qty.toStringAsFixed(2)}.',
          ),
        );
      }
      _move(line.itemId, van, -qty, 'Return ${van.label} to warehouse');
      _move(line.itemId, StockLocation.warehouse, qty, 'Return ${van.label} to warehouse');
    }
    final load = VanLoad(
      id: newId(),
      van: van,
      inbound: false,
      lines: [
        for (final line in lines)
          if (moneyRound(line.quantity) > 0)
            VanLoadLine(
              itemId: line.itemId,
              sku: line.sku,
              name: line.name,
              quantity: moneyRound(line.quantity),
              purchaseCost: moneyRound(line.purchaseCost),
              sellingPrice: moneyRound(line.sellingPrice),
            ),
      ],
    );
    loads = [load, ...loads];
    _audit(action: 'Stock transfer', reference: load.id, amount: load.lines.fold(0.0, (sum, line) => sum + line.quantity), note: 'Unload ${van.label}');
    notifyListeners();
    await _commit();
    return load;
  }

  Future<Invoice> submitInvoice(Invoice draft, {bool deductStock = true}) async {
    _requireWrite();
    final already = invoices.where((row) => row.id == draft.id).toList();
    if (already.isNotEmpty && already.first.submitted) {
      throw RbacException(
        s.t(
          'This invoice is already submitted. Only Admin can edit it.',
          'هذه الفاتورة مرحلة. التعديل للمدير فقط.',
        ),
      );
    }
    if (isSalesman && draft.docType == DocType.creditNote) {
      throw RbacException(
        s.t(
          'Submit a return/damage request. Only Admin can restore warehouse stock.',
          'أرسل طلب مرتجع/تالف. إعادة المخزون للمستودع للمدير فقط.',
        ),
      );
    }
    if (isSalesman && draft.location != session!.sellingLocation) {
      throw RbacException(
        s.t(
          'You can only bill from your assigned van.',
          'يمكنك الفوترة من الفان المخصص لك فقط.',
        ),
      );
    }
    _enforcePriceGuard(draft);
    _enforceCreditLimit(draft);
    var ready = draft.copyWith(
      lines: [
        for (final line in draft.lines)
          line.unitCost > 0
              ? line
              : line.copyWith(
                  unitCost: moneyRound(itemById(line.itemId ?? '')?.cogsPerPiece ?? 0),
                ),
      ],
    );
    _assertInvoiceStock(ready);
    if (ready.customerName.trim().isEmpty) {
      ready = ready.copyWith(customerName: 'Walk-in');
    }
    if (ready.amountPaid > ready.grandTotal + 0.009) {
      ready = ready.copyWith(amountPaid: ready.grandTotal);
    }
    if (ready.invoiceNo.trim().isEmpty ||
        invoices.any((row) => row.id != ready.id && row.invoiceNo == ready.invoiceNo)) {
      ready = ready.copyWith(
        invoiceNo: nextDocNo(invoices, ready.docType, prefix: settings.options.invoicePrefix),
      );
    }
    var stamped = _withZatca(ready);
    if (stamped.docType == DocType.taxInvoice) {
      stamped = stamped.copyWith(
        status: stamped.balanceDue <= 0.05 ? 'delivered' : 'sold',
        paymentMethod: stamped.resolvedPayMethod,
      );
    } else {
      stamped = stamped.copyWith(status: 'returned');
    }
    invoices = [stamped, ...invoices.where((row) => row.id != stamped.id)];
    if (deductStock && stamped.docType == DocType.taxInvoice) {
      for (final line in stamped.lines) {
        final itemId = line.itemId;
        if (itemId == null) continue;
        _move(
          itemId,
          stamped.location,
          -moneyRound(line.stockPieces),
          'Invoice ${stamped.invoiceNo}',
        );
      }
    }
    if (stamped.docType == DocType.creditNote &&
        stamped.returnKind != 'damaged' &&
        stamped.returnKind != 'approved_request') {
      for (final line in stamped.lines) {
        final itemId = line.itemId;
        if (itemId == null) continue;
        _move(
          itemId,
          stamped.location,
          moneyRound(line.stockPieces),
          stamped.returnKind == 'salable'
              ? 'Return salable ${stamped.invoiceNo}'
              : 'Credit ${stamped.invoiceNo}',
        );
      }
    }
    if (stamped.customerId != null && stamped.amountPaid > 0 && stamped.docType == DocType.taxInvoice) {
      payments = [
        LedgerPayment(
          id: newId(),
          customerId: stamped.customerId!,
          amount: stamped.amountPaid,
          method: stamped.resolvedPayMethod == 'credit' ? 'cash' : stamped.resolvedPayMethod,
          invoiceId: stamped.id,
          note: stamped.invoiceNo,
          van: stamped.location.name,
        ),
        ...payments,
      ];
    }
    if (stamped.customerId != null && stamped.docType == DocType.taxInvoice) {
      visits = [
        VisitLog(
          id: newId(),
          customerId: stamped.customerId!,
          van: stamped.location.name,
          outcome: 'sale',
          reason: stamped.invoiceNo,
          lat: stamped.gpsLat,
          lng: stamped.gpsLng,
          invoiceId: stamped.id,
        ),
        ...visits,
      ];
    }
    _audit(
      action: stamped.isCreditNote ? 'Credit note' : 'Sale',
      reference: stamped.invoiceNo,
      amount: stamped.grandTotal,
      note: stamped.location.label,
    );
    await _commit();
    notifyListeners();
    return stamped;
  }

  void _enforcePriceGuard(Invoice draft) {
    if (draft.lines.isEmpty) {
      throw RbacException(
        s.t('Add at least one item.', 'أضف صنفاً واحداً على الأقل.'),
      );
    }
    if (draft.discount < 0 || draft.deliveryCharge < 0 || draft.amountPaid < 0) {
      throw RbacException(
        s.t('Negative amounts are not allowed.', 'المبالغ السالبة غير مسموحة.'),
      );
    }
    if (draft.grandTotal < 0) {
      throw RbacException(
        s.t('Invoice total cannot be negative.', 'لا يمكن أن يكون إجمالي الفاتورة سالباً.'),
      );
    }
    for (final line in draft.lines) {
      if (line.quantity <= 0) {
        throw RbacException(
          s.t('Line quantity must be greater than zero.', 'يجب أن تكون كمية السطر أكبر من صفر.'),
        );
      }
      if (line.unitPrice < 0 || line.lineDiscount < 0) {
        throw RbacException(
          s.t('Negative line amounts are not allowed.', 'مبالغ السطر السالبة غير مسموحة.'),
        );
      }
    }
    if (draft.docType != DocType.taxInvoice) return;
    for (final line in draft.lines) {
      if (line.unitPrice <= 0) continue;
      if (line.itemId == null || line.itemId!.isEmpty) continue;
      final item = itemById(line.itemId!);
      if (item == null) continue;
      final floor = item.costFor(line.billingUnit);
      final netUnit = moneyRound(line.taxable / line.quantity);
      if (netUnit + 0.001 < floor) {
        throw RbacException(
          s.t(
            'Price guard: cannot sell ${item.name} below cost (${sar.format(floor)}).',
            'حماية السعر: لا يمكن بيع ${item.name} بأقل من التكلفة (${sar.format(floor)}).',
          ),
        );
      }
      if (!isSalesman) continue;
      final list = item.saleRateFor(line.billingUnit);
      final promo = matchingPromo(line.stockPieces);
      final allowed = promo == null
          ? list
          : moneyRound(list * (1 - promo.discountPct / 100));
      if ((toHalalas(line.unitPrice) - toHalalas(allowed)).abs() > 1) {
        throw RbacException(
          s.t(
            'Only Admin can change the selling price of ${item.name}.',
            'تغيير سعر بيع ${item.name} للمدير فقط.',
          ),
        );
      }
    }
  }

  void _assertInvoiceStock(Invoice draft) {
    if (draft.docType != DocType.taxInvoice) return;
    final needed = <String, double>{};
    for (final line in draft.lines) {
      final id = line.itemId;
      if (id == null || id.isEmpty) continue;
      needed[id] = moneyRound((needed[id] ?? 0) + line.stockPieces);
    }
    final placeEn = draft.location == StockLocation.warehouse ? 'warehouse' : 'van';
    final placeAr = draft.location == StockLocation.warehouse ? 'المستودع' : 'الفان';
    for (final entry in needed.entries) {
      final available = stockAt(draft.location, entry.key).quantity;
      final item = itemById(entry.key);
      if (available <= 0.001 || entry.value > available + 0.001) {
        throw RbacException(
          s.t(
            available <= 0.001
                ? 'Cannot sell ${item?.name ?? 'item'}: $placeEn stock is 0.'
                : 'Not enough $placeEn stock for ${item?.name ?? 'item'}. Available ${available.toStringAsFixed(2)}, requested ${entry.value.toStringAsFixed(2)}.',
            available <= 0.001
                ? 'لا يمكن بيع ${item?.name ?? 'الصنف'}: مخزون $placeAr صفر.'
                : 'مخزون $placeAr غير كافٍ لـ ${item?.name ?? 'الصنف'}. المتاح ${available.toStringAsFixed(2)} والمطلوب ${entry.value.toStringAsFixed(2)}.',
          ),
        );
      }
    }
  }

  void _enforceCreditLimit(Invoice draft) {
    if (!settings.options.enforceCreditLimit) return;
    final id = draft.customerId;
    if (id == null || draft.docType != DocType.taxInvoice) return;
    final customer = customerById(id);
    if (customer == null || customer.creditLimit <= 0) return;
    final projected = customerDue(id) + draft.grandTotal - draft.amountPaid;
    if (projected > customer.creditLimit + 0.009) {
      throw RbacException(
        s.t(
          'Credit limit exceeded (${sar.format(customer.creditLimit)}). Admin must raise the limit.',
          'تم تجاوز حد الائتمان (${sar.format(customer.creditLimit)}). يرفع المدير الحد فقط.',
        ),
      );
    }
  }

  Future<void> updateInvoice(Invoice invoice) async {
    _requireAdmin();
    final stamped = _withZatca(invoice);
    invoices = [
      for (final row in invoices) row.id == stamped.id ? stamped : row,
    ];
    notifyListeners();
    await _commit();
  }

  Future<void> deleteInvoice(String id) async {
    _requireAdmin();
    Invoice? match;
    for (final row in invoices) {
      if (row.id == id) match = row;
    }
    if (match != null && match.docType == DocType.taxInvoice) {
      for (final line in match.lines) {
        final itemId = line.itemId;
        if (itemId == null || itemId.isEmpty) continue;
        final qty = moneyRound(line.stockPieces);
        if (qty <= 0) continue;
        _move(itemId, match.location, qty, 'Void ${match.invoiceNo}');
      }
    }
    if (match != null) {
      payments = payments.where((p) => p.invoiceId != id).toList();
      _audit(action: 'Void', reference: match.invoiceNo, amount: match.grandTotal);
    }
    invoices = invoices.where((row) => row.id != id).toList();
    notifyListeners();
    await _commit();
  }

  Customer? customerById(String? id) {
    if (id == null) return null;
    for (final c in customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  double customerBilled(String customerId) {
    var total = 0;
    for (final inv in scopedInvoices.where((i) => i.customerId == customerId)) {
      final gross = toHalalas(inv.grandTotal);
      total += inv.isCreditNote ? -gross : gross;
    }
    return fromHalalas(total);
  }

  double customerPaid(String customerId) => fromHalalas(_receiptHalalas(customerId));

  /// Receipts are every payment plus any invoice amount that has no matching payment row.
  int _receiptHalalas(String customerId) {
    final scoped = scopedInvoices.where((i) => i.customerId == customerId).toList();
    final ids = scoped.map((i) => i.id).toSet();
    final vanName = scopedVan?.name;
    final linked = <String, int>{};
    var pay = 0;
    for (final p in payments) {
      if (p.customerId != customerId) continue;
      if (scopedVan != null) {
        final vanOk = p.van == vanName || (p.invoiceId != null && ids.contains(p.invoiceId));
        if (!vanOk) continue;
      }
      pay += toHalalas(p.amount);
      final invoiceId = p.invoiceId;
      if (invoiceId != null) {
        linked[invoiceId] = (linked[invoiceId] ?? 0) + toHalalas(p.amount);
      }
    }
    for (final inv in scoped) {
      if (inv.isCreditNote) continue;
      final gap = toHalalas(inv.amountPaid) - (linked[inv.id] ?? 0);
      if (gap > 0) pay += gap;
    }
    return pay;
  }

  /// What is still collectable on one tax invoice after cash and credit notes.
  double balanceDueOf(Invoice inv) {
    if (inv.isCreditNote) return 0;
    var credits = 0;
    for (final note in invoices) {
      if (!note.isCreditNote || note.originalInvoiceId != inv.id) continue;
      credits += toHalalas(note.grandTotal);
    }
    final due = toHalalas(inv.grandTotal) - toHalalas(inv.amountPaid) - credits;
    return fromHalalas(due < 0 ? 0 : due);
  }

  /// Signed party balance. Positive = You'll Get. Negative = You'll Pay.
  double customerBalance(String customerId) {
    final opening = toHalalas(customerById(customerId)?.openingBalance ?? 0);
    return fromHalalas(opening + toHalalas(customerBilled(customerId)) - _receiptHalalas(customerId));
  }

  double customerDue(String customerId) {
    final balance = customerBalance(customerId);
    return balance > 0 ? balance : 0;
  }

  double customerPayable(String customerId) {
    final balance = customerBalance(customerId);
    return balance < 0 ? moneyRound(-balance) : 0;
  }

  double dozenSizeFor(String itemId) {
    final item = itemById(itemId);
    if (item != null && item.cartonSize >= 2) return item.cartonSize;
    return CatalogItem.dozenPieces;
  }

  double returnedPiecesFor({
    required String invoiceId,
    required String itemId,
    String? excludingRequestId,
  }) {
    var sum = 0.0;
    for (final req in returnRequests) {
      if (req.originalInvoiceId != invoiceId || req.isRejected) continue;
      if (excludingRequestId != null && req.id == excludingRequestId) continue;
      for (final line in req.lines) {
        if (line.itemId == itemId) sum += line.pieces;
      }
    }
    return moneyRound(sum);
  }

  double returnablePieces(Invoice invoice, String itemId) {
    InvoiceLine? sold;
    for (final l in invoice.lines) {
      if (l.itemId == itemId) sold = l;
    }
    final soldPcs = sold?.stockPieces ?? 0;
    final used = returnedPiecesFor(invoiceId: invoice.id, itemId: itemId);
    return moneyRound((soldPcs - used).clamp(0, soldPcs).toDouble());
  }

  Invoice? creditNoteForReturn(StockReturnRequest req) {
    if (req.creditNoteId != null && req.creditNoteId!.isNotEmpty) {
      for (final i in invoices) {
        if (i.id == req.creditNoteId) return i;
      }
    }
    for (final i in invoices) {
      if (!i.isCreditNote) continue;
      if (i.originalInvoiceId == req.originalInvoiceId &&
          (i.notes.contains(req.shortId) || i.notes.contains(req.id))) {
        return i;
      }
    }
    return null;
  }

  List<CustomerLedgerEntry> customerLedger(String customerId) {
    final raw = <({
      DateTime date,
      String invoiceNo,
      String items,
      double billed,
      double received,
      String kind,
      String method,
      String invoiceId,
      String paymentId,
    })>[];
    final linkedIds = scopedInvoices
        .where((i) => i.customerId == customerId)
        .map((i) => i.id)
        .toSet();
    for (final inv in scopedInvoices.where((i) => i.customerId == customerId)) {
      raw.add((
        date: inv.createdAt,
        invoiceNo: inv.invoiceNo,
        items: inv.lines
            .map((l) => '${l.quantity.toStringAsFixed(0)}× ${l.itemName}')
            .join(', '),
        billed: inv.isCreditNote ? -inv.grandTotal : inv.grandTotal,
        received: 0.0,
        kind: inv.isCreditNote ? 'credit' : 'invoice',
        method: inv.paymentMethod == 'credit' ? 'credit' : inv.resolvedPayMethod,
        invoiceId: inv.id,
        paymentId: '',
      ));
    }
    final linkedPaid = <String, int>{};
    for (final p in payments.where((p) => p.customerId == customerId)) {
      if (scopedVan != null) {
        final vanOk = p.van == scopedVan!.name || (p.invoiceId != null && linkedIds.contains(p.invoiceId));
        if (!vanOk) continue;
      }
      final invoiceId = p.invoiceId;
      if (invoiceId != null) {
        linkedPaid[invoiceId] = (linkedPaid[invoiceId] ?? 0) + toHalalas(p.amount);
      }
      final m = p.method.toLowerCase();
      raw.add((
        date: p.createdAt,
        invoiceNo: p.note.trim().isNotEmpty ? p.note.trim() : 'PAY',
        items: '',
        billed: 0.0,
        received: fromHalalas(toHalalas(p.amount)),
        kind: 'payment',
        method: (m == 'bank' || m == 'cheque' || m == 'transfer') ? 'bank' : 'cash',
        invoiceId: p.invoiceId ?? '',
        paymentId: p.id,
      ));
    }
    for (final inv in scopedInvoices.where((i) => i.customerId == customerId && !i.isCreditNote)) {
      final gap = toHalalas(inv.amountPaid) - (linkedPaid[inv.id] ?? 0);
      if (gap <= 0) continue;
      raw.add((
        date: inv.createdAt,
        invoiceNo: inv.invoiceNo,
        items: '',
        billed: 0.0,
        received: fromHalalas(gap),
        kind: 'payment',
        method: 'cash',
        invoiceId: inv.id,
        paymentId: '',
      ));
    }
    raw.sort((a, b) => a.date.compareTo(b.date));
    var run = toHalalas(customerById(customerId)?.openingBalance ?? 0);
    final out = <CustomerLedgerEntry>[];
    for (final row in raw) {
      run += toHalalas(row.billed) - toHalalas(row.received);
      out.add(
        CustomerLedgerEntry(
          date: row.date,
          invoiceNo: row.invoiceNo,
          items: row.items,
          billed: row.billed,
          received: row.received,
          balance: fromHalalas(run),
          kind: row.kind,
          method: row.method,
          invoiceId: row.invoiceId,
          paymentId: row.paymentId,
        ),
      );
    }
    return out.reversed.toList();
  }

  DayCloseSnapshot dayClose({StockLocation? van, DateTime? day}) {
    final scope = isSalesman ? session!.sellingLocation : van;
    final today = day ?? DateTime.now();
    bool sameDay(DateTime d) =>
        d.year == today.year && d.month == today.month && d.day == today.day;
    var creditSales = 0;
    var salesTotal = 0;
    for (final inv in invoices) {
      if (inv.docType != DocType.taxInvoice || !sameDay(inv.createdAt)) continue;
      if (scope != null && inv.location != scope) continue;
      salesTotal += toHalalas(inv.grandTotal);
      creditSales += toHalalas(balanceDueOf(inv));
    }
    final expenses = expensesFor(van: scope, todayOnly: true);
    final StockMetrics stock;
    if (scope == null) {
      final first = stockMetrics(StockLocation.van1);
      final second = stockMetrics(StockLocation.van2);
      stock = StockMetrics(
        quantity: first.quantity + second.quantity,
        purchaseValue: moneyRound(first.purchaseValue + second.purchaseValue),
        sellingValue: moneyRound(first.sellingValue + second.sellingValue),
      );
    } else {
      stock = stockMetrics(scope);
    }
    final drawer = _cashDrawerHalalas(scope, sameDay);
    final bankCollected = collectionsToday(van: scope, method: 'bank', day: today);
    final chequeCollected = collectionsToday(van: scope, method: 'cheque', day: today);
    final expenseHalalas = toHalalas(expenses);
    final net = drawer.cashSales + drawer.creditCollections - expenseHalalas;
    return DayCloseSnapshot(
      van: scope ?? StockLocation.van1,
      salesTotal: fromHalalas(salesTotal),
      cashSales: fromHalalas(drawer.cashSales),
      bankSales: bankCollected,
      chequeCollected: chequeCollected,
      creditSales: fromHalalas(creditSales),
      expenses: expenses,
      vanStockSell: stock.sellingValue,
      vanStockCost: stock.purchaseValue,
      cashCollected: fromHalalas(drawer.cashSales + drawer.creditCollections),
      creditCollections: fromHalalas(drawer.creditCollections),
      netDeposit: fromHalalas(net),
      outstandingDues: scope == null ? totalDues : duesForVan(scope),
    );
  }

  /// Cash sales are today's cash taken on today's invoices.
  /// Credit collections are cash taken today on older invoices or on account.
  ({int cashSales, int creditCollections}) _cashDrawerHalalas(
    StockLocation? van,
    bool Function(DateTime d) sameDay,
  ) {
    var cashSales = 0;
    var creditCollections = 0;
    final counted = <String>{};
    for (final p in payments) {
      if (!sameDay(p.createdAt) || !_sameTender(p.method, 'cash')) continue;
      if (!_paymentOnVan(p, van)) continue;
      Invoice? linked;
      if (p.invoiceId != null) {
        for (final inv in invoices) {
          if (inv.id == p.invoiceId) {
            linked = inv;
            break;
          }
        }
      }
      final sameDaySale = linked != null &&
          linked.docType == DocType.taxInvoice &&
          sameDay(linked.createdAt);
      if (sameDaySale) {
        cashSales += toHalalas(p.amount);
      } else {
        creditCollections += toHalalas(p.amount);
      }
      if (p.invoiceId != null) counted.add(p.invoiceId!);
    }
    for (final inv in invoices) {
      if (inv.docType != DocType.taxInvoice || !sameDay(inv.createdAt)) continue;
      if (van != null && inv.location != van) continue;
      if (inv.amountPaid <= 0 || counted.contains(inv.id)) continue;
      if (inv.resolvedPayMethod != 'cash') continue;
      cashSales += toHalalas(inv.amountPaid);
    }
    return (cashSales: cashSales, creditCollections: creditCollections);
  }

  bool _paymentOnVan(LedgerPayment p, StockLocation? van) {
    if (van == null) return true;
    if (p.van != null && p.van != van.name) return false;
    if (p.van == null || p.invoiceId != null) {
      Invoice? linked;
      if (p.invoiceId != null) {
        for (final inv in invoices) {
          if (inv.id == p.invoiceId) {
            linked = inv;
            break;
          }
        }
      }
      if (p.van == null && (linked == null || linked.location != van)) return false;
      if (linked != null && linked.location != van) return false;
    }
    return true;
  }

  double get totalDues =>
      moneyRound(customers.fold(0.0, (s, c) => s + customerDue(c.id)));

  double get totalPayable =>
      moneyRound(customers.fold(0.0, (s, c) => s + customerPayable(c.id)));

  /// Cash taken on sales and collections, minus cash expenses.
  /// A SAR 1,000 bill with SAR 100 received adds 100 here and leaves 900 outstanding.
  double get cashInHand {
    final van = scopedVan;
    var halalas = 0;
    final covered = <String>{};
    for (final payment in payments) {
      if (van != null && payment.van != null && payment.van != van.name) continue;
      if (!_cashTender(payment.method)) continue;
      halalas += toHalalas(payment.amount);
      final invoiceId = payment.invoiceId;
      if (invoiceId != null && invoiceId.isNotEmpty) covered.add(invoiceId);
    }
    for (final inv in invoices) {
      if (van != null && inv.location != van) continue;
      if (inv.isCreditNote) {
        if (inv.amountPaid > 0.001 && _cashTender(inv.paymentMethod)) {
          halalas -= toHalalas(inv.amountPaid);
        }
        continue;
      }
      if (covered.contains(inv.id) || inv.amountPaid <= 0.001) continue;
      if (!_cashTender(inv.resolvedPayMethod)) continue;
      halalas += toHalalas(inv.amountPaid);
    }
    for (final expense in expenses) {
      if (van != null && expense.van != van.name) continue;
      halalas -= toHalalas(expense.amount);
    }
    return fromHalalas(halalas);
  }

  bool _cashTender(String method) {
    final value = method.trim().toLowerCase();
    return value.isEmpty || value == 'cash';
  }

  double collectionsToday({StockLocation? van, String? method, DateTime? day}) {
    final today = day ?? DateTime.now();
    bool sameDay(DateTime d) =>
        d.year == today.year && d.month == today.month && d.day == today.day;

    var total = 0.0;
    final countedInvoices = <String>{};
    for (final p in payments) {
      if (!sameDay(p.createdAt)) continue;
      if (method != null && !_sameTender(p.method, method)) continue;
      if (van != null) {
        if (p.van != null && p.van != van.name) continue;
        if (p.van == null) {
          Invoice? linked;
          if (p.invoiceId != null) {
            for (final inv in invoices) {
              if (inv.id == p.invoiceId) {
                linked = inv;
                break;
              }
            }
          }
          if (linked == null || linked.location != van) continue;
        }
      }
      if (van != null && p.invoiceId != null && p.van != null) {
        Invoice? match;
        for (final inv in invoices) {
          if (inv.id == p.invoiceId) {
            match = inv;
            break;
          }
        }
        if (match != null && match.location != van) continue;
      }
      total += p.amount;
      if (p.invoiceId != null) countedInvoices.add(p.invoiceId!);
    }
    for (final inv in invoices) {
      if (inv.docType != DocType.taxInvoice) continue;
      if (!sameDay(inv.createdAt) || inv.amountPaid <= 0) continue;
      if (van != null && inv.location != van) continue;
      if (countedInvoices.contains(inv.id)) continue;
      if (method != null && inv.resolvedPayMethod != method) continue;
      total += inv.amountPaid;
    }
    return moneyRound(total);
  }

  bool _sameTender(String stored, String filter) {
    final method = stored.toLowerCase();
    if (filter == 'bank') return method == 'bank' || method == 'transfer';
    return method == filter;
  }

  double duesForVan(StockLocation? van) {
    if (van == null) return totalDues;
    var total = 0;
    for (final inv in invoices) {
      if (inv.location != van) continue;
      total += toHalalas(balanceDueOf(inv));
    }
    return fromHalalas(total);
  }

  Invoice? latestInvoiceFor(String customerId) {
    final list = invoices.where((i) => i.customerId == customerId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.isEmpty ? null : list.first;
  }

  Future<void> recordSettlement(CashSettlement settlement) async {
    _requireWrite();
    settlements = [settlement, ...settlements];
    notifyListeners();
    await _commit();
  }

  Future<void> addVisit(VisitLog visit) async {
    _requireWrite();
    visits = [visit, ...visits];
    notifyListeners();
    await _commit();
  }

  Future<void> markPrinted(String invoiceId) async {
    invoices = [
      for (final row in invoices)
        row.id == invoiceId ? row.copyWith(printCount: row.printCount + 1) : row,
    ];
    notifyListeners();
    await _commit();
  }

  String remainingCreditLabel(Customer customer, {double extra = 0}) {
    if (customer.creditLimit <= 0) return '';
    final left = moneyRound(customer.creditLimit - customerDue(customer.id) - extra);
    return s.t(
      'Credit remaining ${sar.format(left.clamp(0, customer.creditLimit))}',
      'الائتمان المتبقي ${sar.format(left.clamp(0, customer.creditLimit))}',
    );
  }

  double expensesFor({StockLocation? van, bool todayOnly = false}) {
    final today = DateTime.now();
    final raw = expenses.where((e) {
      if (van != null && e.van != van.name) return false;
      if (todayOnly &&
          (e.createdAt.year != today.year ||
              e.createdAt.month != today.month ||
              e.createdAt.day != today.day)) {
        return false;
      }
      return true;
    }).fold(0.0, (s, e) => s + e.amount);
    return moneyRound(raw);
  }

  double cogsFor({bool todayOnly = false, StockLocation? van}) {
    final today = DateTime.now();
    var total = 0;
    for (final inv in invoices) {
      if (inv.docType != DocType.taxInvoice && !inv.isCreditNote) continue;
      if (van != null && inv.location != van) continue;
      if (todayOnly &&
          (inv.createdAt.year != today.year ||
              inv.createdAt.month != today.month ||
              inv.createdAt.day != today.day)) {
        continue;
      }
      final sign = inv.isCreditNote ? -1 : 1;
      for (final line in inv.lines) {
        final item = itemById(line.itemId ?? '');
        final cost = item?.cogsPerPiece ?? (line.unitCost > 0 ? line.unitCost : 0);
        total += sign *
            toHalalas(
              AccountingEngine.lineCogs(
                unitCost: cost,
                pieces: line.stockPieces,
              ),
            );
      }
    }
    return fromHalalas(total);
  }

  ProfitSnapshot profit({bool todayOnly = true}) {
    final van = scopedVan;
    final revenue = moneyRound(salesFor(van, todayOnly: todayOnly) - creditsFor(van, todayOnly: todayOnly));
    final cogs = moneyRound(cogsFor(todayOnly: todayOnly, van: van));
    final exp = moneyRound(expensesFor(van: van, todayOnly: todayOnly));
    final grossProfit = moneyRound(revenue - cogs);
    final commission = grossProfit > 0
        ? moneyRound(grossProfit * (settings.commissionRate / 100))
        : 0.0;
    return ProfitSnapshot(
      revenue: revenue,
      cogs: cogs,
      expenses: exp,
      collections: moneyRound(collectionsToday(van: van)),
      dues: moneyRound(van == null ? totalDues : duesForVan(van)),
      commission: commission,
    );
  }

  double partnerShareOf(double net) {
    final pct = settings.partnerSharePct.clamp(0, 100);
    return moneyRound(net * pct / 100);
  }

  double salesmanCommission(StockLocation van) {
    final revenue = moneyRound(salesFor(van) - creditsFor(van));
    final grossProfit = moneyRound(revenue - cogsFor(van: van));
    if (grossProfit <= 0) return 0;
    return moneyRound(grossProfit * (settings.commissionRate / 100));
  }

  PromoRule? matchingPromo(double pieces) {
    final fits = promos.where((p) => pieces >= p.minPieces).toList()
      ..sort((a, b) => b.minPieces.compareTo(a.minPieces));
    return fits.isEmpty ? null : fits.first;
  }

  Future<void> saveCustomer(Customer customer) async {
    _requireWrite();
    final previous = customerById(customer.id);
    if (previous != null &&
        (previous.creditLimit - customer.creditLimit).abs() > 0.001) {
      _requireAdmin();
    }
    if (previous == null && customer.creditLimit > 0 && !isAdmin) {
      _requireAdmin();
    }
    final exists = customers.any((c) => c.id == customer.id);
    customers = exists
        ? [for (final c in customers) c.id == customer.id ? customer : c]
        : [customer, ...customers];
    notifyListeners();
    await _commit();
  }

  Future<void> addPayment(LedgerPayment payment) async {
    await collectOutstanding(
      customerId: payment.customerId,
      amount: payment.amount,
      method: payment.method,
      note: payment.note,
      invoiceId: payment.invoiceId,
    );
  }

  Future<LedgerPayment> collectOutstanding({
    required String customerId,
    required double amount,
    required String method,
    String note = '',
    String? invoiceId,
  }) async {
    _requireWrite();
    final value = moneyRound(amount);
    if (value <= 0) {
      throw RbacException(s.t('Enter a payment amount.', 'أدخل مبلغ التحصيل.'));
    }
    final cap = invoiceId == null
        ? customerDue(customerId)
        : () {
            Invoice? match;
            for (final inv in scopedInvoices) {
              if (inv.id == invoiceId) match = inv;
            }
            return match == null ? 0.0 : balanceDueOf(match);
          }();
    if (toHalalas(value) > toHalalas(cap)) {
      throw RbacException(
        s.t(
          'Payment exceeds the balance due (${sar.format(cap)}).',
          'المبلغ أكبر من الرصيد المستحق (${sar.format(cap)}).',
        ),
      );
    }
    final targets = scopedInvoices.where((i) {
      if (i.customerId != customerId || i.docType != DocType.taxInvoice) return false;
      if (invoiceId != null && i.id != invoiceId) return false;
      return balanceDueOf(i) > 0;
    }).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final takes = AccountingEngine.allocatePayment(
      [for (final inv in targets) toHalalas(balanceDueOf(inv))],
      toHalalas(value),
    );
    final applied = <String, int>{};
    final created = <LedgerPayment>[];
    for (var i = 0; i < targets.length; i++) {
      if (takes[i] <= 0) continue;
      final inv = targets[i];
      applied[inv.id] = toHalalas(inv.amountPaid) + takes[i];
      created.add(
        LedgerPayment(
          id: newId(),
          customerId: customerId,
          amount: fromHalalas(takes[i]),
          method: method,
          invoiceId: inv.id,
          note: note.trim().isEmpty ? 'Collection' : note.trim(),
          van: scopedVan?.name ?? inv.location.name,
        ),
      );
    }
    final appliedHalalas = takes.fold(0, (sum, take) => sum + take);
    final remainder = toHalalas(value) - appliedHalalas;
    if (remainder > 0) {
      created.add(
        LedgerPayment(
          id: newId(),
          customerId: customerId,
          amount: fromHalalas(remainder),
          method: method,
          note: note.trim().isEmpty ? 'On account' : note.trim(),
          van: scopedVan?.name,
        ),
      );
    }
    if (created.isEmpty) {
      throw RbacException(s.t('Nothing is due on this account.', 'لا يوجد رصيد مستحق على هذا الحساب.'));
    }
    if (applied.isNotEmpty) {
      invoices = [
        for (final row in invoices)
          if (applied.containsKey(row.id))
            row.copyWith(
              amountPaid: fromHalalas(applied[row.id]!),
              status: applied[row.id]! >= toHalalas(row.grandTotal) ? 'delivered' : 'sold',
              paymentMethod: method,
              paymentType: method,
            )
          else
            row,
      ];
    }
    payments = [...created.reversed, ...payments];
    _audit(
      action: 'Payment received',
      reference: created.first.id,
      amount: value,
      note: note.trim(),
    );
    await _commit();
    notifyListeners();
    return created.first;
  }

  Future<StockReturnRequest> submitReturnRequest(StockReturnRequest draft) async {
    _requireWrite();
    if (!draft.van.isVan) {
      throw RbacException(s.t('Pick Van 1 or Van 2.', 'اختر الفان 1 أو 2.'));
    }
    if (isSalesman && draft.van != session!.sellingLocation) {
      throw RbacException(
        s.t('You can only request returns from your van.', 'يمكنك طلب المرتجعات من فانك فقط.'),
      );
    }
    if (draft.lines.isEmpty || draft.lines.every((l) => l.pieces <= 0)) {
      throw RbacException(s.t('Add items and quantities.', 'أضف الأصناف والكميات.'));
    }
    Invoice? linkedInvoice;
    if (draft.originalInvoiceId != null) {
      for (final i in invoices) {
        if (i.id == draft.originalInvoiceId) linkedInvoice = i;
      }
    }
    if (linkedInvoice == null || linkedInvoice.docType != DocType.taxInvoice) {
      throw RbacException(
        s.t('Pick the original sales invoice for this return.', 'اختر فاتورة البيع الأصلية لهذا المرتجع.'),
      );
    }
    if (isSalesman && linkedInvoice.location != draft.van) {
      throw RbacException(
        s.t('That invoice is not from your van.', 'هذه الفاتورة ليست من فانك.'),
      );
    }
    for (final line in draft.lines) {
      if (line.pieces <= 0) continue;
      final maxPcs = returnablePieces(linkedInvoice, line.itemId);
      if (line.pieces > maxPcs + 0.001) {
        throw RbacException(
          s.t(
            '${line.name}: max returnable is ${maxPcs.toStringAsFixed(0)} pcs from invoice ${linkedInvoice.invoiceNo}.',
            '${line.name}: الحد الأقصى للإرجاع ${maxPcs.toStringAsFixed(0)} قطعة من الفاتورة ${linkedInvoice.invoiceNo}.',
          ),
        );
      }
    }
    final ready = StockReturnRequest(
      id: draft.id.isEmpty ? newId() : draft.id,
      van: draft.van,
      kind: draft.kind == 'damaged' ? 'damaged' : 'salable',
      lines: [for (final l in draft.lines) if (l.pieces > 0) l],
      note: draft.note,
      originalInvoiceId: draft.originalInvoiceId,
      originalInvoiceNo: draft.originalInvoiceNo,
      customerId: draft.customerId,
      customerName: draft.customerName,
      requestedBy: session?.label ?? 'salesman',
      status: 'pending',
    );
    returnRequests = [ready, ...returnRequests];
    notifyListeners();
    await _commit();
    return ready;
  }

  Future<void> reviewReturnRequest(String id, {required bool approve, String note = ''}) async {
    _requireAdmin();
    StockReturnRequest? match;
    for (final r in returnRequests) {
      if (r.id == id) match = r;
    }
    if (match == null || !match.isPending) {
      throw RbacException(s.t('Request not found or already reviewed.', 'الطلب غير موجود أو تمت مراجعته.'));
    }
    if (!approve) {
      returnRequests = [
        for (final r in returnRequests)
          r.id == id
              ? r.copyWith(status: 'rejected', reviewNote: note, reviewedAt: DateTime.now())
              : r,
      ];
      notifyListeners();
      await _commit();
      return;
    }
    final invNo = match.originalInvoiceNo ?? match.shortId;
    final marker = 'Return ${match.shortId}';
    if (!movements.any((row) => row.reason.contains(marker))) {
      for (final line in match.lines) {
        final qty = moneyRound(line.pieces);
        if (qty <= 0) continue;
        if (match.isDamaged) {
          _move(
            line.itemId,
            StockLocation.damage,
            qty,
            '$marker #$invNo (damaged)',
          );
        } else {
          _move(
            line.itemId,
            match.van,
            qty,
            '$marker #$invNo',
          );
        }
      }
    }
    Invoice? original;
    for (final inv in invoices) {
      if (inv.id == match.originalInvoiceId) original = inv;
    }
    String? cnId;
    if (match.lines.isNotEmpty) {
      final customer = customerById(match.customerId ?? original?.customerId);
      final cnLines = <InvoiceLine>[];
      for (final line in match.lines) {
        InvoiceLine? sold;
        if (original != null) {
          for (final l in original.lines) {
            if (l.itemId == line.itemId) sold = l;
          }
        }
        if (sold != null) {
          final perUnit = sold.quantity.abs() < 0.001 ? 1.0 : sold.stockPieces / sold.quantity;
          final cnQty = moneyRound(line.pieces / perUnit);
          final qty = cnQty <= 0 ? line.pieces : cnQty;
          final fullLine = (qty - sold.quantity).abs() < 0.001;
          final lineDiscount = fullLine
              ? sold.lineDiscount
              : moneyRound(sold.lineDiscount * qty / (sold.quantity == 0 ? 1 : sold.quantity));
          cnLines.add(
            InvoiceLine(
              id: newId(),
              itemId: line.itemId,
              itemName: line.name,
              sku: line.sku,
              quantity: qty,
              unitPrice: sold.unitPrice,
              taxRate: sold.taxRate,
              billingUnit: sold.billingUnit,
              pieces: line.pieces,
              unitCost: sold.unitCost,
              lineDiscount: lineDiscount,
              taxInclusive: sold.taxInclusive,
            ),
          );
        } else {
          cnLines.add(
            InvoiceLine(
              id: newId(),
              itemId: line.itemId,
              itemName: line.name,
              sku: line.sku,
              quantity: line.qty > 0 ? line.qty : line.pieces,
              unitPrice: line.unitPrice,
              taxRate: line.taxRate > 0 ? line.taxRate : settings.options.effectiveVat,
              billingUnit: BillingUnitX.parse(line.unit == 'dozen' ? 'dozen' : line.unit),
              pieces: line.pieces,
              unitCost: line.unitCost,
              taxInclusive: line.taxInclusive,
            ),
          );
        }
      }
      final cn = await submitInvoice(
        Invoice(
          id: newId(),
          invoiceNo: '',
          docType: DocType.creditNote,
          customerName: match.customerName.isNotEmpty ? match.customerName : (customer?.name ?? 'Customer'),
          customerPhone: customer?.phone ?? '',
          customerTrn: customer?.vatNumber ?? '',
          notes: match.note.trim().isEmpty
              ? 'Sales return ${match.shortId} · Invoice #$invNo'
              : '${match.note.trim()} · Invoice #$invNo',
          discount: 0,
          status: 'returned',
          lines: cnLines,
          location: match.van,
          sellerName: settings.zatcaSellerName,
          vatTrn: settings.vatTrn,
          crNumber: settings.crNumber,
          zatcaQr: '',
          originalInvoiceId: match.originalInvoiceId,
          originalInvoiceNo: match.originalInvoiceNo,
          submitted: false,
          customerId: match.customerId ?? original?.customerId,
          shopName: customer?.shopName ?? '',
          buyerCr: customer?.crNumber ?? '',
          taxPercent: original?.taxPercent ?? settings.options.effectiveVat,
          taxInclusive: cnLines.every((l) => l.taxInclusive),
          returnKind: match.isDamaged ? 'damaged' : 'approved_request',
          paymentMethod: 'credit',
          paymentType: 'credit',
        ),
        deductStock: false,
      );
      cnId = cn.id;
      final cid = cn.customerId;
      if (cid != null && cid.isNotEmpty) {
        final due = customerDue(cid);
        invoices = [
          for (final i in invoices)
            i.id == cn.id ? i.copyWith(outstandingAfter: due) : i,
        ];
      }
    }
    returnRequests = [
      for (final r in returnRequests)
        r.id == id
            ? r.copyWith(
                status: 'approved',
                reviewNote: note,
                reviewedAt: DateTime.now(),
                creditNoteId: cnId,
              )
            : r,
    ];
    _audit(
      action: 'Return',
      reference: match.originalInvoiceNo ?? match.shortId,
      amount: match.lines.fold(0.0, (sum, line) => sum + line.pieces),
      note: match.isDamaged ? 'damaged' : 'salable',
    );
    notifyListeners();
    await _commit();
  }

  /// Admin-only wipe of operational data. Catalog, settings, and party records stay.
  Future<void> factoryResetTransactions({required String pin}) async {
    _requireAdmin();
    final p = pin.trim();
    if (p.isEmpty || (!unlockAdmin(p) && !unlockMasterAdmin(p))) {
      throw RbacException(
        s.t('Incorrect Admin PIN.', 'رمز المدير غير صحيح.'),
      );
    }
    invoices = [];
    payments = [];
    expenses = [];
    settlements = [];
    visits = [];
    returnRequests = [];
    loads = [];
    movements = [];
    daybook = [];
    inventory = {
      for (final row in inventory.values)
        row.key: row.copyWith(quantity: 0, updatedAt: DateTime.now()),
    };
    customers = [
      for (final c in customers) c.copyWith(openingBalance: 0),
    ];
    notifyListeners();
    await _commit();
  }

  Future<void> addExpense(VanExpense expense) async {
    _requireWrite();
    final amount = moneyRound(expense.amount);
    if (amount <= 0) {
      throw RbacException(s.t('Enter an expense amount.', 'أدخل مبلغ المصروف.'));
    }
    final vanName = isSalesman ? session!.sellingLocation.name : expense.van;
    if (vanName != StockLocation.van1.name && vanName != StockLocation.van2.name) {
      throw RbacException(s.t('Pick Van 1 or Van 2.', 'اختر الفان 1 أو 2.'));
    }
    expenses = [
      VanExpense(
        id: expense.id,
        van: vanName,
        category: expense.category,
        amount: amount,
        note: expense.note,
        createdAt: expense.createdAt,
      ),
      ...expenses,
    ];
    _audit(action: 'Expense', reference: expense.id, amount: amount, note: expense.category);
    await _commit();
    notifyListeners();
  }

  Future<void> savePromo(PromoRule rule) async {
    _requireAdmin();
    final exists = promos.any((p) => p.id == rule.id);
    promos = exists
        ? [for (final p in promos) p.id == rule.id ? rule : p]
        : [...promos, rule];
    notifyListeners();
    await _commit();
  }

  Future<void> saveSettings(ShopSettings value) async {
    _requireAdmin();
    settings = value.normalized();
    if (value.options.language.isNotEmpty) localeCode = value.options.language;
    notifyListeners();
    await repository.writeLocale(localeCode);
    await _commit();
    await _revokeStaleSession();
    notifyListeners();
  }

  Future<void> patchOptions(AppOptions Function(AppOptions current) fn) async {
    final next = fn(settings.options);
    if (!isAdmin) {
      settings = settings.copyWith(
        options: settings.options.copyWith(
          darkTheme: next.darkTheme,
          language: next.language,
        ),
      );
      localeCode = next.language;
      notifyListeners();
      await repository.writeLocale(localeCode);
      await _commit();
      return;
    }
    settings = settings.copyWith(options: next);
    if (next.language.isNotEmpty) localeCode = next.language;
    notifyListeners();
    await repository.writeLocale(localeCode);
    await _commit();
  }

  Future<void> backupNow() async {
    _requireAdmin();
    final stamp = DateTime.now().toIso8601String();
    settings = settings.copyWith(options: settings.options.copyWith(lastBackupAt: stamp));
    notifyListeners();
    await _commit();
  }
}
