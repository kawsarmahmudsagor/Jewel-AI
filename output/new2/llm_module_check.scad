/*
   Procedural Cathedral Ring with Pavé Bridge
   Generated from Expert Jewelry CAD Analysis
*/

// --- Global Parameters ---
$fn = 48;

ring_inner_radius = 8.25;
width_top = 3.0;
width_bottom = 2.0;
thickness_top = 2.2;
thickness_bottom = 1.8;

band_tube_radius = thickness_top / 2;
band_apex_z = ring_inner_radius + band_tube_radius;
true_crest_radial = band_apex_z + band_tube_radius;

gem_radius = 3.25;
gem_depth = 4.0;

stone_color = "#E8F4FF";
ring_color = "#D4AF37";

// World Z coordinates mapped from assembly stack
galleryBaseZ_world = band_apex_z + 1.5;
galleryTopZ_world = band_apex_z + 4.5;
stoneGirdleZ_world = band_apex_z + 4.5;
stoneTableZ_world = band_apex_z + 5.54;
prongTipZ_world = band_apex_z + 5.8;

// Pavé data on the bridge
pave_data = [
    [-15, 2.0],
    [-10, 2.2],
    [-5, 2.3],
    [0, 2.4],
    [5, 2.3],
    [10, 2.2],
    [15, 2.0]
];

// --- Helper Functions ---
function clamp(val, min_val, max_val) = min(max(val, min_val), max_val);
function bridge_height(a) = let(abs_a = abs(a)) abs_a > 22 ? 0 : (1 - abs_a/22) * 2.4;

// --- Modules ---

module half_round_profile(w, t) {
    // Creates a half-round profile in Y-Z plane
    scale([1, w, 2 * t])
    intersection() {
        rotate([0, 90, 0]) cylinder(h = 1, r = 0.5, center = true, $fn=24);
        translate([0, 0, 0.25]) cube([1.1, 1.1, 0.5], center=true);
    }
}

module band_slice(angle) {
    angle_from_top = abs(angle > 180 ? angle - 360 : angle);
    factor = angle_from_top / 180;
    w = width_top * (1 - factor) + width_bottom * factor;
    t = thickness_top * (1 - factor) + thickness_bottom * factor;
    
    rotate([0, angle, 0])
    translate([0, 0, ring_inner_radius])
    scale([0.1, 1, 1])
    half_round_profile(w, t);
}

module ring_band_base() {
    steps = 64;
    color(ring_color) {
        for (i = [0 : steps-1]) {
            angle1 = i * 360 / steps;
            angle2 = (i + 1) * 360 / steps;
            // Leave a gap at the very top where the bridge and gallery sit
            if (abs(angle1 > 180 ? angle1 - 360 : angle1) > 20 || abs(angle2 > 180 ? angle2 - 360 : angle2) > 20) {
                hull() {
                    band_slice(angle1);
                    band_slice(angle2);
                }
            }
        }
    }
}

function shoulder_point(t, start_angle, end_angle, x_end, z_end) = 
    let(
        angle = start_angle + (end_angle - start_angle) * t,
        radial_band = ring_inner_radius + thickness_top/2,
        x_band = radial_band * sin(angle),
        z_band = radial_band * cos(angle),
        x = x_band * (1 - t) + x_end * t,
        z = z_band + (z_end - z_band) * sin(t * 90)
    ) [x, 0, z];

module shoulder_half(side) {
    steps = 15;
    start_angle = 40 * side;
    end_angle = 5 * side;
    x_end = (gem_radius + 0.1) * side;
    z_end = galleryTopZ_world - 0.5;
    
    for (i = [0 : steps-1]) {
        t1 = i / steps;
        t2 = (i + 1) / steps;
        
        p1 = shoulder_point(t1, start_angle, end_angle, x_end, z_end);
        p2 = shoulder_point(t2, start_angle, end_angle, x_end, z_end);
        
        w1 = width_top * (1 - t1*0.4);
        th1 = thickness_top * (1 - t1*0.4);
        w2 = width_top * (1 - t2*0.4);
        th2 = thickness_top * (1 - t2*0.4);
        
        hull() {
            translate(p1) rotate([0, -start_angle * (1-t1), 0]) scale([th1, w1, th1]) sphere(r=0.5, $fn=12);
            translate(p2) rotate([0, -start_angle * (1-t2), 0]) scale([th2, w2, th2]) sphere(r=0.5, $fn=12);
        }
    }
}

module cathedral_shoulders() {
    color(ring_color) {
        shoulder_half(1);
        shoulder_half(-1);
    }
}

module bridge_slice(a) {
    h = bridge_height(a);
    rotate([0, a, 0])
    translate([0, 0, ring_inner_radius])
    scale([0.1, width_top, 1])
    translate([0, 0, (thickness_top + h)/2])
    cube([1, 1, thickness_top + h], center=true);
}

module bridge_arch() {
    color(ring_color) {
        steps = 20;
        for (i = [0 : steps-1]) {
            a1 = -22 + i * 44 / steps;
            a2 = -22 + (i + 1) * 44 / steps;
            hull() {
                bridge_slice(a1);
                bridge_slice(a2);
            }
        }
    }
}

module place_pave_stone(angle, lateral, height, stone_d) {
    theta = 90 + angle;
    beta = clamp(lateral, -85, 85);
    radial = true_crest_radial + height + band_tube_radius * (cos(beta) - 1);
    radial_clamped = max(radial, ring_inner_radius + 0.05);
    w = band_tube_radius * sin(beta);
    
