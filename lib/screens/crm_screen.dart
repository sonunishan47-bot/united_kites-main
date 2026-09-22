import 'dart:async';

import 'package:flutter/material.dart';

import '../models/crm.dart';
import '../services/map_customers.dart';
import '../services/maps_link.dart';
import '../services/whatsapp_share.dart';
import '../state/billing_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/search_text.dart';
import '../utils/route_safety.dart';
import '../widgets/collect_payment_sheet.dart';
import '../widgets/common.dart';
import '../widgets/customer_location_section.dart';
import '../widgets/shop_photo_picker.dart';
import '../widgets/vyapar.dart';
import 'customer_ledger_screen.dart';
import 'invoice_editor_screen.dart';
import 'shell.dart';

class CrmScreen extends StatefulWidget {
  const CrmScreen({super.key});

  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final filtered = billing.customers.where((c) {
      return matchesSearch(query, [
        c.name,
        c.phone,
        c.shopName,
        c.crNumber,
        c.vatNumber,
        c.address,
      ]);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      floatingActionButton: billing.isPartner
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppTheme.fabRed,
              onPressed: () => _editCustomer(context, billing),
              icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
              label: Text(
                s.t('Add party', 'إضافة عميل'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                hintText: s.t('Search party or phone...', 'بحث بالاسم أو الجوال...'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? EmptyHint(
                    icon: Icons.people_outline,
                    message: s.t('No parties found.', 'لا يوجد عملاء.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final customer = filtered[index];
                      final due = billing.customerDue(customer.id);
                      return UkCard(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        onTap: () => _showCustomerDetails(
                          context,
                          customer,
                          billing,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.display,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    customer.phone.isNotEmpty
                                        ? customer.phone
                                        : s.t('No phone number', 'لا يوجد جوال'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                StatusBadge(
                                  label: due > 0 ? s.due : s.paid,
                                  tone: due > 0 ? BadgeTone.due : BadgeTone.paid,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  sar.format(due),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: due > 0
                                        ? AppTheme.fabRed
                                        : const Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showCustomerDetails(
    BuildContext context,
    Customer customer,
    BillingController billing,
  ) {
    final s = billing.s;
    final due = billing.customerDue(customer.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    customer.display,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!billing.isPartner)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      Navigator.pop(context);
                      _editCustomer(context, billing, existing: customer);
                    },
                  ),
              ],
            ),
            const Divider(height: 16),
            if (!billing.isPartner) ...[
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
                    child: FilledButton.icon(
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
              const SizedBox(height: 8),
            ],
            if (customer.phone.isNotEmpty)
              Text('${s.t('Phone', 'الجوال')}: ${customer.phone}'),
            if (customer.crNumber.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('${s.t('CR number', 'السجل التجاري')}: ${customer.crNumber}'),
            ],
            if (customer.vatNumber.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('${s.t('VAT number', 'الرقم الضريبي')}: ${customer.vatNumber}'),
            ],
            if (customer.address.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('${s.t('Address', 'العنوان')}: ${customer.address}'),
            ],
            if (customer.hasGps && billing.canAccessMaps) ...[
              const SizedBox(height: 6),
              Text('GPS: ${customer.lat.toStringAsFixed(4)}, ${customer.lng.toStringAsFixed(4)}'),
            ],
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(s.t('Customer ledger', 'كشف حساب العميل')),
              subtitle: Text(s.t('Invoices, items, payments, balance', 'فواتير وأصناف ودفعات ورصيد')),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CustomerLedgerScreen(customerId: customer.id),
                  ),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.t('Due', 'المستحق')),
              trailing: MoneyText(due),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.t('Credit limit', 'حد الائتمان')),
              trailing: Text(
                customer.creditLimit <= 0
                    ? s.t('No limit', 'بدون حد')
                    : sar.format(customer.creditLimit),
              ),
            ),
            if (!billing.isPartner)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.payments_outlined),
                title: Text(s.t('Receive Payment', 'استلام دفعة')),
                subtitle: Text(s.t('Collect outstanding without a new bill', 'تحصيل المديونية بدون فاتورة جديدة')),
                onTap: () async {
                  final host = Navigator.of(context).context;
                  Navigator.pop(context);
                  await Future<void>.delayed(Duration.zero);
                  if (!host.mounted) return;
                  await CollectPaymentSheet.open(host, billing: billing, customer: customer);
                },
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.chat),
              title: Text(s.t('WhatsApp credit alert', 'تنبيه واتساب')),
              onTap: () async {
                Navigator.pop(context);
                await const WhatsAppShare().creditAlert(
                  customer: customer,
                  due: due,
                  arabic: s.isAr,
                  statement: billing.latestInvoiceFor(customer.id),
                  settings: billing.settings,
                );
              },
            ),
            if (customer.hasGps && billing.canAccessMaps)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.map_outlined),
                title: Text(s.t('Google Maps shop', 'موقع المحل')),
                onTap: () => const WhatsAppShare().openMaps(customer),
              ),
            ...billing.payments
                .where((p) => p.customerId == customer.id)
                .take(6)
                .map(
                  (p) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${p.method} · ${sar.format(p.amount)}'),
                    subtitle: Text(dayTime.format(p.createdAt)),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCustomer(
    BuildContext context,
    BillingController billing, {
    Customer? existing,
  }) {
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final shop = TextEditingController(text: existing?.shopName ?? '');
    final cr = TextEditingController(text: existing?.crNumber ?? '');
    final vat = TextEditingController(text: existing?.vatNumber ?? '');
    final limit = TextEditingController(
      text: existing == null ? '0' : existing.creditLimit.toStringAsFixed(0),
    );
    final lat = TextEditingController(
      text: existing == null ? '24.7136' : existing.lat.toString(),
    );
    final lng = TextEditingController(
      text: existing == null ? '46.6753' : existing.lng.toString(),
    );
    final address = TextEditingController(text: existing?.address ?? '');
    final coordInput = TextEditingController(
      text: existing == null
          ? '24.713600, 46.675300'
          : '${existing.lat}, ${existing.lng}',
    );
    var shopPhoto = existing?.shopPhotoBase64 ?? '';
    var saving = false;
    String? formError;
    final customerId = existing?.id ?? newId();
    final messenger = ScaffoldMessenger.of(context);

    Future<void> submit(BuildContext sheetContext, StateSetter setLocal) async {
      if (saving) return;
      saving = true;
      setLocal(() => formError = null);
      final shopName = shop.text.trim();
      final contact = name.text.trim();
      if (shopName.isEmpty && contact.isEmpty) {
        setLocal(() {
          saving = false;
          formError = billing.s.t(
            'Enter a shop name or contact name.',
            'أدخل اسم المحل أو اسم المسؤول.',
          );
        });
        return;
      }
      if (isShortMapsLink(coordInput.text)) {
        final expanded = await expandMapsUrl(coordInput.text.trim());
        if (!saving) return;
        final parsed = expanded == null ? null : parseShopCoordinates(expanded);
        if (parsed != null) {
          lat.text = parsed.lat.toStringAsFixed(6);
          lng.text = parsed.lng.toStringAsFixed(6);
          if (address.text.trim().isEmpty && (parsed.address ?? '').isNotEmpty) {
            address.text = parsed.address!;
          }
          coordInput.text = '${lat.text}, ${lng.text}';
        }
      }
      final point = resolveShopPoint(
        manual: coordInput.text,
        latText: lat.text,
        lngText: lng.text,
      );
      final manual = coordInput.text.trim().toLowerCase();
      if (point == null && (manual.contains('://') || manual.contains('goo.gl') || manual.contains('+'))) {
        setLocal(() {
          saving = false;
          formError = billing.s.t(
            'Could not read a location from that link. Paste the full Google Maps URL, or select the shop on the map.',
            'تعذر قراءة الموقع من الرابط. الصق رابط خرائط كاملاً أو حدّد المحل على الخريطة.',
          );
        });
        return;
      }
      final party = Customer(
        id: customerId,
        name: contact.isEmpty ? shopName : contact,
        phone: phone.text.trim(),
        shopName: shopName.isEmpty ? contact : shopName,
        crNumber: cr.text.trim(),
        vatNumber: vat.text.trim(),
        lat: point?.lat ?? double.tryParse(lat.text) ?? 0,
        lng: point?.lng ?? double.tryParse(lng.text) ?? 0,
        address: address.text.trim().isNotEmpty
            ? address.text.trim()
            : (point?.address ?? '').trim(),
        creditLimit: billing.canChangeCreditLimits
            ? (double.tryParse(limit.text) ?? existing?.creditLimit ?? 0)
            : (existing?.creditLimit ?? 0),
        openingBalance: existing?.openingBalance ?? 0,
        shopPhotoBase64: shopPhoto,
      );
      try {
        await billing.saveCustomer(party).timeout(const Duration(seconds: 20));
      } on RbacException catch (e) {
        if (sheetContext.mounted) {
          setLocal(() {
            saving = false;
            formError = e.message;
          });
        }
        return;
      } on TimeoutException {
        if (billing.customerById(party.id) == null) {
          if (sheetContext.mounted) {
            setLocal(() {
              saving = false;
              formError = billing.s.t(
                'Saving took too long. Check the connection and try again.',
                'استغرق الحفظ وقتاً طويلاً. تحقق من الاتصال ثم أعد المحاولة.',
              );
            });
          }
          return;
        }
      } catch (_) {
        if (sheetContext.mounted) {
          setLocal(() {
            saving = false;
            formError = billing.s.t(
              'Could not save this customer. Try again.',
              'تعذر حفظ العميل. حاول مرة أخرى.',
            );
          });
        }
        return;
      }
      if (!sheetContext.mounted) return;
      popAfterFrame(sheetContext);
      messenger.showSnackBar(
        SnackBar(
          content: Text(billing.s.t('Customer saved successfully!', 'تم حفظ العميل بنجاح!')),
        ),
      );
    }

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
            left: 16,
            right: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setLocal) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                TextField(
                  controller: shop,
                  decoration: InputDecoration(
                    labelText: billing.s.t('Shop name', 'اسم المحل'),
                  ),
                ),
                TextField(
                  controller: name,
                  decoration: InputDecoration(
                    labelText: billing.s.t('Contact name', 'اسم المسؤول'),
                  ),
                ),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: billing.s.t('WhatsApp phone', 'جوال واتساب'),
                  ),
                ),
                TextField(
                  controller: cr,
                  decoration: const InputDecoration(labelText: 'CR'),
                ),
                TextField(
                  controller: vat,
                  decoration: InputDecoration(
                    labelText: billing.s.t('VAT TRN', 'الرقم الضريبي'),
                  ),
                ),
                if (billing.canChangeCreditLimits)
                  TextField(
                    controller: limit,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: billing.s.t('Credit limit (SAR)', 'حد الائتمان (ر.س)'),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      billing.s.t(
                        'Credit limit is Admin-only.',
                        'حد الائتمان يُعدّل من حساب المدير فقط.',
                      ),
                    ),
                  ),
                TextField(
                  controller: address,
                  decoration: InputDecoration(
                    labelText: billing.s.t('Address', 'العنوان'),
                  ),
                ),
                CustomerLocationSection(
                  lat: lat,
                  lng: lng,
                  coordInput: coordInput,
                  address: address,
                  onChanged: () => setLocal(() {}),
                ),
                const SizedBox(height: 12),
                ShopPhotoPicker(
                  photoBase64: shopPhoto,
                  onChanged: (value) => setLocal(() => shopPhoto = value),
                ),
                if (formError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      formError!,
                      style: const TextStyle(color: AppTheme.fabRed, fontWeight: FontWeight.w700),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: saving ? null : () => submit(context, setLocal),
                  child: saving
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            SizedBox(width: 10),
                            Text('Saving...'),
                          ],
                        )
                      : Text(billing.s.t('Save customer', 'حفظ العميل')),
                ),
                const SizedBox(height: 16),
              ],
            ),
              );
            },
          ),
        );
      },
    );
  }
}
