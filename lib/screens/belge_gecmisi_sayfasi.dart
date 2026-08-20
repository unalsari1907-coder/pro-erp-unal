import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class BelgeGecmisiSayfasi extends StatefulWidget {
  const BelgeGecmisiSayfasi({super.key});

  @override
  State<BelgeGecmisiSayfasi> createState() => _BelgeGecmisiSayfasiState();
}

class _BelgeGecmisiSayfasiState extends State<BelgeGecmisiSayfasi> {
  final _arama = TextEditingController();
  bool _yukleniyor = false;
  String? _hata;
  List<Map<String, dynamic>> _sonuclar = [];

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  Future<void> _ara() async {
    final q = _arama.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _yukleniyor = true;
      _hata = null;
      _sonuclar = [];
    });

    final bulunan = <Map<String, dynamic>>[];
    final kaynaklar = <Map<String, String>>[
      {'tablo': 'satis_baslik', 'tip': 'Satış Faturası', 'no': 'fatura_no', 'tarih': 'tarih', 'cari': 'cari_unvan', 'tutar': 'genel_toplam'},
      {'tablo': 'alis_baslik', 'tip': 'Alış Faturası', 'no': 'fatura_no', 'tarih': 'tarih', 'cari': 'cari_unvan', 'tutar': 'genel_toplam'},
      {'tablo': 'satis_siparis_baslik', 'tip': 'Satış Siparişi', 'no': 'siparis_no', 'tarih': 'tarih', 'cari': 'cari_unvan', 'tutar': 'genel_toplam'},
      {'tablo': 'alis_siparis_baslik', 'tip': 'Alış Siparişi', 'no': 'siparis_no', 'tarih': 'tarih', 'cari': 'cari_unvan', 'tutar': 'genel_toplam'},
      {'tablo': 'satis_irsaliye_baslik', 'tip': 'Satış İrsaliyesi', 'no': 'irsaliye_no', 'tarih': 'tarih', 'cari': 'cari_unvan', 'tutar': 'genel_toplam'},
      {'tablo': 'alis_irsaliye_baslik', 'tip': 'Alış İrsaliyesi', 'no': 'irsaliye_no', 'tarih': 'tarih', 'cari': 'cari_unvan', 'tutar': 'genel_toplam'},
      {'tablo': 'erp_teklifler', 'tip': 'Teklif / Proforma', 'no': 'belge_no', 'tarih': 'tarih', 'cari': 'cari_unvan', 'tutar': 'toplam'},
      {'tablo': 'cari_hareket', 'tip': 'Cari Hareket', 'no': 'belge_no', 'tarih': 'tarih', 'cari': 'cari_unvan', 'tutar': 'tutar'},
    ];

    for (final k in kaynaklar) {
      try {
        final tablo = k['tablo']!;
        final no = k['no']!;
        final cari = k['cari']!;
        final rows = await SupabaseService.supabase
            .from(tablo)
            .select()
            .or('$no.ilike.%$q%,$cari.ilike.%$q%')
            .limit(80);
        for (final raw in (rows as List)) {
          final x = Map<String, dynamic>.from(raw as Map);
          bulunan.add({
            'tip': k['tip'],
            'tablo': tablo,
            'belge_no': x[no]?.toString() ?? '-',
            'tarih': x[k['tarih']]?.toString() ?? '',
            'cari': x[cari]?.toString() ?? '-',
            'tutar': x[k['tutar']] ?? 0,
            'durum': x['durum']?.toString() ?? '',
            'raw': x,
          });
        }
      } catch (_) {
        // Bazı eski tablolarda kolon adı farklı olabilir; diğer kaynaklar yine gösterilir.
      }
    }

    bulunan.sort((a, b) => (b['tarih']?.toString() ?? '').compareTo(a['tarih']?.toString() ?? ''));
    if (!mounted) return;
    setState(() {
      _sonuclar = bulunan;
      _yukleniyor = false;
      if (bulunan.isEmpty) _hata = 'Belge veya cari eşleşmesi bulunamadı.';
    });
  }

  String _para(dynamic d) {
    final n = d is num ? d.toDouble() : double.tryParse('${d ?? 0}'.replaceAll(',', '.')) ?? 0;
    return '${n.toStringAsFixed(2)} ₺';
  }

  void _detay(Map<String, dynamic> item) {
    final raw = Map<String, dynamic>.from(item['raw'] as Map);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${item['tip']} • ${item['belge_no']}'),
        content: SizedBox(
          width: MediaQuery.sizeOf(c).width < 720 ? MediaQuery.sizeOf(c).width - 48 : 760,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              children: raw.entries.map((e) => SizedBox(
                width: 225,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.key, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  Text('${e.value ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              )).toList(),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Kapat'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobil = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      appBar: AppBar(title: const Text('BELGE GEÇMİŞİ / BELGE ZİNCİRİ')),
      body: Padding(
        padding: EdgeInsets.all(mobil ? 10 : 18),
        child: Column(children: [
          TextField(
            controller: _arama,
            onSubmitted: (_) => _ara(),
            decoration: InputDecoration(
              labelText: 'Belge No veya Cari Ara',
              hintText: 'ST-2026..., SIR-2026..., BİRLİK OTOMOTİV...',
              prefixIcon: const Icon(Icons.manage_search_rounded),
              suffixIcon: IconButton(onPressed: _ara, icon: const Icon(Icons.search_rounded)),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _sonuclar.isEmpty
                    ? Center(child: Text(_hata ?? 'Bir belge numarası veya cari adı ile arama yapın.'))
                    : ListView.separated(
                        itemCount: _sonuclar.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final x = _sonuclar[i];
                          return ListTile(
                            leading: CircleAvatar(child: Icon(_ikon(x['tip']?.toString() ?? ''))),
                            title: Text('${x['tip']} • ${x['belge_no']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${x['cari']}  •  ${x['tarih']}  ${x['durum'].toString().isEmpty ? '' : '• ${x['durum']}'}'),
                            trailing: Text(_para(x['tutar']), style: const TextStyle(fontWeight: FontWeight.bold)),
                            onTap: () => _detay(x),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }

  IconData _ikon(String tip) {
    if (tip.contains('İrsaliye')) return Icons.local_shipping_rounded;
    if (tip.contains('Sipariş')) return Icons.assignment_rounded;
    if (tip.contains('Teklif')) return Icons.request_quote_rounded;
    if (tip.contains('Cari')) return Icons.people_alt_rounded;
    return Icons.receipt_long_rounded;
  }
}
