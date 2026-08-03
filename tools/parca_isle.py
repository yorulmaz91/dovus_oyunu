"""
parca_isle.py  —  Lyra'nin ham cizimlerini rig'e takilabilir parcalara cevirir.

NE YAPAR (her kaynak gorsel icin):
  1. Arka plani seffaflastirir. YALNIZ KENARLARDAN tasmali doldurma yapar,
     yani icerideki beyazlar (bandaj cizgileri, goz aki, kiyafet vurgusu)
     KORUNUR.
  2. Kenari 1-2 px yumusatir (beyaz sacak kalmasin).
  3. Seffaf bosluklari kirpar, 4 px pay birakir.
  4. kalca icin: alt %30'u atar. Sebep: bacak pacalari ust_bacak
     parcasinda ZATEN var; ikisi birden kalirsa cift paca olur.
  5. Ten tonunu olcer ve kafaya gore farki raporlar. DUZELTME UYGULAMAZ -
     o karar mimara ait.

NASIL CALISTIRILIR (proje klasorunde):
    python tools/parca_isle.py

Girdi : assets/kaynak/lyra/*.png        (ham cizimler, git'te durur)
Cikti : assets/characters/lyra/parts/*.png  (Godot'un kullandigi parcalar)
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

KAYNAK = os.path.join("assets", "kaynak", "lyra")
CIKIS = os.path.join("assets", "characters", "lyra", "parts")

PARCALAR = [
    "kafa", "govde", "kalca", "ust_kol", "alt_kol",
    "el", "ust_bacak", "alt_bacak", "ayak",
]

# --- Ayarlar -----------------------------------------------------------------
## Beyaz sayilma toleransi (0-255). Yuksek olursa acik tenli bolgeler yenir.
BEYAZ_TOLERANS = 40
## Kenar yumusatma yaricapi (px). 0 = keskin kenar.
KENAR_YUMUSATMA = 1.2
## Yumusatmadan sonra alfayi iceri cekme miktari - beyaz sacagi siler.
ALFA_ICERI_CEK = 0.28
## Kirpma sonrasi birakilan seffaf pay (px).
PAY = 4
## kalca parcasinda ATILAN alt oran. Bacak pacalari ust_bacak'ta zaten var.
## Ekran dogrulamasinda ayarlanir.
KALCA_ALT_KESIM = 0.30
## govde parcasinda HER IKI YANDAN atilan oran. Cizimdeki omuz kutukleri
## kolun disina tasip "kopuk omuz" gibi duruyordu; omuzu ust_kol parcasinin
## kendi yuvarlak ucu veriyor. (Kalcadaki cift paca sorununun omuz hali.)
GOVDE_OMUZ_KESIM = 0.13
## Tasmali doldurmada kullanilan isaret rengi (cizimde bulunmadigi
## dogrulanir).
ISARET = (255, 0, 255)


def arka_plani_sil(im: Image.Image) -> Image.Image:
    """Kenarlardan tasmali doldurma ile arka plani seffaf yapar."""
    rgb = im.convert("RGB")

    # Isaret rengi cizimde geciyor mu? Geciyorsa baska bir renk secilmeli.
    if (np.asarray(rgb) == np.array(ISARET, dtype=np.uint8)).all(axis=-1).any():
        raise SystemExit("HATA: isaret rengi cizimde geciyor, ISARET degistirilmeli.")

    # 1 px beyaz cerceve ekle: boylece TEK bir doldurma butun kenar
    # beyazlarini yakalar (kose kose ugrasmaya gerek kalmaz).
    cerceve = Image.new("RGB", (rgb.width + 2, rgb.height + 2), (255, 255, 255))
    cerceve.paste(rgb, (1, 1))
    ImageDraw.floodfill(cerceve, (0, 0), ISARET, thresh=BEYAZ_TOLERANS)
    doldurulmus = cerceve.crop((1, 1, rgb.width + 1, rgb.height + 1))

    dizi = np.asarray(doldurulmus)
    disari = (dizi == np.array(ISARET, dtype=np.uint8)).all(axis=-1)

    alfa = np.where(disari, 0.0, 255.0).astype(np.float32)
    alfa_im = Image.fromarray(alfa.astype(np.uint8), "L")
    if KENAR_YUMUSATMA > 0.0:
        alfa_im = alfa_im.filter(ImageFilter.GaussianBlur(KENAR_YUMUSATMA))

    # Yumusatilmis alfayi biraz iceri cek: kenardaki yari-beyaz pikseller
    # gorunmesin. a' = (a - c) / (1 - c)
    a = np.asarray(alfa_im).astype(np.float32) / 255.0
    a = np.clip((a - ALFA_ICERI_CEK) / (1.0 - ALFA_ICERI_CEK), 0.0, 1.0)

    sonuc = np.dstack([np.asarray(rgb), (a * 255.0).astype(np.uint8)])
    return Image.fromarray(sonuc, "RGBA")


def kirp(im: Image.Image, pay: int = PAY) -> Image.Image:
    """Seffaf kenar bosluklarini atar, cevresine pay birakir."""
    kutu = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    if kutu is None:
        return im
    x0, y0, x1, y1 = kutu
    x0 = max(0, x0 - pay)
    y0 = max(0, y0 - pay)
    x1 = min(im.width, x1 + pay)
    y1 = min(im.height, y1 + pay)
    return im.crop((x0, y0, x1, y1))


def ten_medyani(im: Image.Image):
    """Parcadaki EN BUYUK ten renkli bolgenin medyan RGB'si."""
    dizi = np.asarray(im)
    r = dizi[..., 0].astype(np.int16)
    g = dizi[..., 1].astype(np.int16)
    b = dizi[..., 2].astype(np.int16)
    a = dizi[..., 3]

    ten = (
        (a > 200) & (r > 95) & (g > 40) & (b > 20)
        & (r > g) & (g > b) & ((r - b) > 15) & ((r - g) > 5)
    )
    if not ten.any():
        return None, 0

    etiket, adet = ndimage.label(ten)
    if adet == 0:
        return None, 0
    boyutlar = ndimage.sum(ten, etiket, range(1, adet + 1))
    en_buyuk = int(np.argmax(boyutlar)) + 1
    maske = etiket == en_buyuk
    medyan = (
        int(np.median(r[maske])),
        int(np.median(g[maske])),
        int(np.median(b[maske])),
    )
    return medyan, int(maske.sum())


