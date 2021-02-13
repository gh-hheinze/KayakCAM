# NAME

kcam - KayakCAM command line tool

# SYNOPSIS

kcam <OPTIONS> <YAK INPUT FILE> [<OUTPUT FILE> ...]

# DESCRIPTION

KayakCAM is a somewhat minimalist set of Perl tools for computer-aided
manufacturing (CAM) of kayaks. It builds on the file output of Kayak
Foundry ((C) 2002-2009 by Ross Leidy) to allow for further processing
beyond printing of stations, namely additional post-processing of the
geometry, exporting to OpenSCAD, generating 3D models for ray tracing
etc, and last not least CNC data.

# INSTALLATION

kcam comes along with a couple of Perl modules in the namespace of
KayakCAM. Install these Perl modules somewhere where Perl can find
them.  The kcam tool adds the current directory to the search path; in
a pinch just invoke the script in a directory that contains a
subdirectory

      ./kcam
      ./KayakCAM/<MODULES>
	  
with the modules.

# USE

The kcam utility always takes a .yak file as its input. Its output
depends on output options and potentially additional, auxillary input
data.

The input .yak file is either given as positional parameter, either as a
full absolute or relative path to the .yak file>.

Examples:

      kcam ../../kayak.yak
      cat ../../kayak.yak | kcam

The type of output is controlled by additional positional parameters,
representing the desired output. The file suffix controls the type of
output. For example:

      kcam ../../kayak.yak  _test.stl

would read the .yak file from STDIN and create an output file
"test.stl" for for a 3D renderer. If no output format is provided then
a short info about kayak defined in the yak file is printed to STDERR.

More than one output can be given in a single invokation of the tool,
eg:

      kcam ../../kayak.yak   _kayak.stl  _kayak.scad

would produce for the yak file "kayak.yak" both a 3D model for
rendereing as "_kayak.stl" and for display in OpenSCAD "_kayak.scad".

This allows to run the tool in a continuous loop; any update to the
yak file will result in automatic updates to the specified output
files.

# OPTIONS

## -continuous

        Running in a continuous loop. Interrupt with Ctrl-C.

## -quiet

        Quiet. No output on console to STDERR except for errors.

## -verbose

        Additional output on console to STDERR

## -debug

        Additional debugging output to STDERR

# AUTHOR
   
KayakCAM Copyright (C) 2021 (helmut.heinze@icloud.com)

License GPLv3+: GNU GPL version 3 or later
<https://gnu.org/licenses/gpl.html> This is free software: you are
free to change and redistribute it. There is NO WARRANTY, to the
extent permitted by law.

# LIMITATIONS

Only tested with latest available version of Kayak Foundry 1.6.4

# BUGS

To few features to care at this stage

# TODO

Almost everything.

