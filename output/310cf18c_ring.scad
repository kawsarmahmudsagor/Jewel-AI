$fn = 64;

// =============================================================
// METAL & GEM COLORS
// =============================================================
ring_color  = "#FFD700";   // Yellow gold (shank and head body)
prong_color = "#E5E4E2";   // White gold / platinum (prongs)
stone_color = "#E8F4FF";   // Colorless diamond

// =============================================================
// RING BAND DIMENSIONS
// =============================================================
ring_inner_radius       = 8.25;   // mm
band_width_bottom       = 2.2;
band_width_shoulder     = 2.6;
band_width_near_setting = 2.8;
band_thickness_bottom   = 1.6;
band_thickness_shoulder = 1.7;
edge_fillet_radius      = 0.4;

// =============================================================
// Z POSITIONS  (from assemblyStack - never hardcoded)
// =============================================================
band_top_z      = 0;
band_bottom_z   = -1.7;
gallery_base_z  = 0;
gallery_top_z   = 3.5;
stone_girdle_z  = 3.5;
stone_table_z   = 4.5;
prong_tip_z     = 5.5;
halo_plane_z    = 0;

// =============================================================
// GALLERY / CATHEDRAL HEAD
// =============================================================
gallery_outer_radius_top = 3.6;   // > stone girdle radius 3.25
gallery_inner_radius_top = 3.3;   // >= stone girdle radius 3.25
gallery_wall_thickness   = 0.4;
gallery_window_count     = 0;
shoulder_rise_height     = 3.5;

// =============================================================
// CENTER STONE  (Round Brilliant)
// =============================================================
gem_girdle_diameter = 6.5;
gem_table_diameter  = 6.5 * 0.56;   // ~3.64 mm
gem_crown_height    = stone_table_z - stone_girdle_z;   // 1.0 mm
gem_pavilion_depth  = 6.5 * 0.43;   // ~2.795 mm

// =============================================================
// PRONGS
// =============================================================
prong_count                 = 4;
prong_thickness             = 0.6;
prong_base_radius           = 0.3;
prong_tip_radius            = 0.15;
prong_base_z                = stone_girdle_z;
prong_base_radial_offset    = 3.5;   // > gem_girdle_diameter/2 (3.25)
prong_tip_radial_offset     = 3.8;   // outward splay
prong_splay_angle           = 10;
prong_extension_above_stone = 1.0;
prong_angular_positions     = [0, 90, 180, 270];

// =============================================================
// MODULES
// =============================================================

module ring_band() {
    // Half-round band: flat inner edge, rounded outer corners, straight outer edge.
    inner_r  = ring_inner_radius;
    outer_r  = inner_r + band_thickness_shoulder;   // 9.95
    corner_r = edge_fillet_radius;                  // 0.4

    module profile_2d() {
        points = [];
        n = 16;

        // Inner flat edge (bottom -> top)
        points = concat(points, [
            [inner_r, band_bottom_z],
            [inner_r, band_top_z]
        ]);

        // Top short flat segment before top-right corner
        points = concat(points, [[outer_r - corner_r, band_top_z]]);

        // Top-right rounded corner (quarter circle)
        cx = outer_r - corner_r;
        cy = band_top_z - corner_r;
        for (i = [1:n]) {
            angle = 90 - (90 * i / n);
            x = cx + corner_r * cos(angle);
            y = cy + corner_r * sin(angle);
            points = concat(points, [[x, y]]);
        }

        // Right straight edge
        points = concat(points, [[outer_r, band_bottom_z + corner_r]]);

        // Bottom-right rounded corner (quarter circle)
        cx = outer_r - corner_r;
        cy = band_bottom_z + corner_r;
        for (i = [1:n]) {
            angle = 0 - (90 * i / n);
            x = cx + corner_r * cos(angle);
            y = cy + corner_r * sin(angle);
            points = concat(points, [[x, y]]);
        }

        // Bottom short flat segment (auto-closes back to first point)
        points = concat(points, [[outer_r - corner_r, band_bottom_z]]);

        polygon(points);
    }

    color(ring_color)
    rotate_extrude(angle = 360)
        profile_2d();
}

module gallery_head() {
    // Cathedral head: two swept shoulder wedges + basket ring.

    module shoulder(angle) {
        steps = 8;
        shoulder_half_arc_base = 28;   // degrees
        shoulder_half_arc_top  = 18;   // degrees

        hull() {
            for (i = [0:steps]) {
                t = i / steps;
                z = gallery_base_z + (gallery_top_z - gallery_base_z) * t;

                inner_r = ring_inner_radius +
                          (gallery_inner_radius_top - ring_inner_radius) * t;
                outer_r = (ring_inner_radius + band_thickness_shoulder) +
                          (gallery_outer_radius_top -
                           (ring_inner_radius + band_thickness_shoulder)) * t;

                half_arc = shoulder_half_arc_base +
                           (shoulder_half_arc_top - shoulder_half_arc_base) * t;

                pts = [
                    [inner_r * cos(angle - half_arc), inner_r * sin(angle - half_arc)],
                    [inner_r * cos(angle + half_arc), inner_r * sin(angle + half_arc)],
                    [outer_r * cos(angle + half_arc), outer_r * sin(angle + half_arc)],
                    [outer_r * cos(angle - half_arc), outer_r * sin(angle - half_arc)]
                ];

                translate([0, 0, z])
                    polygon(pts);
            }
        }
    }

    color(ring_color) {
        // Two cathedral shoulders (left and right of finger axis)
        shoulder(0);
        shoulder(180);

        // Basket ring (annular) sitting just below the stone girdle
        translate([0, 0, gallery_top_z - 0.4])
            linear_extrude(height = 0.4)
                difference() {
                    circle(r = gallery_outer_radius_top);
                    circle(r = gallery_inner_radius_top);
                }
    }
}

module prong(base_angle) {
    // Tapered claw: hull() between base sphere and tip sphere.
    base_x = prong_base_radial_offset * cos(base_angle);
    base_y = prong_base_radial_offset * sin(base_angle);
    tip_x  = prong_tip_radial_offset  * cos(base_angle);
    tip_y  = prong_tip_radial_offset  * sin(base_angle);

    color(prong_color)
    hull() {
        translate([base_x, base_y, prong_base_z])
            sphere(r = prong_base_radius);

        translate([tip_x, tip_y, prong_tip_z])
            sphere(r = prong_tip_radius);
    }
}

module center_stone() {
    // Round brilliant diamond.

    // Crown: truncated cone from girdle to table
    color(stone_color, alpha = 0.75)
    translate([0, 0, stone_girdle_z])
    cylinder(r1 = gem_girdle_diameter / 2,
             r2 = gem_table_diameter  / 2,
             h  = gem_crown_height);

    // Pavilion: cone from girdle to a point
    pavilion_tip_z = stone_girdle_z - gem_pavilion_depth;
    color(stone_color, alpha = 0.55)
    hull() {
        translate([0, 0, stone_girdle_z - 0.01])
            cylinder(r = gem_girdle_diameter / 2, h = 0.01);

        translate([0, 0, pavilion_tip_z])
            cylinder(r = 0.01, h = 0.01);
    }
}

// =============================================================
// ASSEMBLY
// =============================================================
union() {
    ring_band();
    gallery_head();
    for (a = prong_angular_positions) prong(a);
    center_stone();
}
