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

  6. Uzun kenari MAX_BOYUT'a indirir (LANCZOS). Ham cizimler ~1500 px;
     karakter ekranda ~50 px kapliyor, o yuzden 512 fazlasiyla yeter ve
     paket boyutunu bes kat kuculttur.
  7. VARYANT: Lyra parcalarindan Grunt'un renk varyantini uretir. HSV'de
     SECICI kaydirma - ten ve kontur cizgilerine DOKUNMAZ, yalniz kumas
     renklerini degistirir. Yeni cizim gerekmez.

NASIL CALISTIRILIR (proje klasorunde):
    python tools/parca_isle.py

Girdi : assets/kaynak/lyra/*.png             (ham cizimler, git'te durur)
Cikti : assets/characters/lyra/parts/*.png   (Lyra parcalari)
        assets/characters/grunt/parts/*.png  (Grunt renk varyanti)
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
## 0.30 -> 0.24: kosu ve tekme pozlarinda uyluk ust ucu ile sort arasinda
## centik kaliyordu; sortu biraz uzatmak bindirmeyi geri getirdi.
KALCA_ALT_KESIM = 0.24
## Doku uzun kenari (px). Karakter ekranda ~50 px; 512 fazlasiyla yeter.
MAX_BOYUT = 512
## govde parcasinda HER IKI YANDAN atilan oran.
## ONCEKI CIZIM onden bakisti ve iki yanindan omuz kutugu tasiyordu; kolun
## disina tasip "kopuk omuz" veriyordu, o yuzden 0.13 kesiliyordu.
## YENI CIZIM yandan-3/4: tek bir deltoid var ve o omuzun KENDISI, kesilirse
## govde daralir. Bu yuzden 0.0 - ekran dogrulamasiyla teyit edildi.
GOVDE_OMUZ_KESIM = 0.0
## Govdenin ARKA omuz topunu siler. Yandan-3/4 cizimde govde kendi ARKA
## deltoidini tasiyor; arka kol GOVDENIN ARKASINDA cizildigi icin o topu
## ortemiyor ve ciplak bir kure gibi disari cikiyordu. Arka omuzu artik
## ArmB parcasinin kendi yuvarlak ucu veriyor.
## SILME YUMUSAK ve ELIPTIK: dikdortgen kesim denendi, duz kenar birakip
## "dilimlenmis omuz" gorunumu verdi (tekme pozunda belirgindi).
## merkez ve yaricap, parcanin kendi olculerine orandir.
## GOVDE OMUZ KESIMI (kok neden cozumu). Yandan-3/4 govde, atlet aski
## hattinin DISINDA iki ten renkli deltoid TOPU tasiyor. Bunlari kol
## ortemiyor (arka kol govdenin arkasinda cizilir) ve ayrik kure gibi
## duruyorlar. Omuzu artik ust_kol parcasinin kendi yuvarlak ucu verir.
## Silme YALNIZ TEN RENKLI piksellere uygulanir: aski, kontur ve
## boyun/trapez ten bolgesi KALIR. Degerler parca oranidir (levhayla
## ayarlanir): (x_siniri, y_siniri)
GOVDE_OMUZ_KES_SOL = (0.30, 0.42)   # x < 0.30 ve y < 0.42 -> arka top
GOVDE_OMUZ_KES_SAG = (0.80, 0.30)   # x > 0.80 ve y < 0.30 -> on top
GOVDE_OMUZ_MERKEZ = (0.10, 0.10)
GOVDE_OMUZ_YARICAP = (0.30, 0.22)
## Kenar yumusakligi: 1.0 = tam yumusak gecis.
GOVDE_OMUZ_YUMUSAK = 0.0  # 0 = silme KAPALI
## YATAY AYNALAMA. Karakter SAGA bakar; sola donuk cizilmis parcalar burada
## cevrilir. Islem zincirinin EN BASINDA, seffaflastirmadan bile once yapilir.
## govde: cizim sola donuktu - Lyra saga bakarken gogus SIRT yonunde
## kaliyordu. Gogus amblemi simetrik sevron, aynalama guvenli.
FLIP = {
    "govde": True,
}
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


def kucult(im: Image.Image, en_uzun: int = MAX_BOYUT) -> Image.Image:
    """Uzun kenari en_uzun'a indirir. Zaten kucukse dokunmaz."""
    uzun = max(im.size)
    if uzun <= en_uzun:
        return im
    k = en_uzun / float(uzun)
    return im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))),
                     Image.LANCZOS)


# =============================================================================
# GRUNT RENK VARYANTI
# =============================================================================
GRUNT_CIKIS = os.path.join("assets", "characters", "grunt", "parts")


def _rgb_hsv(rgb: np.ndarray):
    """Vektorel RGB(0-1) -> HSV. H derece (0-360), S ve V 0-1."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    enb = rgb.max(axis=-1)
    enk = rgb.min(axis=-1)
    fark = enb - enk
    h = np.zeros_like(enb)
    m = (fark > 1e-6) & (enb == r)
    h[m] = (60.0 * ((g[m] - b[m]) / fark[m])) % 360.0
    m = (fark > 1e-6) & (enb == g)
    h[m] = 60.0 * ((b[m] - r[m]) / fark[m]) + 120.0
    m = (fark > 1e-6) & (enb == b)
    h[m] = 60.0 * ((r[m] - g[m]) / fark[m]) + 240.0
    s = np.where(enb > 1e-6, fark / np.maximum(enb, 1e-6), 0.0)
    return h % 360.0, s, enb


def _hsv_rgb(h: np.ndarray, s: np.ndarray, v: np.ndarray) -> np.ndarray:
    """Vektorel HSV -> RGB(0-1)."""
    i = np.floor(h / 60.0).astype(int) % 6
    f = (h / 60.0) - np.floor(h / 60.0)
    p = v * (1.0 - s)
    q = v * (1.0 - f * s)
    t = v * (1.0 - (1.0 - f) * s)
    r = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [v, q, p, p, t, v])
    g = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [t, v, v, q, p, p])
    b = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [p, p, t, v, v, q])
    return np.stack([r, g, b], axis=-1)


def grunt_varyanti(im: Image.Image, sac: bool = False):
    """Lyra parcasindan Grunt paletini uretir. SECICI: ten ve konturlara
    dokunmaz, yalniz kumas renklerini kaydirir."""
    dizi = np.asarray(im).astype(np.float32) / 255.0
    rgb = dizi[..., :3].copy()
    a = dizi[..., 3]
    h, s, v = _rgb_hsv(rgb)

    gorunur = a > 0.05
    # --- DOKUNULMAYANLAR ---
    kontur = v < 0.25                                   # cizgi/koyu golge
    ten = (h >= 10.0) & (h <= 40.0) & (s > 0.15)        # ten tonu
    korunan = kontur | ten

    # --- BOYANANLAR ---
    # Notr kumas. PARLAK notrler (goz aki, beyaz vurgu) HARIC birakilir -
    # aksi halde Grunt'un gozleri kizariyordu.
    notr = gorunur & ~korunan & (s < 0.15) & (v < 0.78)
    haki = gorunur & ~korunan & (h >= 40.0) & (h <= 90.0)        # zeytin
    turkuaz = gorunur & ~korunan & (h >= 150.0) & (h <= 200.0) & (s > 0.3)

    yh, ys, yv = h.copy(), s.copy(), v.copy()

    # gri/notr -> kizil-bordo. Orijinal doygunlugu 0.45-0.60 bandina yay.
    yh[notr] = 355.0
    ys[notr] = 0.45 + (s[notr] / 0.15) * 0.15
    yv[notr] = v[notr] * 0.85

    # haki/zeytin -> koyu bordo
    yh[haki] = 350.0
    yv[haki] = v[haki] * 0.80

    # turkuaz vurgu -> turuncu-amber
    yh[turkuaz] = 30.0

    # SAC BOYASI - yalniz kafa parcasinda. Sac V 0.12-0.32 bandinda; asagisi
    # (V<0.12) kontur cizgisi, o KORUNUR. Lyra'nin siyah sacini Grunt'ta koyu
    # kizil-kahveye cevirir; iki karakter uzaktan da ayrilsin diye.
    sac_maske = np.zeros_like(gorunur)
    if sac:
        sac_maske = gorunur & (v >= 0.12) & (v <= 0.32) & ~ten
        yh[sac_maske] = 17.0
        ys[sac_maske] = 0.50
        yv[sac_maske] = v[sac_maske] * 1.15

    yeni = _hsv_rgb(yh, ys, yv)
    yeni = np.where(gorunur[..., None], yeni, rgb)
    cikti = np.dstack([(np.clip(yeni, 0.0, 1.0) * 255.0).astype(np.uint8),
                       (a * 255.0).astype(np.uint8)])

    toplam = int(gorunur.sum())
    boyanan = int((notr | haki | turkuaz | sac_maske).sum())
    yuzde = (100.0 * boyanan / toplam) if toplam else 0.0
    ayrinti = (int(notr.sum()), int(haki.sum()), int(turkuaz.sum()), int(sac_maske.sum()))
    return Image.fromarray(cikti, "RGBA"), yuzde, ayrinti


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
        if FLIP.get(ad, False):
            ham = ham.transpose(Image.FLIP_LEFT_RIGHT)
        im = arka_plani_sil(ham)
        im = kirp(im)

        if ad == "govde":
            if GOVDE_OMUZ_KESIM > 0.0:
                kes = int(im.width * GOVDE_OMUZ_KESIM)
                im = im.crop((kes, 0, im.width - kes, im.height))
            # --- OMUZ TOPLARINI SIL (yalniz ten renkli pikseller) ---
            g = np.asarray(im).astype(np.int16)
            gy, gx = g.shape[0], g.shape[1]
            yy, xx = np.mgrid[0:gy, 0:gx]
            fx, fy = xx / float(gx), yy / float(gy)
            rr, gg, bb, aa = g[..., 0], g[..., 1], g[..., 2], g[..., 3]
            ten_px = ((aa > 40) & (rr > 95) & (gg > 40) & (bb > 20)
                      & (rr > gg) & (gg > bb) & ((rr - bb) > 15) & ((rr - gg) > 5))
            bolge = (((fx < GOVDE_OMUZ_KES_SOL[0]) & (fy < GOVDE_OMUZ_KES_SOL[1]))
                     | ((fx > GOVDE_OMUZ_KES_SAG[0]) & (fy < GOVDE_OMUZ_KES_SAG[1])))
            sil = ten_px & bolge
            ga = np.asarray(im).copy()
            ga[..., 3] = np.where(sil, 0, ga[..., 3])
            im = Image.fromarray(ga, "RGBA")
            # Kesim kenarini 1 px yumusat - keskin basamak kalmasin.
            al = Image.fromarray(np.asarray(im)[..., 3], "L").filter(ImageFilter.GaussianBlur(0.8))
            ga = np.asarray(im).copy()
            ga[..., 3] = np.asarray(al)
            im = Image.fromarray(ga, "RGBA")

            # NOT: govdenin arka omuz topunu SILMEYI iki kez denedim.
            # Dikdortgen kesim duz kenar birakti ("dilimlenmis omuz"),
            # eliptik yumusak silme ise fazla yiyip omuzu hayaletlestirdi.
            # Dogru cozum kirpmak DEGIL, kolun yuvarlak basligini omuz
            # eklemine oturtup topu ORTMEK oldu (lyra/grunt.tscn'de
            # Arm*_Upper sprite y 15 -> 10.5). GOVDE_OMUZ_YUMUSAK = 0
            # oldugu icin asagidaki blok etkisizdir; ayar burada duruyor.
            d = np.asarray(im).astype(np.float32).copy()
            yuk, gen = d.shape[0], d.shape[1]
            yy, xx = np.mgrid[0:yuk, 0:gen]
            # Normalize edilmis elips uzakligi (arka-ust kose merkezli)
            u = ((xx / gen - GOVDE_OMUZ_MERKEZ[0]) / GOVDE_OMUZ_YARICAP[0]) ** 2
            w2 = ((yy / yuk - GOVDE_OMUZ_MERKEZ[1]) / GOVDE_OMUZ_YARICAP[1]) ** 2
            uzak = np.sqrt(u + w2)
            ic = 1.0 - GOVDE_OMUZ_YUMUSAK
            kalan = np.clip((uzak - ic) / max(1e-6, 1.0 - ic), 0.0, 1.0)
            if GOVDE_OMUZ_YUMUSAK > 0.0:
                d[..., 3] *= kalan
            im = Image.fromarray(d.astype(np.uint8), "RGBA")
            im = kirp(im)

        if ad == "kalca":
            # Alt %30 = bacak pacalari. Kesip yeniden kirpiyoruz.
            yeni_yukseklik = int(im.height * (1.0 - KALCA_ALT_KESIM))
            im = im.crop((0, 0, im.width, yeni_yukseklik))
            im = kirp(im)

        im = kucult(im)

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

    # --- GRUNT RENK VARYANTI (yeni cizim gerekmez) ---
    os.makedirs(GRUNT_CIKIS, exist_ok=True)
    print("\n--------- GRUNT RENK VARYANTI ---------")
    print("  KORUNAN: ten (H 10-40, S>0.15) ve kontur/koyu (V<0.25)")
    print("  BOYANAN: notr kumas -> kizil-bordo | haki -> koyu bordo |")
    print("           turkuaz vurgu -> turuncu-amber")
    print("  %-11s %9s %9s %9s %9s %9s" % ("parca", "boyanan", "notr", "haki", "turkuaz", "sac"))
    for ad in PARCALAR:
        kaynak = Image.open(os.path.join(CIKIS, ad + ".png")).convert("RGBA")
        varyant, yuzde, (n, hk, tq, sc) = grunt_varyanti(kaynak, sac=(ad == "kafa"))
        varyant.save(os.path.join(GRUNT_CIKIS, ad + ".png"))
        print("  %-11s %8.1f%% %9d %9d %9d %9d" % (ad, yuzde, n, hk, tq, sc))

    print("\n=========== BITTI ===========\n")


if __name__ == "__main__":
    sys.exit(main())
