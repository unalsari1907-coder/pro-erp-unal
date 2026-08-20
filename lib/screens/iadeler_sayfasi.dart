// lib/screens/iadeler_sayfasi.dart

import 'package:flutter/material.dart';

import '../widgets/mobil_uyum.dart';
import '../services/supabase_service.dart';
import '../services/yetki_service.dart';

class IadelerSayfasi extends StatefulWidget {
  final String baslangicTipi;
  final int? baslangicCariId;
  final int? baslangicFaturaId;
  final int? baslangicDepoId;

  const IadelerSayfasi({
    super.key,
    this.baslangicTipi = 'SATIS_IADE',
    this.baslangicCariId,
    this.baslangicFaturaId,
    this.baslangicDepoId,
  });

  @override
  State<IadelerSayfasi> createState() => _IadelerSayfasiState();
}

class _IadelerSayfasiState extends State<IadelerSayfasi> {
  final TextEditingController _aramaController = TextEditingController();
  final TextEditingController _stokAramaController = TextEditingController();
  final TextEditingController _aciklamaController = TextEditingController();

  bool _yukleniyor = true;
  bool _detayYukleniyor = false;
  bool _kaydediliyor = false;

  late String _iadeTipi;

  List<Map<String, dynamic>> _cariler = [];
  List<Map<String, dynamic>> _faturalar = [];
  List<Map<String, dynamic>> _gorunenFaturalar = [];
  List<Map<String, dynamic>> _detaylar = [];
  List<Map<String, dynamic>> _iadeler = [];
  List<Map<String, dynamic>> _depolar = [];
  List<Map<String, dynamic>> _stoklar = [];
  List<Map<String, dynamic>> _gorunenStoklar = [];

  final Map<int, Set<int>> _stokFaturaIds = {};

  int? _cariId;
  int? _faturaId;
  int? _depoId;
  int? _secilenStokId;

  final Map<int, TextEditingController> _miktarControllerlari = {};

  @override
  void initState() {
    super.initState();
    _iadeTipi = widget.baslangicTipi;
    _cariId = widget.baslangicCariId;
    _depoId = widget.baslangicDepoId;
    _aramaController.addListener(_faturaFiltrele);
    _stokAramaController.addListener(_stokFiltrele);
    _verileriYukle();
  }

  @override
  void dispose() {
    _aramaController.dispose();
    _stokAramaController.dispose();
    _aciklamaController.dispose();

    for (final controller in _miktarControllerlari.values) {
      controller.dispose();
    }

    super.dispose();
  }

