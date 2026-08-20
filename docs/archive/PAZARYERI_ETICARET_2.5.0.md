# PRO-ERP 2.5.0 — Pazaryeri / E-Ticaret Merkezi

Hazır altyapı: Trendyol, Hepsiburada, n11, Amazon Türkiye ve kendi web sitesi.
PRO-ERP ana stok/fiyat kaynağıdır. Mağaza API bilgileri girilmeden hiçbir dış servise veri gönderilmez.

## Kurulum
Supabase SQL Editor'da `supabase/migrations/20260813_pazaryeri_eticaret_merkezi.sql` dosyasını bir kez çalıştırın.
Sonra Flutter uygulamasını normal şekilde çalıştırın.

## Hazır ekranlar
Genel Bakış; Sipariş Merkezi; Ürün/Stok/Fiyat; İade/Kargo; Mağazalar/API.
Veritabanında kanal, ürün eşleştirme, sipariş, sipariş detay, iade ve senkron log tabloları hazırdır.

## Canlı bağlantı
API anahtarları kaynak koda yazılmamalıdır. Satış başladığında Supabase Edge Function/Secrets üzerinden kanal adaptörleri aktive edilmelidir.
