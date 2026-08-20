import 'package:flutter_test/flutter_test.dart';
import 'package:pro_erp/app_config.dart';
import 'package:pro_erp/screens/kurumsal_moduller_sayfasi.dart';
import 'package:pro_erp/services/erp_hesaplama_service.dart';

void main() {
  test('PRO ERP sürüm bilgisi tanımlı', () {
    expect(AppConfig.appName, 'ÜNAL YEDEK PARÇA ERP');
    expect(AppConfig.version, '2.5.11');
  });

  test('Aktif kurumsal ERP modülleri tanımlı', () {
    expect(KurumsalModuller.teklif.tablo, 'erp_teklifler');
    expect(KurumsalModuller.cekSenet.tablo, 'erp_cek_senet');
    expect(KurumsalModuller.eBelge.tablo, 'erp_e_belgeler');
    expect(KurumsalModuller.seriLot.tablo, 'erp_seri_lot');
  });

  test('Kur farkı ve vade yaşlandırma mantığı doğru', () {
    expect(
      ErpHesaplamaService.kurFarki(
        dovizTutar: 1000,
        eskiKur: 40,
        yeniKur: 42,
      ),
      2000,
    );
    expect(ErpHesaplamaService.vadeGrubu(15), '1-30 Gün');
    expect(ErpHesaplamaService.vadeGrubu(95), '90+ Gün');
  });
}
