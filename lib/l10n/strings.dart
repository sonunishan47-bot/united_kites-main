class S {
  const S(this.code);

  final String code;
  bool get isAr => code.startsWith('ar');

  String t(String en, String ar, [String? ml]) {
    if (code.startsWith('ar')) return ar;
    if (code.startsWith('ml')) return ml ?? en;
    return en;
  }

  bool get isMl => code.startsWith('ml');

  String get app => t('United Kites', 'يونايتد كايتس');
  String get signOut => t('Sign out', 'خروج');
  String get home => t('Home', 'الرئيسية');
  String get dashboard => t('Dashboard', 'لوحة التحكم');
  String get items => t('Items', 'الأصناف');
  String get bills => t('Invoices', 'الفواتير');
  String get catalog => t('Products', 'المنتجات');
  String get txnDetails => t('Transaction Details', 'تفاصيل العمليات');
  String get partyDetails => t('Party Details', 'تفاصيل العملاء');
  String get searchTxn => t('Search for a transaction', 'ابحث عن عملية');
  String get searchParty => t('Search for a party', 'ابحث عن عميل');
  String get stock => t('Stock', 'المخزون');
  String get load => t('Van Loading', 'تحميل الفان');
  String get reports => t('Reports', 'التقارير');
  String get print => t('Print Setup', 'إعدادات الطباعة');
  String get crm => t('Customers', 'العملاء');
  String get analytics => t('Sales Reports', 'التقارير والتحليلات');
  String get routes => t('Customer Map', 'خريطة العملاء');
  String get more => t('More', 'المزيد');
  String get expenses => t('Expenses', 'المصروفات');
  String get partner => t('Partner View', 'الشريك');
  String get vanStock => t('Van Stock', 'مخزون الفان');
  String get live => t('Live Status', 'مباشر');

  String get total => t('Total', 'الإجمالي');
  String get vat => t('VAT', 'الضريبة');
  String get vat15 => t('VAT 15%', 'ضريبة 15%');
  String get balance => t('Balance', 'الرصيد');
  String get invoice => t('Invoice', 'فاتورة');
  String get sales => t('Sales', 'المبيعات');
  String get taxable => t('Taxable', 'الخاضع للضريبة');
  String get discount => t('Discount', 'الخصم');
  String get creditNote => t('Credit note', 'إشعار دائن');
  String get taxInvoice => t('Tax invoice', 'فاتورة ضريبية');
  String get newBill => t('New bill', 'فاتورة جديدة');
  String get addTxn => t('Add Txn', 'إضافة عملية');
  String get saleReport => t('Sale Report', 'تقرير المبيعات');
  String get dayBook => t('Day Book', 'دفتر اليوم');
  String get profitLoss => t('Profit & Loss', 'الأرباح والخسائر');
  String get quickLinks => t('Quick Links', 'روابط سريعة');
  String get addNewSale => t('Add New Sale', 'فاتورة جديدة');
  String get addNewProduct => t('Add New Product', 'منتج جديد');
  String get productCode => t('Product Code', 'رمز المنتج');
  String get itemCode => t('Item Code', 'رمز الصنف');
  String get sale => t('SALE', 'بيع');
  String get paid => t('PAID', 'مدفوع');
  String get due => t('DUE', 'مستحق');
  String get partial => t('PARTIAL', 'جزئي');
  String get viewOnly => t('View only', 'عرض فقط');
  String get openEditAdmin => t('Open / edit (admin)', 'فتح / تعديل (المدير)');
  String get deleteAdmin => t('Delete (admin)', 'حذف (المدير)');
  String get issueCredit => t('ZATCA credit note / return', 'إشعار دائن زاتكا / مرتجع');
  String get languageEn => '🇬🇧 EN';
  String get languageAr => '🇸🇦 عربي';
  String get languageMl => '🇮🇳 ML';
  String get settings => t('Settings', 'الإعدادات', 'ക്രമീകരണങ്ങൾ');
}
