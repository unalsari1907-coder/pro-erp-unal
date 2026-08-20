import 'package:flutter/material.dart';

class AlisFooter extends StatelessWidget {
  final bool kaydediliyor;
  final VoidCallback onKaydet;
  final VoidCallback onTemizle;
  final VoidCallback onIptal;

  const AlisFooter({
    super.key,
    required this.kaydediliyor,
    required this.onKaydet,
    required this.onTemizle,
    required this.onIptal,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: kaydediliyor ? null : onTemizle,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Temizle'),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: kaydediliyor ? null : onIptal,
              icon: const Icon(Icons.close),
              label: const Text('İptal'),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: kaydediliyor ? null : onKaydet,
                icon: kaydediliyor
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  kaydediliyor
                      ? 'Kaydediliyor...'
                      : 'Alışı Kaydet',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}