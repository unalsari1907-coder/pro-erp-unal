from pathlib import Path
import re

ROOT = Path('/tmp/proerp-src')

def rep(path, old, new, count=1):
    p = ROOT / path
    s = p.read_text(encoding='utf-8')
    if old not in s:
        raise RuntimeError(f'pattern not found in {path}: {old[:120]!r}')
    p.write_text(s.replace(old, new, count), encoding='utf-8')

# ------------------------------------------------------------
# 1) Stoktan satışa ekle -> stok listesine geri dön -> ikinci ürün ekle
# ------------------------------------------------------------
(ROOT / 'lib/services/satis_taslak_service.dart').write_text("""import '../models/stok_model.dart';

class SatisTaslakService {
  SatisTaslakService._();

  static final List<StokModel> _stoklar = <StokModel>[];

  static List<StokModel> get stoklar => List<StokModel>.unmodifiable(_stoklar);

  static bool get bos => _stoklar.isEmpty;

  static void ekle(StokModel stok) => _stoklar.add(stok);

  static void temizle() => _stoklar.clear();
}
""", encoding='utf-8')

rep('lib/screens/stok_sayfasi.dart',
    "import '../services/supabase_service.dart';",
    "import '../services/supabase_service.dart';\nimport '../services/satis_taslak_service.dart';")
rep('lib/screens/stok_sayfasi.dart',
"""                                        : () async {
                                            await Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => SatisSayfasi(
                                                  baslangicStok: urun,
                                                ),
                                              ),
                                            );

                                            if (!mounted) return;
                                            await _stoklariYukle();
                                          },""",
"""                                        : () async {
                                            SatisTaslakService.ekle(urun);
                                            await Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => const SatisSayfasi(),
                                              ),
                                            );

                                            if (!mounted) return;
                                            await _stoklariYukle();
                                          },""")

rep('lib/screens/stok_detay_sayfasi.dart',
    "import '../services/supabase_service.dart';",
    "import '../services/supabase_service.dart';\nimport '../services/satis_taslak_service.dart';")
rep('lib/screens/stok_detay_sayfasi.dart',
"""                : () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SatisSayfasi(
                          baslangicStok: widget.stok,
                        ),
                      ),
                    );

                    if (!mounted) return;
                    await _hareketleriYukle();
                  },""",
"""                : () async {
                    SatisTaslakService.ekle(widget.stok);
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SatisSayfasi(),
                      ),
                    );

                    if (!mounted) return;
                    await _hareketleriYukle();
                  },""")

rep('lib/screens/satis_sayfasi.dart',
    "import '../services/supabase_service.dart';",
    "import '../services/supabase_service.dart';\nimport '../services/satis_taslak_service.dart';")
rep('lib/screens/satis_sayfasi.dart',
"""        _depoId = depolar.isEmpty
            ? null
            : int.tryParse(depolar.first['depo_id'].toString());""",
"""        Map<String, dynamic>? merkezDepo;
        for (final depo in depolar) {
          final ad = depo['depo_adi']?.toString().trim().toUpperCase() ?? '';
          if (ad.contains('MERKEZ')) {
            merkezDepo = depo;
            break;
          }
        }
        final varsayilanDepo = merkezDepo ?? (depolar.isEmpty ? null : depolar.first);
        _depoId = varsayilanDepo == null
            ? null
            : int.tryParse(varsayilanDepo['depo_id'].toString());""")
rep('lib/screens/satis_sayfasi.dart',
"""      if (widget.baslangicStok != null &&
          _sepet.isEmpty &&
          mounted) {
        _sepeteEkle(widget.baslangicStok!);
      }""",
"""      if (_sepet.isEmpty && mounted) {
        if (widget.baslangicStok != null) {
          SatisTaslakService.ekle(widget.baslangicStok!);
        }
        for (final stok in SatisTaslakService.stoklar) {
          _sepeteEkle(stok);
        }
      }""")
rep('lib/screens/satis_sayfasi.dart',
"""  void _formuTemizle() {
    setState(() {""",
"""  void _formuTemizle() {
    SatisTaslakService.temizle();
    setState(() {""")
rep('lib/screens/satis_sayfasi.dart',
"""        actions: [
          IconButton(
            tooltip: 'Yenile',""",
"""        actions: [
          if (!SatisTaslakService.bos)
            TextButton.icon(
              onPressed: _kaydediliyor ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Stok Kartlarına Dön'),
            ),
          IconButton(
            tooltip: 'Yenile',""")

