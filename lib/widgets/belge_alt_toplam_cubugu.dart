import 'package:flutter/material.dart';

class BelgeAltToplamCubugu extends StatelessWidget {
  final double araToplam;
  final double iskontoToplam;
  final double kdvToplam;
  final double genelToplam;
  final List<Widget> actions;

  const BelgeAltToplamCubugu({
    super.key,
    required this.araToplam,
    required this.iskontoToplam,
    required this.kdvToplam,
    required this.genelToplam,
    this.actions = const <Widget>[],
  });

  Widget _kart(
    String baslik,
    double deger, {
    Color? renk,
  }) {
    return Container(
      width: 165,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD9DCE3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            baslik,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${deger.toStringAsFixed(2)} ₺',
            style: TextStyle(
              color: renk ?? Colors.blue.shade700,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFD9DCE3)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dar = constraints.maxWidth < 900;

          final toplamlar = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _kart('Ara Toplam', araToplam),
              _kart('İskonto Toplam', iskontoToplam),
              _kart('KDV Toplam', kdvToplam),
              _kart(
                'Genel Toplam',
                genelToplam,
                renk: Colors.green.shade700,
              ),
            ],
          );

          final butonlar = Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          );

          if (dar) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                toplamlar,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: butonlar,
                  ),
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              toplamlar,
              const Spacer(),
              butonlar,
            ],
          );
        },
      ),
    );
  }
}
