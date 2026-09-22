import '../utils/formatters.dart';

class AppOptions {
  AppOptions({
    this.language = 'en',
    this.darkTheme = false,
    this.lockEnabled = false,
    this.lockPin = '',
    this.biometricEnabled = false,
    this.backupTarget = 'local',
    this.lastBackupAt = '',
    this.financialYearStart = '2026-01-01',
    this.invoicePrefix = 'INV',
    this.autoInvoiceNo = true,
    this.printTime = true,
    this.roundOff = false,
    this.itemDiscount = true,
    this.billDiscount = true,
    this.deliveryCharges = false,
    this.posMode = false,
    this.showLogo = true,
    this.showFooter = true,
    this.showTerms = false,
    this.showBank = true,
    this.showSignature = true,
    this.termsText = 'Goods once sold will not be taken back.',
    this.bankDetails = '',
    this.vatEnabled = true,
    this.vatPercent = 15,
    this.priceInclusive = false,
    this.showTrnCr = true,
    this.autoWhatsApp = false,
    this.whatsappTemplate =
        'Dear {Customer_Name}, invoice {Invoice_No} total {Bill_Amount}. Thank you.',
    this.paymentReminders = true,
    this.reminderDays = 7,
    this.enforceCreditLimit = true,
    this.showOutstandingOnBill = true,
    this.itemCategories = true,
    this.lowStockThreshold = 5,
    this.batchExpiry = false,
    this.barcodeEnabled = true,
    this.multiPricing = true,
    this.baseCurrency = 'SAR',
    this.multiCurrency = false,
    this.exchangeRate = 1,
    this.quoteCurrency = 'USD',
  });

  final String language;
  final bool darkTheme;
  final bool lockEnabled;
  final String lockPin;
  final bool biometricEnabled;
  final String backupTarget;
  final String lastBackupAt;
  final String financialYearStart;
  final String invoicePrefix;
  final bool autoInvoiceNo;
  final bool printTime;
  final bool roundOff;
  final bool itemDiscount;
  final bool billDiscount;
  final bool deliveryCharges;
  final bool posMode;
  final bool showLogo;
  final bool showFooter;
  final bool showTerms;
  final bool showBank;
  final bool showSignature;
  final String termsText;
  final String bankDetails;
  final bool vatEnabled;
  final double vatPercent;
  final bool priceInclusive;
  final bool showTrnCr;
  final bool autoWhatsApp;
  final String whatsappTemplate;
  final bool paymentReminders;
  final int reminderDays;
  final bool enforceCreditLimit;
  final bool showOutstandingOnBill;
  final bool itemCategories;
  final double lowStockThreshold;
  final bool batchExpiry;
  final bool barcodeEnabled;
  final bool multiPricing;
  final String baseCurrency;
  final bool multiCurrency;
  final double exchangeRate;
  final String quoteCurrency;

  double get effectiveVat => vatEnabled ? vatPercent : 0;

  AppOptions copyWith({
    String? language,
    bool? darkTheme,
    bool? lockEnabled,
    String? lockPin,
    bool? biometricEnabled,
    String? backupTarget,
    String? lastBackupAt,
    String? financialYearStart,
    String? invoicePrefix,
    bool? autoInvoiceNo,
    bool? printTime,
    bool? roundOff,
    bool? itemDiscount,
    bool? billDiscount,
    bool? deliveryCharges,
    bool? posMode,
    bool? showLogo,
    bool? showFooter,
    bool? showTerms,
    bool? showBank,
    bool? showSignature,
    String? termsText,
    String? bankDetails,
    bool? vatEnabled,
    double? vatPercent,
    bool? priceInclusive,
    bool? showTrnCr,
    bool? autoWhatsApp,
    String? whatsappTemplate,
    bool? paymentReminders,
    int? reminderDays,
    bool? enforceCreditLimit,
    bool? showOutstandingOnBill,
    bool? itemCategories,
    double? lowStockThreshold,
    bool? batchExpiry,
    bool? barcodeEnabled,
    bool? multiPricing,
    String? baseCurrency,
    bool? multiCurrency,
    double? exchangeRate,
    String? quoteCurrency,
  }) {
    return AppOptions(
      language: language ?? this.language,
      darkTheme: darkTheme ?? this.darkTheme,
      lockEnabled: lockEnabled ?? this.lockEnabled,
      lockPin: lockPin ?? this.lockPin,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      backupTarget: backupTarget ?? this.backupTarget,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      financialYearStart: financialYearStart ?? this.financialYearStart,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      autoInvoiceNo: autoInvoiceNo ?? this.autoInvoiceNo,
      printTime: printTime ?? this.printTime,
      roundOff: roundOff ?? this.roundOff,
      itemDiscount: itemDiscount ?? this.itemDiscount,
      billDiscount: billDiscount ?? this.billDiscount,
      deliveryCharges: deliveryCharges ?? this.deliveryCharges,
      posMode: posMode ?? this.posMode,
      showLogo: showLogo ?? this.showLogo,
      showFooter: showFooter ?? this.showFooter,
      showTerms: showTerms ?? this.showTerms,
      showBank: showBank ?? this.showBank,
      showSignature: showSignature ?? this.showSignature,
      termsText: termsText ?? this.termsText,
      bankDetails: bankDetails ?? this.bankDetails,
      vatEnabled: vatEnabled ?? this.vatEnabled,
      vatPercent: vatPercent ?? this.vatPercent,
      priceInclusive: priceInclusive ?? this.priceInclusive,
      showTrnCr: showTrnCr ?? this.showTrnCr,
      autoWhatsApp: autoWhatsApp ?? this.autoWhatsApp,
      whatsappTemplate: whatsappTemplate ?? this.whatsappTemplate,
      paymentReminders: paymentReminders ?? this.paymentReminders,
      reminderDays: reminderDays ?? this.reminderDays,
      enforceCreditLimit: enforceCreditLimit ?? this.enforceCreditLimit,
      showOutstandingOnBill: showOutstandingOnBill ?? this.showOutstandingOnBill,
      itemCategories: itemCategories ?? this.itemCategories,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      batchExpiry: batchExpiry ?? this.batchExpiry,
      barcodeEnabled: barcodeEnabled ?? this.barcodeEnabled,
      multiPricing: multiPricing ?? this.multiPricing,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      multiCurrency: multiCurrency ?? this.multiCurrency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      quoteCurrency: quoteCurrency ?? this.quoteCurrency,
    );
  }

