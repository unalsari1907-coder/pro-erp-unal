import 'package:flutter/material.dart';

class AlisToplam extends StatelessWidget {
  final int kalemSayisi;
  final int toplamMiktar;

  final double araToplam;
  final double iskonto;
  final double kdv;
  final double genelToplam;

  const AlisToplam({
    super.key,
    required this.kalemSayisi,
    required this.toplamMiktar,
    required this.araToplam,
    required this.iskonto,
    required this.kdv,
    required this.genelToplam,
  });

  Widget _satir(
    String baslik,
    String deger, {
    bool kalin = false,
    Color? renk,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              baslik,
              style: TextStyle(
                fontWeight:
                    kalin ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            deger,
            style: TextStyle(
              fontSize: kalin ? 17 : 13,
              color: renk,
              fontWeight:
                  kalin ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 390,
        child: Card(
          elevation: 3,
          margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                _satir(
                  'Kalem Sayısı',
                  kalemSayisi.toString(),
                ),
                _satir(
                  'Toplam Miktar',
                  toplamMiktar.toString(),
                ),
                const Divider(),
                _satir(
                  'Ara Toplam',
                  '${araToplam.toStringAsFixed(2)} ₺',
                ),
                _satir(
                  'İskonto',
                  '${iskonto.toStringAsFixed(2)} ₺',
                ),
                _satir(
                  'KDV',
                  '${kdv.toStringAsFixed(2)} ₺',
                ),
                const Divider(),
                _satir(
                  'GENEL TOPLAM',
                  '${genelToplam.toStringAsFixed(2)} ₺',
                  kalin: true,
                  renk: Colors.blue.shade800,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}