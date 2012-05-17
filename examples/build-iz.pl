use UI::KeyboardLayout; 
use strict;
UI::KeyboardLayout::->set_NamesList(q(C:\Users\ilya\Downloads\NamesList.txt), 
				    q(C:\Users\ilya\Downloads\DerivedAge.txt)); 
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
$l->print_table_coverage(q(Latin),1);
open STDOUT, q(>), q(coverage-1prefix-Cyrillic.html);
$l->print_table_coverage(q(CyrillicPhonetic),1);
