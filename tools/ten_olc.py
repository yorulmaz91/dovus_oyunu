"""
ten_olc.py  —  Dogrulama karelerinden renk olcumu

NE ISE YARAR: build/dogrulama/*.png karelerinde Lyra'nin TEN tonunu ve
Grunt'un USTLUK bordosunu olcer. "Ekranda iyi gorunuyor" demek yerine sayi
verir; isik ayarlarini bununla karsilastiriyoruz.

AYIRT EDICI (onemli): ten ile bordo ikisi de kirmizi baskin. Ayrim
YESIL-MAVI farkindan gelir:
    ten   -> kademeli sicak, g-b >= 25
    bordo -> duz kirmizi,    g-b <  15
Bu olmadan olcum ikisini karistirir ve yaniltir.

NASIL CALISTIRILIR (proje klasorunde):
    python tools/ten_olc.py
"""

import colorsys
import os
import sys

import numpy as np
from PIL import Image

KARELER = ["idle", "yumruk", "tekme", "havalandirici",
           "zipla", "juggle", "grunt_idle", "karsilasma"]
KLASOR = os.path.join("build", "dogrulama")

# --- Hedef olcutler (Gorev 10) ---
TEN_R_ENAZ = 185
TEN_RG_ENAZ = 35
TEN_RB_ENAZ = 60
BORDO_S_ENAZ = 0.35
## HUD'i disarida birakmak icin ustten atilan piksel.
UST_KIRP = 120


def _hsv(c):
    h, s, v = colorsys.rgb_to_hsv(c[0] / 255.0, c[1] / 255.0, c[2] / 255.0)
    return h * 360.0, s, v


def olc(yol: str):
    im = np.asarray(Image.open(yol).convert("RGB")).astype(int)[UST_KIRP:, :, :]
    r, g, b = im[..., 0], im[..., 1], im[..., 2]

    ten = (r > g) & (g > b) & ((g - b) >= 25) & ((r - g) >= 12) & (r > 90) & (r < 252)
    tm = np.median(im[ten], axis=0).astype(int) if ten.sum() > 150 else None

    bordo = (r > g + 25) & ((g - b) < 15) & (r > 55) & (r < 215)
    bm = np.median(im[bordo], axis=0).astype(int) if bordo.sum() > 150 else None
    return tm, bm


def main() -> int:
    if not os.path.isdir(KLASOR):
        raise SystemExit("HATA: %s yok. Once tools/ekran_dogrula.tscn kostur." % KLASOR)

    print("\n=========== TEN / BORDO OLCUMU ===========")
    print("Hedef: Lyra ten R>=%d, R-G>=+%d, R-B>=+%d | Grunt hue 340-15, S>=%.2f"
          % (TEN_R_ENAZ, TEN_RG_ENAZ, TEN_RB_ENAZ, BORDO_S_ENAZ))
    print("%-15s | %-18s %5s %5s %5s | %-22s %s"
          % ("kare", "LYRA ten RGB", "R", "R-G", "R-B", "GRUNT ustluk", "hukum"))

    kalan = 0
    for ad in KARELER:
        yol = os.path.join(KLASOR, ad + ".png")
        if not os.path.exists(yol):
            print("%-15s | (kare yok)" % ad)
            continue
        tm, bm = olc(yol)
        if tm is None:
            print("%-15s | ten bulunamadi" % ad)
            kalan += 1
            continue
        rg, rb = tm[0] - tm[1], tm[0] - tm[2]
        ten_ok = tm[0] >= TEN_R_ENAZ and rg >= TEN_RG_ENAZ and rb >= TEN_RB_ENAZ
        if bm is None:
            bs, bordo_ok = "(bulunamadi)", False
        else:
            h, s, _ = _hsv(bm)
            bordo_ok = (h >= 340.0 or h <= 15.0) and s >= BORDO_S_ENAZ
            bs = "RGB%s hue=%.0f S=%.2f" % (tuple(bm), h, s)
        # yumruk flas karesi: beyaza yaklastigi icin ten olcutu muaf
        flas = ad == "yumruk"
        hukum = "FLAS" if flas else ("GECTI" if (ten_ok and bordo_ok) else "KALDI")
        if hukum == "KALDI":
            kalan += 1
        print("%-15s | %-18s %5d %+5d %+5d | %-22s %s"
              % (ad, str(tuple(tm)), tm[0], rg, rb, bs, hukum))

    print("\n%s\n" % ("HEPSI GECTI." if kalan == 0 else "%d kare KALDI." % kalan))
    return 0


if __name__ == "__main__":
    sys.exit(main())
