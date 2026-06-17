$fn = 48;

ring_color  = "#E5E9EC";
prong_color = "#E5E9EC";
stone_color = "#3B9EC6";

ring_inner_radius   = 8.25;
band_apex_z         = 9.15;
stone_girdle_z      = 12.65;
stone_table_z       = 13.75;

module rounded_rectangle(w, l, r) {
    minkowski() {
        square([w - 2*r, l - 2*r], center = true);
        circle(r = r, $fn = 24);
    }
}

module ring_band_base() {
    color(ring_color)
    difference() {
        rotate([90, 0, 0])
            rotate_extrude(angle = 360, $fn = 64)
                translate([8.25 + 0.9, 0])
                    scale([1, 1.8])
                        circle(r = 0.9, $fn = 24);
        
        // Cut the top part above Z = 6.0
        translate([0, 0, 12.0])
            cube([20, 20, 12], center = true);
    }
}

module split_arm(x_sign, y_sign) {
    color(ring_color) {
        pts = [
            [x_sign * 7.8, y_sign * 0.4, 3.5, 0.95],
            [x_sign * 7.0, y_sign * 0.9, 5.5, 0.85],
            [x_sign * 5.8, y_sign * 1.4, 7.8, 0.78],
            [x_sign * 4.4, y_sign * 1.8, 9.8, 0.72],
            [x_sign * 2.8, y_sign * 2.0, 11.5, 0.65]
        ];
        for (i = [0 : len(pts) - 2]) {
            hull() {
                translate([pts[i][0], pts[i][1], pts[i][2]]) sphere(r = pts[i][3], $fn = 12);
                translate([pts[i+1][0], pts[i+1][1], pts[i+1][2]]) sphere(r = pts[i+1][3], $fn = 12);
            }
        }
    }
}

module split_arms() {
    split_arm(1, 1);
    split_arm(1, -1);
    split_arm(-1, 1);
    split_arm(-1, -1);
}

module arm_pave_stones(x_sign, y_sign) {
    color(stone_color) {
        stone_pts = [
            [x_sign * 7.0, y_sign * 1.1, 5.7, 0.5],
            [x_sign * 5.8, y_sign * 1.6, 8.0, 0.48],
            [x_sign * 4.4, y_sign * 2.0, 10.0, 0.45],
            [x_sign * 3.0, y_sign * 2.2, 11.6, 0.42]
        ];
        for (pt = stone_pts) {
            translate(pt) sphere(r = pt[3], $fn = 12);
        }
    }
}

module pave_stones() {
    arm_pave_stones(1, 1);
    arm_pave_stones(1, -1);
    arm_pave_stones(-1, 1);
    arm_pave_stones(-1, -1);
}

module halo_frame() {
    color(ring_color)
    difference() {
        // Outer frame
        translate([0, 0, stone_girdle_z - 0.5])
            linear_extrude(height = 1.2, center = true)
                rounded_rectangle(w = 6.0 + 2.2, l = 8.0 + 2.2, r = 1.5);
        // Inner cutout for stone
        translate([0, 0, stone_girdle_z - 0.5])
            linear_extrude(height = 1.6, center = true)
                rounded_rectangle(w = 6.0 - 0.2, l = 8.0 - 0.2, r = 0.8);
    }
}

module halo_stones() {
    color(stone_color) {
        stone_r = 0.55;
        z_pos = stone_girdle_z + 0.1;
        
        // Top/Bottom rows: Y = +/- 4.6
        for (x = [-3.8 : 1.27 : 3.8]) {
            translate([x, 4.6, z_pos]) sphere(r = stone_r, $fn = 12);
            translate([x, -4.6, z_pos]) sphere(r = stone_r, $fn = 12);
        }
        // Left/Right rows: X = +/- 3.6
        for (y = [-3.5 : 1.16 : 3.5]) {
            translate([3.6, y, z_pos]) sphere(r = stone_r, $fn = 12);
            translate([-3.6, y, z_pos]) sphere(r = stone_r, $fn = 12);
        }
    }
}

module under_gallery() {
    color(ring_color) {
        // Lower rail
        translate([0, 0, stone_girdle_z - 2.2])
            linear_extrude(height = 0.6, center = true)
                difference() {
                    rounded_rectangle(w = 6.0 + 1.0, l = 8.0 + 1.0, r = 1.0);
                    rounded_rectangle(w = 6.0 - 1.0, l = 8.0 - 1.0, r = 0.5);
                }
        
        // Support pillars
        for (x = [-2.5, 2.5]) {
            for (y = [-3.5, 3.5]) {
                hull() {
                    translate([x, y, stone_girdle_z - 2.2]) sphere(r = 0.4, $fn = 12);
                    translate([x * 1.1, y * 1.1, stone_girdle_z - 0.8]) sphere(r = 0.4, $fn = 12);
                }
            }
        }
    }
}

module claw_prong(x_sign, y_sign) {
    color(prong_color) {
        bx = x_sign * 2.9;
        by = y_sign * 3.9;
        bz = stone_girdle_z - 1.5;
        
        mx = x_sign * 2.9;
        my = y_sign * 3.9;
        mz = stone_girdle_z + 0.2;
        
        tx = x_sign * 2.4;
        ty = y_sign * 3.4;
        tz = stone_table_z + 0.1;
        
        hull() {
            translate([bx, by, bz]) sphere(r = 0.45, $fn = 12);
            translate([mx, my, mz]) sphere(r = 0.4, $fn = 12);
        }
        hull() { 
            translate([mx, my, mz]) sphere(r = 0.4, $fn = 12);
            translate([tx, ty, tz]) sphere(r = 0.25, $fn = 12);
        }
    }
}

module prongs() {
    claw_prong(1, 1);
    claw_prong(1, -1);
    claw_prong(-1, 1);
    claw_prong(-1, -1);
}

module emerald_shape_2d(w, l, bevel) {
    difference() {
        square([w, l], center = true);
        translate([w/2, l/2]) rotate(45) square([bevel*2, bevel*2], center = true);
        translate([-w/2, l/2]) rotate(45) square([bevel*2, bevel*2], center = true);
        translate([w/2, -l/2]) rotate(45) square([bevel*2, bevel*2], center = true);
        translate([-w/2, -l/2]) rotate(45) square([bevel*2, bevel*2], center = true);
    }
}

module emerald_stone(w, l, depth, crown_h, pavilion_h, bevel) {
    hull() {
        translate([0, 0, -0.05])
            linear_extrude(height = 0.1, center = true)
                emerald_shape_2d(w, l, bevel);
        translate([0, 0, crown_h])
            linear_extrude(height = 0.1, center = true)
                emerald_shape_2d(w * 0.65, l * 0.65, bevel * 0.65);
    }
    hull() {
        translate([0, 0, 0.05])
            linear_extrude(height = 0.1, center = true)
                emerald_shape_2d(w, l, bevel);
        translate([0, 0, -pavilion_h])
            linear_extrude(height = 0.1, center = true)
                emerald_shape_2d(w * 0.1, l * 0.1, bevel * 0.1);
    }
}

module center_stone() {
    color(stone_color)
    translate([0, 0, stone_girdle_z])
        emerald_stone(w = 6.0, l = 8.0, depth = 4.0, crown_h = 1.1, pavilion_h = 2.9, bevel = 1.2);
}

union() {
    ring_band_base();
    split_arms();
    pave_stones();
    halo_frame();
    halo_stones();
    under_gallery();
    prongs();
    center_stone();
}