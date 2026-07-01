String numberToArabicWords(int n) {
  if (n == 0) return 'صفر';

  const unitsMasc = ['', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة', 'عشرة'];
  const unitsFem = ['', 'واحدة', 'اثنتان', 'ثلاث', 'أربع', 'خمس', 'ست', 'سبع', 'ثمان', 'تسع', 'عشر'];
  const tensNames = ['', '', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون', 'تسعون'];
  const hundredsNames = ['', 'مائة', 'مائتان', 'ثلاثمائة', 'أربعمائة', 'خمسمائة', 'ستمائة', 'سبعمائة', 'ثمانمائة', 'تسعمائة'];

  String below100(int x, {bool feminine = false}) {
    if (x == 0) return '';
    if (x == 1) return feminine ? 'إحدى' : 'واحد';
    if (x == 2) return feminine ? 'اثنتان' : 'اثنان';
    if (x <= 10) return feminine ? unitsFem[x] : unitsMasc[x];
    if (x == 11) return feminine ? 'إحدى عشرة' : 'أحد عشر';
    if (x == 12) return feminine ? 'اثنتا عشرة' : 'اثنا عشر';
    if (x < 20) return '${unitsFem[x % 10]} عشرة';
    final u = x % 10;
    final t = x ~/ 10;
    if (u == 0) return tensNames[t];
    final uStr = u == 1 ? (feminine ? 'إحدى' : 'أحد') :
                u == 2 ? (feminine ? 'اثنتا' : 'اثنا') :
                (feminine ? unitsFem[u] : unitsMasc[u]);
    return '$uStr و${tensNames[t]}';
  }

  String below1000(int x, {bool feminine = false}) {
    final h = x ~/ 100;
    final r = x % 100;
    final parts = <String>[];
    if (h > 0) parts.add(hundredsNames[h]);
    if (r > 0) parts.add(below100(r, feminine: feminine));
    return parts.join(' و');
  }

  String suffix(int x) {
    if (x == 1) return 'ألف';
    if (x == 2) return 'ألفان';
    if (x <= 10) return 'آلاف';
    return 'ألف';
  }

  String build(int x) {
    final parts = <String>[];

    final millions = x ~/ 1000000;
    if (millions > 0) {
      x %= 1000000;
      if (millions == 1) {
        parts.add('مليون');
      } else if (millions == 2) {
        parts.add('مليونان');
      } else if (millions <= 10) {
        parts.add('${below1000(millions)} ملايين');
      } else {
        parts.add('${below1000(millions)} مليون');
      }
    }

    final thousands = x ~/ 1000;
    if (thousands > 0) {
      x %= 1000;
      final prefix = (thousands == 1 || thousands == 2) ? '' : below1000(thousands);
      parts.add('$prefix ${suffix(thousands)}'.trim());
    }

    if (x > 0) {
      parts.add(below1000(x));
    }

    if (parts.isEmpty) return 'صفر';
    return parts.join(' و');
  }

  return build(n);
}