sales_header = """  Widget _kurumsalFaturaBasligi() {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blueGrey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_long_rounded, color: Colors.blue.shade800),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('ÜNAL YEDEK PARÇA', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                Text('Kurumsal ERP • Resmi Belge Girişi'),
              ],
            ),
          ),
          Text(
            'SATIŞ FATURASI',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade900),
          ),
        ],
      ),
    );
  }

"""
rep('lib/screens/satis_sayfasi.dart', '  Widget _darDuzen() {', sales_header + '  Widget _darDuzen() {')
rep('lib/screens/satis_sayfasi.dart',
"""    return Column(
      children: [
        _ustBilgiler(),""",
"""    return Column(
      children: [
        _kurumsalFaturaBasligi(),
        _ustBilgiler(),""", 1)
rep('lib/screens/satis_sayfasi.dart',
"""    return Column(
      children: [
        _ustBilgiler(),""",
"""    return Column(
      children: [
        _kurumsalFaturaBasligi(),
        _ustBilgiler(),""", 1)

# ------------------------------------------------------------
# 2-5) İrsaliye: Merkez depo, belirgin stok/raf, detay, kurumsal görünüm
# ------------------------------------------------------------
irs_helper = r'''
  int? _varsayilanMerkezDepoId(List<Map<String, dynamic>> depolar) {
    if (depolar.isEmpty) return null;
    for (final depo in depolar) {
      final ad = depo['depo_adi']?.toString().trim().toUpperCase() ?? '';
      if (ad.contains('MERKEZ')) {
        return int.tryParse(depo['depo_id']?.toString() ?? '');
      }
    }
    return int.tryParse(depolar.first['depo_id']?.toString() ?? '');
  }

  String _listeMetni(List<String> liste) {
    final temiz = liste.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return temiz.isEmpty ? '-' : temiz.join(', ');
  }

  Future<void> _stokDetayAc(StokModel stok) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(stok.urunAdi),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _detaySatiri('Üretici Kodu', stok.ureticiKodu),
                _detaySatiri('OEM', _listeMetni(stok.oemler)),
                _detaySatiri('CROSS', _listeMetni(stok.crossKodlar)),
                _detaySatiri('Rakip Kod', _listeMetni(stok.rakipKodlar)),
                _detaySatiri('RAF', stok.raf),
                _detaySatiri('Mevcut Stok', stok.stokMiktari.toStringAsFixed(0)),
                _detaySatiri('Marka', stok.marka),
                _detaySatiri('Araç', _listeMetni(stok.araclar)),
                _detaySatiri('Ürün Özelliği', stok.urunOzellik),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _detaySatiri(String baslik, String deger) {
    final metin = deger.trim().isEmpty ? '-' : deger.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 125,
            child: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Expanded(child: SelectableText(metin)),
        ],
      ),
    );
  }

  Widget _stokRafRozeti(StokModel stok) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: stok.stokMiktari > 0 ? Colors.green.shade50 : Colors.red.shade50,
            border: Border.all(color: stok.stokMiktari > 0 ? Colors.green.shade300 : Colors.red.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'STOK ${stok.stokMiktari.toStringAsFixed(0)}',
            style: TextStyle(fontWeight: FontWeight.w800, color: stok.stokMiktari > 0 ? Colors.green.shade800 : Colors.red.shade800),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            border: Border.all(color: Colors.blueGrey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'RAF ${stok.raf.trim().isEmpty ? '-' : stok.raf.trim()}',
            style: TextStyle(fontWeight: FontWeight.w800, color: Colors.blueGrey.shade900),
          ),
        ),
      ],
    );
  }

  Widget _kurumsalBelgeBasligi(String belgeTipi) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blueGrey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.receipt_long_rounded, color: Colors.blue.shade800),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('ÜNAL YEDEK PARÇA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('Kurumsal ERP • Belge Oluşturma'),
              ],
            ),
          ),
          Text(belgeTipi, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade900)),
        ],
      ),
    );
  }
'''

