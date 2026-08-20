from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_method(path: str, signature: str, replacement: str):
    p = ROOT / path
    s = p.read_text(encoding='utf-8')
    start = s.find(signature)
    if start < 0:
        raise RuntimeError(f'{path}: method not found: {signature}')
    brace = s.find('{', start)
    if brace < 0:
        raise RuntimeError(f'{path}: opening brace not found')
    depth = 0
    quote = None
    escape = False
    i = brace
    end = None
    while i < len(s):
        c = s[i]
        if quote:
            if escape:
                escape = False
            elif c == '\\':
                escape = True
            elif c == quote:
                quote = None
        else:
            if c in ('\'', '"'):
                quote = c
            elif c == '{':
                depth += 1
            elif c == '}':
                depth -= 1
                if depth == 0:
                    end = i + 1
                    break
        i += 1
    if end is None:
        raise RuntimeError(f'{path}: method closing brace not found')
    s = s[:start] + replacement.rstrip() + s[end:]
    p.write_text(s, encoding='utf-8')


def insert_before(path: str, anchor: str, block: str, guard: str):
    p = ROOT / path
    s = p.read_text(encoding='utf-8')
    if guard in s:
        return
    idx = s.find(anchor)
    if idx < 0:
        raise RuntimeError(f'{path}: anchor not found: {anchor}')
    s = s[:idx] + block.rstrip() + '\n\n' + s[idx:]
    p.write_text(s, encoding='utf-8')


# 1) CARI KARTLARI: mobile summary cards become one compact row.
insert_before(
    'lib/screens/cariler_sayfasi.dart',
    '  Widget _cariKarti(Map<String, dynamic> cari) {',
    r'''  Widget _mobilCariOzet({
    required String baslik,
    required String deger,
    required IconData ikon,
    required Color renk,
  }) {
    return Expanded(
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: renk.withOpacity(0.20)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: renk.withOpacity(0.12),
              child: Icon(ikon, color: renk, size: 16),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    baslik,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 9.5),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      deger,
                      maxLines: 1,
                      style: TextStyle(
                        color: renk,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }''',
    '_mobilCariOzet({',
)

# Replace only the summary area in build by textual bounds.
p = ROOT / 'lib/screens/cariler_sayfasi.dart'
s = p.read_text(encoding='utf-8')
start = s.find("          Padding(\n            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),\n            child: MobilYatayRow(")
end_anchor = "          Container(\n            color: Colors.white,"
end = s.find(end_anchor, start)
if start < 0 or end < 0:
    raise RuntimeError('cariler_sayfasi.dart: summary block not found')
new_summary = r'''          Padding(
            padding: EdgeInsets.fromLTRB(mobil ? 8 : 12, mobil ? 6 : 10, mobil ? 8 : 12, 4),
            child: mobil
                ? Row(
                    children: [
                      _mobilCariOzet(
                        baslik: 'Aktif',
                        deger: _aktifCariSayisi.toString(),
                        ikon: Icons.people,
                        renk: Colors.blue,
                      ),
                      const SizedBox(width: 5),
                      _mobilCariOzet(
                        baslik: 'Alacaklıyız',
                        deger: _para(_toplamCariAlacagimiz),
                        ikon: Icons.trending_up,
                        renk: Colors.green,
                      ),
                      const SizedBox(width: 5),
                      _mobilCariOzet(
                        baslik: 'Borçluyuz',
                        deger: _para(_toplamCariBorcumuz),
                        ikon: Icons.trending_down,
                        renk: Colors.red,
                      ),
                    ],
                  )
                : MobilYatayRow(
                    mobilDikey: true,
                    minWidth: 760,
                    children: [
                      _ozetKarti(
                        baslik: 'Aktif Cari',
                        deger: _aktifCariSayisi.toString(),
                        ikon: Icons.people,
                        renk: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      _ozetKarti(
                        baslik: 'ALACAKLIYIZ',
                        deger: _para(_toplamCariAlacagimiz),
                        ikon: Icons.trending_up,
                        renk: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      _ozetKarti(
                        baslik: 'BORÇLUYUZ',
                        deger: _para(_toplamCariBorcumuz),
                        ikon: Icons.trending_down,
                        renk: Colors.red,
                      ),
                    ],
                  ),
          ),
'''
s = s[:start] + new_summary + s[end:]
p.write_text(s, encoding='utf-8')

