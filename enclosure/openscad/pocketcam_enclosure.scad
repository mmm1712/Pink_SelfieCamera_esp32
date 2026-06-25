
$fn = 80;


// part = "assembly";
// part = "back_cover";
// part = "accent_panel";
// part = "bezel_rings";
// part = "front_fit_test";
// part = "battery_fit_test";
// part = "display_screw_template";
// part = "front_shell";

part = "front_shell";


body_w = 60;

body_h_base = 66;
top_extra = 10;
body_h = body_h_base + top_extra;

body_z_shift = top_extra / 2;
body_bottom_z = -body_h_base / 2;
body_top_z = body_bottom_z + body_h;

front_depth = 20.0;


back_depth = 20.5;


lid_lip_depth = 5.0;
lid_lip_wall = 1.2;
lid_lip_clearance = 0.65;
lip_overlap = 2.0;   


back_outer_depth = back_depth - lid_lip_depth;

body_depth = front_depth + back_outer_depth;

corner_r = 10.0;
wall = 2.0;
front_face_t = 2.3;
clearance = 0.45;

xiao_w = 21.0;
xiao_h = 17.8;
xiao_t = 3.2;
xiao_sense_stack_t = 15.0;

round_display_pcb_d = 39.0;
round_display_visible_d = 34.5;
round_display_recess_d = 41.0;

battery_w = 33.0;
battery_h = 43.0;
battery_t = 10.5;

lens_hole_d = 7.4;
lens_bezel_outer_d = 12.2;
lens_bezel_inner_d = 7.8;

screen_z = -4.0;
lens_z = screen_z + round_display_visible_d/2 + 9.2;

display_screw_clearance_r = 1.18;  
display_screw_head_r = 2.55;       
display_screw_head_depth = 1.35;
display_screw_boss_r = 3.35;      
display_screw_boss_depth = 3.0;


corner_extension_receiver_r = 4.65;  
corner_extension_receiver_depth = 6.0;
corner_extension_receiver_y = -back_depth/2 + corner_extension_receiver_depth/2 - 0.05;


display_hug_outer_r = display_screw_boss_r;       
display_hug_inner_r = display_screw_clearance_r;  
display_hug_depth = 5.0;
display_hug_y = back_depth/2 - wall - display_hug_depth/2 + 0.10;


xiao_back_side_hugs_enabled = true;
xiao_back_hug_depth = 5.0;
xiao_back_hug_t = 1.25;
xiao_back_hug_h = 18.0;
xiao_back_hug_extra_gap = 1.1;
xiao_back_hug_y = back_depth/2 - wall - xiao_back_hug_depth/2 + 0.10;
xiao_back_hug_z = xiao_mount_z;



display_screw_positions = [
    [  0.000, screen_z + 19.431],
    [-11.811, screen_z - 15.621],
    [ 11.811, screen_z - 15.621]
];


round_display_locator_clearance = 0.55;
round_display_locator_inner_r = round_display_pcb_d/2 + round_display_locator_clearance;
round_display_locator_wall = 1.45;
round_display_locator_outer_r = round_display_locator_inner_r + round_display_locator_wall;
round_display_locator_depth = 3.2;
round_display_locator_y = -front_depth/2 + front_face_t + round_display_locator_depth/2 - 0.05;


xiao_mount_clearance = 0.85;
xiao_mount_w = xiao_h + 2*xiao_mount_clearance;
xiao_mount_h = xiao_w + 2*xiao_mount_clearance;


xiao_display_gap = 1.35;
xiao_mount_bottom_z = screen_z + round_display_locator_outer_r + xiao_display_gap;
xiao_mount_z = xiao_mount_bottom_z + xiao_mount_h/2;


xiao_rail_t = 1.20;
xiao_rail_depth = 7.2;
xiao_rail_y = -front_depth/2 + front_face_t + xiao_rail_depth/2 + 0.25;


xiao_bottom_stop_t = 1.25;
xiao_support_h = 10.5;
xiao_support_center_z = xiao_mount_bottom_z + xiao_support_h/2;


screw_margin = 7.2;
screw_x = body_w/2 - screw_margin;

