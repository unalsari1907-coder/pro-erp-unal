// lib/screens/dashboard_sayfasi.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/stok_model.dart';
import '../services/supabase_service.dart';
import '../services/doviz_kur_service.dart';

import 'alis_faturalari_sayfasi.dart';
import 'alis_irsaliyeleri_screen.dart';
import 'alis_siparisleri_screen.dart';
import 'ayarlar_sayfasi.dart';
import 'cari_hareketleri_sayfasi.dart';
import 'cariler_sayfasi.dart';
import 'iadeler_sayfasi.dart';
import 'kasa_banka_sayfasi.dart';
import 'kasa_hareketleri_sayfasi.dart';
import 'makbuzlar_sayfasi.dart';
import 'raporlar_sayfasi.dart';
import 'gider_masraf_sayfasi.dart';
import 'kullanici_yetki_sayfasi.dart';
import '../services/yetki_service.dart';
import 'satis_faturalari_sayfasi.dart';
import 'satis_irsaliyeleri_screen.dart';
import 'siparisler_screen.dart';
import 'stok_hareket_screen.dart';
import 'stok_sayfasi.dart';
import 'depolar_screen.dart';
import 'sayim_screen.dart';
import 'depo_transfer_screen.dart';
import 'finans_transfer_virman_sayfasi.dart';
import 'vade_takip_sayfasi.dart';
import 'kasa_gun_sonu_sayfasi.dart';
import 'kurumsal_moduller_sayfasi.dart';
import 'doviz_kur_sayfasi.dart';
import 'operasyon_merkezi_sayfasi.dart';
import 'hesap_makinesi_sayfasi.dart';
import 'belge_gecmisi_sayfasi.dart';
import 'yonetici_kokpiti_sayfasi.dart';
import 'muhasebe_raporlari_sayfasi.dart';
import 'arac_parca_katalog_sayfasi.dart';
import 'vade_yaslandirma_sayfasi.dart';
import 'kur_farki_sayfasi.dart';
import 'sistem_saglik_sayfasi.dart';
import 'kritik_stok_siparis_oneri_sayfasi.dart';
import 'pazaryeri_merkezi_sayfasi.dart';

class DashboardSayfasi extends StatefulWidget {
  const DashboardSayfasi({super.key});

  @override
  State<DashboardSayfasi> createState() => _DashboardSayfasiState();
}

class _DashboardSayfasiState extends State<DashboardSayfasi> {
  static const double _genisMenu = 286;
  static const double _darMenu = 76;

  final TextEditingController _menuAramaController = TextEditingController();
  final FocusNode _menuAramaFocusNode = FocusNode(debugLabel: 'erpMenuArama');
  final ScrollController _menuScrollController = ScrollController();

  String _seciliSayfa = 'dashboard';
  String _menuArama = '';

  final List<String> _acikSayfalar = <String>['dashboard'];

  bool _menuDar = false;
  bool _mobilMod = false;

  bool get _menuDarEtkin => !_mobilMod && _menuDar;

  final Set<String> _acikGruplar = <String>{'stok'};

  bool yukleniyor = true;

  double bugunkuCiro = 0.0;
  double toplamAlacak = 0.0;

  int toplamStokCesidi = 0;
  int kritikStokSayisi = 0;
  int bugunkuSatisSayisi = 0;

  List<StokModel> kritikStoklar = [];
  List<Map<String, dynamic>> enCokSatilanlar = [];
  List<Map<String, dynamic>> sonSatislar = [];
  List<double> aylikKarlar = List<double>.filled(6, 0);
  List<String> aylikKarEtiketleri = List<String>.filled(6, '');
  int gecikenVadeSayisi = 0;

  bool _dashboardYuklemeDevam = false;
  DateTime? _sonDashboardYukleme;

  double _sayi(dynamic deger) {
    if (deger is num) return deger.toDouble();
    return double.tryParse(deger?.toString().replaceAll(',', '.') ?? '0') ?? 0;
  }

  bool _iptalMi(dynamic durum) {
    final metin = durum?.toString().trim().toUpperCase() ?? '';
    return metin == 'IPTAL' || metin == 'İPTAL';
  }

  String _ayKisaltma(int ay) {
    const aylar = <String>[
      'OCA',
      'ŞUB',
      'MAR',
      'NİS',
      'MAY',
      'HAZ',
      'TEM',
      'AĞU',
      'EYL',
      'EKİ',
      'KAS',
      'ARA',
    ];
    return aylar[ay - 1];
  }

  @override
  void initState() {
    super.initState();

    _menuAramaController.addListener(() {
      if (!mounted) return;

      setState(() {
        _menuArama = _menuAramaController.text.toLowerCase().trim();
      });
    });

    YetkiService.yukle(zorla: true).then((_) {
      if (mounted) setState(() {});
    });

    dashboardVerileriniYukle();

    // Günün TCMB kuru yoksa ERP ilk açılışta sessizce günceller.
    DovizKurService.gunlukKurKontrolEt();
  }

  @override
  void dispose() {
    _menuAramaController.dispose();
    _menuAramaFocusNode.dispose();
    _menuScrollController.dispose();
    super.dispose();
  }

