"""Régénère les assets de marque et d'onboarding (UI Refresh, 30/09/2026).

Usage, depuis la racine de lilia-app (Pillow et numpy, plus `cwebp`) :

    python3 tool/brand_assets.py

## Logo blanc du splash

Source : `assets/branding/source/logo1.jpg` (JPEG 6047 px, trait orange sur
fond crème, sans transparence ; aucune source vectorielle n'existe dans les
dépôts). L'alpha est extrait **progressivement** (distance au fond crème sur
les canaux G et B), pas par seuil binaire : les bords restent anticrénelés.
Le blanc étant constant, chaque sortie est un PNG palette 8 bits dont les 256
entrées sont des blancs d'opacité croissante — sans perte, ≤ 30 Ko à 444 px.

Sorties (logo de 148 dp de large, centré — identique au SplashScreen Flutter) :
- `assets/branding/logo_mark_white.png` (Flutter, 3×) ;
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage{,@2x,@3x}.png` ;
- `android/.../drawable-*dpi/splash_logo.png` (Android ≤ 11) ;
- `android/.../drawable-*dpi/android12_splash_logo.png` : toile 288 dp, logo
  inscrit dans le cercle de 192 dp exigé par l'API SplashScreen d'Android 12.

## Photos d'onboarding

Sources (non versionnées, hors bundle) : `assets/onb.jpeg`, `assets/onb2.webp`,
`assets/onb3.jpg`. Recadrages :
- onb1 : x 56–556 — **retire le verre GORDON'S (gin) et le cocktail** du bord
  droit, et la paille du bord gauche. Lilia Food ne vend pas d'alcool.
- onb2 : x 600–1430 — la cheffe et l'assiette (source paysage).
- onb3 : x 360–940, y 40–640 — le livreur. Source 1024×640 et livrée d'un
  tiers (turquoise) : photo **provisoire**, à remplacer par une photo locale.
Encodage `cwebp -q 80 -m 6` vers `assets/onboarding/onb{1,2,3}.webp`.
"""

import math
import os
import subprocess
import tempfile

import numpy as np
from PIL import Image

# 148 dp partout : c'est la plus grande largeur qui tient dans le cercle de
# 192 dp de l'écran système d'Android 12+ (diagonale du logo ≈ 192 × 0,98).
# Mêmes 148 dp sur iOS, Android ≤ 11 et le SplashScreen Flutter : aucun saut
# de taille d'un écran à l'autre.
LOGO_DP = 148
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
RES = "android/app/src/main/res"
LAUNCH = "ios/Runner/Assets.xcassets/LaunchImage.imageset"


def white_mark() -> Image.Image:
    src = np.asarray(
        Image.open("assets/branding/source/logo1.jpg").convert("RGB")
    ).astype(np.float32)
    bg = np.array([255, 247, 236], np.float32)  # crème du fond
    fg = np.array([253, 72, 45], np.float32)  # orange du trait
    t = ((bg[1] - src[..., 1]) / (bg[1] - fg[1]) + (bg[2] - src[..., 2]) / (bg[2] - fg[2])) / 2
    a = np.clip((np.clip(t, 0, 1) - 0.06) / 0.94, 0, 1)  # bruit JPEG du fond
    ys, xs = np.where(a > 0.02)
    a = a[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    rgba = np.zeros((*a.shape, 4), np.uint8)
    rgba[..., :3] = 255
    rgba[..., 3] = (a * 255 + 0.5).astype(np.uint8)
    return Image.fromarray(rgba)


def save_white(im: Image.Image, path: str) -> None:
    palette = Image.new("P", im.size)
    palette.putdata(list(im.getchannel("A").getdata()))
    palette.putpalette([255, 255, 255] * 256)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    palette.save(path, optimize=True, transparency=bytes(range(256)))
    print(path, im.size, os.path.getsize(path))


def logos() -> None:
    mark = white_mark()
    w, h = mark.size

    def fit(width: float) -> Image.Image:
        width = round(width)
        return mark.resize((width, round(width * h / w)), Image.LANCZOS)

    save_white(fit(LOGO_DP * 3), "assets/branding/logo_mark_white.png")
    for s in (1, 2, 3):
        suffix = "" if s == 1 else f"@{s}x"
        save_white(fit(LOGO_DP * s), f"{LAUNCH}/LaunchImage{suffix}.png")
    inner = LOGO_DP
    assert inner * math.hypot(1, h / w) <= 192, "le logo dépasse le cercle Android 12"
    for d, s in DENSITIES.items():
        save_white(fit(LOGO_DP * s), f"{RES}/drawable-{d}/splash_logo.png")
        canvas = round(288 * s)
        icon = Image.new("RGBA", (canvas, canvas), (255, 255, 255, 0))
        m = fit(inner * s)
        icon.paste(m, ((canvas - m.width) // 2, (canvas - m.height) // 2), m)
        save_white(icon, f"{RES}/drawable-{d}/android12_splash_logo.png")


ONBOARDING = {
    "assets/onb.jpeg": ("onb1", (56, 150, 556, 1024)),
    "assets/onb2.webp": ("onb2", (600, 0, 1430, 1024)),
    "assets/onb3.jpg": ("onb3", (360, 40, 940, 640)),
}


def onboarding() -> None:
    os.makedirs("assets/onboarding", exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for src, (name, box) in ONBOARDING.items():
            png = os.path.join(tmp, f"{name}.png")
            Image.open(src).convert("RGB").crop(box).save(png)
            out = f"assets/onboarding/{name}.webp"
            subprocess.run(["cwebp", "-quiet", "-q", "80", "-m", "6", png, "-o", out], check=True)
            print(out, os.path.getsize(out))


if __name__ == "__main__":
    logos()
    onboarding()
