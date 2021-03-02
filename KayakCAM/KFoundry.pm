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

KayakCAM::KFoundry - Parser for Kayak Foundry-generated .yak files

=head1 SYNOPSIS

  parse

=cut



package KayakCAM::KFoundry;

use strict;
use warnings;

use vars qw( $VERSION );
use XML::Simple qw( :strict );
use Math::Trig;

use lib '../';
use KayakCAM::Utils;

use base 'Exporter';

our @EXPORT = qw();

##
## Constants
##

## NELO TR COAMING
##
##  Outer, measure from trace
##  X Axis:  0   90   220  350   480   610   735   845 
##  Y Axis:  0  230   325  410   455   465   430     0
##
##  Inner flange, measured from image
##  X        0  25  50  70  90 120 190 280 350 400 450 500 525 575 600 675 700 730 740 750 775 790 800 805 815 820 845
##  Y    -   0  40  60  75  95 120 148 170 185 190 200 207 210 210 203 190 180 170 167 140 120  99  87  60  35   0   -
##

my $_BEZIER_NELO_TR_COAMING = CubicBezierChain([[0,0], [110,215], [845,320], [845,0]]);
my $_LENGTH_NELO_TR_COAMING = 845;

sub debug_tr_coaming() {
    DEBUG [
	map {
	    my $x = $_->[0];
	    my $y_ref = $_->[1] * 2;
	    my $y_act = getPointYatX($_BEZIER_NELO_TR_COAMING,$x,3);
	    sprintf "%3d => %d  (deviation from reference: %d mm)", $x, $y_act*2, $y_act*2 - $y_ref; 
     #( [90,230], [220,325], [350,410], [480,455], [610,465], [735,430] )
     } ([25,40],[50,60],[90,95],[280,170],[400,190],[600,203],[700,180],[800,87],[815,35])
    ]
};

#debug_tr_coaming(); die;


## intermediate data structure
my %_YAK = ();