for path in ['lib/screens/yeni_satis_irsaliyesi_screen.dart', 'lib/screens/yeni_alis_irsaliyesi_screen.dart']:
    rep(path,
"""  String _para(dynamic deger) {
    return '${_sayi(deger).toStringAsFixed(2)} ₺';
  }
""",
"""  String _para(dynamic deger) {
    return '${_sayi(deger).toStringAsFixed(2)} ₺';
  }
""" + irs_helper)
    rep(path,
"""        _depoId = depolar.isEmpty
            ? null
            : int.tryParse(depolar.first['depo_id'].toString());""",
"""        _depoId = _varsayilanMerkezDepoId(depolar);""")
    rep(path,
"""                        Text(
                          'Stok: ${stok.stokMiktari.toStringAsFixed(0)} Adet',
                        ),""",
"""                        const SizedBox(height: 6),
                        _stokRafRozeti(stok),""")
    rep(path,
"""                  IconButton(
                    tooltip: 'Sepete ekle',""",
"""                  IconButton(
                    tooltip: 'Stok detayı',
                    onPressed: () => _stokDetayAc(stok),
                    icon: const Icon(Icons.info_outline_rounded, color: Colors.blueGrey),
                  ),
                  IconButton(
                    tooltip: 'Sepete ekle',""")
    rep(path,
"""                  Text(
                    'Kod: ${stok.ureticiKodu.isEmpty ? '-' : stok.ureticiKodu} • '
                    'RAF: ${stok.raf.isEmpty ? '-' : stok.raf}',
                  ),
                  const SizedBox(height: 4),""",
"""                  Text(
                    'Kod: ${stok.ureticiKodu.isEmpty ? '-' : stok.ureticiKodu}',
                  ),
                  const SizedBox(height: 6),
                  _stokRafRozeti(stok),
                  const SizedBox(height: 4),""")
    rep(path,
"""            const SizedBox(width: 8),
            Container(""",
"""            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Stok detayı (OEM / CROSS / Rakip Kod)',
              onPressed: () => _stokDetayAc(stok),
              icon: const Icon(Icons.info_outline_rounded, color: Colors.blueGrey),
            ),
            Container(""")

rep('lib/screens/yeni_satis_irsaliyesi_screen.dart',
"""          : Column(
              children: [
                Card(""",
"""          : Column(
              children: [
                _kurumsalBelgeBasligi('SATIŞ İRSALİYESİ'),
                Card(""")
rep('lib/screens/yeni_alis_irsaliyesi_screen.dart',
"""          : Column(
              children: [
                Card(""",
"""          : Column(
              children: [
                _kurumsalBelgeBasligi('ALIŞ İRSALİYESİ'),
                Card(""")

# ------------------------------------------------------------
# 3 + 6) Alış faturası: Merkez depo + kurumsal belge görünümü
# ------------------------------------------------------------
rep('lib/screens/satin_alma/satin_alma_sayfasi.dart',
"""        if (_depolar.isNotEmpty) {
          _secilenDepoId = int.tryParse(
            _depolar.first['depo_id'].toString(),
          );
        }""",
"""        if (_depolar.isNotEmpty) {
          Map<String, dynamic>? merkezDepo;
          for (final depo in _depolar) {
            final ad = depo['depo_adi']?.toString().trim().toUpperCase() ?? '';
            if (ad.contains('MERKEZ')) {
              merkezDepo = depo;
              break;
            }
          }
          final varsayilanDepo = merkezDepo ?? _depolar.first;
          _secilenDepoId = int.tryParse(varsayilanDepo['depo_id'].toString());
        }""")

purchase_header = """  Widget _kurumsalFaturaBasligi() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blueGrey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.receipt_long_rounded, color: Colors.blue.shade800),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('ÜNAL YEDEK PARÇA', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                Text('Kurumsal ERP • Resmi Belge Girişi'),
              ],
            ),
          ),
          Text('ALIŞ FATURASI', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade900)),
        ],
      ),
    );
  }

"""
rep('lib/screens/satin_alma/satin_alma_sayfasi.dart',
"""  // ------------------------------------------------------
  // HEADER
  // ------------------------------------------------------
""",
purchase_header + """  // ------------------------------------------------------
  // HEADER
  // ------------------------------------------------------
""")
rep('lib/screens/satin_alma/satin_alma_sayfasi.dart',
"""    return Column(
      children: [
        _header(),""",
"""    return Column(
      children: [
        _kurumsalFaturaBasligi(),
        _header(),""")
rep('lib/screens/satin_alma/satin_alma_sayfasi.dart',
"""      child: Column(
        children: [
          _header(),""",
"""      child: Column(
        children: [
          _kurumsalFaturaBasligi(),
          _header(),""")

