// Cathedral Solitaire Engagement Ring - OpenSCAD procedural model
// Coordinate system: ring center at origin, finger-hole axis along Y (horizontal),
// stone and head assembly at +Z (up). All head Z values derived from band_apex_z
// using assemblyStack offsets.

$fn = 64;

// ============================================
// COLORS
// ============================================
ring_color  = "#D4AF37";  // warm gold
prong_color = "#D4AF37";
stone_color = "#E8F4FF";  // near-colorless diamond

// ============================================
// BAND PARAMETERS
// ============================================
ring_inner_radius     = 8.25;
ring_inner_diameter   = 16.50;
band_tube_radius      = 0.85;   // round cross-section radius (= thickness/2)
band_outer_radius     = ring_inner_radius + band_tube_radius;  // 9.10
band_width_shoulder   = 2.0;
band_thickness_shoulder = 1.7;

// ============================================
// CATHEDRAL SHOULDER PARAMETERS
// ============================================
shoulder_outer_x      = 2.5;    // X offset where shoulder meets band top
shoulder_inner_x      = 1.3;    // X offset where shoulder meets cup base
shoulder_radius       = 0.55;   // cross-section sphere radius
shoulder_arch_boost   = 0.5;    // additional upward arch above linear path

// ============================================
// GALLERY CUP PARAMETERS
// ============================================
cup_height            = 1.6;
cup_base_outer_r      = 1.7;
cup_top_outer_r       = 2.7;
cup_top_inner_r       = 2.5;    // == gem_girdle_diameter / 2 (flush seat)
cup_wall_thickness    = 0.3;

// ============================================
// PRONG PARAMETERS
// ============================================
prong_count              = 4;
prong_base_radius        = 0.30;
prong_tip_radius         = 0.18;
prong_base_radial        = 2.15; // base radial offset from center axis
prong_tip_radial         = 1.90; // tip radial offset (inward claw)
prong_extension_below    = 0.6;  // how far base sinks below girdle into cup
prong_extension_above_stone = 1.0;
prong_splay_degrees      = 5;

// ============================================
// CENTER STONE PARAMETERS
// ============================================
gem_girdle_diameter   = 5.0;
gem_table_diameter     = 3.4;
gem_crown_height       = 0.8;
gem_pavilion_depth     = 2.15;
gem_radius             = gem_girdle_diameter / 2;
gem_table_radius       = gem_table_diameter / 2;

// ============================================
// ASSEMBLY STACK (relative to bandTopZ)
// ============================================
bandTopZ       = 0;
galleryTopZ    = 3.5;
stoneGirdleZ   = 3.5;
stoneTableZ    = 4.3;
prongTipZ      = 5.3;

// ============================================
// DERIVED WORLD-Z ANCHORS (band_apex_z + stack offset)
// ============================================
band_apex_z    = ring_inner_radius + band_tube_radius;          // 9.10
gallery_top_z  = band_apex_z + (galleryTopZ  - bandTopZ);       // 12.60
stone_girdle_z = band_apex_z + (stoneGirdleZ - bandTopZ);       // 12.60
stone_table_z  = band_apex_z + (stoneTableZ  - bandTopZ);       // 13.40
prong_tip_z    = band_apex_z + (prongTipZ    - bandTopZ);       // 14.40

// Cup Z values (cup top aligns with gallery_top_z / stone girdle)
cup_top_z   = gallery_top_z;          // 12.60
cup_base_z  = cup_top_z - cup_height; // 11.00

// Shoulder Z values (start sinks into band, end meets cup base)
shoulder_start_z = band_apex_z - 0.3; // 8.80
shoulder_end_z   = cup_base_z;        // 11.00

// Stone pavilion tip (below girdle)
pavilion_tip_z = stone_girdle_z - gem_pavilion_depth;  // 10.45

// ============================================
// MODULES
// ============================================

module ring_band() {
    // Round cross-section band, swept around Y axis (horizontal finger hole).
    // The band profile is a single circle translated to the band centerline.
    color(ring_color)
    rotate([90, 0, 0])
        rotate_extrude(angle = 360)
            translate([ring_inner_radius + band_tube_radius, 0, 0])
                circle(r = band_tube_radius);
}

module cathedral_shoulder(side) {
    // Arched shoulder from band top to cup base.
    // side: +1 (right, +X) or -1 (left, -X).
    // Built as hull() over a chain of sphere cross-sections along an arched path.
    n = 12;

    module shoulder_segment(t) {
        // t in [0, 1]: 0 = at band, 1 = at cup base
        x = shoulder_outer_x * (1 - t) + shoulder_inner_x * t;
        z_linear = shoulder_start_z * (1 - t) + shoulder_end_z * t;
        z_arch   = shoulder_arch_boost * sin(t * 90);
        z = z_linear + z_arch;
        r = shoulder_radius * (1 - 0.15 * t);

        translate([side * x, 0, z])
            sphere(r = r, $fn = 20);
    }

    color(ring_color)
    hull() {
        for (i = [0:n]) {
            shoulder_segment(i / n);
        }
    }
}

module gallery_cup() {
    // Tapered cup that holds the prongs and seats the stone.
    // Outer shell minus inner cavity (difference).
    color(ring_color)
    difference() {
        // Outer shell: tapered cylinder, base sinks below band for fusion
        translate([0, 0, cup_base_z])
            cylinder(
                r1 = cup_base_outer_r,
                r2 = cup_top_outer_r,
                h  = cup_height + 0.2,
                $fn = 48
            );

        // Inner cavity: tapered to match stone girdle diameter at top
        translate([0, 0, cup_base_z - 0.1])
            cylinder(
                r1 = cup_base_outer_r - cup_wall_thickness,
                r2 = cup_top_inner_r,
                h  = cup_height + 0.4,
                $fn = 48
            );
    }
}

module prong_at_angle(angle) {
    // Single tapered prong, oriented at given angle around Z.
    base_z = stone_girdle_z - prong_extension_below;  // embedded below girdle
    tip_z  = prong_tip_z;                             // above stone table

    color(prong_color)
    rotate([0, 0, angle])
    hull() {
        // Base sphere (larger, embedded in cup wall)
        translate([prong_base_radial, 0, base_z])
            sphere(r = prong_base_radius, $fn = 20);

        // Tip sphere (smaller, claw-like, above stone table)
        translate([prong_tip_radial, 0, tip_z])
            sphere(r = prong_tip_radius, $fn = 20);
    }
}

module center_stone() {
    // Round brilliant approximation: crown + pavilion as stacked cylinders.
    color(stone_color)
    union() {
        // Crown: girdle diameter to table diameter
        translate([0, 0, stone_girdle_z])
            cylinder(
                r1 = gem_radius,
                r2 = gem_table_radius,
                h  = gem_crown_height,
                $fn = 48
            );

        // Pavilion: near-point tip up to girdle diameter
        translate([0, 0, pavilion_tip_z])
            cylinder(
                r1 = 0.01,
                r2 = gem_radius,
                h  = gem_pavilion_depth,
                $fn = 48
            );
    }
}

// ============================================
// ASSEMBLY
// ============================================
union() {
    // Band forms the base; finger hole is the swept profile's inner wall
    ring_band();

    // Cathedral shoulders rise from band to cup base
    cathedral_shoulder( 1);
    cathedral_shoulder(-1);

    // Gallery cup at the top of the shoulders
    gallery_cup();

    // Four prongs at 0, 90, 180, 270 degrees
    for (a = [0, 90, 180, 270]) {
        prong_at_angle(a);
    }

    // Center stone
    center_stone();
}
