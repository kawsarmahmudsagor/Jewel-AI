/*
   Procedural Split-Shank Halo Ring with Emerald-Cut Center Stone
   Generated from Ring Analysis JSON
*/

// --- Parameters ---
$fn = 48;

// Ring Band Dimensions
r_in = 8.25; // Inner radius (finger size 6)
t_band = 1.8; // Thickness at shoulder
w_band = 2.2; // Width at bottom shank
w_shoulder = 4.8; // Width at shoulder

// Coordinate System & Assembly Stack
band_apex_z = r_in + t_band/2; // 9.15
true_crest_radial = r_in + t_band; // 10.05

bandTopZ = 0;
galleryTopZ = 3.5;
stoneGirdleZ = 3.5;
stoneTableZ = 4.5;
prongTipZ = 4.8;
haloPlaneZ = 3.3;

function world_z(stack_z) = band_apex_z + (stack_z - bandTopZ);

z_girdle = world_z(stoneGirdleZ);
z_table = world_z(stoneTableZ);
z_prong_tip = world_z(prongTipZ);
z_halo = world_z(haloPlaneZ);
z_gallery_base = world_z(0);

// --- Helper Modules ---

module half_round_profile(w, t) {
    intersection() {
        resize([w, t*2]) circle(d=w, $fn=32);
        translate([-w, 0]) square([w*2, t]);
    }
}

module place_profile(theta, y_offset, w, t) {
    rotate([0, -theta, 0])
    translate([r_in + t/2, y_offset, 0])
    rotate([0, 90, 0])
    linear_extrude(height=0.1, center=true)
    half_round_profile(w, t);
}

module octagonal_prism(w, l, h) {
    c = min(w, l) * 0.15; // Corner cut size
    linear_extrude(height = h, center = true)
    polygon(points=[
        [-w/2+c, -l/2], [w/2-c, -l/2],
        [w/2, -l/2+c], [w/2, l/2-c],
        [w/2-c, l/2], [-w/2+c, l/2],
        [-w/2, l/2-c], [-w/2, -l/2+c]
    ]);
}

module place_on_rectangle(w, l, count) {
    p = 2 * (w + l);
    for (i = [0 : count-1]) {
        d = i * (p / count);
        x = (d < w) ? (-w/2 + d) :
            (d < w + l) ? (w/2) :
            (d < 2*w + l) ? (w/2 - (d - (w + l))) :
            (-w/2);
        y = (d < w) ? (-l/2) :
            (d < w + l) ? (-l/2 + (d - w)) :
            (d < 2*w + l) ? (l/2) :
            (l/2 - (d - (2*w + l)));
        translate([x, y, 0]) children();
    }
}

// --- Component Modules ---

module build_band() {
    step = 5;
    for (theta = [-90 : step : 270 - step]) {
        theta1 = theta;
        theta2 = theta + step;

        // Map to symmetric angle in [-90, 90]
        sa1 = (theta1 > 90) ? (180 - theta1) : theta1;
        sa2 = (theta2 > 90) ? (180 - theta2) : theta2;

        // Width and thickness interpolation
        w1 = w_band + (w_shoulder - w_band) * (sa1 - (-90)) / 180;
        w2 = w_band + (w_shoulder - w_band) * (sa2 - (-90)) / 180;
        t1 = 1.6 + (1.8 - 1.6) * (sa1 - (-90)) / 180;
        t2 = 1.6 + (1.8 - 1.6) * (sa2 - (-90)) / 180;

        // Split logic (starts at sa = -30)
        max_split_y = 2.0;
        y1 = (sa1 < -30) ? 0 : (sa1 - (-30)) / (90 - (-30)) * max_split_y;
        y2 = (sa2 < -30) ? 0 : (sa2 - (-30)) / (90 - (-30)) * max_split_y;

        if (sa1 < -30 && sa2 < -30) {
            hull() {
                place_profile(theta1, 0, w1, t1);
                place_profile(theta2, 0, w2, t2);
            }
        } else if (sa1 < -30 && sa2 >= -30) {
            hull() {
                place_profile(theta1, 0, w1, t1);
                place_profile(theta2, y2, w2/2, t2);
            }
            hull() {
                place_profile(theta1, 0, w1, t1);
                place_profile(theta2, -y2, w2/2, t2);
            }
        } else {
            // Arm 1 (+y)
            hull() {
                place_profile(theta1, y1, w1/2, t1);
                place_profile(theta2, y2, w2/2, t2);
            }
            // Arm 2 (-y)
            hull() {
                place_profile(theta1, -y1, w1/2, t1);
                place_profile(theta2, -y2, w2/2, t2);
            }
        }
    }
}

