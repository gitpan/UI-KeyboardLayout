use UI::KeyboardLayout;
use strict;
my $home = $ENV{HOME} || '';
$home = "$ENV{HOMEDRIVE}$ENV{HOMEPATH}" if $ENV{HOMEDRIVE} and $ENV{HOMEPATH};
UI::KeyboardLayout::->set_NamesList(qq($home/Downloads/NamesList.txt),
				    qq($home/Downloads/DerivedAge.txt))
  if -r qq($home/Downloads/NamesList.txt)
  and -r qq($home/Downloads/DerivedAge.txt);
die "Usage: $0 KBDD_FILE\n" unless @ARGV == 1;
my $l = UI::KeyboardLayout::->new_from_configfile(shift);

open my $kbdd, '>', 'ooo-us' or die;
select $kbdd;
print $l->fill_win_template(1,[qw(faces Latin)]);
$l->print_coverage(q(Latin));
close $kbdd or die;

open my $kbdd1, '>', 'ooo-ru' or die;
select $kbdd1;
print $l->fill_win_template(1,[qw(faces CyrillicPhonetic)]);
$l->print_coverage(q(CyrillicPhonetic));
close $kbdd1 or die;

select STDOUT;
open STDOUT, q(>), q(coverage-1prefix-Latin.html); 
$l->print_table_coverage(q(Latin),		'html');
open STDOUT, q(>), q(coverage-1prefix-Cyrillic.html);
$l->print_table_coverage(q(CyrillicPhonetic),	'html');

open F, '<', 'visual-base.html' or die "Can't open visual-base.html for read";
my $html = do {local $/; <F>};
close F or die "Can't close visual-base.html for read";

open STDOUT, q(>), q(visual-out.html); 
print $l->apply_filter_div($l->apply_filter_style($html));
open STDOUT, q(>), q(visual-out-fake.html); 
print $l->apply_filter_div($l->apply_filter_style($html, {fake => 1}), {fake => 1});
