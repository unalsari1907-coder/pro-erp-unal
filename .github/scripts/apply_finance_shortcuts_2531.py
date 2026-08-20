from pathlib import Path


def must(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f"Pattern not found: {label}")
    return text.replace(old, new, 1)

p = Path('lib/screens/kasa_banka_sayfasi.dart')
s = p.read_text(encoding='utf-8')
s = must(s, "  final TextEditingController _aramaController = TextEditingController();\n\n  bool _yukleniyor = true;", "  final TextEditingController _aramaController = TextEditingController();\n  final FocusNode _aramaFocusNode = FocusNode(debugLabel: 'kasaArama');\n\n  bool _yukleniyor = true;", 'kasa focus node')
s = must(s, "    _aramaController.dispose();\n\n    super.dispose();", "    _aramaController.dispose();\n    _aramaFocusNode.dispose();\n\n    super.dispose();", 'kasa focus dispose')
s = s.replace(".select('kasa_id, kasa_adi, kasa_tipi')", ".select('kasa_id, kasa_adi, kasa_tipi, kk_limit')", 1)

if '_kkLimitDuzenle(' not in s:
    marker = "  double _kasaBakiyesi(int kasaId) {"
    helper = """  bool _krediKartiMi(Map<String, dynamic> kasa) {
    final ad = _metin(kasa['kasa_adi']).toUpperCase();
    final tip = _metin(kasa['kasa_tipi']).toUpperCase();
    return tip.contains('POS') || tip.contains('KART') || ad.contains('POS') || ad.contains('K.K') || ad.contains('KREDI') || ad.contains('KREDİ') || ad.contains('KART');
  }

  double _kkLimit(Map<String, dynamic> kasa) => _sayi(kasa['kk_limit']);

  double _kkKullanilan(Map<String, dynamic> kasa) {
    final id = int.tryParse(kasa['kasa_id']?.toString() ?? '') ?? 0;
    final bakiye = _kasaBakiyesi(id);
    return bakiye < 0 ? -bakiye : 0.0;
  }

  double _kkKalan(Map<String, dynamic> kasa) {
    final kalan = _kkLimit(kasa) - _kkKullanilan(kasa);
    return kalan < 0 ? 0 : kalan;
  }

  Future<void> _kkLimitDuzenle(Map<String, dynamic> kasa) async {
    final kasaId = int.tryParse(kasa['kasa_id']?.toString() ?? '') ?? 0;
    if (kasaId <= 0) return;
    final controller = TextEditingController(text: _kkLimit(kasa) == 0 ? '' : _kkLimit(kasa).toStringAsFixed(2));
    final kaydet = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('${_metin(kasa['kasa_adi'])} • K.K Limiti'),
      content: TextField(controller: controller, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))], decoration: const InputDecoration(labelText: 'Kredi Kartı Limiti', prefixIcon: Icon(Icons.credit_card_rounded), suffixText: '₺', border: OutlineInputBorder())),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')), FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.save_rounded), label: const Text('Kaydet'))],
    ));
    if (kaydet != true) { controller.dispose(); return; }
    final limit = double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0.0;
    controller.dispose();
    if (limit < 0) { _mesaj('Kredi kartı limiti negatif olamaz.', Colors.red); return; }
    try {
      await SupabaseService.supabase.from('kasalar').update({'kk_limit': limit}).eq('kasa_id', kasaId);
      if (!mounted) return;
      setState(() => kasa['kk_limit'] = limit);
      _mesaj('Kredi kartı limiti güncellendi.', Colors.green);
    } catch (e) { if (mounted) _mesaj('K.K limiti kaydedilemedi: $e', Colors.red); }
  }

"""
    if marker not in s:
        raise SystemExit('Pattern not found: kasa balance marker')
    s = s.replace(marker, helper + marker, 1)

if "'hareket_id': 'yeni'" not in s:
    s = must(s, "      if (!mounted) return;\n\n      _mesaj(\n        _islemTipi == 'TAHSILAT'", "      if (!mounted) return;\n\n      final yeniHareket = <String, dynamic>{\n        'hareket_id': 'yeni',\n        'tarih': _islemTarihi.toIso8601String(),\n        'kasa_id': kasaId,\n        'tip': _islemTipi == 'TAHSILAT' ? 'GIRIS' : 'CIKIS',\n        'tutar': tutar,\n        'aciklama': aciklama,\n        'cari_id': cariId,\n        'kullanici': YetkiService.aktifKullanici,\n        'belge_no': belgeNo,\n        'cari_unvan': _metin(cari['unvan']),\n        'kasa_adi': _metin(kasa['kasa_adi']),\n      };\n      setState(() { _tumHareketler = <Map<String, dynamic>>[yeniHareket, ..._tumHareketler]; });\n      _hareketleriFiltrele();\n\n      _mesaj(\n        _islemTipi == 'TAHSILAT'", 'instant kasa refresh')

