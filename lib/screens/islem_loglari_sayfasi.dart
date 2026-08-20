import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class IslemLoglariSayfasi extends StatefulWidget {
  const IslemLoglariSayfasi({super.key});

  @override
  State<IslemLoglariSayfasi> createState() => _IslemLoglariSayfasiState();
}

class _IslemLoglariSayfasiState extends State<IslemLoglariSayfasi> {
  final _aramaController = TextEditingController();
  Timer? _timer;
  bool _yukleniyor = true;
  List<Map<String, dynamic>> _kayitlar = [];
  List<Map<String, dynamic>> _filtreli = [];

  @override
  void initState() {
    super.initState();
    _yukle();
    _aramaController.addListener(_filtrele);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _aramaController.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    if (mounted) setState(() => _yukleniyor = true);
    try {
      final response = await SupabaseService.supabase
          .from('erp_islem_log')
          .select('log_id, tarih, tablo, islem, kayit_id, kullanici, eski_veri, yeni_veri')
          .order('tarih', ascending: false)
          .limit(1000);
      if (!mounted) return;
      setState(() {
        _kayitlar = List<Map<String, dynamic>>.from(response);
        _filtreli = List<Map<String, dynamic>>.from(_kayitlar);
        _yukleniyor = false;
      });
      _filtrele();
    } catch (e) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem logları yüklenemedi: $e')),
      );
    }
  }

  void _filtrele() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final kelimeler = _aramaController.text.toLowerCase().trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
      setState(() {
        if (kelimeler.isEmpty) {
          _filtreli = List<Map<String, dynamic>>.from(_kayitlar);
        } else {
          _filtreli = _kayitlar.where((x) {
            final metin = [x['tablo'], x['islem'], x['kayit_id'], x['kullanici'], x['eski_veri'], x['yeni_veri']]
                .map((e) => e?.toString() ?? '')
                .join(' ')
                .toLowerCase();
            return kelimeler.every(metin.contains);
          }).toList();
        }
      });
    });
  }

  String _tarih(dynamic v) {
    final d = DateTime.tryParse(v?.toString() ?? '')?.toLocal();
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
  }

  Color _renk(String islem) {
    switch (islem.toUpperCase()) {
      case 'INSERT':
        return Colors.green;
      case 'DELETE':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('İŞLEM GEÇMİŞİ / LOG'),
        actions: [IconButton(onPressed: _yukle, icon: const Icon(Icons.refresh))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _aramaController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tablo, işlem, kullanıcı, kayıt no ara...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _filtreli.isEmpty
                    ? const Center(child: Text('İşlem kaydı bulunamadı.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filtreli.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final x = _filtreli[index];
                          final islem = (x['islem'] ?? '-').toString();
                          final renk = _renk(islem);
                          return Card(
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: renk.withOpacity(.12),
                                child: Icon(Icons.history, color: renk),
                              ),
                              title: Text('${x['tablo'] ?? '-'} • $islem', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${_tarih(x['tarih'])}  •  Kullanıcı: ${x['kullanici'] ?? '-'}  •  Kayıt: ${x['kayit_id'] ?? '-'}'),
                              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              children: [
                                Align(alignment: Alignment.centerLeft, child: SelectableText('ÖNCE:\n${x['eski_veri'] ?? '-'}')),
                                const Divider(),
                                Align(alignment: Alignment.centerLeft, child: SelectableText('SONRA:\n${x['yeni_veri'] ?? '-'}')),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}