# ------------------------------------------------------------
# Araç katalogu: kalıcı düzenleme, R/L standart, kategori ve araç OEM renkleri
# ------------------------------------------------------------
service_path = ROOT / 'lib/services/arac_katalog_service.dart'
s = service_path.read_text(encoding='utf-8')
service_helper = r'''
  static String _parcaAdiStandartla(String raw, {String kategoriKodu = ''}) {
    var x = _norm(raw).replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final kod = kategoriKodu.trim().toUpperCase();
    final rl = kod.endsWith('_SAG') ||
        kod.endsWith('_SOL') ||
        RegExp(r'(?:\s+R/L|\s+R L|\s+RL|\s+SAG|\s+SOL)$').hasMatch(x);
    x = x.replaceFirst(RegExp(r'(?:\s+R/L|\s+R L|\s+RL|\s+SAG|\s+SOL)$'), '').trim();
    return rl && x.isNotEmpty ? '$x R/L' : x;
  }

  static List<String> _kategoriKodVaryantlari(String raw) {
    var kod = raw.trim().toUpperCase();
    if (kod.endsWith('_SAG')) kod = kod.substring(0, kod.length - 4);
    if (kod.endsWith('_SOL')) kod = kod.substring(0, kod.length - 4);
    return <String>[kod, '${kod}_SAG', '${kod}_SOL'];
  }

  static Future<Map<int, Map<String, int>>> aracOemDurumlari(List<int> aracIds) async {
    if (aracIds.isEmpty) return <int, Map<String, int>>{};
    final raw = await _db
        .from('erp_arac_katalog_parcalar')
        .select('arac_id,kategori_kodu,oem_kodu,nitelik')
        .inFilter('arac_id', aracIds);
    final toplamKodlar = <int, Set<String>>{};
    final tamamKodlar = <int, Set<String>>{};
    for (final item in (raw as List)) {
      final row = Map<String, dynamic>.from(item as Map);
      final aracId = int.tryParse('${row['arac_id']}') ?? 0;
      if (aracId <= 0) continue;
      var kod = _cell(row['kategori_kodu']).toUpperCase();
      if (kod.endsWith('_SAG')) kod = kod.substring(0, kod.length - 4);
      if (kod.endsWith('_SOL')) kod = kod.substring(0, kod.length - 4);
      if (kod.isEmpty) continue;
      toplamKodlar.putIfAbsent(aracId, () => <String>{}).add(kod);
      if (_cell(row['oem_kodu']).isNotEmpty) {
        tamamKodlar.putIfAbsent(aracId, () => <String>{}).add(kod);
      }
    }
    final sonuc = <int, Map<String, int>>{};
    for (final id in aracIds) {
      sonuc[id] = <String, int>{
        'tamam': tamamKodlar[id]?.length ?? 0,
        'toplam': toplamKodlar[id]?.length ?? 0,
      };
    }
    return sonuc;
  }

'''
needle = '  static Future<void> parcaGuncelle({'
if service_helper not in s:
    s = s.replace(needle, service_helper + needle, 1)
s = s.replace("    final ad = parcaAdi.trim();\n    if (ad.isEmpty) throw Exception('Parça adı boş bırakılamaz.');",
              "    final ad = _parcaAdiStandartla(parcaAdi, kategoriKodu: mevcutKategoriKodu);\n    if (ad.isEmpty) throw Exception('Parça adı boş bırakılamaz.');", 1)
old = """    if (eskiKod.isNotEmpty) {
      await _db
          .from('erp_arac_katalog_parcalar')
          .update(<String, dynamic>{
            'kategori_adi': ad,
            'nitelik': 'UST_KATEGORI:$ust',
          })
          .eq('kategori_kodu', eskiKod);

      // Ana şablonu da aynı anda güncelle; bundan sonra açılan yeni araçlar
      // eski kategori adını değil güncel adı alsın.
      try {
        await _db
            .from('erp_arac_katalog_sablon')
            .update(<String, dynamic>{
              'kategori_adi': ad,
              'nitelik': 'UST_KATEGORI:$ust',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('kategori_kodu', eskiKod);
      } catch (_) {
        // 2.5.4 SQL henüz çalıştırılmadıysa mevcut güncelleme davranışını bozma.
      }
    }
"""
new = """    if (eskiKod.isNotEmpty) {
      final varyantlar = _kategoriKodVaryantlari(eskiKod);
      for (final kod in varyantlar) {
        await _db
            .from('erp_arac_katalog_parcalar')
            .update(<String, dynamic>{
              'kategori_adi': ad,
              'nitelik': 'UST_KATEGORI:$ust',
            })
            .eq('kategori_kodu', kod);
        try {
          await _db
              .from('erp_arac_katalog_sablon')
              .update(<String, dynamic>{
                'kategori_adi': ad,
                'nitelik': 'UST_KATEGORI:$ust',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('kategori_kodu', kod);
        } catch (_) {}
      }
    }
"""
if old not in s:
    raise RuntimeError('catalog service global-update block not found')
