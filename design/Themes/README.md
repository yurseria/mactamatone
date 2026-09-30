# Theme artwork

These five theme strips were generated with the built-in image_gen tool from the user's references and the existing classic widget. The existing classic artwork remains unchanged.

The generated PNGs retain alpha. Run `swift scripts/prepare-theme-art.swift` from the repository root to identify the five instruments in each strip, remove disconnected alpha speckles, and place complete cutouts on 1024 × 1024 canvases. Output: `Sources/Mactamatone/Resources/Otamatone{Pink,Cat,Chick,Galaxy,Shiba}Level{0...4}.png`.

## Verification

Run `./build.sh` and `./scripts/verify-themes.sh` to check selection persistence, classic fallback for unknown stored identifiers, all 30 distinct transparent frames, unchanged pitch, and UI rendering. The checks compile the actual app sources with a separate entry point and only need Xcode Command Line Tools. Theme previews are saved under the ignored `dist/theme-previews/` directory.

## Prompt set

Shared specification for Pink, Cat, Chick and Galaxy:

Use case: stylized-concept. Asset type: one horizontal animation sprite strip for a macOS floating musical widget. Reference image 1 is design guide ONLY, use only the specified theme design. Reference image 2 is existing widget: use its straight vertical pose and near-front 3/4 camera. Create exactly FIVE full-body copies of the SAME theme instrument, evenly spaced in exactly five equal-width columns in a single row. Transparent background, isolated cutout, no floor, no shadows on ground, no labels, no borders, no text or musical notes. Entire instrument from curved music-note tip to bottom of round head is visible in EACH column with ample padding. ALL five copies must have IDENTICAL scale, vertical straight stem, tip shape, head center, eye positions, lighting, decorations and camera. Only change the mouth opening: column 1 completely closed thin seam, column 2 slightly open narrow dark slit, column 3 half-open oval mouth, column 4 wide open, column 5 maximum open oval mouth. Do not tilt or squash whole instrument between columns. High quality soft studio 3D toy product render matching design guide, clean edge alpha. Canvas landscape 2560x1280, each cell 512x1280. Ball head diameter about 320 pixels, entire instrument height about 1100 pixels, head sits centered in lower portion. Exactly five instruments, no cropped tips or missing bottom edges.

Theme subjects:

- pink: pastel pink cherry blossom Otamatone, pink stem, black touch strip, small white pink cherry blossom flowers on right cheek and curled tip
- cat: matte black cat Otamatone, black stem and black touch strip, two triangular black ears with pink interiors above ball head, white round eyes, white short whiskers, tiny white paw print on curled tip
- chick: bright warm yellow chick Otamatone, yellow stem, black touch strip, black round eyes and small orange beak centered just above mouth seam
- galaxy: glossy cobalt blue violet galaxy Otamatone, blue stem, black touch strip, black eyes, subtle nebula pink cyan gradients and tiny scattered stars and ringed planets on ball head, gold star charm hanging from curled tip

Shiba prompt:

Use case: stylized-concept. Asset type: one horizontal animation sprite strip for a macOS floating musical widget. Reference image 1 is the user's SHIBA INU face design and must be matched: warm golden tan spherical head, cream white lower muzzle and jaw, two upright triangular tan ears with cream inner ears, black round eyes, two cream eyebrow dots, tiny centered black oval nose. Reference image 2 is the full-body existing Otamatone; use this straight vertical music-note instrument geometry and near-front 3/4 camera with a long golden tan stem, black touch strip and curled note tip. Exactly FIVE full-body copies of the SAME Shiba Inu Otamatone evenly spaced in exactly five equal-width columns in a single horizontal row. Transparent background, no floor or ground shadows, no text, no borders, no extra objects. Entire instrument visible from curled tip to bottom of spherical head in every column, generous transparent padding. ALL five copies must have IDENTICAL scale, pose, head center, eye and ear positions, lighting, decorations and camera. Only mouth opening changes: column 1 closed thin seam, column 2 slight narrow dark slit, column 3 half-open oval mouth, column 4 wide open mouth, column 5 maximum open mouth. Keep nose and eyebrows fixed above mouth. Clean polished soft studio 3D toy product render. Canvas landscape 2560x1280, five columns of 512x1280 each. Ball head diameter about 320 pixels, full instrument height about 1100 pixels, straight upright stem. No cropped tips or missing bottom edges. Background must be true transparency with clean antialiased edges, NO disconnected pixel speckles.
