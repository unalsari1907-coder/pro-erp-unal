import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class MuhasebeRaporlariSayfasi extends StatefulWidget {
  const MuhasebeRaporlariSayfasi({super.key});
  @override
  State<MuhasebeRaporlariSayfasi> createState() => _MuhasebeRaporlariSayfasiState();
}

class _MuhasebeRaporlariSayfasiState extends State<MuhasebeRaporlariSayfasi> {
  bool _yukleniyor = true;
  List<Map<String, dynamic>> _mizan = [];
  double _borc = 0, _alacak = 0;

  double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? 0}'.replaceAll(',', '.')) ?? 0;
  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    if (mounted) setState(() => _yukleniyor = true);
    final map = <String, Map<String, dynamic>>{};
    try {
      final hesaplarRaw = await SupabaseService.supabase.from('erp_hesap_plani').select('hesap_kodu,hesap_adi,hesap_tipi').order('hesap_kodu');
      for (final r in (hesaplarRaw as List)) {
        final x = Map<String, dynamic>.from(r as Map);
        map['${x['hesap_kodu']}'] = {'hesap_kodu': x['hesap_kodu'], 'hesap_adi': x['hesap_adi'], 'hesap_tipi': x['hesap_tipi'], 'borc': 0.0, 'alacak': 0.0};
      }
      final satirRaw = await SupabaseService.supabase.from('erp_muhasebe_fis_satirlari').select('hesap_kodu,borc,alacak');
      for (final r in (satirRaw as List)) {
        final x = Map<String, dynamic>.from(r as Map);
        final kod = '${x['hesap_kodu'] ?? ''}';
        map.putIfAbsent(kod, () => {'hesap_kodu': kod, 'hesap_adi': '-', 'hesap_tipi': '-', 'borc': 0.0, 'alacak': 0.0});
        map[kod]!['borc'] = _n(map[kod]!['borc']) + _n(x['borc']);
        map[kod]!['alacak'] = _n(map[kod]!['alacak']) + _n(x['alacak']);
      }
    } catch (_) {}
    final liste = map.values.toList()..sort((a,b) => '${a['hesap_kodu']}'.compareTo('${b['hesap_kodu']}'));
    double b = 0, a = 0;
    for (final x in liste) { b += _n(x['borc']); a += _n(x['alacak']); }
    if (!mounted) return;
    setState(() { _mizan = liste; _borc = b; _alacak = a; _yukleniyor = false; });
  }

  String _p(double n) => n.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('MUHASEBE RAPORLARI / MİZAN'), actions: [IconButton(onPressed: _yukle, icon: const Icon(Icons.refresh_rounded))]),
    body: _yukleniyor ? const Center(child: CircularProgressIndicator()) : Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: _ozet('Toplam Borç', _borc)), const SizedBox(width: 10),
          Expanded(child: _ozet('Toplam Alacak', _alacak)), const SizedBox(width: 10),
          Expanded(child: _ozet('Fark', _borc - _alacak)),
        ]),
      ),
      Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(child: DataTable(
        columns: const [DataColumn(label: Text('Hesap Kodu')), DataColumn(label: Text('Hesap Adı')), DataColumn(label: Text('Tip')), DataColumn(label: Text('Borç'), numeric: true), DataColumn(label: Text('Alacak'), numeric: true), DataColumn(label: Text('Bakiye'), numeric: true)],
        rows: _mizan.map((x) {
          final b = _n(x['borc']), a = _n(x['alacak']);
          return DataRow(cells: [DataCell(Text('${x['hesap_kodu']}')), DataCell(Text('${x['hesap_adi']}')), DataCell(Text('${x['hesap_tipi'] ?? '-'}')), DataCell(Text(_p(b))), DataCell(Text(_p(a))), DataCell(Text(_p(b-a)))]);
        }).toList(),
      )))),
    ]),
  );

  Widget _ozet(String b, double d) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [Text(b), const SizedBox(height: 5), FittedBox(child: Text('${_p(d)} ₺', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))])));
}