s = s.replace(old, new, 1)
service_path.write_text(s, encoding='utf-8')

ui_path = ROOT / 'lib/screens/arac_parca_katalog_sayfasi.dart'
s = ui_path.read_text(encoding='utf-8')
s = s.replace("  String _kategoriFiltre = 'Tümü';", "  String _kategoriFiltre = 'Tümü';\n  Map<int, Map<String, int>> _aracOemDurumlari = <int, Map<String, int>>{};", 1)
s = s.replace("""      setState(() {
        _araclar = liste;
        _yukleniyor = false;
        if (liste.isEmpty) {
          _hata = 'Araç bulunamadı. Katalog Excel/CSV dosyanızı içe aktarabilirsiniz.';
        }
      });""",
"""      final ids = liste.map((e) => _int(e['arac_id'])).where((e) => e > 0).toList();
      final durumlar = await AracKatalogService.aracOemDurumlari(ids);
      if (!mounted) return;
      setState(() {
        _araclar = liste;
        _aracOemDurumlari = durumlar;
        _yukleniyor = false;
        if (liste.isEmpty) {
          _hata = 'Araç bulunamadı. Katalog Excel/CSV dosyanızı içe aktarabilirsiniz.';
        }
      });""", 1)

ui_helper = r'''
  String _birlesikRlKategoriKodu(String raw) {
    var kod = raw.trim().toUpperCase();
    if (kod.endsWith('_SAG')) kod = kod.substring(0, kod.length - 4);
    if (kod.endsWith('_SOL')) kod = kod.substring(0, kod.length - 4);
    return kod;
  }

  String _standartParcaAdi(String raw) {
    var x = raw.trim().toUpperCase();
    const from = 'ÇĞİÖŞÜÂÊÎÔÛ';
    const to = 'CGIOSUAEIOU';
    for (var i = 0; i < from.length; i++) {
      x = x.replaceAll(from[i], to[i]);
    }
    final rl = RegExp(r'(?:\s+R/L|\s+R L|\s+RL|\s+SAG|\s+SOL)$').hasMatch(x);
    x = x.replaceFirst(RegExp(r'(?:\s+R/L|\s+R L|\s+RL|\s+SAG|\s+SOL)$'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return rl && x.isNotEmpty ? '$x R/L' : x;
  }

  Color _durumRengi(int tamam, int toplam) {
    if (toplam > 0 && tamam >= toplam) return Colors.green;
    if (tamam > 0) return Colors.orange;
    return Colors.red;
  }

'''
s = s.replace('  Widget _aracListesi() {', ui_helper + '  Widget _aracListesi() {', 1)
s = s.replace("final ad = TextEditingController(text: _s(parca['kategori_adi']));",
              "final ad = TextEditingController(text: _standartParcaAdi(_s(parca['kategori_adi'])));", 1)
s = s.replace("""      final kod = _s(p['kategori_kodu']).isEmpty
          ? 'PARCA_${_int(p['parca_id'])}'
          : _s(p['kategori_kodu']);""",
"""      final hamKod = _s(p['kategori_kodu']);
      final kod = hamKod.isEmpty
          ? 'PARCA_${_int(p['parca_id'])}'
          : _birlesikRlKategoriKodu(hamKod);""", 1)
s = s.replace("""    final kategoriler = <String, int>{};
    for (final grup in parcaGruplari) {
      final k = _parcaUstKategori(grup.first);
      kategoriler[k] = (kategoriler[k] ?? 0) + 1;
    }""",
"""    final kategoriler = <String, int>{};
    final kategoriTamam = <String, int>{};
    for (final grup in parcaGruplari) {
      final k = _parcaUstKategori(grup.first);
      kategoriler[k] = (kategoriler[k] ?? 0) + 1;
      final tamamMi = grup.any((p) => _s(p['oem_kodu']).isNotEmpty);
      if (tamamMi) kategoriTamam[k] = (kategoriTamam[k] ?? 0) + 1;
    }""", 1)
