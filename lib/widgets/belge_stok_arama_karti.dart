import 'package:flutter/material.dart';

import '../models/stok_model.dart';
import 'fiyat_seridi.dart';

class BelgeStokAramaKarti extends StatelessWidget {
  final StokModel stok;
  final VoidCallback onEkle;
  final ValueChanged<String>? onFiyatSecildi;

  const BelgeStokAramaKarti({
    super.key,
    required this.stok,
    required this.onEkle,
    this.onFiyatSecildi,
  });

  String _liste(List<String> values) {
    final temiz = values.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return temiz.isEmpty ? '-' : temiz.join(', ');
  }

  Future<void> _detayAc(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(stok.urunAdi),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _satir('Üretici Kodu', stok.ureticiKodu),
                _satir('OEM', _liste(stok.oemler)),
                _satir('CROSS', _liste(stok.crossKodlar)),
                _satir('Rakip Kod', _liste(stok.rakipKodlar)),
                _satir('RAF', stok.raf),
                _satir('Mevcut Stok', stok.stokMiktari.toStringAsFixed(0)),
                _satir('Marka', stok.marka),
                _satir('Araç', _liste(stok.araclar)),
                _satir('Ürün Özelliği', stok.urunOzellik),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _satir(String baslik, String deger) {
    final metin = deger.trim().isEmpty ? '-' : deger.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              baslik,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: SelectableText(metin)),
        ],
      ),
    );
  }

  Widget _rozet({
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stokRenk = stok.stokMiktari > 0 ? Colors.green.shade700 : Colors.red.shade700;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onEkle,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: stok.resim.isEmpty
                        ? const Icon(Icons.inventory_2_outlined, size: 36)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              stok.resim,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.inventory_2_outlined, size: 36),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stok.urunAdi,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          margin: const EdgeInsets.only(top: 5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.08),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.28),
                            ),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            'ÜRETİCİ KODU: ${stok.ureticiKodu.trim().isEmpty ? '-' : stok.ureticiKodu.trim()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _rozet(
                              text: 'STOK ${stok.stokMiktari.toStringAsFixed(0)}',
                              color: stokRenk,
                            ),
                            _rozet(
                              text: 'RAF ${stok.raf.trim().isEmpty ? '-' : stok.raf.trim()}',
                              color: Colors.blueGrey.shade700,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Stok detayı',
                    onPressed: () => _detayAc(context),
                    icon: const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.blueGrey,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sepete ekle',
                    onPressed: onEkle,
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FiyatSeridi(
                stok: stok,
                onFiyatSecildi: onFiyatSecildi,
                kompakt: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
