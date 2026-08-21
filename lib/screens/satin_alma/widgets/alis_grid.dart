import 'package:flutter/material.dart';

import '../../../models/stok_model.dart';
import '../../../widgets/logo_klasik_belge_satiri.dart';
import '../../../utils/marka_kod.dart';

class AlisGrid extends StatelessWidget {
  final List<Map<String, dynamic>> sepet;

  final void Function(int index, int miktar)
      onMiktarDegisti;

  final void Function(int index, double fiyat)
      onFiyatDegistir;

  final void Function(int index, double iskonto)
      onIskontoDegisti;

  final void Function(int index, double kdv)
      onKdvDegisti;

  final void Function(int index) onSil;

  const AlisGrid({
    super.key,
    required this.sepet,
    required this.onMiktarDegisti,
    required this.onFiyatDegistir,
    required this.onIskontoDegisti,
    required this.onKdvDegisti,
    required this.onSil,
  });

  double _sayi(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();

    return double.tryParse(
          value
              .toString()
              .trim()
              .replaceAll(',', '.'),
        ) ??
        0.0;
  }

  Future<double?> _sayiGir(
    BuildContext context, {
    required String baslik,
    required double mevcut,
  }) async {
    final controller = TextEditingController(
      text: mevcut.toStringAsFixed(2),
    );

    final sonuc = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(baslik),
          content: SizedBox(
            width: 320,
            child: TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                final value = double.tryParse(
                  controller.text
                      .trim()
                      .replaceAll(',', '.'),
                );

                if (value != null) {
                  Navigator.pop(
                    dialogContext,
                    value,
                  );
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = double.tryParse(
                  controller.text
                      .trim()
                      .replaceAll(',', '.'),
                );

                if (value == null) return;

                Navigator.pop(
                  dialogContext,
                  value,
                );
              },
              child: const Text('Uygula'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    return sonuc;
  }

  Future<void> _satirDuzenle(
    BuildContext context,
    int index,
    int miktar,
    double fiyat,
    double iskonto,
    double kdv,
  ) async {
    final miktarC = TextEditingController(text: '$miktar');
    final fiyatC = TextEditingController(text: fiyat.toStringAsFixed(2));
    final iskontoC = TextEditingController(text: iskonto.toStringAsFixed(2));
    final kdvC = TextEditingController(text: kdv.toStringAsFixed(0));

    final kaydet = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Malzeme Satırını Düzenle'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: miktarC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Miktar',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fiyatC,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Birim Fiyat',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: iskontoC,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'İskonto %',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: kdvC,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'KDV %',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Uygula'),
          ),
        ],
      ),
    );

    if (kaydet == true) {
      final yeniMiktar = int.tryParse(miktarC.text.trim()) ?? miktar;
      final yeniFiyat = _sayi(fiyatC.text);
      final yeniIskonto = _sayi(iskontoC.text);
      final yeniKdv = _sayi(kdvC.text);
      onMiktarDegisti(index, yeniMiktar < 1 ? 1 : yeniMiktar);
      onFiyatDegistir(index, yeniFiyat);
      onIskontoDegisti(index, yeniIskonto);
      onKdvDegisti(index, yeniKdv);
    }

    miktarC.dispose();
    fiyatC.dispose();
    iskontoC.dispose();
    kdvC.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (sepet.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 72,
              color: Colors.grey,
            ),
            SizedBox(height: 12),
            Text(
              'Alış faturası sepeti boş.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Ürün arayarak sepete ekleyin.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return LogoKlasikBelgeListe(
      alis: true,
      itemCount: sepet.length,
      itemBuilder: (context, index) {
        final item = sepet[index];
        final stok = item['stok'] as StokModel;
        final miktar = int.tryParse('${item['miktar'] ?? ''}') ?? 1;
        final fiyat = _sayi(item['alisFiyati']);
        final iskonto = _sayi(item['iskonto']);
        final kdv = _sayi(item['kdv']);
        final net = miktar * fiyat * (1 - iskonto / 100);
        final toplam = net + (net * kdv / 100);

        return LogoKlasikBelgeSatiri(
          no: index + 1,
          kod: markaVeUreticiKodu(stok.marka, stok.ureticiKodu),
          aciklama: stok.urunAdi,
          miktar: '$miktar',
          birim: 'Adet',
          fiyat: '${fiyat.toStringAsFixed(2)} ₺',
          indirim: '%${iskonto.toStringAsFixed(1)}',
          kdv: '%${kdv.toStringAsFixed(0)}',
          tutar: '${toplam.toStringAsFixed(2)} ₺',
          raf: stok.raf.isEmpty ? '-' : stok.raf,
          stok: stok.stokMiktari.toStringAsFixed(0),
          ambar: item['depo_adi']?.toString() ?? 'Merkez',
          onTap: () => _satirDuzenle(
            context,
            index,
            miktar,
            fiyat,
            iskonto,
            kdv,
          ),
          onEdit: () => _satirDuzenle(
            context,
            index,
            miktar,
            fiyat,
            iskonto,
            kdv,
          ),
          onDelete: () => onSil(index),
        );
      },
    );
  }

}

class _DegerButonu extends StatelessWidget {
  final String baslik;
  final String deger;
  final VoidCallback onTap;

  const _DegerButonu({
    required this.baslik,
    required this.deger,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color:
                Theme.of(context).dividerColor,
          ),
          borderRadius:
              BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              baslik,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              deger,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
