import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/doviz_kur_service.dart';

class HesapMakinesiSayfasi extends StatefulWidget {
  final bool dialogModu;

  const HesapMakinesiSayfasi({
    super.key,
    this.dialogModu = false,
  });

  static Future<void> dialogAc(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final boyut = MediaQuery.of(dialogContext).size;
        final mobil = boyut.width < 720;
        return Dialog(
          insetPadding: EdgeInsets.all(mobil ? 8 : 24),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: mobil ? boyut.width : 980,
            height: mobil ? boyut.height * 0.94 : 720,
            child: const HesapMakinesiSayfasi(dialogModu: true),
          ),
        );
      },
    );
  }

  @override
  State<HesapMakinesiSayfasi> createState() => _HesapMakinesiSayfasiState();
}

class _HesapMakinesiSayfasiState extends State<HesapMakinesiSayfasi>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final FocusNode _klavyeFocus = FocusNode();
  final TextEditingController _ifadeController = TextEditingController();
  final TextEditingController _tutarController = TextEditingController(text: '0');
  final TextEditingController _oranController = TextEditingController(text: '20');
  final TextEditingController _dovizTutarController = TextEditingController(text: '1');

  String _sonuc = '0';
  final List<String> _gecmis = <String>[];
  List<Map<String, dynamic>> _kurlar = <Map<String, dynamic>>[];
  bool _kurYukleniyor = true;
  String _kaynakDoviz = 'USD';
  String _hedefDoviz = 'TRY';
  String _kurTipi = 'SATIS';

  static const _lacivert = Color(0xFF123653);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _kurlariYukle();
    WidgetsBinding.instance.addPostFrameCallback((_) => _klavyeFocus.requestFocus());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _klavyeFocus.dispose();
    _ifadeController.dispose();
    _tutarController.dispose();
    _oranController.dispose();
    _dovizTutarController.dispose();
    super.dispose();
  }

  double _sayi(String text) {
    final ham = text.trim();
    if (ham.contains(',')) {
      return double.tryParse(ham.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
    }
    return double.tryParse(ham) ?? 0;
  }

  String _format(double value) {
    if (!value.isFinite) return 'Hata';
    var s = value.toStringAsFixed(6);
    s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    return s.isEmpty ? '0' : s;
  }

  Future<void> _kurlariYukle() async {
    if (!mounted) return;
    setState(() => _kurYukleniyor = true);
    try {
      final liste = await DovizKurService.bugununKurlariGetir();
      if (!mounted) return;
      setState(() => _kurlar = liste);
    } catch (_) {
      // Hesap makinesi kur servisi yüzünden açılışı engellemez.
    } finally {
      if (mounted) setState(() => _kurYukleniyor = false);
    }
  }

  void _ekle(String deger) {
    final c = _ifadeController;
    final secim = c.selection;
    final bas = secim.isValid ? secim.start : c.text.length;
    final son = secim.isValid ? secim.end : c.text.length;
    final yeni = c.text.replaceRange(bas, son, deger);
    c.value = TextEditingValue(
      text: yeni,
      selection: TextSelection.collapsed(offset: bas + deger.length),
    );
  }

  void _sil() {
    final c = _ifadeController;
    if (c.text.isEmpty) return;
    final secim = c.selection;
    if (secim.isValid && !secim.isCollapsed) {
      final yeni = c.text.replaceRange(secim.start, secim.end, '');
      c.value = TextEditingValue(
        text: yeni,
        selection: TextSelection.collapsed(offset: secim.start),
      );
      return;
    }
    final pos = secim.isValid ? secim.start : c.text.length;
    if (pos <= 0) return;
    final yeni = c.text.replaceRange(pos - 1, pos, '');
    c.value = TextEditingValue(
      text: yeni,
      selection: TextSelection.collapsed(offset: pos - 1),
    );
  }

  void _temizle() {
    _ifadeController.clear();
    setState(() => _sonuc = '0');
  }

  void _hesapla() {
    try {
      final ifade = _ifadeController.text.trim();
      if (ifade.isEmpty) return;
      final deger = _IfadeCozucu(ifade).coz();
      final sonuc = _format(deger);
      setState(() {
        _sonuc = sonuc;
        _gecmis.insert(0, '$ifade = $sonuc');
        if (_gecmis.length > 50) _gecmis.removeLast();
      });
    } catch (_) {
      setState(() => _sonuc = 'Hata');
    }
  }

  void _ticariHesap(String tip) {
    final tutar = _sayi(_tutarController.text);
    final oran = _sayi(_oranController.text);
    double sonuc;
    String aciklama;
    switch (tip) {
      case 'KDV_EKLE':
        sonuc = tutar * (1 + oran / 100);
        aciklama = '$tutar + %$oran KDV';
        break;
      case 'KDV_CIKAR':
        sonuc = oran == -100 ? 0 : tutar / (1 + oran / 100);
        aciklama = '$tutar içinden %$oran KDV çıkar';
        break;
      case 'ISKONTO':
        sonuc = tutar * (1 - oran / 100);
        aciklama = '$tutar - %$oran iskonto';
        break;
      case 'KAR':
        sonuc = tutar * (1 + oran / 100);
        aciklama = '$tutar + %$oran kâr';
        break;
      case 'MARJ':
        sonuc = oran >= 100 ? 0 : tutar / (1 - oran / 100);
        aciklama = '$tutar maliyet, %$oran marj';
        break;
      default:
        return;
    }
    final metin = _format(sonuc);
    setState(() {
      _sonuc = metin;
      _gecmis.insert(0, '$aciklama = $metin');
    });
  }

  Map<String, dynamic>? _kurSatiri(String kod) {
    if (kod == 'TRY') return null;
    for (final row in _kurlar) {
      if ((row['para_birimi']?.toString().toUpperCase() ?? '') == kod) return row;
    }
    return null;
  }

  double _tlKarsiligi(String kod, String tip) {
    if (kod == 'TRY') return 1;
    final row = _kurSatiri(kod);
    if (row == null) return 0;
    final alan = tip == 'ALIS' ? 'alis' : 'satis';
    return double.tryParse(row[alan]?.toString() ?? '') ?? 0;
  }

  void _dovizCevir() {
    final miktar = _sayi(_dovizTutarController.text);
    final kaynakKur = _tlKarsiligi(_kaynakDoviz, _kurTipi);
    final hedefKur = _tlKarsiligi(_hedefDoviz, _kurTipi);
    if (kaynakKur <= 0 || hedefKur <= 0) {
      _mesaj('Seçilen döviz için bugünün kuru bulunamadı.', hata: true);
      return;
    }
    final tl = miktar * kaynakKur;
    final sonuc = tl / hedefKur;
    final metin = _format(sonuc);
    setState(() {
      _sonuc = metin;
      _gecmis.insert(0, '$miktar $_kaynakDoviz → $metin $_hedefDoviz ($_kurTipi)');
    });
  }

  void _mesaj(String mesaj, {bool hata = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: hata ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  KeyEventResult _klavye(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _hesapla();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (widget.dialogModu) Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final mobil = MediaQuery.of(context).size.width < 720;
    final govde = Column(
      children: [
        _ustBaslik(mobil),
        Material(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: mobil,
            tabs: const [
              Tab(icon: Icon(Icons.calculate_outlined), text: 'Normal'),
              Tab(icon: Icon(Icons.percent_rounded), text: 'Ticari'),
              Tab(icon: Icon(Icons.currency_exchange_rounded), text: 'Döviz'),
              Tab(icon: Icon(Icons.history_rounded), text: 'Geçmiş'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _normal(mobil),
              _ticari(mobil),
              _doviz(mobil),
              _gecmisWidget(),
            ],
          ),
        ),
      ],
    );

    return Focus(
      focusNode: _klavyeFocus,
      onKeyEvent: (_, event) => _klavye(event),
      child: widget.dialogModu
          ? Material(color: const Color(0xFFF4F6F9), child: govde)
          : Scaffold(
              backgroundColor: const Color(0xFFF4F6F9),
              body: SafeArea(child: govde),
            ),
    );
  }

  Widget _ustBaslik(bool mobil) {
    return Container(
      padding: EdgeInsets.fromLTRB(mobil ? 14 : 20, 12, 10, 12),
      color: _lacivert,
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white12,
            child: Icon(Icons.calculate_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ERP HESAP MAKİNESİ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text('Normal • KDV • İskonto • Kâr • Döviz', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          if (widget.dialogModu)
            IconButton(
              tooltip: 'Kapat',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _sonucKutusu() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('SONUÇ', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                SelectableText(_sonuc, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sonucu kopyala',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _sonuc));
              if (mounted) _mesaj('Sonuç panoya kopyalandı.');
            },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    );
  }

  Widget _normal(bool mobil) {
    final tuslar = <String>[
      'C', '(', ')', '⌫',
      '7', '8', '9', '÷',
      '4', '5', '6', '×',
      '1', '2', '3', '-',
      '0', ',', '%', '+',
    ];
    return SingleChildScrollView(
      padding: EdgeInsets.all(mobil ? 10 : 18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              TextField(
                controller: _ifadeController,
                autofocus: true,
                style: const TextStyle(fontSize: 24),
                decoration: const InputDecoration(
                  labelText: 'İşlem',
                  hintText: 'Örnek: (1250 + 250) × 1,20',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _hesapla(),
              ),
              const SizedBox(height: 12),
              _sonucKutusu(),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 2.0,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: tuslar.length,
                itemBuilder: (_, i) {
                  final t = tuslar[i];
                  final operator = <String>{'÷', '×', '-', '+', '%', '(', ')'}.contains(t);
                  return FilledButton.tonal(
                    onPressed: () {
                      if (t == 'C') return _temizle();
                      if (t == '⌫') return _sil();
                      _ekle(t == '×' ? '*' : t == '÷' ? '/' : t == ',' ? '.' : t);
                    },
                    style: FilledButton.styleFrom(
                      textStyle: TextStyle(fontSize: operator ? 20 : 18, fontWeight: FontWeight.w600),
                    ),
                    child: Text(t),
                  );
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _hesapla,
                  icon: const Icon(Icons.drag_handle_rounded),
                  label: const Text('HESAPLA', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ticari(bool mobil) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(mobil ? 10 : 18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              _sonucKutusu(),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _tutarController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Tutar / Maliyet', prefixText: '₺ ', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _oranController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Oran', suffixText: '%', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final o in const [1, 10, 20])
                            ActionChip(label: Text('%$o'), onPressed: () => setState(() => _oranController.text = '$o')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _ticariButon('KDV Ekle', Icons.add_circle_outline, () => _ticariHesap('KDV_EKLE')),
                      _ticariButon('KDV Çıkar', Icons.remove_circle_outline, () => _ticariHesap('KDV_CIKAR')),
                      _ticariButon('İskonto Uygula', Icons.percent_rounded, () => _ticariHesap('ISKONTO')),
                      _ticariButon('Kâr Ekle', Icons.trending_up_rounded, () => _ticariHesap('KAR')),
                      _ticariButon('Hedef Marjdan Satış Fiyatı', Icons.show_chart_rounded, () => _ticariHesap('MARJ')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ticariButon(String baslik, IconData ikon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        height: 46,
        child: OutlinedButton.icon(onPressed: onPressed, icon: Icon(ikon), label: Text(baslik)),
      ),
    );
  }

  Widget _doviz(bool mobil) {
    const kodlar = <String>['TRY', 'USD', 'EUR', 'GBP', 'CHF', 'JPY'];
    return SingleChildScrollView(
      padding: EdgeInsets.all(mobil ? 10 : 18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              _sonucKutusu(),
              const SizedBox(height: 16),
              if (_kurYukleniyor) const LinearProgressIndicator(),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _dovizTutarController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Miktar', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _dovizSec('Kaynak', _kaynakDoviz, kodlar, (v) => setState(() => _kaynakDoviz = v!))),
                          IconButton(
                            tooltip: 'Yer değiştir',
                            onPressed: () => setState(() {
                              final x = _kaynakDoviz;
                              _kaynakDoviz = _hedefDoviz;
                              _hedefDoviz = x;
                            }),
                            icon: const Icon(Icons.swap_horiz_rounded),
                          ),
                          Expanded(child: _dovizSec('Hedef', _hedefDoviz, kodlar, (v) => setState(() => _hedefDoviz = v!))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'ALIS', label: Text('TCMB Alış')),
                          ButtonSegment(value: 'SATIS', label: Text('TCMB Satış')),
                        ],
                        selected: <String>{_kurTipi},
                        onSelectionChanged: (s) => setState(() => _kurTipi = s.first),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _dovizCevir,
                          icon: const Icon(Icons.currency_exchange_rounded),
                          label: const Text('DÖVİZ ÇEVİR'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _kurlariYukle,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Bugünün TCMB kurlarını yenile'),
                      ),
                    ],
                  ),
                ),
              ),
              if (_kurlar.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Bugünün kurları', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _kurlar.map((e) => Chip(label: Text('${e['para_birimi']}  A:${e['alis']}  S:${e['satis']}'))).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _dovizSec(String label, String value, List<String> kodlar, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: kodlar.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _gecmisWidget() {
    if (_gecmis.isEmpty) {
      return const Center(child: Text('Henüz hesaplama geçmişi yok.'));
    }
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(_gecmis.clear),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Geçmişi temizle'),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: _gecmis.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => ListTile(
              leading: const Icon(Icons.history_rounded),
              title: SelectableText(_gecmis[i]),
              trailing: IconButton(
                tooltip: 'Kopyala',
                onPressed: () => Clipboard.setData(ClipboardData(text: _gecmis[i])),
                icon: const Icon(Icons.copy_outlined),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IfadeCozucu {
  final String kaynak;
  int _i = 0;

  _IfadeCozucu(String text)
      : kaynak = text
            .replaceAll(',', '.')
            .replaceAll('×', '*')
            .replaceAll('÷', '/')
            .replaceAll(' ', '');

  double coz() {
    final v = _ifade();
    if (_i != kaynak.length) throw const FormatException('Geçersiz ifade');
    return v;
  }

  double _ifade() {
    var v = _terim();
    while (_i < kaynak.length) {
      if (_al('+')) {
        v += _terim();
      } else if (_al('-')) {
        v -= _terim();
      } else {
        break;
      }
    }
    return v;
  }

  double _terim() {
    var v = _faktor();
    while (_i < kaynak.length) {
      if (_al('*')) {
        v *= _faktor();
      } else if (_al('/')) {
        final d = _faktor();
        if (d == 0) throw const FormatException('Sıfıra bölme');
        v /= d;
      } else {
        break;
      }
    }
    return v;
  }

  double _faktor() {
    if (_al('+')) return _faktor();
    if (_al('-')) return -_faktor();
    double v;
    if (_al('(')) {
      v = _ifade();
      if (!_al(')')) throw const FormatException('Parantez eksik');
    } else {
      v = _sayi();
    }
    while (_al('%')) {
      v /= 100;
    }
    return v;
  }

  double _sayi() {
    final bas = _i;
    var nokta = false;
    while (_i < kaynak.length) {
      final c = kaynak[_i];
      if (c == '.') {
        if (nokta) break;
        nokta = true;
        _i++;
      } else if (RegExp(r'[0-9]').hasMatch(c)) {
        _i++;
      } else {
        break;
      }
    }
    if (bas == _i) throw const FormatException('Sayı bekleniyor');
    return double.parse(kaynak.substring(bas, _i));
  }

  bool _al(String c) {
    if (_i < kaynak.length && kaynak[_i] == c) {
      _i++;
      return true;
    }
    return false;
  }
}
