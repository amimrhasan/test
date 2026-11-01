// lib/widgets/tactile_widgets.dart
// অনুশীলন (Onushilon) — 3D Tactile Cards, Buttons, Math/Fraction/Matrix/SVG Renderer & Visual Banners

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../data/syllabus_data.dart';
import '../models/app_models.dart';

class AppPalette {
  final bool isDark;
  const AppPalette(this.isDark);

  Color get primary => isDark ? const Color(0xFF2DD484) : const Color(0xFF07884B);
  Color get primaryDark => isDark ? const Color(0xFF10B968) : const Color(0xFF05663A);
  Color get primary3d => isDark ? const Color(0xFF138A50) : const Color(0xFF04522E);
  Color get primarySoft => isDark ? const Color(0xFF142E22) : const Color(0xFFE3F4EC);
  Color get primarySoft3d => isDark ? const Color(0xFF0D2118) : const Color(0xFFB5DFC9);

  Color get bg => isDark ? const Color(0xFF0A100D) : const Color(0xFFF2F6F4);
  Color get card => isDark ? const Color(0xFF121B16) : const Color(0xFFFFFFFF);
  Color get cardAlt => isDark ? const Color(0xFF17231D) : const Color(0xFFF8FBF9);
  Color get text => isDark ? const Color(0xFFECF5F0) : const Color(0xFF16221B);
  Color get muted => isDark ? const Color(0xFF8FA397) : const Color(0xFF5F7066);
  Color get border => isDark ? const Color(0xFF223229) : const Color(0xFFDBE5DF);
  Color get border3d => isDark ? const Color(0xFF16221B) : const Color(0xFFC1D0C7);

  Color get red => isDark ? const Color(0xFFFB7185) : const Color(0xFFD93645);
  Color get redSoft => isDark ? const Color(0xFF2D161B) : const Color(0xFFFFF0F1);
  Color get redSoft3d => isDark ? const Color(0xFF1F0E12) : const Color(0xFFF5C2C7);

  Color get amber => isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
  Color get amberSoft => isDark ? const Color(0xFF2B210E) : const Color(0xFFFFFBEB);

  Color get blue => isDark ? const Color(0xFF38BDF8) : const Color(0xFF1D8CF8);
  Color get blue3d => isDark ? const Color(0xFF0284C7) : const Color(0xFF0B65C6);
  Color get blueSoft => isDark ? const Color(0xFF112638) : const Color(0xFFEFF6FF);

  Color get purple => isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
  Color get onPrimary => isDark ? const Color(0xFF042012) : Colors.white;
}

class TactileCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? bgColor;
  final Color? borderColor;
  final Color? bottomBorderColor;
  final double bottomDepth;
  final VoidCallback? onTap;

  const TactileCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = 20,
    this.bgColor,
    this.borderColor,
    this.bottomBorderColor,
    this.bottomDepth = 4.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pal = AppPalette(isDark);
    final bg = bgColor ?? pal.card;
    final bCol = borderColor ?? pal.border;
    final b3d = bottomBorderColor ?? pal.border3d;

    final box = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: b3d,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.35) : const Color(0x0F0F2A1C),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.only(bottom: bottomDepth),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: bCol, width: 1.5),
        ),
        child: child,
      ),
    );

    if (onTap == null) return box;
    return GestureDetector(onTap: onTap, child: box);
  }
}

enum TactileBtnVariant { primary, secondary, ghost, danger }

class TactileButton extends StatelessWidget {
  final String label;
  final Widget? icon;
  final VoidCallback? onPressed;
  final TactileBtnVariant variant;
  final bool isSmall;
  final bool isBlock;

  const TactileButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = TactileBtnVariant.primary,
    this.isSmall = false,
    this.isBlock = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pal = AppPalette(isDark);

    Color bg;
    Color border;
    Color bottom3d;
    Color fg;

    switch (variant) {
      case TactileBtnVariant.primary:
        bg = pal.primary;
        border = pal.primary3d;
        bottom3d = pal.primary3d;
        fg = pal.onPrimary;
        break;
      case TactileBtnVariant.secondary:
        bg = pal.primarySoft;
        border = pal.primarySoft3d;
        bottom3d = pal.primarySoft3d;
        fg = pal.primary;
        break;
      case TactileBtnVariant.danger:
        bg = pal.redSoft;
        border = pal.redSoft3d;
        bottom3d = pal.redSoft3d;
        fg = pal.red;
        break;
      case TactileBtnVariant.ghost:
        bg = pal.card;
        border = pal.border;
        bottom3d = pal.border3d;
        fg = pal.text;
        break;
    }

