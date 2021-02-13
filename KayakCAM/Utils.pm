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

KayakCAM::Utils - Utility module for KayakCAM.

=head1 SYNOPSIS

    use Momos::Kayak::Utils;

    DEBUG
    LOG_INFO
    LOG_WARNING
    LOG_ERROR
    STRFTIME

    CubicBezierChain

    getThetaCurve
    getIntervalCurve
    getPointYatX

    mapCurve3D_xy0
    mapCurve3D_x0z
    mapCurve3D_0yz
    spliceCurves3D_xy_xz
    mirrorCurve3D_y

    to_scad
    print_scad

    make_mesh_from_yz_strip

=cut




package KayakCAM::Utils;

use strict;
use warnings;
use vars qw( $VERSION );

use Data::Dumper;
use POSIX;


use base 'Exporter';

our @EXPORT = qw(
    DEBUG
    LOG_INFO
    LOG_WARNING
    LOG_ERROR
    STRFTIME

    CubicBezierChain

    getThetaCurve
    getIntervalCurve_10
    getIntervalCurve
    getPointYatX

    mapCurve3D_xy0
    mapCurve3D_x0z
    mapCurve3D_0yz
    spliceCurves3D_xy_xz
    mirrorCurve3D_y

    to_scad
    print_scad

    make_mesh_from_yz_strip
);


my $_LOGLEVEL = 1;

sub set_loglevel($) {$_LOGLEVEL=shift}


sub DEBUG($) {
    print STDERR "\n===DEBUG========================================================================\n";
    print STDERR Dumper($_[0]);
    print STDERR "================================================================================\n";
    return $_[0]
}

sub LOG_DEBUG($) {
    return '' if($_LOGLEVEL < 3);
    DEBUG shift();
}

sub LOG_INFO  {
    return '' if($_LOGLEVEL < 1);
    print STDERR "INFO:  ", join("\n", map {"\t".$_}  @_), "\n"
}

sub LOG_WARNING($) {
    print STDERR "WARNING: ", $_[0], "\n"
}

sub LOG_ERROR($) {
    print STDERR "ERROR: ", $_[0], "\n"
}

sub STRFTIME($$) {
    my($format, $epoch) = @_;
    return POSIX::strftime($format, localtime($epoch))
}






sub _CubicN ($$$$$) {
    my ($a,$b,$c,$d, $T) = @_;
    
    my $t2 = $T * $T;
    my $t3 = $t2 * $T;
    return 
	$a + (-$a * 3 + $T * (3 * $a - $a * $T)) * $T
	+ (3 * $b + $T * (-6 * $b + $b * 3 * $T)) * $T
	+ ($c * 3 - $c * 3 * $T) * $t2
	+ $d * $t3
	
}


=head1 Bezier

=over 4

=cut


sub _getCubicBezierXYatT($$){
    my ($pts,$T) = @_;
    my ($startPt,$controlPt1,$controlPt2,$endPt) = @$pts;
    my $x = _CubicN($startPt->[0],$controlPt1->[0],$controlPt2->[0],$endPt->[0], $T);
    my $y = _CubicN($startPt->[1],$controlPt1->[1],$controlPt2->[1],$endPt->[1], $T);
    return [$x,$y];
}

sub _getCubicBezierXatT($$){
    my ($pts,$T) = @_;
    my ($startPt,$controlPt1,$controlPt2,$endPt) = @$pts;
    return _CubicN($T,$startPt->[0],$controlPt1->[0],$controlPt2->[0],$endPt->[0]);
}

sub _getCubicBezierYatT($$){
    my ($pts,$T) = @_;
    my ($startPt,$controlPt1,$controlPt2,$endPt) = @$pts;
    return _CubicN($T,$startPt->[1],$controlPt1->[1],$controlPt2->[1],$endPt->[1]);
}

sub _getCubicBezierYatX($$$){
    my ($pts,$X,$tolerance) = @_;
    my ($startPt,$controlPt1,$controlPt2,$endPt) = @$pts;

    $X >= $startPt->[0] || return undef;
    $X <= $endPt->[0]   || return undef;
    
    my $lower = 0;
    my $upper = 1;

    my $T = ($upper + $lower) / 2;

    my $x = _CubicN($startPt->[0],$controlPt1->[0],$controlPt2->[0],$endPt->[0],$T);

    ## approximation loop
    my $max_loops = 10; my $i=0;
    while(abs($X - $x) > $tolerance &&  $i++ < $max_loops) {	
	if($X > $x) {
	    $lower = $T;
	}
	else {
	    $upper = $T;
	}
	
	$T = ($upper + $lower) / 2;
	$x = _CubicN($startPt->[0],$controlPt1->[0],$controlPt2->[0],$endPt->[0],$T);
    }

    my $y = _CubicN($startPt->[1],$controlPt1->[1],$controlPt2->[1],$endPt->[1],$T); 

    return $y;
}




=item B<CubicBezierChain([P0, ...]) 

Generates a data structure from a list reference of 2D points:

  {BEZIER => {CHUNKS => [ <CHUNK> [, ...]  ]}} 
    CHUNK : [P0,P1,P2,P3]
    PX    : [X,Y]

Size of input list must be 4 + n * 3

=cut

sub CubicBezierChain($) {
    my $points = shift;

    ref($points) eq 'ARRAY' || die 'Expect array reference of points';
    
    my @points = @$points;
    my $npoints = @points;

    ##
    ## check size
    ##
    
    $npoints >= 4           || die "Expect 4 or more points but only got $npoints"; 
    ($npoints - 4) % 3 == 0 || die "Expect 4 + n * 3 points, eg 4,7,10,13 ... but got $npoints";

    ##
    ## build chunks
    ##

    my @chunks = ();

    my $p0 = shift(@points);
    
    while(@points) {
	my $p1 = shift(@points);
	my $p2 = shift(@points);
	my $p3 = shift(@points);
	push(@chunks, [$p0,$p1,$p2,$p3]);
	$p0 = $p3;
    }

    return {
	CHUNKS => \@chunks,
	X1 => $chunks[0][0][0],
	X2 => $chunks[ scalar(@chunks) -1 ][3][0]
    }
}



