// Ring parameters
ring_inner_radius = 8.25;
band_width = 1.8;
band_thickness = 1.6;
band_tube_radius = band_thickness / 2;
band_apex_z = ring_inner_radius + band_tube_radius;
true_crest_radial = ring_inner_radius + band_thickness;

// Assembly stack
bandTopZ = 0;
galleryTopZ = 3.4;
stoneGirdleZ = 3.4;
stoneTableZ = 4.2;
prongTipZ = 4.4;

function world_z(stackValue) = band_apex_z + (stackValue - bandTopZ);

galleryTopZ_world = world_z(galleryTopZ);
stoneGirdleZ_world = world_z(stoneGirdleZ);
stoneTableZ_world = world_z(stoneTableZ);
prongTipZ_world = world_z(prongTipZ);

// Gemstone parameters
gem_radius = 2.6;
gem_table_radius = gem_radius * 0.6;
stone_color = "#E8F4FF";
ring_color = "#D4AF37";

// Helper functions
function lerp(a, b, t) = a + (b - a) * t;
function cubic_bezier(t, p0, p1, p2, p3) = 
    pow(1-t, 3)*p0 + 3*pow(1-t, 2)*t*p1 + 3*(1-t)*pow(t, 2)*p2 + pow(t, 3)*p3;

module band_profile() {
    translate([ring_inner_radius, 0])
    intersection() {
        scale([band_thickness, band_width/2])
        circle(r=1, $fn=32);
        translate([0, -band_width/2])
        square([band_thickness, band_width]);
    }
}

module ring_band_base() {
    color(ring_color)
    rotate([90, 0, 0])
    rotate_extrude(angle = 360, $fn=96)
    band_profile();
}

module shoulder_slice(t, sign) {
    angle_start = 65;
    theta = 90 - sign * angle_start;
    r_start = ring_inner_radius + band_thickness/2;
    x0 = r_start * cos(theta);
    z0 = r_start * sin(theta);
    
    x3 = sign * (gem_radius + 0.2);
    z3 = galleryTopZ_world;
    
    dx_tan = -sign * sin(theta);
    dz_tan = sign * cos(theta);
    
    L1 = 4.0;
    x1 = x0 + L1 * dx_tan;
    z1 = z0 + L1 * dz_tan;
    
    L2 = 3.0;
    x2 = x3;
    z2 = z3 - L2;
    
    x = cubic_bezier(t, x0, x1, x2, x3);
    z = cubic_bezier(t, z0, z1, z2, z3);
    
    dx = 3*pow(1-t, 2)*(x1-x0) + 6*(1-t)*t*(x2-x1) + 3*pow(t, 2)*(x3-x2);
    dz = 3*pow(1-t, 2)*(z1-z0) + 6*(1-t)*t*(z2-z1) + 3*pow(t, 2)*(z3-z2);
    ang = atan2(dz, dx);
    
    w = lerp(band_width, 1.5, t);
    th = lerp(band_thickness, 1.2, t);
    
    translate([x, 0, z])
    rotate([0, ang - 90, 0])
    scale([th/2, w/2, 1])
    cylinder(h=0.02, r=1, center=true, $fn=24);
}

module cathedral_shoulders() {
    color(ring_color) {
        points = 20;
        for(sign = [-1, 1]) {
            for(i=[0:points-1]) {
                hull() {
                    shoulder_slice(i/points, sign);
                    shoulder_slice((i+1)/points, sign);
                }
            }
        }
    }
}

module gallery_rail() {
    color(ring_color) {
        rail_z = stoneGirdleZ_world - 1.5;
        
        z_base = band_apex_z - 0.5;
        z_bend = stoneGirdleZ_world + 0.6 * (stoneTableZ_world - stoneGirdleZ_world);
        r_base = gem_radius - 0.2;
        r_bend = gem_radius + 0.1;
        
        t_prong = (rail_z - z_base) / (z_bend - z_base);
        r_prong = r_base + t_prong * (r_bend - r_base);
        
        translate([0, 0, rail_z])
        rotate_extrude($fn=64)
        translate([r_prong, 0])
        circle(r=0.4, $fn=16);
    }
}

module prong(angle) {
    r_base = gem_radius - 0.2;
    z_base = band_apex_z - 0.5;
    
    r_bend = gem_radius + 0.1;
    z_bend = stoneGirdleZ_world + 0.6 * (stoneTableZ_world - stoneGirdleZ_world);
    
    r_tip = gem_table_radius - 0.2;
    z_tip = prongTipZ_world;
    
    prong_r = 0.4;
    
    color(ring_color) {
        hull() {
            translate([r_base * cos(angle), r_base * sin(angle), z_base])
            sphere(r=prong_r, $fn=16);
            translate([r_bend * cos(angle), r_bend * sin(angle), z_bend])
            sphere(r=prong_r, $fn=16);
        }
        hull() {
            translate([r_bend * cos(angle), r_bend * sin(angle), z_bend])
            sphere(r=prong_r, $fn=16);
            translate([r_tip * cos(angle), r_tip * sin(angle), z_tip])
            sphere(r=prong_r*0.7, $fn=16);
        }
    }
}

module prongs() {
    angles = [45, 135, 225, 315];
    for(a = angles) {
        prong(a);
    }
}

module center_stone() {
    color(stone_color) {
        // Pavilion
        hull() {
            translate([0, 0, stoneGirdleZ_world])
            cylinder(r=gem_radius, h=0.1, center=true, $fn=64);
            translate([0, 0, stoneGirdleZ_world - 2.4])
            cylinder(r=0.1, h=0.1, center=true, $fn=16);
        }
        // Crown
        hull() {
            translate([0, 0, stoneGirdleZ_world])
            cylinder(r=gem_radius, h=0.1, center=true, $fn=64);
            translate([0, 0, stoneTableZ_world])
            cylinder(r=gem_table_radius, h=0.1, center=true, $fn=64);
        }
    }
}

module accent_stone(r) {
    color(stone_color) {
        hull() {
            cylinder(r=r, h=0.05, center=true, $fn=16);
            translate([0, 0, -r*0.6]) cylinder(r=0.05, h=0.05, center=true, $fn=8);
        }
        hull() {
            cylinder(r=r, h=0.05, center=true, $fn=16);
            translate([0, 0, r*0.3]) cylinder(r=r*0.6, h=0.05, center=true, $fn=16);
        }
    }
}

module pave_stones() {
    angleFromHeadDegrees = 180;
    theta = 90 + angleFromHeadDegrees;
    
    // Inner shank placement
    radial = ring_inner_radius + 0.1;
    
    x = radial * cos(theta);
    y = 0;
    z = radial * sin(theta);
    
    rot_y = atan2(-cos(theta), -sin(theta));
    
    translate([x, y, z])
    rotate([0, rot_y, 0])
    accent_stone(0.5);
}

// Main Assembly
union() {
    ring_band_base();
    cathedral_shoulders();
    gallery_rail();
    prongs();
    center_stone();
    pave_stones();
}