# Cari dialog: reserve room for action buttons on phone so balance/actions cannot overlap.
p = ROOT / 'lib/widgets/mobil_uyum.dart'
s = p.read_text(encoding='utf-8')
s = s.replace(
    "final maxHeight = math.max(320.0, ekran.height - 120.0).toDouble();",
    "final maxHeight = math.max(260.0, ekran.height - 260.0).toDouble();",
)
p.write_text(s, encoding='utf-8')

# 2) SALES INVOICE: collapse document header fields on mobile, leaving real stock search space.
replace_method(
    'lib/screens/satis_sayfasi.dart',
    '  Widget _darDuzen() {',
    r'''  Widget _darDuzen() {
    return Column(
      children: [
        _kurumsalFaturaBasligi(),
        Card(
          margin: const EdgeInsets.fromLTRB(8, 4, 8, 2),
          elevation: 0,
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            leading: const Icon(Icons.tune_rounded),
            title: const Text(
              'Belge Bilgileri',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Cari, depo, ödeme, kasa ve belge no',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 370),
                child: SingleChildScrollView(child: _ustBilgiler()),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: [
                const ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.search),
                  label: Text('Ürün Ara'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: const Icon(Icons.shopping_cart),
                  label: Text('Sepet (${_sepet.length})'),
                ),
              ],
              selected: {_aktifPanel},
              onSelectionChanged: (secim) {
                setState(() => _aktifPanel = secim.first);
              },
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _aktifPanel,
            children: [
              _aramaPaneli(),
              _sepetPaneli(),
            ],
          ),
        ),
        _altBolum(),
      ],
    );
  }''',
)