=item B<getThetaCurve(BEZIER_CHAIN,N)>

Returns a reference to list of approximately N 2D points. The points
are guaranteed not to be subsequent duplicates of each other.

Due to rounding effects, the resulting number of points may not be
exactly the same as the number of Theta increments.

=cut

sub getThetaCurve($$) {
    my ($bezchain,$n_overall) = @_;

    ## calculate the size of increments of theta to achieve the
    ## desired number of points.
    
    my $n_chunks = scalar(@{$bezchain->{CHUNKS}});
    my $increment = 1/( ($n_overall - $n_chunks) /$n_chunks);

    my @points = ();
    my $last_x = undef;
    
    for my $chunk (@{$bezchain->{CHUNKS}}) {

	my $T = 0; 
	while($T < 1) {
	    my $point = _getCubicBezierXYatT($chunk,$T);

	    if(!defined($last_x) || $point->[0] != $last_x) {
		#DEBUG [$last_x,$point->[0]];
		push(@points, $point);
		$last_x = $point->[0]; 
	    }

	    $T += $increment;
	}

	push(@points, [$chunk->[3][0], $chunk->[3][1]]); # last point of last chunk
	$last_x = $chunk->[3][0];
    }

    # DEBUG {n_chunks=>$n_chunks, n_overall=>$n_overall, increment=>$increment, n_overall_actual=>scalar(@points), points=>\@points};
    
    return \@points;
}



=item B<getIntervalCurve(BEZIER_CHAIN, INTERVAL) {>

Points of Bezier Chain Curve based on fixed, approximated x intervals.

=cut

sub getIntervalCurve($$) {
    my ($bezchain,$interval) = @_;

    my $tolerance = $interval/2 + 1;
    
    my $x1 = $bezchain->{X1};
    my $x2 = $bezchain->{X2};

    my @points = ();

    
    my $chunk_i = 0;
    my $chunk = $bezchain->{CHUNKS}[$chunk_i];

    ## record start point
    my $x = $chunk->[0][0]; 
    my $y = $chunk->[0][1]; 
    push(@points, [$x,$y]);
    
    while($x < $x2) {
	## wind forward to next chunk if x is out-of-range

	while($x > $bezchain->{CHUNKS}[$chunk_i][3][0] ){
	    $chunk_i++;
	    $chunk =  $bezchain->{CHUNKS}[$chunk_i]; 
	    $chunk || return \@points; ## precaution, should not happen 
	}

	my $y = _getCubicBezierYatX($chunk, $x, $tolerance);
	push(@points, [$x,$y]);
	
	## increment to next x
	$x += $interval;
    }

    ## record end point
    $x = $chunk->[3][0];
    $y = $chunk->[3][1]; 
    push(@points, [$x,$y]);

    return \@points;
}


=item B<getPointYatX($$$)

Get point XY at approximated point X on Bezier Chain curve.

=cut

sub getPointYatX($$$) {
    my ($bezchain,$x,$tolerance) = @_;

    my $chunk_i = 0;
    my $chunk = $bezchain->{CHUNKS}[$chunk_i];
    while($x > $bezchain->{CHUNKS}[$chunk_i][3][0] ){
	    $chunk_i++;
	    $chunk =  $bezchain->{CHUNKS}[$chunk_i]; 
	    $chunk || die "Point X $x out-of-bounds"
    }

    my $y = _getCubicBezierYatX($chunk, $x, $tolerance);
}



sub getIntervalCurve_10($) {
    return getIntervalCurve($_[0], 10)
}


sub mapCurve3D_xy0($) {
    my ($curve) = @_;
    return [
	map {
	    [ $_->[0], $_->[1], 0]
	} @$curve];
}

sub mapCurve3D_x0z($) {
    my ($curve) = @_;
    return [
	map {
	    [$_->[0], 0, $_->[1]]
	} @$curve];
}

sub mapCurve3D_0yz($) {
    my ($curve) = @_;
    return [
	map {
	    [$_->[0], $_->[1], 0]
	} @$curve];
}

##
## Expects two curves with the same number of elements at fixed
## intervals
##
sub spliceCurves3D_xy_xz($$) {
    my ($curve_xy, $curve_xz) = @_;

    ## build an array of z values
    my @z = map {$_->[1]} @$curve_xz; 
    
    return [
	map {
	    my $val = shift(@z);
	    my $z = $val if(defined($val));
	    [ $_->[0], $_->[1], $z ]
	} @$curve_xy
	];
}




sub mirrorCurve3D_y($) {
    my ($curve) = @_;
    return [
	map {
	    [$_->[0], $_->[1] * -1, $_->[2] ]
	} @$curve];
}

=back

=head1 OpenSCAD

=over 4

=item B<to_scad(EXPR)>

Transforms Perl data structures into SCAD syntax

=cut

sub to_scad($);
sub to_scad($) {
    my $x = shift;

    defined($x) || die "to_scad: called with undefined input";

    return "[" . join(",", map {to_scad($_)} @$x) . "]" if(ref($x) eq 'ARRAY');

    return $x;
}


sub print_scad {
    print join("\n",@_), "\n";
}



=head1 Mesh

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




=back



=head1 AUTHOR

Helmut Heinze 2021 (helmut.heinze@icloud.com) 

=cut

return 1;