screw_positions = [
    [-screw_x, body_bottom_z + screw_margin],
    [ screw_x, body_bottom_z + screw_margin],
    [-screw_x, body_top_z    - screw_margin],
    [ screw_x, body_top_z    - screw_margin]
];


key_tab_w = 14.0;
key_tab_h = 13.0;
key_tab_d = 7.2;
key_hole_d = 5.0;
key_tab_x = body_w/2 - key_tab_w/2 - 3.4;


switch_slot_z = 13;

switch_slot_h = 13.8;
switch_slot_w = 6.6;


accent_panel_inset = 2.6;
accent_panel_w = body_w - 2*accent_panel_inset;
accent_panel_bottom_z = body_bottom_z + accent_panel_inset;
accent_panel_base_h = 23.0;
accent_panel_cheek_r = 13.4;
accent_panel_cheek_x = accent_panel_w/2 - 9.2;
accent_panel_cheek_z = accent_panel_bottom_z + 18.0;
accent_panel_top_z = accent_panel_cheek_z + accent_panel_cheek_r;
accent_panel_h = accent_panel_top_z - accent_panel_bottom_z;
accent_panel_z = (accent_panel_top_z + accent_panel_bottom_z)/2;
accent_panel_corner_r = max(corner_r - accent_panel_inset, 1);
accent_panel_screen_cutout_r = round_display_visible_d/2 + 3.2;
accent_panel_t = 0.95;


relief_t = 0.75;
tiny_relief_t = 0.55;

front_decor_y = -front_depth/2 - relief_t/2 + 0.10;
accent_decor_y = -accent_panel_t/2 - tiny_relief_t/2 + 0.04;

cute_label_text = "PocketCam";
cute_sub_text = "selfie cam";


module rounded_rect_2d(w, h, r) {
    hull() {
        translate([ w/2-r,  h/2-r]) circle(r=r);
        translate([-w/2+r,  h/2-r]) circle(r=r);
        translate([ w/2-r, -h/2+r]) circle(r=r);
        translate([-w/2+r, -h/2+r]) circle(r=r);
    }
}


module rounded_prism(w, h, d, r) {
    rotate([90,0,0])
        linear_extrude(height=d, center=true, convexity=10)
            rounded_rect_2d(w, h, r);
}

module cyl_y(h, r) {
    rotate([90,0,0]) cylinder(h=h, r=r, center=true);
}

module cyl_x(h, r) {
    rotate([0,90,0]) cylinder(h=h, r=r, center=true);
}

module accent_panel_body_clip_2d() {
    translate([0, body_z_shift])
        rounded_rect_2d(
            accent_panel_w,
            body_h - 2*accent_panel_inset,
            accent_panel_corner_r
        );
}

module accent_panel_soft_blob_2d() {
    union() {

        translate([0, accent_panel_bottom_z + accent_panel_base_h/2])
            rounded_rect_2d(
                accent_panel_w,
                accent_panel_base_h,
                accent_panel_corner_r
            );


        translate([-accent_panel_cheek_x, accent_panel_cheek_z - 1.5])
            scale([0.92, 0.78])
                circle(r=accent_panel_cheek_r);


        translate([ accent_panel_cheek_x, accent_panel_cheek_z - 1.5])
            scale([0.92, 0.78])
                circle(r=accent_panel_cheek_r);


        translate([0, accent_panel_bottom_z + 9.0])
            rounded_rect_2d(accent_panel_w - 13.0, 16.0, 6.0);
    }
}


accent_tip_trim_r = 1.35;
accent_tip_trim_x = 16.9;
accent_tip_trim_z = screen_z + 6.8;

accent_end_soft_cut_r = 2;
accent_end_soft_cut_x = 16.7;
accent_end_soft_cut_z = screen_z + 6.5;

module accent_panel_outline_2d() {
    difference() {
        intersection() {
            accent_panel_body_clip_2d();
            accent_panel_soft_blob_2d();
        }


        translate([0, screen_z])
            circle(r=accent_panel_screen_cutout_r);
    }
}

