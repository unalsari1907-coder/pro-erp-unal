import 'dart:async';

import 'package:flutter/material.dart';
import '../../../widgets/belge_stok_arama_karti.dart';

import '../../../models/stok_model.dart';
import '../../../services/supabase_service.dart';

class AlisUrunArama extends StatefulWidget {
  final ValueChanged<StokModel> onUrunSecildi;

  const AlisUrunArama({
    super.key,
    required this.onUrunSecildi,
  });

  @override
  State<AlisUrunArama> createState() =>
      _AlisUrunAramaState();
}

class _AlisUrunAramaState extends State<AlisUrunArama> {
  final TextEditingController _aramaController =
      TextEditingController();

  final FocusNode _aramaFocusNode = FocusNode();

  Timer? _debounce;

  List<StokModel> _sonuclar = [];

  bool _araniyor = false;
  String? _hataMesaji;

  Future<void> _ara(String metin) async {
    _debounce?.cancel();

    _debounce = Timer(
      const Duration(milliseconds: 300),
      () async {
        final arama = metin.trim();

        if (arama.isEmpty) {
          if (!mounted) return;

          setState(() {
            _sonuclar = [];
            _araniyor = false;
            _hataMesaji = null;
          });

          return;
        }

        if (!mounted) return;

        setState(() {
          _araniyor = true;
          _hataMesaji = null;
        });

        try {
          final liste =
              await SupabaseService.stoklariGetir(
            aramaMetni: arama,
          );

          if (!mounted) return;

          setState(() {
            _sonuclar = liste;
            _araniyor = false;
          });
        } catch (e) {
          if (!mounted) return;

          setState(() {
            _sonuclar = [];
            _araniyor = false;
            _hataMesaji = e.toString();
          });
        }
      },
    );
  }

  void _urunEkle(StokModel urun) {
    widget.onUrunSecildi(urun);

    _aramaController.clear();

    setState(() {
      _sonuclar = [];
      _hataMesaji = null;
    });

    _aramaFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _aramaController.dispose();
    _aramaFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.all(8),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          10,
          10,
          10,
          8,
        ),
        child: Column(
          children: [
            TextField(
              controller: _aramaController,
              focusNode: _aramaFocusNode,
              autofocus: true,
              decoration: InputDecoration(
                hintText:
                    'Ürün adı, kod, OEM, barkod, marka, RAF...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _aramaController.text.isNotEmpty
                        ? IconButton(
                            tooltip: 'Temizle',
                            onPressed: () {
                              _aramaController.clear();
                              _ara('');
                              _aramaFocusNode
                                  .requestFocus();

                              setState(() {});
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (deger) {
                setState(() {});
                _ara(deger);
              },
              onSubmitted: (_) {
                if (_sonuclar.length == 1) {
                  _urunEkle(_sonuclar.first);
                }
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ClipRect(
                child: _icerik(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _icerik() {
    if (_araniyor) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hataMesaji != null) {
      return Center(
        child: Text(
          'Arama hatası:\n$_hataMesaji',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.red,
          ),
        ),
      );
    }

    if (_aramaController.text.trim().isEmpty) {
      return const Center(
        child: Text(
          'Ürün aramak için yukarıdaki alana yazın.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey,
          ),
        ),
      );
    }

    if (_sonuclar.isEmpty) {
      return const Center(
        child: Text(
          'Ürün bulunamadı.',
          style: TextStyle(
            color: Colors.grey,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 6),
      itemCount: _sonuclar.length,
      separatorBuilder: (_, __) {
        return const SizedBox(height: 4);
      },
      itemBuilder: (context, index) {
        final urun = _sonuclar[index];

        return BelgeStokAramaKarti(
          stok: urun,
          onEkle: () => _urunEkle(urun),
        );
      },
    );
  }
}