  Map<String, dynamic> toJson() => {
        'language': language,
        'dark_theme': darkTheme,
        'lock_enabled': lockEnabled,
        'lock_pin': lockPin,
        'biometric_enabled': biometricEnabled,
        'backup_target': backupTarget,
        'last_backup_at': lastBackupAt,
        'financial_year_start': financialYearStart,
        'invoice_prefix': invoicePrefix,
        'auto_invoice_no': autoInvoiceNo,
        'print_time': printTime,
        'round_off': roundOff,
        'item_discount': itemDiscount,
        'bill_discount': billDiscount,
        'delivery_charges': deliveryCharges,
        'pos_mode': posMode,
        'show_logo': showLogo,
        'show_footer': showFooter,
        'show_terms': showTerms,
        'show_bank': showBank,
        'show_signature': showSignature,
        'terms_text': termsText,
        'bank_details': bankDetails,
        'vat_enabled': vatEnabled,
        'vat_percent': vatPercent,
        'price_inclusive': priceInclusive,
        'show_trn_cr': showTrnCr,
        'auto_whatsapp': autoWhatsApp,
        'whatsapp_template': whatsappTemplate,
        'payment_reminders': paymentReminders,
        'reminder_days': reminderDays,
        'enforce_credit_limit': enforceCreditLimit,
        'show_outstanding_on_bill': showOutstandingOnBill,
        'item_categories': itemCategories,
        'low_stock_threshold': lowStockThreshold,
        'batch_expiry': batchExpiry,
        'barcode_enabled': barcodeEnabled,
        'multi_pricing': multiPricing,
        'base_currency': baseCurrency,
        'multi_currency': multiCurrency,
        'exchange_rate': exchangeRate,
        'quote_currency': quoteCurrency,
      };

  factory AppOptions.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return AppOptions();
    bool flag(String k, bool d) {
      if (!json.containsKey(k)) return d;
      return json[k] == true;
    }

    return AppOptions(
      language: json['language']?.toString() ?? 'en',
      darkTheme: flag('dark_theme', false),
      lockEnabled: flag('lock_enabled', false),
      lockPin: json['lock_pin']?.toString() ?? '',
      biometricEnabled: flag('biometric_enabled', false),
      backupTarget: json['backup_target']?.toString() ?? 'local',
      lastBackupAt: json['last_backup_at']?.toString() ?? '',
      financialYearStart: json['financial_year_start']?.toString() ?? '2026-01-01',
      invoicePrefix: json['invoice_prefix']?.toString() ?? 'INV',
      autoInvoiceNo: flag('auto_invoice_no', true),
      printTime: flag('print_time', true),
      roundOff: flag('round_off', false),
      itemDiscount: flag('item_discount', true),
      billDiscount: flag('bill_discount', true),
      deliveryCharges: flag('delivery_charges', false),
      posMode: flag('pos_mode', false),
      showLogo: flag('show_logo', true),
      showFooter: flag('show_footer', true),
      showTerms: flag('show_terms', false),
      showBank: flag('show_bank', true),
      showSignature: flag('show_signature', true),
      termsText: json['terms_text']?.toString() ?? 'Goods once sold will not be taken back.',
      bankDetails: json['bank_details']?.toString() ?? '',
      vatEnabled: flag('vat_enabled', true),
      vatPercent: asDouble(json['vat_percent'] ?? 15),
      priceInclusive: flag('price_inclusive', false),
      showTrnCr: flag('show_trn_cr', true),
      autoWhatsApp: flag('auto_whatsapp', false),
      whatsappTemplate: json['whatsapp_template']?.toString() ??
          'Dear {Customer_Name}, invoice {Invoice_No} total {Bill_Amount}. Thank you.',
      paymentReminders: flag('payment_reminders', true),
      reminderDays: (json['reminder_days'] is num)
          ? (json['reminder_days'] as num).toInt()
          : int.tryParse(json['reminder_days']?.toString() ?? '') ?? 7,
      enforceCreditLimit: flag('enforce_credit_limit', true),
      showOutstandingOnBill: flag('show_outstanding_on_bill', true),
      itemCategories: flag('item_categories', true),
      lowStockThreshold: asDouble(json['low_stock_threshold'] ?? 5),
      batchExpiry: flag('batch_expiry', false),
      barcodeEnabled: flag('barcode_enabled', true),
      multiPricing: flag('multi_pricing', true),
      baseCurrency: json['base_currency']?.toString() ?? 'SAR',
      multiCurrency: flag('multi_currency', false),
      exchangeRate: asDouble(json['exchange_rate'] ?? 1),
      quoteCurrency: json['quote_currency']?.toString() ?? 'USD',
    );
  }
}
