# PRO-ERP'yi Telefonda Kullanma

## Yerel ağda son test
1. Bilgisayar ve telefon aynı Wi-Fi'da olsun.
2. `TELEFONDA_TEST_ET.bat` dosyasını çift tıklayın.
3. Ekranda çıkan IPv4 adresini telefonda `http://IP:8080` şeklinde açın.
4. Bu test release modundadır.

## İnternetten her yerden kullanım
1. `MOBIL_RELEASE_HAZIRLA.bat` çalıştırın.
2. İşlem sonunda `build\\web` klasörü oluşur.
3. Bu klasörü mevcut Cloudflare yayınınıza / Pages projenize yükleyin.
4. Telefon Chrome/Safari'de alan adını açın.
5. Tarayıcı menüsünden `Ana ekrana ekle` seçeneğini kullanın.

Telefon ve bilgisayar aynı Supabase projesini kullanır. Ayrı veri aktarımı yapılmaz.
