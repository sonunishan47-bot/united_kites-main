import 'package:url_launcher/url_launcher.dart';

import '../models/crm.dart';
import '../models/invoice.dart';
import '../models/shop_settings.dart';
import '../services/pdf_service.dart';
import '../utils/formatters.dart';

class WhatsAppShare {
  const WhatsAppShare();

  String digits(String phone) {
    var d = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('05') && d.length == 10) {
      d = '966${d.substring(1)}';
    }
    if (d.startsWith('5') && d.length == 9) {
      d = '966$d';
    }
    return d;
  }

  Future<void> openChat(String phone, String message) async {
    final uri = Uri.parse(
      'https://wa.me/${digits(phone)}?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> zatcaBill({
    required Invoice invoice,
    required ShopSettings settings,
    bool arabic = false,
  }) async {
    await const PdfService().share(invoice, settings);
    final tpl = settings.options.whatsappTemplate;
    final body = tpl
        .replaceAll('{Customer_Name}', invoice.customerName)
        .replaceAll('{Bill_Amount}', sar.format(invoice.grandTotal))
        .replaceAll('{Invoice_No}', invoice.invoiceNo);
    if (invoice.customerPhone.trim().isEmpty) return;
    await openChat(invoice.customerPhone, body);
  }

  Future<void> paymentReceipt({
    required Customer customer,
    required LedgerPayment payment,
    required double remainingDue,
    required bool arabic,
    ShopSettings? settings,
  }) async {
    if (settings != null) {
      await const PdfService().sharePaymentReceipt(
        payment: payment,
        customer: customer,
        settings: settings,
        remainingDue: remainingDue,
      );
    }
    final body = arabic
        ? 'إيصال تحصيل — ${customer.shopName}\nالمبلغ ${sar.format(payment.amount)}\nطريقة الدفع ${payment.method}\nالمتبقي ${sar.format(remainingDue)}\nشكراً.'
        : 'Payment received — ${customer.shopName}\nAmount ${sar.format(payment.amount)}\nMethod ${payment.method}\nBalance due ${sar.format(remainingDue)}\nThank you.';
    if (customer.phone.trim().isNotEmpty) {
      await openChat(customer.phone, body);
    }
  }

  Future<void> customerLedger({
    required Customer customer,
    required double due,
    required bool arabic,
    required List<CustomerLedgerEntry> rows,
    required double billed,
    required double paid,
    required ShopSettings settings,
  }) async {
    await const PdfService().shareCustomerLedger(
      customer: customer,
      rows: rows,
      billed: billed,
      paid: paid,
      due: due,
      settings: settings,
    );
    final body = arabic
        ? 'كشف حساب — ${customer.shopName}\nالمستحق ${sar.format(due)}'
        : 'Account ledger — ${customer.shopName}\nBalance due ${sar.format(due)}';
    if (customer.phone.trim().isNotEmpty) {
      await openChat(customer.phone, body);
    }
  }

  Future<void> creditAlert({
    required Customer customer,
    required double due,
    required bool arabic,
    Invoice? statement,
    ShopSettings? settings,
  }) async {
    if (statement != null && settings != null) {
      await const PdfService().share(statement, settings);
    }
    final pdfLine = statement == null
        ? ''
        : (arabic
            ? '\nتم إرفاق/مشاركة كشف PDF: ${statement.invoiceNo}'
            : '\nPDF statement shared: ${statement.invoiceNo}');
    final body = arabic
        ? 'تنبيه رصيد — ${customer.shopName}\nالمستحق ${sar.format(due)}$pdfLine\nيرجى السداد. شكراً.'
        : 'Payment reminder — ${customer.shopName}\nBalance due ${sar.format(due)}$pdfLine\nPlease settle. Thank you.';
    await openChat(customer.phone, body);
  }

  Future<void> openMaps(Customer customer) async {
    final uri = Uri.parse(customer.mapsUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> openDirections(Customer customer) async {
    final uri = Uri.parse(customer.directionsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> openGoogleRoute(List<Customer> ordered) async {
    if (ordered.isEmpty) return;
    if (ordered.length == 1) {
      await openMaps(ordered.first);
      return;
    }
    final origin = '${ordered.first.lat},${ordered.first.lng}';
    final dest = '${ordered.last.lat},${ordered.last.lng}';
    final waypoints = ordered.length <= 2
        ? ''
        : '&waypoints=${ordered.sublist(1, ordered.length - 1).map((c) => '${c.lat},${c.lng}').join('|')}';
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$dest$waypoints&travelmode=driving',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
