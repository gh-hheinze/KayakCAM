#######################################################################
#
# KayakCAM
#    
# Copyright (C) 2021 Helmut Heinze (helmut.heinze@icloud.com)
#
# License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>
# This is free software: you are free to change and redistribute it.
# There is NO WARRANTY, to the extent permitted by law.
#
#######################################################################



=head1 NAME

KayakCAM::Design - Design module for KayakCAM.

=head1 SYNOPSIS

    use Momos::Kayak::Design;

=cut




package KayakCAM::Design;

use strict;
use warnings;
use vars qw( $VERSION );

use base 'Exporter';

our @EXPORT = qw(
    to_scad
    print_scad
);


use KayakCAM::Utils;



=head1 3D Mesh

Functions to represent the kayak as a 3D mesh for viewing in Meshlab or similar VR viewers.

=over 4

=cut

=item B<make_mesh_from_yz_strip(X1,BEZ1,X2,BEZ2,OPTIONS)>

Returns a list of 3D facets from two Bezier Chains BEZ1 and BEZ at
point X1 and point X2 with each approximately containing N points.

This strip may represent the slice along the circumference of of the
kayak hull.

The number of points on the two Bezier curves may differ, eg:
   
    *
    |     *
    *     |
    |     *
    *     |
    |     *
    *
   
The algorithm will take care at this.

OPTIONS:  
  {npoints   => N}       default is 10
  {invert_z  => 0|1}     default is FALSE
  {shift_y   => mm}      default is 1000 mm
  {mirror_y  => 0|1}     default is TRUE     


=cut 

