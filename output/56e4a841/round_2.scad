$fn = 64;

ring_color  = "#D4AF37";
prong_color = "#D4AF37";
stone_color = "#E8F4FF";

ring_inner_radius   = 8.25;
band_tube_radius    = 0.7;
band_apex_z         = 8.95;
gallery_top_z       = 12.45;
stone_girdle_z      = 12.45;
stone_table_z       = 13.287;
prong_tip_z         = 14.25;
gem_radius          = 2.5;
gem_table_radius    = 1.4;
gem_crown_height    = 0.837;
gem_pavilion_depth  = 2.263;
pavilion_tip_z      = 10.187;

module ring_band_base() {
    color(ring_color)
    rotate([90, 0, 0])
        rotate_extrude(angle = 360)
            translate([8.95, 0]) circle(r=0.7, $fn=48);
}


module shoulder_r() {
    color(ring_color)
    {
        pts = [[4.675, 0, 8.65, 0.56], [4.3771, 0, 8.8986, 0.55], [4.0792, 0, 9.1461, 0.54], [3.7813, 0, 9.3913, 0.53], [3.4833, 0, 9.6333, 0.52], [3.1854, 0, 9.871, 0.51], [2.8875, 0, 10.1036, 0.5], [2.5896, 0, 10.33, 0.49], [2.2917, 0, 10.5497, 0.48], [1.9938, 0, 10.7619, 0.47], [1.6958, 0, 10.9663, 0.46], [1.3979, 0, 11.1624, 0.45], [1.1, 0, 11.35, 0.44]];
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
        pts = [[-4.675, 0, 8.65, 0.56], [-4.3771, 0, 8.8986, 0.55], [-4.0792, 0, 9.1461, 0.54], [-3.7813, 0, 9.3913, 0.53], [-3.4833, 0, 9.6333, 0.52], [-3.1854, 0, 9.871, 0.51], [-2.8875, 0, 10.1036, 0.5], [-2.5896, 0, 10.33, 0.49], [-2.2917, 0, 10.5497, 0.48], [-1.9938, 0, 10.7619, 0.47], [-1.6958, 0, 10.9663, 0.46], [-1.3979, 0, 11.1624, 0.45], [-1.1, 0, 11.35, 0.44]];
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
        translate([0, 0, 10.85])
            cylinder(r1 = 1.2, r2 = 1.7, h = 1.8, $fn = 48);
        translate([0, 0, 10.75])
            cylinder(r1 = 0.9, r2 = 2.5, h = 2, $fn = 48);
    }
}


module prong(base_angle) {
    color(prong_color)
    rotate([0, 0, base_angle])
    {
        hull() {
            translate([2.7, 0, 10.75]) sphere(r = 0.3, $fn = 16);
            translate([2.5, 0, 12.9522]) sphere(r = 0.2475, $fn = 16);
        }
        hull() {
            translate([2.5, 0, 12.9522]) sphere(r = 0.2475, $fn = 16);
            translate([1.19, 0, 14.25]) sphere(r = 0.195, $fn = 16);
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
        translate([0, 0, 12.45])
            cylinder(r1 = 2.5, r2 = 1.4, h = 0.837, $fn = 64);
        translate([0, 0, 10.187])
            cylinder(r1 = 0.01, r2 = 2.5, h = 2.263, $fn = 64);
    }
}


module halo_stones() {
    color(stone_color)
    halo_radius = 3.15;
    stone_r = 0.45;
    n = 18;
    for (i = [0 : n-1]) {
        angle = i * 360 / n;
        x = halo_radius * cos(angle);
        y = halo_radius * sin(angle);
        translate([x, y, 12.45]) sphere(r = stone_r, $fn = 16);
    }
}


module pave_stones() {
    color(stone_color)
    {
        pts_r = [
            [4.3, 0, 9.3, 0.45],
            [4.0, 0, 9.6, 0.45],
            [3.7, 0, 9.9, 0.45],
            [3.4, 0, 10.2, 0.45],
            [3.1, 0, 10.5, 0.45],
            [2.8, 0, 10.8, 0.45],
            [2.5, 0, 11.1, 0.45],
            [2.2, 0, 11.4, 0.45],
            [1.9, 0, 11.6, 0.45]
        ];
        for (i = [0 : len(pts_r) - 1]) {
            translate([pts_r[i][0], pts_r[i][1], pts_r[i][2]]) sphere(r = pts_r[i][3], $fn = 16);
        }
        pts_l = [
            [-4.3, 0, 9.3, 0.45],
            [-4.0, 0, 9.6, 0.45],
            [-3.7, 0, 9.9, 0.45],
            [-3.4, 0, 10.2, 0.45],
            [-3.1, 0, 10.5, 0.45],
            [-2.8, 0, 10.8, 0.45],
            [-2.5, 0, 11.1, 0.45],
            [-2.2, 0, 11.4, 0.45],
            [-1.9, 0, 11.6, 0.45]
        ];
        for (i = [0 : len(pts_l) - 1]) {
            translate([pts_l[i][0], pts_l[i][1], pts_l[i][2]]) sphere(r = pts_l[i][3], $fn = 16);
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
    halo_stones();
    pave_stones();
}
