import 'package:flutter/material.dart';

class AdBanner extends StatelessWidget {
  const AdBanner({super.key});

  static const _ads = [
    _AdData('خصم 20%', 'على جميع الحجوزات في ملاعب البندر', '🏟️', Color(0xFF6A1B9A)),
    _AdData('عرض الجمعة', 'احجز ملعبين واحصل على الثالث مجاناً', '⚡', Color(0xFFC62828)),
    _AdData('بطولة رمضان', 'سجل الآن في بطولة رمضان لكرة القدم', '🏆', Color(0xFF00695C)),
    _AdData('عرض الصباح', 'خصم 15% للحجوزات قبل الساعة 10 صباحاً', '🌅', Color(0xFFE65100)),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: PageView.builder(
        itemCount: _ads.length,
        itemBuilder: (_, i) => _AdCard(ad: _ads[i]),
      ),
    );
  }
}

class _AdData {
  final String title;
  final String description;
  final String emoji;
  final Color color;
  const _AdData(this.title, this.description, this.emoji, this.color);
}

class _AdCard extends StatelessWidget {
  final _AdData ad;
  const _AdCard({required this.ad});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [ad.color, ad.color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: ad.color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('ممول',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(ad.title,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(ad.description,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(ad.emoji, style: const TextStyle(fontSize: 44)),
          ],
        ),
      ),
    );
  }
}
