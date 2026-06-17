/*
  Procedural Jewelry CAD - Square Halo Signet Ring
  Auto-generated from expert analysis JSON
*/

// --- Global Parameters ---
$fn = 48;

// --- Ring Band Module ---
module band_slice(theta) {
    // theta goes from -90 (bottom) to 90 (top) to 270 (bottom)
    a = 180 - abs(90 - theta);
    w = 5.0 + (11.0 - 5.0) * (a / 180);
    t = 1.8 + (2.2 - 1.8) * (a / 180);
    r_in = 9.5;
    
    rotate([0, -theta, 0])
    translate([r_in, -w/2, -0.05])
    cube([t, w, 0.1]);
}

module ring_band_base() {
    step = 5;
    for (theta = [-90 : step : 270 - step]) {
        hull() {
            band_slice(theta);
            band_slice(theta + step);
        }
    }
}

// --- Square Halo Module ---
module square_halo() {
    // Sinks slightly into the band (from Z = 11.5 to 13.2)
    translate([0, 0, 11.5 + 1.7/2]) {
        difference() {
            // Outer square plate with rounded corners
            hull() {
                for (x = [-4.75, 4.75]) {
                    for (y = [-4.75, 4.75]) {
                        translate([x, y, -1.7/2])
                        cylinder(r=0.75, h=1.7, $fn=16);
                    }
                } 
            }
            // Center hole for stone
            cylinder(r=2.4, h=3, center=true, $fn=32);
        }
    }
}

// --- Prongs Module ---
module prong(angle) {
    r_girdle = 2.25;
    r_table = 1.3;
    prong_r = 0.4; // thickness = 0.8 -> radius = 0.4

    // 3-Point Bent Claw Design (BUG #3 Prevention)
    // Base point (sinks into halo plate)
    base_radial = r_girdle + 0.1;
    base_z = 13.0;
    p_base = [base_radial * cos(angle), base_radial * sin(angle), base_z];

    // Bend point (rides up over crown)
    bend_radial = r_girdle - 0.1;
    bend_z = 14.38;
    p_bend = [bend_radial * cos(angle), bend_radial * sin(angle), bend_z];

    // Tip point (curls inward over table)
    tip_radial = r_table - 0.2;
    tip_z = 14.8;
    p_tip = [tip_radial * cos(angle), tip_radial * sin(angle), tip_z];

    hull() {
        translate(p_base) sphere(r=prong_r, $fn=16);
        translate(p_bend) sphere(r=prong_r, $fn=16);
    }
    hull() {
        translate(p_bend) sphere(r=prong_r, $fn=16);
        translate(p_tip) sphere(r=prong_r, $fn=16);
    }
}

// --- Center Stone Module ---
module center_stone() {
    girdle_z = 13.9;
    crown_h = 0.8;
    pav_d = 1.9;
    girdle_t = 0.1;
    r_girdle = 2.25;
    r_table = 1.3;

    color("#E8F4FF", 0.8) {
        // Crown
        hull() {
            translate([0, 0, girdle_z + girdle_t])
            cylinder(r=r_girdle, h=0.05, $fn=32);
            translate([0, 0, girdle_z + girdle_t + crown_h])
            cylinder(r=r_table, h=0.05, $fn=32);
        }
        // Girdle
        translate([0, 0, girdle_z])
        cylinder(r=r_girdle, h=girdle_t, $fn=32);
        // Pavilion
        hull() {
            translate([0, 0, girdle_z])
            cylinder(r=r_girdle, h=0.05, $fn=32);
            translate([0, 0, girdle_z - pav_d])
            cylinder(r=0.1, h=0.05, $fn=32);
        }
    }
}

// --- Halo Stones Module ---
module halo_stones() {
    stone_r = 0.6;
    stone_z = 13.2; // Sits on top of the halo
    side_len = 8.4;
    steps = [for (i = [0:5]) -side_len/2 + i * (side_len/5)];
    
    color("#E8F4FF") {
        for (x = steps) {
            for (y = steps) {
                // Place only on the boundary of the 6x6 grid (20 stones total)
                if (x == steps[0] || x == steps[5] || y == steps[0] || y == steps[5]) {
                    translate([x, y, stone_z])
                    sphere(r=stone_r, $fn=12);
                }
            }
        }
    }
}

// --- Pave Stones Module (Band-relative, BUG #1 Prevention) ---
module pave_stones() {
    true_crest_radial = 11.7 + 1.1;
    ring_inner_radius = 9.5;
    band_tube_radius = 1.1;
    
    stones_data = [
        [0.0, 15.0, 1.5],
        [0.0, -15.0, 1.5],
        [5.0, 15.0, 1.5],
        [-5.0, -15.0, 1.5]
    ];
    
    color("#E8F4FF") {
        for (stone = stones_data) {
            angleFromHeadDegrees = stone[0];
            lateralOffsetDegrees = stone[1];
            heightAboveBandSurface = stone[2];
            
            theta = 90 + angleFromHeadDegrees;
            beta = lateralOffsetDegrees < -85 ? -85 : (lateralOffsetDegrees > 85 ? 85 : lateralOffsetDegrees);
            
            radial_temp = true_crest_radial + heightAboveBandSurface + band_tube_radius * (cos(beta) - 1);
            radial = radial_temp < (ring_inner_radius + 0.05) ? (ring_inner_radius + 0.05) : radial_temp;
            
            w = band_tube_radius * sin(beta);
            
            x = radial * cos(theta);
            y = -w;
            z = radial * sin(theta);
            
            translate([x, y, z])
            sphere(r=0.6, $fn=12);
        }
    }
}

// --- Main Assembly ---
union() {
    // Metal Components
    color("#D4AF37") {
        difference() {
            ring_band_base();
            // Decorative central groove fading towards the bottom
            rotate([90, 0, 0])
            rotate_extrude($fn=90)
            translate([11.4, 0, 0])
            circle(r=0.4, $fn=12);
        }
        
        square_halo();
        
        prong(45);
        prong(135);
        prong(225);
        prong(315);
    }
    
    // Gemstone Components
    center_stone();
    halo_stones();
    pave_stones();
}