  int _int(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  double _sayi(dynamic value) =>
      double.tryParse(value?.toString().replaceAll(',', '.') ?? '0') ?? 0;

  String _metin(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  String _para(dynamic value) => '${_sayi(value).toStringAsFixed(2)} ₺';

  String _miktar(dynamic value) {
    final sayi = _sayi(value);
    return sayi == sayi.roundToDouble()
        ? sayi.toStringAsFixed(0)
        : sayi.toStringAsFixed(3);
  }

  String _tarih(dynamic value) {
    final raw = value?.toString() ?? '';
    final date = DateTime.tryParse(raw)?.toLocal();

    if (date == null) return _metin(value);

    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  String get _faturaTablosu =>
      _iadeTipi == 'SATIS_IADE' ? 'satis_baslik' : 'alis_baslik';

  String get _detayTablosu =>
      _iadeTipi == 'SATIS_IADE' ? 'satis_detay' : 'alis_detay';

  String get _faturaIdKolonu =>
      _iadeTipi == 'SATIS_IADE' ? 'satis_id' : 'alis_id';

  String get _ekranBasligi =>
      _iadeTipi == 'SATIS_IADE' ? 'SATIŞ İADELERİ' : 'ALIŞ İADELERİ';

  Future<void> _verileriYukle() async {
    if (!mounted) return;

    setState(() => _yukleniyor = true);

    try {
      final sonuclar = await Future.wait([
        SupabaseService.supabase
            .from('cariler')
            .select('cari_id, unvan')
            .order('unvan'),
        SupabaseService.supabase
            .from('depolar')
            .select('depo_id, depo_adi, depo_tipi, aktif, satilabilir')
            .eq('aktif', true)
            .order('depo_adi'),
        SupabaseService.supabase
            .from('iade_baslik')
            .select()
            .order('tarih', ascending: false),
      ]);

      _cariler = List<Map<String, dynamic>>.from(sonuclar[0] as List);

      _depolar = List<Map<String, dynamic>>.from(sonuclar[1] as List);

      _iadeler = List<Map<String, dynamic>>.from(sonuclar[2] as List);

      await _faturalariYukle();

      if (!mounted) return;
      setState(() => _yukleniyor = false);

      final baslangicFaturaId = widget.baslangicFaturaId;

      if (baslangicFaturaId != null) {
        Map<String, dynamic>? fatura;

        for (final item in _faturalar) {
          if (_int(item[_faturaIdKolonu]) == baslangicFaturaId) {
            fatura = item;
            break;
          }
        }

        if (fatura != null) {
          await _faturaSec(fatura);
        } else {
          _mesaj('İade alınacak fatura bulunamadı.', Colors.orange);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
      _mesaj('İade ekranı yüklenemedi: $e', Colors.red);
    }
  }

  Future<void> _faturalariYukle() async {
    final sonuclar = await Future.wait([
      SupabaseService.supabase
          .from(_faturaTablosu)
          .select(
            '$_faturaIdKolonu, fatura_no, tarih, cari_id, '
            'depo_id, genel_toplam, durum, odeme_tipi',
          )
          .neq('durum', 'IPTAL')
          .order('tarih', ascending: false),
      SupabaseService.supabase
          .from(_detayTablosu)
          .select('$_faturaIdKolonu, stok_id'),
      SupabaseService.supabase
          .from('stoklar')
          .select(
            'stok_id, urun_adi, uretici_kodu, oem_no, '
            'barkod, marka, raf, cross_kod, rakip_kod, stok_miktari',
          )
          .order('urun_adi'),
    ]);

    final faturalar = List<Map<String, dynamic>>.from(sonuclar[0] as List);

    final faturaDetaylari = List<Map<String, dynamic>>.from(
      sonuclar[1] as List,
    );

    final stoklar = List<Map<String, dynamic>>.from(sonuclar[2] as List);

    final cariMap = <int, String>{
      for (final cari in _cariler) _int(cari['cari_id']): _metin(cari['unvan']),
    };

    final depoMap = <int, String>{
      for (final depo in _depolar)
        _int(depo['depo_id']): _metin(depo['depo_adi']),
    };

    for (final fatura in faturalar) {
      fatura['cari_unvan'] = cariMap[_int(fatura['cari_id'])] ?? '-';
      fatura['depo_adi'] = depoMap[_int(fatura['depo_id'])] ?? '-';
    }

    _stokFaturaIds.clear();

    for (final detay in faturaDetaylari) {
      final stokId = _int(detay['stok_id']);
      final faturaId = _int(detay[_faturaIdKolonu]);

      if (stokId <= 0 || faturaId <= 0) {
        continue;
      }

      _stokFaturaIds.putIfAbsent(stokId, () => <int>{}).add(faturaId);
    }

    _faturalar = faturalar;
    // Bütün stok kartlarını aramada göster.
    // Faturada bulunmayan stoklarda fatura sayısı 0 görünür.
    _stoklar = stoklar;

    _stokFiltrele();
    _faturaFiltrele();
  }

  void _faturaFiltrele() {
    final q = _aramaController.text.toLowerCase().trim();

    if (!mounted) return;

    setState(() {
      _gorunenFaturalar = _faturalar.where((fatura) {
        if (_cariId != null && _int(fatura['cari_id']) != _cariId) {
          return false;
        }

        if (_secilenStokId != null) {
          final faturaIds = _stokFaturaIds[_secilenStokId];

          if (faturaIds == null ||
              !faturaIds.contains(_int(fatura[_faturaIdKolonu]))) {
            return false;
          }
        }

        if (q.isEmpty) return true;

        final metin = [
          fatura['fatura_no'],
          fatura['cari_unvan'],
          fatura['depo_adi'],
          fatura['durum'],
        ].map((e) => e?.toString().toLowerCase() ?? '').join(' ');

        return metin.contains(q);
      }).toList();
    });
  }

  void _stokFiltrele() {
    final kelimeler = _stokAramaController.text
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    if (!mounted) return;

    setState(() {
      if (kelimeler.isEmpty) {
        _gorunenStoklar = [];
        return;
      }

      final bulunanlar = _stoklar.where((stok) {
        final metin = [
          stok['uretici_kodu'],
          stok['urun_adi'],
          stok['oem_no'],
          stok['barkod'],
          stok['marka'],
          stok['cross_kod'],
          stok['rakip_kod'],
          stok['raf'],
        ].map((e) => e?.toString().toLowerCase() ?? '').join(' ');

        return kelimeler.every(metin.contains);
      }).toList();

      final aranan = _stokAramaController.text.toLowerCase().trim();

      bulunanlar.sort((a, b) {
        final aKod = a['uretici_kodu']?.toString().toLowerCase() ?? '';
        final bKod = b['uretici_kodu']?.toString().toLowerCase() ?? '';

        final aTam = aKod == aranan ? 0 : 1;
        final bTam = bKod == aranan ? 0 : 1;

        if (aTam != bTam) return aTam.compareTo(bTam);

        final aBas = aKod.startsWith(aranan) ? 0 : 1;
        final bBas = bKod.startsWith(aranan) ? 0 : 1;

        if (aBas != bBas) return aBas.compareTo(bBas);

        return (a['urun_adi']?.toString() ?? '').compareTo(
          b['urun_adi']?.toString() ?? '',
        );
      });

      _gorunenStoklar = bulunanlar.take(30).toList();
    });
  }

  void _stokSec(Map<String, dynamic> stok) {
    setState(() {
      _secilenStokId = _int(stok['stok_id']);
      _stokAramaController.text = _metin(stok['uretici_kodu']) == '-'
          ? _metin(stok['urun_adi'])
          : _metin(stok['uretici_kodu']);
      _gorunenStoklar = [];
      _faturaId = null;
      _detaylar = [];
    });

    _faturaFiltrele();
  }

  void _stokFiltresiniTemizle() {
    setState(() {
      _secilenStokId = null;
      _stokAramaController.clear();
      _gorunenStoklar = [];
      _faturaId = null;
      _detaylar = [];
    });

    _faturaFiltrele();
  }

  Map<String, dynamic>? get _secilenStok {
    final stokId = _secilenStokId;

    if (stokId == null) return null;

    for (final stok in _stoklar) {
      if (_int(stok['stok_id']) == stokId) {
        return stok;
      }
    }

    return null;
  }

  Future<void> _tipDegistir(String tip) async {
    for (final controller in _miktarControllerlari.values) {
      controller.dispose();
    }

    setState(() {
      _iadeTipi = tip;
      _cariId = null;
      _faturaId = null;
      _depoId = null;
      _secilenStokId = null;
      _stokAramaController.clear();
      _gorunenStoklar = [];
      _detaylar = [];
      _miktarControllerlari.clear();
    });

    try {
      await _faturalariYukle();
      if (mounted) setState(() {});
    } catch (e) {
      _mesaj('Faturalar yüklenemedi: $e', Colors.red);
    }
  }

  Future<void> _faturaSec(Map<String, dynamic> fatura) async {
    final faturaId = _int(fatura[_faturaIdKolonu]);

    if (faturaId <= 0) return;

    for (final controller in _miktarControllerlari.values) {
      controller.dispose();
    }

    setState(() {
      _detayYukleniyor = true;
      _faturaId = faturaId;
      _cariId = _int(fatura['cari_id']);
      _depoId = _int(fatura['depo_id']);
      _detaylar = [];
      _miktarControllerlari.clear();
    });

    try {
      final sonuclar = await Future.wait([
        SupabaseService.supabase
            .from(_detayTablosu)
            .select()
            .eq(_faturaIdKolonu, faturaId),
        SupabaseService.supabase
            .from('stoklar')
            .select('stok_id, urun_adi, uretici_kodu, oem_no, raf'),
        SupabaseService.supabase
            .from('iade_baslik')
            .select('iade_id')
            .eq('iade_tipi', _iadeTipi)
            .eq('kaynak_fatura_id', faturaId)
            .neq('durum', 'IPTAL'),
      ]);

      final detaylar = List<Map<String, dynamic>>.from(sonuclar[0] as List);

      final stoklar = List<Map<String, dynamic>>.from(sonuclar[1] as List);

      final oncekiBasliklar = List<Map<String, dynamic>>.from(
        sonuclar[2] as List,
      );

      final stokMap = <int, Map<String, dynamic>>{
        for (final stok in stoklar) _int(stok['stok_id']): stok,
      };

      final oncekiMap = <int, double>{};

      if (oncekiBasliklar.isNotEmpty) {
        final ids = oncekiBasliklar
            .map((e) => _int(e['iade_id']))
            .where((e) => e > 0)
            .toList();

        if (ids.isNotEmpty) {
          final oncekiDetayResponse = await SupabaseService.supabase
              .from('iade_detay')
              .select('stok_id, miktar')
              .inFilter('iade_id', ids);

          for (final item in List<Map<String, dynamic>>.from(
            oncekiDetayResponse,
          )) {
            final stokId = _int(item['stok_id']);
            oncekiMap[stokId] =
                (oncekiMap[stokId] ?? 0) + _sayi(item['miktar']);
          }
        }
      }

      final birlesik = <int, Map<String, dynamic>>{};

      for (final detay in detaylar) {
        final stokId = _int(detay['stok_id']);

        final satir = birlesik.putIfAbsent(
          stokId,
          () => {...detay, 'miktar': 0.0},
        );

        satir['miktar'] = _sayi(satir['miktar']) + _sayi(detay['miktar']);
      }

      for (final entry in birlesik.entries) {
        final stok = stokMap[entry.key];
        final detay = entry.value;
        final onceki = oncekiMap[entry.key] ?? 0;
        final kalan = _sayi(detay['miktar']) - onceki;

        detay['urun_adi'] = stok?['urun_adi'] ?? '-';
        detay['uretici_kodu'] = stok?['uretici_kodu'] ?? '-';
        detay['oem_no'] = stok?['oem_no'] ?? '-';
        detay['raf'] = stok?['raf'] ?? '-';
        detay['onceki_iade'] = onceki;
        detay['kalan_iade'] = kalan < 0 ? 0 : kalan;

        _miktarControllerlari[entry.key] = TextEditingController(text: '0');
      }

      if (!mounted) return;

      setState(() {
        _detaylar = birlesik.values
            .where((e) => _sayi(e['kalan_iade']) > 0)
            .toList();
        _detayYukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _detayYukleniyor = false);
      _mesaj('Fatura kalemleri yüklenemedi: $e', Colors.red);
    }
  }

  double _satirToplam(Map<String, dynamic> detay) {
    final stokId = _int(detay['stok_id']);
    final miktar =
        double.tryParse(
          _miktarControllerlari[stokId]?.text.replaceAll(',', '.') ?? '0',
        ) ??
        0;

    final fiyat = _sayi(detay['birim_fiyat']);
    final indirim = _sayi(detay['indirim'] ?? detay['indirim_orani']);
    final kdv = _sayi(detay['kdv_orani']);

    final brut = miktar * fiyat;
    final matrah = brut - (brut * indirim / 100);

    return matrah + (matrah * kdv / 100);
  }

  double get _genelToplam {
    return _detaylar.fold<double>(
      0,
      (toplam, detay) => toplam + _satirToplam(detay),
    );
  }

  Future<void> _kaydet() async {
    if (_kaydediliyor) return;

    if (_cariId == null || _faturaId == null || _depoId == null) {
      _mesaj('Önce cari ve fatura seçmelisiniz.', Colors.orange);
      return;
    }

    final secilenler = <Map<String, dynamic>>[];

    for (final detay in _detaylar) {
      final stokId = _int(detay['stok_id']);
      final miktar =
          double.tryParse(
            _miktarControllerlari[stokId]?.text.replaceAll(',', '.') ?? '0',
          ) ??
          0;

      if (miktar <= 0) continue;

      if (miktar > _sayi(detay['kalan_iade'])) {
        _mesaj(
          '${_metin(detay['urun_adi'])} için miktar kalan iade miktarını aşıyor.',
          Colors.orange,
        );
        return;
      }

      secilenler.add({
        'stok_id': stokId,
        'miktar': miktar,
        'birim_fiyat': _sayi(detay['birim_fiyat']),
        'indirim': _sayi(detay['indirim'] ?? detay['indirim_orani']),
        'kdv_orani': _sayi(detay['kdv_orani']),
        'neden': _aciklamaController.text.trim(),
      });
    }

    if (secilenler.isEmpty) {
      _mesaj('En az bir ürüne iade miktarı girin.', Colors.orange);
      return;
    }

    setState(() => _kaydediliyor = true);

    try {
      await SupabaseService.supabase.rpc(
        'faturaya_bagli_iade_olustur',
        params: {
          'p_iade_tipi': _iadeTipi,
          'p_kaynak_fatura_id': _faturaId,
          'p_cari_id': _cariId,
          'p_depo_id': _depoId,
          'p_aciklama': _aciklamaController.text.trim(),
          'p_kullanici': YetkiService.aktifKullanici,
          'p_detaylar': secilenler,
        },
      );

      if (!mounted) return;

      _mesaj(
        _iadeTipi == 'SATIS_IADE'
            ? 'Satış iadesi kaydedildi ve ürünler İade Deposuna alındı.'
            : 'Alış iadesi kaydedildi ve ürünler seçili depodan çıkarıldı.',
        Colors.green,
      );

      setState(() {
        _faturaId = null;
        _detaylar = [];
        _miktarControllerlari.clear();
        _aciklamaController.clear();
      });

      await _verileriYukle();
    } catch (e) {
      if (!mounted) return;
      _mesaj('İade kayıt hatası: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _kaydediliyor = false);
      }
    }
  }

  void _mesaj(String mesaj, Color renk) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mesaj), backgroundColor: renk));
  }

  Widget _faturaKarti(Map<String, dynamic> fatura) {
    final id = _int(fatura[_faturaIdKolonu]);
    final secili = id == _faturaId;

    return Card(
      elevation: 0,
      color: secili ? Colors.blue.withOpacity(0.08) : null,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: secili ? Colors.blue : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            _iadeTipi == 'SATIS_IADE'
                ? Icons.receipt_long_rounded
                : Icons.shopping_cart_rounded,
          ),
        ),
        title: Text(
          _metin(fatura['fatura_no']),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_metin(fatura['cari_unvan'])}\n'
          '${_tarih(fatura['tarih'])} • '
          '${_metin(fatura['depo_adi'])}',
        ),
        isThreeLine: true,
        trailing: Text(
          _para(fatura['genel_toplam']),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onTap: () => _faturaSec(fatura),
      ),
    );
  }

  Widget _stokSonucKarti(Map<String, dynamic> stok) {
    final stokId = _int(stok['stok_id']);
    final faturaSayisi = _stokFaturaIds[stokId]?.length ?? 0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(9),
      ),
      child: ListTile(
        dense: true,
        leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
        title: Text(
          _metin(stok['urun_adi']),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Kod: ${_metin(stok['uretici_kodu'])} • '
          'OEM: ${_metin(stok['oem_no'])}\n'
          'Mevcut: ${_miktar(stok['stok_miktari'])} • '
          '$faturaSayisi Fatura',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () => _stokSec(stok),
      ),
    );
  }

  Widget _secilenStokKarti(Map<String, dynamic> stok) {
    final stokId = _int(stok['stok_id']);
    final faturaSayisi = _stokFaturaIds[stokId]?.length ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        border: Border.all(color: Colors.orange.withOpacity(0.45)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: MobilYatayRow(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFFFE0B2),
            child: Icon(Icons.inventory_2_rounded, color: Colors.deepOrange),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _metin(stok['urun_adi']),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Üretici Kodu: '
                  '${_metin(stok['uretici_kodu'])}',
                ),
                Text(
                  'OEM: ${_metin(stok['oem_no'])} • '
                  'Stok: ${_miktar(stok['stok_miktari'])} • '
                  '$faturaSayisi Fatura',
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Stok filtresini kaldır',
            onPressed: _stokFiltresiniTemizle,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _mobilIadeTipiSecici() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'SATIS_IADE',
              label: Text('Satış İadesi'),
              icon: Icon(Icons.keyboard_return_rounded),
            ),
            ButtonSegment(
              value: 'ALIS_IADE',
              label: Text('Alış İadesi'),
              icon: Icon(Icons.outbox_rounded),
            ),
          ],
          selected: {_iadeTipi},
          onSelectionChanged: (value) => _tipDegistir(value.first),
          showSelectedIcon: false,
        ),
      ),
    );
  }

  Widget _mobilFaturaSecimi(List<Map<String, dynamic>> cariFaturalari) {
    return Column(
      children: [
        _mobilIadeTipiSecici(),
        Padding(
          padding: const EdgeInsets.all(10),
          child: DropdownButtonFormField<int?>(
            value: _cariId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Cari Seç',
              prefixIcon: Icon(Icons.people_rounded),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Tüm Cariler'),
              ),
              ..._cariler.map(
                (cari) => DropdownMenuItem<int?>(
                  value: _int(cari['cari_id']),
                  child: Text(
                    _metin(cari['unvan']),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _cariId = value;
                _faturaId = null;
                _detaylar = [];
              });
              _faturaFiltrele();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: TextField(
            controller: _stokAramaController,
            onSubmitted: (_) {
              if (_gorunenStoklar.isNotEmpty) {
                _stokSec(_gorunenStoklar.first);
              }
            },
            decoration: InputDecoration(
              labelText: 'Stok Kartından Fatura Bul',
              hintText: 'Üretici kodu, ürün adı, OEM...',
              prefixIcon: const Icon(Icons.inventory_2_outlined),
              suffixIcon:
                  _secilenStokId == null && _stokAramaController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _stokFiltresiniTemizle,
                      icon: const Icon(Icons.clear_rounded),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        if (_secilenStok != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Card(
              color: Colors.orange.withOpacity(0.08),
              child: ListTile(
                leading: const Icon(
                  Icons.inventory_2_rounded,
                  color: Colors.deepOrange,
                ),
                title: Text(
                  _metin(_secilenStok!['urun_adi']),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('Kod: ${_metin(_secilenStok!['uretici_kodu'])}'),
                trailing: IconButton(
                  onPressed: _stokFiltresiniTemizle,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ),
        if (_secilenStokId == null &&
            _stokAramaController.text.trim().isNotEmpty)
          SizedBox(
            height: 170,
            child: _gorunenStoklar.isEmpty
                ? const Center(child: Text('Uygun stok kartı bulunamadı.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: _gorunenStoklar.length,
                    itemBuilder: (_, index) =>
                        _stokSonucKarti(_gorunenStoklar[index]),
                  ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: TextField(
            controller: _aramaController,
            decoration: const InputDecoration(
              labelText: 'Fatura Ara',
              hintText: 'Fatura no veya cari ara...',
              prefixIcon: Icon(Icons.search_rounded),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: cariFaturalari.isEmpty
              ? const Center(
                  child: Text(
                    'Seçime uygun fatura bulunamadı.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 90),
                  itemCount: cariFaturalari.length,
                  itemBuilder: (_, index) =>
                      _faturaKarti(cariFaturalari[index]),
                ),
        ),
      ],
    );
  }

  Widget _mobilIadeDetayi() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() {
                _faturaId = null;
                _detaylar = [];
              }),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Fatura Seçimine Dön'),
            ),
          ),
        ),
        Expanded(
          child: _detayYukleniyor
              ? const Center(child: CircularProgressIndicator())
              : _detaylar.isEmpty
              ? const Center(
                  child: Text(
                    'Bu faturada iade edilebilir ürün kalmamış.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: _detaylar.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final detay = _detaylar[index];
                    final stokId = _int(detay['stok_id']);
                    return Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _metin(detay['urun_adi']),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Kod: ${_metin(detay['uretici_kodu'])} • '
                              'RAF: ${_metin(detay['raf'])}',
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 14,
                              runSpacing: 5,
                              children: [
                                Text('Fatura: ${_miktar(detay['miktar'])}'),
                                Text(
                                  'Önceki: ${_miktar(detay['onceki_iade'])}',
                                ),
                                Text(
                                  'Kalan: ${_miktar(detay['kalan_iade'])}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _miktarControllerlari[stokId],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'İade Miktarı',
                                helperText:
                                    'Satır toplamı: ${_para(_satirToplam(detay))}',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _aciklamaController,
                  decoration: const InputDecoration(
                    labelText: 'İade Nedeni / Açıklama',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'GENEL: ${_para(_genelToplam)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _kaydediliyor ? null : _kaydet,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(
                        _kaydediliyor ? 'Kaydediliyor...' : 'İadeyi Kaydet',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cariFaturalari = _gorunenFaturalar;
    final mobil = MobilUyum.telefon(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _ekranBasligi,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: mobil
            ? [
                IconButton(
                  onPressed: _yukleniyor ? null : _verileriYukle,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ]
            : [
                MobilAppBarActions(
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'SATIS_IADE',
                          label: Text('Satış İadesi'),
                          icon: Icon(Icons.keyboard_return_rounded),
                        ),
                        ButtonSegment(
                          value: 'ALIS_IADE',
                          label: Text('Alış İadesi'),
                          icon: Icon(Icons.outbox_rounded),
                        ),
                      ],
                      selected: {_iadeTipi},
                      onSelectionChanged: (value) {
                        _tipDegistir(value.first);
                      },
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: _yukleniyor ? null : _verileriYukle,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : mobil
          ? (_faturaId == null
                ? _mobilFaturaSecimi(cariFaturalari)
                : _mobilIadeDetayi())
          : MobilYatayRow(
              children: [
                SizedBox(
                  width: 470,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: DropdownButtonFormField<int?>(
                          value: _cariId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Cari Seç',
                            prefixIcon: Icon(Icons.people_rounded),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Tüm Cariler'),
                            ),
                            ..._cariler.map(
                              (cari) => DropdownMenuItem<int?>(
                                value: _int(cari['cari_id']),
                                child: Text(_metin(cari['unvan'])),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _cariId = value;
                              _faturaId = null;
                              _detaylar = [];
                            });
                            _faturaFiltrele();
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        child: TextField(
                          controller: _stokAramaController,
                          onSubmitted: (_) {
                            if (_gorunenStoklar.isNotEmpty) {
                              _stokSec(_gorunenStoklar.first);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Stok Kartından Fatura Bul',
                            hintText: 'Üretici kodu, ürün adı, OEM, barkod...',
                            prefixIcon: const Icon(Icons.inventory_2_outlined),
                            suffixIcon:
                                _secilenStokId == null &&
                                    _stokAramaController.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: _stokFiltresiniTemizle,
                                    icon: const Icon(Icons.clear_rounded),
                                  ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      if (_secilenStok != null)
                        _secilenStokKarti(_secilenStok!),
                      if (_secilenStokId == null &&
                          _stokAramaController.text.trim().isNotEmpty)
                        Container(
                          height: 240,
                          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _gorunenStoklar.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Bu aramaya uygun stok kartı bulunamadı.',
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _gorunenStoklar.length,
                                  itemBuilder: (_, index) {
                                    return _stokSonucKarti(
                                      _gorunenStoklar[index],
                                    );
                                  },
                                ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        child: TextField(
                          controller: _aramaController,
                          decoration: const InputDecoration(
                            labelText: 'Fatura Ara',
                            hintText: 'Fatura no veya cari ara...',
                            prefixIcon: Icon(Icons.search_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Expanded(
                        child: cariFaturalari.isEmpty
                            ? Center(
                                child: Text(
                                  _secilenStokId != null
                                      ? 'Bu stok kartının seçili cari için faturası bulunamadı.\n'
                                            'Cari filtresini “Tüm Cariler” yaparak tekrar deneyin.'
                                      : 'Seçime uygun fatura bulunamadı.',
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                itemCount: cariFaturalari.length,
                                itemBuilder: (_, index) {
                                  return _faturaKarti(cariFaturalari[index]);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      if (_faturaId == null)
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Soldan üretici koduyla stok kartını bulun veya cari/fatura seçin.',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      else if (_detayYukleniyor)
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        Expanded(
                          child: _detaylar.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Bu faturada iade edilebilir ürün kalmamış.',
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _detaylar.length,
                                  separatorBuilder: (_, __) => const Divider(),
                                  itemBuilder: (_, index) {
                                    final detay = _detaylar[index];
                                    final stokId = _int(detay['stok_id']);

                                    return MobilYatayRow(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _metin(detay['urun_adi']),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                'Kod: ${_metin(detay['uretici_kodu'])} • '
                                                'RAF: ${_metin(detay['raf'])}',
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            'Fatura\n${_miktar(detay['miktar'])}',
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            'Önceki\n${_miktar(detay['onceki_iade'])}',
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            'Kalan\n${_miktar(detay['kalan_iade'])}',
                                          ),
                                        ),
                                        SizedBox(
                                          width: 125,
                                          child: TextField(
                                            controller:
                                                _miktarControllerlari[stokId],
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            decoration: const InputDecoration(
                                              labelText: 'İade Miktarı',
                                              border: OutlineInputBorder(),
                                            ),
                                            onChanged: (_) {
                                              setState(() {});
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 18),
                                        SizedBox(
                                          width: 125,
                                          child: Text(
                                            _para(_satirToplam(detay)),
                                            textAlign: TextAlign.end,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: MobilYatayRow(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _aciklamaController,
                                  decoration: const InputDecoration(
                                    labelText: 'İade Nedeni / Açıklama',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'GENEL: ${_para(_genelToplam)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _kaydediliyor ? null : _kaydet,
                                icon: const Icon(Icons.save_rounded),
                                label: Text(
                                  _kaydediliyor
                                      ? 'Kaydediliyor...'
                                      : 'İadeyi Kaydet',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