  Future<void> dashboardVerileriniYukle({bool zorla = false}) async {
    if (!mounted || _dashboardYuklemeDevam) return;

    final son = _sonDashboardYukleme;
    if (!zorla &&
        son != null &&
        DateTime.now().difference(son) < const Duration(seconds: 45) &&
        !yukleniyor) {
      return;
    }

    _dashboardYuklemeDevam = true;

    setState(() {
      yukleniyor = true;
    });

    try {
      final tumStoklar = await SupabaseService.stoklariGetir();

      final kritikler = tumStoklar.where((stok) {
        return stok.aktif && stok.stokMiktari <= stok.minimumStok;
      }).toList();

      final simdi = DateTime.now();

      final bugunBaslangic = DateTime(simdi.year, simdi.month, simdi.day);

      double ciroToplam = 0.0;
      final List<Map<String, dynamic>> bugunSatisListesi = [];

      try {
        final bugunSatisResponse = await SupabaseService.supabase
            .from('satis_baslik')
            .select()
            .gte('tarih', bugunBaslangic.toIso8601String())
            .order('tarih', ascending: false);

        final satislar = List<Map<String, dynamic>>.from(bugunSatisResponse);

        for (final item in satislar) {
          if (_iptalMi(item['durum'])) {
            continue;
          }

          final dynamic tutarRaw =
              item['genel_toplam'] ?? item['toplam_tutar'] ?? 0;

          final double tutar = tutarRaw is num
              ? tutarRaw.toDouble()
              : double.tryParse(tutarRaw.toString()) ?? 0.0;

          ciroToplam += tutar;
          bugunSatisListesi.add(item);
        }
      } catch (e) {
        debugPrint('⚠️ Bugünkü satışlar yüklenemedi: $e');
      }

      final aylikKar = List<double>.filled(6, 0);
      final aylikEtiket = List<String>.filled(6, '');
      final aylikBaslangic = DateTime(simdi.year, simdi.month - 5, 1);

      for (var i = 0; i < 6; i++) {
        final ay = DateTime(aylikBaslangic.year, aylikBaslangic.month + i, 1);
        aylikEtiket[i] = _ayKisaltma(ay.month);
      }

      try {
        final baslikResponse = await SupabaseService.supabase
            .from('satis_baslik')
            .select('satis_id, tarih, durum')
            .gte('tarih', aylikBaslangic.toUtc().toIso8601String());

        final basliklar = List<Map<String, dynamic>>.from(baslikResponse)
            .where((item) => !_iptalMi(item['durum']))
            .toList();

        final tarihHaritasi = <int, DateTime>{};
        for (final baslik in basliklar) {
          final id = int.tryParse(baslik['satis_id']?.toString() ?? '');
          final tarih = DateTime.tryParse(baslik['tarih']?.toString() ?? '')
              ?.toLocal();
          if (id != null && tarih != null) {
            tarihHaritasi[id] = tarih;
          }
        }

        if (tarihHaritasi.isNotEmpty) {
          final detayResponse = await SupabaseService.supabase
              .from('satis_detay')
              .select('satis_id, miktar, birim_fiyat, indirim, alis_fiyati')
              .inFilter('satis_id', tarihHaritasi.keys.toList());

          for (final detay in List<Map<String, dynamic>>.from(detayResponse)) {
            final satisId = int.tryParse(detay['satis_id']?.toString() ?? '');
            final tarih = satisId == null ? null : tarihHaritasi[satisId];
            if (tarih == null) continue;

            final ayIndex =
                (tarih.year - aylikBaslangic.year) * 12 +
                tarih.month -
                aylikBaslangic.month;
            if (ayIndex < 0 || ayIndex >= 6) continue;

            final miktar = _sayi(detay['miktar']);
            final fiyat = _sayi(detay['birim_fiyat']);
            final indirim = _sayi(detay['indirim']);
            final maliyet = _sayi(detay['alis_fiyati']);
            final netSatis = miktar * fiyat * (1 - indirim / 100);

            aylikKar[ayIndex] += netSatis - miktar * maliyet;
          }
        }
      } catch (e) {
        debugPrint('Aylık kâr grafiği yüklenemedi: $e');
      }

      var gecikenSayisi = 0;
      try {
        final vadeResponse = await SupabaseService.supabase
            .from('erp_vade_takip')
            .select('gecikme_gun, kalan_tutar');
        gecikenSayisi = List<Map<String, dynamic>>.from(vadeResponse)
            .where(
              (item) =>
                  _sayi(item['gecikme_gun']) > 0 &&
                  _sayi(item['kalan_tutar']) > 0,
            )
            .length;
      } catch (e) {
        debugPrint('Geciken vade özeti yüklenemedi: $e');
      }

      double alacakToplam = 0.0;

      try {
        final cariResponse = await SupabaseService.supabase
            .from('cariler')
            .select('bakiye');

        final cariler = List<Map<String, dynamic>>.from(cariResponse);

        for (final cari in cariler) {
          final bakiye =
              double.tryParse(cari['bakiye']?.toString() ?? '0') ?? 0.0;

          if (bakiye > 0) {
            alacakToplam += bakiye;
          }
        }
      } catch (e) {
        debugPrint('⚠️ Cari bakiye okuma uyarısı: $e');
      }

      if (!mounted) return;

      setState(() {
        toplamStokCesidi = tumStoklar.length;

        kritikStoklar = kritikler;
        kritikStokSayisi = kritikler.length;

        bugunkuCiro = ciroToplam;
        toplamAlacak = alacakToplam;

        enCokSatilanlar = const [];
        bugunkuSatisSayisi = bugunSatisListesi.length;
        sonSatislar = bugunSatisListesi.take(5).toList();
        aylikKarlar = aylikKar;
        aylikKarEtiketleri = aylikEtiket;
        gecikenVadeSayisi = gecikenSayisi;

        yukleniyor = false;
        _sonDashboardYukleme = DateTime.now();
      });
    } catch (e) {
      debugPrint('❌ Dashboard yükleme hatası: $e');

      if (!mounted) return;

      setState(() {
        yukleniyor = false;
      });
    } finally {
      _dashboardYuklemeDevam = false;
    }
  }