    final content = Row(
      mainAxisSize: isBlock ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          IconTheme(data: IconThemeData(color: fg, size: isSmall ? 15 : 18), child: icon!),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: isSmall ? 12.5 : 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );

    return Opacity(
      opacity: onPressed == null ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: isBlock ? double.infinity : null,
          decoration: BoxDecoration(
            color: bottom3d,
            borderRadius: BorderRadius.circular(isSmall ? 11 : 14),
          ),
          padding: EdgeInsets.only(bottom: isSmall ? 2.5 : 3.5),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 12 : 16,
              vertical: isSmall ? 6 : 10,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(isSmall ? 11 : 14),
              border: Border.all(color: border, width: 1.4),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

// Subject & Chapter 16:9 Visual Banner Widget matching HTML SVG Artwork
class SubjectArtBanner extends StatelessWidget {
  final SubjectItem subject;
  final String topBadge;
  final String rightBadge;

  const SubjectArtBanner({
    super.key,
    required this.subject,
    required this.topBadge,
    required this.rightBadge,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pal = AppPalette(isDark);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(subject.color1), Color(subject.color2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            if (subject.thumb.trim().isNotEmpty && subject.thumb.startsWith('http'))
              Positioned.fill(
                child: Image.network(
                  subject.thumb.trim(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            // Decorative circle & symbol
            Positioned(
              right: 22,
              top: 26,
              child: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.14),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    subject.symbol,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            // Formula & Bottom label
            Positioned(
              left: 16,
              top: 48,
              right: 112,
              child: Text(
                subject.formula,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 14,
              right: 16,
              child: Text(
                subject.bottomLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            // Top Left Badge
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xD10A120E),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  topBadge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            // Top Right Badge
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: pal.primary,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  rightBadge,
                  style: TextStyle(
                    color: pal.onPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
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

// Rich Math, Science, Chemical Subscripts, Superscripts, Fractions & Matrices Text Widget
class MathScienceText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const MathScienceText(
    this.text, {
    super.key,
    this.style,
  });

  static String normalizeMathSymbols(String input) {
    if (input.isEmpty) return '';
    var s = input;
    const latexMap = {
      r'\alpha': 'α',
      r'\beta': 'β',
      r'\gamma': 'γ',
      r'\delta': 'δ',
      r'\Delta': 'Δ',
      r'\epsilon': 'ϵ',
      r'\varepsilon': 'ε',
      r'\zeta': 'ζ',
      r'\eta': 'η',
      r'\theta': 'θ',
      r'\Theta': 'Θ',
      r'\lambda': 'λ',
      r'\Lambda': 'Λ',
      r'\mu': 'μ',
      r'\nu': 'ν',
      r'\xi': 'ξ',
      r'\pi': 'π',
      r'\Pi': 'Π',
      r'\rho': 'ρ',
      r'\sigma': 'σ',
      r'\Sigma': 'Σ',
      r'\tau': 'τ',
      r'\phi': 'ϕ',
      r'\varphi': 'φ',
      r'\Phi': 'Φ',
      r'\chi': 'χ',
      r'\psi': 'ψ',
      r'\Psi': 'Ψ',
      r'\omega': 'ω',
      r'\Omega': 'Ω',
      r'\infty': '∞',
      r'\pm': '±',
      r'\mp': '∓',
      r'\times': '×',
      r'\div': '÷',
      r'\cdot': '·',
      r'\neq': '≠',
      r'\ne': '≠',
      r'\leq': '≤',
      r'\le': '≤',
      r'\geq': '≥',
      r'\ge': '≥',
      r'\approx': '≈',
      r'\equiv': '≡',
      r'\propto': '∝',
      r'\perp': '⊥',
      r'\parallel': '∥',
      r'\angle': '∠',
      r'\triangle': '△',
      r'\rightarrow': '→',
      r'\to': '→',
      r'\leftarrow': '←',
      r'\leftrightarrow': '⇌',
      r'\Rightarrow': '⇒',
      r'\Leftrightarrow': '⇔',
      r'\forall': '∀',
      r'\exists': '∃',
      r'\in': '∈',
      r'\notin': '∉',
      r'\subset': '⊂',
      r'\subseteq': '⊆',
      r'\cup': '∪',
      r'\cap': '∩',
      r'\emptyset': '∅',
      r'\nabla': '∇',
      r'\partial': '∂',
      r'\int': '∫',
      r'\sum': '∑',
      r'\prod': '∏',
      r'\degree': '°',
      r'\circ': '°',
    };
    latexMap.forEach((k, v) {
      s = s.replaceAll(k, v);
    });
    // Strip $$ and $ wrappers
    s = s.replaceAll('$$', '').replaceAll('$', '');
    // Convert \hat{i} -> î, \vec{A} -> A⃗
    s = s.replaceAllMapped(RegExp(r'\\hat\{([a-zA-Z0-9]+)\}'), (m) => '${m[1]}̂');
    s = s.replaceAllMapped(RegExp(r'\\vec\{([a-zA-Z0-9]+)\}'), (m) => '${m[1]}⃗');
    // Convert \sqrt{...} -> √(...)
    s = s.replaceAllMapped(RegExp(r'\\sqrt\{([^}]+)\}'), (m) => '√(${m[1]})');
    // Convert \frac{a}{b} -> (a)/(b)
    s = s.replaceAllMapped(
        RegExp(r'\\d?frac\{([^}]+)\}\{([^}]+)\}'), (m) => '(${m[1]})/(${m[2]})');
    // Convert common superscripts ^2, ^3, ^n
    const supDigits = {
      '0': '⁰',
      '1': '¹',
      '2': '²',
      '3': '³',
      '4': '⁴',
      '5': '⁵',
      '6': '⁶',
      '7': '⁷',
      '8': '⁸',
      '9': '⁹',
      '+': '⁺',
      '-': '⁻',
      'n': 'ⁿ',
    };
    s = s.replaceAllMapped(RegExp(r'\^\{?([0-9+-n]+)\}?'), (m) {
      final raw = m[1] ?? '';
      return raw.split('').map((ch) => supDigits[ch] ?? ch).join();
    });
    // Convert common chemical formulas H2O, CO2, H2SO4
    const subDigits = {
      '0': '₀',
      '1': '₁',
      '2': '₂',
      '3': '₃',
      '4': '₄',
      '5': '₅',
      '6': '₆',
      '7': '₇',
      '8': '₈',
      '9': '₉',
    };
    s = s.replaceAllMapped(RegExp(r'_\{?([0-9]+)\}?'), (m) {
      final raw = m[1] ?? '';
      return raw.split('').map((ch) => subDigits[ch] ?? ch).join();
    });
    s = s.replaceAllMapped(
      RegExp(
          r'\b(H2O|CO2|SO2|SO3|NO2|NH3|CH4|O2|N2|H2|Cl2|H2SO4|HNO3|HCl|H3PO4|Na2CO3|NaHCO3|CaCO3|Al2O3|Fe2O3|Fe3O4|C6H12O6|C2H5OH|C6H6)\b'),
      (m) {
        final raw = m[1] ?? '';
        return raw.replaceAllMapped(RegExp(r'\d'), (dm) => subDigits[dm[0]] ?? dm[0]!);
      },
    );
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final formatted = normalizeMathSymbols(text);
    return Text(
      formatted,
      style: style ??
          TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            height: 1.5,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
    );
  }
}

// Question SVG / Image Media Box with Tap-to-Zoom
class QuestionMediaView extends StatelessWidget {
  final String rawMedia;
  const QuestionMediaView({super.key, required this.rawMedia});

  @override
  Widget build(BuildContext context) {
    final trimmed = rawMedia.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pal = AppPalette(isDark);

    Widget mediaChild;
    if (trimmed.startsWith('<svg') || trimmed.contains('<svg')) {
      final cleanSvg = trimmed.replaceAll(RegExp(r'<script[\s\S]*?>[\s\S]*?</script>', caseSensitive: false), '');
      mediaChild = SvgPicture.string(
        cleanSvg,
        height: 165,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      );
    } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      mediaChild = Image.network(
        trimmed,
        height: 180,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pal.cardAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.border, width: 1.5),
      ),
      alignment: Alignment.center,
      child: mediaChild,
    );
  }
}

// Reference Pill (Shown ONLY below Question, matching Requirement 9 & 16)
class ReferenceBadgePill extends StatelessWidget {
  final String reference;
  const ReferenceBadgePill({super.key, required this.reference});

  @override
  Widget build(BuildContext context) {
    final clean = reference
        .trim()
        .replaceFirst(RegExp(r'^(?:রেফারেন্স|reference)\s*[:：-]\s*', caseSensitive: false), '')
        .trim();
    if (clean.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pal = AppPalette(isDark);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: pal.amberSoft,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: pal.amber.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.layers_outlined, size: 14, color: pal.amber),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                MathScienceText.normalizeMathSymbols(clean),
                style: TextStyle(
                  color: pal.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Source Pill (Shown ONLY inside Explanation, matching Requirement 9 & 16)
class SourceBadgePill extends StatelessWidget {
  final String source;
  const SourceBadgePill({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    final clean = source.trim();
    if (clean.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pal = AppPalette(isDark);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: pal.blueSoft,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: pal.blue.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 14, color: pal.blue),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                clean,
                style: TextStyle(
                  color: pal.blue,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