sub make_mesh_from_yz_strip($$$$$) {
    my ($X1,$bez1,$X2,$bez2,$options) = @_;

    $options = {} if(!$options);
    $options->{npoints} = 10   if(!$options->{npoints});
    $options->{shift_y} = 1000 if(!$options->{shift_y});
    $options->{mirror_y} = 1  if(!$options->{mirror_y});
    $options->{invert_z} = 1  if(!$options->{invert_z});
    
    my @pts1 = map {[$_->[0], $_->[1] * ($options->{invert_z}? -1 : 1)]} @{getThetaCurve($bez1,$options->{npoints})};
    my @pts2 = map {[$_->[0], $_->[1] * ($options->{invert_z}? -1 : 1)]} @{getThetaCurve($bez2,$options->{npoints})};

    my $npts1 = scalar(@pts1);
    my $npts2 = scalar(@pts2);

    my $npts_diff = ($npts1 - $npts2);
    my $npts_diff_abs = abs($npts_diff);
    my $npts1_extra_beg = 0;
    my $npts1_extra_end = 0;
    my $npts2_extra_beg = 0;
    my $npts2_extra_end = 0;
    my $npts_common = $npts1;
    if($npts_diff > 0) {
	## npts1 > npts2
	$npts1_extra_beg = int($npts_diff_abs/2);
	$npts1_extra_end = $npts_diff_abs - $npts1_extra_beg;
	$npts_common = $npts1 - $npts_diff_abs;
    }
    elsif($npts_diff < 0) {
	## npts1 < npts2
	$npts2_extra_beg = int($npts_diff_abs/2);
	$npts2_extra_end = $npts_diff_abs - $npts2_extra_beg;
	$npts_common = $npts2 - $npts_diff_abs;
    }

    my @facets = ();
    
    ##
    ## start: connect extra points
    ##

    ##   X1 X2
    ##   a
    ##      c
    ##   b
    ##
    if($npts1_extra_beg) {
	for my $i (0 .. $npts1_extra_beg-1)  {
	    ## rh-order for correct inside/outside orientation!
	    push(@facets, [
		     [$X1,  $pts1[$i][0],   $pts1[$i][1]],   # a
		     [$X2,  $pts2[0][0],    $pts2[0][1]],    # c
		     [$X1,  $pts1[$i+1][0], $pts1[$i+1][1]], # b
		 ])
	}
    }

    ##   X1 X2
    ##      b
    ##   a   
    ##      c
    ##

    if($npts2_extra_beg) {
	for my $i (0 .. $npts2_extra_beg-1)  {
	    push(@facets,
		 [
		  [$X2,  $pts2[$i][0],   $pts2[$i][1]],   # b
		  [$X2,  $pts2[$i+1][0], $pts2[$i+1][1]], # c
		  [$X1,  $pts1[0][0],    $pts1[0][1]],    # a
		 ])
	}
    }


    
    ##
    ## middle
    ##
    ##  X1 X2
    ##  a - b
    ##  | / |
    ##  c - d
    ##
    for my $i (0 .. $npts_common-2)  {
	push(@facets,
	     ## rh-order for correct inside/outside orientation!
	     [
	      [$X1,  $pts1[$i+$npts1_extra_beg][0],   $pts1[$i+$npts1_extra_beg][1]],   # a
	      [$X2,  $pts2[$i+$npts2_extra_beg][0],   $pts2[$i+$npts2_extra_beg][1]],   # b
	      [$X1,  $pts1[$i+$npts1_extra_beg+1][0], $pts1[$i+$npts1_extra_beg+1][1]], # c
	     ],
	     [
	      [$X2,  $pts2[$i+$npts2_extra_beg][0],   $pts2[$i+$npts2_extra_beg][1]],   # b
	      [$X2,  $pts2[$i+$npts2_extra_beg+1][0], $pts2[$i+$npts2_extra_beg+1][1]], # d
	      [$X1,  $pts1[$i+$npts1_extra_beg+1][0], $pts1[$i+$npts1_extra_beg+1][1]], # c
	     ]
	    )
    }

    ##
    ## end: connect extra points
    ##

    ##   X1 X2
    ##   a
    ##      c  <- converging on last point of X2
    ##   b
    ##

    if($npts1_extra_end) {
	for my $i ($npts_common+$npts1_extra_beg-1 .. $npts1-2)  {
	    push(@facets, [
		     ## rh-order for correct inside/outside orientation!
		     [$X1,  $pts1[$i][0],       $pts1[$i][1]],       # a
		     [$X2,  $pts2[$npts2-1][0], $pts2[$npts2-1][1]], # c
		     [$X1,  $pts1[$i+1][0],     $pts1[$i+1][1]],     # b
		 ])
	}
    }

    ##   X1 X2
    ##      b
    ##   a     <- last point expanding to remaining points
    ##      c
    ##

    if($npts2_extra_end) {
	for my $i ($npts_common+$npts2_extra_beg-1 .. $npts2-2)  {
	    push(@facets,
		 ## rh-order for correct inside/outside orientation!
		 [
		  [$X1,  $pts1[$npts1-1][0], $pts1[$npts1-1][1]], # a
		  [$X2,  $pts2[$i][0],       $pts2[$i][1]],       # b
		  [$X2,  $pts2[$i+1][0],     $pts2[$i+1][1]]      # c
		 ])
	}
    }



    ##
    ## transform 
    ##

    my $shift_y = $options->{shift_y};
    
    my @out = ();

    for my $f (@facets)  {
	push(@out,
	     [
	      [$f->[0][0], $f->[0][1] *  1 + $shift_y, $f->[0][2]],
	      [$f->[1][0], $f->[1][1] *  1 + $shift_y, $f->[1][2]],
	      [$f->[2][0], $f->[2][1] *  1 + $shift_y, $f->[2][2]],	       
	     ]
	    );
	push(@out,
	     [
	      ## invert order of mirrored facet for correct inside/outside orientation!
	      [$f->[2][0], $f->[2][1] * -1 + $shift_y, $f->[2][2]],	       
	      [$f->[1][0], $f->[1][1] * -1 + $shift_y, $f->[1][2]],
	      [$f->[0][0], $f->[0][1] * -1 + $shift_y, $f->[0][2]],
	     ]
	    ) if $options->{mirror_y};
    }

    
    return \@out;
}


=item B<kayak_to_mesh(KAYAK,OPTIONS)>

Generates a complete 3D mesh of the kayak.

=cut

