import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'data/sepet_data.dart';
import 'screens/satis_sayfasi.dart';
import 'screens/cariler_sayfasi.dart';
import 'screens/ayarlar_sayfasi.dart';
import 'screens/dashboard_sayfasi.dart';
import 'screens/giris_sayfasi.dart';
import 'services/supabase_service.dart';
import 'services/yetki_service.dart';
import 'services/erp_error_logger.dart';
import 'models/stok_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase Canlı Bağlantısı
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErpErrorLogger.kaydet(details.exception, details.stack, kaynak: 'FLUTTER');
  };

  runZonedGuarded(
    () => runApp(const ProERPApp()),
    (error, stack) => ErpErrorLogger.kaydet(error, stack, kaynak: 'ZONE'),
  );
}

// Global Supabase İstemcisi
final supabase = Supabase.instance.client;

class ProERPApp extends StatelessWidget {
  const ProERPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      builder: (context, child) {
        final ekran = MediaQuery.of(context);
        final mobil = ekran.size.width < 720;

        // Küçük ekranlarda yazı ve kontrol yoğunluğunu hafifçe azalt.
        // Masaüstünde mevcut görünüm aynen korunur.
        return MediaQuery(
          data: ekran.copyWith(
            textScaler: TextScaler.linear(mobil ? 0.92 : 1.0),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              visualDensity:
                  mobil ? VisualDensity.compact : VisualDensity.standard,
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      // İlk açılış ekranı Dashboard (Ana Sayfa) olarak ayarlandı
      home: const KimlikDogrulamaKapisi(),
    );
  }
}

class KimlikDogrulamaKapisi extends StatefulWidget {
  const KimlikDogrulamaKapisi({super.key});

  @override
  State<KimlikDogrulamaKapisi> createState() => _KimlikDogrulamaKapisiState();
}

class _KimlikDogrulamaKapisiState extends State<KimlikDogrulamaKapisi> {
  StreamSubscription<AuthState>? _abonelik;
  bool _yukleniyor = true;
  bool _buAcilistaDogrulandi = false;

  @override
  void initState() {
    super.initState();
    _abonelik = supabase.auth.onAuthStateChange.listen((durum) {
      if (durum.event == AuthChangeEvent.signedOut) {
        _buAcilistaDogrulandi = false;
      }
      _yenile();
    });
    _yenile();
  }

  @override
  void dispose() {
    _abonelik?.cancel();
    super.dispose();
  }

  Future<void> _yenile() async {
    if (_buAcilistaDogrulandi && supabase.auth.currentSession != null) {
      await YetkiService.yukle(zorla: true);
    }
    if (!mounted) return;
    setState(() {
      _yukleniyor = false;
    });
  }