# 3) STOCK COUNT: true mobile card layout; no narrow product-name column.
replace_method(
    'lib/screens/sayim_screen.dart',
    '  @override\n  Widget build(BuildContext context) {',
    r'''  @override
  Widget build(BuildContext context) {
    final mobil = MediaQuery.sizeOf(context).width < 720;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('STOK SAYIMI', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (!mobil)
            ElevatedButton.icon(
              onPressed: _kaydediliyor ? null : _kaydet,
              icon: const Icon(Icons.save_rounded),
              label: Text(_kaydediliyor ? 'Kaydediliyor...' : 'Sayımı Kaydet'),
            )
          else
            IconButton(
              tooltip: 'Sayımı Kaydet',
              onPressed: _kaydediliyor ? null : _kaydet,
              icon: const Icon(Icons.save_rounded),
            ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: _yukleniyor ? null : _depoStoklariniYukle,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: mobil
                ? Column(
                    children: [
                      DropdownButtonFormField<int>(
                        value: _depoId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Depo', border: OutlineInputBorder()),
                        items: _depolar.map((depo) => DropdownMenuItem<int>(
                          value: int.tryParse(depo['depo_id'].toString()),
                          child: Text('${_metin(depo['depo_adi'])} (${_metin(depo['depo_tipi'])})', overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (value) async {
                          setState(() => _depoId = value);
                          await _depoStoklariniYukle();
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _aramaController,
                        decoration: InputDecoration(
                          hintText: 'Ürün, kod, OEM, marka, RAF ara...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _aramaController.text.isEmpty ? null : IconButton(onPressed: _aramaController.clear, icon: const Icon(Icons.clear_rounded)),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      SizedBox(
                        width: 320,
                        child: DropdownButtonFormField<int>(
                          value: _depoId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Depo', border: OutlineInputBorder()),
                          items: _depolar.map((depo) => DropdownMenuItem<int>(
                            value: int.tryParse(depo['depo_id'].toString()),
                            child: Text('${_metin(depo['depo_adi'])} (${_metin(depo['depo_tipi'])})'),
                          )).toList(),
                          onChanged: (value) async {
                            setState(() => _depoId = value);
                            await _depoStoklariniYukle();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(
                        controller: _aramaController,
                        decoration: InputDecoration(
                          hintText: 'Ürün, üretici kodu, OEM, marka, RAF ara...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _aramaController.text.isEmpty ? null : IconButton(onPressed: _aramaController.clear, icon: const Icon(Icons.clear_rounded)),
                          border: const OutlineInputBorder(),
                        ),
                      )),
                    ],
                  ),
          ),
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _gorunenStoklar.isEmpty
                    ? const Center(child: Text('Bu depoda sayılacak stok bulunamadı.', style: TextStyle(fontSize: 18)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _gorunenStoklar.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 7),
                        itemBuilder: (_, index) {
                          final item = _gorunenStoklar[index];
                          final stokId = int.tryParse(item['stok_id']?.toString() ?? '') ?? 0;
                          final sistem = _sayi(item['miktar']);
                          final controller = _sayimController[stokId];

                          if (mobil) {
                            return Card(
                              elevation: 0,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(_metin(item['urun_adi']), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Text('ÜRETİCİ KODU: ${_metin(item['uretici_kodu'])}', maxLines: 1, overflow: TextOverflow.ellipsis),
                                              Text('RAF: ${_metin(item['raf'])}', maxLines: 1, overflow: TextOverflow.ellipsis),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(.06), borderRadius: BorderRadius.circular(8)),
                                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                              const Text('Sistem', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                              Text(_miktar(sistem), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                            ]),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: TextField(
                                            controller: controller,
                                            textAlign: TextAlign.right,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: const InputDecoration(labelText: 'Sayılan', border: OutlineInputBorder(), isDense: true),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return Card(
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(children: [
                                const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(_metin(item['urun_adi']), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 3),
                                  Text('Kod: ${_metin(item['uretici_kodu'])} • RAF: ${_metin(item['raf'])}'),
                                ])),
                                SizedBox(width: 110, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  const Text('Sistem', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                  Text(_miktar(sistem), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                                ])),
                                const SizedBox(width: 18),
                                SizedBox(width: 150, child: TextField(
                                  controller: controller,
                                  textAlign: TextAlign.right,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'Sayılan', border: OutlineInputBorder(), isDense: true),
                                )),
                              ]),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }''',
)

# 4) CASH END-OF-DAY: mobile cards are vertical/responsive, not ListTile with huge trailing width.
replace_method(
    'lib/screens/kasa_gun_sonu_sayfasi.dart',
    '  @override\n  Widget build(BuildContext context) {',
    r'''  @override
  Widget build(BuildContext context) {
    final mobil = MobilUyum.telefon(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(mobil ? 'KASA GÜN SONU' : 'KASA GÜN SONU / MUTABAKAT'),
        actions: [
          MobilAppBarActions(children: [
            TextButton.icon(onPressed: _tarihSec, icon: const Icon(Icons.calendar_month_rounded), label: Text(_tarihAnahtari)),
            IconButton(tooltip: 'Yenile', onPressed: _yukle, icon: const Icon(Icons.refresh_rounded)),
          ]),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : _kasalar.isEmpty
              ? const Center(child: Text('Kasa/banka hesabı bulunamadı.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: _kasalar.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final kasa = _kasalar[index];
                    final id = int.tryParse(kasa['kasa_id']?.toString() ?? '') ?? 0;
                    final beklenen = _beklenen[id] ?? 0;
                    final kayit = _kayitlar[id];
                    final fark = _sayi(kayit?['fark']);
                    final renk = kayit == null ? Colors.orange : fark.abs() < 0.01 ? Colors.green : Colors.red;
                    final ikon = kayit == null ? Icons.pending_actions_rounded : fark.abs() < 0.01 ? Icons.verified_rounded : Icons.warning_amber_rounded;

                    if (mobil) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                CircleAvatar(backgroundColor: renk.withOpacity(.12), child: Icon(ikon, color: renk)),
                                const SizedBox(width: 10),
                                Expanded(child: Text(kasa['kasa_adi']?.toString() ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                              ]),
                              const SizedBox(height: 8),
                              Text(kayit == null ? 'Gün sonu yapılmadı' : 'Sayılan: ${_para(kayit['sayilan_bakiye'])} • Fark: ${_para(fark)} • ${kayit['kullanici'] ?? '-'}', maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(child: Text('Sistem: ${_para(beklenen)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(onPressed: () => _sayimKaydet(kasa), icon: const Icon(Icons.fact_check_rounded), label: Text(kayit == null ? 'Sayım Yap' : 'Düzelt')),
                              ]),
                            ],
                          ),
                        ),
                      );
                    }

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: renk.withOpacity(.12), child: Icon(ikon, color: renk)),
                        title: Text(kasa['kasa_adi']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(kayit == null ? 'Gün sonu yapılmadı' : 'Sayılan: ${_para(kayit['sayilan_bakiye'])} • Fark: ${_para(fark)} • ${kayit['kullanici'] ?? '-'}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('Sistem: ${_para(beklenen)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(onPressed: () => _sayimKaydet(kasa), icon: const Icon(Icons.fact_check_rounded), label: Text(kayit == null ? 'Sayım Yap' : 'Düzelt')),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }''',
)

