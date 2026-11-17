import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VORTEXA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const AnaEkran(),
    );
  }
}

// =====================================================================
// KATEGORİLER
// İşlemlere kategori eklendi, Analiz sayfasındaki kategori dağılımı
// grafiği (donut chart) bu listeden besleniyor.
// =====================================================================

const List<Map<String, dynamic>> kategoriListesi = [
  {"ad": "Yemek & Restoran", "ikon": Icons.restaurant_outlined, "renk": Color(0xFF1B5E20)},
  {"ad": "Alışveriş", "ikon": Icons.shopping_cart_outlined, "renk": Color(0xFF66BB6A)},
  {"ad": "Ulaşım", "ikon": Icons.directions_car_outlined, "renk": Color(0xFFE53935)},
  {"ad": "Faturalar", "ikon": Icons.receipt_outlined, "renk": Color(0xFFFFA726)},
  {"ad": "Maaş", "ikon": Icons.payments_outlined, "renk": Color(0xFF2E7D32)},
  {"ad": "Diğer", "ikon": Icons.more_horiz, "renk": Color(0xFF7E57C2)},
];

IconData kategoriIkon(String ad) =>
    kategoriListesi.firstWhere((e) => e["ad"] == ad, orElse: () => kategoriListesi.last)["ikon"] as IconData;

Color kategoriRenk(String ad) =>
    kategoriListesi.firstWhere((e) => e["ad"] == ad, orElse: () => kategoriListesi.last)["renk"] as Color;

// =====================================================================
// VERİ MODELLERİ
// Tüm veriler JSON olarak saklanıyor (pipe "|" ile birleştirme kırılgan
// olduğu için terk edildi). IslemKaydi artık "kategori" ve "tarih" de
// tutuyor — Analiz sayfasındaki trend grafiği ve kategori dağılımı
// bunlara ihtiyaç duyuyor.
// =====================================================================

class IslemKaydi {
  final String id;
  String baslik;
  double miktar;
  String tur; // "Gelir" ya da "Gider"
  String kategori;
  DateTime tarih;

  IslemKaydi({
    required this.baslik,
    required this.miktar,
    required this.tur,
    this.kategori = "Diğer",
    DateTime? tarih,
  })  : id = DateTime.now().microsecondsSinceEpoch.toString(),
        tarih = tarih ?? DateTime.now();

  IslemKaydi._raw({
    required this.id,
    required this.baslik,
    required this.miktar,
    required this.tur,
    required this.kategori,
    required this.tarih,
  });

  Map<String, dynamic> toJson() => {
    "id": id,
    "baslik": baslik,
    "miktar": miktar,
    "tur": tur,
    "kategori": kategori,
    "tarih": tarih.toIso8601String(),
  };

  factory IslemKaydi.fromJson(Map<String, dynamic> json) => IslemKaydi._raw(
    id: json["id"]?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
    baslik: json["baslik"]?.toString() ?? "",
    miktar: (json["miktar"] as num?)?.toDouble() ?? 0.0,
    tur: json["tur"]?.toString() ?? "Gider",
    // Eski kayıtlarda kategori/tarih olmayabilir, güvenli varsayılan atanıyor.
    kategori: json["kategori"]?.toString() ?? "Diğer",
    tarih: DateTime.tryParse(json["tarih"]?.toString() ?? "") ?? DateTime.now(),
  );
}

class YaziNotu {
  final String id;
  String baslik;
  String icerik;

  YaziNotu({required this.baslik, required this.icerik}) : id = DateTime.now().microsecondsSinceEpoch.toString();

  YaziNotu._raw({required this.id, required this.baslik, required this.icerik});

  Map<String, dynamic> toJson() => {"id": id, "baslik": baslik, "icerik": icerik};

  factory YaziNotu.fromJson(Map<String, dynamic> json) => YaziNotu._raw(
    id: json["id"]?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
    baslik: json["baslik"]?.toString() ?? "",
    icerik: json["icerik"]?.toString() ?? "",
  );
}

class Hatirlatici {
  final String id;
  String baslik;
  String icerik;
  DateTime tarih;

  Hatirlatici({required this.baslik, required this.icerik, required this.tarih})
      : id = DateTime.now().microsecondsSinceEpoch.toString();

  Hatirlatici._raw({required this.id, required this.baslik, required this.icerik, required this.tarih});

  Map<String, dynamic> toJson() => {"id": id, "baslik": baslik, "icerik": icerik, "tarih": tarih.toIso8601String()};

  factory Hatirlatici.fromJson(Map<String, dynamic> json) => Hatirlatici._raw(
    id: json["id"]?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
    baslik: json["baslik"]?.toString() ?? "",
    icerik: json["icerik"]?.toString() ?? "",
    tarih: DateTime.tryParse(json["tarih"]?.toString() ?? "") ?? DateTime.now(),
  );
}

// =====================================================================
// DEPOLAMA SERVİSİ
// =====================================================================

