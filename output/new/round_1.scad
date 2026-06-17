$fn = 48;

// --- Color Definitions ---
ring_color = "#D4AF37";
stone_color = "#E8F4FF";

// --- Dimensions & Parameters ---
ring_inner_radius = 8.25;
band_width_top = 4.5;
band_width_bottom = 2.5;
band_thickness_top = 1.8;
band_thickness_bottom = 1.6;
band_tube_radius = band_thickness_top / 2; // 0.9
band_apex_z = ring_inner_radius + band_tube_radius; // 9.15
true_crest_radial = ring_inner_radius + band_thickness_top; // 10.05

// Center Stone Dimensions
gem_radius = 2.75;
gem_depth = 3.4;

// Assembly Stack (World Z mapping)
galleryBaseZ = band_apex_z + 0.0;
galleryTopZ = band_apex_z + 3.5;
stoneGirdleZ = band_apex_z + 3.5;
stoneTableZ = band_apex_z + 4.38;
prongTipZ = band_apex_z + 4.58;
haloPlaneZ = band_apex_z + 3.3;

gem_crown_height = stoneTableZ - stoneGirdleZ; // 0.88
gem_pavilion_depth = gem_depth - gem_crown_height; // 2.52

// Halo Parameters
halo_stone_count = 12;
halo_stone_dia = 1.2;
halo_radial_offset = 0.6;

// --- Modules ---

module band_profile_2d_xy(w, t) {
    steps = 12;
    points = concat(
        [[ring_inner_radius, -w/2], [ring_inner_radius, w/2]],
        [for (i = [0:steps]) let(a = -90 + i * 180 / steps)
            [ring_inner_radius + t * cos(a), w/2 * sin(a)]]
    );
    polygon(points);
}

module band_slice(theta, w, t) {
    rotate([0, theta - 90, 0])
    linear_extrude(0.01, center=true)
    band_profile_2d_xy(w, t);
}

module ring_band_base() {
    step = 10;
    color(ring_color) {
        for (theta = [-180 : step : 180 - step]) {
            factor1 = (1 + cos(theta)) / 2;
            w1 = band_width_bottom + (band_width_top - band_width_bottom) * factor1;
            t1 = band_thickness_bottom + (band_thickness_top - band_thickness_bottom) * factor1;

            next_theta = theta + step;
            factor2 = (1 + cos(next_theta)) / 2;
            w2 = band_width_bottom + (band_width_top - band_width_bottom) * factor2;
            t2 = band_thickness_bottom + (band_thickness_top - band_thickness_bottom) * factor2;

            hull() {
                band_slice(theta, w1, t1);
                band_slice(next_theta, w2, t2);
            }
        }
    }
}

module center_stone() {
    color(stone_color) {
        // Crown
        translate([0, 0, stoneGirdleZ])
        cylinder(r1 = gem_radius, r2 = gem_radius * 0.55, h = gem_crown_height, $fn=32);
        // Pavilion
        translate([0, 0, stoneGirdleZ - gem_pavilion_depth])
        cylinder(r1 = 0.1, r2 = gem_radius, h = gem_pavilion_depth, $fn=32);
    }
}

module gallery_basket() {
    color(ring_color) {
        // Base ring (sits on the band)
        translate([0, 0, galleryBaseZ])
        difference() {
            cylinder(r = gem_radius * 0.6, h = 0.6, $fn=32);
            translate([0, 0, -0.1])
            cylinder(r = gem_radius * 0.4, h = 0.8, $fn=32);
        }

        // Top ring (just under the girdle)
        translate([0, 0, galleryTopZ - 0.6])
        difference() {
            cylinder(r = gem_radius * 0.9, h = 0.6, $fn=32);
            translate([0, 0, -0.1])
            cylinder(r = gem_radius * 0.7, h = 0.8, $fn=32);
        }

        // Struts connecting base ring to top ring
        for (a = [0, 90, 180, 270]) {
            rotate([0, 0, a])
            hull() {
                translate([gem_radius * 0.5, 0, galleryBaseZ + 0.3])
                sphere(r = 0.4, $fn=16);
                translate([gem_radius * 0.8, 0, galleryTopZ - 0.3])
                sphere(r = 0.4, $fn=16);
            }
        }

        // Halo platter (the ring that holds the halo stones)
        translate([0, 0, haloPlaneZ - 0.4])
        difference() {
            cylinder(r = gem_radius + halo_radial_offset + halo_stone_dia/2 + 0.2, h = 0.8, $fn=48);
            translate([0, 0, -0.1])
            cylinder(r = gem_radius + halo_radial_offset - halo_stone_dia/2 - 0.2, h = 1.0, $fn=48);
        }
    }
}

module halo_stones() {
    r_halo = gem_radius + halo_radial_offset;
    z_halo = haloPlaneZ;
    for (i = [0 : halo_stone_count - 1]) {
        angle = i * 360 / halo_stone_count;
        rotate([0, 0, angle])
        translate([r_halo, 0, z_halo])
        color(stone_color) {
            cylinder(r1 = halo_stone_dia/2, r2 = 0, h = halo_stone_dia/2, $fn=12);
            rotate([180, 0, 0])
            cylinder(r1 = halo_stone_dia/2, r2 = 0, h = halo_stone_dia/2, $fn=12);
        }
    }
}

module prongs() {
    prong_angles = [45, 135, 225, 315];
    color(ring_color) {
        for (a = prong_angles) {
            rotate([0, 0, a]) {
                // Base point (embedded in gallery)
                p1 = [gem_radius + 0.15, 0, stoneGirdleZ - 1.0];
                // Bend point (riding up the crown)
                p2 = [gem_radius + 0.05, 0, stoneGirdleZ + 0.6 * gem_crown_height];
                // Tip point (curled over the table)
                p3 = [gem_radius * 0.5, 0, prongTipZ];

                hull() {
                    translate(p1) sphere(r = 0.4, $fn=12);
                    translate(p2) sphere(r = 0.4, $fn=12);
                }
                hull() {
                    translate(p2) sphere(r = 0.4, $fn=12);
                    translate(p3) sphere(r = 0.3, $fn=12);
                }
            }
        }
    }
}

module pave_stones() {
    angles = [12, 24, 36, 48, 60, 72, 84];
    laterals = [-15, 0, 15];
    color(stone_color) {
        for (side = [-1, 1]) {
            for (a = angles) {
                for (lat = laterals) {
                    dia = (lat == 0) ? 1.4 : 0.9;
                    angleFromHead = side * a;
                    beta = lat;
                    radial = true_crest_radial + 0.1 + band_tube_radius * (cos(beta) - 1);

                    rotate([0, angleFromHead, 0])
                    rotate([lat, 0, 0])
                    translate([0, 0, radial]) {
                        cylinder(r1 = dia/2, r2 = 0, h = dia/2, $fn=12);
                        rotate([180, 0, 0])
                        cylinder(r1 = dia/2, r2 = 0, h = dia/2, $fn=12);
                    }
                }
            }
        }
    }
}

// --- Assembly ---
union() {
    ring_band_base();
    gallery_basket();
    halo_stones();
    prongs();
    center_stone();
    pave_stones();
}
