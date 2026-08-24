# Prompt AI untuk Maskot PiRa

Spesifikasi untuk membuat maskot **PiRa** (kaPI baRa) — kapibara berendam di
bak, maskot aplikasi **uangku**.

---

## Batasan yang tidak boleh dilanggar

Maskot ini tampil **54×54 piksel** di kartu saldo beranda. Itu ukuran kuku jari.
Sebagian besar maskot buatan AI gagal di sini: hasilnya cantik di 1024px lalu
jadi bubur waktu dikecilkan. Karena itu gaya datar bergaris tebal bukan selera,
tapi syarat.

### Palet resmi aplikasi (jangan improvisasi)

| Peran | Hex | Nama di kode |
|---|---|---|
| Garis luar & tinta | `#1E1E1E` | `borderColor` |
| Bulu PiRa | `#C98A5B` | `piraFur` |
| Air | `#8EC5FF` | `neoBlue` |
| Jeruk yuzu | `#FFD84D` | `neoYellow` |
| Bagian dalam bak | `#FFFCF5` | `neoPaper` |
| Latar kartu saldo | `#98E6A8` | `neoMint` |

Latar kartunya mint terang **di mode gelap maupun terang**, jadi maskotnya
tidak perlu versi gelap — tapi harus tetap terbaca di atas mint.

---

## Prompt utama (Bahasa Inggris — model gambar lebih akurat dengannya)

```
Flat vector mascot illustration of a capybara relaxing in a Japanese onsen tub,
front view, perfectly symmetrical, centered.

CHARACTER ANATOMY — this is a CAPYBARA, not a bear, hamster, or dog:
- Head is a BLOCKY ROUNDED RECTANGLE with a flat top, wider than it is tall
- Ears are TINY, round, and sit flush at the top corners of the head
- Eyes are SMALL dots placed HIGH on the head and WIDE apart, in the upper third
- Blunt, broad muzzle in the SAME brown as the fur — absolutely no white or
  cream muzzle patch
- Two small nostril dots, a tiny closed mouth, no visible teeth, no grin
- Calm, sleepy, unbothered expression

SCENE:
- Capybara sits chest-deep inside a deep wooden soaking tub
- The tub's front wall is opaque and hides the body below the rim
- A single round yellow yuzu fruit balanced on top of the head, no leaf or stem
- Two thin curls of steam rising on the left and right, outside the tub

STYLE:
- Flat 2D vector, neo-brutalist sticker art
- Uniform thick black outlines (#1E1E1E), same stroke weight on every shape
- Solid flat fills only — NO gradients, NO shading, NO texture, NO highlights
- Bold simple silhouette that stays readable when scaled down to 48 pixels
- Generous rounded corners, chunky geometric shapes

COLORS (exact):
- fur #C98A5B, outlines #1E1E1E, water #8EC5FF, yuzu #FFD84D, tub interior #FFFCF5

OUTPUT:
- Transparent background, square 1:1, centered with even margin, 1024x1024
```

### Negative prompt

```
realistic, photorealistic, 3D render, fur texture, hair strands, gradient,
soft shading, drop shadow, glow, watercolor, sketch lines, cross-hatching,
bear, teddy bear, hamster, guinea pig, dog, mouse, beaver,
white muzzle patch, big round bear ears, visible teeth, wide grin, tongue,
angry eyebrows, panicked expression, tears,
busy background, scenery, text, watermark, signature, multiple characters
```

---

## Tiga varian suasana

Wajah PiRa adalah data, bukan hiasan: ia mengikuti rasio pengeluaran terhadap
pemasukan. Tambahkan blok berikut ke prompt utama, satu per gambar.

### 1. `santai` — belanja di bawah 70%

```
Eyes closed in two content downward curves. Yuzu sitting upright and centered
on top of the head. Two curls of steam. Tub filled to the brim with water.
Serene, blissful.
```

### 2. `hatiHati` — belanja 70–100%

```
Eyes open as two small dots, alert but not alarmed. Yuzu slipping off toward
the right side of the head, about to fall. No steam. Water only about
one quarter full. Mildly watchful.
```

### 3. `lewatBatas` — belanja di atas 100%

```
Eyes open as two small dots. A single blue sweat drop beside the head.
Still completely calm — NO angry eyebrows, NO panic, NO tears. The yuzu has
fallen and rests on the dry floor of the tub. The tub is empty, no water.
Stoic and unbothered despite the situation.
```

