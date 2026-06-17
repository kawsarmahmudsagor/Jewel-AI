$fn = 48;

// --- Color Definitions ---
ring_color = "#E5A490"; // Rose Gold to match reference photo
stone_color = "#FFFFFF"; // Bright colorless diamond

// --- Dimensions & Parameters ---
ring_inner_radius = 8.25;
band_width_top = 4.5;
band_width_bottom = 2.5;
band_thickness_top = 1.8;
band_thickness_bottom = 1.6;
band_tube_radius = band_thickness_top / 2;
band_apex_z = ring_inner_radius + band_tube_radius;
true_crest_radial = ring_inner_radius + band_thickness_top;

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

gem_crown_height = stoneTableZ - stoneGirdleZ;
gem_pavilion_depth = gem_depth - gem_crown_height;

// Halo Parameters
halo_stone_count = 12; // 12 stones matches the diagonal prong alignment perfectly
halo_stone_dia = 1.2;
halo_radial_offset = 0.7;

// --- Modules ---

module band_profile_2d_xy(w, t) {
    // Low-dome profile with a flat top and curved shoulders to support triple-row pavé
    flat_w = w * 0.5;
    steps = 6;
    points = concat(
        [[ring_inner_radius, -w/2]],
        [for (i = [0:steps]) let(f = i/steps, y = -w/2 + (w - flat_w)/2 * f)
            [ring_inner_radius + t * sin(f * 90), y]],
        [for (i = [0:steps]) let(f = i/steps, y = -flat_w/2 + flat_w * f)
            [ring_inner_radius + t, y]],
        [for (i = [0:steps]) let(f = i/steps, y = flat_w/2 + (w - flat_w)/2 * f)
            [ring_inner_radius + t * cos(f * 90), y]],
        [[ring_inner_radius, w/2]]
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

module stone_geometry(dia) {
    cylinder(r1 = dia/2, r2 = dia/2 * 0.55, h = dia * 0.3, $fn=16);
    rotate([180, 0, 0])
    cylinder(r1 = dia/2, r2 = 0, h = dia * 0.5, $fn=16);
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
            cylinder(r = gem_radius * 0.7, h = 0.6, $fn=32);
            translate([0, 0, -0.1])
            cylinder(r = gem_radius * 0.5, h = 0.8, $fn=32);
        }

        // Struts connecting base ring to the halo platter
        for (a = [45, 135, 225, 315]) {
            rotate([0, 0, a])
            hull() {
                translate([gem_radius * 0.6, 0, galleryBaseZ + 0.3])
                sphere(r = 0.4, $fn=16);
                translate([gem_radius * 0.9, 0, haloPlaneZ - 0.2])
                sphere(r = 0.4, $fn=16);
            }
        }

        // Scalloped Halo Platter
        translate([0, 0, haloPlaneZ])
        difference() {
            union() {
                cylinder(r = gem_radius + halo_radial_offset, h = 0.8, center = true, $fn=48);
                for (i = [0 : halo_stone_count - 1]) {
                    angle = i * 360 / halo_stone_count;
                    rotate([0, 0, angle])
                    translate([gem_radius + halo_radial_offset, 0, 0])
                    cylinder(r = halo_stone_dia/2 + 0.25, h = 0.8, center = true, $fn=24);
                } 
            }
            // Subtract the stones
            for (i = [0 : halo_stone_count - 1]) {
                angle = i * 360 / halo_stone_count;
                rotate([0, 0, angle])
                translate([gem_radius + halo_radial_offset, 0, 0])
                cylinder(r = halo_stone_dia/2 - 0.05, h = 1.2, center = true, $fn=24);
            }
            // Hollow out center
            cylinder(r = gem_radius - 0.2, h = 1.2, center = true, $fn=48);
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
            stone_geometry(halo_stone_dia);
        }
    }
}

