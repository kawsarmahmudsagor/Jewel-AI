$fn = 64;

ring_color  = "#E5A08D";
prong_color = "#E5A08D";
stone_color = "#E8F4FF";

ring_inner_radius   = 8.25;
band_apex_z         = 10.25;
stone_girdle_z      = 13.5;

module ring_band_base() {
    color(ring_color)
    rotate([90, 0, 0])
    difference() {
        cylinder(r = 10.25, h = 4.2, center = true, $fn = 96);
        cylinder(r = 8.25, h = 4.5, center = true, $fn = 96);
    }
}

module gallery_halo_basket() {
    color(ring_color) {
        translate([0, 0, stone_girdle_z - 1.0]) {
            difference() {
                cylinder(r = 4.5, h = 0.8, center = true, $fn = 64);
                cylinder(r = 3.2, h = 1.0, center = true, $fn = 64);
            }
        }
        for (i = [0 : 3]) {
            rotate([0, 0, i * 90 + 45])
                translate([2.5, 0, (stone_girdle_z - 1.0 + 10.25)/2])
                    rotate([0, 35, 0])
                        cylinder(r = 0.5, h = 3.2, center = true, $fn = 16);
        }
    }
}

module halo_stones() {
    color(stone_color) {
        for (i = [0 : 11]) {
            theta = i * 30;
            x = cos(theta) * 3.9;
            y = sin(theta) * 3.9;
            translate([x, y, stone_girdle_z - 0.2])
                sphere(r = 0.75, $fn = 16);
        }
    }
}

module halo_prongs() {
    color(ring_color) {
        for (i = [0 : 11]) {
            theta_outer = i * 30 + 15;
            xo = cos(theta_outer) * 4.6;
            yo = sin(theta_outer) * 4.6;
            translate([xo, yo, stone_girdle_z + 0.2])
                sphere(r = 0.3, $fn = 12);

            theta_inner = i * 30;
            xi = cos(theta_inner) * 3.2;
            yi = sin(theta_inner) * 3.2;
            translate([xi, yi, stone_girdle_z + 0.2])
                sphere(r = 0.25, $fn = 12);
        } 
    }
}

module prong(base_angle) {
    color(prong_color)
    rotate([0, 0, base_angle]) {
        hull() {
            translate([2.9, 0, stone_girdle_z - 1.2]) sphere(r = 0.4, $fn = 16);
            translate([2.9, 0, stone_girdle_z + 0.2]) sphere(r = 0.35, $fn = 16);
        }
        hull() { 
            translate([2.9, 0, stone_girdle_z + 0.2]) sphere(r = 0.35, $fn = 16);
            translate([2.2, 0, stone_girdle_z + 0.8]) sphere(r = 0.3, $fn = 16);
        }
    }
}

module prongs() {
    prong(45);
    prong(135);
    prong(225);
    prong(315);
}

module center_stone() {
    color(stone_color) {
        translate([0, 0, stone_girdle_z]) {
            cylinder(r1 = 3.0, r2 = 1.7, h = 1.0, $fn = 64);
            translate([0, 0, -2.5])
                cylinder(r1 = 0.01, r2 = 3.0, h = 2.5, $fn = 64);
        }
    }
}

module pave_stones() {
    color(stone_color) {
        R = 10.15;
        for (side = [-1, 1]) {
            for (a = [14 : 8 : 70]) {
                angle = side * a;
                x = sin(angle) * R;
                z = cos(angle) * R;

                translate([x, 0, z])
                    rotate([0, angle, 0])
                        cylinder(r1 = 0.6, r2 = 0.6, h = 0.8, center = true, $fn = 12);

                for (y_offset = [-1.3, 1.3]) {
                    translate([x, y_offset, z])
                        rotate([0, angle, 0])
                            cylinder(r1 = 0.4, r2 = 0.4, h = 0.6, center = true, $fn = 12);
                }
            }
        }
    }
}

union() {
    ring_band_base();
    gallery_halo_basket();
    halo_stones();
    halo_prongs();
    prongs();
    center_stone();
    pave_stones();
}