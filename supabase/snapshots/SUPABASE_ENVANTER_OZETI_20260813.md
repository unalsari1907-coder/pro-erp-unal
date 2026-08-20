# PRO-ERP Supabase Database Object Snapshot

Objects: 82
Columns: 886
Functions: 122
Views: 8
Constraints: 213
Indexes: 215
Triggers: 34
RLS policies: 45
Foreign keys: 73

## Triggers
- `alis_baslik.trg_alis_vade_ata` — `CREATE TRIGGER trg_alis_vade_ata BEFORE INSERT OR UPDATE OF cari_id, tarih ON alis_baslik FOR EACH ROW EXECUTE FUNCTION erp_fatura_vade_ata()`
- `alis_baslik.trg_erp_audit_alis_baslik` — `CREATE TRIGGER trg_erp_audit_alis_baslik AFTER INSERT OR DELETE OR UPDATE ON alis_baslik FOR EACH ROW EXECUTE FUNCTION erp_audit_trigger()`
- `alis_detay.trg_erp_audit_alis_detay` — `CREATE TRIGGER trg_erp_audit_alis_detay AFTER INSERT OR DELETE OR UPDATE ON alis_detay FOR EACH ROW EXECUTE FUNCTION erp_audit_trigger()`
- `alis_irsaliye_baslik.trg_alis_irsaliye_baslik_guncelleme` — `CREATE TRIGGER trg_alis_irsaliye_baslik_guncelleme BEFORE UPDATE ON alis_irsaliye_baslik FOR EACH ROW EXECUTE FUNCTION irsaliye_guncelleme_tarihi()`
- `alis_irsaliye_detay.trg_alis_irsaliye_detay_guncelleme` — `CREATE TRIGGER trg_alis_irsaliye_detay_guncelleme BEFORE UPDATE ON alis_irsaliye_detay FOR EACH ROW EXECUTE FUNCTION irsaliye_guncelleme_tarihi()`
- `alis_siparis_baslik.trg_alis_siparis_baslik_guncelleme` — `CREATE TRIGGER trg_alis_siparis_baslik_guncelleme BEFORE UPDATE ON alis_siparis_baslik FOR EACH ROW EXECUTE FUNCTION alis_siparis_guncelleme_tarihi()`
- `alis_siparis_detay.trg_alis_siparis_detay_guncelleme` — `CREATE TRIGGER trg_alis_siparis_detay_guncelleme BEFORE UPDATE ON alis_siparis_detay FOR EACH ROW EXECUTE FUNCTION alis_siparis_guncelleme_tarihi()`
- `cari_hareket.trg_erp_audit_cari_hareket` — `CREATE TRIGGER trg_erp_audit_cari_hareket AFTER INSERT OR DELETE OR UPDATE ON cari_hareket FOR EACH ROW EXECUTE FUNCTION erp_audit_trigger()`
- `cariler.trg_erp_audit_cariler` — `CREATE TRIGGER trg_erp_audit_cariler AFTER INSERT OR DELETE OR UPDATE ON cariler FOR EACH ROW EXECUTE FUNCTION erp_audit_trigger()`
- `depo_hareketleri.trg_pro_transfer_stok_hareketleri` — `CREATE TRIGGER trg_pro_transfer_stok_hareketleri AFTER INSERT ON depo_hareketleri FOR EACH ROW EXECUTE FUNCTION pro_transfer_stok_hareketleri()`
- `erp_kullanicilar.trg_erp_kullanici_updated_at` — `CREATE TRIGGER trg_erp_kullanici_updated_at BEFORE UPDATE ON erp_kullanicilar FOR EACH ROW EXECUTE FUNCTION erp_kullanici_updated_at()`
- `erp_muhasebe_fis_satirlari.trg_erp_muhasebe_fis_toplam` — `CREATE TRIGGER trg_erp_muhasebe_fis_toplam AFTER INSERT OR DELETE OR UPDATE ON erp_muhasebe_fis_satirlari FOR EACH ROW EXECUTE FUNCTION erp_muhasebe_fis_toplam_guncelle()`
- `kasa_hareket.trg_erp_audit_kasa_hareket` — `CREATE TRIGGER trg_erp_audit_kasa_hareket AFTER INSERT OR DELETE OR UPDATE ON kasa_hareket FOR EACH ROW EXECUTE FUNCTION erp_audit_trigger()`
- `satis_baslik.trg_erp_audit_satis_baslik` — `CREATE TRIGGER trg_erp_audit_satis_baslik AFTER INSERT OR DELETE OR UPDATE ON satis_baslik FOR EACH ROW EXECUTE FUNCTION erp_audit_trigger()`
- `satis_baslik.trg_satis_baslik_irsaliye_no` — `CREATE TRIGGER trg_satis_baslik_irsaliye_no BEFORE INSERT OR UPDATE OF irsaliye_id ON satis_baslik FOR EACH ROW EXECUTE FUNCTION satis_baslik_irsaliye_no_doldur()`
- `satis_baslik.trg_satis_fatura_no_otomatik` — `CREATE TRIGGER trg_satis_fatura_no_otomatik BEFORE INSERT ON satis_baslik FOR EACH ROW EXECUTE FUNCTION satis_fatura_no_otomatik()`
- `satis_baslik.trg_satis_vade_ata` — `CREATE TRIGGER trg_satis_vade_ata BEFORE INSERT OR UPDATE OF cari_id, tarih ON satis_baslik FOR EACH ROW EXECUTE FUNCTION erp_fatura_vade_ata()`
- `satis_detay.trg_erp_audit_satis_detay` — `CREATE TRIGGER trg_erp_audit_satis_detay AFTER INSERT OR DELETE OR UPDATE ON satis_detay FOR EACH ROW EXECUTE FUNCTION erp_audit_trigger()`
- `satis_irsaliye_baslik.trg_satis_irsaliye_baslik_guncelleme` — `CREATE TRIGGER trg_satis_irsaliye_baslik_guncelleme BEFORE UPDATE ON satis_irsaliye_baslik FOR EACH ROW EXECUTE FUNCTION irsaliye_guncelleme_tarihi()`
- `satis_irsaliye_detay.trg_satis_irsaliye_detay_guncelleme` — `CREATE TRIGGER trg_satis_irsaliye_detay_guncelleme BEFORE UPDATE ON satis_irsaliye_detay FOR EACH ROW EXECUTE FUNCTION irsaliye_guncelleme_tarihi()`
- `satis_siparis_baslik.trg_satis_siparis_baslik_guncelleme` — `CREATE TRIGGER trg_satis_siparis_baslik_guncelleme BEFORE UPDATE ON satis_siparis_baslik FOR EACH ROW EXECUTE FUNCTION satis_siparis_guncelleme_tarihi()`
- `satis_siparis_detay.trg_satis_siparis_detay_guncelleme` — `CREATE TRIGGER trg_satis_siparis_detay_guncelleme BEFORE UPDATE ON satis_siparis_detay FOR EACH ROW EXECUTE FUNCTION satis_siparis_guncelleme_tarihi()`
- `satislar.cari_bakiye_satis_trigger` — `CREATE TRIGGER cari_bakiye_satis_trigger AFTER INSERT ON satislar FOR EACH ROW EXECUTE FUNCTION cari_bakiye_satis()`
- `satislar.stok_azalt_trigger` — `CREATE TRIGGER stok_azalt_trigger AFTER INSERT ON satislar FOR EACH ROW EXECUTE FUNCTION stok_azalt()`
- `satislar.trg_satis_hesapla` — `CREATE TRIGGER trg_satis_hesapla BEFORE INSERT OR UPDATE ON satislar FOR EACH ROW EXECUTE FUNCTION satis_hesapla()`
- `satislar.trg_stok_satis_adedi` — `CREATE TRIGGER trg_stok_satis_adedi AFTER INSERT ON satislar FOR EACH ROW EXECUTE FUNCTION stok_satis_adedi_artir()`
- `stok_hareket.trg_check_cari_risk_limiti` — `CREATE TRIGGER trg_check_cari_risk_limiti BEFORE INSERT ON stok_hareket FOR EACH ROW EXECUTE FUNCTION check_cari_risk_limiti()`
- `stok_hareket.trg_erp_audit_stok_hareket` — `CREATE TRIGGER trg_erp_audit_stok_hareket AFTER INSERT OR DELETE OR UPDATE ON stok_hareket FOR EACH ROW EXECUTE FUNCTION erp_audit_trigger()`
- `stok_hareket.trg_pro_konsinye_stok_hareket` — `CREATE TRIGGER trg_pro_konsinye_stok_hareket BEFORE INSERT ON stok_hareket FOR EACH ROW EXECUTE FUNCTION pro_konsinye_stok_hareket_tipi()`
- `stok_hareket.trg_update_cari_bakiye` — `CREATE TRIGGER trg_update_cari_bakiye AFTER INSERT ON stok_hareket FOR EACH ROW EXECUTE FUNCTION update_cari_bakiye()`
- `stoklar.trg_erp_audit_stoklar` — `CREATE TRIGGER trg_erp_audit_stoklar AFTER INSERT OR DELETE OR UPDATE ON stoklar FOR EACH ROW EXECUTE FUNCTION erp_audit_trigger()`
- `stoklar.trg_stok_arama` — `CREATE TRIGGER trg_stok_arama BEFORE INSERT OR UPDATE ON stoklar FOR EACH ROW EXECUTE FUNCTION stok_arama_metni()`
- `stoklar.trg_stok_fiyatlarini_hesapla` — `CREATE TRIGGER trg_stok_fiyatlarini_hesapla BEFORE INSERT OR UPDATE OF alis_fiyati, kdv, kar_orani_perakende, kar_orani_toptan, kar_orani_liste, kar_orani_indirimli ON stoklar FOR EACH ROW EXECUTE FUNCTION stok_fiyatlarini_hesapla()`
- `stoklar.trg_stok_vector` — `CREATE TRIGGER trg_stok_vector BEFORE INSERT OR UPDATE ON stoklar FOR EACH ROW EXECUTE FUNCTION stoklar_vector_guncelle()`