class DepoServisi {
  static const _islemlerKey = 'vortexa_islemler';
  static const _notlarKey = 'vortexa_notlar';
  static const _hatirlaticilarKey = 'vortexa_hatirlaticilar';
  static const _butceKey = 'vortexa_aylik_butce';

  Future<List<IslemKaydi>> islemleriYukle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_islemlerKey);
      if (raw == null || raw.isEmpty) return [];
      final liste = jsonDecode(raw) as List;
      return liste.map((e) => IslemKaydi.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint("İşlemler yüklenemedi: $e");
      return [];
    }
  }

  Future<bool> islemleriKaydet(List<IslemKaydi> islemler) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(islemler.map((e) => e.toJson()).toList());
      return await prefs.setString(_islemlerKey, raw);
    } catch (e) {
      debugPrint("İşlemler kaydedilemedi: $e");
      return false;
    }
  }

  Future<List<YaziNotu>> notlariYukle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_notlarKey);
      if (raw == null || raw.isEmpty) return [];
      final liste = jsonDecode(raw) as List;
      return liste.map((e) => YaziNotu.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint("Notlar yüklenemedi: $e");
      return [];
    }
  }

  Future<bool> notlariKaydet(List<YaziNotu> notlar) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(notlar.map((e) => e.toJson()).toList());
      return await prefs.setString(_notlarKey, raw);
    } catch (e) {
      debugPrint("Notlar kaydedilemedi: $e");
      return false;
    }
  }

  Future<List<Hatirlatici>> hatirlaticilariYukle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_hatirlaticilarKey);
      if (raw == null || raw.isEmpty) return [];
      final liste = jsonDecode(raw) as List;
      return liste.map((e) => Hatirlatici.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint("Hatırlatıcılar yüklenemedi: $e");
      return [];
    }
  }

  Future<bool> hatirlaticilariKaydet(List<Hatirlatici> hatirlaticilar) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(hatirlaticilar.map((e) => e.toJson()).toList());
      return await prefs.setString(_hatirlaticilarKey, raw);
    } catch (e) {
      debugPrint("Hatırlatıcılar kaydedilemedi: $e");
      return false;
    }
  }

  Future<double?> butceYukle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_butceKey);
    } catch (e) {
      debugPrint("Bütçe yüklenemedi: $e");
      return null;
    }
  }

  Future<bool> butceKaydet(double tutar) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setDouble(_butceKey, tutar);
    } catch (e) {
      debugPrint("Bütçe kaydedilemedi: $e");
      return false;
    }
  }
}