sub kayak_to_mesh($$) {
    my $yak     = shift();
    my $options = shift() || {stepping=>'smart'};

    $options->{shift_y} = 1000 if(!$options->{shift_y});
    
    my $STEP_X = 50;
    $STEP_X  = $options->{stepping} if($options->{stepping} =~ /^\d+$/);
    

    my $PTS_CS  = int($yak->{LOA} / $STEP_X);
    
    my $LOA = $yak->{LOA};

    my @out = ();
    my $x1 = 0;
    my $x2;
    while ($x1 < $LOA) {
	my $step_x = $STEP_X;
	my $pts_cs = $PTS_CS;
	
        if(
	    $x1 < 200         ||    # fine stepping at bow
	    $x1 > $LOA - 200  ||    # fine stepping at stern
	    ($x1 > $yak->{COCKPIT_X_FORE} - 50 && $x1 < $yak->{COCKPIT_X_FORE} + 100) || # fine stepping at start of coaming
	    ($x1 < $yak->{COCKPIT_X_AFT}  + 50 && $x1 > $yak->{COCKPIT_X_AFT}  - 100)    # fine stepping at end of coaming
	    ) {
	    $step_x = 10;
	    $pts_cs = 250;
	}
	
	$x2 = ($x1 < $LOA - $STEP_X)?  $x1 + $step_x : $LOA;
	
	my $bez1 = KayakCAM::KFoundry::make_cs_at_x($yak,$x1,$options);
	my $bez2 = KayakCAM::KFoundry::make_cs_at_x($yak,$x2,$options);
	my $mesh =  make_mesh_from_yz_strip($x1,$bez1,$x2,$bez2, {npoints=>$pts_cs, invert_z=>1} );
	push (@out, @$mesh);
	
	$x1 = $x2;
    }

    if($options->{transom}) {
	##
	## transom
	##
	##  p1
	##     pstern = [LOA,0,STERN]
	##  p2
	##
	##  p...
	##
	##  ..
	my $bez2 = KayakCAM::KFoundry::make_cs_at_x($yak,$LOA,$options);
	my $pstern = [$LOA,$options->{shift_y},$yak->{STERN_HEIGHT}];
	my @pts = map {[$LOA, $_->[0]+$options->{shift_y}, $_->[1] * ($options->{invert}? 1 : -1)]} @{getThetaCurve($bez2,5)};	
	
	my $p1 = shift(@pts);
	while(my $p2 = shift(@pts)) {
	    push(@out,[$p1,$pstern,$p2]);
	    $p1 = $p2;
	}
    }
    
    
    return \@out;
}


=item B<kayak_to_stl(KAYAK,PATH,OPTIONS)>

Writes a complete 3D mesh of the kayak to a file.

=cut

sub kayak_to_stl($$$) {
    my ($yak,$path,$options) = @_;

    my $fh;
    
    $path               || die "kayak_to_stl: no output path provided";
    $path =~ m/\.stl$/  || die "kayak_to_stl: no valid output path with .stl suffix provided";
    open($fh,'>',$path) || die "kayak_to_stl: cannot open '$path' for writing: $!";


    print $fh "solid kayak\n";

    
    map {
	my $tessel = $_;
	print $fh join("\n",
		       "facet normal 0 0 0 ",
		       " outer loop",
		       sprintf("  vertext %0.2f %0.2f %0.2f", $tessel->[0][0],$tessel->[0][1],$tessel->[0][2]),
		       sprintf("  vertext %0.2f %0.2f %0.2f", $tessel->[1][0],$tessel->[1][1],$tessel->[1][2]),
		       sprintf("  vertext %0.2f %0.2f %0.2f", $tessel->[2][0],$tessel->[2][1],$tessel->[2][2]),
		       " endloop",
		       "endfacet",
		       "")
    } @{kayak_to_mesh($yak,$options)};

    print $fh "endsolid kayak\n";
    LOG_INFO "Written STL to '$path'"
}



=back

=head1 OpenSCAD

Output of kayak in OpenSCAD.

=item B<kayak_to_scad(KAUAK,PATH,OPTIONS)>

Returns a complete model as OpenSCAD output.

Options:

  stepping       => INT       Resolution in the X axis in mm - default 50mm
  wall_thickness => INT       Wall thickness of ares with standard core  - default 18mm
  solid_bow      => INT       Bow area to remain solid foam - default 200mm
  solid_stern    => INT       Stern area to remain solid foam - default 200mm
  bulkhead_rear  => INT       Position of rear bulkhead - default 3900mm 

=cut

