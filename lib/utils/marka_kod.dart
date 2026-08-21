String markaVeUreticiKodu(dynamic marka, dynamic ureticiKodu) {
  String temizle(dynamic deger) {
    final metin = deger?.toString().trim() ?? '';
    if (metin.isEmpty || metin == '-' || metin.toLowerCase() == 'null') {
      return '';
    }
    return metin;
  }

  final markaMetni = temizle(marka);
  final kodMetni = temizle(ureticiKodu);

  if (markaMetni.isEmpty && kodMetni.isEmpty) return '-';
  if (markaMetni.isEmpty) return kodMetni;
  if (kodMetni.isEmpty) return markaMetni;
  if (markaMetni.toLowerCase() == kodMetni.toLowerCase()) return markaMetni;

  return '$markaMetni $kodMetni';
}