    x = radial_clamped * cos(theta);
    y = -w;
    z = radial_clamped * sin(theta);
    
    translate([x, y, z])
    rotate([0, -angle, 0])
    children();
}

module accent_stone(d) {
    r = d/2;
    color(stone_color)
    translate([0, 0, -r*0.4])
    union() {
        cylinder(h = r*0.4, r1 = r, r2 = r*0.6, $fn=12);
        mirror([0,0,1]) cylinder(h = r*0.8, r1 = r, r2 = 0, $fn=12);
    }
}

module accent_cutter(d) {
    r = d/2;
    translate([0, 0, -r*2.5])
    cylinder(h = r*4, r = r*1.05, $fn=12);
}

module pave_beads(d) {
    r = d/2;
    color(ring_color) {
        translate([0, r + 0.1, 0.1]) sphere(r = 0.15, $fn=8);
        translate([0, -(r + 0.1), 0.1]) sphere(r = 0.15, $fn=8);
    }
}

module milgrain_beads() {
    step_angle = 2.0;
    for (a = [-20 : step_angle : 20]) {
        h = bridge_height(a);
        radial = true_crest_radial + h;
        place_milgrain_bead(a, width_top/2 - 0.15, radial);
        place_milgrain_bead(a, -width_top/2 + 0.15, radial);
    }
}

module place_milgrain_bead(angle, y_offset, radial) {
    theta = 90 + angle;
    x = radial * cos(theta);
    z = radial * sin(theta);
    color(ring_color)
    translate([x, y_offset, z])
    sphere(r = 0.12, $fn=8);
}

module center_stone() {
    color(stone_color) {
        // Crown
        translate([0, 0, stoneGirdleZ_world])
        cylinder(h = stoneTableZ_world - stoneGirdleZ_world, r1 = gem_radius, r2 = gem_radius * 0.55, $fn=32);
        // Pavilion
        translate([0, 0, stoneGirdleZ_world])
        mirror([0, 0, 1])
        cylinder(h = gem_depth - (stoneTableZ_world - stoneGirdleZ_world), r1 = gem_radius, r2 = 0, $fn=32);
    }
}

module prongs() {
    prong_angles = [45, 135, 225, 315];
    for (a = prong_angles) {
        prong_single(a);
    }
}

module prong_single(angle) {
    cos_a = cos(angle);
    sin_a = sin(angle);
    
    r_base = gem_radius + 0.15;
    z_base = stoneGirdleZ_world - 1.5;
    p_base = [r_base * cos_a, r_base * sin_a, z_base];
    
    r_bend = gem_radius + 0.05;
    z_bend = stoneGirdleZ_world + 0.6 * (stoneTableZ_world - stoneGirdleZ_world);
    p_bend = [r_bend * cos_a, r_bend * sin_a, z_bend];
    
    r_tip = gem_radius * 0.65;
    z_tip = prongTipZ_world;
    p_tip = [r_tip * cos_a, r_tip * sin_a, z_tip];
    
    color(ring_color) {
        hull() {
            translate(p_base) sphere(r = 0.4, $fn=12);
            translate(p_bend) sphere(r = 0.35, $fn=12);
        }
        hull() {
            translate(p_bend) sphere(r = 0.35, $fn=12);
            translate(p_tip) sphere(r = 0.25, $fn=12);
        }
    }
}

module basket_gallery() {
    color(ring_color) {
        // Bottom Ring
        translate([0, 0, galleryBaseZ_world])
        difference() {
            cylinder(h = 0.6, r = gem_radius * 0.75, center = true, $fn=32);
            cylinder(h = 0.7, r = gem_radius * 0.75 - 0.6, center = true, $fn=32);
        }
        
        // Top Ring (Rail)
        translate([0, 0, stoneGirdleZ_world - 0.4])
        difference() {
            cylinder(h = 0.6, r = gem_radius, center = true, $fn=32);
            cylinder(h = 0.7, r = gem_radius - 0.6, center = true, $fn=32);
        }
        
        // Struts
        for (a = [0, 90, 180, 270]) {
            hull() {
                rotate([0, 0, a])
                translate([gem_radius * 0.75 - 0.3, 0, galleryBaseZ_world])
                sphere(r = 0.3, $fn=12);
                
                rotate([0, 0, a])
                translate([gem_radius - 0.3, 0, stoneGirdleZ_world - 0.4])
                sphere(r = 0.3, $fn=12);
            }
        }
    }
}

// --- Assembly ---

union() {
    // Metal components with pave cuts subtracted
    difference() {
        union() {
            ring_band_base();
            cathedral_shoulders();
            bridge_arch();
            basket_gallery();
            prongs();
            milgrain_beads();
            
            // Pave beads
            for (p = pave_data) {
                place_pave_stone(p[0], 0, p[1], 1.2) {
                    pave_beads(1.2);
                }
            }
        }
        
        // Pave cutters
        for (p = pave_data) {
            place_pave_stone(p[0], 0, p[1], 1.2) {
                accent_cutter(1.2);
            }
        }
    }
    
    // Gemstones
    center_stone();
    for (p = pave_data) {
        place_pave_stone(p[0], 0, p[1], 1.2) {
            accent_stone(1.2);
        }
    }
}
