#!/usr/bin/perl -wC31
use UI::KeyboardLayout; 
use strict;

#open my $f, '<', 
my $f = "$ENV{HOME}/Downloads/NamesList-6.1.0d8.txt";		# or die;
my $k = UI::KeyboardLayout::->new()->load_compositions($f);

print <<EOP;
<html><head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/></head><body><table>
EOP
while (<>) {
  s/\s+$//;
  s(/|(?<=\t)(?=\S))(</td><td>)g;	# Make tabs and / separate columns
  s{([^\x00-\x7E])}{ sprintf '<span title="%04X  %s">%s</span>', ord $1, $k->UName("$1"), $1 }ge;
  print "<tr><td>$_</td></tr>\n"
}
print <<EOP;
</table></body></html>
EOP
