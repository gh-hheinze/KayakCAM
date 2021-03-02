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

KayakCAM::Config - Config module for KayakCAM.

=head1 SYNOPSIS

    use KayakCAM::Config;

    KayakCAM::Config::parse(PATH);
    KayakCAM::Config::config();

=cut




package KayakCAM::Config;

use strict;
use warnings;
use vars qw( $VERSION );

use KayakCAM::Utils;


use base 'Exporter';

our @EXPORT = qw(
);


my %_CONFIG = ();

sub parse($) {
    my $path = shift;
    $path || die "Config::parse: no valid path provided";
    -f $path || die "Config::parse: No such file '$path'";

    if(open(my $fh,'<',$path)) {
	my $lineno = 0;
	while(<$fh>) {
	    $lineno++;

	    my $line = $_;
	    chomp($line);
	    $line =~ s/#.*//;  # strip comments
	    $line =~ s/^\s*//; # strip leading space
	    $line =~ s/\s*$//; # strip trailing space

	    if($line eq '') {
	    }
	    elsif($line =~ /^(solid-bow|solid-stern|bulkhead-rear|transom|stern-hinge)\s*[:=]\s*(\d+)/) {
		my $key = $1; my $val=$2;
		LOG_INFO "Config: $path:$lineno: $key = $val";
		$key =~ s/-/_/g;
		$_CONFIG{$key} = $val;
	    }
	    else {
		LOG_WARNING "Config: $path:$lineno: illegal expression: '$line'";
	    }
	}
    }


}

sub get() {
    return \%_CONFIG;
}





=head1 AUTHOR

Helmut Heinze 2021 (helmut.heinze@icloud.com) 

=cut

return 1;
