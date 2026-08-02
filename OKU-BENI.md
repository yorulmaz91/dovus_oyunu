# DÖVÜŞ OYUNU — Lyra

2.5D mobil dövüş oyunu. Godot 4.7 + Compatibility (OpenGL3) işleyicisi.
Ana mekanik: **havada kombo (juggle)** — rakibi havalandır, yere düşmeden
peş peşe tekmelerle yukarıda tut.

---

## OYUNU BAŞLATMAK

Godot'ta projeyi aç ve klavyeden **F5**'e bas. Hepsi bu.
(Ya da sağ üstteki ▶ üçgen düğme.)

## KONTROLLER

| Tuş | Ne yapar |
|---|---|
| **A / D** | Sola / sağa yürü |
| **W** veya **BOŞLUK** | Zıpla |
| **S** | Blok |
| **J** | Yumruk (hızlı açılış) |
| **L** | Tekme (yerde ve havada) |
| **K** | **HAVALANDIR** — rakibi göğe fırlatır |
| **R** | Dövüşü yeniden başlat |

Ekrandaki düğmelere **fareyle de tıklayabilirsin** (telefonda parmakla).

## KOMBOYU DENEMEK

1. **D** ile rakibe yaklaş
2. **K** — rakip havaya fırlar
3. **W** — sen de zıpla
4. **L L L** — havada peş peşe tekme

Ekranın ortasındaki yazı sana canlı olarak "Juggle puanı"nı gösterir.
Her tekme rakibi bir öncekinden **daha az** kaldırır ve yer çekimi
**biraz daha ağırlaşır**. Ağırlık kaldırmayı yendiğinde rakip düşer —
kombo kendiliğinden biter.

Zincir hamleler: **J → L → K** (yumruk, tekme, havalandır).

---

## AYARLARI DEĞİŞTİRMEK (kod yazmadan)

Godot'ta soldaki **FileSystem** panelinden dosyaya çift tıkla, sağdaki
**Inspector**'da sayıları değiştir. Kaydet (Ctrl+S) ve F5.

| Ne değiştirmek istiyorsun | Hangi dosya |
|---|---|
| Kombonun uzunluğu, havada kalma süresi | `data/rules/default_juggle.tres` |
| Havalandırıcının gücü ve hasarı | `data/moves/lyra/launcher.tres` |
| Yumruğun hızı/hasarı | `data/moves/lyra/jab.tres` |
| Hava tekmesi | `data/moves/lyra/air_kick.tres` |
| Düşmanın zorluğu | `src/characters/enemies/grunt/grunt.tscn` → `InputSource` → Difficulty |

**En çok işe yarayan iki ayar** (`default_juggle.tres` içinde):
- `Lift Decay` — küçült = kombo daha çabuk biter
- `Fall Gravity Scale` — küçült = rakip daha yavaş düşer, kovalaması kolaylaşır

---

## KLASÖR YAPISI

```
assets/   Ham çizimler ve sesler (şu an boş — yer tutucu renkler kullanılıyor)
data/     Hamle kartları ve juggle kuralları (.tres — Inspector'dan düzenlenir)
src/      Çalışan her şey: sahneler (.tscn) + scriptler (.gd) yan yana
  autoload/    Vuruş donması, olay tahtası
  combat/      Vuruş kutusu, hasar kutusu, hasar verisi
  states/      Durum makinesi: Idle, Run, Airborne, Attack, Hit, Juggle, Knockdown
  characters/  Lyra ve düşman
  stages/      Sahne + parallax derinlik katmanları
  main/        battle.tscn (oyunun açılış sahnesi) + kamera
  ui/          Can barları, kombo sayacı, dokunmatik tuşlar
shaders/  Compatibility için güvenli shader
tools/    oto_test — Godot'u açmadan sistemi doğrulayan otomatik test
```

**Tek kural:** ham resimler `assets/` altında, çalışan her şey `src/` altında.

---

## GERÇEK ÇİZİMLERE GEÇMEK

Şu an her uzuv Godot'un ürettiği renkli bir dikdörtgen. Gerçek çizimlere
geçmek için `assets/OKU-BENI.md` dosyasını oku — kod değiştirmeye gerek yok,
sadece her Sprite2D'nin "Texture" alanına kendi PNG'ni sürükleyeceksin.

---

## COMPATIBILITY İŞLEYİCİSİ — DİKKAT EDİLECEKLER

Bu proje bilerek **Compatibility (OpenGL3)** kullanıyor: eski telefonlar ve
web yayını için gerekli. Bunun iki sonucu var:

1. **2D parlama (glow) ÇALIŞMAZ.** `WorldEnvironment` ile Glow açma —
   Compatibility'de HDR 2D desteklenmiyor. Onun yerine `Blend Mode = Add`
   ayarlı `PointLight2D` kullan (sahnedeki `RimLight` böyle yapıyor).
2. **Işık sayısını az tut.** Compatibility'de bir ışığın değdiği her nesne
   fazladan bir çizim geçişi demektir. Şu anki bütçe: 1 gölge düşüren ışık
   + 3 gölgesiz ışık. Telefonda bunu aşma.

2D ışıklar ve gölgeler ÇALIŞIR — sahnedeki `KeyLight` gölge düşürüyor.

---

## OTOMATİK TEST

Bir şeyi bozduğundan şüphelenirsen, Godot'u açmadan komut satırından:

```
"C:\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path . res://tools/oto_test.tscn
```

Sanal bir oyuncu gibi oynar (yaklaş → havalandır → zıpla → tekme tekme)
ve sonunda "HİÇ HATA YOK" ya da hata listesi yazar.