def main() -> None:
    if not os.path.isdir(KAYNAK):
        raise SystemExit("HATA: %s yok." % KAYNAK)
    os.makedirs(CIKIS, exist_ok=True)

    print("=========== PARCA ISLEME ===========")
    print("Kaynak: %s" % KAYNAK)
    print("Cikis : %s" % CIKIS)
    print("Ayar  : beyaz tolerans %d, kenar yumusatma %.1f px, pay %d px, "
          "kalca alt kesim %%%d\n" % (BEYAZ_TOLERANS, KENAR_YUMUSATMA, PAY,
                                      KALCA_ALT_KESIM * 100))

    tonlar = {}
    boyutlar = {}

    for ad in PARCALAR:
        kaynak_yol = None
        for uzanti in (".png", ".jpg", ".jpeg"):
            aday = os.path.join(KAYNAK, ad + uzanti)
            if os.path.exists(aday):
                kaynak_yol = aday
                break
        if kaynak_yol is None:
            raise SystemExit("HATA: %s icin kaynak gorsel yok." % ad)

        ham = Image.open(kaynak_yol)
        im = arka_plani_sil(ham)
        im = kirp(im)

        if ad == "govde":
            # Iki yandaki omuz kutuklerini at, sonra yeniden kirp.
            kes = int(im.width * GOVDE_OMUZ_KESIM)
            im = im.crop((kes, 0, im.width - kes, im.height))
            im = kirp(im)

        if ad == "kalca":
            # Alt %30 = bacak pacalari. Kesip yeniden kirpiyoruz.
            yeni_yukseklik = int(im.height * (1.0 - KALCA_ALT_KESIM))
            im = im.crop((0, 0, im.width, yeni_yukseklik))
            im = kirp(im)

        cikis_yol = os.path.join(CIKIS, ad + ".png")
        im.save(cikis_yol)
        boyutlar[ad] = im.size

        medyan, piksel = ten_medyani(im)
        tonlar[ad] = (medyan, piksel)

        print("  %-11s %4dx%-4d -> %4dx%-4d  (%7d bayt)" % (
            ad, ham.width, ham.height, im.width, im.height,
            os.path.getsize(cikis_yol)))

    # --- Ten tonu tablosu ---
    print("\n--------- TEN TONU (kafa referans) ---------")
    ref = tonlar.get("kafa", (None, 0))[0]
    if ref is None:
        print("  kafa parcasinda ten bolgesi bulunamadi.")
    else:
        print("  %-11s %-16s %-18s %s" % ("parca", "medyan RGB", "fark (dR,dG,dB)", "ten pikseli"))
        for ad in PARCALAR:
            medyan, piksel = tonlar[ad]
            if medyan is None:
                print("  %-11s %-16s %-18s %d" % (ad, "-", "(ten yok)", 0))
                continue
            fark = (medyan[0] - ref[0], medyan[1] - ref[1], medyan[2] - ref[2])
            not_ = "" if ad != "kafa" else "  <- referans"
            print("  %-11s %-16s %-18s %d%s" % (
                ad, str(medyan), "(%+d,%+d,%+d)" % fark, piksel, not_))
    print("\n  NOT: duzeltme UYGULANMADI. Fark buyukse kaynak cizim ya da")
    print("       Sprite2D modulate ile ayarlanir - karar mimarin.")
    print("\n=========== BITTI ===========\n")


if __name__ == "__main__":
    sys.exit(main())