module accent_panel_prism(t) {
    rotate([90,0,0])
        linear_extrude(height=t, center=true, convexity=10)
            accent_panel_outline_2d();
}


module front_extrude(t) {
    rotate([90,0,0])
        linear_extrude(height=t, center=true, convexity=10)
            children();
}

module heart_2d(s=1) {
    scale([s,s])
        union() {
            translate([-2.2, 1.2]) circle(r=2.25);
            translate([ 2.2, 1.2]) circle(r=2.25);
            polygon(points=[
                [-4.5, 0.8],
                [ 4.5, 0.8],
                [ 0.0,-5.2]
            ]);
        }
}

module sparkle_2d(s=1) {
    scale([s,s])
        union() {
            polygon(points=[
                [0, 5.2],
                [0.8, 0.8],
                [5.2, 0],
                [0.8,-0.8],
                [0,-5.2],
                [-0.8,-0.8],
                [-5.2,0],
                [-0.8,0.8]
            ]);
        }
}

module tiny_star_2d(s=1) {
    scale([s,s])
        polygon(points=[
            [0,5.0], [1.3,1.5], [4.8,1.5], [2.0,-0.5],
            [3.0,-4.2], [0,-2.0], [-3.0,-4.2], [-2.0,-0.5],
            [-4.8,1.5], [-1.3,1.5]
        ]);
}

module paw_2d(s=1) {
    scale([s,s])
        union() {
            translate([0,-1.0]) circle(r=2.1);
            translate([-2.4,1.7]) circle(r=1.05);
            translate([0,2.4]) circle(r=1.05);
            translate([2.4,1.7]) circle(r=1.05);
        }
}

module raised_heart(x, z, s=1.0, t=relief_t) {
    translate([x, front_decor_y, z])
        front_extrude(t)
            heart_2d(s);
}

module raised_sparkle(x, z, s=1.0, t=tiny_relief_t) {
    translate([x, front_decor_y, z])
        front_extrude(t)
            sparkle_2d(s);
}

module raised_star(x, z, s=1.0, t=tiny_relief_t) {
    translate([x, front_decor_y, z])
        front_extrude(t)
            tiny_star_2d(s);
}

module raised_paw(x, z, s=1.0, t=tiny_relief_t) {
    translate([x, front_decor_y, z])
        front_extrude(t)
            paw_2d(s);
}


module front_toy_camera_relief() {

    raised_heart(-21.5, body_top_z - 14.5, 0.72);
    raised_sparkle( 21.8, body_top_z - 13.5, 0.58);



    raised_sparkle(-16.5, lens_z + 4.2, 0.38, 0.45);
    raised_sparkle( 16.5, lens_z - 6.5, 0.34, 0.45);

}

module accent_panel_relief() {
    translate([-20.5, accent_decor_y, accent_panel_bottom_z + 12.0])
        front_extrude(tiny_relief_t)
            heart_2d(0.40);

    translate([20.8, accent_decor_y, accent_panel_bottom_z + 15.0])
        front_extrude(tiny_relief_t)
            sparkle_2d(0.34);

    translate([-18.4, accent_decor_y, accent_panel_bottom_z + 4.8])
        front_extrude(tiny_relief_t)
            paw_2d(0.36);

    translate([17.8, accent_decor_y, accent_panel_bottom_z + 5.8])
        front_extrude(tiny_relief_t)
            tiny_star_2d(0.26);

    translate([0, accent_decor_y, accent_panel_bottom_z + 3.6])
        front_extrude(tiny_relief_t)
            sparkle_2d(0.22);
}

module side_slot_x(x, y, z, slot_h, slot_w, depth) {
    translate([x, y, z])
        hull() {
            translate([0,0, slot_h/2 - slot_w/2]) cyl_x(depth, slot_w/2);
            translate([0,0,-slot_h/2 + slot_w/2]) cyl_x(depth, slot_w/2);
        }
}


module screw_boss(x, z, len=23.2, boss_r=3.8, insert_hole_r=1.55) {
    boss_y = -front_depth/2 + front_face_t + len/2 - 0.15;