**Kenapa varian ketiga tetap tenang:** aplikasi keuangan yang menghakimi bikin
orang berhenti mencatat, dan begitu berhenti mencatat, aplikasinya jadi tidak
berguna. Kapibara yang tetap kalem waktu saldonya menipis berkata "masih bisa
dibenahi", bukan "kamu gagal". Kalau AI-nya ngotot menggambar wajah panik,
pertahankan baris ini di prompt.

---

## Menjaga ketiganya tetap satu karakter

Ini bagian tersulit — tiga kali generate biasanya menghasilkan tiga kapibara
yang berbeda. Urutan yang berhasil:

1. **Buat varian `santai` dulu** sampai benar-benar puas. Itu jadi acuan.
2. **Pakai gambar itu sebagai referensi** untuk dua varian lain:
   - Midjourney: `--cref <url-gambar> --cw 100` (`cw 100` mengunci wajah)
   - Nano Banana / Gemini: unggah gambarnya, minta *"keep this exact character,
     change only the eyes, the yuzu position, and the water level"*
   - Stable Diffusion: seed yang sama + IP-Adapter
3. **Jangan generate ulang dari nol** untuk varian 2 dan 3. Selalu berangkat
   dari gambar acuan.
4. **Uji kecil sejak awal:** kecilkan hasilnya jadi 54px dan lihat. Kalau
   wajahnya hilang, minta *"simplify, fewer details, thicker outlines"* —
   bukan menambah detail.

---

## Cara yang saya sarankan: bagi tugas

Alih-alih tiga gambar utuh, **minta PiRa-nya saja** — kepala dan badan dengan
latar transparan, tanpa bak dan tanpa air — lalu biarkan bak dan airnya tetap
digambar kode.

Alasannya bukan soal selera:

- **Tinggi air harus bisa di angka berapa pun.** Air adalah sisa uangmu. Tiga
  gambar tetap cuma bisa menampilkan tiga tinggi air; kode bisa menampilkan
  63%. Kalau baknya jadi gambar, mekanisme "air = sisa uang" hilang dan
  maskotnya turun pangkat jadi stiker.
- **Konsistensi jadi gampang.** Cuma karakternya yang perlu sama antar varian,
  dan baknya dijamin identik karena digambar rumus yang sama.
- **Asetnya lebih ringan** — tiga potong karakter kecil, bukan tiga adegan.

Untuk jalur ini, buang bagian `SCENE` dari prompt utama dan ganti dengan:

```
SCENE:
- Only the capybara's head and upper chest, cut off cleanly at chest level
- A single round yellow yuzu fruit balanced on top of the head, no leaf
- No tub, no water, no steam, no background — transparent
```

Bak, air, uap, dan jeruk yang jatuh tetap ditangani
[`pira_mascot.dart`](../lib/widgets/dashboard/pira_mascot.dart).

---

## Setelah gambarnya jadi

1. Ekspor **PNG transparan** (atau SVG kalau modelnya bisa) di `1024×1024`.
2. Simpan di `assets/mascot/pira_santai.png`, `pira_hati_hati.png`,
   `pira_lewat_batas.png`.
3. Daftarkan foldernya di `pubspec.yaml` pada bagian `flutter: assets:`.
4. Ganti isi `PiraMascot.build` agar memuat gambar sesuai `mood`. Label
   `Semantics` dan `moodForRatio` **tidak perlu diubah** — keduanya tidak
   bergantung pada cara maskotnya digambar.

Kalau gambarnya sudah ada, saya bisa langsung memasangnya.

---

# Memecah Gambar Jadi Lapisan (untuk Rive)

Dipakai kalau maskotnya mau dianimasikan dengan Rive. Semua prompt di bawah
adalah **perintah sunting** terhadap gambar yang sudah ada, bukan perintah
menggambar baru.

## Aturan main yang menentukan berhasil-tidaknya

**Minta menghapus, jangan minta menggambar.** Kalau kamu bilang "gambarkan
kapibaranya saja", model akan menggambar ulang dari nol — hasilnya bergeser,
beda ukuran, dan lapisannya tidak akan pas saat ditumpuk. Kalau kamu bilang
"hapus semua kecuali kapibaranya, jangan pindahkan apa pun", posisinya
terjaga.

**Selalu berangkat dari gambar sumber yang sama.** Unggah ulang gambar
aslinya di tiap permintaan. Jangan menyunting hasil suntingan.

## Pakai gambar bak kering sebagai sumber