module halo_prongs() {
    r_halo = gem_radius + halo_radial_offset;
    color(ring_color) {
        for (i = [0 : halo_stone_count - 1]) {
            angle = (i + 0.5) * 360 / halo_stone_count;
            
            // Outer shared prong
            rotate([0, 0, angle])
            translate([r_halo + 0.5, 0, haloPlaneZ + 0.1])
            cylinder(r1 = 0.25, r2 = 0.18, h = 0.5, $fn=12);

            // Inner shared prong
            rotate([0, 0, angle])
            translate([r_halo - 0.5, 0, haloPlaneZ + 0.1])
            cylinder(r1 = 0.25, r2 = 0.18, h = 0.5, $fn=12);
        }
    }
}

module prongs() {
    // Diagonal prong positions (45, 135, 225, 315) matching the reference photo
    prong_angles = [45, 135, 225, 315];
    color(ring_color) {
        for (a = prong_angles) {
            rotate([0, 0, a]) {
                p1 = [gem_radius - 0.1, 0, stoneGirdleZ - 0.8];
                p2 = [gem_radius - 0.05, 0, stoneGirdleZ + 0.5 * gem_crown_height];
                p3 = [gem_radius - 0.35, 0, prongTipZ];

                hull() {
                    translate(p1) sphere(r = 0.38, $fn=12);
                    translate(p2) sphere(r = 0.38, $fn=12);
                }
                hull() {
                    translate(p2) sphere(r = 0.38, $fn=12);
                    translate(p3) sphere(r = 0.30, $fn=12);
                }
            }
        } 
    }
}

module pave_stones() {
    angles = [12, 22, 32, 42, 52, 62, 72, 82];
    color(stone_color) {
        for (side = [-1, 1]) {
            for (theta = angles) {
                factor = (1 + cos(theta)) / 2;
                w = band_width_bottom + (band_width_top - band_width_bottom) * factor;
                t = band_thickness_bottom + (band_thickness_top - band_thickness_bottom) * factor;
                r_outer = ring_inner_radius + t;
                flat_w = w * 0.5;

                // 1. Center Row (Larger stones)
                let (
                    dia = 1.3,
                    r_stone = r_outer - 0.1
                ) {
                    rotate([0, side * theta, 0])
                    translate([0, 0, r_stone])
                    stone_geometry(dia);
                }

                // 2. Side Rows (Smaller stones)
                let (
                    dia = 0.9,
                    y_offset = flat_w * 0.5,
                    r_stone = r_outer - 0.15
                ) {
                    rotate([0, side * theta, 0])
                    translate([0, -y_offset, r_stone])
                    stone_geometry(dia);

                    rotate([0, side * theta, 0])
                    translate([0, y_offset, r_stone])
                    stone_geometry(dia);
                }
            }
        }
    }
}

module pave_beads() {
    angles = [12, 22, 32, 42, 52, 62, 72, 82];
    color(ring_color) {
        for (side = [-1, 1]) {
            for (theta = angles) {
                factor = (1 + cos(theta)) / 2;
                w = band_width_bottom + (band_width_top - band_width_bottom) * factor;
                t = band_thickness_bottom + (band_thickness_top - band_thickness_bottom) * factor;
                r_outer = ring_inner_radius + t;
                flat_w = w * 0.5;

                for (t_offset = [-5, 5]) {
                    let (
                        bead_theta = theta + t_offset,
                        bead_factor = (1 + cos(bead_theta)) / 2,
                        bead_w = band_width_bottom + (band_width_top - band_width_bottom) * bead_factor,
                        bead_t = band_thickness_bottom + (band_thickness_top - band_thickness_bottom) * bead_factor,
                        bead_r = ring_inner_radius + bead_t
                    ) {
                        y_positions = [-flat_w * 0.7, -flat_w * 0.2, flat_w * 0.2, flat_w * 0.7];
                        for (y = y_positions) {
                            let (
                                is_side = abs(y) > flat_w/2,
                                h_offset = is_side ? (bead_r - 0.05) : bead_r,
                                bead_size = 0.32
                            ) {
                                rotate([0, side * bead_theta, 0])
                                translate([0, y, h_offset])
                                sphere(r = bead_size, $fn=12);
                            }
                        }
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
    halo_prongs();
    prongs();
    center_stone();
    pave_stones();
    pave_beads();
}