    difference() {
        translate([x, boss_y, z])
            cyl_y(len, boss_r);

        translate([x, boss_y, z])
            cyl_y(len + 1.0, insert_hole_r);
    }
}

module round_display_front_locator() {
    translate([0, round_display_locator_y, screen_z])
        difference() {
            cyl_y(round_display_locator_depth, round_display_locator_outer_r);
            cyl_y(round_display_locator_depth + 0.6, round_display_locator_inner_r);
        }
}

module xiao_side_rails() {

    // Lower side rails
    for (sx = [-1, 1]) {
        translate([
            sx * (xiao_mount_w/2 + xiao_rail_t/2),
            xiao_rail_y,
            xiao_support_center_z
        ])
            cube([xiao_rail_t, xiao_rail_depth, xiao_support_h], center=true);
    }


    translate([
        0,
        xiao_rail_y,
        xiao_mount_bottom_z + xiao_bottom_stop_t/2
    ])
        cube([
            xiao_mount_w + 2*xiao_rail_t,
            xiao_rail_depth,
            xiao_bottom_stop_t
        ], center=true);


    translate([
        0,
        xiao_rail_y,
        xiao_mount_bottom_z + 2.2
    ])
        cube([
            xiao_mount_w - 2.0,
            xiao_rail_depth,
            1.0
        ], center=true);
}


module display_screw_boss(x, z) {
    boss_y = back_depth/2 - wall - display_screw_boss_depth/2 + 0.10;

    translate([x, boss_y, z])
        cyl_y(display_screw_boss_depth, display_screw_boss_r);
}


module corner_extension_receiver(x, z) {
    translate([x, corner_extension_receiver_y, z])
        cyl_y(corner_extension_receiver_depth + 0.20, corner_extension_receiver_r);
}


module display_hug_ring(x, z) {
    translate([x, display_hug_y, z])
        difference() {
            cyl_y(display_hug_depth, display_hug_outer_r);
            cyl_y(display_hug_depth + 0.50, display_hug_inner_r);
        }
}


module xiao_back_side_hugs() {
    if (xiao_back_side_hugs_enabled) {
        hug_x = xiao_mount_w/2 + xiao_back_hug_extra_gap;

        for (sx = [-1, 1]) {
            translate([
                sx * hug_x,
                xiao_back_hug_y,
                xiao_back_hug_z
            ])
                cube([
                    xiao_back_hug_t,
                    xiao_back_hug_depth,
                    xiao_back_hug_h
                ], center=true);
        }
    }
}


usb_screw_spacing = 17.0;
usb_screw_hole_d = 2.25;

usb_c_cutout_w = 9.4;
usb_c_cutout_h = 4.4;

module usb_c_panel_mount_cutout(x, y, z) {
    translate([x, y, z])
        cube([wall + 5.0, usb_c_cutout_h, usb_c_cutout_w], center=true);

    translate([x, y, z + usb_screw_spacing/2])
        cyl_x(wall + 6.0, usb_screw_hole_d/2);

    translate([x, y, z - usb_screw_spacing/2])
        cyl_x(wall + 6.0, usb_screw_hole_d/2);
}


module back_alignment_lip() {
    lip_depth_actual = lid_lip_depth + lip_overlap;
    lip_y = -back_depth/2 + lip_depth_actual/2;

    tab_t = 3.4;
    top_tab_w = 30.0;
    side_tab_h = 28.0;


    translate([
        0,
        lip_y,
        body_top_z - wall - lid_lip_clearance - tab_t/2
    ])
        cube([top_tab_w, lip_depth_actual, tab_t], center=true);


    translate([
        0,
        lip_y,
        body_bottom_z + wall + lid_lip_clearance + tab_t/2
    ])
        cube([top_tab_w, lip_depth_actual, tab_t], center=true);

}

module back_shoulder_rim() {
    rim_depth = 2.4;
    rim_wall = 5.0;

    rim_y = -back_depth/2 + lid_lip_depth + rim_depth/2 - 0.9;

