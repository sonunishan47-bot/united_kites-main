/// VM / test stand-in. Web builds replace this with IndexedDB + localStorage.
class DeviceJournal {
  static void writeSync(String key, String value) {}

  static String? readSync(String key) => null;

  static Future<void> writeDurable(String key, String value) async {}

  static Future<String?> readDurable(String key) async => null;
}
