ring_inner_radius = 8.25;
band_thickness_top = 2.2;
band_tube_radius = band_thickness_top / 2; // 1.1
band_apex_z = ring_inner_radius + band_tube_radius; // 9.35
true_crest_radial = band_apex_z + band_tube_radius; // 10.45

gem_radius = 3.75;
gem_depth = 4.6;
gem_crown_height = 1.2;
gem_table_radius = gem_radius * 0.6;

ring_color = "#D4AF37";
stone_color = "#E8F4FF";

module comfort_profile(W, T) {
    r_corner = 0.3;
    hull() {
        translate([-W/2 + r_corner, r_corner]) circle(r = r_corner, $fn=16);
        translate([W/2 - r_corner, r_corner]) circle(r = r_corner, $fn=16);
        translate([-W/2 + r_corner, T - r_corner]) circle(r = r_corner, $fn=16);
        translate([W/2 - r_corner, T - r_corner]) circle(r = r_corner, $fn=16);
    }
}

module band_slice_3d(theta) {
    phi = (theta >= 90 && theta <= 270) ? theta - 90 : (theta < 90 ? 90 - theta : 450 - theta);
    W = 5.2 - (5.2 - 3.2) * (phi / 180);
    T = 2.2 - (2.2 - 1.7) * (phi / 180);
    
    rotate([0, 90 - theta, 0])
    rotate([90, 0, 0])
    linear_extrude(height = 0.1, center = true)
    translate([0, ring_inner_radius])
    comfort_profile(W, T);
}

module ring_band_base() {
    step = 10;
    color(ring_color) {
        for (theta = [0 : step : 350]) {
            hull() {
                band_slice_3d(theta);
                band_slice_3d(theta + step);
            }
        } 
    }
}

module place_pave_stone(angleFromHead, lateralOffset, heightAboveBandSurface, diameter) {
    radial = true_crest_radial + heightAboveBandSurface + band_tube_radius * (cos(lateralOffset) - 1);
    w = band_tube_radius * sin(lateralOffset);
    
    rotate([0, angleFromHead, 0])
    translate([0, -w, radial])
    children();
}

module gemstone_round(r, depth) {
    crown_h = depth * 0.3;
    pav_h = depth * 0.7;
    table_r = r * 0.6;
    
    color(stone_color) {
        hull() {
            translate([0, 0, 0]) cylinder(r = r, h = 0.05, center = true, $fn = 16);
            translate([0, 0, crown_h]) cylinder(r = table_r, h = 0.05, center = true, $fn = 16);
        }
        hull() { 
            translate([0, 0, 0]) cylinder(r = r, h = 0.05, center = true, $fn = 16);
            translate([0, 0, -pav_h]) cylinder(r = 0.1, h = 0.05, center = true, $fn = 16);
        }
    }
}

module pave_stones() {
    for (side = [-1, 1]) {
        for (angle = [12 : 6 : 72]) {
            for (lateral = [-15, 0, 15]) {
                place_pave_stone(side * angle, lateral, 0.1, 1.1) {
                    gemstone_round(1.1/2, 1.1 * 0.6);
                }
            }
        }
    }
}

module milgrain_beads() {
    color(ring_color) {
        for (side = [-1, 1]) {
            for (lateral = [-25, 25]) {
                for (angle = [10 : 2 : 74]) {
                    place_pave_stone(side * angle, lateral, 0.15, 0.35) {
                        sphere(r = 0.35/2, $fn = 8);
                    }
                }
            }
        }
    }
}

module prong(a) {
    r_prong = 0.45;
    
    p1 = [gem_radius * 0.65 * cos(a), gem_radius * 0.65 * sin(a), 9.55];
    p2 = [(gem_radius + 0.15) * cos(a), (gem_radius + 0.15) * sin(a), 13.55 - 0.2];
    p3 = [(gem_radius + 0.1) * cos(a), (gem_radius + 0.1) * sin(a), 13.55 + 0.6 * 1.2];
    p4 = [(gem_radius - 0.4) * cos(a), (gem_radius - 0.4) * sin(a), 15.05];
    
    color(ring_color) {
        hull() {
            translate(p1) sphere(r = r_prong, $fn = 12);
            translate(p2) sphere(r = r_prong, $fn = 12);
        }
        hull() {
            translate(p2) sphere(r = r_prong, $fn = 12);
            translate(p3) sphere(r = r_prong, $fn = 12);
        }
        hull() {
            translate(p3) sphere(r = r_prong, $fn = 12);
            translate(p4) sphere(r = r_prong * 0.7, $fn = 12);
        }
    }
}

module prongs() {
    prong_angles = [30, 90, 150, 210, 270, 330];
    for (a = prong_angles) {
        prong(a);
    }
}

module filigree_petal(a) {
    color(ring_color)
    rotate([0, 0, a])
    translate([gem_radius * 0.75, 0, 10.6])
    rotate([0, 45, 0])
    difference() {
        cylinder(r = 1.2, h = 0.3, center = true, $fn = 24);
        cylinder(r = 0.8, h = 0.4, center = true, $fn = 24);
    }
}

module gallery_basket() {
    color(ring_color) {
        // Bottom Ring
        translate([0, 0, 9.55])
        difference() {
            cylinder(r = gem_radius * 0.65 + 0.4, h = 0.6, center = true, $fn = 48);
            cylinder(r = gem_radius * 0.65 - 0.4, h = 0.7, center = true, $fn = 48);
        }
        
        // Mid Ring
        translate([0, 0, 11.55])
        difference() {
            cylinder(r = gem_radius * 0.85 + 0.3, h = 0.5, center = true, $fn = 48);
            cylinder(r = gem_radius * 0.85 - 0.3, h = 0.6, center = true, $fn = 48);
        }
        
        // Top Ring (Girdle Rail)
        translate([0, 0, 13.55 - 0.25])
        difference() {
            cylinder(r = gem_radius + 0.2, h = 0.5, center = true, $fn = 48);
            cylinder(r = gem_radius - 0.4, h = 0.6, center = true, $fn = 48);
        }
        
        // Filigree Petals
        for (a = [0, 60, 120, 180, 240, 300]) {
            filigree_petal(a);
        }
    }
}

module center_stone() {
    translate([0, 0, 13.55]) {
        gemstone_round(3.75, 4.6);
    }
}

union() {
    ring_band_base();
    pave_stones();
    milgrain_beads();
    gallery_basket();
    prongs();
    center_stone();
}