sub parse($$) {
    my $yak_path = shift;
    my $options  = shift;

    ## sanity checks
    $yak_path               || die "No valid path for Kayak Foundry yak file provided";
    ($yak_path =~ /\.yak$/) || die "Not a .yak file '$yak_path'";
    -f $yak_path            || die "No such Kayak Foundry yak file '$yak_path'";

    
    ## parsed input from Kayak Foundry
    my $XML = XMLin($yak_path,
		    ForceArray => 1,
		    KeyAttr => {
			'form-layouts'=>'name',
			    'DeckAssembly'=>'name',
			    'CockpitSection'=>'name',
			    'CockpitShape'=>'name',
			    'Cockpit'=>'name',
			    'control-points'=>'name',
			    'point'=>'name',
			    'section-control'=>'name',
			    'cs-control'=>'name',
			    'string'=>'name',
			    'integer'=>'name',
			    'integer-set'=>'name',
			    'double'=>'name',
			    'Bezier'=>'name'
		    });

    
    my @cs = ();

    delete $XML->{'form-layouts'};

    my $DWL = $XML->{integer}{dwl}{content};
    
    ##
    ## cross section control points at 10%, 30%, 50%, 70%, 90%
    ##
    
    push @cs,
	$XML->{'cs-control'}{'cs'}{'section-control'}{'section1'},
	$XML->{'cs-control'}{'cs'}{'section-control'}{'section2'},
	$XML->{'cs-control'}{'cs'}{'section-control'}{'section3'},
	$XML->{'cs-control'}{'cs'}{'section-control'}{'section4'},
	$XML->{'cs-control'}{'cs'}{'section-control'}{'section5'},
	;
    
    for (@cs) {
	my $cs = $_;
	my %h = ();

	my $position = $cs->{integer}{position}{content};
	
	map {
	    $h{$_}{x} = $cs->{'point'}{$_}{integer}{x}{content};
	    $h{$_}{y} = $cs->{'point'}{$_}{integer}{y}{content} * -1;
	} ('hullkeel','hullsheer','decksheer','deckcenter');
	
	$_YAK{CS}{$position} = \%h;
	
    }



    
    
    
    ##
    ## Bezier for sheer, sheerline (mirrored), hull,  
    ##

    my $xml;
    my $bez;

    ## sheerline bow   cont1   cont2   stern
    ##           x-o   o-x-o   o-x-o   o-x
    $xml = $XML->{Bezier}{sheerline}{'control-points'}{'points'}{'point'};
    $bez = {
	p1 => { # none (= bow 0/0)
	    x=>$xml->{point1}{integer}{x}{content},
	    y=>$xml->{point1}{integer}{y}{content}
	},
	p2 => { # circle
	    x=>$xml->{point2}{integer}{x}{content},
	    y=>$xml->{point2}{integer}{y}{content}
	},
	p3 => { # circle
	    x=>$xml->{point3}{integer}{x}{content},
	    y=>$xml->{point3}{integer}{y}{content}
	},
	p4 => { # square
	    x=>$xml->{point4}{integer}{x}{content},
	    y=>$xml->{point4}{integer}{y}{content}
	},
	p5 => { # circle
	    x=>$xml->{point5}{integer}{x}{content},
	    y=>$xml->{point5}{integer}{y}{content}
	},
	p6 => { # circle
	    x=>$xml->{point6}{integer}{x}{content},
	    y=>$xml->{point6}{integer}{y}{content}
	},
	p7 => { # square
	    x=>$xml->{point7}{integer}{x}{content},
	    y=>$xml->{point7}{integer}{y}{content}
	},
	p8 => { # circle
	    x=>$xml->{point8}{integer}{x}{content},
	    y=>$xml->{point8}{integer}{y}{content}
	},
	p9 => { # circle
	    x=>$xml->{point9}{integer}{x}{content},
	    y=>$xml->{point9}{integer}{y}{content}
	},
	p10 => { # square (=stern)
	    x=>$xml->{point10}{integer}{x}{content},
	    y=>$xml->{point10}{integer}{y}{content}
	}
    };

    $_YAK{BEZIER}{sheer_xy} = $bez;

    
    ## sheer bow  cont   stern
    ##       x-o  o-x-o  o-x
    $xml = $XML->{Bezier}{sheer}{'control-points'}{'points'}{'point'};
    $bez = {
	p1 => { # square
	    x=>$xml->{point1}{integer}{x}{content},
	    y=>$xml->{point1}{integer}{y}{content}
	},
	p2 => { # circle
	    x=>$xml->{point2}{integer}{x}{content},
	    y=>$xml->{point2}{integer}{y}{content}
	},
	p3 => { # circle
		x=>$xml->{point3}{integer}{x}{content},
		y=>$xml->{point3}{integer}{y}{content}
	},
	p4 => { # square
	    x=>$xml->{point4}{integer}{x}{content},
	    y=>$xml->{point4}{integer}{y}{content}
	    },
	p5 => { # circle
	    x=>$xml->{point5}{integer}{x}{content},
	    y=>$xml->{point5}{integer}{y}{content}
	},
	p6 => {
	    x=>$xml->{point6}{integer}{x}{content},
	    y=>$xml->{point6}{integer}{y}{content}
	},
	p7 => { # square 
	    x=>$xml->{point7}{integer}{x}{content},
	    y=>$xml->{point7}{integer}{y}{content}
	}
    };

    $_YAK{BEZIER}{sheer_xz}  = $bez;
    

    
    ## hull  bow  cont1  cont2  cont3  stern
    ##       x-o  o-x-o  o-x-o  o-x-o  o-x
    $xml = $XML->{Bezier}{hull}{'control-points'}{'points'}{'point'};
    $bez = {
	p1 => { # bow point
	    x=>$xml->{point1}{integer}{x}{content},
	    y=>$xml->{point1}{integer}{y}{content}
	},
	p2 => { # 1st control
	    x=>$xml->{point2}{integer}{x}{content},
	    y=>$xml->{point2}{integer}{y}{content}
	},
	p3 => { # circle
	    x=>$xml->{point3}{integer}{x}{content},
	    y=>$xml->{point3}{integer}{y}{content}
	},
	p4 => { # square
	    x=>$xml->{point4}{integer}{x}{content},
	    y=>$xml->{point4}{integer}{y}{content}
	},
	p5 => { # circle
	    x=>$xml->{point5}{integer}{x}{content},
	    y=>$xml->{point5}{integer}{y}{content}
	},
	p6 => { # circle
	    x=>$xml->{point6}{integer}{x}{content},
	    y=>$xml->{point6}{integer}{y}{content}
	},
	p7 => { # square
	    x=>$xml->{point7}{integer}{x}{content},
	    y=>$xml->{point7}{integer}{y}{content}
	},
	p8 => { # circle
	    x=>$xml->{point8}{integer}{x}{content},
	    y=>$xml->{point8}{integer}{y}{content}
	},
	p9 => {
	    x=>$xml->{point9}{integer}{x}{content},
	    y=>$xml->{point9}{integer}{y}{content}
	},
	p10 => { # square
	    x=>$xml->{point10}{integer}{x}{content},
	    y=>$xml->{point10}{integer}{y}{content}
	},
	p11 => { # circle
	    x=>$xml->{point11}{integer}{x}{content},
	    y=>$xml->{point11}{integer}{y}{content}
	},
	p12 => { # circle
	    x=>$xml->{point12}{integer}{x}{content},
	    y=>$xml->{point12}{integer}{y}{content}
	},
	p13 => { # square
	    x=>$xml->{point13}{integer}{x}{content},
	    y=>$xml->{point13}{integer}{y}{content}
	}
    };

    $_YAK{BEZIER}{hull} = $bez;


    ##
    ## deck assembly: FORE - COCKPIT - BACK
    ##

    ## Cockpit 1
    $xml = $XML->{DeckAssembly}{deck}{CockpitSection}{middle}{Cockpit}{cockpit1};
    
    $_YAK{DECK}{COCKPIT}{fore}{point}{x} =  $xml->{point}{fore}{integer}{x}{content};
    $_YAK{DECK}{COCKPIT}{fore}{point}{y} =  $xml->{point}{fore}{integer}{y}{content};
    $_YAK{DECK}{COCKPIT}{aft}{point}{x} =  $xml->{point}{aft}{integer}{x}{content};
    $_YAK{DECK}{COCKPIT}{aft}{point}{y} =  $xml->{point}{aft}{integer}{y}{content};

    ## Bow to cockpit
    $xml = $XML->{DeckAssembly}{deck}{'control-points'}{bow}{point}; 
    $_YAK{DECK}{FORE}{p1}{x} = $xml->{point1}{integer}{x}{content};
    $_YAK{DECK}{FORE}{p1}{y} = $xml->{point1}{integer}{y}{content};
    $_YAK{DECK}{FORE}{p2}{x} = $xml->{point2}{integer}{x}{content}; 
    $_YAK{DECK}{FORE}{p2}{y} = $xml->{point2}{integer}{y}{content}; 
    $_YAK{DECK}{FORE}{p3}{x} = $xml->{point3}{integer}{x}{content};  
    $_YAK{DECK}{FORE}{p3}{y} = $xml->{point3}{integer}{y}{content}; 
    $_YAK{DECK}{FORE}{p4}{x} = $xml->{point4}{integer}{x}{content};
    $_YAK{DECK}{FORE}{p4}{y} = $xml->{point4}{integer}{y}{content};

    ## Cockpit to stern
    $xml = $XML->{DeckAssembly}{deck}{'control-points'}{stern}{point}; 
    $_YAK{DECK}{AFT}{p1}{x} = $xml->{point1}{integer}{x}{content};
    $_YAK{DECK}{AFT}{p1}{y} = $xml->{point1}{integer}{y}{content};
    $_YAK{DECK}{AFT}{p2}{x} = $xml->{point2}{integer}{x}{content}; 
    $_YAK{DECK}{AFT}{p2}{y} = $xml->{point2}{integer}{y}{content}; 
    $_YAK{DECK}{AFT}{p3}{x} = $xml->{point3}{integer}{x}{content};  
    $_YAK{DECK}{AFT}{p3}{y} = $xml->{point3}{integer}{y}{content}; 
    $_YAK{DECK}{AFT}{p4}{x} = $xml->{point4}{integer}{x}{content};
    $_YAK{DECK}{AFT}{p4}{y} = $xml->{point4}{integer}{y}{content};

    ## coaming shape
    $xml = $XML->{CockpitShape}{A}{'control-points'}{points}{point}; 
    $_YAK{COAMING}{p1}{x} = $xml->{point1}{integer}{x}{content};
    $_YAK{COAMING}{p1}{y} = $xml->{point1}{integer}{y}{content};
    $_YAK{COAMING}{p2}{x} = $xml->{point2}{integer}{x}{content};
    $_YAK{COAMING}{p2}{y} = $xml->{point2}{integer}{y}{content};
    $_YAK{COAMING}{p3}{x} = $xml->{point3}{integer}{x}{content};
    $_YAK{COAMING}{p3}{y} = $xml->{point3}{integer}{y}{content};
    $_YAK{COAMING}{p4}{x} = $xml->{point4}{integer}{x}{content};
    $_YAK{COAMING}{p4}{y} = $xml->{point4}{integer}{y}{content};


    ##
    ##
    ## Assemble result
    ##
    ##

    my $test = CubicBezierChain(
	[
	 [$_YAK{BEZIER}{hull}{p1}{x}, $_YAK{BEZIER}{hull}{p1}{y}],
	 [$_YAK{BEZIER}{hull}{p2}{x}, $_YAK{BEZIER}{hull}{p2}{y}],
	 [$_YAK{BEZIER}{hull}{p3}{x}, $_YAK{BEZIER}{hull}{p3}{y}],
	 [$_YAK{BEZIER}{hull}{p4}{x}, $_YAK{BEZIER}{hull}{p4}{y}],
	 [$_YAK{BEZIER}{hull}{p5}{x}, $_YAK{BEZIER}{hull}{p5}{y}],
	 [$_YAK{BEZIER}{hull}{p6}{x}, $_YAK{BEZIER}{hull}{p6}{y}],
	 [$_YAK{BEZIER}{hull}{p7}{x}, $_YAK{BEZIER}{hull}{p7}{y}],
	 [$_YAK{BEZIER}{hull}{p8}{x}, $_YAK{BEZIER}{hull}{p8}{y}],
	 [$_YAK{BEZIER}{hull}{p9}{x}, $_YAK{BEZIER}{hull}{p9}{y}],
	 [$_YAK{BEZIER}{hull}{p10}{x}, $_YAK{BEZIER}{hull}{p10}{y}],
	 [$_YAK{BEZIER}{hull}{p11}{x}, $_YAK{BEZIER}{hull}{p11}{y}],
	 [$_YAK{BEZIER}{hull}{p12}{x}, $_YAK{BEZIER}{hull}{p12}{y}],
	 [$_YAK{BEZIER}{hull}{p13}{x}, $_YAK{BEZIER}{hull}{p13}{y}]
	]
	);

    
    my $bezier_hull = CubicBezierChain(
	[
	 [$_YAK{BEZIER}{hull}{p1}{x}, $_YAK{BEZIER}{hull}{p1}{y}],
	 [$_YAK{BEZIER}{hull}{p2}{x}, $_YAK{BEZIER}{hull}{p2}{y}],
	 [$_YAK{BEZIER}{hull}{p3}{x}, $_YAK{BEZIER}{hull}{p3}{y}],
	 [$_YAK{BEZIER}{hull}{p4}{x}, $_YAK{BEZIER}{hull}{p4}{y}],
	 [$_YAK{BEZIER}{hull}{p5}{x}, $_YAK{BEZIER}{hull}{p5}{y}],
	 [$_YAK{BEZIER}{hull}{p6}{x}, $_YAK{BEZIER}{hull}{p6}{y}],
	 [$_YAK{BEZIER}{hull}{p7}{x}, $_YAK{BEZIER}{hull}{p7}{y}],
	 [$_YAK{BEZIER}{hull}{p8}{x}, $_YAK{BEZIER}{hull}{p8}{y}],
	 [$_YAK{BEZIER}{hull}{p9}{x}, $_YAK{BEZIER}{hull}{p9}{y}],
	 [$_YAK{BEZIER}{hull}{p10}{x}, $_YAK{BEZIER}{hull}{p10}{y}],
	 [$_YAK{BEZIER}{hull}{p11}{x}, $_YAK{BEZIER}{hull}{p11}{y}],
	 [$_YAK{BEZIER}{hull}{p12}{x}, $_YAK{BEZIER}{hull}{p12}{y}],
	 [$_YAK{BEZIER}{hull}{p13}{x}, $_YAK{BEZIER}{hull}{p13}{y}]
	]);

    ## sheer line side top view (rh side)
    my $bezier_sheer_horizontal = CubicBezierChain(
	[
	 [$_YAK{BEZIER}{sheer_xy}{p1}{x}, $_YAK{BEZIER}{sheer_xy}{p1}{y}],
	 [$_YAK{BEZIER}{sheer_xy}{p2}{x}, $_YAK{BEZIER}{sheer_xy}{p2}{y}],
	 [$_YAK{BEZIER}{sheer_xy}{p3}{x}, $_YAK{BEZIER}{sheer_xy}{p3}{y}],
	 [$_YAK{BEZIER}{sheer_xy}{p4}{x}, $_YAK{BEZIER}{sheer_xy}{p4}{y}],
	 [$_YAK{BEZIER}{sheer_xy}{p5}{x}, $_YAK{BEZIER}{sheer_xy}{p5}{y}],
	 [$_YAK{BEZIER}{sheer_xy}{p6}{x}, $_YAK{BEZIER}{sheer_xy}{p6}{y}],
	 [$_YAK{BEZIER}{sheer_xy}{p7}{x}, $_YAK{BEZIER}{sheer_xy}{p7}{y}],
	 [$_YAK{BEZIER}{sheer_xy}{p8}{x}, $_YAK{BEZIER}{sheer_xy}{p8}{y}],
	 [$_YAK{BEZIER}{sheer_xy}{p9}{x}, $_YAK{BEZIER}{sheer_xy}{p9}{y}],
	 [$_YAK{BEZIER}{sheer_xy}{p10}{x},$_YAK{BEZIER}{sheer_xy}{p10}{y} + $options->{transom}/2],
	]);
    
    
    
    ## sheer line side view (x & z)
    my $bezier_sheer_vertical = CubicBezierChain(
	[
	 [$_YAK{BEZIER}{sheer_xz}{p1}{x}, $_YAK{BEZIER}{sheer_xz}{p1}{y}],
	 [$_YAK{BEZIER}{sheer_xz}{p2}{x}, $_YAK{BEZIER}{sheer_xz}{p2}{y}],
	 [$_YAK{BEZIER}{sheer_xz}{p3}{x}, $_YAK{BEZIER}{sheer_xz}{p3}{y}],
	 [$_YAK{BEZIER}{sheer_xz}{p4}{x}, $_YAK{BEZIER}{sheer_xz}{p4}{y}],
	 [$_YAK{BEZIER}{sheer_xz}{p5}{x}, $_YAK{BEZIER}{sheer_xz}{p5}{y}],
	 [$_YAK{BEZIER}{sheer_xz}{p6}{x}, $_YAK{BEZIER}{sheer_xz}{p6}{y}],
	 [$_YAK{BEZIER}{sheer_xz}{p7}{x}, $_YAK{BEZIER}{sheer_xz}{p7}{y}],
	]);

    ## deck
    my $bezier_deck_fore =  CubicBezierChain(
	[
	 [$_YAK{DECK}{FORE}{p1}{x}, $_YAK{DECK}{FORE}{p1}{y}],
	 [$_YAK{DECK}{FORE}{p2}{x}, $_YAK{DECK}{FORE}{p2}{y}],
	 [$_YAK{DECK}{FORE}{p3}{x}, $_YAK{DECK}{FORE}{p3}{y}],
	 [$_YAK{DECK}{FORE}{p4}{x}, $_YAK{DECK}{FORE}{p4}{y}],
	]);
    my $bezier_deck_mid =  CubicBezierChain(
	[
	 [$_YAK{DECK}{FORE}{p4}{x}, $_YAK{DECK}{FORE}{p4}{y}],
	 [$_YAK{DECK}{FORE}{p4}{x}, $_YAK{DECK}{FORE}{p4}{y}],
	 [$_YAK{DECK}{AFT}{p1}{x}, $_YAK{DECK}{AFT}{p1}{y}] ,
	 [$_YAK{DECK}{AFT}{p1}{x}, $_YAK{DECK}{AFT}{p1}{y}] 
	]);
    my $bezier_deck_aft = CubicBezierChain(
	[
	 [$_YAK{DECK}{AFT}{p1}{x}, $_YAK{DECK}{AFT}{p1}{y}],
	 [$_YAK{DECK}{AFT}{p2}{x}, $_YAK{DECK}{AFT}{p2}{y}],
	 [$_YAK{DECK}{AFT}{p3}{x}, $_YAK{DECK}{AFT}{p3}{y}],
	 [$_YAK{DECK}{AFT}{p4}{x}, $_YAK{DECK}{AFT}{p4}{y}]
	]);

    ## calculate angle of coaming
    my $cockpit_x1 = $_YAK{DECK}{FORE}{p4}{x};
    my $cockpit_z1 = $_YAK{DECK}{FORE}{p4}{y};
    my $cockpit_x2 = $_YAK{DECK}{AFT}{p1}{x};
    my $cockpit_z2 = $_YAK{DECK}{AFT}{p1}{y};
    my $c = $cockpit_x2 - $cockpit_x1;
    my $b = $cockpit_z1 - $cockpit_z2;
    my $a = int(sqrt($c * $c - $b * $b));
    my $coaming_angle = Math::Trig::rad2deg(acos($a/$c)); 

    
    my %data = (
	## length overall
	LOA => $XML->{integer}{loa}{content},
	BOW_HEIGHT => $XML->{integer}{'bow-height'}{content},
	STERN_HEIGHT => $XML->{integer}{'stern-height'}{content},
	## DWL vertical offset
	DWL => $DWL,
	## Cockpit pos
	COCKPIT_X_FORE => $_YAK{DECK}{FORE}{p4}{x},
	COCKPIT_Z_FORE => $_YAK{DECK}{FORE}{p4}{y},
	COCKPIT_X_AFT  => $_YAK{DECK}{AFT}{p1}{x},
	COCKPIT_Z_AFT  => $_YAK{DECK}{AFT}{p1}{y},
	
	## hardwired for approximating Nelo TR
	BEZIER_COAMING => $_BEZIER_NELO_TR_COAMING,
	COAMING_ANGLE  => $coaming_angle,

	## Beziers in the vertical plane
	BEZIER_XZ_AXIS => {
	    KEEL  => $bezier_hull,
	    SHEER => $bezier_sheer_vertical,
	    DECK_FORE  => $bezier_deck_fore,
	    DECK_MID   => $bezier_deck_mid,
	    DECK_AFT   => $bezier_deck_aft
	},
	## Beziers in the horizontal plane
	BEZIER_XY_AXIS => {
	    SHEER => $bezier_sheer_horizontal,
	},
	## Beziers in the depths plane
	BEZIER_YZ_AXIS => {
	}
	);

    
    $data{BEZIER_YZ_AXIS}{CS_10} = parse_bezier_cs(\%data,10);
    $data{BEZIER_YZ_AXIS}{CS_30} = parse_bezier_cs(\%data,30);  
    $data{BEZIER_YZ_AXIS}{CS_50} = parse_bezier_cs(\%data,50);
    $data{BEZIER_YZ_AXIS}{CS_70} = parse_bezier_cs(\%data,70);
    $data{BEZIER_YZ_AXIS}{CS_90} = parse_bezier_cs(\%data,90);


    LOG_INFO (
     	sprintf("YAK File:     %s", $yak_path),
	sprintf("Last Update:  %s", STRFTIME("%Y-%m-%d %T", (stat($yak_path))[9])),
	sprintf("LOA:          %4d mm", $data{LOA}),
	sprintf("Cockpit:      %4d mm", ($data{COCKPIT_X_AFT} - $data{COCKPIT_X_FORE})),
	sprintf("COG:          %4d mm", ($data{COCKPIT_X_AFT} - 350)),
	);

    return \%data; 
}


