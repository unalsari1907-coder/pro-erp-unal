# PRO-ERP 2.5.10

Mobil derleme düzeltmesi.

- `vade_yaslandirma_sayfasi.dart` içindeki `width<720?.78:.7` ifadesi `width < 720 ? 0.78 : 0.7` olarak düzeltildi.
- Benzer ternary decimal yazımları güvenli olması için başına `0` eklenerek normalize edildi.
- Bu değişiklik Supabase SQL gerektirmez.
