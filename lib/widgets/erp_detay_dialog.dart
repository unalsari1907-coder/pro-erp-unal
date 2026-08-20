import 'package:flutter/material.dart';

class ErpDetayDialog {
  static Future<void> goster(
    BuildContext context, {
    required String baslik,
    String? altBaslik,
    required Map<String, dynamic> veri,
    Map<String, String> etiketler = const {},
    List<String>? alanSirasi,
    List<Widget> ekBolumler = const [],
    VoidCallback? onDuzenle,
  }) async {
    final mobil = MediaQuery.sizeOf(context).width < 720;
    final keys = <String>[];
    if (alanSirasi != null) {
      for (final k in alanSirasi) {
        if (veri.containsKey(k) && !keys.contains(k)) keys.add(k);
      }
    }
    for (final k in veri.keys) {
      if (!keys.contains(k)) keys.add(k);
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(22, 18, 14, 8),
        contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
        actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(baslik, style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (altBaslik != null && altBaslik.trim().isNotEmpty)
                    Text(altBaslik, style: Theme.of(ctx).textTheme.bodySmall),
                ],
              ),
            ),
            if (onDuzenle != null)
              IconButton(
                tooltip: 'Düzenle',
                onPressed: () {
                  Navigator.pop(ctx);
                  onDuzenle();
                },
                icon: const Icon(Icons.edit_rounded),
              ),
          ],
        ),
        content: SizedBox(
          width: mobil ? MediaQuery.sizeOf(ctx).width * .94 : 900,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: keys.map((k) {
                    final v = veri[k];
                    if (v is Map || v is List) return const SizedBox.shrink();
                    return SizedBox(
                      width: mobil ? double.infinity : 275,
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(ctx).dividerColor),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              etiketler[k] ?? _etiket(k),
                              style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 3),
                            SelectableText(
                              _deger(v),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (ekBolumler.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ...ekBolumler,
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  static String _deger(dynamic v) {
    if (v == null || '$v'.trim().isEmpty) return '-';
    if (v is bool) return v ? 'Evet' : 'Hayır';
    return '$v';
  }

  static String _etiket(String key) {
    return key
        .replaceAll('_id', ' ID')
        .replaceAll('_', ' ')
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((e) => e[0].toUpperCase() + e.substring(1))
        .join(' ');
  }
}
