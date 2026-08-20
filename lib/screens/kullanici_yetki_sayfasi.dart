import 'package:flutter/material.dart';

import '../widgets/mobil_uyum.dart';
import '../services/supabase_service.dart';
import '../services/yetki_service.dart';

class KullaniciYetkiSayfasi
    extends StatefulWidget {
  const KullaniciYetkiSayfasi({
    super.key,
  });

  @override
  State<KullaniciYetkiSayfasi>
      createState() =>
          _KullaniciYetkiSayfasiState();
}

class _KullaniciYetkiSayfasiState
    extends State<KullaniciYetkiSayfasi> {
  bool _yukleniyor = true;

  List<Map<String, dynamic>>
      _kullanicilar = [];

  static const List<String> _roller = [
    'YONETICI',
    'SATIS',
    'SATIN_ALMA',
    'MUHASEBE',
    'DEPO',
  ];

  static const Map<String, String>
      _yetkiAdlari = {
    'dashboard': 'Dashboard',
    'kritik_stok_siparis_oneri': 'Kritik Stok Sipariş Önerisi',
    'yonetici_kokpiti': 'Yönetici Kokpiti',
    'belge_gecmisi': 'Belge Geçmişi / Zinciri',
    'muhasebe_raporlari': 'Mizan / Muhasebe Raporları',
    'arac_parca_katalog': 'Araç → Parça Kataloğu',
    'vade_yaslandirma': 'Vade Yaşlandırma',
    'kur_farki': 'Kur Farkı Fişleri',
    'sistem_saglik': 'Sistem Sağlık Kontrolü',
    'stok_kartlari': 'Stok Kartları',
    'stok_hareketleri':
        'Stok Hareketleri',
    'depolar': 'Depolar',
    'sayim': 'Sayım',
    'depo_transfer':
        'Depolar Arası Transfer',
    'satis_faturalari':
        'Satış Faturaları',
    'satis_siparisleri':
        'Satış Siparişleri',
    'satis_irsaliyeleri':
        'Satış İrsaliyeleri',
    'satis_iadeleri':
        'Satış İadeleri',
    'alis_faturalari':
        'Alış Faturaları',
    'alis_siparisleri':
        'Alış Siparişleri',
    'alis_irsaliyeleri':
        'Alış İrsaliyeleri',
    'alis_iadeleri':
        'Alış İadeleri',
    'cari_kartlari':
        'Cari Kartları',
    'cari_hareketleri':
        'Cari Hareketleri',
    'vade_takip': 'Vade Takibi',
    'kasalar': 'Kasalar',
    'transfer_virman':
        'Transfer / Virman',
    'kasa_hareketleri':
        'Kasa Hareketleri',
    'kasa_gun_sonu': 'Kasa Gün Sonu',
    'bankalar': 'Bankalar',
    'pos': 'POS',
    'makbuzlar': 'Makbuzlar',
    'gider_masraf':
        'Gider / Masraf',
    'rapor_satis':
        'Rapor - Satış',
    'rapor_alis': 'Rapor - Alış',
    'rapor_stok': 'Rapor - Stok',
    'rapor_cari': 'Rapor - Cari',
    'rapor_kasa': 'Rapor - Kasa',
    'hesap_makinesi': 'Hesap Makinesi',
    'rapor_grafikler':
        'Rapor - Grafikler / Kâr',
    'excel': 'Excel İçe / Dışa Aktarım',
    'pdf': 'PDF / Yazdırma',
    'kullanici_yetki':
        'Kullanıcı / Yetki Yönetimi',
    'ayarlar': 'Ayarlar',
  };

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  String _metin(dynamic d) {
    final s = d?.toString().trim() ?? '';
    return s.isEmpty ? '-' : s;
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);

    try {
      final sonuc =
          await SupabaseService.supabase
              .from('erp_kullanicilar')
              .select(
                'kullanici, eposta, auth_user_id, rol, aktif, yetkiler, '
                'created_at, updated_at',
              )
              .order('kullanici');

      if (!mounted) return;

      setState(() {
        _kullanicilar =
            List<Map<String, dynamic>>.from(
          sonuc,
        );
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _yukleniyor = false);

      _mesaj(
        'Kullanıcılar yüklenemedi: $e',
        Colors.red,
      );
    }
  }

  void _mesaj(
    String mesaj,
    Color renk,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: renk,
      ),
    );
  }

  Future<void> _duzenle({
    Map<String, dynamic>? mevcut,
  }) async {
    final yeniMi = mevcut == null;

    final kullaniciController =
        TextEditingController(
      text: yeniMi
          ? ''
          : _metin(mevcut['kullanici']),
    );
    final epostaController = TextEditingController(
      text: yeniMi ? '' : (mevcut['eposta']?.toString() ?? ''),
    );

    String rol = yeniMi
        ? 'SATIS'
        : _metin(mevcut['rol'])
            .toUpperCase();

    if (!_roller.contains(rol)) {
      rol = 'SATIS';
    }

    bool aktif = yeniMi
        ? true
        : mevcut['aktif'] == true;

    final Map<String, dynamic>
        yetkiler = {};

    if (mevcut?['yetkiler'] is Map) {
      yetkiler.addAll(
        Map<String, dynamic>.from(
          mevcut!['yetkiler'] as Map,
        ),
      );
    }

    bool ozelYetkiKullan =
        yetkiler.isNotEmpty;

    final kaydet =
        await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder:
              (context, setDialogState) {
            return Dialog(
              child: MobilDialogIcerik(
                width: 900,
                height: 720,
                child: Column(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets
                              .all(18),
                      color: Colors
                          .blueGrey.shade800,
                      child: MobilYatayRow(
                        children: [
                          const Icon(
                            Icons
                                .admin_panel_settings,
                            color:
                                Colors.white,
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: Text(
                              yeniMi
                                  ? 'YENİ KULLANICI'
                                  : 'KULLANICI / YETKİ DÜZENLE',
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,
                                fontSize: 20,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.pop(
                                dialogContext,
                                false,
                              );
                            },
                            icon: const Icon(
                              Icons.close,
                              color:
                                  Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child:
                          SingleChildScrollView(
                        padding:
                            const EdgeInsets
                                .all(18),
                        child: Column(
                          children: [
                            MobilYatayRow(
                              children: [
                                Expanded(
                                  child:
                                      TextField(
                                    controller:
                                        kullaniciController,
                                    enabled:
                                        yeniMi,
                                    decoration:
                                        const InputDecoration(
                                      labelText:
                                          'Kullanıcı Adı',
                                      border:
                                          OutlineInputBorder(),
                                      prefixIcon:
                                          Icon(
                                        Icons
                                            .person,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 12,
                                ),
                                Expanded(
                                  child:
                                      DropdownButtonFormField<
                                          String>(
                                    value:
                                        rol,
                                    decoration:
                                        const InputDecoration(
                                      labelText:
                                          'Rol',
                                      border:
                                          OutlineInputBorder(),
                                    ),
                                    items: _roller
                                        .map(
                                          (e) =>
                                              DropdownMenuItem(
                                            value:
                                                e,
                                            child:
                                                Text(
                                              e,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged:
                                        (v) {
                                      if (v ==
                                          null) {
                                        return;
                                      }

                                      setDialogState(
                                        () {
                                          rol =
                                              v;
                                        },
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(
                                  width: 12,
                                ),
                                SizedBox(
                                  width: 150,
                                  child:
                                      SwitchListTile(
                                    title:
                                        const Text(
                                      'Aktif',
                                    ),
                                    value:
                                        aktif,
                                    onChanged:
                                        (v) {
                                      setDialogState(
                                        () {
                                          aktif =
                                              v;
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 14,
                            ),
                            TextField(
                              controller: epostaController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Supabase Auth E-posta',
                                helperText:
                                    'Supabase Authentication kullanıcısındaki e-postayla aynı olmalıdır.',
                                prefixIcon: Icon(Icons.email_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Card(
                              child:
                                  SwitchListTile(
                                title:
                                    const Text(
                                  'Özel yetki kullan',
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                                subtitle:
                                    const Text(
                                  'Kapalıysa rolün varsayılan yetkileri kullanılır. '
                                  'Açıksa aşağıdaki anahtarlar rol yetkisini ezer.',
                                ),
                                value:
                                    ozelYetkiKullan,
                                onChanged:
                                    (v) {
                                  setDialogState(
                                    () {
                                      ozelYetkiKullan =
                                          v;

                                      if (!v) {
                                        yetkiler
                                            .clear();
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(
                              height: 8,
                            ),
                            if (ozelYetkiKullan)
                              GridView.count(
                                shrinkWrap:
                                    true,
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                crossAxisCount:
                                    3,
                                childAspectRatio:
                                    3.8,
                                crossAxisSpacing:
                                    8,
                                mainAxisSpacing:
                                    8,
                                children:
                                    _yetkiAdlari
                                        .entries
                                        .map(
                                  (entry) {
                                    final raw =
                                        yetkiler[
                                            entry
                                                .key];

                                    final deger =
                                        raw ==
                                                true ||
                                            raw
                                                    ?.toString()
                                                    .toLowerCase() ==
                                                'true';

                                    return Card(
                                      child:
                                          CheckboxListTile(
                                        dense:
                                            true,
                                        title:
                                            Text(
                                          entry
                                              .value,
                                          maxLines:
                                              2,
                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                        ),
                                        value:
                                            deger,
                                        onChanged:
                                            (v) {
                                          setDialogState(
                                            () {
                                              yetkiler[
                                                      entry.key] =
                                                  v ==
                                                      true;
                                            },
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets
                              .all(14),
                      decoration:
                          BoxDecoration(
                        color: Colors
                            .grey.shade50,
                        border: Border(
                          top: BorderSide(
                            color: Colors
                                .grey
                                .shade300,
                          ),
                        ),
                      ),
                      child: MobilYatayRow(
                        children: [
                          Text(
                            'Rol: $rol',
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(
                                dialogContext,
                                false,
                              );
                            },
                            child:
                                const Text(
                              'Vazgeç',
                            ),
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          ElevatedButton
                              .icon(
                            onPressed: () {
                              if (kullaniciController
                                  .text
                                  .trim()
                                  .isEmpty) {
                                _mesaj(
                                  'Kullanıcı adı boş olamaz.',
                                  Colors.red,
                                );
                                return;
                              }

                              Navigator.pop(
                                dialogContext,
                                true,
                              );
                            },
                            icon:
                                const Icon(
                              Icons.save,
                            ),
                            label:
                                const Text(
                              'Kaydet',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (kaydet != true) {
      kullaniciController.dispose();
      epostaController.dispose();
      return;
    }

    try {
      final kullanici =
          kullaniciController.text
              .trim()
              .toUpperCase();

      await SupabaseService.supabase
          .from('erp_kullanicilar')
          .upsert({
        'kullanici': kullanici,
        'eposta': epostaController.text.trim().toLowerCase(),
        'rol': rol,
        'aktif': aktif,
        'yetkiler': ozelYetkiKullan
            ? yetkiler
            : <String, dynamic>{},
        'updated_at':
            DateTime.now()
                .toUtc()
                .toIso8601String(),
      });

      kullaniciController.dispose();
      epostaController.dispose();

      if (kullanici ==
          YetkiService.aktifKullanici) {
        await YetkiService.yukle(
          zorla: true,
        );
      }

      _mesaj(
        'Kullanıcı / yetki kaydedildi.',
        Colors.green,
      );

      await _yukle();
    } catch (e) {
      kullaniciController.dispose();
      epostaController.dispose();

      _mesaj(
        'Kullanıcı kaydedilemedi: $e',
        Colors.red,
      );
    }
  }

  Future<void> _aktifKullaniciYap(
    Map<String, dynamic> kullanici,
  ) async {
    final ad =
        _metin(kullanici['kullanici']);

    if (kullanici['aktif'] != true) {
      _mesaj(
        'Pasif kullanıcı aktif kullanıcı yapılamaz.',
        Colors.red,
      );
      return;
    }

    await YetkiService.kullaniciDegistir(
      ad,
    );

    if (!mounted) return;

    setState(() {});

    _mesaj(
      'Aktif kullanıcı: $ad',
      Colors.green,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'KULLANICI / ROL / YETKİ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          MobilAppBarActions(
            children: [
          Chip(
            avatar: const Icon(
              Icons.person,
              size: 18,
            ),
            label: Text(
              'Aktif: ${YetkiService.aktifKullanici} / ${YetkiService.rol}',
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _yukle,
            icon:
                const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        
            ],
          ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: () => _duzenle(),
        icon: const Icon(
          Icons.person_add,
        ),
        label:
            const Text('Yeni Kullanıcı'),
      ),
      body: _yukleniyor
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _kullanicilar.isEmpty
              ? const Center(
                  child: Text(
                    'Kullanıcı kaydı bulunamadı.',
                  ),
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.all(
                    12,
                  ),
                  itemCount:
                      _kullanicilar.length,
                  separatorBuilder:
                      (_, __) =>
                          const SizedBox(
                    height: 8,
                  ),
                  itemBuilder:
                      (context, index) {
                    final k =
                        _kullanicilar[index];

                    final aktif =
                        k['aktif'] == true;

                    final secili =
                        _metin(
                              k['kullanici'],
                            )
                                .toUpperCase() ==
                            YetkiService
                                .aktifKullanici
                                .toUpperCase();

                    final yetkiler =
                        k['yetkiler'];

                    final authEposta =
                        k['eposta']?.toString().trim() ?? '';

                    final ozelYetki =
                        yetkiler is Map &&
                            yetkiler
                                .isNotEmpty;

                    return Card(
                      color: secili
                          ? Colors.green
                              .withOpacity(
                              0.05,
                            )
                          : null,
                      child: ListTile(
                        leading:
                            CircleAvatar(
                          backgroundColor:
                              (aktif
                                      ? Colors
                                          .blue
                                      : Colors
                                          .grey)
                                  .withOpacity(
                            0.14,
                          ),
                          child: Icon(
                            aktif
                                ? Icons
                                    .person
                                : Icons
                                    .person_off,
                            color: aktif
                                ? Colors.blue
                                : Colors.grey,
                          ),
                        ),
                        title: MobilYatayRow(
                          children: [
                            Text(
                              _metin(
                                k['kullanici'],
                              ),
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Chip(
                              label: Text(
                                _metin(
                                  k['rol'],
                                ),
                              ),
                              visualDensity:
                                  VisualDensity
                                      .compact,
                            ),
                            if (secili) ...[
                              const SizedBox(
                                width: 8,
                              ),
                              const Chip(
                                avatar: Icon(
                                  Icons
                                      .check_circle,
                                  size: 16,
                                ),
                                label: Text(
                                  'AKTİF OTURUM',
                                ),
                                visualDensity:
                                    VisualDensity
                                        .compact,
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '${aktif ? 'Aktif' : 'Pasif'} • '
                          '${ozelYetki ? 'Özel yetkiler tanımlı' : 'Rol varsayılan yetkileri'} • '
                          '${authEposta.isEmpty ? 'Auth e-posta yok' : authEposta}',
                        ),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            OutlinedButton.icon(
                              onPressed: aktif
                                  ? () =>
                                      _aktifKullaniciYap(
                                        k,
                                      )
                                  : null,
                              icon:
                                  const Icon(
                                Icons.login,
                              ),
                              label:
                                  const Text(
                                'Aktif Kullanıcı Yap',
                              ),
                            ),
                            IconButton(
                              tooltip:
                                  'Düzenle',
                              onPressed: () =>
                                  _duzenle(
                                mevcut: k,
                              ),
                              icon:
                                  const Icon(
                                Icons.edit,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}


/// Eski ekran adlarıyla uyumluluk için alias.
/// AyarlarSayfasi içinde KullaniciYetkileriSayfasi kullanılıyorsa
/// aynı ekranı açar.
class KullaniciYetkileriSayfasi extends KullaniciYetkiSayfasi {
  const KullaniciYetkileriSayfasi({super.key});
}