# 5) RECEIPTS: mobile top controls stack and cards use a clean vertical layout.
replace_method(
    'lib/screens/makbuzlar_sayfasi.dart',
    '  Widget _makbuzKarti(Map<String, dynamic> makbuz) {',
    r'''  Widget _makbuzKarti(Map<String, dynamic> makbuz) {
    final renk = _turRengi(makbuz);
    final mobil = MobilUyum.telefon(context);

    if (mobil) {
      return Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _detayGoster(makbuz),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  CircleAvatar(backgroundColor: renk.withOpacity(.14), child: Icon(_turIkonu(makbuz), color: renk)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_metin(makbuz['cari_unvan']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(_metin(makbuz['belge_no']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  ])),
                  Text(_para(makbuz['tutar']), style: TextStyle(color: renk, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 10, runSpacing: 5, children: [
                  Text('Tür: ${_odemeTuru(makbuz)}'),
                  Text('Kasa: ${_metin(makbuz['kasa_adi'])}'),
                  Text('Tarih: ${_tarih(makbuz['tarih'])}'),
                ]),
                const SizedBox(height: 5),
                Text('Not: ${_metin(makbuz['aciklama'])}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _detayGoster(makbuz),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(backgroundColor: renk.withOpacity(.14), child: Icon(_turIkonu(makbuz), color: renk)),
            const SizedBox(width: 14),
            SizedBox(width: 190, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_metin(makbuz['belge_no']), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(_tarih(makbuz['tarih']), style: const TextStyle(fontSize: 12)),
            ])),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_metin(makbuz['cari_unvan']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 5),
              Wrap(spacing: 18, runSpacing: 4, children: [
                Text('Tür: ${_odemeTuru(makbuz)}'),
                Text('Kasa: ${_metin(makbuz['kasa_adi'])}'),
                Text('Kullanıcı: ${_metin(makbuz['kullanici'])}'),
              ]),
              const SizedBox(height: 4),
              Text('Not: ${_metin(makbuz['aciklama'])}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ])),
            SizedBox(width: 170, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_para(makbuz['tutar']), style: TextStyle(color: renk, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(makbuz['iptal_mi'] == true ? 'İPTAL' : 'AKTİF', style: TextStyle(color: renk, fontSize: 11, fontWeight: FontWeight.bold)),
            ])),
          ]),
        ),
      ),
    );
  }''',
)