sub parse_bezier_cs($$) {
     my ($data,$position) = @_;

    ($position==10 ||
     $position==30 ||
     $position==50 ||
     $position==70 ||
     $position==90 ) || die "Invalid position for cross sections (must be 10|30|50|70|90)";
    
     my $at_x  = int($position/100 * $data->{LOA});
     my $PRECISION = 5;    

     ##
     ## get keel, sheer, deck, viewed  at x
     ##
     
     ## keel
     my $point_keel_z = getPointYatX($data->{BEZIER_XZ_AXIS}{KEEL}, $at_x, $PRECISION);

     ## deck
     my $bez = $data->{BEZIER_XZ_AXIS}{DECK_FORE};
     $bez = $data->{BEZIER_XZ_AXIS}{DECK_MID} if($at_x > $bez->{X2});
     $bez = $data->{BEZIER_XZ_AXIS}{DECK_AFT} if($at_x > $bez->{X2});
     my $point_deck_z = getPointYatX($bez, $at_x, $PRECISION);
     
     ## sheer
     my $point_sheer_y = getPointYatX($data->{BEZIER_XY_AXIS}{SHEER}, $at_x, $PRECISION);
     my $point_sheer_z = getPointYatX($data->{BEZIER_XZ_AXIS}{SHEER}, $at_x, $PRECISION);
     
     ##
     ## the control points are relative to the anchor points, expressed in 10,000th of the distance to the other anchor point
     ##
     my $k_hull_y = $point_sheer_y / 10000;                    # 1/10,000 of the distance from the centre to the sheer line
     my $k_hull_z = ($point_sheer_z - $point_keel_z) / 10000;  # 1/10,000 of the distance between keel and sheer
     
     my $k_deck_y = $k_hull_y;
     my $k_deck_z = ($point_deck_z - $point_sheer_z) / 10000;  # 1/10,000 of the distance between deck and sheer
     
     my $bezier = CubicBezierChain(
	 [
	  ## segment deck to sheer
	  [0, $point_deck_z],
	  [($_YAK{CS}{$position}{deckcenter}{x} * $k_deck_y),  ($point_deck_z  + $_YAK{CS}{$position}{deckcenter}{y} * $k_deck_z)],
	  [$point_sheer_y + ($_YAK{CS}{$position}{decksheer}{x}  * $k_deck_y),  ($point_sheer_z + $_YAK{CS}{$position}{decksheer}{y}  * $k_deck_z)],
	  ## common
	  [$point_sheer_y, $point_sheer_z],
	  ## segment sheer to keel
	  [$point_sheer_y + ($_YAK{CS}{$position}{hullsheer}{x}  * $k_hull_y),  ($point_sheer_z + $_YAK{CS}{$position}{hullsheer}{y}  * $k_hull_z)],
	  [($_YAK{CS}{$position}{hullkeel}{x}   * $k_hull_y),  ($point_keel_z  + $_YAK{CS}{$position}{hullkeel}{y}   * $k_hull_z)],
	  [0, $point_keel_z]
	 ]);

    return $bezier;
}