  Future<void> _girisBasarili() async {
    if (supabase.auth.currentSession == null) return;
    _buAcilistaDogrulandi = true;
    await _yenile();
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_buAcilistaDogrulandi || supabase.auth.currentSession == null) {
      return GirisSayfasi(onGiris: _girisBasarili);
    }
    return const DashboardSayfasi();
  }
}

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  int seciliIndex = 0;
  final TextEditingController aramaController = TextEditingController();
  List<StokModel> stoklar = [];
  bool yukleniyor = true;
  String? hataMesaji;

  // Supabase üzerinden verileri yükleme fonksiyonu
  Future<void> verileriYukle({String aramaMetni = ""}) async {
    setState(() {
      yukleniyor = true;
      hataMesaji = null;
    });

    try {
      final veriler = await SupabaseService.stoklariGetir(
        aramaMetni: aramaMetni,
      );

      if (!mounted) return;

      setState(() {
        stoklar = veriler;
        yukleniyor = false;
      });
    } catch (e) {
      debugPrint("❌ AnaSayfa Yükleme Hatası: $e");
      if (!mounted) return;

      setState(() {
        hataMesaji = e.toString();
        yukleniyor = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    verileriYukle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        currentIndex: seciliIndex,
        onTap: (index) {
          setState(() {
            seciliIndex = index;
          });

          if (index == 0) return;

          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SatisSayfasi()),
            ).then((_) {
              verileriYukle(aramaMetni: aramaController.text);
            });
          }

          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CarilerSayfasi()),
            );
          }

          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AyarlarSayfasi()),
            ).then((_) {
              verileriYukle(aramaMetni: aramaController.text);
            });
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Ana Sayfa"),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: "Satış",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Cariler"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Ayarlar"),
        ],
      ),
      appBar: AppBar(
        title: const Text('ÜNAL YEDEK PARÇA ERP'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'OEM / CROSS / RAKİP KOD ARA',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: aramaController,
              onChanged: (value) {
                verileriYukle(aramaMetni: value);
              },
              decoration: InputDecoration(
                hintText: 'OEM, barkod veya ürün adı yaz...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: yukleniyor
                  ? const Center(child: CircularProgressIndicator())
                  : hataMesaji != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SelectableText(
                              "❌ Bağlantı/Veri Hatası:\n\n$hataMesaji",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      : stoklar.isEmpty
                          ? const Center(
                              child: Text(
                                "Aramaya uygun ürün bulunamadı veya henüz aktarım yapılmadı.",
                                style: TextStyle(fontSize: 16),
                              ),
                            )
                          : ListView.builder(
                              itemCount: stoklar.length,
                              itemBuilder: (context, index) {
                                final urun = stoklar[index];

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            UrunDetaySayfasi(urun: urun),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 15),
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          urun.urunAdi,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text('Marka: ${urun.marka}'),
                                        Text('Araç: ${urun.arac}'),
                                        Text(
                                            'Üretici Kodu: ${urun.ureticiKodu}'),
                                        Text('Barkod: ${urun.barkod}'),
                                        Text('OEM: ${urun.oemNo}'),
                                        Text('Cross: ${urun.cross}'),
                                        Text('Rakip Kod: ${urun.rakipKod}'),
                                        Text('Raf: ${urun.raf}'),
                                        Text(
                                          'Stok: ${urun.stokMiktari}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class UrunDetaySayfasi extends StatefulWidget {
  final StokModel urun;

  const UrunDetaySayfasi({super.key, required this.urun});

  @override
  State<UrunDetaySayfasi> createState() => _UrunDetaySayfasiState();
}

class _UrunDetaySayfasiState extends State<UrunDetaySayfasi> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.urun.urunAdi)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Text(
              widget.urun.urunAdi,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 25),
            if (widget.urun.resim.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.urun.resim,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            const SizedBox(height: 20),
            bilgiSatiri("Marka", widget.urun.marka),
            bilgiSatiri("Araç", widget.urun.arac),
            bilgiSatiri("Üretici Kodu", widget.urun.ureticiKodu),
            bilgiSatiri("OEM", widget.urun.oemNo),
            bilgiSatiri("Cross", widget.urun.cross),
            bilgiSatiri("Rakip Kod", widget.urun.rakipKod),
            bilgiSatiri("Barkod", widget.urun.barkod),
            bilgiSatiri("Raf", widget.urun.raf),
            bilgiSatiri("Stok", widget.urun.stokMiktari.toString()),
            bilgiSatiri("Alış Fiyatı", "${widget.urun.alisFiyati} TL"),
            bilgiSatiri("Perakende", "${widget.urun.satisFiyatiPerakende} TL"),
            bilgiSatiri("Toptan", "${widget.urun.satisFiyatiToptan} TL"),
            bilgiSatiri("KDV", "%${widget.urun.kdv}"),
            bilgiSatiri("Ürün Özelliği", widget.urun.urunOzellik),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                SepetData.urunEkle(widget.urun);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Ürün sepete eklendi")),
                );
              },
              icon: const Icon(Icons.shopping_cart),
              label: const Text("Sepete Ekle"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget bilgiSatiri(String baslik, String deger) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(
                baslik,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(child: Text(deger)),
          ],
        ),
      ),
    );
  }
}
