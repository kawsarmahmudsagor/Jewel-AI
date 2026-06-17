// Auto-generated procedural draft -- scad_builder.py
$fn = 64;

ring_color  = "#D4AF37";
prong_color = "#D4AF37";
stone_color = "#E8F4FF";

ring_inner_radius   = 8.25;
band_tube_radius    = 1;
band_apex_z         = 9.25;
gallery_top_z       = 12.75;
stone_girdle_z      = 13.05;
stone_table_z       = 14.049;
prong_tip_z         = 14.21;
gem_radius          = 3;
gem_table_radius    = 1.68;
gem_crown_height    = 0.999;
gem_pavilion_depth  = 2.701;
pavilion_tip_z      = 10.349;

module ring_band_base() {
    color(ring_color)
    rotate([90, 0, 0])
        rotate_extrude(angle = 360)
            polygon([[8.25, -2.25], [8.5792, -2.2193], [8.8994, -2.1281], [9.2019, -1.9788], [9.4784, -1.7756], [9.7214, -1.5239], [9.9243, -1.2306], [10.0815, -0.9038], [10.1888, -0.5523], [10.2432, -0.1858], [10.2432, 0.1858], [10.1888, 0.5523], [10.0815, 0.9038], [9.9243, 1.2306], [9.7214, 1.5239], [9.4784, 1.7756], [9.2019, 1.9788], [8.8994, 2.1281], [8.5792, 2.2193], [8.25, 2.25]]);
}


module gallery_halo_basket() {
    color(ring_color)
    difference() {
        translate([0, 0, 11.65])
            cylinder(r1 = 1.65, r2 = 2.25, h = 1.6, $fn = 48);
        translate([0, 0, 11.55])
            cylinder(r1 = 1.35, r2 = 2.7, h = 1.8, $fn = 48);
    }
}


module halo_stones() {
    color(stone_color)
    {
        pts = [[3.5, 0, 12.85, 0.75], [2.8316, 2.0572, 12.85, 0.75], [1.0816, 3.3287, 12.85, 0.75], [-1.0816, 3.3287, 12.85, 0.75], [-2.8316, 2.0572, 12.85, 0.75], [-3.5, 0, 12.85, 0.75], [-2.8316, -2.0572, 12.85, 0.75], [-1.0816, -3.3287, 12.85, 0.75], [1.0816, -3.3287, 12.85, 0.75], [2.8316, -2.0572, 12.85, 0.75]];
        for (i = [0 : len(pts) - 1]) {
            translate([pts[i][0], pts[i][1], pts[i][2]]) sphere(r = pts[i][3], $fn = 16);
        }
    }
}


module prong(base_angle) {
    color(prong_color)
    rotate([0, 0, base_angle])
    {
        hull() {
            translate([3.2, 0, 11.35]) sphere(r = 0.4, $fn = 16);
            translate([3, 0, 13.6494]) sphere(r = 0.33, $fn = 16);
        }
        hull() {
            translate([3, 0, 13.6494]) sphere(r = 0.33, $fn = 16);
            translate([1.428, 0, 14.21]) sphere(r = 0.26, $fn = 16);
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
        translate([0, 0, 13.05])
            cylinder(r1 = 3, r2 = 1.68, h = 0.999, $fn = 64);
        translate([0, 0, 10.349])
            cylinder(r1 = 0.01, r2 = 3, h = 2.701, $fn = 64);
    }
}


module pave_stones() {
    color(stone_color)
    {
        pts = [[-2.42, -0, 9.0314, 0.9], [-2.4111, 0.2588, 8.9985, 0.5], [-2.4111, -0.2588, 8.9985, 0.5]];
        for (i = [0 : len(pts) - 1]) {
            translate([pts[i][0], pts[i][1], pts[i][2]]) sphere(r = pts[i][3], $fn = 16);
        }
    }
}

union() {
    ring_band_base();
    gallery_halo_basket();
    halo_stones();
    prongs();
    center_stone();
    pave_stones();
}
