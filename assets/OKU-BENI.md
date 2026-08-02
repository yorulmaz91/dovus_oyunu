# assets/ klasoru

Buraya SADECE ham gorsel ve ses dosyalari konur. Sahne (.tscn) veya
script (.gd) dosyasi buraya KONMAZ - onlar `src/` altinda yasar.

## Su an ne var?

Hicbir sey. Oyun su anda gecici "yer tutucu" gorseller kullaniyor: her uzuv
Godot'un kendi urettigi renkli bir dikdortgen (GradientTexture2D). Bu sayede
oyunu hicbir cizim yapmadan HEMEN oynayabiliyorsun.

## Gercek cizimlere gecerken

1. Lyra'nin her uzvunu ayri bir PNG olarak (seffaf arka planli) su klasore koy:
   `assets/characters/lyra/parts/`
   Onerilen isimler:
   head.png  torso.png  pelvis.png
   arm_f_upper.png  arm_f_lower.png  hand_f.png
   arm_b_upper.png  arm_b_lower.png  hand_b.png
   leg_f_upper.png  leg_f_lower.png  foot_f.png
   leg_b_upper.png  leg_b_lower.png  foot_b.png

2. Godot'ta `src/characters/lyra/lyra.tscn` sahnesini ac.

3. Iskeletteki her Sprite2D'ye tikla, sagdaki Inspector'da "Texture" alanina
   ilgili PNG'yi surukle.

4. Sprite2D'nin "Offset" degerini, eklemin (kemigin baslangicinin) tam
   dogru yere gelmesi icin ayarla. Ornegin ust bacak resminin UST ucu
   kalcanin oldugu noktada olmali.

Hicbir kod degistirmen gerekmez - animasyonlar kemikleri dondurur,
resimler kemiklere yapisiktir.

## Bukulmesi gereken parcalar (etek, kusak, sac)

Bunlar icin Sprite2D yerine Polygon2D kullanilir ve `Skeleton` alani
`Skeleton2D`'ye baglanir. Polygon2D, Skeleton2D'nin KARDESI olmali,
bir Bone2D'nin ALTINDA olmamali - yoksa iki kez donusur ve ekrandan ucar.
