import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/shop_settings.dart';
import '../theme/app_theme.dart';
import '../utils/route_safety.dart';
import '../widgets/company_header.dart';
import '../widgets/signature_pad.dart';
import '../widgets/vyapar.dart';
import 'shell.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  late final TextEditingController nameEn;
  late final TextEditingController nameAr;
  late final TextEditingController phone1;
  late final TextEditingController phone2;
  late final TextEditingController email;
  late final TextEditingController building;
  late final TextEditingController zip;
  late final TextEditingController city;
  late final TextEditingController country;
  late final TextEditingController pincode;
  late final TextEditingController street;
  late final TextEditingController description;
  late final TextEditingController trn;
  late final TextEditingController cr;
  String businessType = 'wholesale';
  String businessCategory = 'General Trading';
  DateTime? booksBeginning;
  String logoBase64 = '';
  String signatureBase64 = '';
  bool loaded = false;
  bool saving = false;

  static const _categories = [
    'General Trading',
    'Wholesale',
    'Retail',
    'Apparel',
    'Footwear',
    'Perfume',
    'FMCG',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loaded) return;
    final s = AppScope.of(context).settings;
    nameEn = TextEditingController(text: s.shopName);
    nameAr = TextEditingController(text: s.shopNameAr);
    phone1 = TextEditingController(text: s.phone);
    phone2 = TextEditingController(text: s.phone2);
    email = TextEditingController(text: s.email);
    building = TextEditingController(text: s.buildingNo);
    zip = TextEditingController(text: s.zipCode);
    city = TextEditingController(text: s.city);
    country = TextEditingController(text: s.country);
    pincode = TextEditingController(text: s.pincode);
    street = TextEditingController(text: s.streetLine);
    description = TextEditingController(text: s.businessDescription);
    trn = TextEditingController(text: s.vatTrn);
    cr = TextEditingController(text: s.crNumber);
    businessType = s.businessType == 'retail' ? 'retail' : 'wholesale';
    businessCategory = _categories.contains(s.businessCategory) ? s.businessCategory : 'General Trading';
    booksBeginning = DateTime.tryParse(s.booksBeginning);
    logoBase64 = s.logoBase64;
    signatureBase64 = s.signatureBase64;
    loaded = true;
  }

  @override
  void dispose() {
    tabs.dispose();
    nameEn.dispose();
    nameAr.dispose();
    phone1.dispose();
    phone2.dispose();
    email.dispose();
    building.dispose();
    zip.dispose();
    city.dispose();
    country.dispose();
    pincode.dispose();
    street.dispose();
    description.dispose();
    trn.dispose();
    cr.dispose();
    super.dispose();
  }

  ShopSettings get draft {
    final base = AppScope.of(context).settings;
    final composed = ShopSettings(
      shopName: nameEn.text.trim(),
      shopNameAr: nameAr.text.trim(),
      address: street.text.trim(),
      phone: phone1.text.trim(),
      phone2: phone2.text.trim(),
      email: email.text.trim(),
      vatTrn: trn.text.trim(),
      crNumber: cr.text.trim(),
      iban: base.iban,
      footerNote: base.footerNote,
      paper: base.paper,
      adminPin: base.adminPin,
      vatRate: base.vatRate,
      partnerPin: base.partnerPin,
      van1Pin: base.van1Pin,
      van2Pin: base.van2Pin,
      masterAdminPin: base.masterAdminPin,
      commissionRate: base.commissionRate,
      partnerSharePct: base.partnerSharePct,
      printerName: base.printerName,
      printerMac: base.printerMac,
      autoPrint: base.autoPrint,
      buildingNo: building.text.trim(),
      zipCode: zip.text.trim(),
      city: city.text.trim(),
      country: country.text.trim(),
      pincode: pincode.text.trim(),
      businessDescription: description.text.trim(),
      businessType: businessType,
      businessCategory: businessCategory,
      booksBeginning: booksBeginning == null ? '' : DateFormat('yyyy-MM-dd').format(booksBeginning!),
      logoBase64: logoBase64,
      signatureBase64: signatureBase64,
      options: base.options,
    );
    return composed.normalized();
  }

  Future<void> _pickImage({required bool logo}) async {
    if (!AppScope.of(context).isAdmin) return;
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
        imageQuality: 78,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        if (logo) {
          logoBase64 = base64Encode(bytes);
        } else {
          signatureBase64 = base64Encode(bytes);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _captureSignature() async {
    if (!AppScope.of(context).isAdmin) return;
    final data = await SignaturePadDialog.capture(context);
    if (data == null || data.isEmpty) return;
    setState(() => signatureBase64 = data);
  }

  Future<void> _save() async {
    final billing = AppScope.of(context);
    if (!billing.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(billing.s.t('Admin can edit the business profile.', 'المدير يعدّل ملف المنشأة.'))),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await billing.saveSettings(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(billing.s.t('Business profile saved.', 'تم حفظ ملف المنشأة.'))),
      );
      popAfterFrame(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final locked = !billing.isAdmin;
    final pct = draft.profileCompletion;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: Text(s.t('Business Profile', 'ملف المنشأة')),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                GestureDetector(
                  onTap: locked ? null : () => _pickImage(logo: true),
                  child: CompanyLogoAvatar(settings: draft, radius: 48),
                ),
                if (!locked)
                  Material(
                    color: AppTheme.navy,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _pickImage(logo: true),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: pct >= 100 ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                pct >= 100
                    ? s.t('Profile 100% Completed', 'اكتمل الملف 100٪')
                    : s.t('Profile $pct% completed', 'اكتمال الملف $pct٪'),
                style: TextStyle(
                  color: pct >= 100 ? const Color(0xFF2E7D32) : const Color(0xFFB45309),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          TabBar(
            controller: tabs,
            labelColor: AppTheme.navy,
            indicatorColor: AppTheme.fabRed,
            tabs: [
              Tab(text: s.t('Basic Details', 'البيانات الأساسية')),
              Tab(text: s.t('Business Details', 'بيانات المنشأة')),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: tabs,
              children: [
                _basicTab(s, locked),
                _businessTab(s, locked),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(s.t('Cancel', 'إلغاء')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: saving ? null : _save,
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.fabRed),
                        child: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                s.t('Save', 'حفظ'),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _basicTab(dynamic s, bool locked) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        UkCard(
          child: Column(
            children: [
              _field(nameEn, s.t('Business Name (English)', 'اسم المنشأة (إنجليزي)'), locked),
              const SizedBox(height: 10),
              _field(nameAr, s.t('Business Name (Arabic)', 'اسم المنشأة (عربي)'), locked, arabic: true),
              const SizedBox(height: 10),
              _field(phone1, s.t('Phone Number 1', 'هاتف 1'), locked, keyboard: TextInputType.phone),
              const SizedBox(height: 10),
              _field(phone2, s.t('Phone Number 2', 'هاتف 2'), locked, keyboard: TextInputType.phone),
              const SizedBox(height: 10),
              _field(email, s.t('Email ID', 'البريد الإلكتروني'), locked, keyboard: TextInputType.emailAddress),
            ],
          ),
        ),
        UkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t('Business Address', 'عنوان المنشأة'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              _field(building, s.t('Building No', 'رقم المبنى'), locked),
              const SizedBox(height: 10),
              _field(street, s.t('Street / Address line', 'الشارع / العنوان'), locked),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _field(zip, s.t('Zip Code', 'الرمز البريدي'), locked)),
                  const SizedBox(width: 8),
                  Expanded(child: _field(pincode, s.t('Pincode', 'الرمز'), locked)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _field(city, s.t('City', 'المدينة'), locked)),
                  const SizedBox(width: 8),
                  Expanded(child: _field(country, s.t('Country', 'الدولة'), locked)),
                ],
              ),
            ],
          ),
        ),
        UkCard(
          child: Column(
            children: [
              _field(
                description,
                s.t('Business description', 'وصف المنشأة'),
                locked,
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              _field(cr, s.t('CR Number', 'السجل التجاري'), locked),
            ],
          ),
        ),
        _signatureCard(s, locked),
      ],
    );
  }

  Widget _businessTab(dynamic s, bool locked) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        UkCard(
          child: Column(
            children: [
              _field(trn, s.t('TRN / VAT Number', 'الرقم الضريبي'), locked),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: businessType,
                decoration: InputDecoration(labelText: s.t('Business Type', 'نوع النشاط')),
                items: [
                  DropdownMenuItem(value: 'wholesale', child: Text(s.t('Wholesale', 'جملة'))),
                  DropdownMenuItem(value: 'retail', child: Text(s.t('Retail', 'تجزئة'))),
                ],
                onChanged: locked ? null : (v) => setState(() => businessType = v ?? 'wholesale'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: businessCategory,
                decoration: InputDecoration(labelText: s.t('Business Category', 'فئة النشاط')),
                items: [
                  for (final c in _categories) DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: locked ? null : (v) => setState(() => businessCategory = v ?? 'General Trading'),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.t('Books Beginning Date', 'تاريخ بداية الدفاتر')),
                subtitle: Text(
                  booksBeginning == null
                      ? s.t('Select date', 'اختر التاريخ')
                      : DateFormat('dd MMM yyyy').format(booksBeginning!),
                ),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: locked
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: booksBeginning ?? DateTime(2026, 1, 1),
                          firstDate: DateTime(2015),
                          lastDate: DateTime(2040),
                        );
                        if (picked != null) setState(() => booksBeginning = picked);
                      },
              ),
            ],
          ),
        ),
        _signatureCard(s, locked),
      ],
    );
  }

  Widget _signatureCard(dynamic s, bool locked) {
    final image = signatureImageProvider(signatureBase64);
    return UkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t('Signature', 'التوقيع'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: image == null
                ? Text(
                    s.t('No signature', 'لا يوجد توقيع'),
                    style: const TextStyle(color: Color(0xFF94A3B8)),
                  )
                : Image(image: image, fit: BoxFit.contain),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: locked ? null : _captureSignature,
                child: Text(s.t('Change', 'تغيير')),
              ),
              OutlinedButton(
                onPressed: locked ? null : () => _pickImage(logo: false),
                child: Text(s.t('Upload', 'رفع')),
              ),
              TextButton(
                onPressed: locked ? null : () => setState(() => signatureBase64 = ''),
                child: Text(s.t('Remove', 'حذف'), style: const TextStyle(color: AppTheme.fabRed)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    bool locked, {
    TextInputType? keyboard,
    int maxLines = 1,
    bool arabic = false,
  }) {
    return TextField(
      controller: controller,
      enabled: !locked,
      maxLines: maxLines,
      keyboardType: keyboard,
      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: label),
    );
  }
}