s = s.replace("      await _ilkVerileriYukle();\n    } catch (e) {", "      await Future<void>.delayed(const Duration(milliseconds: 250));\n      await _ilkVerileriYukle();\n    } catch (e) {", 1)

if 'focusNode: _aramaFocusNode' not in s:
    s = must(s, "                          controller: _aramaController,\n                          decoration: InputDecoration(", "                          controller: _aramaController,\n                          focusNode: _aramaFocusNode,\n                          decoration: InputDecoration(", 'kasa search focus')

if 'K.K limitini düzenle' not in s:
    block = """                      Text(
                        _para(bakiye),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: bakiye >= 0 ? Colors.blue : Colors.red,
                        ),
                      ),"""
    extra = block + """
                      if (_krediKartiMi(kasa)) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          Expanded(child: Text(_kkLimit(kasa) > 0 ? 'Limit: ${_para(_kkLimit(kasa))} • Kalan: ${_para(_kkKalan(kasa))}' : 'K.K limiti tanımlanmadı', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kkLimit(kasa) > 0 ? Colors.green.shade700 : Colors.orange.shade700))),
                          IconButton(tooltip: 'K.K limitini düzenle', visualDensity: VisualDensity.compact, onPressed: () => _kkLimitDuzenle(kasa), icon: const Icon(Icons.edit_rounded, size: 17)),
                        ]),
                      ],"""
    s = must(s, block, extra, 'kasa limit card')

if 'return CallbackShortcuts(' not in s:
    s = must(s, "  @override\n  Widget build(BuildContext context) {\n    return Scaffold(", "  @override\n  Widget build(BuildContext context) {\n    return CallbackShortcuts(\n      bindings: <ShortcutActivator, VoidCallback>{\n        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () { _aramaFocusNode.requestFocus(); },\n      },\n      child: Focus(autofocus: true, child: Scaffold(", 'kasa shortcuts open')
    s = must(s, "                Expanded(child: _hareketListesi()),\n              ],\n            ),\n    );\n  }\n}", "                Expanded(child: _hareketListesi()),\n              ],\n            ),\n      )),\n    );\n  }\n}", 'kasa shortcuts close')

p.write_text(s, encoding='utf-8')

p = Path('lib/screens/dashboard_sayfasi.dart')
d = p.read_text(encoding='utf-8')
if "import 'package:flutter/services.dart';" not in d:
    d = d.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';", 1)
d = must(d, "  final TextEditingController _menuAramaController = TextEditingController();\n  final ScrollController _menuScrollController = ScrollController();", "  final TextEditingController _menuAramaController = TextEditingController();\n  final FocusNode _menuAramaFocusNode = FocusNode(debugLabel: 'erpMenuArama');\n  final ScrollController _menuScrollController = ScrollController();", 'dashboard focus node')
d = must(d, "    _menuAramaController.dispose();\n    _menuScrollController.dispose();", "    _menuAramaController.dispose();\n    _menuAramaFocusNode.dispose();\n    _menuScrollController.dispose();", 'dashboard focus dispose')
if 'focusNode: _menuAramaFocusNode' not in d:
    d = must(d, 'controller: _menuAramaController,', 'controller: _menuAramaController,\n                focusNode: _menuAramaFocusNode,', 'dashboard menu search focus')
if 'return CallbackShortcuts(' not in d[d.rfind('  @override\n  Widget build(BuildContext context) {'):]:
    d = must(d, "  @override\n  Widget build(BuildContext context) {\n    return LayoutBuilder(", "  @override\n  Widget build(BuildContext context) {\n    return CallbackShortcuts(\n      bindings: <ShortcutActivator, VoidCallback>{\n        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () { _menuAramaFocusNode.requestFocus(); },\n        const SingleActivator(LogicalKeyboardKey.escape): () { if (_seciliSayfa != 'dashboard') { setState(() => _seciliSayfa = 'dashboard'); } else { Navigator.of(context).maybePop(); } },\n      },\n      child: Focus(autofocus: true, child: LayoutBuilder(", 'dashboard shortcuts open')
    d = must(d, "      },\n    );\n  }\n}\n\nclass _AltMenuModel", "      },\n      )),\n    );\n  }\n}\n\nclass _AltMenuModel", 'dashboard shortcuts close')
p.write_text(d, encoding='utf-8')

sql = Path('supabase/PRO_ERP_FINANS_KK_LIMIT_2_5_31.sql')
sql.write_text("""-- PRO ERP 2.5.31 - Kredi kartı limit takibi
alter table if exists public.kasalar
  add column if not exists kk_limit numeric(14,2) not null default 0;

comment on column public.kasalar.kk_limit is
  'POS/Kredi kartı için tanımlı toplam limit.';

notify pgrst, 'reload schema';
""", encoding='utf-8')