  Widget _sayfaGetir(String sayfaId) {
    switch (sayfaId) {
      case 'stok_kartlari':
        return const StokSayfasi();

      case 'stok_hareketleri':
        return const StokHareketleriSayfasi();

      case 'depolar':
        return const DepolarScreen();

      case 'sayim':
        return const SayimScreen();

      case 'depo_transfer':
        return const DepoTransferScreen();

      case 'satis_faturalari':
        return const SatisFaturalariSayfasi();

      case 'satis_siparisleri':
        return const SiparislerScreen();

      case 'satis_irsaliyeleri':
        return const SatisIrsaliyeleriScreen();

      case 'satis_iadeleri':
        return const IadelerSayfasi();

      case 'alis_faturalari':
        return const AlisFaturalariSayfasi();

      case 'alis_siparisleri':
        return const AlisSiparisleriScreen();

      case 'alis_irsaliyeleri':
        return const AlisIrsaliyeleriScreen();

      case 'alis_iadeleri':
        return const IadelerSayfasi(baslangicTipi: 'ALIS_IADE');

      case 'cari_kartlari':
        return const CarilerSayfasi();

      case 'cari_hareketleri':
        return const CariHareketleriSayfasi();

      case 'vade_takip':
        return const VadeTakipSayfasi();

      case 'kasalar':
        return const KasaBankaSayfasi();

      case 'transfer_virman':
        return const FinansTransferVirmanSayfasi();

      case 'kasa_hareketleri':
        return const KasaHareketleriSayfasi();

      case 'kasa_gun_sonu':
        return const KasaGunSonuSayfasi();

      case 'bankalar':
        return const KasaBankaSayfasi(gorunum: 'BANKA');

      case 'pos':
        return const KasaBankaSayfasi(gorunum: 'POS');

      case 'makbuzlar':
        return const MakbuzlarSayfasi();

      case 'gider_masraf':
        return const GiderMasrafSayfasi();

      case 'rapor_satis':
        return const RaporlarSayfasi(baslangicSekmesi: 0);
      case 'rapor_alis':
        return const RaporlarSayfasi(baslangicSekmesi: 1);
      case 'rapor_stok':
        return const RaporlarSayfasi(baslangicSekmesi: 2);
      case 'rapor_cari':
        return const RaporlarSayfasi(baslangicSekmesi: 3);
      case 'rapor_kasa':
        return const RaporlarSayfasi(baslangicSekmesi: 4);

      case 'operasyon_merkezi':
        return const OperasyonMerkeziSayfasi();
      case 'yonetici_kokpiti':
        return const YoneticiKokpitiSayfasi();
      case 'belge_gecmisi':
        return const BelgeGecmisiSayfasi();
      case 'muhasebe_raporlari':
        return const MuhasebeRaporlariSayfasi();
      case 'arac_parca_katalog':
        return const AracParcaKatalogSayfasi();
      case 'pazaryeri_merkezi':
        return const PazaryeriMerkeziSayfasi(baslangicSekmesi: 0);
      case 'pazaryeri_siparis':
        return const PazaryeriMerkeziSayfasi(baslangicSekmesi: 1);
      case 'pazaryeri_urun':
        return const PazaryeriMerkeziSayfasi(baslangicSekmesi: 2);
      case 'pazaryeri_iade':
        return const PazaryeriMerkeziSayfasi(baslangicSekmesi: 3);
      case 'pazaryeri_magaza':
        return const PazaryeriMerkeziSayfasi(baslangicSekmesi: 4);
      case 'vade_yaslandirma':
        return const VadeYaslandirmaSayfasi();
      case 'kur_farki':
        return const KurFarkiSayfasi();
      case 'sistem_saglik':
        return const SistemSaglikSayfasi();
      case 'teklif_proforma':
        return const KurumsalModulSayfasi(tanim: KurumsalModuller.teklif);
      case 'hesap_plani':
        return const KurumsalModulSayfasi(tanim: KurumsalModuller.hesapPlani);
      case 'muhasebe_fisleri':
        return const KurumsalModulSayfasi(
          tanim: KurumsalModuller.muhasebeFisleri,
        );
      case 'cek_senet':
        return const KurumsalModulSayfasi(tanim: KurumsalModuller.cekSenet);
      case 'doviz_kur':
        return const DovizKurSayfasi();
      case 'hesap_makinesi':
        return const HesapMakinesiSayfasi();
      case 'e_belge':
        return const KurumsalModulSayfasi(tanim: KurumsalModuller.eBelge);
      case 'satin_alma_talepleri':
        return const KurumsalModulSayfasi(
          tanim: KurumsalModuller.satinAlmaTalep,
        );
      case 'kritik_stok_siparis_oneri':
        return const KritikStokSiparisOneriSayfasi();
      case 'onay_merkezi':
        return const KurumsalModulSayfasi(tanim: KurumsalModuller.onay);
      case 'seri_lot':
        return const KurumsalModulSayfasi(tanim: KurumsalModuller.seriLot);
      case 'kampanya_fiyat':
        return const KurumsalModulSayfasi(tanim: KurumsalModuller.kampanya);

      case 'kullanici_yetki':
        return const KullaniciYetkiSayfasi();

      case 'ayarlar':
        return const AyarlarSayfasi();

      case 'dashboard':
      default:
        return _buildAnaSayfaIcerik();
    }
  }

  Future<void> _sayfaSec(String sayfaId, {String? grupId}) async {
    final izin = await YetkiService.yetkiliMi(sayfaId);

    if (!izin) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bu bölüme giriş yetkiniz yok. '
            'Kullanıcı: ${YetkiService.aktifKullanici} • '
            'Rol: ${YetkiService.rol}',
          ),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    if (!mounted) return;

    setState(() {
      if (!_acikSayfalar.contains(sayfaId)) {
        _acikSayfalar.add(sayfaId);
      }

      _seciliSayfa = sayfaId;

      // Telefonda çok sayıda ağır ERP ekranını aynı IndexedStack içinde
      // sonsuza kadar açık tutmak RAM ve tarayıcı performansını düşürür.
      // Dashboard + son iki çalışma ekranını koruyoruz. Masaüstü davranışı
      // değişmez; telefonda da bir önceki ekran kapanmadan hızlı geçiş sürer.
      if (_mobilMod && _acikSayfalar.length > 3) {
        while (_acikSayfalar.length > 3) {
          final silinecek = _acikSayfalar.firstWhere(
            (id) => id != 'dashboard' && id != _seciliSayfa,
            orElse: () => '',
          );
          if (silinecek.isEmpty) break;
          _acikSayfalar.remove(silinecek);
        }
      }

      if (grupId != null) {
        _acikGruplar.add(grupId);
      }
    });

