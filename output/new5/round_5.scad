//$fn = 48;

ring_color  = "#E5E4E2"; // Platinum/White Gold
prong_color = "#E5E4E2";
stone_color = "#E8F4FF";

ring_inner_radius   = 8.25;
band_apex_z         = 9.35;
gallery_top_z       = 13.55;
stone_girdle_z      = 13.55;
stone_table_z       = 14.792;
prong_tip_z         = 15.05;
gem_radius          = 3.75;
gem_table_radius    = 2.1;

// Helper function to calculate the outer radius of the curved band profile at any Y offset
function band_outer_radius(y) = sqrt(max(0, 6.97 - y*y)) + 7.80;

// Helper module to position children on the curved outer surface of the band
module on_band_surface(y, angle) {
    r_val = band_outer_radius(y);
    rotate([0, angle, 0])
        translate([0, y, r_val])
            children();
}

// Fast round chain replacement for hull() of spheres to prevent timeouts
module fast_round_chain(pts) {
    for (i = [0 : len(pts) - 1]) {
        translate([pts[i][0], pts[i][1], pts[i][2]])
            sphere(r = pts[i][3], $fn = 12);
    }
    for (i = [0 : len(pts) - 2]) {
        p1 = [pts[i][0], pts[i][1], pts[i][2]];
        p2 = [pts[i+1][0], pts[i+1][1], pts[i+1][2]];
        r1 = pts[i][3];
        r2 = pts[i+1][3];
        
        dir = p2 - p1;
        h = norm(dir);
        if (h > 0) {
            translate(p1)
            rotate([0, acos(dir[2]/h), atan2(dir[1], dir[0])])
                cylinder(r1 = r1, r2 = r2, h = h, $fn = 12);
        }
    }
}

// Realistic gemstone geometry for pavé stones
module pave_stone_geometry(r=0.55) {
    // Crown
    translate([0, 0, 0])
        cylinder(r1 = r, r2 = r * 0.6, h = r * 0.4, $fn = 8);
    // Pavilion
    translate([0, 0, 0])
        mirror([0, 0, 1])
            cylinder(r1 = r, r2 = 0.01, h = r * 0.8, $fn = 8);
}

module pave_cutters() {
    y_offsets = [-1.4, 0, 1.4];
    for (y = y_offsets) {
        for (theta = [15 : 7.5 : 75]) {
            for (sign = [-1, 1]) {
                angle = theta * sign;
                on_band_surface(y, angle)
                    translate([0, 0, -0.8]) // cut deep into the band
                        cylinder(r = 0.58, h = 1.2, $fn = 12);
            } 
        } 
    }
}

module inner_pierce_cuts() {
    y_offsets = [-1.4, 0, 1.4];
    for (y = y_offsets) {
        for (theta = [15 : 7.5 : 75]) {
            for (sign = [-1, 1]) {
                angle = theta * sign;
                rotate([0, angle, 0])
                    translate([0, y, 8.25]) // at the inner radius
                        rotate([0, 0, 45]) // diamond shape
                            cylinder(r1 = 0.45, r2 = 0.2, h = 1.5, center = true, $fn = 4);
            } 
        }
    }
}

module ring_band() {
    color(ring_color)
    difference() {
        // Main band
        rotate([90, 0, 0])
            rotate_extrude(angle = 360, $fn = 64)
                polygon([[8.25, -2.6], [8.6121, -2.5645], [8.9643, -2.4591], [9.2971, -2.2866], [9.6013, -2.0518], [9.8686, -1.7609], [10.0918, -1.4221], [10.2647, -1.0444], [10.3827, -0.6383], [10.4425, -0.2147], [10.4425, 0.2147], [10.3827, 0.6383], [10.2647, 1.0444], [10.0918, 1.4221], [9.8686, 1.7609], [9.6013, 2.0518], [9.2971, 2.2866], [8.9643, 2.4591], [8.6121, 2.5645], [8.25, 2.6], [8.2173, 2.5645], [8.1854, 2.4591], [8.1554, 2.2866], [8.1279, 2.0518], [8.1037, 1.7609], [8.0836, 1.4221], [8.0679, 1.0444], [8.0573, 0.6383], [8.0519, 0.2147], [8.0519, -0.2147], [8.0573, -0.6383], [8.0679, -1.0444], [8.0836, -1.4221], [8.1037, -1.7609], [8.1279, -2.0518], [8.1554, -2.2866], [8.1854, -2.4591], [8.2173, -2.5645]]);

        // Subtract pave cutters
        pave_cutters();

        // Subtract inner pierce cuts
        inner_pierce_cuts();
    }
}

