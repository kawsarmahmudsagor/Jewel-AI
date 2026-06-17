// Auto-generated procedural draft -- scad_builder.py
$fn = 64;

ring_color  = "#D4AF37";
prong_color = "#D4AF37";
stone_color = "#E8F4FF";

ring_inner_radius   = 8.25;
band_tube_radius    = 1.05;
band_apex_z         = 9.3;
gallery_top_z       = 13.1;
stone_girdle_z      = 13.8;
stone_table_z       = 14.88;
prong_tip_z         = 15;
gem_radius          = 3.25;
gem_table_radius    = 1.82;
gem_crown_height    = 1.08;
gem_pavilion_depth  = 2.92;
pavilion_tip_z      = 10.88;

module ring_band_base() {
    color(ring_color)
    rotate([90, 0, 0])
        rotate_extrude(angle = 360)
            polygon([[8.25, -1.1], [8.5956, -1.085], [8.9319, -1.0404], [9.2495, -0.9674], [9.5398, -0.8681], [9.795, -0.745], [10.008, -0.6016], [10.1731, -0.4419], [10.2857, -0.27], [10.3428, -0.0908], [10.3428, 0.0908], [10.2857, 0.27], [10.1731, 0.4419], [10.008, 0.6016], [9.795, 0.745], [9.5398, 0.8681], [9.2495, 0.9674], [8.9319, 1.0404], [8.5956, 1.085], [8.25, 1.1], [8.25, 1.1], [8.2441, 1.085], [8.2384, 1.0404], [8.2331, 0.9674], [8.2281, 0.8681], [8.2238, 0.745], [8.2202, 0.6016], [8.2174, 0.4419], [8.2155, 0.27], [8.2145, 0.0908], [8.2145, -0.0908], [8.2155, -0.27], [8.2174, -0.4419], [8.2202, -0.6016], [8.2238, -0.745], [8.2281, -0.8681], [8.2331, -0.9674], [8.2384, -1.0404], [8.2441, -1.085], [8.25, -1.1]]);
}


module shoulder_r() {
    color(ring_color)
    {
        pts = [[4.895, 0, 9, 0.616], [4.5879, 0, 9.2736, 0.605], [4.2808, 0, 9.5461, 0.594], [3.9738, 0, 9.8163, 0.583], [3.6667, 0, 10.0833, 0.572], [3.3596, 0, 10.346, 0.561], [3.0525, 0, 10.6036, 0.55], [2.7454, 0, 10.855, 0.539], [2.4383, 0, 11.0997, 0.528], [2.1313, 0, 11.3369, 0.517], [1.8242, 0, 11.5663, 0.506], [1.5171, 0, 11.7874, 0.495], [1.21, 0, 12, 0.484]];
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
        pts = [[-4.895, 0, 9, 0.616], [-4.5879, 0, 9.2736, 0.605], [-4.2808, 0, 9.5461, 0.594], [-3.9738, 0, 9.8163, 0.583], [-3.6667, 0, 10.0833, 0.572], [-3.3596, 0, 10.346, 0.561], [-3.0525, 0, 10.6036, 0.55], [-2.7454, 0, 10.855, 0.539], [-2.4383, 0, 11.0997, 0.528], [-2.1313, 0, 11.3369, 0.517], [-1.8242, 0, 11.5663, 0.506], [-1.5171, 0, 11.7874, 0.495], [-1.21, 0, 12, 0.484]];
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
        translate([0, 0, 8.6])
            cylinder(r1 = 2.85, r2 = 4.75, h = 4.7, $fn = 48);
        translate([0, 0, 8.5])
            cylinder(r1 = 2.55, r2 = 3.25, h = 4.9, $fn = 48);
    }
}


module prong(base_angle) {
    color(prong_color)
    rotate([0, 0, base_angle])
    {
        hull() {
            translate([3.45, 0, 12.1]) sphere(r = 0.4, $fn = 16);
            translate([3.25, 0, 14.448]) sphere(r = 0.33, $fn = 16);
        }
        hull() {
            translate([3.25, 0, 14.448]) sphere(r = 0.33, $fn = 16);
            translate([1.547, 0, 15]) sphere(r = 0.26, $fn = 16);
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
        translate([0, 0, 13.8])
            cylinder(r1 = 3.25, r2 = 1.82, h = 1.08, $fn = 64);
        translate([0, 0, 10.88])
            cylinder(r1 = 0.01, r2 = 3.25, h = 2.92, $fn = 64);
    }
}


module pave_stones() {
    color(stone_color)
    {
        pts = [[-4, 0, 3.8, 0.65]];
        for (i = [0 : len(pts) - 1]) {
            translate([pts[i][0], pts[i][1], pts[i][2]]) sphere(r = pts[i][3], $fn = 16);
        }
    }
}

union() {
    ring_band_base();
    shoulder_r();
    shoulder_l();
    gallery_cup();
    prongs();
    center_stone();
    pave_stones();
}
