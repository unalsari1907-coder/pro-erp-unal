import 'package:flutter/material.dart';

class LogoKlasikBelgeBaslik extends StatelessWidget {
  final bool alis;
  const LogoKlasikBelgeBaslik({super.key, this.alis = false});

  static const double urunW = 360;
  static const double kodW = 170;
  static const double rafW = 90;
  static const double miktarW = 80;
  static const double fiyatW = 130;
  static const double kdvW = 80;
  static const double toplamW = 130;
  static const double aksiyonW = 118;
  static const double toplamGenislik =
      urunW + kodW + rafW + miktarW + fiyatW + kdvW + toplamW + aksiyonW;

  Widget _baslik(String text, double width, {TextAlign align = TextAlign.left}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          text,
          textAlign: align,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF30323A),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: toplamGenislik,
      height: 42,
      color: const Color(0xFFF4F5F8),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          _baslik('Ürün', urunW),
          _baslik('Marka / Kod', kodW),
          _baslik('RAF', rafW),
          _baslik('Miktar', miktarW, align: TextAlign.right),
          _baslik('Birim Fiyat', fiyatW, align: TextAlign.right),
          _baslik('KDV %', kdvW, align: TextAlign.right),
          _baslik('Toplam', toplamW, align: TextAlign.right),
          const SizedBox(width: aksiyonW),
        ],
      ),
    );
  }
}

class LogoKlasikBelgeSatiri extends StatelessWidget {
  final int no;
  final String kod;
  final String aciklama;
  final String miktar;
  final String birim;
  final String fiyat;
  final String indirim;
  final String kdv;
  final String tutar;
  final String raf;
  final String stok;
  final String ambar;
  final VoidCallback? onTap;
  final VoidCallback? onQuantityEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const LogoKlasikBelgeSatiri({
    super.key,
    required this.no,
    required this.kod,
    required this.aciklama,
    required this.miktar,
    required this.birim,
    required this.fiyat,
    required this.indirim,
    required this.kdv,
    required this.tutar,
    required this.raf,
    required this.stok,
    required this.ambar,
    this.onTap,
    this.onQuantityEdit,
    this.onEdit,
    this.onDelete,
  });

  Widget _hucre(
    String text,
    double width, {
    TextAlign align = TextAlign.left,
    FontWeight weight = FontWeight.w500,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          text,
          textAlign: align,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, fontWeight: weight),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F8FB),
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: LogoKlasikBelgeBaslik.toplamGenislik,
          constraints: const BoxConstraints(minHeight: 60),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFFD7DAE1)),
            ),
          ),
          child: Row(
            children: [
              _hucre(
                aciklama,
                LogoKlasikBelgeBaslik.urunW,
                weight: FontWeight.w600,
              ),
              _hucre(
                kod.trim().isEmpty ? '-' : kod.trim(),
                LogoKlasikBelgeBaslik.kodW,
                weight: FontWeight.w900,
              ),
              _hucre(
                raf.trim().isEmpty ? '-' : raf.trim(),
                LogoKlasikBelgeBaslik.rafW,
              ),
              _hucre(
                miktar,
                LogoKlasikBelgeBaslik.miktarW,
                align: TextAlign.right,
              ),
              _hucre(
                fiyat,
                LogoKlasikBelgeBaslik.fiyatW,
                align: TextAlign.right,
                weight: FontWeight.w600,
              ),
              _hucre(
                kdv.replaceAll('%', ''),
                LogoKlasikBelgeBaslik.kdvW,
                align: TextAlign.right,
              ),
              _hucre(
                tutar,
                LogoKlasikBelgeBaslik.toplamW,
                align: TextAlign.right,
                weight: FontWeight.w800,
              ),
              SizedBox(
                width: LogoKlasikBelgeBaslik.aksiyonW,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onQuantityEdit != null)
                      IconButton(
                        tooltip: 'Miktarı Düzenle',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: onQuantityEdit,
                        icon: const Icon(Icons.numbers_rounded, size: 18),
                      ),
                    if (onEdit != null)
                      IconButton(
                        tooltip: 'Fiyatı Düzenle',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 17),
                      ),
                    if (onDelete != null)
                      IconButton(
                        tooltip: 'Sil',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 17,
                          color: Colors.red,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class LogoKlasikBelgeListe extends StatelessWidget {
  final bool alis;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  const LogoKlasikBelgeListe({
    super.key,
    this.alis = false,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          thumbVisibility: false,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: LogoKlasikBelgeBaslik.toplamGenislik,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  LogoKlasikBelgeBaslik(alis: alis),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: itemCount,
                      itemBuilder: itemBuilder,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