## RLS Policies
- `alis_baslik` / `erp_authenticated_all` / `ALL` / roles=['authenticated']
- `alis_detay` / `erp_authenticated_all` / `ALL` / roles=['authenticated']
- `alis_irsaliye_baslik` / `erp_authenticated_all` / `ALL` / roles=['authenticated']
- `alis_irsaliye_detay` / `erp_authenticated_all` / `ALL` / roles=['authenticated']
- `cari_hareket` / `erp_authenticated_all` / `ALL` / roles=['authenticated']
- `cariler` / `erp_authenticated_all` / `ALL` / roles=['authenticated']
- `depolar` / `erp_authenticated_all` / `ALL` / roles=['authenticated']
- `erp_arac_katalog_araclar` / `pro_erp_gecis_erp_arac_katalog_araclar` / `ALL` / roles=['anon', 'authenticated']
- `erp_arac_katalog_parcalar` / `pro_erp_gecis_erp_arac_katalog_parcalar` / `ALL` / roles=['anon', 'authenticated']
- `erp_arac_uyumluluk` / `pro_erp_auth_erp_arac_uyumluluk` / `ALL` / roles=['authenticated']
- `erp_belge_baglantilari` / `pro_erp_gecis_erp_belge_baglantilari` / `ALL` / roles=['anon', 'authenticated']
- `erp_cek_senet` / `pro_erp_auth_erp_cek_senet` / `ALL` / roles=['authenticated']
- `erp_doviz_kurlari` / `pro_erp_auth_erp_doviz_kurlari` / `ALL` / roles=['authenticated']
- `erp_e_belgeler` / `pro_erp_auth_erp_e_belgeler` / `ALL` / roles=['authenticated']
- `erp_firma_ayarlari` / `erp_firma_ayar_oku` / `SELECT` / roles=['anon', 'authenticated']
- `erp_firma_ayarlari` / `erp_firma_ayar_yaz` / `ALL` / roles=['anon', 'authenticated']
- `erp_fiyat_kurallari` / `pro_erp_auth_erp_fiyat_kurallari` / `ALL` / roles=['authenticated']
- `erp_hesap_plani` / `pro_erp_auth_erp_hesap_plani` / `ALL` / roles=['authenticated']
- `erp_kasa_gun_sonu` / `erp_gun_sonu_oku` / `SELECT` / roles=['anon', 'authenticated']
- `erp_kasa_gun_sonu` / `erp_gun_sonu_yaz` / `ALL` / roles=['anon', 'authenticated']
- `erp_kullanicilar` / `erp_authenticated_all` / `ALL` / roles=['authenticated']
- `erp_kur_farki_fisleri` / `pro_erp_gecis_erp_kur_farki_fisleri` / `ALL` / roles=['anon', 'authenticated']
- `erp_muhasebe_fis_satirlari` / `pro_erp_auth_erp_muhasebe_fis_satirlari` / `ALL` / roles=['authenticated']
- `erp_muhasebe_fisleri` / `pro_erp_auth_erp_muhasebe_fisleri` / `ALL` / roles=['authenticated']
- `erp_onaylar` / `pro_erp_auth_erp_onaylar` / `ALL` / roles=['authenticated']
- `erp_satin_alma_talep_detay` / `pro_erp_auth_erp_satin_alma_talep_detay` / `ALL` / roles=['authenticated']
- `erp_satin_alma_talepleri` / `pro_erp_auth_erp_satin_alma_talepleri` / `ALL` / roles=['authenticated']
- `erp_seri_lot` / `pro_erp_auth_erp_seri_lot` / `ALL` / roles=['authenticated']
- `erp_sistem_ayarlari` / `erp_sistem_ayar_oku` / `SELECT` / roles=['anon', 'authenticated']
- `erp_sistem_ayarlari` / `erp_sistem_ayar_yaz` / `ALL` / roles=['authenticated']
- `erp_sistem_kontrol_log` / `pro_erp_gecis_erp_sistem_kontrol_log` / `ALL` / roles=['anon', 'authenticated']
- `erp_teklif_detay` / `pro_erp_auth_erp_teklif_detay` / `ALL` / roles=['authenticated']
- `erp_teklifler` / `pro_erp_auth_erp_teklifler` / `ALL` / roles=['authenticated']
- `kasa_hareket` / `erp_authenticated_all` / `ALL` / roles=['authenticated']
- `kasalar` / `erp_authenticated_all` / `ALL` / roles=['authenticated']
- `satis_baslik` / `erp_authenticated_all` / `ALL` / roles=['authenticated']
- `satis_detay` / `erp_authenticated_all` / `ALL` / roles=['authenticated']
- `satis_irsaliye_baslik` / `erp_authenticated_all` / `ALL` / roles=['authenticated']
- `satis_irsaliye_detay` / `erp_authenticated_all` / `ALL` / roles=['authenticated']
- `stok_cross` / `erp_authenticated_all` / `ALL` / roles=['authenticated']
- `stok_hareket` / `erp_authenticated_all` / `ALL` / roles=['authenticated']
- `stok_oem` / `erp_authenticated_all` / `ALL` / roles=['authenticated']
- `stok_rakip` / `erp_authenticated_all` / `ALL` / roles=['authenticated']
- `stok_resim` / `erp_authenticated_all` / `ALL` / roles=['authenticated']
- `stoklar` / `erp_authenticated_all` / `ALL` / roles=['authenticated']