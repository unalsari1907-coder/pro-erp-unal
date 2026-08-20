import 'package:flutter/material.dart';
import 'kimlik_dogrulama_service.dart';
import 'supabase_service.dart';

class YetkiService {
  YetkiService._();

  static String aktifKullanici = 'UNAL';

  static String _rol = 'YONETICI';
  static bool _aktif = true;
  static Map<String, dynamic> _ozelYetkiler = {};

  static String get rol => _rol;
  static bool get aktif => _aktif;

  static const Map<String, Set<String>> _rolYetkileri = {
    'YONETICI': {'*'},
    'SATIS': {
      'dashboard',
      'belge_gecmisi',
      'arac_parca_katalog',
      'yonetici_kokpiti',
      'hesap_makinesi',
      'operasyon_merkezi',
      'teklif_proforma',
      'kampanya_fiyat',
      'stok_kartlari',
      'stok_hareketleri',
      'satis_faturalari',
      'satis_siparisleri',
      'satis_irsaliyeleri',
      'satis_iadeleri',
      'cari_kartlari',
      'cari_hareketleri',
      'vade_takip',
      'kasalar',
      'transfer_virman',
      'kasa_hareketleri',
      'kasa_gun_sonu',
      'pos',
      'makbuzlar',
      'rapor_satis',
      'rapor_stok',
      'rapor_cari',
      'pdf',
    },
    'SATIN_ALMA': {
      'dashboard',
      'belge_gecmisi',
      'arac_parca_katalog',
      'yonetici_kokpiti',
      'hesap_makinesi',
      'operasyon_merkezi',
      'satin_alma_talepleri',
      'kritik_stok_siparis_oneri',
      'onay_merkezi',
      'seri_lot',
      'stok_kartlari',
      'stok_hareketleri',
      'depolar',
      'sayim',
      'depo_transfer',
      'alis_faturalari',
      'alis_siparisleri',
      'alis_irsaliyeleri',
      'alis_iadeleri',
      'cari_kartlari',
      'cari_hareketleri',
      'vade_takip',
      'kasalar',
      'transfer_virman',
      'kasa_hareketleri',
      'kasa_gun_sonu',
      'rapor_alis',
      'rapor_stok',
      'rapor_cari',
      'pdf',
    },
    'MUHASEBE': {
      'dashboard',
      'belge_gecmisi',
      'sistem_saglik',
      'kur_farki',
      'vade_yaslandirma',
      'muhasebe_raporlari',
      'yonetici_kokpiti',
      'hesap_makinesi',
      'operasyon_merkezi',
      'hesap_plani',
      'muhasebe_fisleri',
      'cek_senet',
      'doviz_kur',
      'e_belge',
      'onay_merkezi',
      'cari_kartlari',
      'cari_hareketleri',
      'vade_takip',
      'kasalar',
      'transfer_virman',
      'kasa_hareketleri',
      'kasa_gun_sonu',
      'bankalar',
      'pos',
      'makbuzlar',
      'gider_masraf',
      'rapor_satis',
      'rapor_alis',
      'rapor_stok',
      'rapor_cari',
      'rapor_kasa',
      'rapor_grafikler',
      'pdf',
      'excel',
    },
    'DEPO': {
      'dashboard',
      'belge_gecmisi',
      'arac_parca_katalog',
      'hesap_makinesi',
      'operasyon_merkezi',
      'seri_lot',
      'stok_kartlari',
      'stok_hareketleri',
      'depolar',
      'sayim',
      'depo_transfer',
      'satis_irsaliyeleri',
      'alis_irsaliyeleri',
    },
  };

  static Future<void> yukle({
    bool zorla = false,
  }) async {
    final guvenliGiris =
        await KimlikDogrulamaService.guvenliGirisAktifMi();
    final authUser = SupabaseService.supabase.auth.currentUser;

    if (guvenliGiris && authUser == null) {
      _rol = 'YETKISIZ';
      _aktif = false;
      _ozelYetkiler = {};
      return;
    }

    try {
      Map<String, dynamic>? sonuc;
      if (authUser != null) {
        sonuc = await SupabaseService.supabase
            .from('erp_kullanicilar')
            .select('kullanici, rol, aktif, yetkiler, auth_user_id, eposta')
            .eq('auth_user_id', authUser.id)
            .maybeSingle();

        if (sonuc == null && authUser.email != null) {
          sonuc = await SupabaseService.supabase
              .from('erp_kullanicilar')
              .select('kullanici, rol, aktif, yetkiler, auth_user_id, eposta')
              .eq('eposta', authUser.email!)
              .maybeSingle();
        }
      } else {
        sonuc = await SupabaseService.supabase
            .from('erp_kullanicilar')
            .select('kullanici, rol, aktif, yetkiler')
            .eq('kullanici', aktifKullanici)
            .maybeSingle();
      }

      if (sonuc == null) {
        _rol = guvenliGiris ? 'YETKISIZ' : 'YONETICI';
        _aktif = !guvenliGiris;
        _ozelYetkiler = {};
        return;
      }

      aktifKullanici =
          (sonuc['kullanici']?.toString().trim().isNotEmpty ?? false)
              ? sonuc['kullanici'].toString().trim()
              : (authUser?.email ?? 'KULLANICI');

      _rol = (sonuc['rol']?.toString() ?? 'SATIS')
          .trim()
          .toUpperCase();

      _aktif = sonuc['aktif'] == true ||
          sonuc['aktif']?.toString().toLowerCase() == 'true';

      final raw = sonuc['yetkiler'];

      if (raw is Map) {
        _ozelYetkiler =
            Map<String, dynamic>.from(raw);
      } else {
        _ozelYetkiler = {};
      }
    } catch (_) {
      // Güvenli giriş açıldıysa bağlantı/yetki hatasında erişim kapalı kalır.
      // Henüz kurulum yapılmadıysa eski sistemi kilitlememek için yönetici kalır.
      _rol = guvenliGiris ? 'YETKISIZ' : 'YONETICI';
      _aktif = !guvenliGiris;
      _ozelYetkiler = {};
    }
  }

  static Future<bool> yetkiliMi(
    String yetki,
  ) async {
    if (!_aktif) return false;

    final anahtar =
        yetki.trim().toLowerCase();

    final ozel = _ozelYetkiler[anahtar];

    if (ozel is bool) {
      return ozel;
    }

    if (ozel != null) {
      final metin =
          ozel.toString().toLowerCase();

      if (metin == 'true' ||
          metin == '1' ||
          metin == 'evet') {
        return true;
      }

      if (metin == 'false' ||
          metin == '0' ||
          metin == 'hayir' ||
          metin == 'hayır') {
        return false;
      }
    }

    final rolYetkileri =
        _rolYetkileri[_rol] ??
            const <String>{};

    return rolYetkileri.contains('*') ||
        rolYetkileri.contains(anahtar);
  }

  static Future<bool> kontrolEt(
    BuildContext context,
    String yetki,
  ) async {
    final izin = await yetkiliMi(yetki);

    if (izin) return true;

    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Bu işlem için yetkiniz yok. '
            'Kullanıcı: $aktifKullanici • Rol: $_rol',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }

    return false;
  }

  static Future<void> kullaniciDegistir(
    String kullanici,
  ) async {
    aktifKullanici =
        kullanici.trim().isEmpty
            ? 'UNAL'
            : kullanici.trim();

    await yukle(zorla: true);
  }
}
