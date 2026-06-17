// Auto-generated procedural draft -- optimized and corrected
$fn = 48;

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

module ring_band_base() {
    color(ring_color)
    difference() {
        // Main band
        rotate([90, 0, 0])
            rotate_extrude(angle = 360)
                polygon([[8.25, -2.6], [8.6121, -2.5645], [8.9643, -2.4591], [9.2971, -2.2866], [9.6013, -2.0518], [9.8686, -1.7609], [10.0918, -1.4221], [10.2647, -1.0444], [10.3827, -0.6383], [10.4425, -0.2147], [10.4425, 0.2147], [10.3827, 0.6383], [10.2647, 1.0444], [10.0918, 1.4221], [9.8686, 1.7609], [9.6013, 2.0518], [9.2971, 2.2866], [8.9643, 2.4591], [8.6121, 2.5645], [8.25, 2.6], [8.25, 2.6], [8.2173, 2.5645], [8.1854, 2.4591], [8.1554, 2.2866], [8.1279, 2.0518], [8.1037, 1.7609], [8.0836, 1.4221], [8.0679, 1.0444], [8.0573, 0.6383], [8.0519, 0.2147], [8.0519, -0.2147], [8.0573, -0.6383], [8.0679, -1.0444], [8.0836, -1.4221], [8.1037, -1.7609], [8.1279, -2.0518], [8.1554, -2.2866], [8.1854, -2.4591], [8.2173, -2.5645], [8.25, -2.6]]);

        // Pierce-out holes under the pave stones (diamond-shaped cuts)
        y_offsets = [-1.4, 0, 1.4];
        for (y = y_offsets) {
            r_val = band_outer_radius(y);
            for (theta = [15 : 6.5 : 80]) {
                for (sign = [-1, 1]) {
                    angle = theta * sign;
                    translate([0, y, 0])
                        rotate([0, angle, 0])
                            translate([0, 0, 8.0])
                                cylinder(r1 = 0.3, r2 = 0.5, h = 3.0, $fn = 4);
                }
            }
        }
    }
}

module gallery_rings() {
    color(ring_color) {
        // Bottom ring
        translate([0, 0, 9.35])
            difference() {
                cylinder(r = 2.4, h = 0.6, $fn = 48);
                translate([0, 0, -0.1])
                    cylinder(r = 1.8, h = 0.8, $fn = 48);
            }
        // Top ring (just below the girdle)
        translate([0, 0, 13.1])
            difference() {
                cylinder(r = 3.8, h = 0.5, $fn = 48);
                translate([0, 0, -0.1])
                    cylinder(r = 3.3, h = 0.7, $fn = 48);
            }
    }
}

module filigree_petal(angle) {
    color(ring_color)
    rotate([0, 0, angle]) {
        pts = [
            [1.8, 0, 9.35, 0.2],
            [2.8, 0.8, 10.5, 0.18],
            [3.5, 1.2, 12.0, 0.16],
            [3.7, 0, 13.25, 0.14]
        ];
        for (i = [0 : len(pts) - 2]) {
            // Left side
            hull() {
                translate([pts[i][0], pts[i][1], pts[i][2]]) sphere(r = pts[i][3], $fn = 12);
                translate([pts[i+1][0], pts[i+1][1], pts[i+1][2]]) sphere(r = pts[i+1][3], $fn = 12);
            }
            // Right side
            hull() {
                translate([pts[i][0], -pts[i][1], pts[i][2]]) sphere(r = pts[i][3], $fn = 12);
                translate([pts[i+1][0], -pts[i+1][1], pts[i+1][2]]) sphere(r = pts[i+1][3], $fn = 12);
            }
        }
    }
}

module filigree_gallery() {
    for (angle = [0, 60, 120, 180, 240, 300]) {
        filigree_petal(angle);
    }
}

module prong(base_angle) {
    color(prong_color)
    rotate([0, 0, base_angle])
    {
        // Lower claw segment (from gallery base to girdle)
        hull() {
            translate([2.34, 0, 9.35]) sphere(r = 0.5, $fn = 16);
            translate([3.95, 0, 11.85]) sphere(r = 0.45, $fn = 16);
        }
        // Middle claw segment
        hull() { 
            translate([3.95, 0, 11.85]) sphere(r = 0.45, $fn = 16);
            translate([3.75, 0, 14.2952]) sphere(r = 0.3713, $fn = 16);
        }
        // Upper claw tip
        hull() {
            translate([3.75, 0, 14.2952]) sphere(r = 0.3713, $fn = 16);
            translate([2.1, 0, 14.95]) sphere(r = 0.3, $fn = 16);
        }
    }
}

module prongs() {
    for (angle = [30, 90, 150, 210, 270, 330]) {
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
            r_val = band_outer_radius(y);
            for (theta = [15 : 6.5 : 80]) {
                for (sign = [-1, 1]) {
                    angle = theta * sign;
                    x = r_val * sin(angle);
                    z = r_val * cos(angle);
                    translate([x, y, z])
                        sphere(r = 0.55, $fn = 12);
                }
            }
        }
    }
}

module milgrain_beads() {
    color(ring_color) {
        y_offsets = [-2.2, -0.7, 0.7, 2.2];
        for (y = y_offsets) {
            r_val = band_outer_radius(y);
            for (theta = [15 : 2.2 : 345]) {
                x = r_val * sin(theta);
                z = r_val * cos(theta);
                translate([x, y, z])
                    sphere(r = 0.175, $fn = 8);
            }
        }
    }
}

union() {
    ring_band_base();
    gallery_rings();
    filigree_gallery();
    prongs();
    center_stone();
    pave_stones();
    milgrain_beads();
}