    translate([0, rim_y, body_z_shift])
        difference() {
            rounded_prism(
                body_w - 0.2,
                body_h - 0.2,
                rim_depth,
                max(corner_r - 0.1, 1)
            );

            rounded_prism(
                body_w - 2*rim_wall,
                body_h - 2*rim_wall,
                rim_depth + 0.6,
                max(corner_r - rim_wall, 1)
            );
        }
}

switch_body_h = 13.5;
switch_body_w = 6.6;


switch_body_depth = 7.4;

switch_holder_wall = 1.25;
switch_wall_overlap = 1.1;

switch_holder_center_x = body_w/2 - wall - switch_body_depth/2 + switch_wall_overlap;

module switch_inner_holder(x, y, z) {

    translate([switch_holder_center_x, y - switch_body_w/2 - switch_holder_wall/2, z])
        cube([switch_body_depth, switch_holder_wall, switch_body_h + 2.0], center=true);

    translate([switch_holder_center_x, y + switch_body_w/2 + switch_holder_wall/2, z])
        cube([switch_body_depth, switch_holder_wall, switch_body_h + 2.0], center=true);

    translate([switch_holder_center_x, y, z + switch_body_h/2 + switch_holder_wall/2])
        cube([switch_body_depth, switch_body_w + 2*switch_holder_wall, switch_holder_wall], center=true);

    translate([switch_holder_center_x, y, z - switch_body_h/2 - switch_holder_wall/2])
        cube([switch_body_depth, switch_body_w + 2*switch_holder_wall, switch_holder_wall], center=true);


    anchor_x = body_w/2 - wall/2;
    anchor_w = wall + 1.4;

    translate([anchor_x, y - switch_body_w/2 - switch_holder_wall/2, z])
        cube([anchor_w, switch_holder_wall, switch_body_h + 1.2], center=true);

    translate([anchor_x, y + switch_body_w/2 + switch_holder_wall/2, z])
        cube([anchor_w, switch_holder_wall, switch_body_h + 1.2], center=true);
}

module front_shell() {
    difference() {
        union() {
            difference() {
                translate([0, 0, body_z_shift])
                    rounded_prism(body_w, body_h, front_depth, corner_r);

                translate([
                    0,
                    -front_depth/2 + front_face_t + (front_depth-front_face_t+1.5)/2,
                    body_z_shift
                ])
                    rounded_prism(
                        body_w - 2*wall,
                        body_h - 2*wall,
                        front_depth-front_face_t+1.5,
                        max(corner_r-wall, 1)
                    );
            }


            front_toy_camera_relief();

            for (p = screw_positions)
                screw_boss(p[0], p[1]);


            translate([0, -front_depth/2 + front_face_t + 0.4, screen_z])
                difference() {
                    cyl_y(1.0, round_display_visible_d/2 + 2.2);
                    cyl_y(1.3, round_display_visible_d/2 + 0.25);
                }

            translate([key_tab_x, 0, body_top_z + key_tab_h/2 - 1.1])
                rounded_prism(key_tab_w, key_tab_h, key_tab_d, 3.2);

            switch_inner_holder(body_w/2 - wall - 1.0, 0, switch_slot_z);
        }


        translate([0, -front_depth/2, screen_z])
            cyl_y(front_depth+4, round_display_visible_d/2);


        translate([0, -front_depth/2 + front_face_t + 3.0, screen_z])
            cyl_y(front_depth, round_display_recess_d/2);


        translate([0, -front_depth/2, lens_z])
            cyl_y(front_depth+4, lens_hole_d/2);


        translate([key_tab_x, 0, body_top_z + key_tab_h/2 + 1.0])
            cyl_y(key_tab_d+3, key_hole_d/2);

        side_slot_x(body_w/2 + 0.1, 0, switch_slot_z, switch_slot_h, switch_slot_w, wall+4);
    }
}


module front_fit_test() {
    difference() {
        translate([0,0,body_z_shift])
            rounded_prism(body_w, body_h, 2.0, corner_r);

        translate([0,0,screen_z])
            cyl_y(3.0, round_display_visible_d/2);

        translate([0,0,lens_z])
            cyl_y(3.0, lens_hole_d/2);
        side_slot_x(body_w/2 + 0.1, 0, switch_slot_z, switch_slot_h, switch_slot_w, wall+4);
    }
}


