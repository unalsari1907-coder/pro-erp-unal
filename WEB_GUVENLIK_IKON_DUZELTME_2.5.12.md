# PRO ERP 2.5.12 Web Güvenlik ve Görünüm Düzeltmesi

## Neden bazı ikonlar ve düğmeler görünmedi?

- Önceki web derlemesinde `MaterialIcons` yazı tipi ağaç budama ile küçültülmüştü.
- Tarayıcıda eski JavaScript veya eski ikon yazı tipi önbellekte kalınca, yeni kodun istediği bazı ikon karakterleri bulunamadı.
- `CupertinoIcons` paketi derlemeye dahil değildi; derleme kaydı da bu eksikliği bildiriyordu.
- Sol menünün alt kısmı kısa ekranlarda sabit kullanıcı çubuğunun arkasında kalabiliyordu.
- Üst araç çubuğundaki metin düğmeleri arka planla yeterince ayrışmıyordu.

## Yapılan düzeltmeler

- `cupertino_icons` bağımlılığı eklendi.
- Web derlemesi `--no-tree-shake-icons` ile tam ikon yazı tiplerini paketliyor.
- Sol menü görünür kaydırma çubuğu ve alt boşlukla güncellendi.
- Araç kataloğundaki Yeni Araç ve Excel/CSV İçe Aktar düğmeleri belirgin düğmelere çevrildi.
- GitHub Pages başlangıç ve ana uygulama dosyalarına 2.5.12 önbellek kimliği eklendi.
- Uygulama her yeni sayfa açılışında e-posta/şifre doğrulaması istiyor; eski Supabase oturumu tek başına ekranı açmıyor.
- Güvenli giriş ayarı kapatılamaz hâle getirildi ve ayar okunamazsa güvenli varsayılan kullanılıyor.

## Doğrulama

- `flutter analyze --no-fatal-warnings --no-fatal-infos` tamamlandı.
- GitHub Pages taban yolu ile release web derlemesi başarıyla oluşturuldu.
- Sürüm: `2.5.12+2026081401`
