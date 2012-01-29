#!/usr/bin/perl -wC31
use UI::KeyboardLayout; 
use strict;

#die "Usage: $0 [<] files" unless @ARGV;
#open my $f, '<', 
my $d = "$ENV{HOME}/Downloads";
my $f = "$ENV{HOME}/Downloads/NamesList-6.1.0d8.txt";		# or die;
-e "$d/NamesList-6.1.0d8.txt" or $d = '/cygdrive/c/Users/ilya/Downloads';
my $k = UI::KeyboardLayout::->new()->load_unidata("$d/NamesList-6.1.0d8.txt", "$d/DerivedAge-6.1.0d13.txt");

my $s;
{  local $/;
   $s = <>		# Unicod::UCD is not compatible with non-standard $/
}
$k->print_coverage_string($s);
