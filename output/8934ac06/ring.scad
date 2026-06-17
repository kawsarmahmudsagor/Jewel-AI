// Auto-generated procedural draft -- scad_builder.py
$fn = 64;

ring_color  = "#D4AF37";
prong_color = "#D4AF37";
stone_color = "#E8F4FF";

ring_inner_radius   = 8.25;
band_tube_radius    = 1;
band_apex_z         = 9.25;
gallery_top_z       = 12.25;
stone_girdle_z      = 12.75;
stone_table_z       = 13.803;
prong_tip_z         = 14.05;
gem_radius          = 3.25;
gem_table_radius    = 1.82;
gem_crown_height    = 1.053;
gem_pavilion_depth  = 2.847;
pavilion_tip_z      = 9.903;

module ring_band_base() {
    color(ring_color)
    rotate([90, 0, 0])
        rotate_extrude(angle = 360)
            polygon([[8.25, -2.75], [8.5792, -2.7125], [8.8994, -2.601], [9.2019, -2.4186], [9.4784, -2.1701], [9.7214, -1.8625], [9.9243, -1.5041], [10.0815, -1.1047], [10.1888, -0.6751], [10.2432, -0.2271], [10.2432, 0.2271], [10.1888, 0.6751], [10.0815, 1.1047], [9.9243, 1.5041], [9.7214, 1.8625], [9.4784, 2.1701], [9.2019, 2.4186], [8.8994, 2.601], [8.5792, 2.7125], [8.25, 2.75], [8.25, 2.75], [8.2134, 2.7125], [8.1778, 2.601], [8.1441, 2.4186], [8.1134, 2.1701], [8.0864, 1.8625], [8.0638, 1.5041], [8.0463, 1.1047], [8.0344, 0.6751], [8.0283, 0.2271], [8.0283, -0.2271], [8.0344, -0.6751], [8.0463, -1.1047], [8.0638, -1.5041], [8.0864, -1.8625], [8.1134, -2.1701], [8.1441, -2.4186], [8.1778, -2.601], [8.2134, -2.7125], [8.25, -2.75]]);
}


module gallery_cup() {
    color(ring_color)
    difference() {
        translate([0, 0, 8.75])
            cylinder(r1 = 3.15, r2 = 5.25, h = 3.7, $fn = 48);
        translate([0, 0, 8.65])
            cylinder(r1 = 2.85, r2 = 3.25, h = 3.9, $fn = 48);
    }
}


module prong(base_angle) {
    color(prong_color)
    rotate([0, 0, base_angle])
    {
        hull() {
            translate([3.45, 0, 11.05]) sphere(r = 0.4, $fn = 16);
            translate([3.25, 0, 13.3818]) sphere(r = 0.33, $fn = 16);
        }
        hull() {
            translate([3.25, 0, 13.3818]) sphere(r = 0.33, $fn = 16);
            translate([1.547, 0, 14.05]) sphere(r = 0.26, $fn = 16);
        }
    }
}

module prongs() {
    rotate([0, 0, 45]) prong(45);
    rotate([0, 0, 135]) prong(135);
    rotate([0, 0, 225]) prong(225);
    rotate([0, 0, 315]) prong(315);
}


module center_stone() {
    color(stone_color)
    scale([1, 1, 1])
    union() {
        translate([0, 0, 12.75])
            cylinder(r1 = 3.25, r2 = 1.82, h = 1.053, $fn = 64);
        translate([0, 0, 9.903])
            cylinder(r1 = 0.01, r2 = 3.25, h = 2.847, $fn = 64);
    }
}


module pave_stones() {
    color(stone_color)
    {
        pts = [[0, 0, 0, 1.1], [1.5, 0, 0, 0.6]];
        for (i = [0 : len(pts) - 1]) {
            translate([pts[i][0], pts[i][1], pts[i][2]]) sphere(r = pts[i][3], $fn = 16);
        }
    }
}


module side_stone_0() {
    color(stone_color)
    translate([0, 0, 3])
        scale([1, 1, 0.6111])
            sphere(r = 0.9, $fn = 24);
}

union() {
    ring_band_base();
    gallery_cup();
    prongs();
    center_stone();
    pave_stones();
    side_stone_0();
}