module shank_pave_stones() {
    stone_d = 1.1;
    for (side = [-1, 1]) {
        for (arm = [-1, 1]) {
            for (i = [0 : 5]) {
                sa = 0 + i * 15;
                theta = (side == 1) ? sa : (180 - sa);
                t = 1.6 + (1.8 - 1.6) * (sa - (-90)) / 180;
                max_split_y = 2.0;
                y_off = (sa < -30) ? 0 : (sa - (-30)) / (90 - (-30)) * max_split_y;
                radial = r_in + t + 0.1;

                x = radial * cos(theta);
                z = radial * sin(theta);
                y = arm * y_off;

                translate([x, y, z])
                color("#FFFFFF")
                sphere(d=stone_d, $fn=12);
            }
        }
    }
}

module gallery_supports() {
    color("#D4AF37") {
        // 4 vertical pillars supporting the halo
        for (sx = [-1, 1]) {
            for (sy = [-1, 1]) {
                px = sx * 3.2;
                py = sy * 4.2;
                hull() {
                    translate([px, py, z_gallery_base]) sphere(r=0.5, $fn=16);
                    translate([px, py, z_halo - 0.2]) sphere(r=0.5, $fn=16);
                }
            }
        }
        // Under-gallery support rail
        translate([0, 0, z_gallery_base + 0.3])
        difference() {
            cube([6.4, 8.4, 0.6], center=true);
            cube([5.2, 7.2, 1.0], center=true);
        }
    }
}

module halo_frame() {
    color("#D4AF37") {
        translate([0, 0, z_halo])
        difference() {
            // Outer octagonal frame
            octagonal_prism(9.5, 11.5, 1.2);
            // Inner cutout for center stone
            octagonal_prism(6.4, 8.4, 2.0);
            // Channel for pavé stones
            translate([0, 0, 0.3])
            octagonal_prism(8.1, 10.1, 1.0);
        }
    }
}

module halo_stones() {
    color("#FFFFFF") {
        translate([0, 0, z_halo + 0.3])
        place_on_rectangle(7.95, 9.95, 24)
        sphere(d=1.1, $fn=16);
    }
}

module center_stone() {
    color("#3B9EC6") {
        // Girdle
        translate([0, 0, z_girdle])
        octagonal_prism(6.0, 8.0, 0.2);

        // Crown
        hull() {
            translate([0, 0, z_girdle + 0.1])
            octagonal_prism(6.0, 8.0, 0.01);
            translate([0, 0, z_table])
            octagonal_prism(4.2, 5.6, 0.01);
        }

        // Pavilion
        hull() {
            translate([0, 0, z_girdle - 0.1])
            octagonal_prism(6.0, 8.0, 0.01);
            translate([0, 0, z_girdle - 3.0])
            octagonal_prism(0.6, 0.8, 0.01);
        }
    }
}

module prongs() {
    // 3-point bent claw prongs at the 4 corners
    for (sx = [-1, 1]) {
        for (sy = [-1, 1]) {
            // Base position (anchored in gallery)
            bx = sx * (3.0 + 0.3);
            by = sy * (4.0 + 0.3);
            bz = z_gallery_base;

            // Bend position (at girdle)
            mx = sx * (3.0 + 0.1);
            my = sy * (4.0 + 0.1);
            mz = z_girdle + 0.2;

            // Tip position (curled over table)
            tx = sx * (3.0 - 0.4);
            ty = sy * (4.0 - 0.4);
            tz = z_prong_tip;

            color("#D4AF37") {
                hull() {
                    translate([bx, by, bz]) sphere(r=0.4, $fn=16);
                    translate([mx, my, mz]) sphere(r=0.35, $fn=16);
                }
                hull() {
                    translate([mx, my, mz]) sphere(r=0.35, $fn=16);
                    translate([tx, ty, tz]) sphere(r=0.25, $fn=16);
                }
            }
        }
    }
}

// --- Final Assembly ---
union() {
    color("#D4AF37") build_band();
    shank_pave_stones();
    gallery_supports();
    halo_frame();
    halo_stones();
    center_stone();
    prongs();
}
