// lib/screens/stok_sayfasi.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stok_model.dart';
import '../services/supabase_service.dart';
import '../services/satis_taslak_service.dart';
import '../services/excel_service.dart';
import '../services/yetki_service.dart';
import '../services/kurumsal_yazdirma_service.dart';
import 'stok_detay_sayfasi.dart';
import 'satis_sayfasi.dart';
import '../widgets/fiyat_seridi.dart';
import '../widgets/mobil_uyum.dart';

class StokSayfasi extends StatefulWidget {
  final String? acilisArama;

  const StokSayfasi({
    super.key,
    this.acilisArama,
  });

  @override
  State<StokSayfasi> createState() => _StokSayfasiState();
}

class _StokSayfasiState extends State<StokSayfasi>
    with SingleTickerProviderStateMixin {
  //------------------------------------------------------
  // TAB
  //------------------------------------------------------

  late TabController tabController;

  //------------------------------------------------------
  // CONTROLLER
  //------------------------------------------------------

  final aramaController = TextEditingController();

  final urunAdiController = TextEditingController();
  final markaController = TextEditingController();
  final modelController = TextEditingController();
  final aracController = TextEditingController();

  final ureticiKodController = TextEditingController();
  final barkodController = TextEditingController();
  final rafController = TextEditingController();
  final grupKodController = TextEditingController();

  final oemController = TextEditingController();
  final crossController = TextEditingController();
  final rakipController = TextEditingController();

  final alisController = TextEditingController();
  final satisController = TextEditingController();
  final toptanController = TextEditingController();

  final stokController = TextEditingController();
  final minStokController = TextEditingController();

  final aciklamaController = TextEditingController();

  //------------------------------------------------------
  // RESİM
  //------------------------------------------------------

  final ImagePicker picker = ImagePicker();
  final resimLinkController = TextEditingController();

  XFile? secilenResim;

  String? resimUrl;

  //------------------------------------------------------
  // LİSTELER
  //------------------------------------------------------

  List<StokModel> tumStoklar = [];

  List<StokModel> filtreliStoklar = [];

  List<Map<String, dynamic>> stokHareketleri = [];

  List<Map<String, dynamic>> sonAlislar = [];

  List<Map<String, dynamic>> sonSatislar = [];

  List<Map<String, dynamic>> muadilUrunler = [];

  final Map<int, Map<String, dynamic>> stokDepoOzetleri = {};

  final Map<int, String> stokGrupKodlari = {};

  //------------------------------------------------------
  // DURUM
  //------------------------------------------------------

  bool yukleniyor = true;

  bool kaydediliyor = false;

  bool duzenlemeModu = false;

  //------------------------------------------------------
  // SEÇİLİ ÜRÜN
  //------------------------------------------------------

  StokModel? seciliStok;

  //------------------------------------------------------
  // TIMER
  //------------------------------------------------------

  Timer? aramaTimer;

  //------------------------------------------------------
  // INIT
  //------------------------------------------------------

  @override
  void initState() {
    super.initState();

    tabController = TabController(
      length: 10,
      vsync: this,
    );

    final acilisArama = widget.acilisArama?.trim() ?? '';
    if (acilisArama.isNotEmpty) {
      aramaController.text = acilisArama;
    }

    _verileriYukle();

    aramaController.addListener(_aramaYap);

    if (acilisArama.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _aramaYap();
      });
    }
  }

  //------------------------------------------------------
  // DISPOSE
  //------------------------------------------------------

  @override
  void dispose() {
    tabController.dispose();

    aramaTimer?.cancel();

    aramaController.dispose();

    urunAdiController.dispose();
    markaController.dispose();
    modelController.dispose();
    aracController.dispose();

    ureticiKodController.dispose();
    barkodController.dispose();
    rafController.dispose();
    grupKodController.dispose();

    oemController.dispose();
    crossController.dispose();
    rakipController.dispose();

    alisController.dispose();
    satisController.dispose();
    toptanController.dispose();

    stokController.dispose();
    minStokController.dispose();

    aciklamaController.dispose();
    resimLinkController.dispose();

    super.dispose();
  }

  //------------------------------------------------------
  // VERİLERİ YÜKLE
  //------------------------------------------------------

  Future<void> _verileriYukle() async {
    if (!mounted) return;

    setState(() {
      yukleniyor = true;
    });

    try {
      await _stoklariYukle();
    } catch (e) {
      debugPrint(e.toString());
    }

    if (!mounted) return;

    setState(() {
      yukleniyor = false;
    });
  }

  //------------------------------------------------------
  // STOKLARI ÇEK
  //------------------------------------------------------

  Future<void> _stoklariYukle() async {
    // Ana stok listesi yardımcı sorgulardan bağımsız yüklenir.
    // Depo görünümü veya grup_kodu sorgusu hata verse bile
    // stok kartları ekranda görünmeye devam eder.
    final liste = await SupabaseService.stoklariGetir(limit: 250);

    // Ana stok listesi her zaman güncel tutulur.
    tumStoklar = List<StokModel>.from(liste);

    if (!mounted) return;

    final aktifArama = aramaController.text.trim();

    if (aktifArama.isEmpty) {
      setState(() {
        filtreliStoklar = List<StokModel>.from(tumStoklar);
      });
    } else {
      final aramaSonucu = await SupabaseService.stoklariGetir(
        aramaMetni: aktifArama,
      );

      if (!mounted) return;

      if (aktifArama == aramaController.text.trim()) {
        setState(() {
          filtreliStoklar = aramaSonucu;
        });
      }
    }

    List<Map<String, dynamic>> depoOzetleri = [];
    List<Map<String, dynamic>> grupKodKayitlari = [];

    try {
      depoOzetleri = await SupabaseService.stokDepoOzetGetir();
    } catch (e) {
      debugPrint('Stok depo özeti yüklenemedi: $e');
    }


    stokDepoOzetleri.clear();
    stokGrupKodlari.clear();

    for (final kayit in grupKodKayitlari) {
      final stokId = int.tryParse(
            kayit['stok_id']?.toString() ?? '',
          ) ??
          0;

      if (stokId > 0) {
        stokGrupKodlari[stokId] =
            kayit['grup_kodu']?.toString().trim() ?? '';
      }
    }

    for (final ozet in depoOzetleri) {
      final stokId = int.tryParse(
            ozet['stok_id']?.toString() ?? '',
          ) ??
          0;

      if (stokId > 0) {
        stokDepoOzetleri[stokId] = ozet;
      }
    }

    if (!mounted) return;

    // Yardımcı bilgiler geldikten sonra mevcut kartları yenile.
    setState(() {});
  }

  //------------------------------------------------------
  // YENİLE
  //------------------------------------------------------

  Future<void> yenile() async {
    await _stoklariYukle();
  }

  //------------------------------------------------------
  // GOOGLE ARAMA
  //------------------------------------------------------

  Future<void> _aramaYap() async {
    aramaTimer?.cancel();

    aramaTimer = Timer(
      const Duration(milliseconds: 250),
      () async {
        final arama = aramaController.text.trim();

        if (arama.isEmpty) {
          if (!mounted) return;

          setState(() {
            filtreliStoklar =
                List<StokModel>.from(
              tumStoklar,
            );
          });

          return;
        }

        final liste =
            await SupabaseService.stoklariGetir(
          aramaMetni: arama,
        );

        if (!mounted) return;

        // Kullanıcı 300 ms içinde yeni bir şey yazdıysa
        // eski sorgu sonucunu ekrana basma.
        if (arama !=
            aramaController.text.trim()) {
          return;
        }

        setState(() {
          filtreliStoklar = liste;

          // tumStoklar ana liste olarak korunur.
          // Böylece arama açıkken başka işlem yapılsa bile
          // arama sonucu ekrandan kaybolmaz.
        });
      },
    );
  }

  //------------------------------------------------------
  // KOPYALA
  //------------------------------------------------------

  void _kopyala(String text) {
    Clipboard.setData(
      ClipboardData(text: text),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Panoya Kopyalandı",
        ),
        duration: Duration(
          milliseconds: 700,
        ),
      ),
    );
  }

  //------------------------------------------------------
  // FORM TEMİZLE
  //------------------------------------------------------

  void _formTemizle() {
    urunAdiController.clear();
    markaController.clear();
    modelController.clear();
    aracController.clear();
    ureticiKodController.clear();
    barkodController.clear();
    rafController.clear();
    grupKodController.clear();
    oemController.clear();
    crossController.clear();
    rakipController.clear();
    alisController.clear();
    satisController.clear();
    toptanController.clear();
    stokController.clear();
    minStokController.clear();
    aciklamaController.clear();

    seciliStok = null;
    secilenResim = null;
    resimUrl = null;
    resimLinkController.clear();
    duzenlemeModu = false;

    setState(() {});
  }

  //------------------------------------------------------
  // STOK SEÇ
  //------------------------------------------------------

  void _stokSec(StokModel stok) {
    seciliStok = stok;
    duzenlemeModu = true;

    urunAdiController.text = stok.urunAdi;
    markaController.text = stok.marka;
    modelController.text = stok.model;
    aracController.text = stok.arac;
    ureticiKodController.text = stok.ureticiKodu;
    barkodController.text = stok.barkod;
    rafController.text = stok.raf;
    grupKodController.text =
        stokGrupKodlari[stok.stokId] ?? '';
    oemController.text = stok.oemNo;
    crossController.text = stok.cross;
    rakipController.text = stok.rakipKod;

    alisController.text = stok.alisFiyati.toString();
    satisController.text = stok.satisFiyatiPerakende.toString();
    toptanController.text = stok.satisFiyatiToptan.toString();

    stokController.text = stok.stokMiktari.toString();
    aciklamaController.text = stok.urunOzellik;

    resimUrl = stok.resim;
    resimLinkController.text = stok.resim ?? '';

    setState(() {});
  }

  Future<StokModel?> _kopyalanacakStokSec() async {
    final aramaCtrl = TextEditingController();
    List<StokModel> liste = List<StokModel>.from(tumStoklar);

    try {
      return await showDialog<StokModel>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              void filtrele(String value) {
                final q = value.toLowerCase().trim();

                setDialogState(() {
                  if (q.isEmpty) {
                    liste = List<StokModel>.from(tumStoklar);
                    return;
                  }

                  final kelimeler = q
                      .split(RegExp(r'\s+'))
                      .where((e) => e.isNotEmpty)
                      .toList();

                  liste = tumStoklar.where((stok) {
                    final metin = [
                      stok.urunAdi,
                      stok.ureticiKodu,
                      stok.oemNo,
                      stok.marka,
                      stok.model,
                      stok.arac,
                      stok.raf,
                      stok.barkod,
                      stok.cross,
                      stok.rakipKod,
                    ].join(' ').toLowerCase();

                    return kelimeler.every(metin.contains);
                  }).toList();
                });
              }

              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.copy_all_rounded),
                    SizedBox(width: 10),
                    Text('Kopyalanacak Stok Kartını Seç'),
                  ],
                ),
                content: SizedBox(
                  width: 850,
                  height: 580,
                  child: Column(
                    children: [
                      TextField(
                        controller: aramaCtrl,
                        autofocus: true,
                        onChanged: filtrele,
                        decoration: InputDecoration(
                          hintText:
                              'Ürün adı, üretici kodu, OEM, marka, araç...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: aramaCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    aramaCtrl.clear();
                                    filtrele('');
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: liste.isEmpty
                            ? const Center(
                                child: Text('Uygun stok kartı bulunamadı.'),
                              )
                            : ListView.separated(
                                itemCount: liste.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final stok = liste[index];

                                  return ListTile(
                                    leading: CircleAvatar(
                                      child: Text(
                                        stok.marka.isEmpty
                                            ? '?'
                                            : stok.marka
                                                .substring(0, 1)
                                                .toUpperCase(),
                                      ),
                                    ),
                                    title: Text(
                                      stok.urunAdi,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Kod: ${stok.ureticiKodu.isEmpty ? '-' : stok.ureticiKodu}'
                                      '  •  OEM: ${stok.oemNo.isEmpty ? '-' : stok.oemNo}'
                                      '  •  Marka: ${stok.marka.isEmpty ? '-' : stok.marka}'
                                      '  •  Model: ${stok.model.isEmpty ? '-' : stok.model}',
                                    ),
                                    trailing:
                                        const Icon(Icons.chevron_right),
                                    onTap: () {
                                      Navigator.pop(
                                        dialogContext,
                                        stok,
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('Vazgeç'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      aramaCtrl.dispose();
    }
  }

  void _stokKartiniFormaKopyala(
    StokModel stok,
  ) {
    urunAdiController.text = stok.urunAdi;
    markaController.text = stok.marka;
    modelController.text = stok.model;
    aracController.text = stok.arac;

    // Yeni kart açılacağı için üretici kodunu bilerek boş bırakıyoruz.
    // Kullanıcı yalnız yeni markanın / üreticinin kodunu yazıp devam edebilir.
    ureticiKodController.clear();

    oemController.text = stok.oemNo;
    crossController.text = stok.cross;
    rakipController.text = stok.rakipKod;
    rafController.text = stok.raf;

    alisController.text = stok.alisFiyati.toString();
    satisController.text =
        stok.satisFiyatiPerakende.toString();
    toptanController.text =
        stok.satisFiyatiToptan.toString();

    // Yeni stok kartında mevcut stok ve barkod kopyalanmaz.
    // Böylece yanlış stok ve mükerrer barkod oluşmaz.
    stokController.text = '0';
    barkodController.clear();

    aciklamaController.text = stok.urunOzellik;

    resimUrl = stok.resim;
    resimLinkController.text = stok.resim ?? '';
    secilenResim = null;
  }

  void _resmiBuyut(String url) {
    if (url.trim().isEmpty) return;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              SizedBox(
                width: MediaQuery.of(dialogContext).size.width * 0.96,
                height: MediaQuery.of(dialogContext).size.height * 0.92,
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 6,
                    boundaryMargin: const EdgeInsets.all(80),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text(
                          'Resim yüklenemedi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _stokResmiYukle(
    XFile? resim, {
    String? mevcutUrl,
  }) async {
    if (resim == null) {
      return mevcutUrl;
    }

    final bytes = await resim.readAsBytes();

    final uzanti = resim.name.contains('.')
        ? resim.name.split('.').last.toLowerCase()
        : 'jpg';

    final dosyaAdi =
        'stok_${DateTime.now().microsecondsSinceEpoch}.$uzanti';

    const bucket = 'stok-resimleri';

    await SupabaseService.supabase.storage
        .from(bucket)
        .uploadBinary(
          dosyaAdi,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
          ),
        );

    return SupabaseService.supabase.storage
        .from(bucket)
        .getPublicUrl(dosyaAdi);
  }

  String? _hariciResimLinkiniDogrula(String deger) {
    final link = deger.trim();
    if (link.isEmpty) return null;

    final uri = Uri.tryParse(link);
    final guvenliSemayaSahip =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;

    if (!guvenliSemayaSahip) {
      throw const FormatException(
        'Resim bağlantısı http:// veya https:// ile başlamalıdır.',
      );
    }

    return link;
  }

  void _yeniUrunDialog() {
    _formTemizle();

    List<Map<String, dynamic>> depolar = [];
    String? secilenDepo;
    String secilenBirim = "ADET";
    int secilenKdv = 20;

    double sonAlisFiyati = 0;
    double sonSatisFiyati = 0;
    int toplamSatis = 0;

    final List<String> birimler = [
      "ADET",
      "TAKIM",
      "METRE",
      "LİTRE",
      "KG",
      "KUTU",
      "PAKET",
    ];

    Future<void> depolariGetir() async {
      try {
        final depoResponse = await SupabaseService.supabase
            .from("depolar")
            .select()
            .order("depo_adi");
        depolar = List<Map<String, dynamic>>.from(depoResponse);
      } catch (e) { debugPrint('PRO ERP sessiz hata [$e]'); }
    }

    depolariGetir();

    Future<void> _resimSec(
      void Function(void Function()) setStateDialog,
    ) async {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );

      if (image == null) return;

      setStateDialog(() {
        secilenResim = image;
        resimUrl = null;
        resimLinkController.clear();
      });
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              child: SizedBox(
                width: 950,
                height: 800,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      color: Colors.blueGrey.shade800,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.inventory_2,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "YENİ STOK KARTI",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                color: Colors.white70,
                              ),
                            ),
                            onPressed: () async {
                              final secilen =
                                  await _kopyalanacakStokSec();

                              if (secilen == null) return;

                              _stokKartiniFormaKopyala(
                                secilen,
                              );

                              setStateDialog(() {});

                              if (!mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${secilen.urunAdi} kopyalandı. '
                                    'Üretici kodunu değiştirerek yeni kartı kaydedebilirsiniz.',
                                  ),
                                  duration: const Duration(
                                    seconds: 2,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.copy_all_rounded,
                            ),
                            label: const Text("Kopyala"),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      width: 220,
                                      height: 220,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: secilenResim != null
                                          ? GestureDetector(
                                              onTap: () => _resmiBuyut(
                                                secilenResim!.path,
                                              ),
                                              child: MouseRegion(
                                                cursor: SystemMouseCursors.click,
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: Image.network(
                                                    secilenResim!.path,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (_, __, ___) =>
                                                            const Center(
                                                      child: Icon(
                                                        Icons.image,
                                                        size: 70,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                          : (resimUrl != null &&
                                                  resimUrl!
                                                      .trim()
                                                      .isNotEmpty)
                                              ? GestureDetector(
                                                  onTap: () =>
                                                      _resmiBuyut(resimUrl!),
                                                  child: MouseRegion(
                                                    cursor:
                                                        SystemMouseCursors.click,
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        10,
                                                      ),
                                                      child: Image.network(
                                                        resimUrl!,
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (_, __, ___) =>
                                                                const Center(
                                                          child: Icon(
                                                            Icons.broken_image,
                                                            size: 70,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : const Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.image,
                                                      size: 70,
                                                    ),
                                                    SizedBox(height: 10),
                                                    Text("Resim Yok"),
                                                  ],
                                                ),
                                    ),
                                    const SizedBox(height: 10),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.photo),
                                      label: const Text("Resim Seç"),
                                      onPressed: () async {
                                        await _resimSec(
                                          setStateDialog,
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: 220,
                                      child: TextField(
                                        controller: resimLinkController,
                                        keyboardType: TextInputType.url,
                                        decoration: const InputDecoration(
                                          labelText: 'Harici Resim Bağlantısı',
                                          hintText: 'https://...',
                                          prefixIcon: Icon(Icons.link),
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (value) {
                                          setStateDialog(() {
                                            final link = value.trim();
                                            resimUrl =
                                                link.isEmpty ? null : link;
                                            if (link.isNotEmpty) {
                                              secilenResim = null;
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.qr_code),
                                      label: const Text("Barkod"),
                                      onPressed: () {},
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.print),
                                      label: const Text("Etiket Yazdır"),
                                      onPressed: () async {
                                        try {
                                          await KurumsalYazdirmaService.stokEtiketiYazdir(
                                            urunAdi: urunAdiController.text,
                                            ureticiKodu: ureticiKodController.text,
                                            barkod: barkodController.text,
                                            raf: rafController.text,
                                          );
                                        } catch (e) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Etiket yazdırılamadı: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Card(
                                        child: ListTile(
                                          leading: const Icon(
                                              Icons.shopping_cart),
                                          title: const Text("Son Alış"),
                                          subtitle: Text(
                                            sonAlisFiyati.toString(),
                                          ),
                                        ),
                                      ),
                                      Card(
                                        child: ListTile(
                                          leading: const Icon(
                                              Icons.point_of_sale),
                                          title: const Text("Son Satış"),
                                          subtitle: Text(
                                            sonSatisFiyati.toString(),
                                          ),
                                        ),
                                      ),
                                      Card(
                                        child: ListTile(
                                          leading:
                                              const Icon(Icons.trending_up),
                                          title: const Text("Toplam Satılan"),
                                          subtitle: Text(
                                            "$toplamSatis Adet",
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(15),
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: urunAdiController,
                                      decoration: const InputDecoration(
                                        labelText: "Ürün Adı",
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: markaController,
                                      decoration: const InputDecoration(
                                        labelText: "Marka",
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: modelController,
                                      decoration: const InputDecoration(
                                        labelText: "Model",
                                        hintText: "Ürünün model bilgisi",
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: aracController,
                                      decoration: const InputDecoration(
                                        labelText: "Araç",
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(15),
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: ureticiKodController,
                                      decoration: const InputDecoration(
                                        labelText: "Üretici Kodu",
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: barkodController,
                                      decoration: const InputDecoration(
                                        labelText: "Barkod",
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: rafController,
                                      decoration: const InputDecoration(
                                        labelText: "Raf",
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: grupKodController,
                                      textCapitalization: TextCapitalization.characters,
                                      decoration: const InputDecoration(
                                        labelText: "Grup Kodu",
                                        hintText: "Örn: FREN, FILTRE, MOTOR",
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: oemController,
                              minLines: 4,
                              maxLines: 8,
                              decoration: InputDecoration(
                                labelText: "OEM Kodları",
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: oemController.text),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: secilenDepo,
                              items: depolar.map((e) {
                                return DropdownMenuItem(
                                  value: e["depo_id"].toString(),
                                  child: Text(e["depo_adi"]),
                                );
                              }).toList(),
                              onChanged: (v) {
                                setStateDialog(() {
                                  secilenDepo = v;
                                });
                              },
                              decoration: const InputDecoration(
                                labelText: "Depo",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: secilenBirim,
                              items: birimler.map((e) {
                                return DropdownMenuItem(
                                  value: e,
                                  child: Text(e),
                                );
                              }).toList(),
                              onChanged: (v) {
                                setStateDialog(() {
                                  secilenBirim = v!;
                                });
                              },
                              decoration: const InputDecoration(
                                labelText: "Birim",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: minStokController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Minimum Stok",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              value: secilenKdv,
                              items: [1, 10, 20].map((e) {
                                return DropdownMenuItem(
                                  value: e,
                                  child: Text("%$e"),
                                );
                              }).toList(),
                              onChanged: (v) {
                                setStateDialog(() {
                                  secilenKdv = v!;
                                });
                              },
                              decoration: const InputDecoration(
                                labelText: "KDV",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: crossController,
                              minLines: 4,
                              maxLines: 8,
                              decoration: InputDecoration(
                                labelText: "Cross Kod",
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(
                                        text: crossController.text,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: rakipController,
                              minLines: 4,
                              maxLines: 8,
                              decoration: InputDecoration(
                                labelText: "Rakip Kod",
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(
                                        text: rakipController.text,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: aciklamaController,
                              minLines: 3,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                labelText: "Ürün Özelliği",
                                hintText:
                                    "Ürüne ait özellik / açıklama bilgisi",
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: stokController,
                                    decoration: const InputDecoration(
                                        labelText: "Stok"),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: alisController,
                                    decoration: const InputDecoration(
                                        labelText: "Alış"),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: satisController,
                                    decoration: const InputDecoration(
                                      labelText: "Perakende",
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: toptanController,
                                    decoration: const InputDecoration(
                                      labelText: "Toptan",
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Divider(),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Stok Hareketleri",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Tarih",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                Text("İşlem",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                Text("Miktar",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                Text("Kalan",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Divider(),
                            const SizedBox(height: 10),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Son Satışlar",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Divider(),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Son Alışlar",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text("İptal"),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () async {
                              try {
                                final ilkStok =
                                    double.tryParse(
                                      stokController.text
                                          .trim()
                                          .replaceAll(',', '.'),
                                    ) ??
                                    0.0;

                                final yeniUreticiKodu =
                                    ureticiKodController.text.trim();

                                if (yeniUreticiKodu.isEmpty) {
                                  if (!mounted) return;

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Üretici kodu boş bırakılamaz.',
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }

                                final ayniKodResponse =
                                    await SupabaseService.supabase
                                        .from('stoklar')
                                        .select('stok_id')
                                        .eq(
                                          'uretici_kodu',
                                          yeniUreticiKodu,
                                        )
                                        .limit(1);

                                final ayniKodVar =
                                    (ayniKodResponse as List).isNotEmpty;

                                if (ayniKodVar) {
                                  if (!mounted) return;

                                  final devam =
                                      await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) {
                                      return AlertDialog(
                                        title: const Text(
                                          'Üretici Kodu Zaten Var',
                                        ),
                                        content: Text(
                                          '$yeniUreticiKodu kodlu başka bir stok kartı zaten mevcut. '
                                          'Yine de yeni kart oluşturmak istiyor musunuz?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(
                                                dialogContext,
                                                false,
                                              );
                                            },
                                            child:
                                                const Text('Vazgeç'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              Navigator.pop(
                                                dialogContext,
                                                true,
                                              );
                                            },
                                            child:
                                                const Text('Devam Et'),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (devam != true) return;
                                }

                                String? yeniResimUrl;

                                try {
                                  final hariciResim =
                                      _hariciResimLinkiniDogrula(
                                    resimLinkController.text,
                                  );

                                  yeniResimUrl = hariciResim ??
                                      await _stokResmiYukle(
                                        secilenResim,
                                        mevcutUrl: resimUrl,
                                      );
                                } catch (e) {
                                  if (!mounted) return;

                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Resim yüklenemedi: $e',
                                      ),
                                      backgroundColor:
                                          Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                final yeniKayit =
                                    await SupabaseService.supabase
                                        .from('stoklar')
                                        .insert({
                                          'urun_adi':
                                              urunAdiController.text.trim(),
                                          'marka':
                                              markaController.text.trim(),
                                          'model':
                                              modelController.text.trim(),
                                          'arac':
                                              aracController.text.trim(),
                                          'uretici_kodu':
                                              yeniUreticiKodu,
                                          'oem_no':
                                              oemController.text.trim(),
                                          'cross_kod':
                                              crossController.text.trim(),
                                          'rakip_kod':
                                              rakipController.text.trim(),
                                          'barkod':
                                              barkodController.text.trim(),
                                          'raf':
                                              rafController.text.trim(),
                                          'grup_kodu':
                                              grupKodController.text.trim(),
                                          'urun_ozellik':
                                              aciklamaController.text.trim(),
                                          'resim': yeniResimUrl,
                                          'stok_miktari': 0,
                                          'alis_fiyati':
                                              double.tryParse(
                                                    alisController.text
                                                        .replaceAll(',', '.'),
                                                  ) ??
                                                  0,
                                          'satis_fiyati_perakende':
                                              double.tryParse(
                                                    satisController.text
                                                        .replaceAll(',', '.'),
                                                  ) ??
                                                  0,
                                          'satis_fiyati_toptan':
                                              double.tryParse(
                                                    toptanController.text
                                                        .replaceAll(',', '.'),
                                                  ) ??
                                                  0,
                                          'min_stok':
                                              int.tryParse(
                                                    minStokController.text,
                                                  ) ??
                                                  2,
                                          'birim': secilenBirim,
                                          'kdv': secilenKdv,
                                        })
                                        .select('stok_id')
                                        .single();

                                final yeniStokId =
                                    int.tryParse(
                                      yeniKayit['stok_id']
                                          .toString(),
                                    );

                                final depoId = int.tryParse(
                                  secilenDepo ?? '',
                                );

                                if (yeniStokId != null &&
                                    depoId != null &&
                                    ilkStok > 0) {
                                  await SupabaseService.supabase.rpc(
                                    'stok_sayim_duzelt',
                                    params: {
                                      'p_stok_id': yeniStokId,
                                      'p_depo_id': depoId,
                                      'p_sayilan_miktar': ilkStok,
                                      'p_kullanici': YetkiService.aktifKullanici,
                                      'p_aciklama':
                                          'Yeni stok kartı açılış miktarı',
                                    },
                                  );
                                }

                                if (!mounted) return;

                                Navigator.pop(context);

                                _stoklariYukle();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Ürün başarıyla eklendi."),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Hata : $e"),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            child: const Text("Kaydet"),
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
  }

  Future<void> _urunDuzenle(StokModel stok) async {
    // StokModel içinde olmayan bazı alanları doğrudan stoklar
    // tablosundan alıyoruz. Böylece model sınıfını değiştirmeden
    // düzenleme formunda mevcut Birim / Min. Stok / KDV görünür.
    Map<String, dynamic> hamStok = <String, dynamic>{};

    try {
      final response =
          await SupabaseService.supabase
              .from('stoklar')
              .select('birim, min_stok, kdv, grup_kodu')
              .eq('stok_id', stok.stokId)
              .limit(1);

      final liste =
          List<Map<String, dynamic>>.from(
        response,
      );

      if (liste.isNotEmpty) {
        hamStok = liste.first;
      }
    } catch (_) {
      // Bu alanlar okunamazsa güvenli varsayılanlar kullanılır.
    }

    final urunAdiCtrl =
        TextEditingController(text: stok.urunAdi);
    final ureticiKodCtrl =
        TextEditingController(text: stok.ureticiKodu);
    final oemCtrl =
        TextEditingController(text: stok.oemNo);
    final barkodCtrl =
        TextEditingController(text: stok.barkod);
    final crossCtrl =
        TextEditingController(text: stok.cross);
    final rakipCtrl =
        TextEditingController(text: stok.rakipKod);
    final markaCtrl =
        TextEditingController(text: stok.marka);
    final modelCtrl =
        TextEditingController(text: stok.model);
    final aracCtrl =
        TextEditingController(text: stok.arac);
    final urunOzellikCtrl =
        TextEditingController(text: stok.urunOzellik);
    final rafCtrl =
        TextEditingController(text: stok.raf);
    final grupKodCtrl = TextEditingController(
      text: hamStok['grup_kodu']?.toString() ?? '',
    );
    final minStokCtrl = TextEditingController(
      text: (hamStok['min_stok'] ?? stok.minimumStok)
          .toString(),
    );
    final alisFiyatCtrl = TextEditingController(
      text: stok.alisFiyati.toString(),
    );
    final perakendeCtrl = TextEditingController(
      text: stok.satisFiyatiPerakende.toString(),
    );
    final toptanCtrl = TextEditingController(
      text: stok.satisFiyatiToptan.toString(),
    );

    XFile? yeniResim;
    String? mevcutResimUrl = stok.resim;
    final resimLinkCtrl = TextEditingController(
      text: stok.resim ?? '',
    );

    final hamBirim =
        hamStok['birim']?.toString().trim() ?? '';

    String secilenBirim =
        hamBirim.isEmpty ? 'ADET' : hamBirim;

    final hamKdv = hamStok['kdv'];

    int secilenKdv = hamKdv is num
        ? hamKdv.toInt()
        : (int.tryParse(
              hamKdv?.toString() ?? '',
            ) ??
            stok.kdv.toInt());

    if (secilenKdv <= 0) {
      secilenKdv = 20;
    }

    const birimler = <String>[
      'ADET',
      'TAKIM',
      'METRE',
      'LİTRE',
      'KG',
      'KUTU',
      'PAKET',
    ];

    Map<String, dynamic>? sonuc;

    try {
      sonuc = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (
              context,
              setDialogState,
            ) {
              Future<void> resimSec() async {
                final image = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 88,
                );

                if (image == null) return;

                setDialogState(() {
                  yeniResim = image;
                  mevcutResimUrl = null;
                  resimLinkCtrl.clear();
                });
              }

              return Dialog(
                child: SizedBox(
                  width: 980,
                  height: 820,
                  child: Column(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.all(15),
                        color:
                            Colors.blueGrey.shade800,
                        child: const Row(
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'STOK KARTI DÜZENLE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding:
                              const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: [
                                      Container(
                                        width: 230,
                                        height: 230,
                                        decoration:
                                            BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: yeniResim != null
                                            ? GestureDetector(
                                                onTap: () => _resmiBuyut(
                                                  yeniResim!.path,
                                                ),
                                                child: MouseRegion(
                                                  cursor:
                                                      SystemMouseCursors.click,
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      10,
                                                    ),
                                                    child: Image.network(
                                                      yeniResim!.path,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (_, __, ___) =>
                                                              const Center(
                                                        child: Icon(
                                                          Icons.image,
                                                          size: 70,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : (mevcutResimUrl != null &&
                                                    mevcutResimUrl!
                                                        .trim()
                                                        .isNotEmpty)
                                                ? GestureDetector(
                                                    onTap: () => _resmiBuyut(
                                                      mevcutResimUrl!,
                                                    ),
                                                    child: MouseRegion(
                                                      cursor:
                                                          SystemMouseCursors.click,
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                          10,
                                                        ),
                                                        child: Image.network(
                                                          mevcutResimUrl!,
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (_, __, ___) =>
                                                                  const Center(
                                                            child: Icon(
                                                              Icons.broken_image,
                                                              size: 70,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : const Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons.image,
                                                        size: 70,
                                                      ),
                                                      SizedBox(
                                                        height: 10,
                                                      ),
                                                      Text(
                                                        'Resim Yok',
                                                      ),
                                                    ],
                                                  ),
                                      ),
                                      const SizedBox(
                                        height: 10,
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: resimSec,
                                        icon: const Icon(
                                          Icons.photo_library,
                                        ),
                                        label: const Text(
                                          'Resim Seç / Değiştir',
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: 230,
                                        child: TextField(
                                          controller: resimLinkCtrl,
                                          keyboardType: TextInputType.url,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Harici Resim Bağlantısı',
                                            hintText: 'https://...',
                                            prefixIcon: Icon(Icons.link),
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (value) {
                                            setDialogState(() {
                                              final link = value.trim();
                                              mevcutResimUrl = link.isEmpty
                                                  ? null
                                                  : link;
                                              if (link.isNotEmpty) {
                                                yeniResim = null;
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                      if ((mevcutResimUrl != null &&
                                              mevcutResimUrl!
                                                  .trim()
                                                  .isNotEmpty) ||
                                          yeniResim != null)
                                        TextButton.icon(
                                          onPressed: () {
                                            setDialogState(() {
                                              yeniResim = null;
                                              mevcutResimUrl =
                                                  null;
                                              resimLinkCtrl.clear();
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          label: const Text(
                                            'Resmi Kaldır',
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Card(
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.all(
                                          15,
                                        ),
                                        child: Column(
                                          children: [
                                            TextField(
                                              controller:
                                                  urunAdiCtrl,
                                              maxLines: null,
                                              decoration:
                                                  const InputDecoration(
                                                labelText:
                                                    'Ürün Adı',
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 12,
                                            ),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child:
                                                      TextField(
                                                    controller:
                                                        markaCtrl,
                                                    decoration:
                                                        const InputDecoration(
                                                      labelText:
                                                          'Marka',
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: 12,
                                                ),
                                                Expanded(
                                                  child:
                                                      TextField(
                                                    controller:
                                                        modelCtrl,
                                                    decoration:
                                                        const InputDecoration(
                                                      labelText:
                                                          'Model',
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: 12,
                                                ),
                                                Expanded(
                                                  child:
                                                      TextField(
                                                    controller:
                                                        aracCtrl,
                                                    decoration:
                                                        const InputDecoration(
                                                      labelText:
                                                          'Araç',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(
                                              height: 12,
                                            ),
                                            TextField(
                                              controller:
                                                  urunOzellikCtrl,
                                              minLines: 2,
                                              maxLines: 4,
                                              decoration:
                                                  const InputDecoration(
                                                labelText:
                                                    'Ürün Özelliği',
                                                hintText:
                                                    'Örn: 8 parça, ölçü, yön, teknik özellik...',
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 12,
                                            ),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child:
                                                      TextField(
                                                    controller:
                                                        ureticiKodCtrl,
                                                    decoration:
                                                        const InputDecoration(
                                                      labelText:
                                                          'Üretici Kodu',
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: 12,
                                                ),
                                                Expanded(
                                                  child:
                                                      TextField(
                                                    controller:
                                                        barkodCtrl,
                                                    decoration:
                                                        const InputDecoration(
                                                      labelText:
                                                          'Barkod',
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: 12,
                                                ),
                                                Expanded(
                                                  child:
                                                      TextField(
                                                    controller:
                                                        rafCtrl,
                                                    decoration:
                                                        const InputDecoration(
                                                      labelText:
                                                          'RAF',
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: 12,
                                                ),
                                                Expanded(
                                                  child:
                                                      TextField(
                                                    controller:
                                                        grupKodCtrl,
                                                    textCapitalization:
                                                        TextCapitalization
                                                            .characters,
                                                    decoration:
                                                        const InputDecoration(
                                                      labelText:
                                                          'Grup Kodu',
                                                      hintText:
                                                          'Örn: FREN, FILTRE, MOTOR',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: oemCtrl,
                                minLines: 3,
                                maxLines: 7,
                                decoration:
                                    const InputDecoration(
                                  labelText: 'OEM Kodları',
                                  border:
                                      OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: crossCtrl,
                                minLines: 3,
                                maxLines: 7,
                                decoration:
                                    const InputDecoration(
                                  labelText: 'Cross Kod',
                                  border:
                                      OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: rakipCtrl,
                                minLines: 3,
                                maxLines: 7,
                                decoration:
                                    const InputDecoration(
                                  labelText: 'Rakip Kod',
                                  border:
                                      OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Card(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.all(
                                    15,
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child:
                                                DropdownButtonFormField<
                                                    String>(
                                              value: birimler
                                                      .contains(
                                                    secilenBirim,
                                                  )
                                                  ? secilenBirim
                                                  : 'ADET',
                                              items: birimler
                                                  .map(
                                                    (birim) =>
                                                        DropdownMenuItem<
                                                            String>(
                                                      value:
                                                          birim,
                                                      child:
                                                          Text(
                                                        birim,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged:
                                                  (value) {
                                                if (value ==
                                                    null) {
                                                  return;
                                                }

                                                setDialogState(
                                                  () {
                                                    secilenBirim =
                                                        value;
                                                  },
                                                );
                                              },
                                              decoration:
                                                  const InputDecoration(
                                                labelText:
                                                    'Birim',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 12,
                                          ),
                                          Expanded(
                                            child:
                                                TextField(
                                              controller:
                                                  minStokCtrl,
                                              keyboardType:
                                                  TextInputType
                                                      .number,
                                              decoration:
                                                  const InputDecoration(
                                                labelText:
                                                    'Minimum Stok',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 12,
                                          ),
                                          Expanded(
                                            child:
                                                DropdownButtonFormField<
                                                    int>(
                                              value:
                                                  [1, 10, 20]
                                                          .contains(
                                                        secilenKdv,
                                                      )
                                                      ? secilenKdv
                                                      : 20,
                                              items: [
                                                1,
                                                10,
                                                20,
                                              ]
                                                  .map(
                                                    (kdv) =>
                                                        DropdownMenuItem<
                                                            int>(
                                                      value:
                                                          kdv,
                                                      child:
                                                          Text(
                                                        '%$kdv',
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged:
                                                  (value) {
                                                if (value ==
                                                    null) {
                                                  return;
                                                }

                                                setDialogState(
                                                  () {
                                                    secilenKdv =
                                                        value;
                                                  },
                                                );
                                              },
                                              decoration:
                                                  const InputDecoration(
                                                labelText:
                                                    'KDV',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(
                                        height: 12,
                                      ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child:
                                                TextField(
                                              controller:
                                                  alisFiyatCtrl,
                                              keyboardType:
                                                  const TextInputType
                                                      .numberWithOptions(
                                                decimal: true,
                                              ),
                                              decoration:
                                                  const InputDecoration(
                                                labelText:
                                                    'Alış Fiyatı',
                                                suffixText: '₺',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 12,
                                          ),
                                          Expanded(
                                            child:
                                                TextField(
                                              controller:
                                                  perakendeCtrl,
                                              keyboardType:
                                                  const TextInputType
                                                      .numberWithOptions(
                                                decimal: true,
                                              ),
                                              decoration:
                                                  const InputDecoration(
                                                labelText:
                                                    'Perakende Satış',
                                                suffixText: '₺',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 12,
                                          ),
                                          Expanded(
                                            child:
                                                TextField(
                                              controller:
                                                  toptanCtrl,
                                              keyboardType:
                                                  const TextInputType
                                                      .numberWithOptions(
                                                decimal: true,
                                              ),
                                              decoration:
                                                  const InputDecoration(
                                                labelText:
                                                    'Toptan Satış',
                                                suffixText: '₺',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(
                                        height: 12,
                                      ),
                                      Align(
                                        alignment:
                                            Alignment.centerLeft,
                                        child: Text(
                                          'Mevcut Stok: '
                                          '${stok.stokMiktari.toStringAsFixed(0)}',
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 4,
                                      ),
                                      const Align(
                                        alignment:
                                            Alignment.centerLeft,
                                        child: Text(
                                          'Stok miktarı doğrudan bu ekrandan değiştirilmez. '
                                          'Stok düzeltmesi için Sayım ekranını kullanın.',
                                          style: TextStyle(
                                            color:
                                                Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.all(15),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(
                                  dialogContext,
                                );
                              },
                              child:
                                  const Text('İptal'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: () async {
                                String? kaydedilecekResim;

                                try {
                                  final hariciResim =
                                      _hariciResimLinkiniDogrula(
                                    resimLinkCtrl.text,
                                  );

                                  kaydedilecekResim = hariciResim ??
                                      await _stokResmiYukle(
                                        yeniResim,
                                        mevcutUrl: mevcutResimUrl,
                                      );
                                } catch (e) {
                                  if (!mounted) return;

                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Resim yüklenemedi: $e',
                                      ),
                                      backgroundColor:
                                          Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                Navigator.pop(
                                  dialogContext,
                                  <String, dynamic>{
                                    'urun_adi':
                                        urunAdiCtrl.text
                                            .trim(),
                                    'uretici_kodu':
                                        ureticiKodCtrl
                                            .text
                                            .trim(),
                                    'oem_no':
                                        oemCtrl.text
                                            .trim(),
                                    'barkod':
                                        barkodCtrl.text
                                            .trim(),
                                    'cross_kod':
                                        crossCtrl.text
                                            .trim(),
                                    'rakip_kod':
                                        rakipCtrl.text
                                            .trim(),
                                    'marka':
                                        markaCtrl.text
                                            .trim(),
                                    'model':
                                        modelCtrl.text
                                            .trim(),
                                    'arac':
                                        aracCtrl.text
                                            .trim(),
                                    'urun_ozellik':
                                        urunOzellikCtrl
                                            .text
                                            .trim(),
                                    'raf':
                                        rafCtrl.text
                                            .trim(),
                                    'grup_kodu':
                                        grupKodCtrl.text
                                            .trim(),
                                    'min_stok':
                                        int.tryParse(
                                              minStokCtrl
                                                  .text
                                                  .trim(),
                                            ) ??
                                            0,
                                    'birim':
                                        secilenBirim,
                                    'kdv':
                                        secilenKdv,
                                    'alis_fiyati':
                                        double.tryParse(
                                              alisFiyatCtrl
                                                  .text
                                                  .trim()
                                                  .replaceAll(
                                                    ',',
                                                    '.',
                                                  ),
                                            ) ??
                                            0,
                                    'satis_fiyati_perakende':
                                        double.tryParse(
                                              perakendeCtrl
                                                  .text
                                                  .trim()
                                                  .replaceAll(
                                                    ',',
                                                    '.',
                                                  ),
                                            ) ??
                                            0,
                                    'satis_fiyati_toptan':
                                        double.tryParse(
                                              toptanCtrl.text
                                                  .trim()
                                                  .replaceAll(
                                                    ',',
                                                    '.',
                                                  ),
                                            ) ??
                                            0,
                                    'resim':
                                        kaydedilecekResim,
                                  },
                                );
                              },
                              icon: const Icon(
                                Icons.save_rounded,
                              ),
                              label:
                                  const Text('Kaydet'),
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
    } finally {
      urunAdiCtrl.dispose();
      ureticiKodCtrl.dispose();
      oemCtrl.dispose();
      barkodCtrl.dispose();
      crossCtrl.dispose();
      rakipCtrl.dispose();
      markaCtrl.dispose();
      modelCtrl.dispose();
      aracCtrl.dispose();
      urunOzellikCtrl.dispose();
      rafCtrl.dispose();
      grupKodCtrl.dispose();
      minStokCtrl.dispose();
      alisFiyatCtrl.dispose();
      perakendeCtrl.dispose();
      toptanCtrl.dispose();
      resimLinkCtrl.dispose();
    }

    if (sonuc == null) return;

    try {
      final updateResponse =
          await SupabaseService.supabase
              .from('stoklar')
              .update(sonuc)
              .eq('stok_id', stok.stokId)
              .select(
                'stok_id, urun_adi, uretici_kodu, oem_no, '
                'barkod, cross_kod, rakip_kod, marka, model, '
                'arac, urun_ozellik, raf, grup_kodu, min_stok, birim, kdv, '
                'alis_fiyati, satis_fiyati_perakende, '
                'satis_fiyati_toptan, resim',
              );

      final guncellenenKayitlar =
          List<Map<String, dynamic>>.from(
        updateResponse,
      );

      if (guncellenenKayitlar.isEmpty) {
        throw Exception(
          'Stok kartı veritabanında güncellenmedi. '
          'Yetki/RLS ayarlarını kontrol edin.',
        );
      }

      if (!mounted) return;

      await _stoklariYukle();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Stok kartı başarıyla güncellendi.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stok kartı güncellenemedi: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double _sayi(dynamic deger) {
    return double.tryParse(
          deger?.toString().replaceAll(',', '.') ?? '0',
        ) ??
        0;
  }

  String _miktarYaz(dynamic deger) {
    final sayi = _sayi(deger);

    if (sayi == sayi.roundToDouble()) {
      return sayi.toStringAsFixed(0);
    }

    return sayi.toStringAsFixed(3);
  }

  Map<String, dynamic> _depoOzeti(
    StokModel stok,
  ) {
    final ozet = stokDepoOzetleri[stok.stokId];

    if (ozet != null) {
      return ozet;
    }

    return {
      'satilabilir_stok': stok.stokMiktari,
      'iade_bekleyen_stok': 0,
      'hasarli_stok': 0,
      'fiziksel_toplam_stok': stok.stokMiktari,
    };
  }

  Widget _stokBilgiKutusu({
    required String baslik,
    required dynamic miktar,
    required Color renk,
  }) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: renk.withOpacity(0.09),
        border: Border.all(
          color: renk.withOpacity(0.35),
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            baslik,
            style: TextStyle(
              color: renk,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _miktarYaz(miktar),
            style: TextStyle(
              color: renk,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stokDepoOzetiKarti(
    StokModel stok,
  ) {
    final ozet = _depoOzeti(stok);

    final normal =
        _sayi(ozet['satilabilir_stok']);

    final iade =
        _sayi(ozet['iade_bekleyen_stok']);

    final hasarli =
        _sayi(ozet['hasarli_stok']);

    final toplam =
        _sayi(ozet['fiziksel_toplam_stok']);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        _depoDagiliminiGoster(stok);
      },
      child: Tooltip(
        message: 'Depo dağılımını görüntüle',
        child: Column(
          children: [
            const Text(
              'DEPO STOKLARI',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _stokBilgiKutusu(
                  baslik: 'NORMAL',
                  miktar: normal,
                  renk: normal <= 2
                      ? Colors.red
                      : Colors.green,
                ),
                const SizedBox(width: 5),
                _stokBilgiKutusu(
                  baslik: 'İADE',
                  miktar: iade,
                  renk: Colors.orange,
                ),
                const SizedBox(width: 5),
                _stokBilgiKutusu(
                  baslik: 'HASARLI',
                  miktar: hasarli,
                  renk: Colors.red.shade700,
                ),
                const SizedBox(width: 5),
                _stokBilgiKutusu(
                  baslik: 'TOPLAM',
                  miktar: toplam,
                  renk: Colors.blueGrey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _depoDagiliminiGoster(
    StokModel stok,
  ) async {
    try {
      final dagilim =
          await SupabaseService.stokDepoDagilimiGetir(
        stok.stokId,
      );

      if (!mounted) return;

      final satirlar =
          List<Map<String, dynamic>>.from(
        dagilim['satirlar'] as List? ??
            <Map<String, dynamic>>[],
      );

      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(
                  Icons.warehouse_rounded,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${stok.urunAdi} - Depo Dağılımı',
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 760,
              height: 480,
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _stokBilgiKutusu(
                        baslik: 'NORMAL',
                        miktar: dagilim['normal'],
                        renk: Colors.green,
                      ),
                      _stokBilgiKutusu(
                        baslik: 'İADE',
                        miktar: dagilim['iade'],
                        renk: Colors.orange,
                      ),
                      _stokBilgiKutusu(
                        baslik: 'HASARLI',
                        miktar: dagilim['hasarli'],
                        renk: Colors.red.shade700,
                      ),
                      _stokBilgiKutusu(
                        baslik: 'TOPLAM',
                        miktar: dagilim['toplam'],
                        renk: Colors.blueGrey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  Expanded(
                    child: satirlar.isEmpty
                        ? const Center(
                            child: Text(
                              'Bu ürün için depo bakiyesi bulunamadı.',
                            ),
                          )
                        : ListView.separated(
                            itemCount: satirlar.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final satir = satirlar[index];

                              return ListTile(
                                leading: CircleAvatar(
                                  child: Icon(
                                    satir['depo_tipi']
                                                ?.toString() ==
                                            'IADE'
                                        ? Icons
                                            .assignment_return_rounded
                                        : satir['depo_tipi']
                                                    ?.toString() ==
                                                'HASARLI'
                                            ? Icons
                                                .warning_amber_rounded
                                            : Icons
                                                .warehouse_rounded,
                                  ),
                                ),
                                title: Text(
                                  satir['depo_adi']
                                          ?.toString() ??
                                      '-',
                                ),
                                subtitle: Text(
                                  'Tip: ${satir['depo_tipi'] ?? '-'}'
                                  ' • Rezerve: '
                                  '${_miktarYaz(satir['rezerve_miktar'])}',
                                ),
                                trailing: Text(
                                  '${_miktarYaz(satir['miktar'])} Adet',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
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
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Depo dağılımı yüklenemedi: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _excelDisariAktar() async {if(!await YetkiService.kontrolEt(context,'excel'))return;try{final f=await ExcelService.stoklariAktar();if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Excel hazır: $f')));}catch(e){if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Excel hatası: $e'),backgroundColor:Colors.red));}}
  Future<void> _excelIceAktar() async {if(!await YetkiService.kontrolEt(context,'excel'))return;try{final n=await ExcelService.stoklariIceAktar();await yenile();if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$n stok işlendi.'),backgroundColor:Colors.green));}catch(e){if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Excel içe aktarım hatası: $e'),backgroundColor:Colors.red));}}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          "STOK YÖNETİMİ",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(tooltip: 'Excel’e Aktar',onPressed: _excelDisariAktar,icon: const Icon(Icons.file_download_outlined)),
          IconButton(tooltip: 'Excel’den Al',onPressed: _excelIceAktar,icon: const Icon(Icons.file_upload_outlined)),
          IconButton(
            tooltip: "Yenile",
            onPressed: yenile,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: aramaController,
                    decoration: InputDecoration(
                      hintText:
                          "Ürün Adı, OEM, Üretici Kodu, Barkod, Cross, Rakip Kod...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: aramaController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                aramaController.clear();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _yeniUrunDialog,
                  icon: const Icon(Icons.add),
                  label: const Text("Yeni Ürün"),
                ),
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (_) {
                if (yukleniyor) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (filtreliStoklar.isEmpty) {
                  return const Center(
                    child: Text(
                      "Kayıt bulunamadı",
                      style: TextStyle(fontSize: 18),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtreliStoklar.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final urun = filtreliStoklar[index];

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StokDetaySayfasi(
                                stok: urun,
                              ),
                            ),
                          );

                          if (!mounted) return;

                          await _stoklariYukle();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: MobilYatayRow(
                            minWidth: 1180,
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: urun.resim.isEmpty
                                    ? const Icon(
                                        Icons.inventory_2,
                                        size: 34,
                                        color: Colors.blue,
                                      )
                                    : GestureDetector(
                                        onTap: () => _resmiBuyut(urun.resim),
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: Image.network(
                                              urun.resim,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                Icons.broken_image,
                                                size: 34,
                                                color: Colors.blueGrey,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      urun.urunAdi,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color:
                                                  Colors.blue.shade200,
                                            ),
                                          ),
                                          child: RichText(
                                            text: TextSpan(
                                              style: DefaultTextStyle.of(
                                                context,
                                              ).style,
                                              children: [
                                                TextSpan(
                                                  text:
                                                      'Üretici Kodu: ',
                                                  style: TextStyle(
                                                    color: Colors
                                                        .blue.shade700,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: urun
                                                          .ureticiKodu
                                                          .trim()
                                                          .isEmpty
                                                      ? '-'
                                                      : urun
                                                          .ureticiKodu,
                                                  style: TextStyle(
                                                    color: Colors
                                                        .blue.shade900,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors
                                                .deepPurple.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Colors
                                                  .deepPurple.shade200,
                                            ),
                                          ),
                                          child: RichText(
                                            text: TextSpan(
                                              style: DefaultTextStyle.of(
                                                context,
                                              ).style,
                                              children: [
                                                TextSpan(
                                                  text: 'Marka: ',
                                                  style: TextStyle(
                                                    color: Colors
                                                        .deepPurple
                                                        .shade700,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: urun.marka
                                                          .trim()
                                                          .isEmpty
                                                      ? '-'
                                                      : urun.marka,
                                                  style: TextStyle(
                                                    color: Colors
                                                        .deepPurple
                                                        .shade900,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.orange.shade200,
                                        ),
                                      ),
                                      child: RichText(
                                        text: TextSpan(
                                          style: DefaultTextStyle.of(
                                            context,
                                          ).style,
                                          children: [
                                            TextSpan(
                                              text: 'Grup Kodu: ',
                                              style: TextStyle(
                                                color:
                                                    Colors.orange.shade800,
                                                fontWeight:
                                                    FontWeight.w600,
                                              ),
                                            ),
                                            TextSpan(
                                              text:
                                                  (stokGrupKodlari[urun.stokId] ??
                                                              '')
                                                          .trim()
                                                          .isEmpty
                                                      ? '-'
                                                      : stokGrupKodlari[
                                                          urun.stokId],
                                              style: TextStyle(
                                                color:
                                                    Colors.orange.shade900,
                                                fontWeight:
                                                    FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Model : ${urun.model.trim().isEmpty ? '-' : urun.model}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text("Araç : ${urun.arac}"),
                                    Text("Ürün Özelliği : ${urun.urunOzellik}"),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.shade50,
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                          color: Colors.blueGrey.shade300,
                                          width: 1.4,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Icon(
                                            Icons.location_on_rounded,
                                            size: 19,
                                            color: Colors.blueGrey.shade800,
                                          ),
                                          const SizedBox(width: 7),
                                          Text(
                                            'RAF  ${urun.raf.trim().isEmpty ? '-' : urun.raf}',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.blueGrey.shade900,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 315,
                                child: _stokDepoOzetiKarti(
                                  urun,
                                ),
                              ),
                              const SizedBox(width: 20),
                              SizedBox(
                                width: 430,
                                child: FiyatSeridi(
                                  stok: urun,
                                  kompakt: true,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Column(
                                children: [
                                  IconButton(
                                    tooltip: 'Satışa Ekle',
                                    icon: const Icon(
                                      Icons.add_shopping_cart_rounded,
                                      color: Colors.blue,
                                    ),
                                    onPressed: urun.stokMiktari <= 0
                                        ? null
                                        : () async {
                                            SatisTaslakService.ekle(urun);
                                            await Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => const SatisSayfasi(),
                                              ),
                                            );

                                            if (!mounted) return;
                                            await _stoklariYukle();
                                          },
                                  ),
                                  IconButton(
                                    tooltip: "Düzenle",
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.orange,
                                    ),
                                    onPressed: () {
                                      _urunDuzenle(urun);
                                    },
                                  ),
                                  IconButton(
                                    tooltip: "Sil",
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {},
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