replace_method(
    'lib/screens/makbuzlar_sayfasi.dart',
    '  @override\n  Widget build(BuildContext context) {',
    r'''  @override
  Widget build(BuildContext context) {
    final mobil = MobilUyum.telefon(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(mobil ? 'MAKBUZLAR' : 'TAHSİLAT / ÖDEME MAKBUZLARI', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(tooltip: 'Yenile', onPressed: _verileriYukle, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: mobil
              ? Column(children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(value: 'TAHSILAT', icon: Icon(Icons.south_west), label: Text('Tahsilat')),
                        ButtonSegment<String>(value: 'ODEME', icon: Icon(Icons.north_east), label: Text('Ödeme')),
                      ],
                      selected: {_aktifTur},
                      onSelectionChanged: (secim) { setState(() => _aktifTur = secim.first); _filtrele(); },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: _aramaController,
                      decoration: InputDecoration(
                        hintText: 'Belge no, cari, kasa, açıklama...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _aramaController.text.isEmpty ? null : IconButton(onPressed: _aramaController.clear, icon: const Icon(Icons.clear)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    )),
                    const SizedBox(width: 8),
                    SizedBox(width: 115, child: DropdownButtonFormField<String>(
                      value: _durumFiltresi,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Durum', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'TÜMÜ', child: Text('Tümü')),
                        DropdownMenuItem(value: 'AKTİF', child: Text('Aktif')),
                        DropdownMenuItem(value: 'İPTAL', child: Text('İptal')),
                      ],
                      onChanged: (deger) { if (deger == null) return; setState(() => _durumFiltresi = deger); _filtrele(); },
                    )),
                  ]),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('Aktif Toplam: ${_para(_toplamTutar)}', style: TextStyle(fontWeight: FontWeight.bold, color: _aktifTur == 'TAHSILAT' ? Colors.green.shade700 : Colors.red.shade700)),
                  ),
                ])
              : Column(children: [
                  Row(children: [
                    Expanded(child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(value: 'TAHSILAT', icon: Icon(Icons.south_west), label: Text('Tahsilat Makbuzları')),
                        ButtonSegment<String>(value: 'ODEME', icon: Icon(Icons.north_east), label: Text('Ödeme Makbuzları')),
                      ],
                      selected: {_aktifTur},
                      onSelectionChanged: (secim) { setState(() => _aktifTur = secim.first); _filtrele(); },
                    )),
                    const SizedBox(width: 12),
                    Container(width: 230, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _aktifTur == 'TAHSILAT' ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text('Aktif Makbuz Toplamı', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 3),
                      Text(_para(_toplamTutar), style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: _aktifTur == 'TAHSILAT' ? Colors.green.shade700 : Colors.red.shade700)),
                    ])),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: _aramaController, decoration: InputDecoration(hintText: 'Belge no, cari, kasa, ödeme türü, açıklama, kullanıcı...', prefixIcon: const Icon(Icons.search), suffixIcon: _aramaController.text.isEmpty ? null : IconButton(onPressed: _aramaController.clear, icon: const Icon(Icons.clear)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                    const SizedBox(width: 12),
                    SizedBox(width: 165, child: DropdownButtonFormField<String>(value: _durumFiltresi, decoration: const InputDecoration(labelText: 'Durum', border: OutlineInputBorder()), items: const [
                      DropdownMenuItem(value: 'TÜMÜ', child: Text('Tüm Durumlar')),
                      DropdownMenuItem(value: 'AKTİF', child: Text('Aktif')),
                      DropdownMenuItem(value: 'İPTAL', child: Text('İptal')),
                    ], onChanged: (deger) { if (deger == null) return; setState(() => _durumFiltresi = deger); _filtrele(); })),
                  ]),
                ]),
        ),
        Expanded(
          child: _yukleniyor
              ? const Center(child: CircularProgressIndicator())
              : _gorunenMakbuzlar.isEmpty
                  ? const Center(child: Text('Makbuz bulunamadı.', style: TextStyle(fontSize: 18)))
                  : RefreshIndicator(
                      onRefresh: _verileriYukle,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _gorunenMakbuzlar.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _makbuzKarti(_gorunenMakbuzlar[index]),
                      ),
                    ),
        ),
      ]),
    );
  }''',
)

print('PRO ERP 2.5.30 mobile repairs applied successfully.')