module back_cover() {
    outer_shell_center_y = lid_lip_depth/2;
    outer_back_y = back_depth/2;

    hollow_depth = back_outer_depth - wall + 1.4;
    hollow_center_y = outer_back_y - wall - hollow_depth/2;

    difference() {
        // Main visible outside back shell only
        translate([0, outer_shell_center_y, body_z_shift])
            rounded_prism(body_w, body_h, back_outer_depth, corner_r);

        // Hollow inside, open toward front
        translate([0, hollow_center_y, body_z_shift])
            rounded_prism(
                body_w - 2*wall,
                body_h - 2*wall,
                hollow_depth,
                max(corner_r-wall, 1)
            );

        for (p = screw_positions)
            translate([p[0], 0, p[1]])
                cyl_y(back_depth + 3, 1.35);
    }
}


module accent_panel() {
    difference() {
        union() {
            accent_panel_prism(accent_panel_t);

            accent_panel_relief();
        }

        translate([0,0,screen_z])
            cyl_y(accent_panel_t + tiny_relief_t + 1.8, accent_panel_screen_cutout_r);
    }
}


module bezel_rings() {

    translate([0,0,0])
        difference() {
            cyl_y(1.25, round_display_visible_d/2 + 3.2);
            cyl_y(1.7, round_display_visible_d/2 + 0.35);
        }



    translate([30,0,0])
        difference() {
            cyl_y(1.25, lens_bezel_outer_d/2 + 0.5);
            cyl_y(1.7, lens_bezel_inner_d/2);
        }

}


module battery_fit_test() {
    pocket_wall = 1.6;

    difference() {
        rounded_prism(
            battery_w + 2*pocket_wall,
            battery_h + 2*pocket_wall,
            battery_t + pocket_wall,
            3.0
        );

        translate([0, -0.4, 0])
            rounded_prism(
                battery_w,
                battery_h,
                battery_t + 2.0,
                2.5
            );
    }
}


module metal_keyring_preview() {
    color("silver")
        translate([key_tab_x,0,body_top_z + key_tab_h + 8])
            rotate([90,0,0])
                rotate_extrude(angle=360)
                    translate([9,0,0])
                        circle(r=1.1);
}


module display_screw_template() {
    template_t = 1.0;

    difference() {
        union() {
            translate([0, 0, screen_z])
                cyl_y(template_t, round_display_pcb_d/2);


            for (p = display_screw_positions)
                translate([p[0], 0, p[1]])
                    cyl_y(template_t, display_screw_head_r + 0.6);
        }

        for (p = display_screw_positions)
            translate([p[0], 0, p[1]])
                cyl_y(template_t + 1.0, display_screw_clearance_r);


        translate([0, 0, screen_z])
            cyl_y(template_t + 1.0, 0.55);
    }
}


module assembly_preview() {

    color("#f4eadf")
        front_shell();

    color("#f2a9bd")
        translate([0, front_depth/2 + back_depth/2 - lid_lip_depth, 0])
            back_cover();

    color("#f2a9bd")
        translate([0, -front_depth/2 - 0.65, 0])
            accent_panel();

    color("black")
        translate([0, -front_depth/2 - 1.25, screen_z])
            difference() {
                cyl_y(1.2, round_display_visible_d/2 + 3.0);
                cyl_y(1.6, round_display_visible_d/2 + 0.35);
            }

    color("black")
        translate([0, -front_depth/2 - 1.25, lens_z])
            difference() {
                cyl_y(1.2, lens_bezel_outer_d/2);
                cyl_y(1.6, lens_bezel_inner_d/2);
            }

    metal_keyring_preview();
}

if (part == "front_shell") {
    front_shell();
} else if (part == "back_cover") {
    back_cover();
} else if (part == "accent_panel") {
    accent_panel();
} else if (part == "bezel_rings") {
    bezel_rings();
} else if (part == "front_fit_test") {
    front_fit_test();
} else if (part == "battery_fit_test") {
    battery_fit_test();
} else if (part == "display_screw_template") {
    display_screw_template();
} else {
    assembly_preview();
}