s = s.replace("""                  final adet = k == 'Tümü'
                      ? parcaGruplari.length
                      : (kategoriler[k] ?? 0);
                  final secili = _kategoriFiltre == k;
                  return ListTile(
                    dense: true,
                    selected: secili,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    title: Text(
                      k,
                      style: TextStyle(
                        fontWeight: secili ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    trailing: CircleAvatar(
                      radius: 13,
                      child: Text(
                        '$adet',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    onTap: () => setState(() => _kategoriFiltre = k),
                  );""",
"""                  final adet = k == 'Tümü' ? parcaGruplari.length : (kategoriler[k] ?? 0);
                  final tamam = k == 'Tümü'
                      ? parcaGruplari.where((g) => g.any((p) => _s(p['oem_kodu']).isNotEmpty)).length
                      : (kategoriTamam[k] ?? 0);
                  final secili = _kategoriFiltre == k;
                  final renk = _durumRengi(tamam, adet);
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: renk.withOpacity(0.08),
                      border: Border.all(color: renk.withOpacity(0.28)),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: ListTile(
                      dense: true,
                      selected: secili,
                      leading: Icon(tamam >= adet && adet > 0 ? Icons.check_circle : Icons.timelapse_rounded, size: 18, color: renk),
                      title: Text(
                        k.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(color: renk, fontWeight: secili ? FontWeight.w800 : FontWeight.w700, fontSize: 12),
                      ),
                      trailing: Text('$tamam/$adet', style: TextStyle(color: renk, fontWeight: FontWeight.w800, fontSize: 11)),
                      onTap: () => setState(() => _kategoriFiltre = k),
                    ),
                  );""", 1)
s = s.replace("""                                    _s(ana['kategori_adi']),
                                    style: const TextStyle(""",
"""                                    _standartParcaAdi(_s(ana['kategori_adi'])),
                                    style: const TextStyle(""", 1)
s = s.replace("""          return ListTile(
            selected: secili,
            leading: const Icon(Icons.directions_car_filled_rounded),
            title: Text(""",
"""          final aracId = _int(arac['arac_id']);
          final durum = _aracOemDurumlari[aracId] ?? const <String, int>{'tamam': 0, 'toplam': 0};
          final tamam = durum['tamam'] ?? 0;
          final toplam = durum['toplam'] ?? 0;
          final renk = _durumRengi(tamam, toplam);
          return Container(
            color: renk.withOpacity(0.06),
            child: ListTile(
            selected: secili,
            leading: Icon(Icons.directions_car_filled_rounded, color: renk),
            title: Text(""", 1)
s = s.replace("""            trailing: _s(arac['sase']).isEmpty
                ? null
                : IconButton(
                    tooltip: 'Şaseyi Kopyala',
                    onPressed: () => _kopyala(_s(arac['sase']), 'Şase'),
                    icon: const Icon(Icons.copy_rounded),
                  ),
            onTap: () => _aracSec(arac),
          );""",
"""            trailing: SizedBox(
              width: 112,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Text('OEM $tamam/$toplam', style: TextStyle(color: renk, fontWeight: FontWeight.w800, fontSize: 11)),
                  if (_s(arac['sase']).isNotEmpty)
                    IconButton(
                      tooltip: 'Şaseyi Kopyala',
                      onPressed: () => _kopyala(_s(arac['sase']), 'Şase'),
                      icon: const Icon(Icons.copy_rounded),
                    ),
                ],
              ),
            ),
            onTap: () => _aracSec(arac),
          ),
          );""", 1)
ui_path.write_text(s, encoding='utf-8')

# ------------------------------------------------------------
# Version
# ------------------------------------------------------------
p = ROOT / 'pubspec.yaml'
s = p.read_text(encoding='utf-8')
s = re.sub(r'^version:\s*.*$', 'version: 2.5.20+2026081701', s, flags=re.M)
p.write_text(s, encoding='utf-8')

p = ROOT / 'lib/app_config.dart'
s = p.read_text(encoding='utf-8')
s = re.sub(r"static const String version = '.*?';", "static const String version = '2.5.20';", s)
p.write_text(s, encoding='utf-8')

print('PRO ERP 2.5.20 source transformations applied')
