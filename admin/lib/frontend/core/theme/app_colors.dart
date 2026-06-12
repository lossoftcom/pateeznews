import 'package:flutter/material.dart';

/// Pateeznews mobil önyüz renk sistemi.
///
/// Palet markanın "Derin Okyanus, Güçlü Kırmızı, Sıcak Ufuk" temasına dayanır.
/// Renkler düz uygulanmaz; psikolojik etkiye göre ana, vurgu, yüzey, kenar,
/// metin ve ikon rolleri için ton türevleri tanımlanır.
class AppColors {
  const AppColors._();

  // -- Ana palet
  static const deepOcean = Color(0xFF2C3E50);
  static const surfaceTinted = Color(0xFFF8F9FA);
  static const actionRed = Color(0xFFEA4335);
  static const warmHorizon = Color(0xFFF39C12);
  static const supportCool = Color(0xFF95A5A6);

  // -- Yüzeyler
  static const canvas = Color(0xFFF2F4F7); // sayfa zemini, sosyal feed grisi
  static const surface = Color(0xFFFFFFFF); // kart yüzeyi
  static const surfaceSoft = Color(0xFFF7F8FA); // ikinci seviye yüzey
  static const surfaceInk = Color(0xFFF1F3F5); // chip / button arka planı

  // -- Çizgi ve gölge
  static const line = Color(0xFFE6ECEE);
  static const softLine = Color(0xFFF0F3F4);
  static const shadow = Color(0x14101828);

  // -- Metin
  static const ink = Color(
    0xFF1B2A37,
  ); // ana metin, deep ocean'ın okunaklı varyantı
  static const inkStrong = Color(0xFF0F1B26); // featured başlıklar
  static const inkSoft = Color(0xFF536270); // ikinci metin
  static const support = Color(0xFF8A949B); // meta, zaman
  static const placeholder = Color(0xFFA1AAAD);
  static const placeholderSoft = Color(0xFFB6BFC4);

  // -- İkonografi
  static const iconStrong = Color(0xFF2C3E50);
  static const iconMuted = Color(0xFF8A949B);

  // -- Vurgu (kısıtlı kullanım)
  static const accentAction = actionRed; // canlı, breaking, kritik CTA
  static const accentWarm = warmHorizon; // öne çıkan etiket, sıcak vurgu

  // -- Overlay'ler (görsel üzeri okunabilirlik için)
  static const overlayBottomStart = Color(0x00000000);
  static const overlayBottomEnd = Color(0xB3000000);
  static const overlayTopStart = Color(0x66000000);
  static const overlayTopEnd = Color(0x00000000);
}
