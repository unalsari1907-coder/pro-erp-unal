import 'dart:math' as math;

import 'package:flutter/material.dart';

/// PRO ERP genel mobil uyum yardımcıları.
/// Masaüstü görünümünü kesinlikle değiştirmez; yalnız küçük ekranlarda
/// taşmaları engelleyen alternatif yerleşim kullanır.
class MobilUyum {
  static const double telefonEsigi = 720;

  static bool telefon(BuildContext context) =>
      MediaQuery.sizeOf(context).width < telefonEsigi;
}

/// Masaüstünde normal Row davranışı aynen korunur.
/// Telefonda satır, güvenli minimum genişlikte yatay kaydırılabilir olur.
class MobilYatayRow extends StatelessWidget {
  final List<Widget> children;
  final double minWidth;

  /// Telefonda yatay kaydırma yerine alanları gerçek tek sütunda gösterir.
  /// Form ve detay satırlarında taşmayı tamamen kaldırmak için kullanılır.
  final bool mobilDikey;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline? textBaseline;

  const MobilYatayRow({
    super.key,
    required this.children,
    this.minWidth = 760,
    this.mobilDikey = false,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline,
  });

  Widget _row() => Row(
    mainAxisAlignment: mainAxisAlignment,
    mainAxisSize: mainAxisSize,
    crossAxisAlignment: crossAxisAlignment,
    textDirection: textDirection,
    verticalDirection: verticalDirection,
    textBaseline: textBaseline,
    children: children,
  );

  Widget _mobilCocuk(Widget child) {
    if (child is Expanded) {
      return SizedBox(width: double.infinity, child: child.child);
    }
    if (child is Flexible) {
      return SizedBox(width: double.infinity, child: child.child);
    }
    if (child is Spacer) {
      return const SizedBox(height: 8);
    }
    if (child is VerticalDivider) {
      return const Divider(height: 16);
    }
    if (child is SizedBox) {
      if (child.child == null && child.width != null && child.height == null) {
        return SizedBox(height: math.min(child.width!, 12));
      }
      if (child.child != null && child.width != null) {
        return SizedBox(
          width: double.infinity,
          height: child.height,
          child: child.child,
        );
      }
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    if (!MobilUyum.telefon(context)) {
      return _row();
    }

    if (mobilDikey) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children.map(_mobilCocuk).toList(),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: minWidth, child: _row()),
    );
  }
}

/// AlertDialog içeriği masaüstünde verilen width/height değerlerini AYNEN
/// kullanır. Yalnız telefonda ekran ölçüsüne göre küçültülür.
class MobilDialogIcerik extends StatelessWidget {
  final double? width;
  final double? height;
  final Widget child;

  const MobilDialogIcerik({
    super.key,
    this.width,
    this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!MobilUyum.telefon(context)) {
      return SizedBox(width: width, height: height, child: child);
    }

    final ekran = MediaQuery.sizeOf(context);
    final maxWidth = math.max(260.0, ekran.width - 32.0).toDouble();
    final maxHeight = math.max(260.0, ekran.height - 260.0).toDouble();

    final hedefWidth = width == null
        ? maxWidth
        : math.min(width!, maxWidth).toDouble();
    final hedefHeight = height == null
        ? maxHeight
        : math.min(height!, maxHeight).toDouble();

    return SizedBox(width: hedefWidth, height: hedefHeight, child: child);
  }
}

/// Masaüstünde tabloya hiçbir ek ScrollView eklemez.
/// Bu özellikle satış/alış fatura detaylarındaki çift yatay ScrollView
/// kaynaklı takılma/donma sorununu önler.
/// Telefonda ise geniş tablo yatay kaydırılabilir olur.
class MobilTablo extends StatelessWidget {
  final Widget child;

  const MobilTablo({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!MobilUyum.telefon(context)) {
      return child;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: child,
    );
  }
}

/// Masaüstünde mevcut AppBar aksiyonlarını normal Row olarak korur.
/// Telefonda başlığı ezmemesi için aksiyon alanı yatay kaydırılabilir olur.
class MobilAppBarActions extends StatelessWidget {
  final List<Widget> children;

  const MobilAppBarActions({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    if (!MobilUyum.telefon(context)) {
      return Row(mainAxisSize: MainAxisSize.min, children: children);
    }

    final width = MediaQuery.sizeOf(context).width;
    final actionWidth = math
        .max(120.0, math.min(250.0, width * .48))
        .toDouble();

    return SizedBox(
      width: actionWidth,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
