// lib/widgets/fiyat_seridi.dart

import 'package:flutter/material.dart';

import '../models/stok_model.dart';

typedef FiyatSecildi = void Function(String fiyatTipi);

class FiyatSeridi extends StatelessWidget {
  final StokModel stok;
  final FiyatSecildi? onFiyatSecildi;
  final bool kompakt;
  final EdgeInsetsGeometry padding;

  const FiyatSeridi({
    super.key,
    required this.stok,
    this.onFiyatSecildi,
    this.kompakt = false,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
  });

  static double fiyatDegeri(
    StokModel stok,
    String fiyatTipi, {
    bool sflNetOlarak = false,
  }) {
    switch (fiyatTipi) {
      case 'AFN':
        return stok.alisFiyati;
      case 'SFI':
        return stok.satisFiyatiIndirimli;
      case 'SFT':
        return stok.satisFiyatiToptan;
      case 'SFL':
        if (sflNetOlarak) {
          final carpan = 1 + (stok.kdv / 100);
          return carpan <= 0 ? stok.satisFiyatiListe : stok.satisFiyatiListe / carpan;
        }
        return stok.satisFiyatiListe;
      case 'SFP':
      default:
        return stok.satisFiyatiPerakende;
    }
  }

  static const List<String> fiyatKodlari = [
    'AFN',
    'SFI',
    'SFT',
    'SFP',
    'SFL',
  ];

  static Color fiyatRengi(String kod) {
    switch (kod) {
      case 'AFN':
        return Colors.orange.shade800;
      case 'SFI':
        return Colors.green.shade700;
      case 'SFT':
        return Colors.blue.shade700;
      case 'SFP':
        return Colors.purple.shade700;
      case 'SFL':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  String _para(double deger) => '${deger.toStringAsFixed(2)} ₺';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final yatay = constraints.maxWidth >= (kompakt ? 255 : 420);

          final kutular = fiyatKodlari.map((kod) {
            final renk = fiyatRengi(kod);
            final fiyat = fiyatDegeri(stok, kod);

            final icerik = Container(
              constraints: BoxConstraints(
                minWidth: kompakt ? 46 : 76,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: kompakt ? 4 : 9,
                vertical: kompakt ? 5 : 7,
              ),
              decoration: BoxDecoration(
                color: renk.withOpacity(0.07),
                border: Border.all(
                  color: renk.withOpacity(0.28),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    kod,
                    style: TextStyle(
                      color: renk,
                      fontSize: kompakt ? 10 : 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _para(fiyat),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: renk,
                      fontSize: kompakt ? 11 : 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );

            if (onFiyatSecildi == null) {
              return icerik;
            }

            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onFiyatSecildi!(kod),
              child: icerik,
            );
          }).toList();

          if (yatay) {
            return Row(
              children: [
                for (int i = 0; i < kutular.length; i++) ...[
                  Expanded(child: kutular[i]),
                  if (i < kutular.length - 1)
                    const SizedBox(width: 5),
                ],
              ],
            );
          }

          return Wrap(
            spacing: 5,
            runSpacing: 5,
            children: kutular,
          );
        },
      ),
    );
  }
}