module gallery_rings() {
    color(ring_color) {
        // Bottom ring
        translate([0, 0, 9.35])
            difference() {
                cylinder(r = 2.4, h = 0.6, $fn = 32);
                translate([0, 0, -0.1])
                    cylinder(r = 1.8, h = 0.8, $fn = 32);
            }
        // Top ring (just below the girdle)
        translate([0, 0, 13.1])
            difference() {
                cylinder(r = 3.8, h = 0.5, $fn = 32);
                translate([0, 0, -0.1])
                    cylinder(r = 3.3, h = 0.7, $fn = 32);
            }
    }
}

module filigree_petal(angle) {
    color(ring_color)
    rotate([0, 0, angle]) {
        pts1 = [
            [1.8, 0, 9.35, 0.2],
            [2.8, 0.8, 10.5, 0.18],
            [3.5, 1.2, 12.0, 0.16],
            [3.7, 0, 13.25, 0.14]
        ];
        pts2 = [
            [1.8, 0, 9.35, 0.2],
            [2.8, -0.8, 10.5, 0.18],
            [3.5, -1.2, 12.0, 0.16],
            [3.7, 0, 13.25, 0.14]
        ];
        fast_round_chain(pts1);
        fast_round_chain(pts2);
    }
}

module filigree_gallery() {
    for (angle = [0, 60, 120, 180, 240, 300]) {
        filigree_petal(angle);
    }
}

module prong(base_angle) {
    color(prong_color)
    rotate([0, 0, base_angle]) {
        pts = [
            [2.4, 0, 9.35, 0.5],
            [3.4, 0, 11.0, 0.46],
            [3.9, 0, 12.5, 0.42],
            [3.8, 0, 13.8, 0.38],
            [3.3, 0, 14.4, 0.34],
            [2.1, 0, 14.9, 0.28]
        ];
        fast_round_chain(pts);
    }
}

module prongs() {
    for (angle = [0, 60, 120, 180, 240, 300]) {
        prong(angle);
    }
}

module center_stone() {
    color(stone_color)
    union() {
        // Crown
        translate([0, 0, 13.55])
            cylinder(r1 = 3.75, r2 = 2.1, h = 1.242, $fn = 64);
        // Pavilion
        translate([0, 0, 10.192])
            cylinder(r1 = 0.01, r2 = 3.75, h = 3.358, $fn = 64);
    }
}

module pave_stones() {
    color(stone_color) {
        y_offsets = [-1.4, 0, 1.4];
        for (y = y_offsets) {
            for (theta = [15 : 7.5 : 75]) {
                for (sign = [-1, 1]) {
                    angle = theta * sign;
                    on_band_surface(y, angle)
                        translate([0, 0, -0.15]) // slightly recessed
                            pave_stone_geometry(r = 0.55);
                } 
            } 
        }
    }
}

module milgrain_beads() {
    color(ring_color) {
        y_offsets = [-2.2, -0.7, 0.7, 2.2];
        for (y = y_offsets) {
            for (theta = [13 : 3.0 : 85]) {
                for (sign = [-1, 1]) {
                    angle = theta * sign;
                    on_band_surface(y, angle)
                        sphere(r = 0.18, $fn = 8);
                } 
            }
        }
    }
}

union() {
    ring_band();
    gallery_rings();
    filigree_gallery();
    prongs();
    center_stone();
    pave_stones();
    milgrain_beads();
}