sub kayak_to_scad($$$) {
    my ($yak, $path, $options) = @_; 

    $options = {stepping=>50, wall_thickness=>18, solid_bow=>200, solid_stern=>200} if(!$options);
    $options->{stepping}        = 50   if(! $options->{stepping});
    $options->{wall_thickness}  = 18   if(! $options->{wall_thickness});
    $options->{solid_bow}       = 200  if(! $options->{solid_bow});
    $options->{solid_stern}     = 200  if(! $options->{solid_stern});
    $options->{bulkhead_rear}   = $yak->{COCKPIT_X_AFT} + 500 if(! $options->{bulkhead_rear});


    my $COCKPIT_LENGTH = 350 + 1100; # from coaming aft
    
    
    my $fh;
    
    $path                || die "kayak_to_stl: no output path provided";
    $path =~ m/\.scad$/  || die "kayak_to_stl: no valid output path with .scad suffix provided";
    open($fh,'>',$path)  || die "kayak_to_stl: cannot open '$path' for writing: $!";

    
    my $bezier_keel = $yak->{BEZIER_XZ_AXIS}{KEEL};
    my $dwl = $yak->{DWL};

    ##
    ## calculate translation & rotation of coaming
    ##
    my $cockpit_x1 = $yak->{COCKPIT_X_FORE};
    my $cockpit_z1 = $yak->{COCKPIT_Z_FORE} ;
    my $alpha = $yak->{COAMING_ANGLE} * -1;
    
    my $coaming_curve_l = mapCurve3D_xy0(getThetaCurve($yak->{BEZIER_COAMING},50));
    my $coaming_curve_r = mirrorCurve3D_y($coaming_curve_l);

    my $sheer_r = spliceCurves3D_xy_xz(
	getIntervalCurve_10($yak->{BEZIER_XY_AXIS}{SHEER}),
	getIntervalCurve_10($yak->{BEZIER_XZ_AXIS}{SHEER}),
	);
    ## handle transom, assure that the right sheer ends at y==0 
    my $p = $sheer_r->[@$sheer_r -1];
    push(@$sheer_r, [$p->[0], 0, $p->[2]] ) if($p->[1] > 0);
    ## mirror sheer
    my $sheer_l = mirrorCurve3D_y($sheer_r);

    my $thickness = 8; # thickness of virtual helper lines

    my $stepping = $options->{stepping};
    $stepping = 50 if($stepping eq 'smart');

    ## ========================================================================
    ##
    ## helper function get_cs_pts
    ##

    my $get_cs_points = sub($$) {
	my $x      = shift;
	my $shrink = shift;
	
	my $npts = 25;

	## combine original points + mirror, strip start and end points
	my @pts = @{getThetaCurve(KayakCAM::KFoundry::make_cs_at_x($yak, $x, {shrink=>$shrink}),$npts)};
#	shift(@pts); pop(@pts);  # strip the first and the last point;
	
	return [@pts, map {[$_->[0] * -1,$_->[1]]} reverse(@pts)]; # combine original + reversed mirrored points
    };

    ##
    ## ========================================================================
    
    
    ## ========================================================================
    ##
    ## helper function make_cs_slice
    ##

    my $make_cs_slice = sub($){
	my $x = shift;

	my $npts = 25;
	
	my $shrink = $options->{wall_thickness};
	my $extrude_height   = $options->{stepping};

	## ------------------------------------------------------------------------
	## solid slice at bow or stern
	## ------------------------------------------------------------------------
	if (
	    $x <= $options->{solid_bow}                  ||
	    $x >= $yak->{LOA} - $options->{solid_stern}  
	    ) {
	    my $pts = &$get_cs_points($x,0);
 	    my $scad_pts = to_scad($pts);
	    my $scad_paths_outer = to_scad([(0 .. @$pts - 1)]);
	    return join(" ",
			"translate([$x - $stepping,0,0])",
			"rotate([90,0,90])",
			"color(\"orange\",1)",
			"linear_extrude(height=$extrude_height,convexity=10)",
			"polygon(points=$scad_pts, paths=[$scad_paths_outer], convexity=10)",
			";\n")

	}
	## ------------------------------------------------------------------------
	## bulkheads
	## ------------------------------------------------------------------------
	elsif (
	    $x == $yak->{COCKPIT_X_AFT}     - $COCKPIT_LENGTH - ($yak->{COCKPIT_X_AFT} % $stepping) ||
	    $x == $yak->{COCKPIT_X_AFT}     - ($yak->{COCKPIT_X_AFT}                   % $stepping) ||
	    $x == $options->{bulkhead_rear} - ($options->{bulkhead_rear}               % $stepping)
	    ) {

	    my $pts = &$get_cs_points($x,0);
	    my $scad_pts = to_scad($pts);
	    my $scad_paths_outer = to_scad([(0 .. @$pts - 1)]);
	    return join(" ",
			"translate([$x - $stepping,0,0])",
			"rotate([90,0,90])",
			"color(\"red\",0.6)",
			"linear_extrude(height=$extrude_height,convexity=10)",
			"polygon(points=$scad_pts, paths=[$scad_paths_outer], convexity=10)",
			";\n")
	}
	elsif (
	    ! (
		  ($x >= $yak->{COCKPIT_X_AFT} - $COCKPIT_LENGTH  && $x <= $yak->{COCKPIT_X_AFT}))
	    ) {
	    my $pts_outer = &$get_cs_points($x,0);
	    my $pts_inner = &$get_cs_points($x,$shrink);
	    my $scad_pts = to_scad([@$pts_outer,@$pts_inner]);
	    my $scad_paths_outer = to_scad([(0 .. @$pts_outer - 1)]);
	    my $scad_paths_inner = to_scad([(@$pts_outer .. @$pts_outer + @$pts_inner - 1)]);
	    return join(" ",
			"translate([$x - $stepping,0,0])",
			"rotate([90,0,90])",
			"color(\"yellow\",0.7)",
			"linear_extrude(height=$extrude_height,convexity=10)",
			"polygon(points=$scad_pts, paths=[$scad_paths_outer,$scad_paths_inner], convexity=20)",
			";\n")
	}
	else {
	    my $pts_outer = &$get_cs_points($x,0);
	    my $pts_inner = &$get_cs_points($x,5);
	    my $scad_pts = to_scad([@$pts_outer,@$pts_inner]);
	    my $scad_paths_outer = to_scad([(0 .. @$pts_outer - 1)]);
	    my $scad_paths_inner = to_scad([(@$pts_outer .. @$pts_outer + @$pts_inner - 1)]);
	    return join(" ",
			"translate([$x - $stepping,0,0])",
			"rotate([90,0,90])",
			"color(\"blue\",0.6)",
			"linear_extrude(height=45,convexity=10)",
			"polygon(points=$scad_pts, paths=[$scad_paths_outer,$scad_paths_inner], convexity=20)",
			";\n")
	}
    };

    ##
    ## ========================================================================
    
    print $fh join("\n",
		## header
		"use <dotSCAD/src/polyline3d.scad>",
		"\n\n",

		## start of main union
		"translate([0,0,$dwl]) mirror([0,0,1]) union() {",
		
		## coaming
		"color(\"Black\") translate([$cockpit_x1,0,$cockpit_z1]) rotate([0,$alpha,0]) union() {",
		"polyline3d(" . to_scad($coaming_curve_l) . ", $thickness);",
		"polyline3d(" . to_scad($coaming_curve_r) . ", $thickness);",
		"}",

		   ## sheer
		"color(\"lightBlue\") union() {",
		"  polyline3d(",to_scad( $sheer_r ), ", $thickness);",
		"  polyline3d(",to_scad( $sheer_l ), ", $thickness);",
		   "  }",
		   
		   
		## deck & keel
		"color(\"Red\") union() {",
		"  polyline3d(", to_scad( mapCurve3D_x0z(getThetaCurve($yak->{BEZIER_XZ_AXIS}{DECK_FORE}, int($yak->{LOA}/$stepping)))), ", $thickness);",
		"  polyline3d(", to_scad( mapCurve3D_x0z(getThetaCurve($yak->{BEZIER_XZ_AXIS}{DECK_AFT},int($yak->{LOA}/$stepping)))), ", $thickness);",
		"  polyline3d(", to_scad( mapCurve3D_x0z(getThetaCurve($yak->{BEZIER_XZ_AXIS}{KEEL},int($yak->{LOA}/$stepping)))), ", $thickness);",
		"  }",

		## cross sections at 10, 30, 50,70 90%
		(map {
		    my $pos = $_;
		    my $x = $yak->{LOA} * $pos / 100;
		    my $bez_cs = $yak->{BEZIER_YZ_AXIS}{"CS_$pos"};
		    my $cs_r = [ map { [$x,$_->[0],$_->[1]] } @{getThetaCurve($bez_cs, int($yak->{LOA}/$stepping))}];
		    my $cs_l = mirrorCurve3D_y($cs_r);

		    "color(\"lightGreen\") union() {\n"
			. "polyline3d(", to_scad($cs_r), ",$thickness);" 
			. "polyline3d(", to_scad($cs_l), ",$thickness);" 
			. "}"
		 } (10,30,50,70,90)),
		   
		## cs foam slices
		"union() {",
		   (map {
		       my $x = $_ * $stepping;
		       &$make_cs_slice($x)
		    } (1 .. int($yak->{LOA}/$stepping))),
		   ## cs transom
		   ($options->{transom}>0)?  &$make_cs_slice($yak->{LOA}) : '',
		   "}",

		## end of main union
		"};\n"
	);

    LOG_INFO "Written SCAD to '$path'"
}







=back



=head1 AUTHOR

Helmut Heinze 2021 (helmut.heinze@icloud.com) 

=cut

return 1;
