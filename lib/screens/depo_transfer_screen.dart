// lib/screens/depo_transfer_screen.dart

import 'package:flutter/material.dart';
import '../models/stok_model.dart';
import '../services/supabase_service.dart';
import '../services/yetki_service.dart';

class DepoTransferScreen extends StatefulWidget {
  const DepoTransferScreen({super.key});

  @override
  State<DepoTransferScreen> createState() => _DepoTransferScreenState();
}

class _DepoTransferScreenState extends State<DepoTransferScreen> {
  bool _yukleniyor = true;
  bool _kaydediliyor = false;

  final TextEditingController _aramaController = TextEditingController();
  final TextEditingController _miktarController = TextEditingController(text: '1');
  final TextEditingController _aciklamaController = TextEditingController();

  List<Map<String, dynamic>> _depolar = [];
  List<StokModel> _urunler = [];

  int? _kaynakDepoId;
  int? _hedefDepoId;
  StokModel? _stok;
  double _kaynakStokMiktari = 0;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _aramaController.dispose();
    _miktarController.dispose();
    _aciklamaController.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);

    try {
      final depolar = await SupabaseService.depolariGetir();
      if (!mounted) return;

      setState(() {
        _depolar = depolar.where((e) => e['aktif'] == true).toList();
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
      _mesaj('Veriler yüklenemedi: $e', Colors.red);
    }
  }

  Future<void> _ara(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _urunler = []);
      return;
    }

    final urunler = await SupabaseService.stoklariGetir(
      aramaMetni: q.trim(),
    );

    if (!mounted) return;
    setState(() => _urunler = urunler.take(30).toList());
  }

  Future<void> _kaynakStokGetir() async {
    final depoId = _kaynakDepoId;
    final stok = _stok;

    if (depoId == null || stok == null) {
      if (mounted) {
        setState(() => _kaynakStokMiktari = 0);
      }
      return;
    }

    try {
      final response = await SupabaseService.supabase
          .from('v_pro_stok_depo_durumu')
          .select('miktar')
          .eq('depo_id', depoId)
          .eq('stok_id', stok.stokId)
          .limit(1);

      final liste = List<Map<String, dynamic>>.from(response);
      final miktar = liste.isEmpty
          ? 0.0
          : double.tryParse(liste.first['miktar']?.toString() ?? '0') ?? 0.0;

      if (!mounted) return;
      setState(() => _kaynakStokMiktari = miktar);
    } catch (_) {
      if (!mounted) return;
      setState(() => _kaynakStokMiktari = 0);
    }
  }

  Future<void> _kaydet() async {
    if (_kaynakDepoId == null ||
        _hedefDepoId == null ||
        _stok == null) {
      _mesaj('Kaynak depo, hedef depo ve ürün seçilmelidir.', Colors.orange);
      return;
    }

    final miktar = double.tryParse(
          _miktarController.text.replaceAll(',', '.'),
        ) ??
        0;

    if (miktar <= 0) {
      _mesaj('Miktar sıfırdan büyük olmalıdır.', Colors.orange);
      return;
    }

    if (miktar > _kaynakStokMiktari) {
      _mesaj(
        'Kaynak depoda yeterli stok yok. Mevcut: '
        '${_kaynakStokMiktari.toStringAsFixed(2)}',
        Colors.red,
      );
      return;
    }

    setState(() => _kaydediliyor = true);

    try {
      await SupabaseService.depolarArasiTransfer(
        stokId: _stok!.stokId,
        kaynakDepoId: _kaynakDepoId!,
        hedefDepoId: _hedefDepoId!,
        miktar: miktar,
        aciklama: _aciklamaController.text.trim(),
        kullanici: YetkiService.aktifKullanici,
      );

      if (!mounted) return;

      _mesaj(
        'Transfer tamamlandı. Kaynak depo için TRANSFER ÇIKIŞ, '
        'hedef depo için TRANSFER GİRİŞ stok hareketi oluşturuldu.',
        Colors.green,
      );

      setState(() {
        _stok = null;
        _urunler = [];
        _aramaController.clear();
        _miktarController.text = '1';
        _aciklamaController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      _mesaj('Transfer hatası: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _kaydediliyor = false);
      }
    }
  }

  void _mesaj(String m, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: c),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DEPOLAR ARASI TRANSFER',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            DropdownButtonFormField<int>(
                              value: _kaynakDepoId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Kaynak Depo',
                                border: OutlineInputBorder(),
                              ),
                              items: _depolar
                                  .map(
                                    (e) => DropdownMenuItem<int>(
                                      value: int.tryParse(e['depo_id'].toString()),
                                      child: Text(e['depo_adi']?.toString() ?? ''),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) async {
                                setState(() {
                                  _kaynakDepoId = v;
                                  _stok = null;
                                  _kaynakStokMiktari = 0;
                                });
                                await _kaynakStokGetir();
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              value: _hedefDepoId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Hedef Depo',
                                border: OutlineInputBorder(),
                              ),
                              items: _depolar
                                  .map(
                                    (e) => DropdownMenuItem<int>(
                                      value: int.tryParse(e['depo_id'].toString()),
                                      child: Text(e['depo_adi']?.toString() ?? ''),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _hedefDepoId = v),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _aramaController,
                              decoration: const InputDecoration(
                                labelText: 'Ürün Ara',
                                prefixIcon: Icon(Icons.search_rounded),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: _ara,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _miktarController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Miktar',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _aciklamaController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Açıklama',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _kaydediliyor ? null : _kaydet,
                                icon: const Icon(Icons.compare_arrows_rounded),
                                label: Text(
                                  _kaydediliyor ? 'Kaydediliyor...' : 'Transferi Kaydet',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _stok != null
                          ? Center(
                              child: ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.inventory_2_outlined),
                                ),
                                title: Text(_stok!.urunAdi),
                                subtitle: Text(
                                  'Kod: ${_stok!.ureticiKodu}\n'
                                  'Kaynak Depo Stoku: ${_kaynakStokMiktari.toStringAsFixed(2)}',
                                ),
                                trailing: IconButton(
                                  onPressed: () => setState(() => _stok = null),
                                  icon: const Icon(Icons.clear_rounded),
                                ),
                              ),
                            )
                          : _urunler.isEmpty
                              ? const Center(
                                  child: Text('Ürün arayın ve seçin.'),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _urunler.length,
                                  separatorBuilder: (_, __) => const Divider(),
                                  itemBuilder: (_, index) {
                                    final urun = _urunler[index];
                                    return ListTile(
                                      title: Text(urun.urunAdi),
                                      subtitle: Text(
                                        'Kod: ${urun.ureticiKodu} • '
                                        'Stok: ${urun.stokMiktari.toStringAsFixed(0)}',
                                      ),
                                      trailing: const Icon(Icons.add_circle_outline),
                                      onTap: () async {
                                      setState(() => _stok = urun);
                                      await _kaynakStokGetir();
                                    },
                                    );
                                  },
                                ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