    if (MediaQuery.sizeOf(context).width < 900 &&
        Navigator.of(context).canPop()) {
      await Navigator.of(context).maybePop();
    }
  }

  void _grupDegistir(String grupId) {
    setState(() {
      if (_acikGruplar.contains(grupId)) {
        _acikGruplar.remove(grupId);
      } else {
        _acikGruplar.add(grupId);
      }
    });
  }

  String _sayfaBasligi(String sayfaId) {
    const basliklar = <String, String>{
      'dashboard': 'Dashboard',
      'stok_kartlari': 'Stok Kartları',
      'stok_hareketleri': 'Stok Hareketleri',
      'depolar': 'Depolar',
      'sayim': 'Sayım',
      'depo_transfer': 'Depolar Arası Transfer',
      'satis_faturalari': 'Satış Faturaları',
      'satis_siparisleri': 'Satış Siparişleri',
      'satis_irsaliyeleri': 'Satış İrsaliyeleri',
      'satis_iadeleri': 'Satış İadeleri',
      'alis_faturalari': 'Alış Faturaları',
      'alis_siparisleri': 'Alış Siparişleri',
      'alis_irsaliyeleri': 'Alış İrsaliyeleri',
      'alis_iadeleri': 'Alış İadeleri',
      'cari_kartlari': 'Cari Kartları',
      'cari_hareketleri': 'Cari Hareketleri',
      'vade_takip': 'Vade Takibi',
      'kasalar': 'Kasalar',
      'transfer_virman': 'Transfer / Virman',
      'kasa_hareketleri': 'Kasa Hareketleri',
      'kasa_gun_sonu': 'Kasa Gün Sonu',
      'bankalar': 'Bankalar',
      'pos': 'POS',
      'makbuzlar': 'Makbuzlar',
      'gider_masraf': 'Gider / Masraf',
      'rapor_satis': 'Satış Raporu',
      'rapor_alis': 'Alış Raporu',
      'rapor_stok': 'Stok Raporu',
      'rapor_cari': 'Cari Raporu',
      'rapor_kasa': 'Kasa Raporu',
      'operasyon_merkezi': 'Yönetici / Operasyon Merkezi',
      'yonetici_kokpiti': 'Yönetici Kokpiti',
      'belge_gecmisi': 'Belge Geçmişi / Zinciri',
      'muhasebe_raporlari': 'Muhasebe Raporları / Mizan',
      'arac_parca_katalog': 'Araç → Parça Kataloğu',
      'pazaryeri_merkezi': 'Pazaryeri / E-Ticaret Merkezi',
      'pazaryeri_siparis': 'Pazaryeri Siparişleri',
      'pazaryeri_urun': 'Ürün / Stok / Fiyat Senkronizasyonu',
      'pazaryeri_iade': 'İade / Kargo Merkezi',
      'pazaryeri_magaza': 'Pazaryeri Mağazaları',
      'vade_yaslandirma': 'Vade Yaşlandırma',
      'kur_farki': 'Kur Farkı Fişleri',
      'sistem_saglik': 'Sistem Sağlık Kontrolü',
      'teklif_proforma': 'Teklif / Proforma',
      'hesap_plani': 'Hesap Planı',
      'muhasebe_fisleri': 'Muhasebe Fişleri',
      'cek_senet': 'Çek / Senet',
      'doviz_kur': 'Döviz / Kur',
      'hesap_makinesi': 'Hesap Makinesi',
      'e_belge': 'e-Belge Merkezi',
      'satin_alma_talepleri': 'Satın Alma Talepleri',
      'kritik_stok_siparis_oneri': 'Kritik Stok Sipariş Önerisi',
      'onay_merkezi': 'Onay Merkezi',
      'seri_lot': 'Seri / Lot Takibi',
      'kampanya_fiyat': 'Kampanya / Fiyat Listeleri',
      'kullanici_yetki': 'Kullanıcı / Yetki',
      'ayarlar': 'Ayarlar',
    };

    return basliklar[sayfaId] ?? sayfaId;
  }

  void _sayfaKapat(String sayfaId) {
    if (sayfaId == 'dashboard') return;

    final kapananIndex = _acikSayfalar.indexOf(sayfaId);
    if (kapananIndex < 0) return;

    setState(() {
      final seciliSayfaKapaniyor = _seciliSayfa == sayfaId;
      _acikSayfalar.removeAt(kapananIndex);

      if (seciliSayfaKapaniyor) {
        var yeniIndex = kapananIndex - 1;

        if (yeniIndex < 0) {
          yeniIndex = 0;
        }

        if (yeniIndex >= _acikSayfalar.length) {
          yeniIndex = _acikSayfalar.length - 1;
        }

        _seciliSayfa = _acikSayfalar[yeniIndex];
      }
    });
  }

  Widget _acikSayfaSekmeleri() {
    final tema = Theme.of(context);
    final seciliRenk = tema.colorScheme.primary;

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: tema.colorScheme.surface,
        border: Border(bottom: BorderSide(color: tema.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 5),
              itemCount: _acikSayfalar.length,
              separatorBuilder: (_, __) => const SizedBox(width: 5),
              itemBuilder: (context, index) {
                final sayfaId = _acikSayfalar[index];
                final secili = sayfaId == _seciliSayfa;

                return Material(
                  color: secili
                      ? seciliRenk.withOpacity(0.13)
                      : Colors.grey.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() {
                        _seciliSayfa = sayfaId;
                      });
                    },
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 110,
                        maxWidth: 220,
                      ),
                      padding: const EdgeInsets.only(left: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: secili
                              ? seciliRenk.withOpacity(0.45)
                              : tema.dividerColor,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _sayfaBasligi(sayfaId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: secili ? seciliRenk : null,
                                fontSize: 13,
                                fontWeight: secili
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (sayfaId != 'dashboard')
                            IconButton(
                              tooltip: 'Sekmeyi kapat',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              onPressed: () => _sayfaKapat(sayfaId),
                              icon: const Icon(Icons.close_rounded, size: 17),
                            )
                          else
                            const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const VerticalDivider(width: 1),
          IconButton(
            tooltip: 'Hesap Makinesi',
            onPressed: () => HesapMakinesiSayfasi.dialogAc(context),
            icon: const Icon(Icons.calculate_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  bool _aramaEslesiyor(String grupBasligi, List<_AltMenuModel> altMenuler) {
    if (_menuArama.isEmpty) return true;

    if (grupBasligi.toLowerCase().contains(_menuArama)) {
      return true;
    }

    return altMenuler.any(
      (item) => item.baslik.toLowerCase().contains(_menuArama),
    );
  }

  Widget _solMenu({bool mobil = false}) {
    const menuRengi = Color(0xFF102A43);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: mobil ? double.infinity : (_menuDarEtkin ? _darMenu : _genisMenu),
      color: menuRengi,
      child: Column(
        children: [
          _menuBaslik(mobil: mobil),
          const Divider(height: 1, color: Colors.white12),
          if (!_menuDarEtkin) _menuAramaKutusu(),
          Expanded(
            child: Scrollbar(
              controller: _menuScrollController,
              thumbVisibility: true,
              child: ListView(
                controller: _menuScrollController,
                padding: const EdgeInsets.fromLTRB(0, 8, 8, 28),
                children: [
                  _tekMenu(
                    id: 'dashboard',
                    baslik: 'Dashboard',
                    ikon: Icons.dashboard_rounded,
                  ),
                  _tekMenu(
                    id: 'arac_parca_katalog',
                    baslik: 'Araç → Parça Kataloğu',
                    ikon: Icons.car_repair_rounded,
                  ),
                  _menuGrubu(
                    id: 'pazaryeri',
                    baslik: 'Pazaryeri / E-Ticaret',
                    ikon: Icons.language_rounded,
                    altMenuler: const [
                      _AltMenuModel(
                        id: 'pazaryeri_merkezi',
                        baslik: 'E-Ticaret Merkezi',
                        ikon: Icons.space_dashboard_rounded,
                      ),
                      _AltMenuModel(
                        id: 'pazaryeri_siparis',
                        baslik: 'Sipariş Merkezi',
                        ikon: Icons.shopping_bag_rounded,
                      ),
                      _AltMenuModel(
                        id: 'pazaryeri_urun',
                        baslik: 'Ürün / Stok / Fiyat',
                        ikon: Icons.sync_rounded,
                      ),
                      _AltMenuModel(
                        id: 'pazaryeri_iade',
                        baslik: 'İade / Kargo',
                        ikon: Icons.local_shipping_rounded,
                      ),
                      _AltMenuModel(
                        id: 'pazaryeri_magaza',
                        baslik: 'Mağazalar / API',
                        ikon: Icons.storefront_rounded,
                      ),
                    ],
                  ),
                  _menuGrubu(
                    id: 'stok',
                    baslik: 'Stok',
                    ikon: Icons.inventory_2_rounded,
                    altMenuler: const [
                      _AltMenuModel(
                        id: 'stok_kartlari',
                        baslik: 'Stok Kartları',
                        ikon: Icons.inventory_rounded,
                      ),
                      _AltMenuModel(
                        id: 'stok_hareketleri',
                        baslik: 'Stok Hareketleri',
                        ikon: Icons.swap_vert_rounded,
                      ),
                      _AltMenuModel(
                        id: 'depolar',
                        baslik: 'Depolar',
                        ikon: Icons.warehouse_rounded,
                      ),
                      _AltMenuModel(
                        id: 'sayim',
                        baslik: 'Sayım',
                        ikon: Icons.fact_check_rounded,
                      ),
                      _AltMenuModel(
                        id: 'depo_transfer',
                        baslik: 'Depolar Arası Transfer',
                        ikon: Icons.compare_arrows_rounded,
                      ),
                    ],
                  ),
                  _menuGrubu(
                    id: 'satis',
                    baslik: 'Satış',
                    ikon: Icons.point_of_sale_rounded,
                    altMenuler: const [
                      _AltMenuModel(
                        id: 'satis_faturalari',
                        baslik: 'Satış Faturaları',
                        ikon: Icons.receipt_long_rounded,
                      ),
                      _AltMenuModel(
                        id: 'satis_siparisleri',
                        baslik: 'Satış Siparişleri',
                        ikon: Icons.assignment_rounded,
                      ),
                      _AltMenuModel(
                        id: 'satis_irsaliyeleri',
                        baslik: 'Satış İrsaliyeleri',
                        ikon: Icons.local_shipping_rounded,
                      ),
                      _AltMenuModel(
                        id: 'satis_iadeleri',
                        baslik: 'Satış İadeleri',
                        ikon: Icons.keyboard_return_rounded,
                      ),
                    ],
                  ),
                  _menuGrubu(
                    id: 'satin_alma',
                    baslik: 'Satın Alma',
                    ikon: Icons.shopping_cart_rounded,
                    altMenuler: const [
                      _AltMenuModel(
                        id: 'alis_faturalari',
                        baslik: 'Alış Faturaları',
                        ikon: Icons.receipt_rounded,
                      ),
                      _AltMenuModel(
                        id: 'alis_siparisleri',
                        baslik: 'Alış Siparişleri',
                        ikon: Icons.shopping_bag_rounded,
                      ),
                      _AltMenuModel(
                        id: 'alis_irsaliyeleri',
                        baslik: 'Alış İrsaliyeleri',
                        ikon: Icons.local_shipping_outlined,
                      ),
                      _AltMenuModel(
                        id: 'alis_iadeleri',
                        baslik: 'Alış İadeleri',
                        ikon: Icons.assignment_return_rounded,
                      ),
                    ],
                  ),
                  _menuGrubu(
                    id: 'cari',
                    baslik: 'Cari',
                    ikon: Icons.people_rounded,
                    altMenuler: const [
                      _AltMenuModel(
                        id: 'cari_kartlari',
                        baslik: 'Cari Kartları',
                        ikon: Icons.person_rounded,
                      ),
                      _AltMenuModel(
                        id: 'cari_hareketleri',
                        baslik: 'Cari Hareketleri',
                        ikon: Icons.payments_rounded,
                      ),
                      _AltMenuModel(
                        id: 'vade_takip',
                        baslik: 'Vade Takibi',
                        ikon: Icons.event_busy_rounded,
                      ),
                    ],
                  ),
                  _menuGrubu(
                    id: 'kasa_banka',
                    baslik: 'Kasa / Banka',
                    ikon: Icons.account_balance_wallet_rounded,
                    altMenuler: const [
                      _AltMenuModel(
                        id: 'kasalar',
                        baslik: 'Kasalar',
                        ikon: Icons.payments_rounded,
                      ),
                      _AltMenuModel(
                        id: 'transfer_virman',
                        baslik: 'Transfer / Virman',
                        ikon: Icons.compare_arrows_rounded,
                      ),
                      _AltMenuModel(
                        id: 'kasa_hareketleri',
                        baslik: 'Kasa Hareketleri',
                        ikon: Icons.swap_horiz_rounded,
                      ),
                      _AltMenuModel(
                        id: 'kasa_gun_sonu',
                        baslik: 'Kasa Gün Sonu',
                        ikon: Icons.fact_check_rounded,
                      ),
                      _AltMenuModel(
                        id: 'bankalar',
                        baslik: 'Bankalar',
                        ikon: Icons.account_balance_rounded,
                      ),
                      _AltMenuModel(
                        id: 'pos',
                        baslik: 'POS',
                        ikon: Icons.credit_card_rounded,
                      ),
                      _AltMenuModel(
                        id: 'makbuzlar',
                        baslik: 'Makbuzlar',
                        ikon: Icons.description_rounded,
                      ),
                      _AltMenuModel(
                        id: 'gider_masraf',
                        baslik: 'Gider / Masraf',
                        ikon: Icons.receipt_long_rounded,
                      ),
                    ],
                  ),
                  _menuGrubu(
                    id: 'kurumsal',
                    baslik: 'Kurumsal ERP',
                    ikon: Icons.business_center_rounded,
                    altMenuler: const [
                      _AltMenuModel(
                        id: 'yonetici_kokpiti',
                        baslik: 'Yönetici Kokpiti',
                        ikon: Icons.space_dashboard_rounded,
                      ),
                      _AltMenuModel(
                        id: 'operasyon_merkezi',
                        baslik: 'Operasyon Merkezi',
                        ikon: Icons.dashboard_customize_rounded,
                      ),
                      _AltMenuModel(
                        id: 'belge_gecmisi',
                        baslik: 'Belge Geçmişi / Zinciri',
                        ikon: Icons.account_tree_rounded,
                      ),
                      _AltMenuModel(
                        id: 'teklif_proforma',
                        baslik: 'Teklif / Proforma',
                        ikon: Icons.request_quote_rounded,
                      ),
                      _AltMenuModel(
                        id: 'satin_alma_talepleri',
                        baslik: 'Satın Alma Talepleri',
                        ikon: Icons.playlist_add_check_circle_rounded,
                      ),
                      _AltMenuModel(
                        id: 'kritik_stok_siparis_oneri',
                        baslik: 'Kritik Stok Sipariş Önerisi',
                        ikon: Icons.add_shopping_cart_rounded,
                      ),
                      _AltMenuModel(
                        id: 'onay_merkezi',
                        baslik: 'Onay Merkezi',
                        ikon: Icons.approval_rounded,
                      ),
                      _AltMenuModel(
                        id: 'kampanya_fiyat',
                        baslik: 'Kampanya / Fiyat Listeleri',
                        ikon: Icons.price_change_rounded,
                      ),
                      _AltMenuModel(
                        id: 'seri_lot',
                        baslik: 'Seri / Lot Takibi',
                        ikon: Icons.qr_code_2_rounded,
                      ),
                    ],
                  ),
                  _menuGrubu(
                    id: 'finans_muhasebe',
                    baslik: 'Finans / Muhasebe',
                    ikon: Icons.account_balance_rounded,
                    altMenuler: const [
                      _AltMenuModel(
                        id: 'hesap_plani',
                        baslik: 'Hesap Planı',
                        ikon: Icons.account_tree_rounded,
                      ),
                      _AltMenuModel(
                        id: 'muhasebe_fisleri',
                        baslik: 'Muhasebe Fişleri',
                        ikon: Icons.menu_book_rounded,
                      ),
                      _AltMenuModel(
                        id: 'muhasebe_raporlari',
                        baslik: 'Mizan / Muhasebe Raporları',
                        ikon: Icons.table_chart_rounded,
                      ),
                      _AltMenuModel(
                        id: 'cek_senet',
                        baslik: 'Çek / Senet',
                        ikon: Icons.payments_outlined,
                      ),
                      _AltMenuModel(
                        id: 'doviz_kur',
                        baslik: 'Döviz / Kur',
                        ikon: Icons.currency_exchange_rounded,
                      ),
                      _AltMenuModel(
                        id: 'kur_farki',
                        baslik: 'Kur Farkı Fişleri',
                        ikon: Icons.trending_up_rounded,
                      ),
                      _AltMenuModel(
                        id: 'hesap_makinesi',
                        baslik: 'Hesap Makinesi',
                        ikon: Icons.calculate_rounded,
                      ),
                      _AltMenuModel(
                        id: 'e_belge',
                        baslik: 'e-Belge Merkezi',
                        ikon: Icons.cloud_upload_rounded,
                      ),
                      _AltMenuModel(
                        id: 'vade_yaslandirma',
                        baslik: 'Vade Yaşlandırma',
                        ikon: Icons.timelapse_rounded,
                      ),
                    ],
                  ),
                  _menuGrubu(
                    id: 'raporlar',
                    baslik: 'Raporlar',
                    ikon: Icons.bar_chart_rounded,
                    altMenuler: const [
                      _AltMenuModel(
                        id: 'rapor_satis',
                        baslik: 'Satış',
                        ikon: Icons.trending_up_rounded,
                      ),
                      _AltMenuModel(
                        id: 'rapor_alis',
                        baslik: 'Alış',
                        ikon: Icons.trending_down_rounded,
                      ),
                      _AltMenuModel(
                        id: 'rapor_stok',
                        baslik: 'Stok',
                        ikon: Icons.inventory_rounded,
                      ),
                      _AltMenuModel(
                        id: 'rapor_cari',
                        baslik: 'Cari',
                        ikon: Icons.people_alt_rounded,
                      ),
                      _AltMenuModel(
                        id: 'rapor_kasa',
                        baslik: 'Kasa',
                        ikon: Icons.account_balance_wallet_rounded,
                      ),
                    ],
                  ),
                  _tekMenu(
                    id: 'sistem_saglik',
                    baslik: 'Sistem Sağlık Kontrolü',
                    ikon: Icons.health_and_safety_rounded,
                  ),
                  _tekMenu(
                    id: 'kullanici_yetki',
                    baslik: 'Kullanıcı / Yetki',
                    ikon: Icons.admin_panel_settings_rounded,
                  ),
                  _tekMenu(
                    id: 'ayarlar',
                    baslik: 'Ayarlar',
                    ikon: Icons.settings_rounded,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          _menuAltBilgi(),
        ],
      ),
    );
  }

  Widget _menuBaslik({bool mobil = false}) {
    return SizedBox(
      height: 72,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.storefront_rounded,
                color: const Color(0xFF90CAF9),
              ),
            ),
            if (!_menuDarEtkin) ...[
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ÜNAL YEDEK PARÇA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Kurumsal ERP',
                      style: TextStyle(color: Color(0xFFB9C8D8), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
            IconButton(
              tooltip: mobil
                  ? 'Menüyü kapat'
                  : (_menuDarEtkin ? 'Menüyü genişlet' : 'Menüyü daralt'),
              onPressed: () {
                if (mobil) {
                  Navigator.of(context).maybePop();
                  return;
                }
                setState(() {
                  _menuDar = !_menuDar;
                });
              },
              icon: Icon(
                mobil
                    ? Icons.close_rounded
                    : (_menuDarEtkin
                          ? Icons.chevron_right_rounded
                          : Icons.chevron_left_rounded),
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuAramaKutusu() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      child: TextField(
        controller: _menuAramaController,
                focusNode: _menuAramaFocusNode,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Menü ara...',
          hintStyle: const TextStyle(color: Color(0xFFB9C8D8)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.07),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFFB9C8D8),
          ),
          suffixIcon: _menuArama.isEmpty
              ? null
              : IconButton(
                  onPressed: _menuAramaController.clear,
                  icon: const Icon(
                    Icons.clear_rounded,
                    color: Color(0xFFB9C8D8),
                  ),
                ),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF64B5F6)),
          ),
        ),
      ),
    );
  }

  Widget _tekMenu({
    required String id,
    required String baslik,
    required IconData ikon,
  }) {
    if (_menuArama.isNotEmpty && !baslik.toLowerCase().contains(_menuArama)) {
      return const SizedBox.shrink();
    }

    final secili = _seciliSayfa == id;
    const renk = Color(0xFF64B5F6);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Tooltip(
        message: _menuDarEtkin ? baslik : '',
        child: Material(
          color: secili ? const Color(0xFF175D93) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _sayfaSec(id),
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  SizedBox(
                    width: _menuDarEtkin ? 58 : 50,
                    child: Icon(
                      ikon,
                      color: secili ? Colors.white : const Color(0xFFCFD8E3),
                    ),
                  ),
                  if (!_menuDarEtkin)
                    Expanded(
                      child: Text(
                        baslik,
                        style: TextStyle(
                          color: secili
                              ? Colors.white
                              : const Color(0xFFE8EEF5),
                          fontWeight: secili
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuGrubu({
    required String id,
    required String baslik,
    required IconData ikon,
    required List<_AltMenuModel> altMenuler,
  }) {
    if (!_aramaEslesiyor(baslik, altMenuler)) {
      return const SizedBox.shrink();
    }

    final aramaVar = _menuArama.isNotEmpty;
    final acik = aramaVar || _acikGruplar.contains(id);

    final gruptaSecili = altMenuler.any((item) => item.id == _seciliSayfa);

    const renk = Color(0xFF64B5F6);

    if (_menuDarEtkin) {
      return PopupMenuButton<String>(
        tooltip: baslik,
        position: PopupMenuPosition.under,
        onSelected: (sayfaId) {
          _sayfaSec(sayfaId, grupId: id);
        },
        itemBuilder: (context) {
          return altMenuler
              .where(
                (item) =>
                    _menuArama.isEmpty ||
                    item.baslik.toLowerCase().contains(_menuArama),
              )
              .map(
                (item) => PopupMenuItem<String>(
                  value: item.id,
                  child: Row(
                    children: [
                      Icon(item.ikon, size: 20),
                      const SizedBox(width: 10),
                      Text(item.baslik),
                    ],
                  ),
                ),
              )
              .toList();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: gruptaSecili
                  ? const Color(0xFF175D93)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              ikon,
              color: gruptaSecili ? Colors.white : const Color(0xFFCFD8E3),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Material(
            color: gruptaSecili ? const Color(0xFF143E63) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _grupDegistir(id),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(
                      ikon,
                      color: gruptaSecili
                          ? const Color(0xFF90CAF9)
                          : const Color(0xFFCFD8E3),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        baslik,
                        style: TextStyle(
                          color: gruptaSecili
                              ? Colors.white
                              : const Color(0xFFE8EEF5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      acik
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: const Color(0xFFB9C8D8),
                    ),
                    const SizedBox(width: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: acik
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: altMenuler
                .where(
                  (item) =>
                      _menuArama.isEmpty ||
                      item.baslik.toLowerCase().contains(_menuArama),
                )
                .map((item) => _altMenuSatiri(grupId: id, item: item))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _altMenuSatiri({required String grupId, required _AltMenuModel item}) {
    final secili = _seciliSayfa == item.id;
    const renk = Color(0xFF64B5F6);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 1, 8, 1),
      child: Material(
        color: secili ? const Color(0xFF175D93) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => _sayfaSec(item.id, grupId: grupId),
          child: SizedBox(
            height: 42,
            child: Row(
              children: [
                SizedBox(
                  width: 42,
                  child: Icon(
                    item.ikon,
                    size: 20,
                    color: secili ? Colors.white : const Color(0xFFB9C8D8),
                  ),
                ),
                Expanded(
                  child: Text(
                    item.baslik,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secili ? Colors.white : const Color(0xFFDCE6F0),
                      fontSize: 13,
                      fontWeight: secili ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
                if (secili)
                  Container(
                    width: 4,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFF90CAF9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuAltBilgi() {
    return SizedBox(
      height: 54,
      child: Row(
        mainAxisAlignment: _menuDarEtkin
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          const SizedBox(width: 16),
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF204B70),
            child: Icon(Icons.person_rounded, size: 18, color: Colors.white),
          ),
          if (!_menuDarEtkin) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    YetkiService.aktifKullanici,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    YetkiService.rol,
                    style: const TextStyle(
                      color: Color(0xFFB9C8D8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dashboardOzetleri() {
    final kartlar = <Widget>[
      _ozetKarti(
        baslik: 'Bugünkü Ciro',
        deger: '${bugunkuCiro.toStringAsFixed(2)} ₺',
        simge: Icons.payments,
        renk: Colors.green,
      ),
      _ozetKarti(
        baslik: 'Müşteri Alacakları',
        deger: '${toplamAlacak.toStringAsFixed(2)} ₺',
        simge: Icons.account_balance,
        renk: Colors.teal,
      ),
      _ozetKarti(
        baslik: 'Toplam Stok Çeşidi',
        deger: '$toplamStokCesidi Kalem',
        simge: Icons.inventory_2,
        renk: Colors.blue,
      ),
      InkWell(
        onTap: kritikStokSayisi > 0 ? _kritikStoklariGoster : null,
        borderRadius: BorderRadius.circular(12),
        child: _ozetKarti(
          baslik: 'Kritik Stok (Min.)',
          deger: '$kritikStokSayisi Parça',
          simge: Icons.warning_amber_rounded,
          renk: kritikStokSayisi > 0 ? Colors.red : Colors.orange,
        ),
      ),
      _ozetKarti(
        baslik: 'Bugünkü Satış Belgesi',
        deger: '$bugunkuSatisSayisi İşlem',
        simge: Icons.receipt_long_rounded,
        renk: Colors.indigo,
      ),
      InkWell(
        onTap: gecikenVadeSayisi > 0
            ? () => _sayfaSec('vade_takip', grupId: 'cari')
            : null,
        borderRadius: BorderRadius.circular(12),
        child: _ozetKarti(
          baslik: 'Geciken Vadeler',
          deger: '$gecikenVadeSayisi Kayıt',
          simge: Icons.event_busy_rounded,
          renk: gecikenVadeSayisi > 0 ? Colors.red : Colors.green,
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final tekSutun = constraints.maxWidth < 620;
        final ucSutun = constraints.maxWidth >= 1180;
        final kartGenisligi = tekSutun
            ? constraints.maxWidth
            : ucSutun
                ? (constraints.maxWidth - 20) / 3
                : (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: kartlar
              .map((kart) => SizedBox(width: kartGenisligi, child: kart))
              .toList(),
        );
      },
    );
  }

  String _dashboardTarih(dynamic value) {
    final dt = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (dt == null) return '-';
    String iki(int n) => n.toString().padLeft(2, '0');
    return '${iki(dt.day)}.${iki(dt.month)} ${iki(dt.hour)}:${iki(dt.minute)}';
  }

  Widget _dashboardHero() {
    return Container(
      padding: EdgeInsets.all(_mobilMod ? 14 : 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blueGrey.shade900,
            Colors.blue.shade800,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.dashboard_customize_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YÖNETİM MERKEZİ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Satış • Stok • Cari • Vade • Operasyon özeti',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (!_mobilMod)
            FilledButton.tonalIcon(
              onPressed: () => dashboardVerileriniYukle(zorla: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Verileri Yenile'),
            ),
        ],
      ),
    );
  }

  Widget _dashboardHizliErisim() {
    final List<Map<String, dynamic>> islemler = [
      {'baslik': 'Stok Kartları', 'sayfa': 'stok_kartlari', 'grup': 'stok', 'ikon': Icons.inventory_2_rounded, 'renk': Colors.blue},
      {'baslik': 'Satış Faturaları', 'sayfa': 'satis_faturalari', 'grup': 'satis', 'ikon': Icons.receipt_long_rounded, 'renk': Colors.indigo},
      {'baslik': 'Alış Faturaları', 'sayfa': 'alis_faturalari', 'grup': 'satin_alma', 'ikon': Icons.shopping_cart_checkout_rounded, 'renk': Colors.orange},
      {'baslik': 'Cari Kartları', 'sayfa': 'cari_kartlari', 'grup': 'cari', 'ikon': Icons.groups_rounded, 'renk': Colors.teal},
      {'baslik': 'Kasalar', 'sayfa': 'kasalar', 'grup': 'kasa', 'ikon': Icons.account_balance_wallet_rounded, 'renk': Colors.green},
      {'baslik': 'Araç Kataloğu', 'sayfa': 'arac_parca_katalog', 'grup': 'arac_parca_katalog', 'ikon': Icons.directions_car_filled_rounded, 'renk': Colors.deepPurple},
    ];

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.flash_on_rounded, size: 20),
                SizedBox(width: 7),
                Text(
                  'Hızlı İşlemler',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final genis = constraints.maxWidth >= 560;
                final w = genis
                    ? (constraints.maxWidth - 10) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: islemler.map((item) {
                    return SizedBox(
                      width: w,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _sayfaSec(item['sayfa'] as String, grupId: item['grup'] as String),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: (item['renk'] as Color).withOpacity(0.06),
                            border: Border.all(
                              color: (item['renk'] as Color).withOpacity(0.18),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(item['ikon'] as IconData, color: item['renk'] as Color, size: 22),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  item['baslik'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 19,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardSonSatislar() {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded, size: 20),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'Bugünün Son Satışları',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _sayfaSec(
                    'satis_faturalari',
                    grupId: 'satis',
                  ),
                  child: const Text('Tümünü Aç'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (sonSatislar.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text(
                    'Bugün henüz satış belgesi yok.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...sonSatislar.take(5).map((item) {
                final no = (item['fatura_no'] ??
                        item['belge_no'] ??
                        item['satis_id'] ??
                        '-')
                    .toString();
                final tutar = _sayi(
                  item['genel_toplam'] ?? item['toplam_tutar'],
                );

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE7E9EE)),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: Colors.green.withOpacity(0.10),
                        child: const Icon(
                          Icons.north_east_rounded,
                          color: Colors.green,
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              no,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _dashboardTarih(item['tarih']),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${tutar.toStringAsFixed(2)} ₺',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _dashboardOrtaBolum() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return Column(
            children: [
              _dashboardHizliErisim(),
              const SizedBox(height: 12),
              _dashboardSonSatislar(),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _dashboardHizliErisim()),
            const SizedBox(width: 12),
            Expanded(child: _dashboardSonSatislar()),
          ],
        );
      },
    );
  }

  Widget _buildAnaSayfaIcerik() {
    return Column(
      children: [
        if (!_mobilMod)
          AppBar(
            title: const Text('ÜNAL YEDEK PARÇA ERP'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => dashboardVerileriniYukle(zorla: true),
                tooltip: 'Yenile',
              ),
            ],
          ),
        Expanded(
          child: yukleniyor
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => dashboardVerileriniYukle(zorla: true),
                  child: ListView(
                    padding: EdgeInsets.all(_mobilMod ? 10 : 16),
                    children: [
                      _dashboardHero(),
                      const SizedBox(height: 14),
                      _dashboardOzetleri(),
                      if (gecikenVadeSayisi > 0) ...[
                        const SizedBox(height: 10),
                        Card(
                          color: Colors.red.withOpacity(0.06),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFFFE2E2),
                              child: Icon(
                                Icons.event_busy_rounded,
                                color: Colors.red,
                              ),
                            ),
                            title: Text(
                              '$gecikenVadeSayisi gecikmiş vade kaydı var',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            subtitle: const Text(
                              'Vade Takibi ekranından tahsilat veya ödeme kaydedin.',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () =>
                                _sayfaSec('vade_takip', grupId: 'cari'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _dashboardOrtaBolum(),
                      const SizedBox(height: 24),
                      const Text(
                        '📈 Son 6 Ay Gerçekleşen Brüt Kâr',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(_mobilMod ? 10 : 20),
                          child: SizedBox(
                            height: 220,
                            child: LineChart(
                              LineChartData(
                                minX: 0,
                                maxX: 5,
                                gridData: const FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                ),
                                titlesData: FlTitlesData(
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                      interval: 1,
                                      getTitlesWidget: (value, meta) {
                                        final index = value.toInt();
                                        if (index < 0 ||
                                            index >=
                                                aylikKarEtiketleri.length ||
                                            value != index.toDouble()) {
                                          return const SizedBox.shrink();
                                        }

                                        return Text(
                                          aylikKarEtiketleri[index],
                                          style: const TextStyle(fontSize: 11),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    isCurved: true,
                                    color: Colors.green,
                                    barWidth: 3,
                                    spots: List<FlSpot>.generate(
                                      aylikKarlar.length,
                                      (index) => FlSpot(
                                        index.toDouble(),
                                        aylikKarlar[index],
                                      ),
                                    ),
                                    dotData: const FlDotData(show: true),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: Colors.green.withOpacity(0.08),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _ozetKarti({
    required String baslik,
    required String deger,
    required IconData simge,
    required Color renk,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: renk.withOpacity(0.2),
              child: Icon(simge, color: renk),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    baslik,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    deger,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _kritikStoklariGoster() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Kritik Stoktaki Ürünler'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: kritikStoklar.length,
              itemBuilder: (context, index) {
                final urun = kritikStoklar[index];

                return ListTile(
                  title: Text(
                    urun.urunAdi.isEmpty ? 'İsimsiz Ürün' : urun.urunAdi,
                  ),
                  subtitle: Text(
                    'ÜRETİCİ KODU: ${urun.ureticiKodu.isEmpty ? '-' : urun.ureticiKodu}',
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  trailing: Text(
                    'Adet: ${urun.stokMiktari.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  Widget _sayfaYigini() {
    return ClipRect(
      child: IndexedStack(
        index: _acikSayfalar.indexOf(_seciliSayfa),
        children: _acikSayfalar
            .map(
              (sayfaId) => KeyedSubtree(
                key: ValueKey<String>(sayfaId),
                child: _sayfaGetir(sayfaId),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () { _menuAramaFocusNode.requestFocus(); },
        const SingleActivator(LogicalKeyboardKey.escape): () { if (_seciliSayfa != 'dashboard') { setState(() => _seciliSayfa = 'dashboard'); } else { Navigator.of(context).maybePop(); } },
      },
      child: Focus(autofocus: true, child: LayoutBuilder(
      builder: (context, constraints) {
        final mobil = constraints.maxWidth < 900;
        _mobilMod = mobil;

        if (mobil) {
          return Scaffold(
            appBar: AppBar(
              toolbarHeight: 54,
              title: Text(
                _sayfaBasligi(_seciliSayfa),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  tooltip: 'Hesap Makinesi',
                  onPressed: () => HesapMakinesiSayfasi.dialogAc(context),
                  icon: const Icon(Icons.calculate_rounded),
                ),
                if (_seciliSayfa == 'dashboard')
                  IconButton(
                    tooltip: 'Yenile',
                    onPressed: () => dashboardVerileriniYukle(zorla: true),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
              ],
            ),
            drawer: Drawer(child: SafeArea(child: _solMenu(mobil: true))),
            body: SafeArea(top: false, child: _sayfaYigini()),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                _solMenu(),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Column(
                    children: [
                      _acikSayfaSekmeleri(),
                      Expanded(child: _sayfaYigini()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      )),
    );
  }
}

class _AltMenuModel {
  final String id;
  final String baslik;
  final IconData ikon;

  const _AltMenuModel({
    required this.id,
    required this.baslik,
    required this.ikon,
  });
}

class _HazirlaniyorSayfasi extends StatelessWidget {
  final String baslik;
  final String aciklama;
  final IconData ikon;

  const _HazirlaniyorSayfasi({
    required this.baslik,
    required this.aciklama,
    required this.ikon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          baslik.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ikon,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  baslik,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  aciklama,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
