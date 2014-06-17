use UI::KeyboardLayout;
use strict;
my $home = $ENV{HOME} || '';
$home = "$ENV{HOMEDRIVE}$ENV{HOMEPATH}" if $ENV{HOMEDRIVE} and $ENV{HOMEPATH};
UI::KeyboardLayout::->set_NamesList(qq($home/Downloads/NamesList.txt),
				    qq($home/Downloads/DerivedAge.txt))
  if -r qq($home/Downloads/NamesList.txt)
  and -r qq($home/Downloads/DerivedAge.txt);
warn "No NamesList/DerivedAge file found" unless UI::KeyboardLayout::->get_NamesList;

my $C = '/usr/share/X11/locale/en_US.UTF-8/Compose';
$C = "$home/Downloads/Compose" unless -r $C;
UI::KeyboardLayout::->set__value('ComposeFiles', [$C]) if -r $C;
warn "No Compose file found" unless UI::KeyboardLayout::->get__value('ComposeFiles');

UI::KeyboardLayout::->set__value('EntityFiles', ["$home/Downloads/bycodes.html"]) if -r "$home/Downloads/bycodes.html";
warn "No Entity file found" unless UI::KeyboardLayout::->get__value('EntityFiles');	# http://www.w3.org/TR/xml-entity-names/bycodes.html

UI::KeyboardLayout::->set__value('rfc1345Files', ["$home/Downloads/rfc1345.html"]) if -r "$home/Downloads/rfc1345.html";
warn "No rfc1345 file found" unless UI::KeyboardLayout::->get__value('rfc1345Files');	# http://tools.ietf.org/html/rfc1345  

die "Usage: $0 KBDD_FILE\n" unless @ARGV == 1;
#  After running this, run build_here.cmd in a subdirectory...  (Minimal build instructions are in the file...)

my $l = UI::KeyboardLayout::->new_from_configfile(shift);

my $skip_dummy = -e 'dummy';
for my $kbd ([qw(ooo-us Latin)], [qw(ooo-ru CyrillicPhonetic)], [qw(ooo-gr GreekPoly)], [qw(ooo-hb Hebrew)]) {
  open my $kbdd, '>', $kbd->[0] or die;
  select $kbdd;
  print $l->fill_win_template(1, ['faces', $kbd->[1]]);
  $l->print_coverage($kbd->[1]);
  # print "### RX_comb: <<<", $l->rxCombining, ">>>\n";
  close $kbdd or die;

  next if $skip_dummy;
  mkdir $_ for 'dummy', 'dummy2';
  my $idx = $l->get_deep($l, 'faces', $kbd->[1], 'MetaData_Index');
  my $n = $l->get_deep_via_parents($l, $idx, 'faces', $kbd->[1], 'DLLNAME');	# MSKLC would ignore the name otherwise???

  for my $dummy ('', '2') {
    open $kbdd, '> :raw:encoding(UTF-16LE):crlf', "dummy$dummy/$n.klc" or die;	# must force LE!  crlf is a complete mess!
    select $kbdd;
    print chr 0xfeff;							# Add BOM manually
    print $l->fill_win_template(1, ['faces', $kbd->[1]], 'dummy', $dummy);
    close $kbdd or die;
  }
}

select STDOUT;
open STDOUT, q(>), q(coverage-1prefix-Latin.html); 
$l->print_table_coverage(q(Latin),		'html');
open STDOUT, q(>), q(coverage-1prefix-Cyrillic.html);
$l->print_table_coverage(q(CyrillicPhonetic),	'html');
open STDOUT, q(>), q(coverage-1prefix-Greek.html); 
$l->print_table_coverage(q(GreekPoly),		'html');
open STDOUT, q(>), q(coverage-1prefix-Hebrew.html); 
$l->print_table_coverage(q(Hebrew),		'html');

unless (-e 'izKeys-visual-maps-base.html') {
  require File::Copy;
  File::Copy::copy('UI-KeyboardLayout/examples/izkeys-visual-maps-base.html', 'izKeys-visual-maps-base.html');
}

open F, '<', 'izKeys-visual-maps-base.html' or die "Can't open izKeys-visual-maps-base.html for read";
my $html = do {local $/; <F>};
close F or die "Can't close izKeys-visual-maps-base.html for read";

open STDOUT, q(>), q(izKeys-visual-maps-out.html); 
print $l->apply_filter_div($l->apply_filter_style($html));
open STDOUT, q(>), q(izKeys-visual-maps-fake.html); 
print $l->apply_filter_div($l->apply_filter_style($html, {fake => 1}), {fake => 1});

open F, '<', 'logo-base.html' or die "Can't open logo-base.html for read";
$html = do {local $/; <F>};
close F or die "Can't close logo-base.html for read";

open STDOUT, q(>), q(logo-out.html); 
print $l->apply_filter_div($l->apply_filter_style($html));
open STDOUT, q(>), q(logo-fake.html); 
print $l->apply_filter_div($l->apply_filter_style($html, {fake => 1}), {fake => 1});