Dari tiga gambar yang ada, pakai **yang baknya kosong dan badan kapibaranya
terlihat utuh**. Dua gambar lainnya adalah *hasil* — tampilan yang nanti
dihasilkan sendiri oleh mesin animasinya saat air naik. Badan yang utuh justru
bahan mentah yang tidak bisa dikarang balik.

## Jangan minta semuanya ke AI

Empat lapisan ini **lebih cepat digambar langsung di Rive** daripada
di-generate lalu dirapikan:

| Lapisan | Kenapa digambar sendiri |
|---|---|
| Air | Cuma persegi dengan tepi bergelombang. Harus jadi *shape* Rive supaya tingginya bisa dianimasikan |
| Uap | Dua kurva. Digambar sendiri lebih presisi dan bisa diberi gerak |
| Tetes keringat | Satu bentuk tetesan |
| Mata | Dua titik dan dua kurva. Perlu jadi shape terpisah supaya bisa berkedip |

Jadi yang diminta ke Nano Banana **cuma tiga**: kapibara, bak, dan jeruk.

---

## Prompt 1 — Kapibara utuh

Unggah gambar sumber, lalu:

```
Using the attached image, keep ONLY the capybara. Completely remove the wooden
tub, the water, the yuzu fruit, the sweat drop, and the steam.

CRITICAL — do not redraw, do not reposition, do not resize:
The capybara must remain at the EXACT same position, scale, rotation and pose
as in the source image. Only reconstruct the parts of its body that were
hidden behind the tub's front wall, continuing the existing outline and the
flat brown fill naturally so the body reads as complete.

Preserve the identical outline weight, outline color, and flat fill colors.
No shading, no gradient, no texture, no drop shadow.

Output: transparent background, same square canvas and same resolution as the
source image.
```

## Prompt 2 — Bak kosong

Unggah **gambar sumber yang sama**, lalu:

```
Using the attached image, keep ONLY the wooden tub. Completely remove the
capybara, the water, the yuzu fruit, the sweat drop, and the steam.

CRITICAL — do not redraw, do not reposition, do not resize:
The tub must remain at the EXACT same position, scale and rotation as in the
source image. Reconstruct the parts of the tub that were hidden behind the
capybara — the far rim and the inner back wall — continuing the existing plank
lines and outline naturally, so the tub reads as a complete empty tub seen
from the same angle.

Preserve the identical outline weight, outline color, plank pattern, and flat
fill colors.

Output: transparent background, same square canvas and same resolution as the
source image.
```

## Prompt 3 — Jeruk yuzu

```
Using the attached image, keep ONLY the yellow yuzu fruit together with its
green leaf. Remove everything else.

Place it in the center of the canvas at a comfortable size. Preserve the
identical outline weight, outline color, and flat fill colors from the source.

Output: transparent background, square canvas.
```

---

## Wajib diperiksa sebelum lanjut

1. **Tumpuk ulang lapisannya** di editor gambar apa pun, dengan urutan:
   `bak` di belakang, `kapibara` di atasnya. Hasilnya harus **persis** seperti
   gambar sumber. Kalau meleset walau sedikit, mintakan perbaikan:

   ```
   The capybara shifted position compared to the source image. Redo the edit
   and keep it pixel-aligned with the original — same position, same scale,
   same rotation. Only erase the surroundings.
   ```

2. **Periksa bagian badan yang direkonstruksi.** Bagian kapibara yang tadinya
   tertutup dinding bak adalah tebakan model. Kalau bentuknya aneh, tidak
   masalah — bagian itu memang akan tertutup air atau dinding bak lagi nanti.
   Yang penting siluetnya tidak terpotong mendadak.

3. **Kecilkan jadi 54px dan lihat.** Kalau wajahnya hilang di ukuran itu,
   masalahnya ada di gambarnya, bukan di animasinya — dan tidak akan tertolong
   oleh Rive.

## Setelah lapisannya jadi

1. **Vektorkan** ketiganya (Illustrator Image Trace, Vectorizer.ai, atau
   Inkscape), lalu sederhanakan titiknya. Rive butuh vektor — PNG hanya bisa
   digeser dan diputar, tidak bisa dipotong oleh air.
2. **Belah baknya jadi dua** di editor vektor: `tub_back` dan `tub_front`,
   dipotong mengikuti garis pelek. Ini mudah bagi manusia dan sulit bagi AI —
   jangan diminta ke model.
3. Susun di Rive dengan urutan:
   `tub_back` → `capybara` → `water` → `tub_front` → `yuzu` / `steam` / `sweat`

Tanpa `tub_front` yang terpisah, PiRa akan terlihat menempel di depan bak,
bukan duduk di dalamnya.
