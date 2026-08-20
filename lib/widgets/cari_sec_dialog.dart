import 'package:flutter/material.dart';

class CariSecDialog {
  static Future<int?> ac({
    required BuildContext context,
    required List<Map<String, dynamic>> cariler,
    int? seciliCariId,
    String baslik = 'Cari Seç',
    String aramaIpucu = 'Cari ünvanı ara...',
  }) async {
    final aramaController = TextEditingController();
    List<Map<String, dynamic>> gorunen =
        List<Map<String, dynamic>>.from(cariler);

    try {
      return await showDialog<int>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              void filtrele(String deger) {
                final kelimeler = deger
                    .toLowerCase()
                    .trim()
                    .split(RegExp(r'\s+'))
                    .where((e) => e.isNotEmpty)
                    .toList();

                setDialogState(() {
                  if (kelimeler.isEmpty) {
                    gorunen = List<Map<String, dynamic>>.from(cariler);
                    return;
                  }

                  gorunen = cariler.where((cari) {
                    final metin = [
                      cari['cari_id'],
                      cari['unvan'],
                      cari['cari_tipi'],
                      cari['telefon'],
                      cari['vergi_no'],
                      cari['yetkili'],
                    ].map((e) => e?.toString() ?? '').join(' ').toLowerCase();

                    return kelimeler.every(metin.contains);
                  }).toList();
                });
              }

              return AlertDialog(
                title: Text(baslik),
                content: SizedBox(
                  width: MediaQuery.sizeOf(context).width < 720 ? MediaQuery.sizeOf(context).width - 48 : 720,
                  height: MediaQuery.sizeOf(context).width < 720 ? MediaQuery.sizeOf(context).height * .68 : 560,
                  child: Column(
                    children: [
                      TextField(
                        controller: aramaController,
                        autofocus: true,
                        onChanged: filtrele,
                        decoration: InputDecoration(
                          hintText: aramaIpucu,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: aramaController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    aramaController.clear();
                                    filtrele('');
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${gorunen.length} cari',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: gorunen.isEmpty
                            ? const Center(child: Text('Cari bulunamadı.'))
                            : ListView.separated(
                                itemCount: gorunen.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, index) {
                                  final cari = gorunen[index];
                                  final id = int.tryParse(
                                    cari['cari_id']?.toString() ?? '',
                                  );
                                  final secili = id != null && id == seciliCariId;

                                  return ListTile(
                                    leading: CircleAvatar(
                                      child: Text(
                                        (cari['unvan']?.toString().trim().isNotEmpty ?? false)
                                            ? cari['unvan'].toString().trim()[0].toUpperCase()
                                            : '?',
                                      ),
                                    ),
                                    title: Text(
                                      cari['unvan']?.toString() ?? '-',
                                      style: TextStyle(
                                        fontWeight: secili
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'ID: ${cari['cari_id'] ?? '-'} • ${cari['cari_tipi'] ?? '-'}',
                                    ),
                                    trailing: secili
                                        ? const Icon(Icons.check_circle, color: Colors.green)
                                        : const Icon(Icons.chevron_right),
                                    onTap: id == null
                                        ? null
                                        : () => Navigator.pop(dialogContext, id),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Vazgeç'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      aramaController.dispose();
    }
  }
}