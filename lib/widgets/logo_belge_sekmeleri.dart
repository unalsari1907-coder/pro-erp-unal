import 'package:flutter/material.dart';

class LogoBelgeSekmeleri extends StatelessWidget {
  final String baslik;
  final String? belgeNo;
  final bool alis;

  const LogoBelgeSekmeleri({
    super.key,
    required this.baslik,
    this.belgeNo,
    this.alis = false,
  });

  @override
  Widget build(BuildContext context) {
    final vurgu = alis
        ? const Color(0xFF667FA3)
        : const Color(0xFF7869BC);

    return Container(
      margin: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD4D4DA)),
      ),
      child: Column(
        children: [
          Container(
            height: 27,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: vurgu,
            child: Row(
              children: [
                const Icon(Icons.description_outlined, size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    (belgeNo == null || belgeNo!.trim().isEmpty)
                        ? baslik
                        : '$baslik - ${belgeNo!.trim()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 27,
            child: Row(
              children: [
                _sekme('İrsaliye', true, vurgu),
                _sekme('Detaylar', false, vurgu),
                _sekme('Detaylar II', false, vurgu),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sekme(String text, bool selected, Color vurgu) {
    return Container(
      height: 27,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: selected ? vurgu.withOpacity(0.11) : Colors.white,
        border: Border(
          right: const BorderSide(color: Color(0xFFD4D4DA)),
          bottom: BorderSide(
            color: selected ? vurgu : const Color(0xFFD4D4DA),
            width: selected ? 2 : 1,
          ),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          color: selected ? vurgu : const Color(0xFF4F4F58),
        ),
      ),
    );
  }
}
