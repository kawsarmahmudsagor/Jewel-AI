// Auto-generated procedural draft -- scad_builder.py
$fn = 64;

ring_color  = "#D4AF37";
prong_color = "#D4AF37";
stone_color = "#E8F4FF";

ring_inner_radius   = 8.25;
band_tube_radius    = 0.8;
band_apex_z         = 9.05;
gallery_top_z       = 13.05;
stone_girdle_z      = 13.05;
stone_table_z       = 14.103;
prong_tip_z         = 14.49;
gem_radius          = 3.25;
gem_table_radius    = 1.82;
gem_crown_height    = 1.053;
gem_pavilion_depth  = 2.847;
pavilion_tip_z      = 10.203;

module ring_band_base() {
    color(ring_color)
    rotate([90, 0, 0])
        rotate_extrude(angle = 360)
            polygon([[8.25, -1], [8.5134, -0.9864], [8.7695, -0.9458], [9.0115, -0.8795], [9.2327, -0.7891], [9.4272, -0.6773], [9.5895, -0.5469], [9.7152, -0.4017], [9.801, -0.2455], [9.8445, -0.0826], [9.8445, 0.0826], [9.801, 0.2455], [9.7152, 0.4017], [9.5895, 0.5469], [9.4272, 0.6773], [9.2327, 0.7891], [9.0115, 0.8795], [8.7695, 0.9458], [8.5134, 0.9864], [8.25, 1], [8.25, 1], [8.2452, 0.9864], [8.2405, 0.9458], [8.236, 0.8795], [8.2319, 0.7891], [8.2284, 0.6773], [8.2254, 0.5469], [8.2231, 0.4017], [8.2215, 0.2455], [8.2207, 0.0826], [8.2207, -0.0826], [8.2215, -0.2455], [8.2231, -0.4017], [8.2254, -0.5469], [8.2284, -0.6773], [8.2319, -0.7891], [8.236, -0.8795], [8.2405, -0.9458], [8.2452, -0.9864], [8.25, -1]]);
}


module shoulder_r() {
    color(ring_color)
    {
        pts = [[4.675, 0, 8.75, 0.56], [4.3771, 0, 9.0403, 0.55], [4.0792, 0, 9.3294, 0.54], [3.7813, 0, 9.6163, 0.53], [3.4833, 0, 9.9, 0.52], [3.1854, 0, 10.1794, 0.51], [2.8875, 0, 10.4536, 0.5], [2.5896, 0, 10.7217, 0.49], [2.2917, 0, 10.983, 0.48], [1.9938, 0, 11.2369, 0.47], [1.6958, 0, 11.483, 0.46], [1.3979, 0, 11.7207, 0.45], [1.1, 0, 11.95, 0.44]];
        for (i = [0 : len(pts) - 2]) {
            hull() {
                translate([pts[i][0], pts[i][1], pts[i][2]]) sphere(r = pts[i][3], $fn = 16);
                translate([pts[i+1][0], pts[i+1][1], pts[i+1][2]]) sphere(r = pts[i+1][3], $fn = 16);
            }
        }
    }
}


module shoulder_l() {
    color(ring_color)
    {
        pts = [[-4.675, 0, 8.75, 0.56], [-4.3771, 0, 9.0403, 0.55], [-4.0792, 0, 9.3294, 0.54], [-3.7813, 0, 9.6163, 0.53], [-3.4833, 0, 9.9, 0.52], [-3.1854, 0, 10.1794, 0.51], [-2.8875, 0, 10.4536, 0.5], [-2.5896, 0, 10.7217, 0.49], [-2.2917, 0, 10.983, 0.48], [-1.9938, 0, 11.2369, 0.47], [-1.6958, 0, 11.483, 0.46], [-1.3979, 0, 11.7207, 0.45], [-1.1, 0, 11.95, 0.44]];
        for (i = [0 : len(pts) - 2]) {
            hull() {
                translate([pts[i][0], pts[i][1], pts[i][2]]) sphere(r = pts[i][3], $fn = 16);
                translate([pts[i+1][0], pts[i+1][1], pts[i+1][2]]) sphere(r = pts[i+1][3], $fn = 16);
            }
        }
    }
}


module gallery_cup() {
    color(ring_color)
    difference() {
        translate([0, 0, 9.05])
            cylinder(r1 = 2.82, r2 = 4.7, h = 4.2, $fn = 48);
        translate([0, 0, 8.95])
            cylinder(r1 = 2.52, r2 = 3.25, h = 4.4, $fn = 48);
    }
}


module prong(base_angle) {
    color(prong_color)
    rotate([0, 0, base_angle])
    {
        hull() {
            translate([3.45, 0, 11.35]) sphere(r = 0.2, $fn = 16);
            translate([3.25, 0, 13.6818]) sphere(r = 0.19, $fn = 16);
        }
        hull() {
            translate([3.25, 0, 13.6818]) sphere(r = 0.19, $fn = 16);
            translate([1.547, 0, 14.49]) sphere(r = 0.18, $fn = 16);
        }
    }
}

module prongs() {
    rotate([0, 0, 0]) prong(0);
    rotate([0, 0, 90]) prong(90);
    rotate([0, 0, 180]) prong(180);
    rotate([0, 0, 270]) prong(270);
}


module center_stone() {
    color(stone_color)
    scale([1, 1, 1])
    union() {
        translate([0, 0, 13.05])
            cylinder(r1 = 3.25, r2 = 1.82, h = 1.053, $fn = 64);
        translate([0, 0, 10.203])
            cylinder(r1 = 0.01, r2 = 3.25, h = 2.847, $fn = 64);
    }
}


module pave_stones() {
    color(stone_color)
    {
        pts = [[0, 3.5, 0, 0.6], [-2.6, 3.5, 0, 0.6], [2.6, 3.5, 0, 0.6], [-4, 2.5, 0, 0.6], [4, 2.5, 0, 0.6], [-4.4, 1.4, 0, 0.6], [4.4, 1.4, 0, 0.6], [-4.4, 0.2, 0, 0.6], [4.4, 0.2, 0, 0.6], [-4.2, -1, 0, 0.6], [4.2, -1, 0, 0.6], [-3.9, -2.1, 0, 0.6], [3.9, -2.1, 0, 0.6], [-3.5, -3.1, 0, 0.6], [3.5, -3.1, 0, 0.6], [-3, -4, 0, 0.6], [3, -4, 0, 0.6], [-2.4, -4.8, 0, 0.55], [2.4, -4.8, 0, 0.55], [-1.7, -5.4, 0, 0.55]];
        for (i = [0 : len(pts) - 1]) {
            translate([pts[i][0], pts[i][1], pts[i][2]]) sphere(r = pts[i][3], $fn = 16);
        }
    }
}


module side_stone_0() {
    color(stone_color)
    translate([-4.2, 1.8, 0])
        scale([1, 1, 0.5833])
            sphere(r = 0.6, $fn = 24);
}


module side_stone_1() {
    color(stone_color)
    translate([4.2, 1.8, 0])
        scale([1, 1, 0.5833])
            sphere(r = 0.6, $fn = 24);
}

union() {
    ring_band_base();
    shoulder_r();
    shoulder_l();
    gallery_cup();
    prongs();
    center_stone();
    pave_stones();
    side_stone_0();
    side_stone_1();
}