##
## generates a single Bezier cross section at point x
##
## With the argument {shrink => INT} generates the skin of the
## inner wall skin INT mm apart from the outer skin.
##


sub make_cs_at_x($$$) {
    my ($data,$x,$options) = @_;

    $options = {
	tolerance => 5,
	shrink => 0
    } if(!$options);
    
    my $TOLERANCE = $options->{tolerance}? $options->{tolerance} : 5;
    my $SHRINK = ($options->{shrink} && $options->{shrink} =~ /^\d+$/)?
	$options->{shrink} :
	0;
    
    my $loa = $data->{LOA};
    $x =~ /^\d+$/ &&  $x >= 0 && $x <= $loa || die "make_cs_at_x: x=$x is out of range";
    
    
    my $percent_at_x = $x/$loa*100;

    my $bh = $data->{BOW_HEIGHT}   * -1;
    my $sh = $data->{STERN_HEIGHT} * -1;
    
    my $pos_ref1;
    my $pos_ref2;
    my $_k; # relative proximity to cs_ref1 -> x cs_ref2 in 
    
    if($percent_at_x <= 10) {
	$pos_ref1 = 0;
	$pos_ref2 = 10;
	$_k = $x/($loa * 0.1);
    }
    elsif($percent_at_x <= 30) {
	$pos_ref1 = 10;
	$pos_ref2 = 30;
	$_k = ($x - $loa * 0.1)/($loa * 0.2);
    }
    elsif($percent_at_x <= 50) {
	$pos_ref1 = 30; 
	$pos_ref2 = 50;
	$_k = ($x - $loa * 0.3)/($loa * 0.2);
    }
    elsif($percent_at_x <= 70) {
	$pos_ref1 = 50;
	$pos_ref2 = 70;
	$_k = ($x - $loa * 0.5)/($loa * 0.2);
    }
    elsif($percent_at_x <= 90) {
	$pos_ref1 = 70;
	$pos_ref2 = 90;
	$_k = ($x - $loa * 0.7)/($loa * 0.2);
    }
    else {
	$pos_ref1 = 90;
	$pos_ref2 = 0;
	$_k = ($x - $loa * 0.9)/($loa * 0.1);
    }
    my $k1 = (1 - $_k);  # multiplier for ref_cs1
    my $k2 = $_k;        # multiplier for ref_cs2

    ##
    ## get keel, sheer, deck, viewed  at x
    ##
    
    ## keel
    my $point_keel_z = getPointYatX($data->{BEZIER_XZ_AXIS}{KEEL}, $x, $TOLERANCE);

    ## deck
    my $is_coaming_area = '';

    my $point_deck_y = 0;  # usually the middle line unless we are at the coaming
    my $point_deck_z;
    if    ($x <= $data->{BEZIER_XZ_AXIS}{DECK_FORE}{X2}) {
	$point_deck_z = getPointYatX($data->{BEZIER_XZ_AXIS}{DECK_FORE}, $x, $TOLERANCE);
    }
    elsif ($x <= $data->{BEZIER_XZ_AXIS}{DECK_MID}{X2}) {
	$point_deck_z = getPointYatX($data->{BEZIER_XZ_AXIS}{DECK_MID}, $x, $TOLERANCE);
	
	## find side edge of coaming which is angled  (stretch factor: cos(angle)  )
	my $k_coaming = 1/cos(Math::Trig::deg2rad($data->{COAMING_ANGLE}));
	my $x_of_coaming = ($x - $data->{BEZIER_XZ_AXIS}{DECK_MID}{X1}) * $k_coaming;
	$point_deck_y = ($x_of_coaming <= $data->{BEZIER_COAMING}{X2})?
	    getPointYatX($data->{BEZIER_COAMING}, $x_of_coaming, 5) :
	    0;
	$is_coaming_area = 1; 
    }
    else {
	$point_deck_z = getPointYatX($data->{BEZIER_XZ_AXIS}{DECK_AFT}, $x, $TOLERANCE);
    }


    
    ## sheer
    my $point_sheer_y = getPointYatX($data->{BEZIER_XY_AXIS}{SHEER}, $x, $TOLERANCE);
    my $point_sheer_z = getPointYatX($data->{BEZIER_XZ_AXIS}{SHEER}, $x, $TOLERANCE);

    ##
    ## the control points are relative to the anchor points, expressed in 10,000th of the distance to the other anchor point
    ##
    my $k_hull_y = $point_sheer_y / 10000;                    # 1/10,000 of the distance from the centre to the sheer line
    my $k_hull_z = ($point_sheer_z - $point_keel_z) / 10000;  # 1/10,000 of the distance between keel and sheer
    my $k_deck_y = $k_hull_y;
    my $k_deck_z = ($point_deck_z - $point_sheer_z) / 10000;  # 1/10,000 of the distance between deck and sheer

    ## ========================================================================
    ##
    ## helper function
    ##
    my $interpolated_cp = sub ($) {
	my $name = shift;

	## reference values in 0.01 %
	my $p1_x = $_YAK{CS}{$pos_ref1}{$name}{x}; 
	my $p2_x = $_YAK{CS}{$pos_ref2}{$name}{x};  
	my $p1_y = $_YAK{CS}{$pos_ref1}{$name}{y}; 
	my $p2_y = $_YAK{CS}{$pos_ref2}{$name}{y};

	if($pos_ref1 == 0) {
	    $p1_x = 0;
	    $p1_y = $data->{BOW_HEIGHT};
	}
	elsif($pos_ref2 == 0) {
	    $p2_x = 0;
	    $p2_y = $data->{STERN_HEIGHT};
	}

	my $p_x = $p1_x * $k1 + $p2_x * $k2;
	my $p_y = $p1_y * $k1 + $p2_y * $k2;  
	return [$p_x,$p_y];
    };
    ##
    ##
    ## ========================================================================

    my $cp_deckcenter = &$interpolated_cp('deckcenter');
    my $cp_decksheer  = &$interpolated_cp('decksheer');
    my $cp_hullsheer  = &$interpolated_cp('hullsheer');
    my $cp_hullkeel   = &$interpolated_cp('hullkeel');



    return CubicBezierChain(
	[
	 ## segment deck to sheer
	 [$point_deck_y, $point_deck_z + $SHRINK], 
	 
	 
	 ## 1st control point in coaming area matches start point
	 ($is_coaming_area?
	  [$point_deck_y, $point_deck_z] :

	  ## prevent y from going negative!
	  [ (($cp_deckcenter->[0] * $k_deck_y) > $SHRINK)?  ($cp_deckcenter->[0] * $k_deck_y) - $SHRINK : 0, ($point_deck_z  + $cp_deckcenter->[1] * $k_deck_z) + $SHRINK]),

	 [($point_sheer_y + $cp_decksheer->[0] * $k_deck_y) - $SHRINK, ($point_sheer_z + $cp_decksheer->[1]  * $k_deck_z) + $SHRINK],

	 ## common
	 [$point_sheer_y - $SHRINK * 1, $point_sheer_z ], 

	 ## segment sheer to keel
	 [$point_sheer_y + ($cp_hullsheer->[0] * $k_hull_y) - $SHRINK, ($point_sheer_z + $cp_hullsheer->[1]  * $k_hull_z) - $SHRINK],
	 [($cp_hullkeel->[0] * $k_hull_y)                   - $SHRINK , ($point_keel_z  + $cp_hullkeel->[1]  * $k_hull_z) - $SHRINK],

	 [0, $point_keel_z - $SHRINK]
	]);
}




=head1 AUTHOR

Helmut Heinze 2021 (helmut.heinze@icloud.com) 

=cut

return 1;
