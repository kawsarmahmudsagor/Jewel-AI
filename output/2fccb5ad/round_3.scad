/*
  Procedural Jewelry CAD - Square Double-Halo Signet Ring
  Fully refined to match reference photo with double-row halo and integrated shoulders
*/

// --- Global Parameters ---
$fn = 48;

// --- Ring Band Module ---
module band_slice(theta) {
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

// --- Shoulder Transition Module ---
module shoulder_transition() {
    // Creates a smooth, solid transition from the band shoulders to the square head
    hull() {
        intersection() {
            ring_band_base();
            translate([0, 0, 8.0]) cube([22, 13, 8], center=true);
        }
        translate([0, 0, 11.0])
        cube([11.5, 11.5, 0.5], center=true);
    }
}

// --- Shoulder Grooves Subtraction ---
module groove_cutter() {
    // 3 parallel, elegant grooves on each shoulder that follow the slope
    for (side = [-1, 1]) {
        for (y_offset = [-2.2, 0, 2.2]) {
            translate([side * 7.5, y_offset, 8.5])
            rotate([0, side * 40, 0])
            cylinder(r=0.45, h=9, center=true, $fn=12);
        }
    }
}

// --- Square Double-Halo Module ---
module square_halo() {
    translate([0, 0, 11.0]) {
        difference() {
            // Outer square plate with rounded corners
            hull() {
                for (x = [-5.1, 5.1]) {
                    for (y = [-5.1, 5.1]) {
                        translate([x, y, 0])
                        cylinder(r=1.0, h=2.0, $fn=16);
                    } 
                }
            }
            // Center hole for stone
            translate([0, 0, -0.5])
            cylinder(r=2.4, h=3.0, $fn=32);
            
            // Recessed channel for outer halo stones
            translate([0, 0, 1.4])
            difference() {
                cube([11.2, 11.2, 0.8], center=true);
                cube([9.6, 9.6, 1.0], center=true);
            }

            // Recessed channel for inner halo stones
            translate([0, 0, 1.6])
            difference() {
                cube([8.2, 8.2, 0.8], center=true);
                cube([6.6, 6.6, 1.0], center=true);
            }
        }
    }
}

// --- Prongs Module ---
module prong(angle) {
    r_girdle = 2.25;
    r_table = 1.3;
    prong_r = 0.4; 

    // Base point (sinks into halo plate)
    base_radial = r_girdle + 0.1;
    base_z = 12.5; 
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

    color("#F0F8FF", 0.8) {
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

// --- Double Halo Stones Module ---
module double_halo_stones() {
    stone_r = 0.45;
    stone_z = 12.8;
    
    color("#F0F8FF") {
        // Outer Row (7x7 grid boundary)
        outer_size = 10.4;
        outer_steps = [for (i = [0:6]) -outer_size/2 + i * (outer_size/6)];
        for (x = outer_steps) {
            for (y = outer_steps) {
                if (x == outer_steps[0] || x == outer_steps[6] || y == outer_steps[0] || y == outer_steps[6]) {
                    translate([x, y, stone_z])
                    sphere(r=stone_r, $fn=12);
                }
            }
        }

        // Inner Row (5x5 grid boundary)
        inner_size = 7.4;
        inner_steps = [for (i = [0:4]) -inner_size/2 + i * (inner_size/4)];
        for (x = inner_steps) {
            for (y = inner_steps) {
                if (x == inner_steps[0] || x == inner_steps[4] || y == inner_steps[0] || y == inner_steps[4]) {
                    translate([x, y, stone_z + 0.2])
                    sphere(r=stone_r, $fn=12);
                }
            }
        }
    }
}

// --- Main Assembly ---
union() {
    // Metal Components (White Gold / Platinum)
    color("#E5E9EC") {
        difference() {
            union() {
                ring_band_base();
                shoulder_transition();
            }
            groove_cutter();
        }
        
        square_halo();
        
        prong(45);
        prong(135);
        prong(225);
        prong(315);
    }
    
    // Gemstone Components
    center_stone();
    double_halo_stones();
}