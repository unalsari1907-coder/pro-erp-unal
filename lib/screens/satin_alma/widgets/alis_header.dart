// lib/screens/satin_alma/widgets/alis_header.dart

import 'package:flutter/material.dart';

import '../../../widgets/cari_sec_dialog.dart';

class AlisHeader extends StatelessWidget {
  final TextEditingController faturaNoController;
  final TextEditingController tarihController;

  final List<Map<String, dynamic>> tedarikciler;
  final List<Map<String, dynamic>> depolar;
  final List<Map<String, dynamic>> kasalar;

  final int? secilenTedarikciId;
  final int? secilenDepoId;
  final int? secilenKasaId;

  final String odemeTipi;

  final ValueChanged<int?> onTedarikciDegisti;
  final ValueChanged<int?> onDepoDegisti;
  final ValueChanged<int?> onKasaDegisti;
  final ValueChanged<String?> onOdemeTipiDegisti;

  const AlisHeader({
    super.key,
    required this.faturaNoController,
    required this.tarihController,
    required this.tedarikciler,
    required this.depolar,
    required this.kasalar,
    required this.secilenTedarikciId,
    required this.secilenDepoId,
    required this.secilenKasaId,
    required this.odemeTipi,
    required this.onTedarikciDegisti,
    required this.onDepoDegisti,
    required this.onKasaDegisti,
    required this.onOdemeTipiDegisti,
  });

  int? _intDeger(dynamic deger) {
    return int.tryParse(
      deger?.toString() ?? '',
    );
  }

  bool get _veresiyeMi {
    final tip = odemeTipi.trim().toLowerCase();

    return tip == 'veresiye' || tip == 'hesap';
  }

  InputDecoration _dekorasyon({
    required String etiket,
    required IconData ikon,
    String? ipucu,
  }) {
    return InputDecoration(
      labelText: etiket,
      hintText: ipucu,
      prefixIcon: Icon(ikon),
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(
        8,
        6,
        8,
        4,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment:
              WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 180,
              child: TextFormField(
                controller: faturaNoController,
                decoration: _dekorasyon(
                  etiket: 'Fatura No',
                  ikon: Icons.receipt_long,
                ),
              ),
            ),
            SizedBox(
              width: 170,
              child: TextFormField(
                controller: tarihController,
                readOnly: true,
                decoration: _dekorasyon(
                  etiket: 'Tarih',
                  ikon: Icons.calendar_month,
                ),
              ),
            ),
            SizedBox(
              width: 320,
              child: InkWell(
                onTap: () async {
                  final secilen = await CariSecDialog.ac(
                    context: context,
                    cariler: tedarikciler,
                    seciliCariId: secilenTedarikciId,
                    baslik: 'Tedarikçi / Cari Seç',
                    aramaIpucu: 'Tedarikçi ünvanı ara...',
                  );

                  if (secilen != null) {
                    onTedarikciDegisti(secilen);
                  }
                },
                child: InputDecorator(
                  decoration: _dekorasyon(
                    etiket: 'Tedarikçi',
                    ikon: Icons.search,
                  ).copyWith(
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(
                    secilenTedarikciId == null
                        ? 'Tedarikçi seçin'
                        : (tedarikciler
                                .where((c) =>
                                    _intDeger(c['cari_id']) ==
                                    secilenTedarikciId)
                                .map((c) => c['unvan']?.toString() ?? '-')
                                .toList()
                                .isEmpty
                            ? 'Tedarikçi seçin'
                            : tedarikciler
                                .where((c) =>
                                    _intDeger(c['cari_id']) ==
                                    secilenTedarikciId)
                                .map((c) => c['unvan']?.toString() ?? '-')
                                .first),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<int>(
                            isExpanded: true,
                value: secilenDepoId,
                decoration: _dekorasyon(
                  etiket: 'Depo',
                  ikon: Icons.warehouse,
                ),
                items: depolar.map((depo) {
                  final id =
                      _intDeger(depo['depo_id']);

                  return DropdownMenuItem<int>(
                    value: id,
                    child: Text(
                      depo['depo_adi']?.toString() ?? '',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: onDepoDegisti,
              ),
            ),
            SizedBox(
              width: 190,
              child:
                  DropdownButtonFormField<String>(
                            isExpanded: true,
                value: odemeTipi,
                decoration: _dekorasyon(
                  etiket: 'Ödeme Tipi',
                  ikon: Icons.payments,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Veresiye',
                    child: Text('Veresiye'),
                  ),
                  DropdownMenuItem(
                    value: 'Nakit',
                    child: Text('Nakit'),
                  ),
                  DropdownMenuItem(
                    value: 'Kredi Kartı',
                    child: Text('Kredi Kartı'),
                  ),
                  DropdownMenuItem(
                    value: 'Havale',
                    child: Text('Havale / EFT'),
                  ),
                ],
                onChanged: onOdemeTipiDegisti,
              ),
            ),
            SizedBox(
              width: 230,
              child: DropdownButtonFormField<int>(
                            isExpanded: true,
                value:
                    _veresiyeMi ? null : secilenKasaId,
                decoration: _dekorasyon(
                  etiket: 'Kasa / Banka',
                  ikon:
                      Icons.account_balance_wallet,
                  ipucu: _veresiyeMi
                      ? 'Veresiye işlemde kullanılmaz'
                      : 'Kasa seçin',
                ),
                items: kasalar.map((kasa) {
                  final id =
                      _intDeger(kasa['kasa_id']);

                  return DropdownMenuItem<int>(
                    value: id,
                    child: Text(
                      kasa['kasa_adi']?.toString() ?? '',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged:
                    _veresiyeMi ? null : onKasaDegisti,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
