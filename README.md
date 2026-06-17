# Jewel-AI

A two-stage AI pipeline that takes a photograph of a ring and generates parametric [OpenSCAD](https://openscad.org/) code ready for 3D rendering or printing. Upload an image, get back a structured analysis and a fully procedural `.scad` file.

---

## How It Works

The pipeline runs in two sequential model calls, both powered by **MiniMax M3** via [OpenRouter](https://openrouter.ai/).

```
Ring Image
    │
    ▼
┌─────────────────────────────────────────────┐
│  Call 1 — Vision (MiniMax M3)               │
│                                             │
│  • Detects photo angle and foreshortening   │
│  • Extracts assembly stack Z-map            │
│    (bandTopZ, galleryTopZ, stoneGirdleZ…)   │
│  • Identifies band style, cross-section,    │
│    split shank geometry, taper profile      │
│  • Counts and positions prongs              │
│  • Measures gallery dimensions              │
│  • Detects pavé, side stones, decorative    │
│    features (milgrain, filigree, engraving) │
│  • Estimates gemstone type and color hex    │
│                                             │
│  Output → Structured analysis JSON          │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│  Call 2 — Text (MiniMax M3)                 │
│                                             │
│  • Reasons through a CAD Construction Guide │
│    (bandApproach, prongApproach, etc.)      │
│  • Fills OpenSCAD CAD parameters (section 9)│
│  • Generates a single flat .scad file with: │
│    - Named variables for every dimension    │
│    - Modules: ring_band, gallery_head,      │
│      prong, center_stone, pave_stone        │
│    - for() loops for prongs and pavé stones │
│    - color() per part (metal / stone)       │
│    - Z positions locked to assembly stack   │
│    - union() / difference() assembly        │
│                                             │
│  Output → section_9 JSON + .scad code       │
└─────────────────────────────────────────────┘
    │
    ▼
Saved to output/
  <run_id>_analysis.json
  <run_id>_ring.scad
```

---

## Analysis Schema

The vision model fills a 9-section expert analysis questionnaire:

| Section | Content |
|---------|---------|
| 1 | General component inventory (name, type, position, dimensions) |
| 2 | Ring band geometry (inner radius, width, thickness, taper, cross-section, curves) |
| 3 | Band style classification (single shank, split shank, cathedral, twisted, bypass…) |
| 4 | Pavé / accent stone analysis (count, positions, diameter, setting style) |
| 5 | Center stone analysis (shape, cut, dimensions, prong geometry, setting type) |
| 6 | Side stone analysis (count, shape, position, setting) |
| 7 | Gallery / head assembly (basket style, rails, windows, cathedral shoulders) |
| 8 | Component relationship mapping (parent → child hierarchy) |
| 9 | CAD reconstruction parameters (OpenSCAD primitives, booleans, transforms, construction guide) |

In addition to the schema, the extraction step outputs three supplemental objects:

- **`assemblyStack`** — authoritative Z positions (`bandTopZ`, `galleryTopZ`, `stoneGirdleZ`, `prongTipZ`, etc.) used to anchor all vertical geometry in the generated code
- **`photoContext`** — view angle, tilt, foreshortening notes, and which components were fully/partially/not visible
- **`gemstoneColor`** — identified stone type, color name, and a hex value used as the default `stone_color` parameter in the `.scad` file

---

## Generated OpenSCAD Structure

The output is a single flat `.scad` file structured as follows:

```openscad
// ── Parameters ──────────────────────────────────
$fn = 64;
ring_inner_radius     = 8.25;   // mm
band_width_bottom     = 2.0;
band_thickness_bottom = 1.4;
prong_count           = 6;
prong_base_radius     = 0.7;
prong_tip_radius      = 0.45;
gem_girdle_diameter   = 7.0;
stone_color           = "#E8F4FF";
ring_color            = "#E8E8E8";
// … all other parameters …

// ── Modules ─────────────────────────────────────
module ring_band() { … }        // rotate_extrude of 2D profile
module gallery_head() { … }     // basket with hull() wire columns
module prong(base_angle) { … }  // hull() tapered cylinder pair
module center_stone() { … }     // crown + pavilion geometry
module pave_stone(x, y, z) { … }

// ── Assembly ─────────────────────────────────────
union() {
  color(ring_color)  difference() { ring_band(); /* finger hole */ }
  color(ring_color)  gallery_head();
  color(prong_color) for(a = [0,60,120,180,240,300]) rotate([0,0,a]) prong(a);
  color(stone_color) center_stone();
}
```

---

## Project Structure

```
Jewel-AI/
├── main.py              # FastAPI app — POST /generate, GET /health
├── extractor.py         # Call 1: encodes image, calls MiniMax vision, returns analysis JSON
├── generator.py         # Call 2: takes analysis JSON, returns section 9 + .scad code
├── prompts/
│   ├── extraction.txt   # System prompt for the vision model
│   └── generation.txt   # System prompt for the code generation model
├── schema/
│   └── questionnaire.json   # 9-section expert analysis template
├── output/              # Generated files saved here (gitignored)
├── .env.example         # Environment variable template
├── requirements.txt
└── README.md
```

---

## Setup

### 1. Clone and install dependencies

```bash
pip install -r requirements.txt
```

### 2. Configure environment

```bash
cp .env.example .env
```

Edit `.env`:

```env
OPENROUTER_API_KEY=your_openrouter_api_key_here
OPENROUTER_MODEL=minimax/minimax-m3
```

Get an API key at [openrouter.ai/keys](https://openrouter.ai/keys).

### 3. Start the server

```bash
uvicorn main:app --reload
```

The API will be available at `http://localhost:8000`.

---

## API Reference

### `POST /generate`

Upload a ring image and receive the full analysis and generated OpenSCAD code.

**Request**

```
Content-Type: multipart/form-data
Field: image  (JPEG, PNG, or WebP)
```

**Example — curl**

```bash
curl -X POST http://localhost:8000/generate \
  -F "image=@my_ring.jpg"
```

**Example — Python**

```python
import requests

with open("my_ring.jpg", "rb") as f:
    response = requests.post(
        "http://localhost:8000/generate",
        files={"image": ("my_ring.jpg", f, "image/jpeg")}
    )

data = response.json()
print(data["scad_code"])
```

**Response**

```json
{
  "run_id": "a3f9c12b",
  "analysis": {
    "expertAnalysisQuestionnaire": { "sections": { "1_general…": {}, "…": {} } },
    "assemblyStack": {
      "bandTopZ": 0,
      "bandBottomZ": -2.5,
      "galleryTopZ": 4.5,
      "stoneGirdleZ": 4.5,
      "stoneTableZ": 5.6,
      "prongTipZ": 6.8
    },
    "gemstoneColor": { "colorName": "colorless", "colorHex": "#E8F4FF" },
    "photoContext": { "viewAngle": "three_quarter" }
  },
  "scad_code": "$fn = 64;\nring_inner_radius = 8.25;\n…",
  "saved_analysis": "output/a3f9c12b_analysis.json",
  "saved_scad": "output/a3f9c12b_ring.scad"
}
```

| Field | Description |
|-------|-------------|
| `run_id` | Unique 8-character identifier for this run |
| `analysis` | Full structured analysis: all 9 schema sections, assembly stack, gemstone color, photo context |
| `scad_code` | Complete OpenSCAD source code as a string |
| `saved_analysis` | Path to the saved analysis JSON on disk |
| `saved_scad` | Path to the saved `.scad` file on disk |

### `GET /health`

```bash
curl http://localhost:8000/health
# { "status": "ok" }
```

---

## Using the Generated OpenSCAD

1. Install [OpenSCAD](https://openscad.org/downloads.html)
2. Open the `.scad` file from the `output/` directory
3. Press **F5** to preview or **F6** to render
4. Use the Customizer panel (Window → Customizer) to adjust any named variable live
5. Export to STL via **File → Export → Export as STL** for 3D printing

---

## Limitations

- Accuracy depends on image quality and camera angle. A three-quarter or side-profile shot with good lighting produces the most accurate measurements.
- Hidden components (underside of gallery, inner band profile) are estimated using industry-standard defaults.
- Very complex or highly irregular custom designs may produce simplified geometry.
- The generated `.scad` is a faithful parametric approximation, not a photogrammetric reconstruction.