class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key});

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> with SingleTickerProviderStateMixin {
  final DepoServisi _depo = DepoServisi();

  int _seciliIndeks = 0;
  late TabController _notlarTabController;
  bool _yukleniyor = true;

  List<IslemKaydi> _islemler = [];
  List<YaziNotu> _duzYaziNotlari = [];
  List<Hatirlatici> _hatirlaticilar = [];
  double? _aylikButce;

  double get _toplamGelir => _islemler.where((e) => e.tur == "Gelir").fold(0.0, (t, e) => t + e.miktar);
  double get _toplamGider => _islemler.where((e) => e.tur == "Gider").fold(0.0, (t, e) => t + e.miktar);

  @override
  void initState() {
    super.initState();
    _notlarTabController = TabController(length: 2, vsync: this);
    _verileriYukle();
  }

  @override
  void dispose() {
    _notlarTabController.dispose();
    super.dispose();
  }

  Future<void> _verileriYukle() async {
    final islemler = await _depo.islemleriYukle();
    final notlar = await _depo.notlariYukle();
    final hatirlaticilar = await _depo.hatirlaticilariYukle();
    final butce = await _depo.butceYukle();
    if (!mounted) return;
    setState(() {
      _islemler = islemler;
      _duzYaziNotlari = notlar;
      _hatirlaticilar = hatirlaticilar;
      _aylikButce = butce;
      _yukleniyor = false;
    });
  }

  void _bildirimGoster(String mesaj, {bool hata = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: hata ? Colors.red.shade600 : Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ================= İŞLEM (GELİR/GİDER) =================

  Future<void> _islemEkle(String baslik, double miktar, String tur, String kategori) async {
    setState(() => _islemler.add(IslemKaydi(baslik: baslik, miktar: miktar, tur: tur, kategori: kategori)));
    final basarili = await _depo.islemleriKaydet(_islemler);
    _bildirimGoster(basarili ? "İşlem kaydedildi." : "Kaydedilemedi, tekrar deneyin.", hata: !basarili);
  }

  Future<void> _islemSil(int index) async {
    final silinen = _islemler[index];
    setState(() => _islemler.removeAt(index));
    final basarili = await _depo.islemleriKaydet(_islemler);
    if (!basarili) {
      setState(() => _islemler.insert(index, silinen));
      _bildirimGoster("Silinemedi, tekrar deneyin.", hata: true);
    }
  }

  // ================= DÜZ YAZI NOTU =================

  Future<void> _duzNotEkle(String baslik, String icerik) async {
    setState(() => _duzYaziNotlari.add(YaziNotu(baslik: baslik, icerik: icerik)));
    final basarili = await _depo.notlariKaydet(_duzYaziNotlari);
    _bildirimGoster(basarili ? "Not kaydedildi." : "Kaydedilemedi, tekrar deneyin.", hata: !basarili);
  }

  Future<void> _duzNotSil(int index) async {
    final silinen = _duzYaziNotlari[index];
    setState(() => _duzYaziNotlari.removeAt(index));
    final basarili = await _depo.notlariKaydet(_duzYaziNotlari);
    if (!basarili) {
      setState(() => _duzYaziNotlari.insert(index, silinen));
      _bildirimGoster("Silinemedi, tekrar deneyin.", hata: true);
    }
  }

  // ================= HATIRLATICI =================

  Future<void> _hatirlaticiEkle(String baslik, String icerik, DateTime tarih) async {
    setState(() => _hatirlaticilar.add(Hatirlatici(baslik: baslik, icerik: icerik, tarih: tarih)));
    final basarili = await _depo.hatirlaticilariKaydet(_hatirlaticilar);
    _bildirimGoster(basarili ? "Hatırlatıcı kuruldu." : "Kaydedilemedi, tekrar deneyin.", hata: !basarili);
  }

  Future<void> _hatirlaticiSil(int index) async {
    final silinen = _hatirlaticilar[index];
    setState(() => _hatirlaticilar.removeAt(index));
    final basarili = await _depo.hatirlaticilariKaydet(_hatirlaticilar);
    if (!basarili) {
      setState(() => _hatirlaticilar.insert(index, silinen));
      _bildirimGoster("Silinemedi, tekrar deneyin.", hata: true);
    }
  }

  // ================= BÜTÇE =================

  Future<void> _butceGuncelle(double tutar) async {
    setState(() => _aylikButce = tutar);
    final basarili = await _depo.butceKaydet(tutar);
    _bildirimGoster(basarili ? "Bütçe güncellendi." : "Kaydedilemedi, tekrar deneyin.", hata: !basarili);
  }

  void _sayfaDegistir(int index) {
    setState(() => _seciliIndeks = index);
  }

  // ================= PENCERE (DIALOG) MODAL KONTROLLERİ =================

  void _islemPencerisiniAc() {
    final baslikController = TextEditingController();
    final miktarController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String tur = "Gelir";
    String kategori = "Diğer";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Yeni Bütçe / Hesap Notu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: baslikController,
                  decoration: const InputDecoration(labelText: "Başlık"),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Başlık boş olamaz" : null,
                ),
                TextFormField(
                  controller: miktarController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: "Miktar (₺)", hintText: "örn: 150.50"),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Miktar boş olamaz";
                    final sayi = double.tryParse(v.trim().replaceAll(',', '.'));
                    if (sayi == null) return "Geçerli bir sayı girin";
                    if (sayi <= 0) return "Miktar 0'dan büyük olmalı";
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: kategori,
                  decoration: const InputDecoration(labelText: "Kategori"),
                  items: kategoriListesi
                      .map((k) => DropdownMenuItem<String>(
                    value: k["ad"] as String,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(k["ikon"] as IconData, size: 18, color: k["renk"] as Color),
                        const SizedBox(width: 8),
                        Text(k["ad"] as String),
                      ],
                    ),
                  ))
                      .toList(),
                  onChanged: (deger) => setModalState(() => kategori = deger!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Gelir"),
                        value: "Gelir",
                        groupValue: tur,
                        onChanged: (deger) => setModalState(() => tur = deger!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Gider"),
                        value: "Gider",
                        groupValue: tur,
                        onChanged: (deger) => setModalState(() => tur = deger!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      final miktar = double.parse(miktarController.text.trim().replaceAll(',', '.'));
                      Navigator.pop(ctx);
                      _islemEkle(baslikController.text.trim(), miktar, tur, kategori);
                    },
                    child: const Text("Kaydet"),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _duzNotPencerisiniAc() {
    final baslikController = TextEditingController();
    final icerikController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Yeni Yazı Notu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextFormField(
                controller: baslikController,
                decoration: const InputDecoration(labelText: "Not Başlığı"),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Başlık boş olamaz" : null,
              ),
              TextFormField(
                controller: icerikController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Not İçeriği"),
                validator: (v) => (v == null || v.trim().isEmpty) ? "İçerik boş olamaz" : null,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(ctx);
                    _duzNotEkle(baslikController.text.trim(), icerikController.text.trim());
                  },
                  child: const Text("Notu Sakla"),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _hatirlaticiPenceresiniAc() {
    final baslikController = TextEditingController();
    final icerikController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime? secilenTarih;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Akıllı Hatırlatıcı Kur", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextFormField(
                  controller: baslikController,
                  decoration: const InputDecoration(labelText: "Hatırlatma Başlığı"),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Başlık boş olamaz" : null,
                ),
                TextFormField(
                  controller: icerikController,
                  decoration: const InputDecoration(labelText: "Kısa Açıklama"),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Açıklama boş olamaz" : null,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        secilenTarih == null
                            ? "Tarih Seçilmedi"
                            : "Seçilen: ${secilenTarih!.day}/${secilenTarih!.month}/${secilenTarih!.year}",
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final t = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (t != null) setModalState(() => secilenTarih = t);
                      },
                      child: const Text("Tarih Seç"),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      if (secilenTarih == null) {
                        setModalState(() {});
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text("Lütfen 'Tarih Seç' ile bir tarih belirleyin.")),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      _hatirlaticiEkle(baslikController.text.trim(), icerikController.text.trim(), secilenTarih!);
                    },
                    child: const Text("Hatırlatıcıyı Kur"),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _butcePencerisiniAc() {
    final controller = TextEditingController(text: _aylikButce != null ? _aylikButce!.toStringAsFixed(0) : "");
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Aylık Bütçe Belirle", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: "Aylık Bütçe (₺)"),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Tutar boş olamaz";
                  final s = double.tryParse(v.trim().replaceAll(',', '.'));
                  if (s == null || s <= 0) return "Geçerli bir tutar girin";
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    final tutar = double.parse(controller.text.trim().replaceAll(',', '.'));
                    Navigator.pop(ctx);
                    _butceGuncelle(tutar);
                  },
                  child: const Text("Kaydet"),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ================= 1. SAYFA: ANA SAYFA =================
  Widget _anaSayfaIcerigi(double bakiye, double grafikOrani) {
    final suAn = DateTime.now();
    final bugunGunu = DateTime(suAn.year, suAn.month, suAn.day);

    // DÜZELTME/YENİ ÖZELLİK: Bakiye eksiye düşünce kart kırmızıya,
    // artıdayken (veya sıfırken) yeşile dönüyor.
    final bakiyeRengi = bakiye < 0 ? const Color(0xFFC62828) : const Color(0xFF1B5E20);

    List<Hatirlatici> anaEkranListesi = List.from(_hatirlaticilar)..sort((a, b) => a.tarih.compareTo(b.tarih));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: bakiyeRengi, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Toplam Bakiye", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    if (bakiye < 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                        child: const Text("Bütçe Açığı", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text("₺${bakiye.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const Divider(color: Colors.white24, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _bakiyeOgesi("Gelir", "₺${_toplamGelir.toStringAsFixed(2)}"),
                    _bakiyeOgesi("Gider", "₺${_toplamGider.toStringAsFixed(2)}"),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text("Hızlı Bakış (Grafik)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: grafikOrani,
                          strokeWidth: 12,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade400),
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ),
                      Text("%${(grafikOrani * 100).toStringAsFixed(0)}\nGider", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      children: [
                        _grafikLejanti(Colors.orange.shade400, "Toplam Harcamalar"),
                        const SizedBox(height: 8),
                        _grafikLejanti(Colors.green.shade400, "Kalan Bütçe Payı"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text("🔔 Yaklaşan Hatırlatıcılar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          anaEkranListesi.isEmpty
              ? Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Center(
              child: Text("Aktif bir hatırlatıcı bulunmuyor kanka.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
            ),
          )
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: anaEkranListesi.length,
            itemBuilder: (context, index) {
              final h = anaEkranListesi[index];
              final hedefGunu = DateTime(h.tarih.year, h.tarih.month, h.tarih.day);
              final kalanGun = hedefGunu.difference(bugunGunu).inDays;
              final tEkran = "${h.tarih.day.toString().padLeft(2, '0')}.${h.tarih.month.toString().padLeft(2, '0')}.${h.tarih.year}";

              Color kartRengi = Colors.white;
              Color etiketBckRengi = const Color(0xFFE8F5E9);
              Color etiketYaziRengi = const Color(0xFF2E7D32);
              String etiketMetni = tEkran;
              IconData solIkon = Icons.event_note;
              Color ikonRengi = const Color(0xFF2E7D32);

              if (kalanGun < 0) {
                etiketBckRengi = Colors.grey.shade300;
                etiketYaziRengi = Colors.grey.shade700;
                etiketMetni = "Süresi Geçti";
                solIkon = Icons.history_toggle_off;
                ikonRengi = Colors.grey;
              } else if (kalanGun == 0) {
                kartRengi = const Color(0xFFFFF3E0);
                etiketBckRengi = Colors.red.shade600;
                etiketYaziRengi = Colors.white;
                etiketMetni = "BUGÜN!";
                solIkon = Icons.notification_important_rounded;
                ikonRengi = Colors.red;
              } else if (kalanGun == 1) {
                kartRengi = const Color(0xFFFFF3E0);
                etiketBckRengi = Colors.orange.shade700;
                etiketYaziRengi = Colors.white;
                etiketMetni = "YARIN!";
                solIkon = Icons.pending_actions_rounded;
                ikonRengi = Colors.orange;
              }

              return Card(
                color: kartRengi,
                elevation: kartRengi != Colors.white ? 1 : 0,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(solIkon, color: ikonRengi),
                  title: Text(h.baslik, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(h.icerik),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: etiketBckRengi, borderRadius: BorderRadius.circular(6)),
                    child: Text(etiketMetni, style: TextStyle(color: etiketYaziRengi, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text("Geçmiş Bütçe İşlemleri", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _islemler.isEmpty
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text("Henüz bir bütçe hareketi eklemediniz.", style: TextStyle(color: Colors.grey))))
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _islemler.length,
            itemBuilder: (context, index) {
              final islem = _islemler[index];
              final isGelir = islem.tur == "Gelir";
              return Card(
                color: Colors.white,
                elevation: 0,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: kategoriRenk(islem.kategori).withOpacity(0.15),
                    child: Icon(kategoriIkon(islem.kategori), color: kategoriRenk(islem.kategori)),
                  ),
                  title: Text(islem.baslik, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${isGelir ? 'Gelir' : 'Gider'} • ${islem.kategori}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("${isGelir ? '+' : '-'} ₺${islem.miktar.toStringAsFixed(2)}", style: TextStyle(color: isGelir ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_outlined, size: 22, color: Colors.redAccent),
                        onPressed: () => _islemSil(index),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ================= 2. SAYFA: NOTLAR SAYFASI =================
  Widget _notlarSayfaIcerigi() {
    return Column(
      children: [
        TabBar(
          controller: _notlarTabController,
          labelColor: const Color(0xFF2E7D32),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF2E7D32),
          tabs: const [
            Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: "Bütçe Notları"),
            Tab(icon: Icon(Icons.sticky_note_2_outlined), text: "Düz Yazı Notları"),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _notlarTabController,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                      onPressed: _islemPencerisiniAc,
                      icon: const Icon(Icons.add_card),
                      label: const Text("Yeni Bütçe / Hesap Notu Ekle"),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _islemler.isEmpty
                          ? const Center(child: Text("Kayıtlı bütçe notu yok.", style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                        itemCount: _islemler.length,
                        itemBuilder: (context, index) {
                          final islem = _islemler[index];
                          final isGelir = islem.tur == "Gelir";
                          return Card(
                            color: Colors.white,
                            elevation: 0,
                            child: ListTile(
                              leading: Icon(kategoriIkon(islem.kategori), color: kategoriRenk(islem.kategori)),
                              title: Text(islem.baslik, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("Tür: ${islem.tur} • ${islem.kategori}"),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("₺${islem.miktar.toStringAsFixed(2)}", style: TextStyle(color: isGelir ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_sweep_outlined, size: 22, color: Colors.redAccent),
                                    onPressed: () => _islemSil(index),
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
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
                      onPressed: _duzNotPencerisiniAc,
                      icon: const Icon(Icons.note_add_outlined),
                      label: const Text("Yeni Yazı Notu Ekle"),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _duzYaziNotlari.isEmpty
                          ? const Center(child: Text("Hafızada düz yazı notu bulunmuyor.", style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                        itemCount: _duzYaziNotlari.length,
                        itemBuilder: (context, index) {
                          final not = _duzYaziNotlari[index];
                          return Card(
                            color: Colors.white,
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.description_outlined, size: 18, color: Color(0xFF2E7D32)),
                                            const SizedBox(width: 6),
                                            Text(not.baslik, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(not.icerik, style: const TextStyle(color: Colors.black87, fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_sweep_outlined, size: 22, color: Colors.redAccent),
                                    onPressed: () => _duzNotSil(index),
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
            ],
          ),
        ),
      ],
    );
  }

  // ================= 3. SAYFA: AKILLI HATIRLATMALAR SAYFASI =================
  Widget _hatirlatmalarSayfaIcerigi() {
    final suAn = DateTime.now();
    final bugunGunu = DateTime(suAn.year, suAn.month, suAn.day);

    List<Hatirlatici> siraliList = List.from(_hatirlaticilar)..sort((a, b) => a.tarih.compareTo(b.tarih));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Akıllı Hatırlatıcılar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Color(0xFF2E7D32), size: 28),
                onPressed: _hatirlaticiPenceresiniAc,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: siraliList.isEmpty
                ? const Center(child: Text("Kurulmuş aktif bir hatırlatıcı yok kanka.", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              itemCount: siraliList.length,
              itemBuilder: (context, index) {
                final h = siraliList[index];
                final tEkran = "${h.tarih.day.toString().padLeft(2, '0')}.${h.tarih.month.toString().padLeft(2, '0')}.${h.tarih.year}";
                final hedefGunu = DateTime(h.tarih.year, h.tarih.month, h.tarih.day);
                final kalanGunSayisi = hedefGunu.difference(bugunGunu).inDays;

                Color kartRengi = Colors.white;
                Color etiketBckRengi = const Color(0xFFE8F5E9);
                Color etiketYaziRengi = const Color(0xFF2E7D32);
                String etiketMetni = "Vakit Var ($tEkran)";
                IconData solIkon = Icons.notifications_active_outlined;
                Color ikonRengi = const Color(0xFF2E7D32);
                bool gectiMi = false;

                if (kalanGunSayisi < 0) {
                  gectiMi = true;
                  etiketBckRengi = Colors.grey.shade300;
                  etiketYaziRengi = Colors.grey.shade700;
                  etiketMetni = "⌛ Süresi Geçti";
                  solIkon = Icons.notification_important_outlined;
                  ikonRengi = Colors.grey;
                } else if (kalanGunSayisi == 0) {
                  kartRengi = const Color(0xFFFFF3E0);
                  etiketBckRengi = Colors.red.shade600;
                  etiketYaziRengi = Colors.white;
                  etiketMetni = "🚨 BUGÜN!";
                  solIkon = Icons.crisis_alert_rounded;
                  ikonRengi = Colors.red;
                } else if (kalanGunSayisi == 1) {
                  kartRengi = const Color(0xFFFFF3E0);
                  etiketBckRengi = Colors.orange.shade700;
                  etiketYaziRengi = Colors.white;
                  etiketMetni = "⏳ YARIN!";
                  solIkon = Icons.running_with_errors_rounded;
                  ikonRengi = Colors.orange;
                }

                return Card(
                  color: kartRengi,
                  elevation: kartRengi != Colors.white ? 1 : 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(solIkon, color: ikonRengi),
                    title: Text(
                      h.baslik,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: gectiMi ? Colors.grey : Colors.black87,
                        decoration: gectiMi ? TextDecoration.lineThrough : TextDecoration.none,
                      ),
                    ),
                    subtitle: Text(h.icerik, style: TextStyle(color: gectiMi ? Colors.grey : Colors.black54)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: etiketBckRengi, borderRadius: BorderRadius.circular(6)),
                          child: Text(etiketMetni, style: TextStyle(color: etiketYaziRengi, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_sweep_outlined, size: 22, color: Colors.redAccent),
                          onPressed: () {
                            final asilIndex = _hatirlaticilar.indexWhere((e) => e.id == h.id);
                            if (asilIndex != -1) _hatirlaticiSil(asilIndex);
                          },
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
    );
  }

  // ================= 4. SAYFA: ANALİZ =================
  Widget _analizSayfaIcerigi() {
    final suAn = DateTime.now();
    final bugun = DateTime(suAn.year, suAn.month, suAn.day);
    final ayBaslangic = DateTime(suAn.year, suAn.month, 1);
    final gecenAyBaslangic = DateTime(suAn.year, suAn.month - 1, 1);

    bool buAyMi(DateTime t) => !t.isBefore(ayBaslangic);
    bool gecenAyMi(DateTime t) => !t.isBefore(gecenAyBaslangic) && t.isBefore(ayBaslangic);

    final buAyIslemler = _islemler.where((e) => buAyMi(e.tarih)).toList();
    final gecenAyIslemler = _islemler.where((e) => gecenAyMi(e.tarih)).toList();

    double topla(List<IslemKaydi> liste, String tur) => liste.where((e) => e.tur == tur).fold(0.0, (t, e) => t + e.miktar);

    final buAyGelir = topla(buAyIslemler, "Gelir");
    final buAyGider = topla(buAyIslemler, "Gider");
    final buAyNet = buAyGelir - buAyGider;
    final gecenAyGider = topla(gecenAyIslemler, "Gider");

    // Kategori dağılımı (bu ayın giderleri)
    final Map<String, double> kategoriToplam = {};
    for (final e in buAyIslemler.where((e) => e.tur == "Gider")) {
      kategoriToplam[e.kategori] = (kategoriToplam[e.kategori] ?? 0) + e.miktar;
    }
    final kategoriGirdileri = kategoriToplam.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Son 5 haftalık trend
    final List<double> haftalikGelir = List.filled(5, 0.0);
    final List<double> haftalikGider = List.filled(5, 0.0);
    final List<String> haftaEtiketleri = [];
    for (int i = 4; i >= 0; i--) {
      final haftaBaslangic = bugun.subtract(Duration(days: i * 7 + 6));
      haftaEtiketleri.add("${haftaBaslangic.day}/${haftaBaslangic.month}");
    }
    for (final e in _islemler) {
      final gunFark = bugun.difference(DateTime(e.tarih.year, e.tarih.month, e.tarih.day)).inDays;
      if (gunFark < 0 || gunFark > 34) continue;
      final haftaIndex = 4 - (gunFark ~/ 7);
      if (haftaIndex < 0 || haftaIndex > 4) continue;
      if (e.tur == "Gelir") {
        haftalikGelir[haftaIndex] += e.miktar;
      } else {
        haftalikGider[haftaIndex] += e.miktar;
      }
    }

    // İçgörüler
    final List<Widget> icgoruler = [];
    if (kategoriGirdileri.isNotEmpty) {
      icgoruler.add(_icgoruSatiri(Icons.shopping_bag_outlined, [
        const TextSpan(text: "En çok harcamayı "),
        TextSpan(text: kategoriGirdileri.first.key, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
        const TextSpan(text: " kategorisinde yaptın."),
      ]));
    }
    if (buAyGelir > 0) {
      final tasarrufOrani = ((buAyGelir - buAyGider) / buAyGelir * 100);
      icgoruler.add(_icgoruSatiri(Icons.savings_outlined, [
        const TextSpan(text: "Gelirinin "),
        TextSpan(text: "%${tasarrufOrani.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
        const TextSpan(text: "'ini tasarruf edebildin."),
      ]));
    }
    if (gecenAyGider > 0) {
      final degisim = ((buAyGider - gecenAyGider) / gecenAyGider * 100);
      final azMi = degisim <= 0;
      icgoruler.add(_icgoruSatiri(Icons.trending_up_outlined, [
        const TextSpan(text: "Bu ay geçen aya göre "),
        TextSpan(
          text: "%${degisim.abs().toStringAsFixed(0)}",
          style: TextStyle(fontWeight: FontWeight.bold, color: azMi ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
        ),
        TextSpan(text: " daha ${azMi ? 'az' : 'fazla'} harcama yaptın."),
      ]));
    }
    if (icgoruler.isEmpty) {
      icgoruler.add(const Text("Yeterli veri birikince burada kişisel içgörüler göreceksin.", style: TextStyle(color: Colors.grey)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Analiz", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                child: Row(
                  children: const [
                    Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF2E7D32)),
                    SizedBox(width: 6),
                    Text("Bu Ay", style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF1B5E20), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Expanded(child: _analizOzetOgesi("Toplam Gelir", buAyGelir, Icons.north_east_rounded)),
                Expanded(child: _analizOzetOgesi("Toplam Gider", buAyGider, Icons.south_rounded)),
                Expanded(child: _analizOzetOgesi("Net Bakiye", buAyNet, Icons.account_balance_wallet_outlined)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Gelir - Gider Trendi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _grafikLejanti(const Color(0xFF2E7D32), "Gelir"),
                      const SizedBox(width: 16),
                      _grafikLejanti(const Color(0xFFE53935), "Gider"),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: CustomPaint(
                      size: const Size(double.infinity, 180),
                      painter: _TrendChartPainter(gelir: haftalikGelir, gider: haftalikGider),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: haftaEtiketleri
                        .map((e) => Text(e, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Kategori Dağılımı", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  kategoriGirdileri.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text("Bu ay için gider kaydı yok.", style: TextStyle(color: Colors.grey)),
                  )
                      : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(120, 120),
                              painter: _DonutChartPainter(
                                veriler: kategoriGirdileri,
                                renkler: kategoriGirdileri.map((e) => kategoriRenk(e.key)).toList(),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text("Toplam Gider", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                Text("₺${buAyGider.toStringAsFixed(0)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          children: kategoriGirdileri.map((e) {
                            final yuzde = buAyGider > 0 ? (e.value / buAyGider * 100) : 0.0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(radius: 10, backgroundColor: kategoriRenk(e.key), child: Icon(kategoriIkon(e.key), size: 11, color: Colors.white)),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
                                  Text("₺${e.value.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 6),
                                  Text("%${yuzde.toStringAsFixed(0)}", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("İçgörüler", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...icgoruler,
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _butceDurumuKarti(buAyGider),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _analizOzetOgesi(String baslik, double tutar, IconData ikon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(baslik, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        Text("₺${tutar.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        CircleAvatar(radius: 14, backgroundColor: Colors.white24, child: Icon(ikon, size: 14, color: Colors.white)),
      ],
    );
  }

  Widget _icgoruSatiri(IconData ikon, List<InlineSpan> spans) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF1F8F1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 15, backgroundColor: const Color(0xFF2E7D32), child: Icon(ikon, size: 15, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 13.5), children: spans))),
        ],
      ),
    );
  }

  Widget _butceDurumuKarti(double harcanan) {
    final butce = _aylikButce;
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Bütçe Durumu", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF2E7D32)),
                  onPressed: _butcePencerisiniAc,
                ),
              ],
            ),
            if (butce == null || butce <= 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Henüz aylık bütçe belirlemedin.", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                      onPressed: _butcePencerisiniAc,
                      child: const Text("Aylık Bütçe Belirle"),
                    ),
                  ],
                ),
              )
            else
              Builder(builder: (context) {
                final kalan = butce - harcanan;
                final oran = (harcanan / butce).clamp(0.0, 1.0);
                final barRengi = oran >= 1.0
                    ? const Color(0xFFC62828)
                    : (oran >= 0.8 ? const Color(0xFFFFA726) : const Color(0xFF2E7D32));
                return Column(
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _butceOgesi("Aylık Bütçe", "₺${butce.toStringAsFixed(0)}", Colors.black87),
                        _butceOgesi("Harcanan", "₺${harcanan.toStringAsFixed(0)}", const Color(0xFFC62828)),
                        _butceOgesi("Kalan", "₺${kalan.toStringAsFixed(0)}", kalan < 0 ? const Color(0xFFC62828) : const Color(0xFF2E7D32)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: oran,
                        minHeight: 10,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(barRengi),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text("%${(oran * 100).toStringAsFixed(0)}", style: TextStyle(color: barRengi, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _butceOgesi(String baslik, String tutar, Color renk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(baslik, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(tutar, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: renk)),
      ],
    );
  }

  Widget _bakiyeOgesi(String baslik, String miktar) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(baslik, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(miktar, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _grafikLejanti(Color renk, String metin) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(metin, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    double toplamBakiye = _toplamGelir - _toplamGider;
    double grafikOrani = _toplamGelir > 0 ? (_toplamGider / _toplamGelir) : 0.0;
    if (grafikOrani > 1.0) grafikOrani = 1.0;

    final List<Widget> sayfalar = [
      _anaSayfaIcerigi(toplamBakiye, grafikOrani),
      _notlarSayfaIcerigi(),
      _hatirlatmalarSayfaIcerigi(),
      _analizSayfaIcerigi(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("VORTEXA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: sayfalar[_seciliIndeks],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF1B5E20),
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white54,
          currentIndex: _seciliIndeks,
          onTap: _sayfaDegistir,
          elevation: 10,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_max_outlined, size: 26),
              activeIcon: Icon(Icons.home_max, size: 28),
              label: "Ana Sayfa",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined, size: 26),
              activeIcon: Icon(Icons.receipt_long, size: 28),
              label: "Notlar",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.alarm_on_outlined, size: 26),
              activeIcon: Icon(Icons.alarm_on, size: 28),
              label: "Hatırlatmalar",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined, size: 26),
              activeIcon: Icon(Icons.bar_chart, size: 28),
              label: "Analiz",
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// GRAFİK ÇİZİMLERİ (ekstra paket kurmadan CustomPainter ile)
// =====================================================================

class _TrendChartPainter extends CustomPainter {
  final List<double> gelir;
  final List<double> gider;

  _TrendChartPainter({required this.gelir, required this.gider});

  @override
  void paint(Canvas canvas, Size size) {
    final tumDegerler = [...gelir, ...gider, 1.0];
    final maxDeger = tumDegerler.reduce((a, b) => a > b ? a : b);
    final adim = gelir.length > 1 ? size.width / (gelir.length - 1) : size.width;

    void cizgiCiz(List<double> veri, Color renk) {
      final path = Path();
      final noktalar = <Offset>[];
      for (int i = 0; i < veri.length; i++) {
        final x = i * adim;
        final y = size.height - (veri[i] / maxDeger) * (size.height - 10) - 5;
        noktalar.add(Offset(x, y));
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final dolguPath = Path.from(path)
        ..lineTo(noktalar.last.dx, size.height)
        ..lineTo(noktalar.first.dx, size.height)
        ..close();

      canvas.drawPath(
        dolguPath,
        Paint()
          ..shader = LinearGradient(
            colors: [renk.withOpacity(0.22), renk.withOpacity(0.0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );

      canvas.drawPath(
        path,
        Paint()
          ..color = renk
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      for (final n in noktalar) {
        canvas.drawCircle(n, 4, Paint()..color = renk);
        canvas.drawCircle(n, 4, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
      }
    }

    cizgiCiz(gider, const Color(0xFFE53935));
    cizgiCiz(gelir, const Color(0xFF2E7D32));
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.gelir != gelir || oldDelegate.gider != gider;
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> veriler;
  final List<Color> renkler;

  _DonutChartPainter({required this.veriler, required this.renkler});

  @override
  void paint(Canvas canvas, Size size) {
    final toplam = veriler.fold(0.0, (t, e) => t + e.value);
    if (toplam <= 0) return;

    final rect = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    double baslangicAcisi = -pi / 2;

    for (int i = 0; i < veriler.length; i++) {
      final oran = veriler[i].value / toplam;
      final aci = oran * 2 * pi;
      canvas.drawArc(
        rect,
        baslangicAcisi,
        aci,
        false,
        Paint()
          ..color = renkler[i % renkler.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.22
          ..strokeCap = StrokeCap.butt,
      );
      baslangicAcisi += aci;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}
