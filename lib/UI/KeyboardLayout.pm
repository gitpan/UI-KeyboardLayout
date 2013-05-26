package UI::KeyboardLayout;

$VERSION = $VERSION ="0.14";

binmode $DB::OUT, ':utf8' if $DB::OUT;		# (older) Perls had "Wide char in Print" in debugger otherwise
binmode $DB::LINEINFO, ':utf8' if $DB::LINEINFO;		# (older) Perls had "Wide char in Print" in debugger otherwise

use strict;
use utf8;
BEGIN { my $n = ($ENV{UI_KEYBOARDLAYOUT_DEBUG} || 0); 
	if ($n =~ /^0x/i) {
	  $n = hex $n;
	} else {
	  $n += 0;
	}
	eval "sub debug() { $n }";
	#		1			2			4		8		0x10	0x20
	my @dbg = (qw( debug_face_layout_recipes debug_GUESS_MASSAGE debug_OPERATOR debug_import debug_stacking debug_noid ),
	#		0x40			0x80		0x100	0x200		0x400		0x800		0x1000
		   qw(warnSORTEDLISTS printSORTEDLISTS warnSORTCOMPOSE warnDO_COMPOSE warnCACHECOMP dontCOMPOSE_CACHE warnUNRES),
	#		0x2000
		   qw(debug_STACKING),
		   '_debug_PERL_dollar1_scoping');
	my $c = 0;		# printSORTEDLISTS: Dumpvalue to STDOUT (implementation detail!)
	my @dbg_b = map $n & (1<<$_), 0..31;
	for (@dbg) {
	  eval "sub $_ () {$dbg_b[$c++]}";
	}
}
sub debug_PERL_dollar1_scoping ()		 { debug & 0x1000000 }

my $ctrl_after = 1;	# In "pairs of nonShift/Shift-columns" (1 simplifies output of BACK/ESCAPE/RETURN/CANCEL)
my $create_alpha_ctrl = 2;
my %start_SEC = (FKEYS => [96, 24, sub { my($self,$u,$v)=@_; 'F' . (1+$u-$v->[0]) }],
		 ARROWS => [128, 16,
		 	    sub { my($self,$u,$v)=@_;
		 	          (qw(HOME UP PRIOR DIVIDE LEFT CLEAR RIGHT MULTIPLY END DOWN NEXT SUBTRACT INSERT DELETE RETURN ADD))[$u-$v->[0]]}],
		 NUMPAD => [144, 16,
		 	    sub { my($self,$u,$v)=@_;
		 	          ((map { ($_ > 10 ? 'F' : "NUMPAD") . $_} 7..9,14,4..6,15,1..3,16,0), 'DECIMAL')[$u-$v->[0]]}]);

sub toU($) { substr+(qq(\x{fff}).shift),1 }	# Some bullshit one must do to make perl's Unicode 8-bit-aware (!)

#use subs qw(chr lc);
use subs qw(chr lc uc ucfirst);

#BEGIN { *CORE::GLOGAL::chr = sub ($) { toU CORE::chr shift };
#        *CORE::GLOGAL::lc  = sub ($)  { CORE::lc  toU shift };
#}
### Remove ß ẞ :
## my %fix = qw( ԥ Ԥ ԧ Ԧ ӏ Ӏ ɀ Ɀ ꙡ Ꙡ ꞑ Ꞑ  ꞧ Ꞧ  ɋ Ɋ  ꞩ Ꞩ  ȿ Ȿ  ꞓ Ꞓ  ꞥ Ꞥ );		# Perl 5.8.8 uc is wrong with palochka, 5.10 with z with swash tail
my %fix = qw( ԥ Ԥ ԧ Ԧ ӏ Ӏ ɀ Ɀ ꙡ Ꙡ ꞑ Ꞑ  ꞧ Ꞧ  ɋ Ɋ  ß ẞ  ꞩ Ꞩ  ȿ Ȿ  ꞓ Ꞓ  ꞥ Ꞥ );		# Perl 5.8.8 uc is wrong with palochka, 5.10 with z with swash tail
my %unfix = reverse %fix;

sub chr($)  { local $^W = 0; toU CORE::chr shift }	# Avoid illegal character 0xfffe etc warnings...
sub lc($)   { my $in = shift; $unfix{$in} || CORE::lc toU $in }
sub uc($)   { my $in = shift;   $fix{$in} || CORE::uc toU $in }
sub ucfirst($)   { my $in = shift;   $fix{$in} || CORE::ucfirst toU $in }

# We use this for printing, not for reading (so we can use //o AFTER the UCD is read)
my $rxCombining = qr/\p{NonspacingMark}/;	# The initial version matches what Perl knows

sub rxCombining { $rxCombining }

=pod

=encoding UTF-8

=head1 NAME

UI::KeyboardLayout - Module for designing keyboard layouts

=head1 SYNOPSIS

  #!/usr/bin/perl -wC31
  use UI::KeyboardLayout; 
  use strict;

  # Download from http://www.unicode.org/Public/UNIDATA/
  UI::KeyboardLayout::->set_NamesList("$ENV{HOME}/Downloads/NamesList.txt"); 
  
  my $i = do {local $/; open $in, '<', 'MultiUni.kbdd' or die; <$in>}; 
  # Init from in-memory copy of the configfile
  my $k = UI::KeyboardLayout:: -> new_from_configfile($i)
             -> fill_win_template( 1, [qw(faces CyrillicPhonetic)] ); 
  print $k;
  
  open my $f, '<', "$ENV{HOME}/Downloads/NamesList.txt" or die;
  my $k = UI::KeyboardLayout::->new();
  my ($d,$c,$names,$blocks,$extraComb,$uniVersion) = $k->parse_NameList($f);
  close $f or die;
  $k->print_decompositions($d);
  $k->print_compositions  ($c);
  
  UI::KeyboardLayout::->set_NamesList("$ENV{HOME}/Downloads/NamesList.txt", 
  				      "$ENV{HOME}/Downloads/DerivedAge.txt"); 
  my $l = UI::KeyboardLayout::->new(); 
  $l->print_compositions; 
  $l->print_decompositions;

  UI::KeyboardLayout::->set_NamesList("$ENV{HOME}/Downloads/NamesList-6.1.0d8.txt", 
  				      "$ENV{HOME}/Downloads/DerivedAge-6.1.0d13.txt"));
  my $l = UI::KeyboardLayout::->new_from_configfile('examples/EurKey++.kbdd');
  for my $F (qw(US CyrillicPhonetic)) {		
  	# Open file, select() 
    print $l->fill_win_template(1,[qw(faces US)]);
    $l->print_coverage(q(US));
  }

  perl -wC31 UI-KeyboardLayout\examples\grep_nameslist.pl "\b(ALPHA|BETA|GAMMA|DELTA|EPSILON|ZETA|ETA|THETA|IOTA|KAPPA|LAMDA|MU|NU|XI|OMICRON|PI|RHO|SIGMA|TAU|UPSILON|PHI|CHI|PSI|OMEGA)\b" ~/Downloads/NamesList.txt >out-greek

=head1 AUTHORS

Ilya Zakharevich, ilyaz@cpan.org

=head1 DESCRIPTION

In this section, a "keyboard" has a certain "character repertoir" (which characters may be
entered using this keyboard), and a mapping associating a character in the repertoir
to a keypress or to several (sequential or simultaneous) keypresses.  A small enough keyboard
may have a pretty arbitrary mapping and remain useful (witness QUERTY
vs Dvorak vs Colemac).  However, if a keyboard has a sufficiently large repertoir,
there must be a strong logic ("orthogonality") in this association - otherwise
the most part of the repertoir will not be useful (except for people who have an
extraordinary memory - and are ready to invest part of it into the keyboard).

"Character repertoir" needs of different people vary enormously; observing
the people around me, I get a very narrow point of view.  But it is the best
I can do; what I observe is that many of them would use 1000-2000 characters
if they had a simple way to enter them; and the needs of different people do 
not match a lot.  So to be helpful to different people, a keyboard should have 
at least 2000-3000 different characters in the repertoir.  (Some ballpark
comparisons: L<MES-3B|http://web.archive.org/web/20000815100817/http://www.egt.ie/standards/iso10646/pdf/cwa13873.pdf> 
has about 2800 characters; L<Adobe Glyph list|http://en.wikipedia.org/wiki/Adobe_Glyph_List> corresponds 
to about 3600 Unicode characters.)

To access these characters, how much structure one needs to carry in memory?  One can
make a (trivial) estimate from below: on Windows, the standard US keyboard allows 
entering 100 - or 104 - characters (94 ASCII keys, SPACE, ENTER, TAB - moreover, C-ENTER, 
BACKSPACE and C-BACKSPACE also produce characters; so do C-[, C-] and C-\
C-Break in most layouts!).  If one needs about 30 times more, one could do
with 5 different ways to "mogrify" a character; if these mogrifications 
are "orthogonal", then there are 2^5 = 32 ways of combining them, and
one could access 32*104 = 3328 characters.

Of course, the characters in a "reasonable repertoir" form a very amorphous
mass; there is no way to introduce a structure like that which is "natural"
(so there is a hope for "ordinary people" to keep it in memory).  So the
complexity of these mogrification is not in their number, but in their
"nature".  One may try to decrease this complexity by having very easy to
understand mogrifications - but then there is no hope in having 5 of them
- or 10, or 15, or 20.

However, we B<know> that many people I<are> able to memorise the layout of 
70 symbols on a keyboard.  So would they be able to handle, for example, 30 
different "natural" mogrifications?  And how large a repertoir of characters
one would be able to access using these mogrifications?

This module does not answer these questions directly, but it provides tools
for investigating them, and tools to construct the actually working keyboard
layouts based on these ideas.  It consists of the following principal
components:

=over 4

=item Unicode table examiner

distills relations between different Unicode characters from the Unicode tables,
and combines the results with user-specified "manual mogrification" rules.
From these automatic/manual mogrifications, it constructs orthogonal scaffolding 
supporting Unicode characters (we call it I<composition/decomposition>, but it
is a major generalization of the corresponding Unicode consortium's terms).

=item Layout constructor

allows building keyboard layouts based on the above mogrification rules, and
on other visual and/or logical directives.  It combines the bulk-handling
ability of automatic rule-based approach with a flexibility provided by 
a system of manual overrides.   (The rules are read from a F<.kbdd> L<I<Keyboard
Description> file|/"Keyboard description files">.

=item System-specific software layouts

may be created basing on the "theoretical layout" made by the layout constructor
(currently only on Windows, and only via F<KBDUTOOL> route).

=item Report/Debugging framework

creates human-readable descriptions of the layout, and/or debugging reports on
how the layout creation logic proceeded.

=back

The last (and, probably, the most important) component of the distribution is
L<an example keyboard layout|http://k.ilyaz.org/iz> created using this toolset.

=head1 Keyboard description files

=head2 Syntax

I could not find an appropriate existing configuration file format, so was
farced to invent yet-another-config-file-format.  Sorry...

Config file is for initialization of a tree implementing a hash of hashes of
hashes etc whole leaves are either strings or arrays of strings, and keys are
words.  The file consists of I<"sections">; each section fills a certain hash
in the tree.

Sections are separated by "section names" which are sequences of word
character and C</> (possibly empty) enclosed in square brackets.
C<[]> is a root hash, then C<[word]> is a hash reference by key C<word> in the
root hash, then C<[word/another]> is a hash referenced by element of the hash
referenced by C<[word]> etc.  Additionally, a section separator may look like
C<< [visual -> wordsAndSlashes] >>.

Sections are of two type: normal and visual.  A normal section
consists of comments (starting with C<#>) and assignments.  An assignment is
in one of 4 forms:

   word=value
   +word=value
   @word=value,value,value,value
   /word=value/value/value/value

The first assigns a string C<value> to the key C<word> in the hash of the
current section.  The second adds a value to an array referenced by the key
C<word>; the other two add several values.  Trailing whitespace is stripped.

Any string value without end-of-line characters and trailing whitespace
can be added this way (and values without commas or without slash can
be added in bulk to arrays).  In particular, there may be no whitespace before
C<=> sign, and the whitespace after C<=> is a part of the value.

Visual sections consist of comments, assignments, and C<content>, which
is I<the rest> of the section.  Comments
after the last assignment become parts of the content.  The content is
preserved as a whole, and assigned to the key C<unparsed_data>; trailing
whitespace is stripped.  (This is the way to insert a value containing
end-of-line-characters.)

In the context of this distribution, the intent of visual sections is to be
parsed by a postprocessor.  So the only purpose of explicit assignments in a
visual section is to configure how I<the rest> is parsed; after the parsing
is done (and the result is copied elsewhere in the tree) these values should
better be not used.

=head2 Semantic of visual sections

Two types of visual sections are supported: C<DEADKEYS> and C<KBD>.  A content of
C<DEADKEYS> section is just an embedded (part of) F<.klc> file.  We can read deadkey
mappings and deadkey names from such sections.  The name of the section becomes the
name of the mapping functions which may be used inside the C<Diacritic_*> rule
(or in a recipe for a computed layer).

A content of C<KBD> section consists of C<#>-comment lines and "the mapping 
lines"; every "mapping line" encodes one row in a keyboard (in one or several 
layouts).  (But the make up of rows of this keyboard may be purely imaginary; 
it is normal to have a "keyboard" with one row of numbers 0...9.)
Configuration settings specify how many lines are per row, and how many layers
are encoded by every line, and what are the names of these layers:

 visual_rowcount	# how many config lines per row of keyboard
 visual_per_row_counts 	# Array of length visual_rowcount
 visual_prefixes	# Array of chars; <= visual_rowcount (miss=SPACE)
 prefix_repeat		# How many times prefix char is repeated (n/a to SPACE)
 in_key_separator	# If several layers per row, splits a key-descr
 layer_names		# Where to put the resulting keys array
 in_key_separator2	# If one of entries is longer than 1 char, join by this 
 				# (optional)

Each line consists of a prefix (which is ignored except for sanity checking), and
whitespace-separated list of key descriptions.  (Whitespace followed by a
combining character is not separating.)  Each key description is split using
C<in_key_separator> into slots, one slot per layout.  (The leading 
C<in_key_separator> is not separating.)  Each key/layout
description consists of one or two entries.  An entry is either two dashes
C<--> (standing for empty), or a hex number of length >=4, or a string.
(A hex numbers must be separated by C<.> from neighbor word
characters.)  A loner character which has a different uppercase is
auto-replicated in uppercase (more precisely, titlecase) form.  Missing or empty key/layout description
gives two empty entries (note that the leading key/layout description cannot
be empty; same for "the whole key description" - use the leading C<-->.

If one of the entries in a slot is a string of length ≥ 2, one must separate 
the entries by C<in_key_separator2>.  Likewise, if a slot has only one entry,
and it is longer than 1 char, it must be started or terminated by C<in_key_separator2>.

To simplify BiDi keyboards, a line may optionally be prefixed with the L<C<LRO/RLO>|http://en.wikipedia.org/wiki/Unicode_character_property#Bidirectional_writing>
character; if so, it may optionally be ended by spaces and the L<C<PDF>|http://en.wikipedia.org/wiki/Unicode_character_property#Bidirectional_writing> character.
For compatibility with other components, layer names should not contain characters C<+()[]>.

=head2 Inclusion of F<.klc> files

Instead of including a F<.klc> file (or its part) verbatim in a visual
section, one can make a section C<DEADKEYS/NAME/name1/nm2> with
a key C<klc_filename>.  Filename will be included and parsed as a C<DEADKEYS>
visual section (with name C<DEADKEYS/name1/nm2>???).  (Currently only UTF-16
files are supported.)

=head2 Metadata

A metadata entry is either a string, or an array.  A string behaves as
if were an array with the string repeated sufficiently many times.  Each
personality defines C<MetaData_Index> which chooses the element of the arrays.
The entries

  COMPANYNAME LAYOUTNAME COPYR_YEARS LOCALE_NAME LOCALE_ID
  DLLNAME SORT_ORDER_ID_ LANGUAGE_NAME

should be defined in the personality section, or above this section in the
configuration tree.  (Used when output Windows F<.klc> files.)

Optional metadata currently consists only of C<VERSION> key (the protocol
version; hardwired now as C<1.0>).

=head2 Layer/Face/Prefix-key Recipes

The sections C<layer_recipes> and C<face_recipes> contain instructions how
to build Layers and Faces out of simpler elements.  Similar recipes appear  
as values of C<DeadKey_*> entries in a face.  Such a "recipe" is
executed with I<parameters>: a base face name, a layer number, and a prefix
character (the latter is undefined when the recipe is a layer recipe or
face recipe).  (The recipe is free to ignore the parameters; for example, most
recipes ignore the prefix character even when they are "prefix key" recipes.)

The recipes and the visual sections are the most important components of the description
of a keyboard group.

To construct layers of a face, a face recipe is executed several times with different 
"layer number" parameter.  In contrast, in simplest cases a layer recipe is executed
once.  However, when the layer is a part of a compound ("parent") recipe, it inherits 
the "parameters" from the parent.  In particular, it may be executed several times with
different face name (if used in different faces), or with different layer number (if used
- explicitly or explicitly - in different layer slots; for example, C<Mutator(LayerName)>
in a face/prefix-key recipe will execute the C<LayerName> recipe separately for all the
layer numbers; or one can use C<Layers(Empty+LayerName)> together with
C<Layers(LayerName+Other)>).  Depending on the recipe, these calls may result in the same layout 
of the resulting layers, or in different layouts.

A recipe may be of three kinds: it is either a "first comer wins" which is a space-separated collection of
simpler recipes, or C<SELECTOR(COMPONENTS)>, or a "mutator": C<MUTATOR(BASE)> or just C<MUTATOR>.
All recipes must be C<()>-balanced
and C<[]>-balanced; so must be the C<MUTATOR>; in turn, the C<BASE> is either a 
layer name, or another recipe.  A layer name must be defined either in a visual C<KBD> section,
or be a key in the C<layer_recipes> section (so it should not have C<+()[]> characters),
or be the literal C<Empty>.
When C<MUTATOR(BASE)> is processed, first, the resulting layer(s) of the C<BASE> recipe 
are calculated; then the layer(s) are processed by the C<MUTATOR> (one key at a time).

The most important C<SELECTOR> keywords are C<Face> (with argument a face name, defined either
via a C<faces/FACENAME> section, or via C<face_recipes>) and C<Layers> (with argument
of the form C<LAYER_NAME+LAYER_NAME+...>, with layer names defined as above).  Both
select the layer (out of a face, or out of a list) with number equal to the "layer number parameter" in the context
of the recipe.  The C<FlipLayers> builder is similar to C<Face>, but chooses the "other" 
layer ("cyclically the next" layer if more than 2 are present).

The other selectors are C<Self>, C<LinkFace> and C<FlipLayersLinkFace>; they
operate on the base face or face associated to the base face.

The simplest forms of C<MUTATORS> are C<Id, lc, uc, ucfirst, Empty> (note that
C<uc>/C<lc>/C<ucfirst> return C<undefined> when case-conversion results in no
change; use C<maybe_uc>/C<maybe_lc>/C<maybe_ucfirst> if one wants them to behave
as Perl operators).  Recall that a layer
is nothing more than a structure associating a pair "unshifted/shifted character" to the key number, and that
these characters may be undefined.  These simplest mutators modify these characters
independently of their key numbers and shift state (with C<Empty> making all of
them undefined).  Similar user-defined simple mutators are C<ByPairs[PAIRS]>;
here C<PAIRS> consists of pairs "FROM TO" of characters (with optional spaces between pairs);
characters not appearing as FROM become undefined by C<ByPairs>.
(As usual, characters may be replaced by hex numbers with 4 or more hex digits;
separate the number from a neighboring word character by C<.> [dot].)

All mutators must have a form C<WORD> or C<WORD[PARAMETERS]>, with C<PARAMETERS>
C<(),[]>-balanced.  Other simple mutators are C<dectrl> (converts
control-char [those between 0x00 and 0x1f] to the corresponding [uppercase] character), 
C<ShiftFromTo[FROM,TO]> (adds a constant to the [numerical code of the] input character
so that C<FROM> becomes C<TO>), C<SelectRX[PERL_REGEXP]> (keeps input characters
which match, converts everything else to C<undefined>), C<FromTo[LAYER_FROM,LAYER_TO]>
(similar to C<ByPairs>, but pairs all characters in the layers based on their position),
C<DefinedTo[CHAR]> (all defined characters are converted to C<CHAR>).

The mutator C<Imported[NAME]> is similar to <ByPairs>, but takes the F<.klc>-style
visual C<DEADKEYS/NAME> section as the description of the mutation.  C<NAME> may
be followed by a character as in C<NAME,CHAR>; if not, C<CHAR> is the prefix key from
the recipe's execution parameters.

The simple mutator C<ByPairs> has flavors: one can append C<Prefix> or C<InvPrefix>
to the name, and the resulting characters become prefix keys (the “C<AltGr>-inverted”
prefix followed by C<CHAR> behaves as non-inverted prefix followed by C<AltGr-CHAR>).

Some mutators pay attention not only to what the character is, but how it is 
accessible on the given key: such are C<FlipShift>, C<FlipLayers>, 
C<FromToFlipShift[LAYER_FROM,LAYER_TO]>.  Some other mutators also take into
account how the key is positioned with respect to the other keys.

C<ByColumns[CHARS]> assigns a character
to a particular column of the keyboard.  Which keys are in which columns is 
governed by how the corresponding
visual layer is formatted (shifted to the right by C<keyline_offsets> array of the
visual layer).  This visual layer is one associated to the face by the
C<geometry_via_layer> key (and the face is the parameter face of the
mutator).  C<CHARS> is a comma-separated list;
empty positions map to the undefined character.

C<ByRows[MUTATORS]> chooses a mutator based on the row of the keyboard.  On the top row,
it is the first mutator which is chosen, etc. The list C<MUTATORS> is separated by C<///> 
surrounded by whitespace.

The mutator C<InheritPrefixKeys[FACE_FROM]> converts some non-prefix characters to prefix
characters; the conversion happens if the argument of the mutator coincides with 
what is at the corresponding position in C<FACE_FROM>, and this position contains
a prefix character.  (Nowadays this mutator is not very handy — most of its uses 
may be accomplished by having I<inheritable> prefix characters in appropriate faces.)

The mutators C<NotId(BASEFACE FACES)>, C<NotSameKey(BASEFACE FACES)> process their 
argument in a special way: the characters in C<FACES> which duplicated the characters 
present (on the same key, and possibly with the same modifiers) in C<BASEFACE> are
ignored.  The remaining characters are combined “as usual” with “the first comer wins”.

The most important mutator is C<Mutate> (and its flavors).  (See L<The C<Mutate[RULES]> mutator>.)

Note that C<Id(LAYERNAME)> is similar to a selector;
it is the only way to insert a
layer without a selector, since a bareword is interpreted as a C<MUTATOR>; C<Id(LAYERNAME)> is a synonym
of C<Layers(LAYERNAME+LAYERNAME+...)> (repeated as many times as there are layers
in the parameter "base face").


The recipes in a space-separated list of recipes ("first comer wins") are 
interpreted independently to give a collection of layers to combine; then,
for every key numbers and both shift states, one takes the leftmost recipe 
which produces a defined character for this position, and the result is put 
into the resulting layer.

Keep in mind that to understand what a recipe does, one should trace 
its description right-to-left order: for example, C<ByPairs[.:](FlipLayers)> creates
a layout where C<:> is at position of C<.>, but on the second [=other] layer (essentially,
if the base layout is the standard one, it binds the character C<:> to the keypress C<AltGr-.>).

To simplify formatting of F<.kbdd> files, a recipe may be an array reference.
The string may be split on spaces, or split after comma or C<|>.

=head2 The C<Mutate[RULES]> mutator

The essense of C<Mutate> is to have several mutation rules and choose I<the best>
of the results of application of these rules.  Grouping the rules allows
one a flexible way to control what I<the best> actually means.  The rules may
be separated by comma, by C<|>, or by C<|||> (interchangeable with C<||||>).

In the simplest case of grouping, C<RULES> form a C<|>-separated list, and
each group consists of one rule.  Then I<the best> result is one coming from
an earlier rule.  The groups are separated by C<|>, and the rules inside the
group are separated by comma; if more than one rule appears in a group, a
different kind of competition appears (inside the group).  

The I<quality> of the generated characters is a list C<UNICODE_AGE, HONEST, 
UNICODE_BLOCK, IN_CASE_PAIR, FROM_NON_ALTGR_POSITION>
with lexicographical order (the earlier element is stronger that ones after it).
Here C<HONEST> describes whether a character is generated by
Unicode compositing (versus “compatibility compositing” or other
“artificially generated” mogrifiers); the older age wins, as well as
honest compositing, earlier Unicode blocks, as well as case pairs and
characters from non-C<AltGr>-positions.  (Experience shows that these rules
have a pretty good correlation with being “more suitable for human consumption”.)

Moreover, quality in case-pairs is equalized by assigning the strongest 
I<quality> of two.  Such pairs are always considered “tied together” when
they compete with other characters.  (In particular, if a single character
with higher quality occupies one of C<Shifted/Unshifted> positions, a
case pair with lower quality is completely ignored; so the “other” position 
may be taken by a single character with yet lower quality.)

In addition, the characters which lost the competition for
non-C<AltGr>-positions are considered I<again> on C<AltGr>-positions.  (With
boosted priority compared to mutated C<AltGr>-characters; see above.)

This mutator comes in several flavors: one can append to its name
C<SpaceOK>/C<Hack>/C<DupsOK>/C<32OK> (in this
order).  Unless C<SpaceOK> is specified, it will not modify characters on a key
which produces C<SPACE> when used without modifiers.  Unless C<32OK> is specified, it
will not produce Unicode characters after C<0xFFFF> (the default is to follow
the brain-damaged semantic of prefix keys on Windows).  Unless C<DupsOK> is
specified, the result is optimized by removing duplicates (per key) generated
by application of C<RULES>.  With the C<Hack> modifier, the generated characters
are not counted as “obtained by logical rules” when statistics for the generated
keyboard layout are calculated.

=head2 Linked prefixes

On top of what is explained above, there is a way to arrange “linking” of two prefix keys;
this linking allows characters which cannot be fit on one (prefixed) key to
“migrate” to unassigned positions on the otherwise-prefixed key.  (This is
similar to migration from non-C<AltGr>-position to C<AltGr>-position.)
This is achieved by using mutator rules of the following form:

  primary	= 		+PRE-GROUPS1|||SHARED||||POST-GROUPS1
  secondary	= PRE-GROUPS2||||PRE-GROUPS1|||SHARED||||POST-GROUPS2

Groups with digits are not shared (specific to a particular prefix); C<SHARED> is
(effectively) reverted when accessed from the secondary prefix; for the
secondary key, the recipies from C<SHARED> which were used in the primary 
key are removed from C<SHARED>, and are appended to the end of C<POST-GROUPS2>;
the C<PRE-GROUPS1> are skipped when finding assignments for the secondary
prefix.

In the primary recipe, C<|||> and C<||||> are interchangeable with C<|>.
Moreover, if C<POST-GROUPS2> is empty, the secondary recipe should be written as

  secondary	= PRE-GROUPS2|||PRE-GROUPS1|||SHARED

if C<PRE-GROUPS1> is empty, this should be written as one of

  secondary	= PRE-GROUPS2|||SHARED
  secondary	= PRE-GROUPS2||||SHARED
  secondary	= PRE-GROUPS2||||SHARED||||POST-GROUPS2

These rules are to allow macro-ization of the common parts of the primary
and secondary recipe.  Put the common parts as a value of the key
C<Named_DIA_Recipe__***> (here C<***> denotes a word), and replace them by
the macro C<< <NAMED-***> >> in the recipes.

B<Implementation>: the primary key recipe starts with the C<+> character; it
forces interpretation of C<|||> and C<||||> as of ordinary C<|>.

If not I<primary>, the top-level groups are formed by C<||||> (if present), otherwise by C<|||>. 
The number of top-level groups should be at most 3.  The second of C<||||>-groups
may have at most 2 C<|||>-groups; there should be no other subdivision.  This way,
there may be up to 4 groups with different roles.

The second of 3 toplevel C<|||>-groups, or the first of two sublevel C<|||>-groups
is the “skip” group.  The last of two or three toplevel C<|||>-groups (or of 
sublevel C<|||>-groups, or the 2nd toplevel C<||||>-group without subdivisions) is the 
inverted group; the 3rd of toplevel C<||||>-groups is the “extra” group.

“Penalize/prohibit” lists start anew in every top-level group.

=head2 Atomic mutators rules

As explained above, the individual RULES in C<Mutate[RULES]> may be
separated by C<,> or C<|>, or C<|||> or C<||||>.  Such an individual
rule is a combination of I<atomic rules> combined by C<+> operators,
and/or preceded by C<-> prefix (with understanding that C<+-> must
be replaced by C<-->).  The prefix C<-> means I<inversion> of the
rule; the operator C<+> is the composition of the rules.

B<Example:> the atomic rule C<< <super> >> converts its input character into
its superscript forms (if such forms exist; for example, C<a> may
be converted to C<ᵃ> or C<ª>).  The atomic rules C<lc>, C<uc>, C<ucfirst>
behave the same as the corresponding MUTATORs.   The atomic rule C<dectrl>
converts a control-character to the corresponding “uppercase” character:
C<^A> is converted to C<A>, and C<^\> is converted to C<\>.  (The last
4 rules cannot be inverted by C<->.)

The composition is performed (as usual) from right to left.  B<Example:> the
indivial rule C<< <super>+lc+dectrl >> converts C<^A> to C<ᵃ> or C<ª>.

In addition to rules listed above, the atomic rules may be of the
following types:

=over

=item *

A hex number with ≥4 digits, or a character: implements the composition
inverting (compatibility or not) Unicode decompositions into two characters;
the character in the rule must the first character of the decomposition.
Here “Unicode decompositions” are either deduced from Unicode decomposition
rules (with compatibility decompositions having lower priority), or deduced
basing on splitting the name of the character into parts.

=item *

C<< <pseudo-upgrade> >> is an inversion of a Unicode decomposition which goes from
1 character to 1 character.

=item *

Flavors of characters C<< <FLAVOR> >> from Unicode tables come from Unicode 
1-character to 1-character decompositions
marked with C<< <FLAVOR> >>.  B<Example:> C<< <sub> >> for a subscript form;
or C<< <final> >>.

=item *

C<< <font=***> >> rules TBC ..........................................

=item *

Calculated rules C<< <pseudo-calculated-***> >> are extracted by a 
heuristic algorithm which tries to parse the Unicode name of the character.

For the best understanding of what these rules produce, inspect
results of print_compositions(), print_decompositions() methods documented
in L<"SYNOPSIS">.  The following “keywords” are processed by the algorithm:

  WITH, OVER, ABOVE, PRECEDED BY, BELOW (only with LONG DASH)

are separators;
  
  COMBINING CYRILLIC LETTER, BARRED, SLANTED, APPROXIMATELY, ASYMPTOTICALLY, 
  SMALL (not near LETTER), ALMOST, SQUARED, BIG, N-ARY, LARGE, LUNATE,
  SIDEWAYS DIAERESIZED, SIDEWAYS OPEN, INVERTED, ARCHAIC, EPIGRAPHIC,
  SCRIPT, LONG, MATHEMATICAL, AFRICAN, INSULAR, VISIGOTHIC, MIDDLE-WELSH,
  BROKEN, TURNED, INSULAR, SANS-SERIF, REVERSED, OPEN, CLOSED, DOTLESS, TAILLESS, FINAL
  BAR, SYMBOL, OPERATOR, SIGN, ROTUNDA, LONGA, IN TRIANGLE, SMALL CAPITAL (as smallcaps)

are modifiers.  For an C<APL FUNCTIONAL SYMBOL>, one scans for

  QUAD, UNDERBAR, TILDE, DIAERESIS, VANE, STILE, JOT, OVERBAR, BAR

TBC ..........................................

=item *

Additionally, C<esh/eng/ezh> are considered C<pseudo-phonetized> variants of
their middle letter, as well as C<SCHWA> of C<0>.

=item *

C<< <pseudo-fake-***> >> rules are obtained by scanning the name for

  WHITE, BLACK, CIRCLED, BUT NOT 

as well as for C<UM> (as C<umify>), paleo-Latin digraphs and C<CON/VEND> 
(as C<paleocontraction-by-last>), doubled-letters
(as C<doubleletter>), C<MIDDLE-WELSH> doubled-letters
as (C<doubleletter-middle-welsh>).

=item *

Manual prearranged rules TBC ..........................................

=item *

C<< <subst-***> >> Explicit named substitution rules TBC ..........................................

=item *

C<< <reveal-substkeys> >> Prohibits handling non-substituted input TBC ..........................................

=item *

C<< <any-***> >> rules TBC ..........................................

=back

=head2 Input substitution in atomic rules

TBC ..........................................

=head2 The C<Mutate2Self> mutator

TBC ..............................

=head2 Pseudo-mutators for generation of documentation

A few mutators do not introduce any characters (in other words, they behave as 
C<Empty>) but are used for their side effects: in prefix-key recipes, 
C<PrefixDocs[STRING]> introduces documentation of what the prefix key is intended
for.  Likewise, C<HTML_classes[HOW]> allows adding CSS classes to highlight 
parts of HTML output generated by this module, the parts corresponding to selected
characters in a face.

C<HOW> is a comma-separated list, every triple in the
list being C<WHERE,HTML_CLASS,CHARACTERS>.  C<WHERE> is one of C<k>/C<K> (which
add formatting to the key containing one of the C<CHARACTERS>) or C<c>/C<C>
(which add formatting to an individual character displayed on the key),
one can add a digit to C<WHERE> to limit to a particular layer in the face
(useful when a character appears several times in a face).
The lower-case variants select characters basing on the I<base face> of a key.
One can also append C<=CONTEXT> to C<WHERE>, then the class is added only if
C<CONTEXT> appears as one of the options for the HTML output generator.

The CSS rules generated by this module support several classes directly; the
rest should be supported by the user-supplied rules.  The classes with existing
support are: on keys

  to_w from_w				# generate arrows between keys
  from_nw from_ne to_nw to_ne		# generate arrows between keys; will yellow-outline
  pure					# 	unless combined with this
  red-bg green-bg blue-bg		# tint the key as the whole (as background)

On characters

  very-special need-learn may-guess	# provide green/brown/yellow-outlines
  special				# provide blue outline (thick unless combined with 
  thinspecial				#                   <-- this)

=head2 Extra CSS classes for documentation

In additional, several CSS classes are auto-generated basing on Unicode
properties of the character.  TBC ........................

=head2 Debugging mutators

If the bit 0x40 of the environment variable C<UI_KEYBOARDLAYOUT_DEBUG> 
(decimal or C<0xHEX>) is set, debugging output for mutators is enabled:

  r ║ ║   ┆ ║ ṙ ṛ ┆ ║ ║ ║ ║ ⓡ ┆
    ║ ║   ┆ ║ Ṙ Ṛ ┆ ║ ║ ║ ║ Ⓡ ┆
    ║ ║ ặ ┆ ║     ┆ ║ ║ ║ ║   ┆
    ║ ║ Ặ ┆ ║     ┆ ║ ║ ║ ║   ┆
  Extracted [ …list… ] deadKey=00b0

The output contains a line per character assigned to the keyboard key (if 
there are 2 layers, each with lc/uc variants, there are 4 lines); empty lines are 
omitted.  The first column indicates the base character (lc of the 1st layer) of 
the key; the separator C<║> indicates C<|>-groups in the mutator.  Above, the first
group produces no mutations, the second group mutates only the characters in
the second layer, and the third group produces two mutations per a character in
the first layer.  The 7th group is also producing mogrifications on the 1st layer.

The next example clarifies C<┆>-separator: to the left of it are mogrifications which 
come in case pairs, to the right are mogrifications where mogrified-lc is not
a case pair of mogrified-uc:

  t ║ ║ ᵵ ║ ꞇ ┆ ʇ ║   ┆ ║
    ║ ║   ║ Ꞇ ┆ ᴛ ║   ┆ ║
    ║ ║   ║   ┆   ║ ꝧ ┆ ║
    ║ ║   ║   ┆   ║ Ꝧ ┆ ║
  Extracted [ …list… ] deadKey=02dc

In this one, C<│> separates mogrifications with different priorities (based on
Unicode ages, whether the atomic mutator was compatibility/synthetic one, and the
Unicode block).

  / ║ ║ ║ ║ ║   │ ∴   ║ ║
    ║ ║ ║ ║ ║   │ ≘ ≗ ║ ║
    ║ ║ ║ ║ ║ / │ ⊘   ║ ║
  Extracted [ …list… ] deadKey=00b0

For secondary mogrifiers, where the distinction between C<|||> and C<|> 
matters, some of the C<║>-separators are replaced by C<┃>.  Additionally,
there are two rounds of extraction: first the characters corresponding
to the primary mogrifier are TMP-extracted (from the groups PRE-GROUPS1, 
COMMON); then what is the extracted from COMMON is put back at the 
effective end (at the end of POST-GROUPS2, or, if no such, at 
the beginning of COMMON):

  t ║ ║ ᵵ ┃ ┃ ʇ │   │ ꞇ ┆ ║
    ║ ║   ┃ ┃   │ ᴛ │ Ꞇ ┆ ║
    ║ ║   ┃ ┃   │   │ ꝧ ┆ ║
    ║ ║   ┃ ┃   │   │ Ꝧ ┆ ║
  TMP Extracted: <…list…> from layers 0 0 | 0 0
  t ║ ║ ᵵ ┃ ꞇ ┆ ʇ ┋ ┃ ┆ │ ┆ │   ┆ ║
    ║ ║   ┃ Ꞇ ┆ ᴛ ┋ ┃ ┆ │ ┆ │   ┆ ║
    ║ ║   ┃   ┆   ┋ ┃ ┆ │ ┆ │ ꝧ ┆ ║
    ║ ║   ┃   ┆   ┋ ┃ ┆ │ ┆ │ Ꝧ ┆ ║
  Extracted [ …list… ] deadKey=02dc

In the second part of the debugging output, the part of common which is put
back is separated by C<┋>.

When bit 0x80 is set, much more lower-level debugging info is printed.  The
arrays at separate depth mean: group number, priority, not-cased-pair, layer
number, subgroup, is-uc.  When bit 0x100 is set, the debugging output for
combining atomic mutators is enabled.

=head2 Personalities

A personality C<NAME> is defined in the section C<faces/NAME>.  (C<NAME> may
include slashes - untested???)

An array C<layers> gives the list of layers forming the face.  (As of version
0.03, only 2 layers are supported.)  The string C<LinkFace> is a face.........

=head2 Substitutions

In section C<Substitutions> one defines composition rules which may be
used on par with composition rules extracted from I<Unicode Character Database>.
An array C<FOO> is converted to a hash accessible as C<< <subst-FOO> >> from
a C<Diacritic> filter of satellite face processor.  An element of the the array
must consist of two characters (the first is mapped to the second one).  If
both characters have upper-case variants, the translation between these variants
is also included.

=head2 Classification of diacritics

The section C<Diacritics> contains arrays each describing a class of
diacritic marks.  Each array may contain up to 7 elements, each
consising of diacritic marks in the order of similarity to the
"principal" mark o fthe array.  Combining characters may be
preceded by horizontal space.  Elements should contain:

 Surrogate chars; 8bit chars; Modifiers
 Modifiers below (or above if base char is below)
 Vertical (or Comma-like or Doubled or Dotlike or Rotated or letter-like) Modifiers
 Prime-like or Centered modifiers
 Combining 
 Combining below (or above if base char is below)
 Vertical combining and dotlike Combining

These lists determine what a C<Diacritic2Self> filter of satellite face processor 
will produce when followed by whitespace characters 
(possibly with modifiers) C<SPACE ENTER TAB BACKSPACE>.  (So, if F<.kbdd> file
requires this) this determines what diacritic prefix keys produce.

=head1 Naming prefix keys

Section C<DEADKEYS> defines naming of prefix keys.  If not named there (or in
processed F<.klc> files), the Unicode name of the character will be used.

=head1 Keyboards: on ease of access

Let's start with trivialities: different people have different needs
with respect to keyboard layouts.  For a moment, ignore the question
of the repertoir of characters available via keyboard; then the most 
crucial distinction corresponds to a certain scale.  In absense of  
a better word, we use a provisional name "the required typing speed".

One example of people on the "quick" (or "rabid"?) pole of this scale are 
people who type a lot of text which is either "already prepared", or for 
which the "quality of prose" is not crucial.  Quite often, these people may
type in access of 100 words per minute.  For them, the most important
questions are of physical exhaustion from typing.  The position
of most frequent letters relative to the "rest" finger position, whether
frequently typed together letters are on different hands (or at least
not on the same/adjacent fingers), the distance fingers must travel
when typing common words, how many keypresses are needed to reach 
a letter/symbol which is not "on the face fo the keyboard" - their
primary concerns are of this kind.

On the other, "deliberate", pole these concerns cease to be crucial.
On this pole are people who type while they "create" the text, and
what takes most of their focus is this "creation" process.  They may
"polish their prose", or the text they write may be overburdened by
special symbols - anyway, what they concentrate on is not typing itself.

For them, the details of the keyboard layout are important mostly in
the relation to how much they I<distract> the writer from the other
things the writer is focused on.  The primary question is now not
"how easy it is to type this", but "how easy it is to I<recall> how
to type this".  The focus transfers from the mechanics of finger movements
to the psycho/neuro/science of memory.

These questions are again multifaceted: there are symbols one encounters
every minute; after you recall once how to access them, most probably
you won't need to recall them again - until you have a long interval when
you do not type.  The situation is quite different with symbols you need
once per week - most probably, each time you will need to call them again
and again.  If such rarely used symbols/letters are frequenct (since I<many>
of them appear), it is important to have an easy way to find how to type them;
on the other hand, probably there is very little need for this way to
be easily memorizable.  And for symbols which you need once per day, one needs
both an easy way to find how to type them, I<and> the way to type them should
better be easily memorizable.

Now add to this the fact that for different people (so: different usage
scenarios) this division into "all the time/every minute/every day/every week"
categories is going to be different.  And one should not forget important
scenario of going to vacation: when you return, you need to "reboot" your
typing skills from the dormant state.

On the other hand, note that the questions discussed above are more or less
orthogonal: if the logic of recollection requires ω to be related in some 
way to the W-key,
then it does not matter where the W-key is on the keyboard - the same logic
is applicable to the QWERTY base layoubt, or BÉPO one, or Colemak, or Dvorak.
This module concerns itself I<only> with the questions of "consistency" and
the related question of "the ease of recall"; we care only about which symbols
relate to which "base keys", and do not care about where the base key sit on
the physical keyboard.

B<NOTE:> the version 0.01 of this module supports only the standard US layout
of the base keys.

Now consider the question of the character repertoir: a person may need ways
to type "continuously" in several languages; in addition to this, there may
be a need to I<occasionally> type "standalone" characters or symbols outside
the repertoir of these languages.  Moreover, these languages may use different
scripts (such as Polish/Bulgarian/Greek/Arabic/Japanese), or may share a
"bulk" of their characters, and differ only in some "exceptional letters".
To add insult to injury, these "exceptional letters" may be rare in the language
(such as ÿ in French or à in Swedish) or may have a significant letter frequency 
(such as é in French) or be somewhere in between (such as ñ in Spanish).

And the non-language symbols do not need to be the I<math> symbols (although
often they are).  An Engish-language discussion of etimology at coffee table 
may lead to a need to write down a word in polytonic greek, or old norse;
next moment one would need to write a phonetic transcription in IPA/APA
symbols.  A discussion of keyboard layout may involve writing down symbols
for non-character keys of the keyboard.  A typography freak would optimize
a document by fine-tuned whitespaces.  Almost everybody needs arrows symbols,
and many people would use box drawing characters if they had a simple access
to them.

Essentially, this means that as far as it does not impacts other accessibility
goals, it makes sense to have unified memorizable access to as many
symbols/characters as possible.  (An example of impacting other aspects:
MicroSoft's (and IBM's) "US International" keyboards steal characters C<`~'^">:
typing them produces "unexpected results" - they are deadkeys.  This
significantly simplifies entering characters with accents, but makes it
harder to enter non-accented characters.)

One of the most known principles of design of human-machine interaction
is that "simple common tasks should be simple to perform, and complicated
tasks should be possible to perform".  I strongly disagree with this
principle - IMO, it lacks a very important component: "a gradual increase
in complexity".  When a certain way of doing things is easy to perform, and another 
similar way is still "possible to perform", but on a very elevated level 
of complexity, this leads to a significant psychological barrier erected
between these ways.  Even when switching from the first way to the other one 
has significant benefits, this barrier leads to self-censorship.  Essentially,
people will 
ignore the benefits even if they exceed the penalty of "the elevated level of 
complexity" mentioned above.  And IMO self-censorship is the worst type of 
censorship.  (There is a certain similarity between this situation and that
of "self-fulfilled prophesies".  "People won't want to do this, so I would not
make it simpler to do" - and now people do not want to do this...)

So I would add another clause to the law above: "and moderately complicated
tasks should remain moderately hard to perform".  What does it tell us in
the situation of keyboard layout?  One can separate several levels of
complexity.

=over 10

=item Basic:

There should be some "base keyboards": keyboard layouts used for continuous 
typing in a certain language or script.  Access from one base keyboard to
letters of another should be as simple as possible.

=item By parts:

If a symbol can be thought of as a combination of certain symbols accessible
on the base keyboard, one should be able to "compose" the symbol: enter it
by typing a certain "composition prefix" key then the combination (as far
as the combination is unambiguously associated to one symbol).

The "thoughts" above should be either obvious (as in "combining a and e should 
give æ") or governed by simple mneumonic rules; the rules should cover as
wide a range as possible (as in "Greek/Coptic/Hebrew/Russian letters are
combined as G/C/H/R and the corresponding Latin letter; the correspondence is 
phonetic, or, in presence of conflicts, visual").

=item Quick access:

As many non-basic letters as possible (of those expected to appear often)
should be available via shortcuts.  Same should be applicable to starting
sequences of composition rules (such as "instead of typing C<StartCompose>
and C<'> one can type C<AltGr-'>).

=item Smart access

Certain non-basic characters may be accessible by shortcuts which are not
based on composition rules.  However, these shortcuts should be deducible
by using simple mneumonic rules (such as "to get a vowel with `-accent,
type C<AltGr>-key with the physical keyboard's key sitting below the vowel key").

=item Superdeath:

If everything else fails, the user should be able to enter a character by
its Unicode number (preferably in the most frequently referenced format:
hexadecimal).

=back

=over

B<NOTE:> This does not seem to be easily achievable, but it looks like a very nifty
UI: a certain HotKey is reserved (e.g., C<AltGr-AppMenu>);
when it is tapped, and a character-key is pressed (for example, B<B>) a
menu-driven interface pops up where user may navigate to different variants
of B, Beta, etc - each of variants with a hotkey to reach I<NOW>, and with
instructions how to reach it later from the keyboard without this UI.

Also: if a certain timeout passes after pressing the initial HotKey, an instruction
what to do next should appear.

=back

Here are the finer points elaborating on these levels of complexity:

=over 4

=item 1

It looks reasonable to allow "fuzzy mneumonic rules": the rules which specify
several possible variants where to look for the shortcut (up to 3-4 variants).
If/when one forgets the keying of the shortcut, but remembers such a rule,
a short experiment with these positions allows one to reconstruct the lost
memory.

=item

The "base keyboards" (those used for continuous typing in a certain language
or script) should be identical to some "standard" widely used keyboards.
These keyboards should differ from each other in position of keys used by the
scripts only; the "punctuation keys" should be in the same position.  If a
script B has more letters than a script A, then a lot of
"punctuation" on the layout A will be replaced by letters in the layout B.
This missing punctuation should be made available by pressing a modifier
(AltGr? compare with MicroSoft's Vietnamese keyboard's top row).

=item

If more than one base keyboard is used, there must be a quick access:
if one needs to enter one letter from layout B when the active layout is A, one
should not be forced to switch to B, type the letter, then switch back
to A.  It must be available on "C<Quick_Access_Key letter>".

=item

One should consider what the C<Quick_Access_Key> does when the layouts A
and B are identical on a particular key.  One can go with the "Occam's
razor" approach and make C<Quick_Access_Key> the do-nothing identity map.
Alternatively, one can make it access some symbols useful both for
script A and script B.  It is a judgement call.

Note that there is a gray area when layouts A and B are not identical,
but a key C<K> produces punctuation in layout A, and a letter in layout
B.  Then when in layout B, this punctuation is available on C<AltGr-key>,
so, in principle, C<Quick_Access_Key> would duplicate the functionality
of C<AltGr>.  Compare with "there is more than one way to do it" below;
remember that OS (or misbehaving applications) may make some keypresses
"unavailable".  I feel that in these situations, having duplication is
a significant advantage over "having some extra symbols available".

=item

Paired symbols (such as such as ≤≥, «», ‹›, “”, ‘’ should be put on paired 
keyboard's keys: <> or [] or ().

=item

"Directional symbols" (such as arrows) should be put either on numeric keypad
or on a 3×3 subgrid on the letter-part of the keyboard (such as QWE/ASD/ZXC).
(Compare with [broken?] implementation in Neo2.)

=item

for symbols that are naturally thought of as sitting in a table, one can 
create intuitive mapping of quite large tables to the keyboard.  Split each
key in halves by a horizontal line, think of C<Shift-key> as sitting in the
top half.  Then ignoring C<`~> key and most of punctuation on the right
hand side, keyboard becomes an 8×10 grid.  Taking into account C<AltGr>,
one can map up to 8×10×2 (or, in some cases, 8×20!) table to a keyboard.

B<Example:> Think of IPA consonants.

=item

Cheatsheets are useful.  And there are people who are ready to dedicate a
piece of their memory to where on a layout is a particularly useful to them
symbol.  So even if there is no logical position for a certain symbol, but
there is an empty slot on layout, one should not hesitate in using this slot.

However, this I<will be> distractive to people who do not want to dedicate
their memory to "special cases".  So it makes sense to have three kinds of
cheatsheets for layouts: one with special cases ignored (useful for most 
people), one with all general cases ignored (useful for checks "is this 
symbol available in some place I do not know about" and for memorization),
and one with all the bells and whistles.

=item

"There is more than one way to do it" is not a defect, it is an asset.
If it is a reasonable expectation to find a symbol X on keypress K', and
the same holds for keypress K'' I<and> they both do not conflict with other
"being intuitive" goals, go with both variants.  Same for 3 variants, 4
- now you get my point.

B<Example:> The standard Russian phonetic layout has Ё on the C<^>-key; on the
other hand, Ё is a variant of Е; so it makes sense to have Ё available on
C<AltGr-Е> as well.  Same for Ъ and Ь.

=item

Dead keys which are "abstract" (as opposed to being related to letters
engraved on physical keyboard) should better be put on modified state
of "zombie" keys of the keyboard (C<SPACE>, C<TAB>, C<CAPSLOCK>, C<MENU_ACCESS>).

B<NOTE:> Making C<Shift-Space> a prefix key may lead to usability issues
for people used to type CAPITALIZED PHRASES by keeping C<Shift> pressed
all the time.  As a minimum, the symbols accessed via C<Shift-SPACE key>
should be strikingly different from those produced by C<key> so that
such problems are noted ASAP.  Example: on the first sight, producing
C<NO-BREAK SPACE> on C<Shift-Space Shift-Space> or C<Shift-Space Space>
looks like a good idea.  Do not do this: the visually undistinguishable
C<NO-BREAK SPACE> would lead to significantly hard-to-debug problems if
it was unintentional.

=back


=head1 Explanation of keyboard layout terms used in the docs

The aim of this module is to make keyboard layout design as simple as 
possible.  It turns out that even very elaborate designs can be made
quickly and the process is not very error-prone.  It looks like certain
venues not tried before are now made possible; at least I'm not aware of 
other attempts in this direction.  One can make layouts which can be
"explained" very concisely, while they contain thousand(s) of accessible
letters.

Unfortunately, being on unchartered territories, in my explanations I'm 
forced to use home-grown terms.  So be patient with me...  The terms are
I<keyboard group>, I<keyboard>, I<face> and I<layer>.  (I must compare them
with what ISO 9995 does: L<http://en.wikipedia.org/wiki/ISO/IEC_9995>...)

In what follows,
the words I<letter> and I<character> are used interchangeably.  A I<key> 
means a physical key on a keyboard clicked (possibly together with 
one of modifiers C<Shift>, C<AltGr> - or, rarely C<Control>.  The key C<AltGr> 
is either marked as such, or is just the "right" C<Alt> key; at least
on Windows it can be replaced by C<Control-Alt>.  A I<prefix key> is a key tapping
which does not produce any letter, but modifies what the next
keypress would do (sometimes it is called a I<dead key>; in C<ISO 9995> terms,
it is probably a I<latching key>).

A plain I<layer> is a part of keyboard layout accessible by using only 
non-prefix keys (possibly in combination with C<Shift>); likewise, I<additional 
layers> are parts of layout accessible by combining the non-prefix keys 
with C<Shift> (if needed) and with a particular combination of other modifiers 
(C<AltGr> or C<Control>).  So there may be up to 2 additional layers: the
C<AltGr>-layer and C<Control>-layer.  


On the simplest layouts, such as "US" or "Russian",  there is no prefix keys - 
but this is only feasible for languages which use very few characters with 
diacritic marks.  However, note that most layouts do not use 
C<Control>-layer - it is stated that this might be subject to problems with
system interaction.

The primary I<face> consists of the plain and additional layers of a keyboard;
it is the part of layout accessible without switching "sticky state" and 
without using prefix keys.  There may be up to 3 layouts (Primary, AltGr, Control)
per face (on Windows).  A I<secondary face> is a face exposed after pressing 
a prefix key.

A I<personality> is a collection of faces: the primary face, plus one face per
a defined prefix-key.  Finally, a I<keyboard group> is a collection of personalities
(switchable by CapsLock and/or personality change hotkeys like C<Shift-Alt>)
designed to work smoothly together.

B<EXAMPLE:> Start with a I<very> elaborate (and not yet implemented, but 
feasible with this module) example.  A keyboard group may consist of 
phonetically matched Latin and Cyrillic personalities, and visually matched Greek 
and Math personalities.  Several prefix-keys may be shared by all 4 of these 
personalities; in particular, there would be 4 prefix-keys allowing access to primary 
faces of these 4 personalities from other personalities of the group.  Also, there 
may be specialised prefix-key tuned for particular need of entering Latin script, 
Cyrillic script, Greek script, and Math.

Suppose that there are 8 specialized Latin prefix-keys (for example, name them
   
  grave/tilde/hat/breve/ring_above/macron/acute/diaeresis

although in practice each one of them may do more than the name suggests).  
Then Latin personality will have the following 13 faces:

   Primary/Latin-Primary/Cyrillic-Primary/Greek-Primary/Math-Primary
   grave/tilde/hat/breve/ring_above/macron/acute/diaeresis

B<NOTE:>   Here Latin-Primary is the face one gets when one presses
the Access-Latin prefix-key when in Latin mode; it may be convenient to define 
it to be the same as Primary - or maybe not.  For example, if one defines it 
to be Greek-Primary, then this prefix-key has a convenient semantic of flipping
between Latin and Greek modes for the next typed character: when in
Latin, C<Latin-PREFIX-KEY a> would enter α, when in Greek, the same keypresses
[now meaning "Latin-PREFIX-KEY α"] would enter "a".

Assume that the layout does not use the C<Control> modifier.  Then each of 
these faces would consists of two layers: the plain one, and the C<AltGr>- 
one.  For example, pressing C<AltGr> with a key on Greek face could add
diaeresis to a vowel, or use a modified ("final" or "symbol") "glyph" for
a consonant (as in σ/ς θ/ϑ).  Or, on Latin face, C<AltGr-a> may produce æ.  Or, on a
Cyrillic personality, AltGr-я (ya) may produce ѣ (yat').

Likewise, the Greek personality may define special prefix-keys to access polytonic 
greek vowels.  (On the other hand, maybe this is not a very good idea - it may
be more useful to make polytonic Greek accessible from all personalities in a
keyboard group.  Then one is able to type a polytonic Greek letter without 
switching to the Greek personality.)

With such a keyboard group, to type one Greek word in a Cyrillic text one 
would switch to the Greek personality, then back to Cyrillic; but when all one 
need to type now is only one Greek letter, it may be easier to use the 
"Greek-PREFIX-KEY letter" combination, and save switching back to the
Cyrillic personality.  (Of course, for this to work the letter should be 
on the primary face of the Greek personality.)

   =====================================================

Looks too complicated?  Try to think about it in a different way: there
are many faces in a keyboard group; break them into 3 "onion rings":

=over 4

=item I<CORE> faces 

one can "switch to a such a face" and type continuously using 
this face without pressing prefix keys.  In other words, these faces 
can be made "active".
     
When another face is active, the letters in these faces are still 
accessible by pressing one particular prefix key before each of these
letters.  This prefix key does not depend on which core face is 
currently "active".  (This is the same as for univerally accessible faces.)
     
=item  I<Universally accessible> faces 

one cannot "switch to them", however, letters
in these faces are accessible by pressing one particular prefix key
before this letter.  This prefix key does not depend on which
core face is currently "active".
     
=item I<satellite> faces 

one cannot "switch to them", and letters in these faces
are accessible from one particular core face only.  One must press a 
prefix key before every letter in such faces.

=back

For example, when entering a mix of Latin/Cyrillic scripts and math,
it makes sense to make the base-Latin and base-Cyrillic faces into
the core; it is convenient when (several) Math faces and a Greek face 
can be made universally accessible.  On the other hand, faces containing
diacritized Latin letters and diacritized Cyrillic letters should better
be made satellite; this avoids a proliferation of prefix keys which would
make typing slower.

=head1 Access to diacritic marks

The logic: prefix keys are either 8-bit characters with high bit set, or
if none with the needed glyph, they are "spacing modifier letters" or
"spacing clones of diacritics".  And if you type I<something> after them,
you can get other modifier letters and combining characters: here is the
logic of this:

=over 20

=item The second press

The principal combining mark.

=item Surrogate for the diacritic

(either C<"> or C<'>): corresponding "prime shape"-modifier character

=item SPACE

The modifier character itself.

=item NBSP

Modifier letter (the first one if diacritic is 8-bit, the second one
otherwise.

=back

Some stats on prefix keys: C<ISO 9995-3> uses 26 prefix keys for diacritics;
bépo uses 20, while EurKey uses 8.  On the other end of spectrum, there are
10 US keyboard keys with "calculatable" relation to Latin diacritics:

  `~^-'",./? --- grave/tilde/hat/macron/acute/diaeresis/cedilla/dot/stroke/hook-above

To this list one may add a "calculatable" key C<$> as I<the currency prefix>;
on the other hand, one should probably remove C<?> since C<AltGr-?> should better
be "set in stone" to denote C<¿>.  If one adds Greek, then the calculatable positions
for aspiration are on C<[ ]> (or on C<( )>).  Of widely used Latin diacritics, this
leaves I<ring/hacek/breve/horn/ogonek/comma> (and doubled I<grave/acute>).

CAVEATS for BÉPO keyboard:

Non-US keycaps: the key "a" still uses (VK_)A, but its scancode is now different.
E.g., French's A is on 0x10, which is US's Q.  Our table of scancodes is
currently hardwired.  Some pictures and tables are available on

  http://bepo.fr/wiki/Pilote_Windows


=head1 FILES

=head1 Useful tidbits from Unicode mailing list (unsorted)

.... skew-orthogonal complement

Drachma: http://unicode.org/mail-arch/unicode-ml/y2012-m05/0167.html

  http://std.dkuug.dk/jtc1/sc2/wg2/docs/n3866.pdf

Pound

  http://unicode.org/mail-arch/unicode-ml/y2012-m05/0242.html

MS keyboard (wrong?)

  http://unicode.org/mail-arch/unicode-ml/y2012-m05/0268.html

w-ring is a stowaway

  http://unicode.org/mail-arch/unicode-ml/y2012-m04/0043.html

History of squared pH

  http://unicode.org/mail-arch/unicode-ml/y2012-m02/0123.html

Why and how to introduce innovative characters

  http://unicode.org/mail-arch/unicode-ml/y2012-m01/0045.html

Upside-down text in CSS (remove position?)

  http://unicode.org/mail-arch/unicode-ml/y2012-m01/0037.html

Classification of Dings (bats etc)

  std.dkuug.dk/jtc1/sc2/wg2/docs/n4115.pdf

	Escape: 2be9 2b9b
	ARROW SHAFT - various

Math Almost-Text encoding

  http://unicode.org/notes/tn28/UTN28-PlainTextMath-v3.pdf
  http://unicode.org/mail-arch/unicode-ml/y2011-m10/0018.html
    For me 1/2/3/4 means unambiguously ((1/2)/3)/4, i.e. 1/(2*3*4)

    Unicode mostly encodes characters that are in use or have been
    encoded in other standards. While not semantically agnostic, it is
    much less oriented towards semantic clarifications and
    distinctions than many people might hope for (and this includes
    me, some of the time at least).

Unicode knows the concept of a provisional property

  http://unicode.org/mail-arch/unicode-ml/y2011-m11/0142.html
  http://unicode.org/reports/tr23/
  http://unicode.org/mail-arch/unicode-ml/y2011-m11/0161.html
    If you want to make analogies, however, the ISO ballots constitute
    the *provisional* publication for character code points and names.
    	that needs to be available from day one for a character to be
	implementable at all (such as decomp mappings, bidi class,
	code point, name, etc.).

	     ZERO-WIDTH UNDEFINED DECOMPOSITION MARK
	     		- to define decomposition, prepend it

Yiddish digraphs

  http://unicode.org/mail-arch/unicode-ml/y2011-m10/0121.html

Locales

  http://blog.kyero.com/2011/11/14/what-is-the-common-locale-data-repository/
  http://blog.kyero.com/2010/12/02/lost-in-translation-locales-not-languages/
  http://unicode.org/mail-arch/unicode-ml/y2006-m06/0203.html

Silly quotation marks: 201b, 201f

  http://en.wikipedia.org/wiki/Quotation_mark_glyphs
  http://unicode.org/mail-arch/unicode-ml/y2006-m06/0300.html
  http://unicode.org/mail-arch/unicode-ml/y2006-m06/0317.html
  http://en.wikipedia.org/wiki/Comma
  http://en.wikipedia.org/wiki/%CA%BBOkina
  http://en.wikipedia.org/wiki/Saltillo_%28linguistics%29
  http://unicode.org/mail-arch/unicode-ml/y2006-m06/0367.html
  http://unicode.org/unicode/reports/tr8/ 
  		under "4.6 Apostrophe Semantics Errata"

COMBINING GREEK YPOGEGRAMMENI equilibristic (depends on a vowel?)

  http://unicode.org/mail-arch/unicode-ml/y2006-m06/0299.html
  http://unicode.org/mail-arch/unicode-ml/y2006-m06/0308.html
  http://www.tlg.uci.edu/~opoudjis/unicode/unicode_adscript.html
  http://unicode.org/mail-arch/unicode-ml/y2008-m05/0046.html

General

  http://ebixio.com/online_docs/UnicodeDemystified.pdf

Keyboard keys:

  http://unicode.org/mail-arch/unicode-ml/Archives-Old/UML009/0204.html

Horizontal/vertical line/arrow extensions

  http://unicode.org/charts/PDF/U2300.pdf
  http://unicode.org/mail-arch/unicode-ml/y2003-m07/0513.html
  http://std.dkuug.dk/JTC1/SC2/WG2/docs/n2508.htm

Cyrillic Script, Unicode status (+combining)

  http://scriptsource.org/cms/scripts/page.php?item_id=entry_detail&uid=ngc339csy8
  http://scriptsource.org/cms/scripts/page.php?item_id=entry_detail&uid=ktxptbccph

OHM: In modern usage, for new documents, this character should not be used. 

  http://unicode.org/mail-arch/unicode-ml/y2011-m08/0060.html

Substitute blank

  http://unicode.org/mail-arch/unicode-ml/y2011-m07/0101.html

Representing invisible characters

  http://unicode.org/mail-arch/unicode-ml/y2011-m07/0094.html

Diacritics in fonts

  http://unicode.org/mail-arch/unicode-ml/y2011-m05/0047.html
  http://www.user.uni-hannover.de/nhtcapri/combining-marks.html#greek

Unicode in 1889

  http://www.archive.org/stream/unicodeuniversa00unkngoog#page/n3/mode/2up

On the other hand, having access to text only math symbols makes it possible to implement it in computer languages, making source code easier to read.

Right now, I feel there is a lack of keyboard maps. You can develop them on your own, but that is very time consuming.

  http://unicode.org/mail-arch/unicode-ml/y2011-m04/0117.html

Licences (GPL etc) in TV sets

  http://unicode.org/mail-arch/unicode-ml/y2009-m12/0092.html

Exciting new letter forms for English

  http://www.theonion.com/articles/alphabet-updated-with-15-exciting-new-replacement,2869/

Similar glyphs:

  http://unicode.org/reports/tr39/data/confusables.txt

Hyphens:

  http://unicode.org/mail-arch/unicode-ml/y2009-m10/0038.html

GOST 10859

  http://unicode.org/mail-arch/unicode-ml/y2009-m09/0082.html
  http://www.mailcom.com/besm6/ACPU-128.jpg

Unicode to PostScript

  http://unicode.org/mail-arch/unicode-ml/y2009-m06/0056.html
  http://www.linuxfromscratch.org/blfs/view/svn/pst/enscript.html
  http://unicode.org/mail-arch/unicode-ml/y2009-m06/0062.html

Linguists mailing lists

  http://unicode.org/mail-arch/unicode-ml/y2009-m06/0066.html

GeoLocation by IP

  http://unicode.org/mail-arch/unicode-ml/y2009-m04/0197.html

Per language character repertoir:

  http://unicode.org/mail-arch/unicode-ml/y2009-m04/0253.html
  http://unicode.org/mail-arch/unicode-ml/y2009-m04/0255.html

Compromizes vs reality

  http://unicode.org/mail-arch/unicode-ml/y2010-m02/0106.html
  http://unicode.org/mail-arch/unicode-ml/y2010-m02/0117.html

Dates/numbers in Unicode

  http://unicode.org/mail-arch/unicode-ml/y2010-m02/0122.html

Normalization FAQ

  http://www.macchiato.com/unicode/nfc-faq

Hebrew char input

  http://rishida.net/scripts/pickers/hebrew/
  http://rishida.net/scripts/uniview/#title

Obsolete IPA

  http://unicode.org/mail-arch/unicode-ml/y2009-m01/0487.html

Teutonista (vowel guide p11, kbd p13)

  http://www.sprachatlas.phil.uni-erlangen.de/materialien/Teuthonista_Handbuch.pdf

Greek letters for non-Greek

  http://stephanus.tlg.uci.edu/~opoudjis/unicode/unicode_interloping.html#ipa

Pretty-printing text math

  http://code.google.com/p/sympy/wiki/PrettyPrinting

Sub/Super on a terminal

  http://unicode.org/mail-arch/unicode-ml/y2008-m07/0028.html

Apostrophe

  http://unicode.org/mail-arch/unicode-ml/y2008-m05/0060.html
  http://unicode.org/mail-arch/unicode-ml/y2008-m05/0063.html
  http://unicode.org/mail-arch/unicode-ml/y2008-m05/0066.html
  http://unicode.org/mail-arch/unicode-ml/y2007-m07/0251.html
  http://unicode.org/mail-arch/unicode-ml/y2007-m05/0309.html

Uppercase eszett ß ẞ

  http://unicode.org/mail-arch/unicode-ml/y2007-m05/0007.html
  http://unicode.org/mail-arch/unicode-ml/y2007-m05/0008.html
  http://unicode.org/mail-arch/unicode-ml/y2007-m05/0142.html
  http://unicode.org/mail-arch/unicode-ml/y2007-m05/0045.html
  http://unicode.org/mail-arch/unicode-ml/y2007-m05/0147.html
  http://unicode.org/mail-arch/unicode-ml/y2007-m05/0170.html
  http://unicode.org/mail-arch/unicode-ml/y2007-m05/0196.html

Questionner at start of Unicode proposal

  http://unicode.org/mail-arch/unicode-ml/y2007-m05/0087.html

Rubi

  http://en.wikipedia.org/wiki/Ruby_character#Unicode

Cyrillic soup

  http://czyborra.com/charsets/cyrillic.html

Glottals

  http://unicode.org/mail-arch/unicode-ml/y2008-m05/0151.html
  http://unicode.org/mail-arch/unicode-ml/y2008-m05/0163.html
  http://unicode.org/mail-arch/unicode-ml/y2008-m05/0202.html
  http://unicode.org/mail-arch/unicode-ml/y2008-m05/0205.html

Tamil/ISCII

  http://unicode.org/faq/indic.html
  http://unicode.org/versions/Unicode6.1.0/ch09.pdf
  http://www.brainsphere.co.in/keyboard/tm.pdf

CGI and OpenType

  http://unicode.org/mail-arch/unicode-ml/y2008-m02/0097.html

Numbers in scripts ;-)

  http://unicode.org/mail-arch/unicode-ml/y2008-m02/0120.html

Indicating coverage of the font

  http://unicode.org/mail-arch/unicode-ml/y2008-m02/0152.html
  http://unicode.org/mail-arch/unicode-ml/y2008-m02/0167.html

Proposing new stuff

  http://unicode.org/mail-arch/unicode-ml/y2008-m01/0238.html

NOT and BROKEN BAR

  http://unicode.org/mail-arch/unicode-ml/y2007-m12/0207.html
  http://www.cs.tut.fi/~jkorpela/latin1/ascii-hist.html#5C

Accessing ligatures

  http://unicode.org/mail-arch/unicode-ml/y2007-m11/0210.html

Should not use (roman numerals)

  http://unicode.org/mail-arch/unicode-ml/y2007-m11/0253.html

Folding characters

  http://unicode.org/reports/tr30/tr30-4.html

Ignorable glyphs

  http://unicode.org/mail-arch/unicode-ml/y2007-m08/0132.html
  http://unicode.org/mail-arch/unicode-ml/y2007-m08/0138.html
  http://unicode.org/mail-arch/unicode-ml/y2007-m08/0120.html

Spacing: English and French

  http://unicode.org/mail-arch/unicode-ml/y2006-m09/0167.html
  http://unicode.org/mail-arch/unicode-ml/y2008-m05/0103.html
  http://unicode.org/mail-arch/unicode-ml/y2007-m08/0138.html

HOWTO: (non)dummy VS in fonts

  http://unicode.org/mail-arch/unicode-ml/y2007-m08/0118.html

OXIA vs TONOS

  http://www.tlg.uci.edu/~opoudjis/unicode/unicode_gkbkgd.html#oxia

ZWSP ZWNJ WJ SHY NON-BREAKING HYPHEN

  http://unicode.org/mail-arch/unicode-ml/y2007-m08/0123.html
  http://unicode.org/mail-arch/unicode-ml/y2007-m07/0188.html
  http://unicode.org/mail-arch/unicode-ml/y2007-m07/0199.html
  http://unicode.org/mail-arch/unicode-ml/y2007-m07/0201.html
  http://unicode.org/mail-arch/unicode-ml/y2007-m06/0122.html
  http://unicode.org/mail-arch/unicode-ml/y2007-m01/0297.html

On which base to draw a "standalone" diacretic

  http://unicode.org/mail-arch/unicode-ml/y2007-m07/0075.html

Universality vs affordability

  http://unicode.org/mail-arch/unicode-ml/y2007-m07/0157.html

The IBM 1401 Hebrew Letter Key

  http://www.qsm.co.il/Hebrew/HebKey.htm

Structure of development of Unicode

  http://unicode.org/mail-arch/unicode-ml/y2006-m07/0056.html
  http://unicode.org/mail-arch/unicode-ml/y2005-m07/0099.html
      I don't have a problem with Unicode. It is what it is; it cannot
      possibly be all things to all people:
  http://unicode.org/mail-arch/unicode-ml/y2005-m07/0101.html

CR symbols

  http://unicode.org/mail-arch/unicode-ml/y2006-m07/0163.html

Chicago Manual of Style

  http://unicode.org/mail-arch/unicode-ml/y2006-m01/0127.html

Stability of normalization

  http://unicode.org/mail-arch/unicode-ml/y2005-m07/0055.html

Writing systems vs written languages

  http://unicode.org/mail-arch/unicode-ml/y2005-m07/0198.html
  http://unicode.org/mail-arch/unicode-ml/y2005-m07/0241.html

MS Visual OpenType tables

  http://www.microsoft.com/typography/VOLT.mspx
  http://www.microsoft.com/typography

Coloring parts of ligatures
    Implemenations:

  http://unicode.org/mail-arch/unicode-ml/y2005-m06/0195.html
  http://unicode.org/mail-arch/unicode-ml/y2005-m06/0233.html
  http://unicode.org/mail-arch/unicode-ml/y2005-m06/0208.html
    GPOS
  http://unicode.org/mail-arch/unicode-ml/y2005-m06/0167.html

Combining power of generative features - implementor's view

  http://unicode.org/mail-arch/unicode-ml/y2004-m09/0145.html

"Same" character Oacute used for different "functions" in the same text

  http://unicode.org/mail-arch/unicode-ml/y2004-m08/0019.html
	etc:
  http://unicode.org/mail-arch/unicode-ml/y2004-m07/0227.html

Diacritics

  http://www.sil.org/~gaultney/ProbsOfDiacDesignLowRes.pdf
  http://en.wikipedia.org/wiki/Sylfaen_%28typeface%29
    http://tiro.com/Articles/sylfaen_article.pdf

Variation sequences

  http://unicode.org/mail-arch/unicode-ml/y2004-m07/0246.html

Federal vs regional aspects of Latinization (a lot of flak; cp1251)

  http://peoples.org.ru/stenogramma.html

Sign writing

  http://std.dkuug.dk/jtc1/sc2/wg2/docs/n4342.pdf

Writing digits in non-decimal

  http://unicode.org/mail-arch/unicode-ml/y2011-m03/0050.html
	Which separator is less ambiguous?  Breve ˘ ? ␣ ?  Inverted ␣ ?

Colors in Unicode names

  http://unicode.org/mail-arch/unicode-ml/y2011-m03/0100.html

Use to identify a letter:

  http://unicode.org/charts/collation/

A useful set of criteria for encoding symbols is found in
Annex H of this document:

  http://std.dkuug.dk/jtc1/sc2/wg2/docs/n3002.pdf 

What is a "Latin" char

  http://unicode.org/forum/viewtopic.php?f=23&t=102

Perl has problems with unpaired surrogates (whole thread)

  http://unicode.org/mail-arch/unicode-ml/y2010-m11/0034.html

Complex fonts (e.g., Indic)

  http://unicode.org/mail-arch/unicode-ml/y2010-m10/0049.html

Complex glyphs in Symbola (pre-6.01) font may crash older versions of Windows

  http://unicode.org/mail-arch/unicode-ml/y2010-m10/0082.html
  http://unicode.org/mail-arch/unicode-ml/y2010-m10/0084.html

Window 7 SP1 improvements

  http://babelstone.blogspot.de/2010/05/prototyping-tangut-imes-or-why-windows.html

Middle dot is ambiguous

  http://unicode.org/mail-arch/unicode-ml/y2010-m09/0023.html
  http://unicode.org/mail-arch/unicode-ml/y2013-m03/0151.html

Apostroph as soft sign

  http://unicode.org/mail-arch/unicode-ml/y2010-m08/0123.html

Chinese typesetting

  http://idsgn.org/posts/the-end-of-movable-type-in-china/

Keyboards - agreement (5 scripts at end)

  ftp://ftp.cen.eu/CEN/Sectors/List/ICT/CWAs/CWA-16108-2010-MEEK.pdf

LAMBDA vs LAMDA

  http://unicode.org/mail-arch/unicode-ml/y2010-m06/0063.html

U+01BE LATIN LETTER INVERTED GLOTTAL STOP WITH STROKE; oi etc

  http://unicode.org/notes/tn27/

Superscript == modifiers

  http://unicode.org/mail-arch/unicode-ml/y2010-m03/0133.html

Need for a keyboard, keyman examples; why "standard" keyboards are doomed

  http://unicode.org/mail-arch/unicode-ml/y2010-m01/0015.html
  http://unicode.org/mail-arch/unicode-ml/y2010-m01/0022.html
  http://unicode.org/mail-arch/unicode-ml/y2010-m01/0036.html
  http://unicode.org/mail-arch/unicode-ml/y2010-m01/0053.html

@fonts and non-URL URIs

  http://unicode.org/mail-arch/unicode-ml/y2010-m01/0156.html

How to encode Latin-in-fraktur

  http://unicode.org/mail-arch/unicode-ml/y2007-m01/0279.html
  http://unicode.org/mail-arch/unicode-ml/y2007-m01/0263.html

Math layout

  http://unicode.org/mail-arch/unicode-ml/y2007-m01/0303.html

Book Spine reading direction

  http://www.artlebedev.com/mandership/122/

Xerox and interrobang

  http://unicode.org/mail-arch/unicode-ml/y2005-m04/0035.html

Translation of Unicode names

  http://unicode.org/mail-arch/unicode-ml/y2012-m12/0066.html
  http://unicode.org/mail-arch/unicode-ml/y2012-m12/0076.html

Tibetian (history of encoding, relative difficulty of handling comparing to cousins)

  http://unicode.org/mail-arch/unicode-ml/y2013-m04/0036.html
  http://unicode.org/mail-arch/unicode-ml/y2013-m04/0040.html

=head1 SEE ALSO

The keyboard(s) generated with this module: L<UI::KeyboardLayout::izKeys>, L<http://k.ilyaz.org/>

On diacritics:

  http://www.phon.ucl.ac.uk/home/wells/dia/diacritics-revised.htm#two
  http://en.wikipedia.org/wiki/Tonos#Unicode
  http://en.wikipedia.org/wiki/Early_Cyrillic_alphabet#Numerals.2C_diacritics_and_punctuation
  http://en.wikipedia.org/wiki/Vietnamese_alphabet#Tone_marks
  http://diacritics.typo.cz/

  http://en.wikipedia.org/wiki/User:TEB728/temp			(Chars of languages)
  http://www.evertype.com/alphabets/index.html

     Accents in different Languages:
  http://fonty.pl/porady,12,inne_diakrytyki.htm#07
  http://en.wikipedia.org/wiki/Latin-derived_alphabet
  
On typography marks

  http://wiki.neo-layout.org/wiki/Striche
  http://www.matthias-kammerer.de/SonsTypo3.htm
  http://en.wikipedia.org/wiki/Soft_hyphen
  http://en.wikipedia.org/wiki/Dash
  http://en.wikipedia.org/wiki/Ditto_mark

On keyboard layouts:

  http://en.wikipedia.org/wiki/Keyboard_layout
  http://en.wikipedia.org/wiki/Keyboard_layout#US-International
  http://en.wikipedia.org/wiki/ISO/IEC_9995
  http://www.pentzlin.com/info2-9995-3-V3.pdf		(used almost nowhere - only half of keys in Canadian multilanguage match)
      Discussion of layout changes and position of €:
  https://www.libreoffice.org/bugzilla/show_bug.cgi?id=5981
  
    History of QUERTY
  http://kanji.zinbun.kyoto-u.ac.jp/~yasuoka/publications/PreQWERTY.html
  http://kanji.zinbun.kyoto-u.ac.jp/db-machine/~yasuoka/QWERTY/

  http://msdn.microsoft.com/en-us/goglobal/bb964651
  http://eurkey.steffen.bruentjen.eu/layout.html
  http://ru.wikipedia.org/wiki/%D0%A4%D0%B0%D0%B9%D0%BB:Birman%27s_keyboard_layout.svg
  http://bepo.fr/wiki/Accueil
  http://cgit.freedesktop.org/xkeyboard-config/tree/symbols/ru
  http://cgit.freedesktop.org/xkeyboard-config/tree/symbols/keypad
  http://www.evertype.com/celtscript/type-keys.html			(Old Irish mechanical typewriters)
  http://eklhad.net/linux/app/halfqwerty.xkb			(One-handed layout)
  http://www.doink.ch/an-x11-keyboard-layout-for-scholars-of-old-germanic/   (and references there)
  http://www.neo-layout.org/
  https://commons.wikimedia.org/wiki/File:Neo2_keyboard_layout.svg
      Images in (download of)
  http://www.mzuther.de/en/contents/osd-neo2
      Neo2 sources:
  http://wiki.neo-layout.org/browser/windows/kbdneo2/Quelldateien
      Shift keys at center, nice graphic:
  http://www.tinkerwithabandon.com/twa/keyboarding.html
      Physical keyboard:
  http://www.konyin.com/?page=product.Multilingual%20Keyboard%20for%20UNITED%20STATES
      Polytonic Greek
  http://www.polytoniko.org/keyb.php?newlang=en
      Portable keyboard layout
  http://www.autohotkey.com/forum/viewtopic.php?t=28447
      One-handed
  http://www.autohotkey.com/forum/topic1326.html
      Typing on numeric keypad
  http://goron.de/~johns/one-hand/#documentation
      On screen keyboard indicator
  http://www.autohotkey.com/docs/scripts/KeyboardOnScreen.htm
      Phonetic Hebrew layout(s) (1st has many duplicates, 2nd overweighted)
  http://bc.tech.coop/Hebrew-ZC.html
  http://help.keymanweb.com/keyboards/keyboard_galaxiehebrewkm6.php
      Greek (Galaxy) with a convenient mapping (except for Ψ) and BibleScript
  http://www.tavultesoft.com/keyboarddownloads/%7B4D179548-1215-4167-8EF7-7F42B9B0C2A6%7D/manual.pdf
      With 2-letter input of Unicode names:
  http://www.jlg-utilities.com
      Medievist's
  http://www.personal.leeds.ac.uk/~ecl6tam/
      Yandex visual keyboards
  http://habrahabr.ru/company/yandex/blog/108255/
      Implementation in FireFox
  http://mxr.mozilla.org/mozilla-central/source/widget/windows/KeyboardLayout.cpp#1085
      Implementation in Emacs 24.3 (ToUnicode() in fns)
  http://fossies.org/linux/misc/emacs-24.3.tar.gz:a/emacs-24.3/src/w32inevt.c
  http://fossies.org/linux/misc/emacs-24.3.tar.gz:a/emacs-24.3/src/w32fns.c
  http://fossies.org/linux/misc/emacs-24.3.tar.gz:a/emacs-24.3/src/w32term.c
      Naive implementations:
  http://social.msdn.microsoft.com/forums/en-US/windowssdk/thread/07afec87-68c1-4a56-bf46-a38a9c2232e9/

By author of MSKLC Michael S. Kaplan (do not forget to follow links)

  http://blogs.msdn.com/b/michkap/archive/2006/03/26/560595.aspx
  http://blogs.msdn.com/b/michkap/archive/2006/04/22/581107.aspx
      Chaining dead keys:
  http://blogs.msdn.com/b/michkap/archive/2011/04/16/10154700.aspx
      Mapping VK to VSC etc:
  http://blogs.msdn.com/b/michkap/archive/2006/08/29/729476.aspx
      [Link] Remapping CapsLock to mean Backspace in a keyboard layout
            (if repeat, every second Press counts ;-)
  http://colemak.com/forum/viewtopic.php?id=870
      Scancodes from kbd.h get in the way
  http://blogs.msdn.com/b/michkap/archive/2006/08/30/726087.aspx
      What happens if you start with .klc with other VK_ mappings:
  http://blogs.msdn.com/b/michkap/archive/2010/11/03/10085336.aspx
      Keyboards with Ctrl-Shift states:
  http://blogs.msdn.com/b/michkap/archive/2010/10/08/10073124.aspx
      On assigning Ctrl-values
  http://blogs.msdn.com/b/michkap/archive/2008/11/04/9037027.aspx
      On hotkeys for switching layouts:
  http://blogs.msdn.com/b/michkap/archive/2008/07/16/8736898.aspx
      Text services
  http://blogs.msdn.com/b/michkap/archive/2008/06/30/8669123.aspx
      Low-level access in MSKLC
  http://levicki.net/articles/tips/2006/09/29/HOWTO_Build_keyboard_layouts_for_Windows_x64.php
  http://blogs.msdn.com/b/michkap/archive/2011/04/09/10151666.aspx
      On font linking
  http://blogs.msdn.com/b/michkap/archive/2006/01/22/515864.aspx
      Unicode in console
  http://blogs.msdn.com/michkap/archive/2005/12/15/504092.aspx
      Adding formerly "invisible" keys to the keyboard
  http://blogs.msdn.com/b/michkap/archive/2006/09/26/771554.aspx
      Redefining NumKeypad keys
  http://blogs.msdn.com/b/michkap/archive/2007/07/04/3690200.aspx
	BUT!!!
  http://blogs.msdn.com/b/michkap/archive/2010/04/05/9988581.aspx
      And backspace/return/etc
  http://blogs.msdn.com/b/michkap/archive/2008/10/27/9018025.aspx
       kbdutool.exe, run with the /S  ==> .c files
      Doing one's own WM_DEADKEY processing'
  http://blogs.msdn.com/b/michkap/archive/2006/09/10/748775.aspx
      Dead keys do not work on SG-Caps
  http://blogs.msdn.com/b/michkap/archive/2008/02/09/7564967.aspx
      Dynamic keycaps keyboard
  http://blogs.msdn.com/b/michkap/archive/2005/07/20/441227.aspx
      Backslash/yen/won confusion
  http://blogs.msdn.com/b/michkap/archive/2005/09/17/469941.aspx
      Unicode output to console
  http://blogs.msdn.com/b/michkap/archive/2010/10/07/10072032.aspx
      Install/Load/Activate an input method/layout
  http://blogs.msdn.com/b/michkap/archive/2007/12/01/6631463.aspx
  http://blogs.msdn.com/b/michkap/archive/2008/05/23/8537281.aspx
      Reset to a TT font from an application:
  http://blogs.msdn.com/b/michkap/archive/2011/09/22/10215125.aspx
      How to (not) treat C-A-Q
  http://blogs.msdn.com/b/michkap/archive/2012/04/26/10297903.aspx
      Treating Brazilian ABNT c1 c2 keys
  http://blogs.msdn.com/b/michkap/archive/2006/10/07/799605.aspx
      And JIS ¥|-key
	 (compare with  http://www.scs.stanford.edu/11wi-cs140/pintos/specs/kbd/scancodes-7.html
			http://hp.vector.co.jp/authors/VA003720/lpproj/others/kbdjpn.htm )
  http://blogs.msdn.com/b/michkap/archive/2006/09/26/771554.aspx
      Suggest a topic:
  http://blogs.msdn.com/b/michkap/archive/2007/07/29/4120528.aspx#7119166

Convert Apple to MSKLC

  http://typophile.com/node/90606

VK_OEM_8 Kana modifier - Using instead of AltGr
  http://www.kbdedit.com/manual/ex13_replacing_altgr_with_kana.html
Limitations of using KANA toggle
  http://www.kbdedit.com/manual/ex12_trilang_ser_cyr_lat_gre.html
  
FE (Far Eastern) keyboard source code example:
  http://read.pudn.com/downloads3/sourcecode/windows/248345/win2k/private/ntos/w32/ntuser/kbd/fe_kbds/jpn/ibm02/kbdibm02.c__.htm

	Investigation on relation between VK_ asignments, KBDEXT, KBDNUMPAD etc:
  http://code.google.com/p/ergo-dvorak-for-developers/source/browse/trunk/kbddvp.c

    PowerShell vs ISE
  http://blogs.msdn.com/b/powershell/archive/2009/04/17/differences-between-the-ise-and-powershell-console.aspx

HTML consolidated entity names and discussion, MES charsets:

  http://www.w3.org/TR/xml-entity-names
  http://www.w3.org/2003/entities/2007/w3centities-f.ent
  http://www.cl.cam.ac.uk/~mgk25/ucs/mes-2-rationale.html
  http://web.archive.org/web/20000815100817/http://www.egt.ie/standards/iso10646/pdf/cwa13873.pdf

Ctrl2cap

  http://technet.microsoft.com/en-us/sysinternals/bb897578

Low level scancode mapping

  http://www.annoyances.org/exec/forum/winxp/r1017256194
    http://web.archive.org/web/20030211001441/http://www.microsoft.com/hwdev/tech/input/w2kscan-map.asp
    http://msdn.microsoft.com/en-us/windows/hardware/gg463447
  http://www.annoyances.org/exec/forum/winxp/1034644655
     ???
  http://netj.org/2004/07/windows_keymap
  the free remapkey.exe utility that's in Microsoft NT / 2000 resource kit.

  perl -wlne "BEGIN{$t = {T => q(), qw( X e0 Y e1 )}} print qq(  $t->{$1}$2\t$3) if /^#define\s+([TXY])([0-9a-f]{2})\s+(?:_EQ|_NE)\((?:(?:\s*\w+\s*,){3})?\s*([^\W_]\w*)\s*(?:(?:,\s*\w+\s*){2})?\)\s*(?:\/\/.*)?$/i" kbd.h >ll2
    then select stuff up to the first e1 key (but DECIMAL is not there T53 is DELETE??? take from MSKLC help/using/advanced/scancodes)

CapsLock as on typewriter:

  http://www.annoyances.org/exec/forum/winxp/1071197341

Problems on X11:

  http://www.x.org/releases/X11R7.6/doc/kbproto/xkbproto.html			(definition of XKB???)

  http://wiki.linuxquestions.org/wiki/Configuring_keyboards			(current???)
  http://wiki.linuxquestions.org/wiki/Accented_Characters			(current???)
  http://wiki.linuxquestions.org/wiki/Altering_or_Creating_Keyboard_Maps	(current???)
  https://help.ubuntu.com/community/ComposeKey			(documents almost 1/2 of the needed stuff)
  http://www.gentoo.org/doc/en/utf-8.xml					(2005++ ???)
  http://en.gentoo-wiki.com/wiki/X.Org/Input_drivers	(2009++ HAS: How to make CapsLock change layouts)
  http://www.freebsd.org/cgi/man.cgi?query=setxkbmap&sektion=1&manpath=X11R7.4
  http://people.uleth.ca/~daniel.odonnell/Blog/custom-keyboard-in-linuxx11
  http://shtrom.ssji.net/skb/xorg-ligatures.html				(of 2008???)
  http://tldp.org/HOWTO/Danish-HOWTO-2.html					(of 2005???)
  http://www.tux.org/~balsa/linux/deadkeys/index.html				(of 1999???)
  http://www.x.org/releases/X11R7.6/doc/libX11/Compose/en_US.UTF-8.html
  http://cgit.freedesktop.org/xorg/proto/xproto/plain/keysymdef.h

  EIGHT_LEVEL FOUR_LEVEL_ALPHABETIC FOUR_LEVEL_SEMIALPHABETIC PC_SYSRQ : see
  http://cafbit.com/resource/mackeyboard/mackeyboard.xkb

  ./xkb in /etc/X11 /usr/local/X11 /usr/share/local/X11 /usr/share/X11
    (maybe it is more productive to try
      ls -d /*/*/xkb  /*/*/*/xkb
     ?)
  but what dead_diaresis means is defined here:
     Apparently, may be in /usr/X11R6/lib/X11/locale/en_US.UTF-8/Compose /usr/share/X11/locale/en_US.UTF-8/Compose
  http://wiki.maemo.org/Remapping_keyboard
  http://www.x.org/releases/current/doc/man/man8/mkcomposecache.8.xhtml
  
B<Note:> have XIM input method in GTK disables Control-Shift-u way of entering HEX unicode.

    How to contribute:
  http://www.freedesktop.org/wiki/Software/XKeyboardConfig/Rules

B<Note:> the problems with handling deadkeys via .Compose are that: .Compose is handled by
applications, while keymaps by server (since they may be on different machines, things can
easily get out of sync); .Compose knows nothing about the current "Keyboard group" or of
the state of CapsLock etc (therefore emulating "group switch" via composing is impossible).

JS code to add "insert these chars": google for editpage_specialchars_cyrilic, or

  http://en.wikipedia.org/wiki/User:TEB728/monobook.jsx

Latin paleography

  http://en.wikipedia.org/wiki/Latin_alphabet
  http://tlt.its.psu.edu/suggestions/international/bylanguage/oenglish.html
  http://guindo.pntic.mec.es/~jmag0042/LATIN_PALEOGRAPHY.pdf
  http://www.evertype.com/standards/wynnyogh/ezhyogh.html
  http://www.wordorigins.org/downloads/OELetters.doc
  http://www.menota.uio.no/menota-entities.txt
  http://std.dkuug.dk/jtc1/sc2/wg2/docs/n2957.pdf	(Uncomplete???)
  http://skaldic.arts.usyd.edu.au/db.php?table=mufi_char&if=mufi	(No prioritization...)

Summary tables for Cyrillic

  http://ru.wikipedia.org/wiki/%D0%9A%D0%B8%D1%80%D0%B8%D0%BB%D0%BB%D0%B8%D1%86%D0%B0#.D0.A1.D0.BE.D0.B2.D1.80.D0.B5.D0.BC.D0.B5.D0.BD.D0.BD.D1.8B.D0.B5_.D0.BA.D0.B8.D1.80.D0.B8.D0.BB.D0.BB.D0.B8.D1.87.D0.B5.D1.81.D0.BA.D0.B8.D0.B5_.D0.B0.D0.BB.D1.84.D0.B0.D0.B2.D0.B8.D1.82.D1.8B_.D1.81.D0.BB.D0.B0.D0.B2.D1.8F.D0.BD.D1.81.D0.BA.D0.B8.D1.85_.D1.8F.D0.B7.D1.8B.D0.BA.D0.BE.D0.B2
  http://ru.wikipedia.org/wiki/%D0%9F%D0%BE%D0%B7%D0%B8%D1%86%D0%B8%D0%B8_%D0%B1%D1%83%D0%BA%D0%B2_%D0%BA%D0%B8%D1%80%D0%B8%D0%BB%D0%BB%D0%B8%D1%86%D1%8B_%D0%B2_%D0%B0%D0%BB%D1%84%D0%B0%D0%B2%D0%B8%D1%82%D0%B0%D1%85
  http://en.wikipedia.org/wiki/List_of_Cyrillic_letters			- per language tables
  http://en.wikipedia.org/wiki/Cyrillic_alphabets#Summary_table
  http://en.wiktionary.org/wiki/Appendix:Cyrillic_script

     Extra chars (see also the ordering table on page 8)
  http://std.dkuug.dk/jtc1/sc2/wg2/docs/n3194.pdf
  
     Typesetting Old and Modern Church Slavonic
  http://www.sanu.ac.rs/Cirilica/Prilozi/Skup.pdf
  http://irmologion.ru/ucsenc/ucslay8.html
  http://irmologion.ru/csscript/csscript.html
  http://cslav.org/success.htm
  http://irmologion.ru/developer/fontdev.html#allocating

     Non-dialogue of Slavists and Unicode experts
  http://www.sanu.ac.rs/Cirilica/Prilozi/Standard.pdf
  http://kodeks.uni-bamberg.de/slavling/downloads/2008-07-26_white-paper.pdf
  
     Newer: (+ combining ф)
  http://tug.org/pipermail/xetex/2012-May/023007.html
  http://www.unicode.org/alloc/Pipeline.html		As below, plus N-left-hook, ДЗЖ ДЧ, L-descender, modifier-Ь/Ъ
  http://www.synaxis.info/azbuka/ponomar/charset/charset_1.htm
  http://www.synaxis.info/azbuka/ponomar/charset/charset_2.htm
  http://www.synaxis.info/azbuka/ponomar/roadmap/roadmap.html
  http://www.ponomar.net/cu_support.html
  http://www.ponomar.net/files/out.pdf
  http://www.ponomar.net/files/variants.pdf		(5 VS for Mark's chapter, 2 VS for t, 1 VS for the rest)

  http://std.dkuug.dk/jtc1/sc2/wg2/docs/n3772.pdf	typikon (+[semi]circled), ε-form
  http://std.dkuug.dk/jtc1/sc2/wg2/docs/n3971.pdf	inverted ε-typikon
  http://std.dkuug.dk/jtc1/sc2/wg2/docs/n3974.pdf	two variants of o/O
  http://std.dkuug.dk/jtc1/sc2/wg2/docs/n3998.pdf	Mark's chapter
  http://std.dkuug.dk/jtc1/sc2/wg2/docs/n3563.pdf	Reversed tse

IPA

  http://upload.wikimedia.org/wikipedia/commons/f/f5/IPA_chart_2005_png.svg
  http://en.wikipedia.org/wiki/Obsolete_and_nonstandard_symbols_in_the_International_Phonetic_Alphabet
  http://en.wikipedia.org/wiki/Case_variants_of_IPA_letters
    Table with Unicode points marked:
  http://www.staff.uni-marburg.de/~luedersb/IPA_CHART2005-UNICODE.pdf
			(except for "Lateral flap" and "Epiglottal" column/row.
    (Extended) IPA explained by consortium:
  http://unicode.org/charts/PDF/U0250.pdf
    IPA keyboard
  http://www.rejc2.co.uk/ipakeyboard/

http://en.wikipedia.org/wiki/International_Phonetic_Alphabet_chart_for_English_dialects#cite_ref-r_11-0


Is this discussing KBDNLS_TYPE_TOGGLE on VK_KANA???

  http://mychro.mydns.jp/~mychro/mt/2010/05/vk-f.html

Windows: fonts substitution/fallback/replacement

  http://msdn.microsoft.com/en-us/goglobal/bb688134

Problems on Windows:

  http://en.wikipedia.org/wiki/Help:Special_characters#Alt_keycodes_for_Windows_computers
  http://en.wikipedia.org/wiki/Template_talk:Unicode#Plane_One_fonts

    Console font: Lucida Console 14 is viewable, but has practically no Unicode support.
                  Consolas (good at 16) has much better Unicode support (sometimes better sometimes worse than DejaVue)
		  Dejavue is good at 14 (equal to a GUI font size 9 on 15in 1300px screen; 16px unifont is native at 12 here)
  http://cristianadam.blogspot.com/2009/11/windows-console-and-true-type-fonts.html
  
    Apparently, Windows picks up the flavor (Bold/Italic/Etc) of DejaVue at random; see
  http://jpsoft.com/forums/threads/strange-results-with-cp-1252.1129/
	- he got it in bold.  I''m getting it in italic...  Workaround: uninstall 
	  all flavors but one (the BOOK flavor), THEN enable it for the console...  Then reinstall
	  (preferably newer versions).

Display (how WikiPedia does it):

  http://en.wikipedia.org/wiki/Help:Special_characters#Displaying_special_characters
  http://en.wikipedia.org/wiki/Template:Unicode
  http://en.wikipedia.org/wiki/Template:Unichar
  http://en.wikipedia.org/wiki/User:Ruud_Koot/Unicode_typefaces
    In CSS:  .IPA, .Unicode { font-family: "Arial Unicode MS", "Lucida Sans Unicode"; }
  http://web.archive.org/web/20060913000000/http://en.wikipedia.org/wiki/Template:Unicode_fonts

Inspect which font is used by Firefox:

  https://addons.mozilla.org/en-US/firefox/addon/fontinfo/

Windows shortcuts:

  http://windows.microsoft.com/en-US/windows7/Keyboard-shortcuts
  http://www.redgage.com/blogs/pankajugale/all-keyboard-shortcuts--very-useful.html
  https://skydrive.live.com/?cid=2ee8d462a8f365a0&id=2EE8D462A8F365A0%21141

On meaning of Unicode math codepoints

  http://milde.users.sourceforge.net/LUCR/Math/unimathsymbols.pdf
  http://milde.users.sourceforge.net/LUCR/Math/data/unimathsymbols.txt
  http://unicode.org/Public/math/revision-09/MathClass-9.txt

Monospaced fonts with combining marks (!)

  https://bugs.freedesktop.org/show_bug.cgi?id=18614
  https://bugs.freedesktop.org/show_bug.cgi?id=26941

Indic ISCII - any hope with it?  (This is not representable...:)

  http://unicode.org/mail-arch/unicode-ml/y2012-m09/0053.html

(Percieved) problems of Unicode (2001)

  http://www.ibm.com/developerworks/library/u-secret.html

On a need to have input methods for unicode

  http://unicode.org/mail-arch/unicode-ml/y2012-m07/0226.html

On info on Unicode chars

  http://unicode.org/mail-arch/unicode-ml/y2012-m07/0415.html 

Zapf dingbats encoding, and other fine points of AdobeGL:

  ftp://ftp.unicode.org/Public/MAPPINGS/VENDORS/ADOBE/zdingbat.txt
  http://web.archive.org/web/20001015040951/http://partners.adobe.com/asn/developer/typeforum/unicodegn.html

Yet another (IMO, silly) way to handle '; fight: ' vs ` ´

  http://www.cl.cam.ac.uk/~mgk25/ucs/apostrophe.html

Surrogate characters on IE

  HKEY_CURRENT_USER\Software\Microsoft\Internet Explorer\International\Scripts\42
  http://winvnkey.sourceforge.net/webhelp/surrogate_fonts.htm
  http://msdn.microsoft.com/en-us/library/aa918682.aspx				Script IDs

Quoting tchrist:
I<You can snag C<unichars>, C<uniprops>, and C<uninames> from L<http://training.perl.com> if you like.>

Tom's unicode scripts

  http://search.cpan.org/~bdfoy/Unicode-Tussle-1.03/lib/Unicode/Tussle.pm

=head2 F<.XCompose>: on docs and examples

Syntax of C<.XCompose> is (partially) documented in

  http://www.x.org/archive/current/doc/man/man5/Compose.5.xhtml
  http://cgit.freedesktop.org/xorg/lib/libX11/tree/man/Compose.man

 #   Modifiers are not documented
 #	 (Shift, Alt, Lock, Ctrl with aliases Meta, Caps; apparently,
 # 	 	 ! is applied to a sequence without ~ ???) 

Semantic (e.g., which of keybindings has a preference) is not documented.
Experiments (see below) show that a longer binding wins; if same
length, one which is loaded later wins.
Relation with presence of modifiers is not clear.

 #      (the source of imLcPrs.c shows that the explansion of the
 #      shorter sequence is stored too - but the presence of
 #      ->succession means that the code to process the resulting
 #      tree ignores the expansion).
 
Before the syntax was documented: For the best approximation,
read the parser's code, e.g., google for

    inurl:compose.c XCompose
    site:cgit.freedesktop.org "XCompose"
    site:cgit.freedesktop.org "XCompose" filetype:c
    _XimParseStringFile

    http://cgit.freedesktop.org/xorg/lib/libX11/tree/modules/im/ximcp/imLcIm.c
    http://cgit.freedesktop.org/xorg/lib/libX11/tree/modules/im/ximcp/imLcPrs.c
    http://uim.googlecode.com/svn-history/r6111/trunk/gtk/compose.c
    http://uim.googlecode.com/svn/tags/uim-1.5.2/gtk/compose.c

The actual use of the compiled compose table:

 http://cgit.freedesktop.org/xorg/lib/libX11/tree/modules/im/ximcp/imLcFlt.c

Apparently, the first node (= defined last) in the tree which
matches keysym and modifiers is chosen.  So to override C<< <Foo> <Bar> >>,
looks like (checked to work!) C<< ~Ctrl <Foo> >> may be used...
On the other hand, defining both C<< <Foo> <Bar> <Baz> >> and (later) C<< <Foo> ~Ctrl <Bar> >>,
one would expect that C<< <Foo> <Ctrl-Bar> <Baz> >> should still trigger the
expansion of C<< <Foo> <Bar> <Baz> >> — but it does not...  See also:

  http://cgit.freedesktop.org/xorg/lib/libX11/tree/modules/im/ximcp/imLcLkup.c

The file F<.XCompose> is processed by X11 I<clients> on startup.  The changes
to this file should be seen immediately by all newly started clients
(but GTK or QT applications may need extra config - see below)
unless the directory F<~/.compose-cache> is present and has a cache
file compatible with binary architecture (then until cache
expires - one day after creation - changes are not seen).  The
name F<.XCompose> may be overriden by environment variable C<XCOMPOSEFILE>. 

To get (better?) examples, google for C<"multi_key" partial alpha "DOUBLE-STRUCK">.

  # include these first, so they may be overriden later
  include "%H/my-Compose/.XCompose-kragen"
  include "%H/my-Compose/.XCompose-ootync"
  include "%H/my-Compose/.XCompose-pSub"

Check success: kragen: C<\ space> --> ␣; ootync: C<o F> --> ℉; pSub: C<0 0> --> ∞ ...

Older versions of X11 do not understand %L %S. - but understand %H
    
E.g. Debian Squeeze 6.0.6; according to
      
   http://packages.debian.org/search?keywords=x11-common
    
it has C<v 1:7.5+8+squeeze1>).

   include "/etc/X11/locale/en_US.UTF-8/Compose"
   include "/usr/share/X11/locale/en_US.UTF-8/Compose"

Import default rules from the system Compose file:
usually as above (but supported only on newer systems):

   include "%L"

detect the success of the lines above: get C<#> by doing C<Compose + +> ...

The next file to include have been generated by

  perl -wlne 'next if /#\s+CIRCLED/; print if />\s+<.*>\s+<.*>\s+<.*/' /usr/share/X11/locale/en_US.UTF-8/Compose
  ### Std tables contain quadruple prefix for GREEK VOWELS and CIRCLED stuff
  ### only.  But there is a lot of triple prefix...  
  perl -wne 'next if /#\s+CIRCLED/; $s{$1}++ or print qq( $1) if />\s+<.*>\s+<.*>\s+<.*"(.*)"/' /usr/share/X11/locale/en_US.UTF-8/Compose
  ##  – — ☭ ª º Ǖ ǖ Ǘ ǘ Ǚ ǚ Ǜ ǜ Ǟ ǟ Ǡ ǡ Ǭ ǭ Ǻ ǻ Ǿ ǿ Ȫ ȫ Ȭ ȭ Ȱ ȱ ʰ ʱ ʲ ʳ ʴ ʵ ʶ ʷ ʸ ˠ ˡ ˢ ˣ ˤ ΐ ΰ Ḉ ḉ Ḕ ḕ Ḗ ḗ Ḝ ḝ Ḯ ḯ Ḹ ḹ Ṍ ṍ Ṏ ṏ Ṑ ṑ Ṓ ṓ Ṝ ṝ Ṥ ṥ Ṧ ṧ Ṩ ṩ Ṹ ṹ Ṻ ṻ Ấ ấ Ầ ầ Ẩ ẩ Ẫ ẫ Ậ ậ Ắ ắ Ằ ằ Ẳ ẳ Ẵ ẵ Ặ ặ Ế ế Ề ề Ể ể Ễ ễ Ệ ệ Ố ố Ồ ồ Ổ ổ Ỗ ỗ Ộ ộ Ớ ớ Ờ ờ Ở ở Ỡ ỡ Ợ ợ Ứ ứ Ừ ừ Ử ử Ữ ữ Ự ự ἂ ἃ ἄ ἅ ἆ ἇ Ἂ Ἃ Ἄ Ἅ Ἆ Ἇ ἒ ἓ ἔ ἕ Ἒ Ἓ Ἔ Ἕ ἢ ἣ ἤ ἥ ἦ ἧ Ἢ Ἣ Ἤ Ἥ Ἦ Ἧ ἲ ἳ ἴ ἵ ἶ ἷ Ἲ Ἳ Ἴ Ἵ Ἶ Ἷ ὂ ὃ ὄ ὅ Ὂ Ὃ Ὄ Ὅ ὒ ὓ ὔ ὕ ὖ ὗ Ὓ Ὕ Ὗ ὢ ὣ ὤ ὥ ὦ ὧ Ὢ Ὣ Ὤ Ὥ Ὦ Ὧ ᾀ ᾁ ᾂ ᾃ ᾄ ᾅ ᾆ ᾇ ᾈ ᾉ ᾊ ᾋ ᾌ ᾍ ᾎ ᾏ ᾐ ᾑ ᾒ ᾓ ᾔ ᾕ ᾖ ᾗ ᾘ ᾙ ᾚ ᾛ ᾜ ᾝ ᾞ ᾟ ᾠ ᾡ ᾢ ᾣ ᾤ ᾥ ᾦ ᾧ ᾨ ᾩ ᾪ ᾫ ᾬ ᾭ ᾮ ᾯ ᾲ ᾴ ᾷ ῂ ῄ ῇ ῒ ῗ ῢ ῧ ῲ ῴ ῷ ⁱ ⁿ ℠ ™ שּׁ שּׂ а̏ А̏ е̏ Е̏ и̏ И̏ о̏ О̏ у̏ У̏ р̏ Р̏ 🙌

The folloing exerpt from NEO compose tables may be good if you use
keyboards which do not generate dead keys, but may generate Cyrillic keys;
in other situations, edit filtering/naming on the following download
command and on the C<include> line below.  (For my taste, most bindings are
useless since they contain keysymbols which may be generated with NEO, but
not with less intimidating keylayouts.)

(Filtering may be important, since having a large file may
significantly slow down client's startup (without F<~/.compose-cache>???).) 

  # perl -wle 'foreach (qw(base cyrillic greek lang math)) {my @i=@ARGV; $i[-1] .= qq($_.module?format=txt); system @i}' wget -O - http://wiki.neo-layout.org/browser/Compose/src/ | perl -wlne 'print unless /<(U[\dA-F]{4,6}>|dead_|Greek_)/' >  .XCompose-neo-no-Udigits-no-dead-no-Greek
  include "%H/.XCompose-neo-no-Udigits-no-dead-no-Greek"
  # detect the success of the line above: get ♫ by doing Compose Compose (but this binding is overwritten later!)

  ###################################### Neo's Math contains junk at line 312

Print with something like (loading in a web browser after this):

  perl -l examples/filter-XCompose ~/.XCompose-neo-no-Udigits-no-dead-no-Greek > ! o-neo
  env LC_ALL=C sort -f o-neo | column -x -c 130 > ! /tmp/oo-neo-x

=head2 “Systematic” parts of rules in a few F<.XCompose>

        ================== .XCompose	b=bepo		o=ootync	k=kragen	p=pSub	s=std
        b	Double-Struck		b
        o	circled ops		b
        O	big circled ops		b
        r	rotated			b	8ACETUv  ∞

        -	sub			p
        =	double arrows		po
        g	greek			po
        m	math			p	|=Double-Struck		rest haphasard...
        O	circles			p	Oo
        S	stars			p	Ss
        ^	sup			p	added: i -
        |	daggers			p

        Double	mathop			ok	+*&|%8CNPQRZ AE

        #	thick-black arrows	o
        -,Num-	arrows			o
        N/N	fractions		o
        hH	pointing hands		o
        O	circled ops		o
        o	degree			o
        rR	roman nums		o
        \ UP	upper modifiers		o
        \ DN	lower modifiers		o
        {	set theoretic		o
        |	arrows |-->flavors	o
        UP /	roots			o
        LFT DN	6-quotes, bold delim	o
        RT DN	9-quotes, bold delim	o
        UP,DN	super,sub		o

        DOUBLE-separated-by-&	op	k	 ( ) 
        in-()	circled			k	xx for tensor
        in-[]	boxed, dice, play-cards	k
        BKSP after	revert		k
        < after		revert		k
        ` after		small-caps	k
        ' after 	hook		k
        , after 	hook below	k
        h after		phonetic	k

        #	musical			k
        %0	ROMAN			k	%_0 for two-digit
        %	roman			k	%_  for two-digit
        *	stars			k
        *.	var-greek		k
        *	greek			k
        ++, 3	triple			k
        +	double			k
        ,	quotes			k
        !, /	negate			k
        6,9	6,9-quotes		k
        N N	fractions		k
        =	double-arrows, RET	k
        CMP x2	long names		k
        f	hand, pencils 		k
        \	combining???		k
        ^	super, up modifier	k
        _	low modifiers		k
        |B, |W	chess, checkers, B&W	k
        |	double-struck		k
        ARROWS	ARROWS			k

        !	dot below		s
        "	diaeresis		s
        '	acute			s
        trail <	left delimiter		s
        trail >	right delimiter		s
        trail \ slopped variant		s
        ( ... )	circled			s
        (	greek aspirations	s
        )	greek aspirations	s
        +	horn			s
        ,	cedilla			s
        .	dot above		s
        -	hor. bar		s
        /	diag, vert hor. bar	s
        ;	ogonek			s
        =	double hor.bar		s
        trail =	double hor.bar		s
        ?	hook above		s
        b	breve			s
        c	check above		s
        iota	iota below		s
        trail 0338	negated		s
        o	ring above		s
        U	breve			s
                        SOME HEBREW
        ^	circumblex		s
        ^ _	superscript		s
        ^ undbr	superscript		s
        _	bar			s
        _	subscript		s
        underbr	subscript		s
        `	grave			s
        ~	greek dieresis		s
        ~	tilde			s
        overbar	bar			s
        ´	acute			s	´ is not '
        ¸	cedilla			s	¸ is cedilla

=head1 LIMITATIONS

Currently only output for Windows keyboard layout drivers (via MSKLC) is available.

Currently only the keyboards with US-mapping of hardware keys to "the etched
symbols" are supported (think of German physical keyboards where Y/Z keycaps
are swapped: Z is etched between T and U, and Y is to the left of X, or French
which swaps A and Q, or French or Russian physical keyboards which have more
alphabetical keys than 26).

While the architecture of assembling a keyboard of small easy-to-describe
pieces is (IMO) elegant and very powerful, and is proven to be useful, it 
still looks like a collection of independent hacks.  Many of these hacks
look quite similar; it would be great to find a way to unify them, so 
reduce the repertoir of operations for assembly.

The current documentation is a hodge-podge of semi-coherent rambling.

The implementation of the module is crumbling under its weight.  Its 
evolution was by bloating (even when some design features were simplified).
Since initially I had very little clue to which level of abstraction and 
flexibility the keyboard description would evolve, bloating accumulated 
to incredible amounts.

=head1 UNICODE TABLE GOTCHAS

APL symbols with C<UP TACK> and C<DOWN TACK> look reverted w.r.t. other
C<UP TACK> and C<DOWN TACK> symbols.  (We base our mutation on the names,
not glyphs.)

C<LESS-THAN>, C<FULL MOON>, C<GREATER-THAN>, C<EQUALS> C<GREEK RHO>, C<MALE>
are defined with C<SYMBOL> or C<SIGN> at end, but (may) drop it when combined
with modifiers via C<WITH>.  Likewise for C<SUBSET OF>, C<SUPERSET OF>,
C<CONTAINS AS MEMBER>, C<PARALLEL TO>, C<EQUIVALENT TO>, C<IDENTICAL TO>.

Sometimes opposite happens, and C<SIGN> appears out of blue sky; compare:

  2A18	INTEGRAL WITH TIMES SIGN
  2A19	INTEGRAL WITH INTERSECTION

C<ENG> I<is> a combination of C<n> with C<HOOK>, but it is not marked as such
in its name.

Sometimes a name of diacritic (after C<WITH>) acquires an C<ACCENT> at end
(see C<U+0476>).

Oftentimes the part to the left of C<WITH> is not resolvable: sometimes it
is underspecified (e.g, just C<TRIANGLE>), sometimes it is overspecified
(e.g., in C<LEFT VERTICAL BAR WITH QUILL>), sometime it should be understood
as a word (e.g, in C<END WITH LEFTWARDS ARROW ABOVE>).  Sometimes it just
does not exist (e.g., C<LATIN LETTER REVERSED GLOTTAL STOP WITH STROKE> -
there is C<LATIN LETTER INVERTED GLOTTAL STOP>, but not the reversed variant).
Sometimes it is a defined synonym (C<VERTICAL BAR>).

Sometimes it has something appended (C<N-ARY UNION OPERATOR WITH DOT>).

Sometimes C<WITH> is just a clarification (C<RIGHTWARDS HARPOON WITH BARB DOWNWARDS>).

  1	AND
  1	ANTENNA
  1	ARABIC MATHEMATICAL OPERATOR HAH
  1	ARABIC MATHEMATICAL OPERATOR MEEM
  1	ARABIC ROUNDED HIGH STOP
  1	ARABIC SMALL HIGH LIGATURE ALEF
  1	ARABIC SMALL HIGH LIGATURE QAF
  1	ARABIC SMALL HIGH LIGATURE SAD
  1	BACK
  1	BLACK SUN
  1	BRIDE
  1	BROKEN CIRCLE
  1	CIRCLED HORIZONTAL BAR
  1	CIRCLED MULTIPLICATION SIGN
  1	CLOSED INTERSECTION
  1	CLOSED LOCK
  1	COMBINING LEFTWARDS HARPOON
  1	COMBINING RIGHTWARDS HARPOON
  1	CONGRUENT
  1	COUPLE
  1	DIAMOND SHAPE
  1	END
  1	EQUIVALENT
  1	FISH CAKE
  1	FROWNING FACE
  1	GLOBE
  1	GRINNING CAT FACE
  1	HEAVY OVAL
  1	HELMET
  1	HORIZONTAL MALE
  1	IDENTICAL
  1	INFINITY NEGATED
  1	INTEGRAL AVERAGE
  1	INTERSECTION BESIDE AND JOINED
  1	KISSING CAT FACE
  1	LATIN CAPITAL LETTER REVERSED C
  1	LATIN CAPITAL LETTER SMALL Q
  1	LATIN LETTER REVERSED GLOTTAL STOP
  1	LATIN LETTER TWO
  1	LATIN SMALL CAPITAL LETTER I
  1	LATIN SMALL CAPITAL LETTER U
  1	LATIN SMALL LETTER LAMBDA
  1	LATIN SMALL LETTER REVERSED R
  1	LATIN SMALL LETTER TC DIGRAPH
  1	LATIN SMALL LETTER TH
  1	LEFT VERTICAL BAR
  1	LOWER RIGHT CORNER
  1	MEASURED RIGHT ANGLE
  1	MONEY
  1	MUSICAL SYMBOL
  1	NIGHT
  1	NOTCHED LEFT SEMICIRCLE
  1	ON
  1	OR
  1	PAGE
  1	RIGHT ANGLE VARIANT
  1	RIGHT DOUBLE ARROW
  1	RIGHT VERTICAL BAR
  1	RUNNING SHIRT
  1	SEMIDIRECT PRODUCT
  1	SIX POINTED STAR
  1	SMALL VEE
  1	SOON
  1	SQUARED UP
  1	SUMMATION
  1	SUPERSET BESIDE AND JOINED BY DASH
  1	TOP
  1	TOP ARC CLOCKWISE ARROW
  1	TRIPLE VERTICAL BAR
  1	UNION BESIDE AND JOINED
  1	UPPER LEFT CORNER
  1	VERTICAL BAR
  1	VERTICAL MALE
  1	WHITE SUN
  2	CLOSED MAILBOX
  2	CLOSED UNION
  2	DENTISTRY SYMBOL LIGHT VERTICAL
  2	DOWN-POINTING TRIANGLE
  2	HEART
  2	LEFT ARROW
  2	LINE INTEGRATION
  2	N-ARY UNION OPERATOR
  2	OPEN MAILBOX
  2	PARALLEL
  2	RIGHT ARROW
  2	SMALL CONTAINS
  2	SMILING CAT FACE
  2	TIMES
  2	TRIPLE HORIZONTAL BAR
  2	UP-POINTING TRIANGLE
  2	VERTICAL KANA REPEAT
  3	CHART
  3	CONTAINS
  3	TRIANGLE
  4	BANKNOTE
  4	DIAMOND
  4	PERSON
  5	LEFTWARDS TWO-HEADED ARROW
  5	RIGHTWARDS TWO-HEADED ARROW
  8	DOWNWARDS HARPOON
  8	UPWARDS HARPOON
  9	SMILING FACE
  11	CIRCLE
  11	FACE
  11	LEFTWARDS HARPOON
  11	RIGHTWARDS HARPOON
  15	SQUARE

  perl -wlane "next unless /^Unresolved: <(.*?)>/; $s{$1}++; END{print qq($s{$_}\t$_) for keys %s}" oxx-us2 | sort -n > oxx-us2-sorted-kw

C<SQUARE WITH> specify fill - not combining.  C<FACE> is not combining, same for C<HARPOON>s.

Only C<CIRCLE WITH HORIZONTAL BAR> is combining.  Triangle is combining only with underbar and dot above.

C<TRIANGLE> means C<WHITE UP-POINTING TRIANGLE>.  C<DIAMOND> - C<WHITE DIAMOND> (so do many others.)
C<TIMES> means C<MULTIPLICATION SIGN>; but C<CIRCLED MULTIPLICATION SIGN> means C<CIRCLED TIMES> - go figure!
C<CIRCLED HORIZONTAL BAR WITH NOTCH> is not a decomposition (it is "something circled").

Another way of compositing is C<OVER> (but not C<UNDER>!) and C<FROM BAR>.  See also C<ABOVE>, C<BELOW>
- but only C<BELOW LONG DASH>.  Avoid C<WITH/AND> after these.

C<TWO HEADED> should replace C<TWO-HEADED>.  C<LEFT ARROW> means C<LEFTWARDS ARROW>, same for C<RIGHT>.
C<DIAMOND SHAPE> means C<DIAMOND> - actually just a bug - http://www.reddit.com/r/programming/comments/fv8ao/unicode_600_standard_published/?
C<LINE INTEGRATION> means C<CONTOUR INTEGRAL>.  C<INTEGRAL AVERAGE> means C<INTEGRAL>.
C<SUMMATION> means C<N-ARY SUMMATION>.  C<INFINITY NEGATED> means C<INFINITY>.

C<HEART> means C<WHITE HEART SUIT>.  C<TRIPLE HORIZONTAL BAR> looks genuinely missing...

C<SEMIDIRECT PRODUCT> means one of two, left or right???

This better be convertible by rounding/sharpening, but see
C<BUT NOT/WITH NOT/OR NOT/AND SINGLE LINE NOT/ABOVE SINGLE LINE NOT/ABOVE NOT>

  2268    LESS-THAN BUT NOT EQUAL TO;             1.1
  2269    GREATER-THAN BUT NOT EQUAL TO;          1.1
  228A    SUBSET OF WITH NOT EQUAL TO;            1.1
  228B    SUPERSET OF WITH NOT EQUAL TO;          1.1
  @               Relations
  22E4    SQUARE IMAGE OF OR NOT EQUAL TO;                1.1
  22E5    SQUARE ORIGINAL OF OR NOT EQUAL TO;             1.1
  @@      2A00    Supplemental Mathematical Operators     2AFF
  @               Relational operators
  2A87    LESS-THAN AND SINGLE-LINE NOT EQUAL TO;         3.2
          x (less-than but not equal to - 2268)
  2A88    GREATER-THAN AND SINGLE-LINE NOT EQUAL TO;              3.2
          x (greater-than but not equal to - 2269)
  2AB1    PRECEDES ABOVE SINGLE-LINE NOT EQUAL TO;                3.2
  2AB2    SUCCEEDS ABOVE SINGLE-LINE NOT EQUAL TO;                3.2
  2AB5    PRECEDES ABOVE NOT EQUAL TO;            3.2
  2AB6    SUCCEEDS ABOVE NOT EQUAL TO;            3.2
  @               Subset and superset relations
  2ACB    SUBSET OF ABOVE NOT EQUAL TO;           3.2
  2ACC    SUPERSET OF ABOVE NOT EQUAL TO;         3.2

Looking into v6.1 reference PDFs, 2268,2269,2ab5,2ab6,2acb,2acc have two horizontal bars, 
228A,228B,22e4,22e5,2a87,2a88,2ab1,2ab2 have one horizontal bar,  Hence C<BUT NOT EQUAL TO> and C<ABOVE NOT EQUAL TO>
are equivalent; so are C<WITH NOT EQUAL TO>, C<OR NOT EQUAL TO>, C<AND SINGLE-LINE NOT EQUAL TO>
and C<ABOVE SINGLE-LINE NOT EQUAL TO>.  (Square variants come only with one horizontal line?)


Set C<$ENV{UI_KEYBOARDLAYOUT_UNRESOLVED}> to enable warnings.  Then do

  perl -wlane "next unless /^Unresolved: <(.*?)>/; $s{$1}++; END{print qq($s{$_}\t$_) for keys %s}" oxx | sort -n > oxx-sorted-kw

=head1 COPYRIGHT

Copyright (c) 2011-2013 Ilya Zakharevich <ilyaz@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.

The distributed examples may have their own copyrights.

=head1 TODO

UniPolyK-MultiSymple

Multiple linked faces (accessible as described in ChangeLog); designated 
Primary- and Secondary- switch keys (as Shift-Space and AltGr-Space now).

C<Soft hyphen> as a deadkey may be not a good idea: following it by a special key
(such as C<Shift-Tab>, or C<Control-Enter>) may insert the deadkey character???
Hence the character should be highly visible... (Now the key is invisible,
so this is irrelevant...)

Currently linked layers must have exactly the same number of keys in VK-tables.

VK tables for TAB, BACK were BS.  Same (remains) for the rest of unusual keys...  (See TAB-was.)
But UTOOL cannot handle them anyway...

Define an extra element in VK keys: linkable.  Should be sorted first in the kbd map,
and there should be the same number in linked lists.  Non-linkable keys should not
be linked together by deadkey access...

Interaction of FromToFlipShift with SelectRX not intuitive.  This works: Diacritic[<sub>](SelectRX[[0-9]](FlipShift(Latin)))

DefinedTo cannot be put on Cyrillic 3a9 (yo to superscript disappears - due to duplication???).

... so we do it differently now, but: LinkLayer was not aggressively resolving all the occurences of a character on a layer
before we started to combine it with Diacritic_if_undef...  - and Cyrillic 3a9 is not helped...

via_parent() is broken - cannot replace for Diacritic_if_undef.

Currently, we map ephigraphic letters to capital letters - is it intuitive???

dotted circle ◌ 25CC

DeadKey_Map200A=	FlipLayers
#DeadKey_Map200A_0=	Id(Russian-AltGr)
#DeadKey_Map200A_1=	Id(Russian)
  performs differently from the commented variant: it adds links to auto-filled keys...

Why ¨ on THIN SPACE inserts OGONEK after making ¨ multifaceted???

When splitting a name on OVER/BELOW/ABOVE, we need both sides as modifiers???

Ỳ currently unreachable (appears only in Latin-8 Celtic, is not on Wikipedia)

Somebody is putting an extra element at the end of arrays for layers???  - Probably SPACE...

Need to treat upside-down as a pseudo-decomposition.

We decompose reversed-smallcaps in one step - probably better add yet another two-steps variant...

When creating a <pseudo-stuff> treat SYMBOL/SIGN/FINAL FORM/ISOLATED FORM/INITIAL FORM/MEDIAL FORM;
note that SIGN may be stripped: LESS-THAN SIGN becomes LESS-THAN WITH DOT

We do not do canonical-merging of diacritics; so one needs to specify VARIA in addition to GRAVE ACCENT.

We use a smartish algorithm to assign multiple diacritics to the same deadkey.  A REALLY smart algorithm
would use information about when a particular precombined form was introduced in Unicode...

Inspector tool for NamesList.txt:

 grep " WITH .* " ! | grep -E -v "(ACUTE|GRAVE|ABOVE|BELOW|TILDE|DIAERESIS|DOT|HOOK|LEG|MACRON|BREVE|CARON|STROKE|TAIL|TONOS|BAR|DOTS|ACCENT|HALF RING|VARIA|OXIA|PERISPOMENI|YPOGEGRAMMENI|PROSGEGRAMMENI|OVERLAY|(TIP|BARB|CORNER) ([A-Z]+WARDS|UP|DOWN|RIGHT|LEFT))$" | grep -E -v "((ISOLATED|MEDIAL|FINAL|INITIAL) FORM|SIGN|SYMBOL)$" |less
 grep " WITH "    ! | grep -E -v "(ACUTE|GRAVE|ABOVE|BELOW|TILDE|DIAERESIS|CIRCUMFLEX|CEDILLA|OGONEK|DOT|HOOK|LEG|MACRON|BREVE|CARON|STROKE|TAIL|TONOS|BAR|CURL|BELT|HORN|DOTS|LOOP|ACCENT|RING|TICK|HALF RING|COMMA|FLOURISH|TITLO|UPTURN|DESCENDER|VRACHY|QUILL|BASE|ARC|CHECK|STRIKETHROUGH|NOTCH|CIRCLE|VARIA|OXIA|PSILI|DASIA|DIALYTIKA|PERISPOMENI|YPOGEGRAMMENI|PROSGEGRAMMENI|OVERLAY|(TIP|BARB|CORNER) ([A-Z]+WARDS|UP|DOWN|RIGHT|LEFT))$" | grep -E -v "((ISOLATED|MEDIAL|FINAL|INITIAL) FORM|SIGN|SYMBOL)$" |less

AltGrMap should be made CapsLock aware (impossible: smart capslock works only on the first layer, so
the dead char must be on the first layer).  [May work for Shift-Space - but it has a bag of problems...]

Alas, CapsLock'ing a composition cannot be made stepwise.  Hence one must calculate it directly.
(Oups, Windows CapsLock is not configurable on AltGr-layer.  One may need to convert
it to VK_KANA???)

WarnConflicts[exceptions] and NoConflicts translation map parsing rules.

Need a way to map to a different face, not a different layer.

Vietnamese: to put second accent over ă, ơ (o/horn), put them over ae/oe; - including 
another ˘ which would "cancel the implied one", so will get o-horn itself.  - Except
for acute accent which should replaced by ¨, and hook must be replaced by ˆ.  (Over ae/oe
there is only macron and diaeresis over ae.)

Or: for the purpose of taking a second accent, AltGr-A behaves as Ă (or Â?), AltGr-O 
behaves as Ô (or O-horn Ơ?).  Then Å and O/ behave as the other one...  And ˚ puts the
dot *below*, macron puts a hook.  Exception: ¨ acts as ´ on the unaltered AE.

  While Å takes acute accent, one can always input it via putting ˚ on Á.

If Ê is on the keyboard (and macron puts a hook), then the only problem is how to enter
a hook alone (double circumflex is not precombined), dot below (???), and accents on u-horn ư.

Mogrification rules for double accents: AE Å OE O/ Ù mogrify into hatted/horned versions; macron
mogrifies into a hook; second hat modifies a hat into a horn.  The only problem: one won't be 
able to enter double grave on U - use the OTHER combination of ¨ and `...  And how to enter
dot below on non-accented aue?  Put ¨ on umlaut? What about Ë?

To allow . or , on VK_DECIMAL: maybe make CapsLock-dependent?

  http://blogs.msdn.com/b/michkap/archive/2006/09/13/752377.aspx

How to write this diacritic recipe: insert hacheck on AltGr-variant, but only if
the breve on the base layer variant does not insert hacheck (so inserts breve)???

Sorting diacritics by usefulness: we want to apply one of accents from the
given list to a given key (with l layers of 2 shift states).  For each accent,
we have 2l possible variants for composition; assign to 2 variants differing
by Shift the minimum penalty of the two.  For each layer we get several possible
combinations of different priority; and for each layer, we have a certain number
of slots open.  We can redistribute combinations from the primary layer to
secondary one, but not between secondary layers.

Work with slots one-by-one (so that the assignent is "monotinic" when the number
of slots increases).  Let m be the number of layers where slots are present.
Take highest priority combinations; if the number of "extra" combinations
in the primary layer is at least m, distribute the first m of them to
secondary layers.  If n<m of them are present, fill k layers which
have no their own combinations first, then other n-k layers.  More precisely,
if n<=k, use the first n of "free" layers; if n>k, fill all free layers, then
the last n-k of non-free layers.

Repeat as needed (on each step, at most one slot in each layer appears).

But we do not need to separate case-differing keys!  How to fix?

All done, but this works only on the current face!  To fix, need to pass
to the translator all the face-characters present on the given key simultaneously.

  ===== Accent-key TAB accesses extra bindinges (including NUM->numbered one)
	(may be problematic with some applications???
	 -- so duplicate it on + and @ if they is not occupied
	 -- there is nothing related to AT in Unicode)

Diacritics_0218_0b56_0c34=	May create such a thing...
 (0b56_0c34 invisible to the user).

  Hmm - how to combine penaltized keys with reversion?  It looks like
  the higher priority bindings would occupy the hottest slots in both
  direct and reverse bindings...

  Maybe additional forms Diacrtitics2S_* and Diacrtitics2E_* which fight
  for symbols of the same penalty from start and from end (with S winning
  on stuff exactly in the middle...).  (The E-form would also strip the last |-group.)

' Shift-Space (from US face) should access the second level of Russian face.
To avoid infinite cycles, face-switch keys to non-private faces should be
marked in each face... 

"Acute makes sharper" is applicable to () too to get <>-parens...

Another ways of combining: "OR EQUAL TO", "OR EQUIVALENT TO", "APL FUNCTIONAL
SYMBOL QUAD", "APL FUNCTIONAL SYMBOL *** UNDERBAR", "APL FUNCTIONAL SYMBOL *** DIAERESIS".

When recognizing symbols for GREEK, treat LUNATE (as NOP).  Try adding HEBREW LETTER at start as well...

Compare with: 8 basic accents: http://en.wikipedia.org/wiki/African_reference_alphabet (English 78)

When a diacritic on a base letter expands to several variants, use them all 
(with penalty according to the flags).

Problem: acute on acute makes double acute modifier...

Penalized letter are temporarily completely ignored; need to attach them in the end... 
 - but not 02dd which should be completely ignore...

Report characters available on diacritic chains, but not accessible via such chains.
Likewise for characters not accessible at all.  Mark certain chains as "Hacks" so that
they are not counted in these lists.

Long s and "preceded by" are not handled since the table has its own (useless) compatibility decompositions.

╒╤╕
╞╪╡
╘╧╛
╓╥╖
╟╫╢
╙╨╜
╔╦╗
╠╬╣
╚╩╝
┌┬┐
├┼┤
└┴┘
┎┰┒
┠╂┨
┖┸┚
┍┯┑
┝┿┥
┕┷┙
┏┳┓
┣╋┫
┗┻┛
    On top of a light-lines grid (3×2, 2×3, 2×2; H, V, V+H):
┲┱
╊╉
┺┹
┢╈┪
┡╇┩
╆╅
╄╇
╼━╾╺╸╶─╴╌┄┈ ╍┅┉
╻
┃
╹
╷
│
╵
 
╽
╿
╎┆┊╏┇┋

╲ ╱
 ╳
╭╮
╰╯
◤▲◥
◀■▶
◣▼◢
◜△◝
◁□▷
◟▽◞
◕◓◔
◐○◑
 ◒ 
▗▄▖
▐█▌
▝▀▘
▛▀▜
▌ ▐
▙▄▟

░▒▓


=head1 WINDOWS GOTCHAS

First of all, keyboard layouts on Windows are controlled by DLLs; the only function
of these DLLs is to export a table of "actions" to perform.  This table is passed
to the kernel, and that's it - whatever is not supported by the format of this table
cannot be implemented by native layouts.  (The DLL performs no "actions" when
actual keyboard events arrive.)

Essentially, the logic is like that: there are primary "keypresses", and
chained "keypresses" ("prefix keys" [= deadkeys] and keys pressed after them).  
Primary keypresses are distinguished by which physical key on keyboard is 
pressed, and which of "modifier keys" are also pressed at this moment (as well
as the state of "latched keys" - usually C<CapsLock> only).  This combination
determines which Unicode character is generated by the keypress, and whether
this character starts a "chained sequence".

On the other hand, the behaviour of chained keys is governed I<ONLY> by Unicode
characters they generate: if there are several physical keypresses generating
the same Unicode characters, these keypresses are completely interchangeable
inside a chained sequence.  (The only restriction is that the first keypress
should be marked as "prefix key"; for example, there may be two keys producing
B<-> so that one is producing a "real dash sign", and another is producing a
"prefix" B<->.)

The table allows: to map C<ScanCode>s to C<VK_key>s; to associate a C<VK_key> to several
(numbered) choices of characters to output, and mark some of these choices as prefixes
(deadkeys).  (These "base" choices may contain up to 4 16-bit characters (with 32-bit
characters mapped to 2 16-bit surrogates); but only those with 1 16-bit character may
be marked as deadkeys.)  For each prefix character (not a prefix key!) one can
associate a table mapping input 16-bit "base characters" to output 16-bit characters,
and mark some of the output choices as prefix characters.

The numbered choices above are determined by the state of "modifier keys" (such as
C<Shift>, C<Alt>, C<Control>), but not directly.  First of all, C<VK_keys> may be
associated to a certain combination of 6 "modifier bits" (called "logical" C<Shift>,
C<Alt>, C<Control>, C<Kana>, C<User1> and C<User2>, but the logical bits are not 
required to coincide with names of modifier keys).  (Example: bind C<Right Control>
to activate C<Shift> and C<Kana> bits.)  The 64 possible combinations of modifier bits
are mapped to the numbered choices above.

Additionally, one can define two "separate 
numbered choices" in presence of CapsLock (but the only allowed modifier bit is C<Shift>).
The another way to determine what C<CapsLock> is doing: one can mark that it 
flips the "logical C<Shift>" bit (separately on no-modifiers state, C<Control-Alt>-only state,
and C<Kana>-only state [?!] - here "only" allow for the C<Shift> bit to be C<ON>).

C<AltGr> key is considered equivalent to C<Control-Alt> combination (of those
are present, or always???), and one cannot bind C<Alt> and C<Alt-Shift> combinations.  
Additionally, binding bare C<Control> modifier on alphabetical keys (and
C<SPACE>, C<[>, C<]>, C<\>) may confuse some applications.

B<NOTE:> there is some additional stuff allowed to be done (but only in presence
of Far_East_Support installed???).  FE-keyboards can define some sticky state (so
may define some other "latching" keys in addition to C<CapsLock>).  However,
I did not find a clear documentation yet (C<keyboard106> in the DDK toolkit???).

There is a tool to create/compile the required DLL: F<kbdutool.exe> of I<MicroSoft 
Keyboard Layout Creator> (with a graphic frontend F<MSKLC.exe>).  The tool does 
not support customization of modifier bits, and has numerous bugs concerning binding keys which
usually do not generate characters.  The graphic frontend does not support
chained prefix keys, adds another batch of bugs, and has arbitrarily limitations:
refuses to work if the compiled version of keyboard is already installed;
refuses to work if C<SPACE> is redefined in useful ways.

B<WORKFLOW:> uninstall the keyboard, comment the definition of C<SPACE>,
load in F<MSKLC> and create an install package.  Then uncomment the
definition of C<SPACE>, and compile 4 architecture versions using F<kbdutool>,
moving the DLLs into suitable directories of the install package.  Install
the keyboard.

For development cycle, one does not need to rebuild the install package
while recompiling.

=head2 MSKLC keyboards not working on Windows 8

The layout is shown as active, but "preview" is grayed out,
and is not shown on the Win-Space list.    See also:

  http://www.errordetails.com/125726/activate-custom-keyboard-layout-created-with-msklc-windows

(I know no workaround right now.)

=head2 It is hard to understand what a keyboard really does

To inspect the output of the keyboard in the console mode (may be 8-bit,
depending on how Perl is compiled), one can run

  perl -we "sub mode2s($){my $in = shift; my @o; $in & (1<<$_) and push @o, (qw(rAlt lAlt rCtrl lCtrl Shft NumL ScrL CapL Enh ? ??))[$_] for 0..10; qq(@o)} use Win32::Console; my $c = Win32::Console->new( STD_INPUT_HANDLE); my @k = qw(T down rep vkey vscan ch ctrl); for (1..20) {my @in = $c->Input; print qq($k[$_]=), ($in[$_] < 0 ? $in[$_] + 256 : $in[$_]), q(; ) for 0..$#in; print(@in ? mode2s $in[-1] : q(empty)); print qq(\n)}"

This reports 20 following console events (press and keep C<Alt> key
to exit by generating a “harmless” chain of events).  B<Limitations:> the reported
input character is not processed (via ToUnicode(); hence chained keys and
multiple chars per key are reported only as low-level), and is reported as
a signed 8-bit integer (so the report for above-8bit characters is
completely meaningless).

  T=1; down=1; rep=1; vkey=65; vscan=30; ch=-26; ctrl=9; rAlt lCtrl
  T=1; down=0; rep=1; vkey=65; vscan=30; ch=-26; ctrl=9; rAlt lCtrl

This reports single (T=1) events for keypress/keyrelease (down=1/0) of
C<AltGr-a>.  One can see that C<AltGr> generates C<rAlt lCtrl> modifiers
(this is just a transcription of C<ctrl=9>,
that C<a> is on virtual key 65 (this is C<VK_A>) with virtual scancode
30, and that the generated character (it was C<æ>) is C<-26 mod 0x100>.

The character is approximated to the current codepage.  For example, this is
C<Kana-b> entering C<β = U+03b2> in codepage C<cp1252>:

  T=1; down=1; rep=1; vkey=66; vscan=48; ch=-33; ctrl=0;
  T=1; down=0; rep=1; vkey=66; vscan=48; ch=-33; ctrl=0;

Note that C<0x100 - 33 = 0xDF>, and C<U+00DF = ß>.  So I<beta> is substituted by
I<eszet>.

=head2 Several similar F<MSKLC> created keyboards may confuse the system

Apparently, the system may get majorly confused when the C<description>
of the project gets changed without changing the DLL (=project) name.
   
(Tested only with Win7 and the name in the DESCRIPTIONS section
coinciding with the name on the KBD line - both in F<*.klc> file.)
   
The symptoms: I know how one can get 4 different lists of keyboards:

=over 4

=item 1

Click on the keyboard icon in the C<Language Bar> - usually shown
on the toolbar; positioned to the right of the language code EN/RU 
etc (keyboard icon is not shown if only one keyboard is associated
to the current language).

=item

Go to the C<Input Language> settings (e.g., right-click on the 
Language bar, Settings, General.

=item

on this C<General> page, press C<Add> button, go to the language
in question.

=item

Check the F<.klc> files for recently installed Input Languages.

=item

In MS Keyboard Layout Creator, go to C<File/Load Existing Keyboard>
list.

=back
        
It looks like the first 4 get in sync if one deletes all related keyboards,
then installs the necessary subset.  I do not know how to fix 5 - MSKLC
continues to show the old name for this project.

Another symptom: Current language indicator (like C<EN>) on the language
bar disappears.  (Reboot time?)

Is it related to C<***\Local Settings\MuiCache\***> hive???

Possible workaround: manually remove the entry in C<HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Keyboard Layouts>
(the last 4 digits match the codepage in the F<.klc> file).
   
=head2 Too long description (or funny characters in description?)

If the name in the C<DESCRIPTIONS> section is too long, the name shown in 
the list C<2> above may be empty.
    
(Checked only on Win7 and when the name in the DESCRIPTIONS section
coincides with the name on the C<KBD> line - both in F<*.klc> file.)
   
(Fixed by shortening the name [but see
L<"Several similar F<MSKLC> created keyboards may confuse the system">
above!], so maybe it was
not the length but some particular character (C<+>?) which was confusing
the system.  (I saw a report on F<MSKLC> bug when description had apostroph
character C<'>.)
   
=head2 F<MSKLC> ruins names of dead key when reading a F<.klc>

When reading a F<.klc> file, MS Keyboard Layout Creator may ruin the names
of dead keys.  Symptom: open the dialogue for a dead key mapping
(click the key, check that C<Dead key view> has checkmark, click on the
C<...> button near the C<Dead key?> checkbox); then the name (the first 
entry field) contains some junk.  (Looks like a long ASCII string 

   U+0030 U+0030 U+0061 U+0039

.)

B<Workaround:> if all one needs is to compile a F<.klc>, one can run
F<KBDUTOOL> directly.

B<Workaround:> correct ALL these names manually in MSKLC.  If the names are
the Unicode name for the dead character, just click the C<Default> button 
near the entry field.  Do this for ALL the dead keys in all the registers
(including C<SPACE>!).  If C<CapsLock> is not made "semantically meaningful",
there are 6 views of the keyboard (C<PLAIN, Ctrl, Ctrl+Shift, Shift,
AltGr, AltGr+Shift>) - check them all for grayed out keys (=deadkeys).
   
Check for success: C<File/"Save Source File As>, use a temporary name.  
Inspect near the end of the generated F<.klc> file.  If OK, you can
go to the Project/Build menu.  (Likewise, this way lets you find which
deadkey's names need to be fixed.)
   
!!! This is time-consuming !!!  Make sure that I<other> things are OK
before you do this (by C<Project/Validate>, C<Project/Test>).
   
BTW: It might be that this is cosmetic only.  I do not know any bad
effect - but I did not try to use any tool with visual feedback on
the currently active sub-layout of keyboard.

=head2 Double bug in F<KBDUTOOL> with dead characters above 0x0fff

This line in F<.klc> file is treated correctly by F<MSKLC>'s builtin keyboard tester:

  39 SPACE 0 0020 00a0@ 0020 2009@ 200a@ //  ,  ,  ,  ,   // SPACE, NO-BREAK SPACE, SPACE, THIN SPACE, HAIR SPACE

However, via F<kbdutool> it produces the following two bugs:

  static ALLOC_SECTION_LDATA MODIFIERS CharModifiers = {
    &aVkToBits[0],
    7,
    {
    //  Modification# //  Keys Pressed
    //  ============= // =============
        0,            // 
        1,            // Shift 
        2,            // Control 
        SHFT_INVALID, // Shift + Control 
        SHFT_INVALID, // Menu 
        SHFT_INVALID, // Shift + Menu 
        3,            // Control + Menu 
        4             // Shift + Control + Menu 
     }
  };
 .....................................
    {VK_SPACE     ,0      ,' '      ,WCH_DEAD ,' '      ,WCH_LGTR ,WCH_LGTR },
    {0xff         ,0      ,WCH_NONE ,0x00a0   ,WCH_NONE ,WCH_NONE ,WCH_NONE },
 .....................................
  static ALLOC_SECTION_LDATA LIGATURE2 aLigature[] = {
    {VK_SPACE     ,6      ,0x2009   ,0x2009   },
    {VK_SPACE     ,7      ,0x200a   ,0x200a   },

Essentially, C<2009@ 200a@> produce C<LIGATURES> (= multiple 16-bit chars)
instead of deadkeys.  Moreover, these ligatures are put on non-existing
"modifications" 6, 7 (the maximal modification defined is 4; so the code uses
the C<Shift + Control + Menu> flags instead of "modification number" in
the ligatures table.

=head2 F<MSKLC> keyboards handle C<Ctrl-Shift-letter> differently than US keyboard

At least in console applications, the US keyboard produces (as the 
“string value”) the corresponding Control-letter when 
C<Ctrl-Shift-letter> is pressed.  F<MSKLC> does not reproduces this
behaviour.  This may break an application if
it was not specifically tested with “complicated” keyboards.

The only way to fix this from the “naive” keyboard
layout DLL (i.e., the kind that F<MSKLC> generates) which I found is to
explicitly include C<Ctrl-Shift> as a handled combination, and return
C<Ctrl-letter> on such keypresses.  (This is enabled in the generated
keyboards generated by this module - not customizable in v0.12.)

=head2 Default keyboard of an application

Apparently, there is no way to choose a default keyboard for a certain
language.  The configuration UI allows moving keyboards up and down in
the list, but, apparently, this order is not related to which keyboard
is selected when an application starts.

=head2 Hex input of unicode is not enabled

One needs to explicitly tinker with the registry (see F<examples/enable-hex-unicode-entry.reg>)
and then I<reboot> to enable this.

=head2 Standard fonts have some chars exchanged

At least in Consolas and Lucida Sans Unicode φ and ϕ are exchanged.
Compare with Courier and Times.  (This may be due to the L<difference between
Unicode's pre-v3.0 choice of representative glyphs|http://en.wikipedia.org/wiki/Phi#Computing>, 
or the L<difference
between French/English Apla=Didot/Porson's approaches|http://www.greekfontsociety.gr/pages/en_typefaces19th.html>.)

=head2 The console font configuration

It is controlled by Registry hive

  HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont

The key C<0> usually gives C<Lucida Console>, and the key C<00>
gives C<Consolas>.  Adding random numbers does not work; however,
if one adds one more zero (at least when adding to a sequence of zeros),
one can add more fonts.
You need to export this hive (e.g., use

  reg export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont" console-ttf.reg

), save a copy (so you can always restore if the love goes sour)
then edit the resulting file.

So if the maximal key with 0s is C<00>, add one extra row with an extra 0
at end, and the family name of your font.  The "family name" is what the Font
list in C<Control Panel> shows for I<font families> (a "stacked" icon is shown);
for individual fonts the weight (Regular, Book, Bold etc) is appended.  So I add a line

  "000"="DejaVu Sans Mono"

the result is (omitting Far Eastern fonts)

  Windows Registry Editor Version 5.00

  [HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont]
  "949"="..."
  "0"="Lucida Console"
  "950"="..."
  "932"="..."
  "936"="..."
  "00"="Consolas"
  "000"="DejaVu Sans Mono"

The full file is in F<examples/console-fonts00-added.reg>.  After importing this
file via F<reg> (or give it as parameter to F<regedit>; both require administrative priviledges)
the font is immediately available in menu.  (However, it does not work in "existing"
console windows, only in newly created windows.)

B<(Do not use the example file directly.  First inspect the hive exported on your system,
and find the number of 0s to use.  Then add a new line with correct number of
zeros - as a value, one can use the string above.  This will I<preserve> the defaults
of your setup.>  Keep in mind that
selection-by-fontfamily is buggy: if you have more than one version of the font
in different weight, it is a Russian Rullette which one of them will be taken
(at least for DejaVu, which uses C<Book> as the default weight).  First install
the "normal" flavor of the font, then do as above (so the system has no way of picking
the wrong flavor!), and only after this install the remaining
flavors.

B<CAVEAT:> the string to put into C<Console\TrueTypeFont> is the I<Family Name> of the font.
On Windows, it is tricky to find the family name using the default Windows' tools, without
inspecting the font in a font editor.  One workaround is to select the font in C<Character Map>
application, then inspect C<HKEY_CURRENT_USER\Software\Microsoft\CharMap\Font> via:

  reg export HKCU\Software\Microsoft\CharMap character-map-font.reg

Note: what is visible in the C<Properties> dialogue of the font, and in C<CurrentVersion\Fonts> is the
I<Full Font Name>.  Fortunately, quite often the full name and the family name coincide —
this is what happened with C<DejaVu>.  To find the "Full name" of the font, look into the hive

  HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts
  reg export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" fonts.reg

For example, after installing C<DejaVuSansMono.ttf>, I see
C<DejaVu Sans Mono (TrueType)> as a key in this hive.  

B<One more remark:> for desktop icons coming from the “Public” user (“shared”
icons) which start a console application, the default font is not directly editable.
To reset it, one must:

=over

=item *

copy the F<.lnk> icon file to “your” desktop directory;

=item *

start the application using the “new” icon;

=item *

change the font via “Properties” of the window's menu;

=item *

as administrator, copy the F<.lnk> file back to the F<Public/Desktop>
directory (usually in something like F<C:/Users>).  Manually refresh
the desktop.  Verify that the “old” icon works as expected.
(Now you can remove the “new” icon created on the first step.)

=back

=head2 There is no way to show Unicode contents on Windows

Until Firefox C<v13>, one could use FireFox to show arbitrary
Unicode text (limited only by which fonts are installed on your
system).  If you upgraded to a newer version, there is no (AFAIK)
Windows program (for general public consumption) which would visualize
Unicode text.  The applications are limited either (in the worst case) by
the characters supported by the currently selected font, or (in the best
case) they can show additionally characters, but only those considered by the
system as "important enough" (coming from a few of default fonts?).

There is a workaround for this major problem in FireFox (present at least
up to C<v20>).  It is caused
by L<this “improvement”|https://bugzilla.mozilla.org/show_bug.cgi?id=705594>
which blatantly saves a few seconds of load time for a tiny minority of
users, the price being an unability to show Unicode I<for everybody>
(compare with comments L<33|https://bugzilla.mozilla.org/show_bug.cgi?id=705594#c33> 
and L<75|https://bugzilla.mozilla.org/show_bug.cgi?id=705594#c75> on the bug report above).

It is not documented, but this action is controlled by C<about:config>
setting C<gfx.font_rendering.fallback.always_use_cmaps>.  To enable Unicode,
make this setting into C<true> (if you have it in the list as C<false>, double-clicking it would
do this — do search to determine this; otherwise you need to create a new
C<Binary> entry).

There is an alternative/additional way to enable extra fonts; it makes
sense if you know a few character-rich fonts present on your system.  The (undocumented)
settings C<font.name-list.*.x-unicode> (apparently) control fallback fonts for situations
when a suitable font cannot be found via more specific settings.  For example, when
you installed (free) L<Deja vu|http://dejavu-fonts.org/>, 
L<junicode|http://junicode.sourceforge.net/>, L<Symbola|http://users.teilar.gr/~g1951d/> fonts on your system, you may set (these
variables are not present by default; you need to create new C<String> variables):

  font.name-list.sans-serif.x-unicode	DejaVu Sans,Symbola,DejaVu Serif,DejaVu Sans Mono,Junicode
  font.name-list.serif.x-unicode	DejaVu Serif,Symbola,Junicode,DejaVu Sans,Symbola,DejaVu Sans Mono
  font.name-list.cursive.x-unicode	Junicode,Symbola,DejaVu Sans,DejaVu Serif,DejaVu Sans Mono
  font.name-list.monospace.x-unicode	DejaVu Sans Mono,DejaVu Sans,Symbola,DejaVu Serif,Junicode

And maybe also L<Fantasy|http://shallowsky.com/blog/tech/web/firefox-cursive-fantasy.html>
  
  font.name-list.fantasy.x-unicode	Symbola,DejaVu Serif,Junicode,DejaVu Sans Mono,DejaVu Sans

If you set both C<font.*> variables with rich enough fonts, 
and C<gfx.font_rendering.fallback.always_use_cmaps>,
then you may have the best of both worlds: the situation when a character cannot
be shown via C<font.*> settings will be extremely rare, so the possiblity of delay
due to C<gfx.font_rendering.fallback.always_use_cmaps> is irrelevant.

=head2 Firefox misinterprets keypresses

=over 4

=item *

Multiple prefix keys are not supported.

=item *

C<AltGr-0> and C<Shift-AltGr-0> are recognized as a character-generating
keypress (good!), but the character they produce bears little relationship
to what keyboard produces.  (In our examples, the character may be available
only via multiple prefix keys!)

=item *

After a prefix key, C<Control-(Shift-)letter> is not recognized as a
character-generating key.

=item *

C<Kana-Enter> is not recognized as a character-generating key.

=item *

C<Alt-+-HEXDIGITS> is not recognized as a character-generating key sequence (recall
that C<Alt> should be pressed all the time, and other keys C<+ HEXDIGITS> should be
pressed+released sequentially).

=back

Of these problems, C<Chrome> has only C<Control-(Shift-)letter> one, but a very cursory inspection shows
other problems: C<Kana-arrows> are not recognized as character-generating keys.  (And IE9 just
crashes in most of these situations…)

=head2 C<AltGr>-keypresses going nowhere

Some C<AltGr>-keypresses do not result in the corresponding letter on
keyboard being inserted.  It looks like they are stolen by some system-wide
hotkeys.  See:

  http://www.kbdedit.com/manual/ex13_replacing_altgr_with_kana.html

If these keypresses would perform some action, one might be able to deduce
how to disable the hotkeys.  So the real problem comes when the keypress
is silently dropped.

I found out one scenario how this might happen, and how to fix this particular
situation.  (Unfortunately, it did not fix what I see, when C<AltGr-s> [but not
C<AltGr-S>] is stolen.)  Installing a shortcut, one can associate a hotkey to
the shortcut.  Unfortunately, the UI allows (and encourages!) hotkeys of the
form <Control-Alt-letter> (which are equivalent to C<AltGr-letter>) - instead
of safe combinations like C<Control-Alt-F4> or
C<Alt-Shift-letter> (which — by convention — are ignored by keyboard drivers, and do not generate
characters).  If/when an application linked to by this shortcut is
gone, the hotkey remains, but now it does nothing (no warning or dialogue comes).

If the shortcut is installed in one of "standard places", one can find it.
Save this to F<K:\findhotkey.vbs> (replace F<K:> by the suitable drive letter
here and below)

  on error resume next
  set WshShell = WScript.CreateObject("WScript.Shell")
  Dim A
  Dim Ag
  Set Ag=Wscript.Arguments
  If Ag.Count > 0 then
    For x = 0 to Ag.Count -1
      A = A & Ag(x)
    Next
  End If
  Set FSO = CreateObject("Scripting.FileSystemObject")
  f=FSO.GetFile(A)
  set lnk = WshShell.CreateShortcut(A)
  If lnk.hotkey <> "" then
    msgbox A & vbcrlf & lnk.hotkey
  End If

Save this to F<K:\findhotkey.cmd>

  set findhotkey=k:\findhotkey
    for /r %%A in (*.lnk) do %findhotkey%.vbs "%%A"
    for /r %%A in (*.pif) do %findhotkey%.vbs "%%A"
    for /r %%A in (*.url) do %findhotkey%.vbs "%%A"
  cd /d %UserProfile%\desktop
    for /r %%A in (*.lnk) do %findhotkey%.vbs "%%A"
    for /r %%A in (*.pif) do %findhotkey%.vbs "%%A"
    for /r %%A in (*.url) do %findhotkey%.vbs "%%A"
  cd /d %AllUsersProfile%\desktop
    for /r %%A in (*.lnk) do %findhotkey%.vbs "%%A"
    for /r %%A in (*.pif) do %findhotkey%.vbs "%%A"
    for /r %%A in (*.url) do %findhotkey%.vbs "%%A"
  cd /d %UserProfile%\Start Menu
    for /r %%A in (*.lnk) do %findhotkey%.vbs "%%A"
    for /r %%A in (*.pif) do %findhotkey%.vbs "%%A"
    for /r %%A in (*.url) do %findhotkey%.vbs "%%A"
  cd /d %AllUsersProfile%\Start Menu
    for /r %%A in (*.lnk) do %findhotkey%.vbs "%%A"
    for /r %%A in (*.pif) do %findhotkey%.vbs "%%A"
    for /r %%A in (*.url) do %findhotkey%.vbs "%%A"
  cd /d %APPDATA%
    for /r %%A in (*.lnk) do %findhotkey%.vbs "%%A"
    for /r %%A in (*.pif) do %findhotkey%.vbs "%%A"
    for /r %%A in (*.url) do %findhotkey%.vbs "%%A"
  cd /d %HOMEDRIVE%%HOMEPATH%
    for /r %%A in (*.lnk) do %findhotkey%.vbs "%%A"
    for /r %%A in (*.pif) do %findhotkey%.vbs "%%A"
    for /r %%A in (*.url) do %findhotkey%.vbs "%%A"

(In most situations, only the section after the last C<cd /d> is important;
in my configuration all the "interesting" stuff is in C<%APPDATA%>.  Running
this should find all shortcuts which define hot keys.

Run the cmd file.  Repeat in the "All users"/"Public" directory.  It should
show a dialogue for every shortcut with a hotkey it finds.  (But, as I said,
it did not fix I<my> problem: C<AltGr-s> works in F<MSKLC> test window,
and nowhere else I tried...)

=head2 C<Control-Shift>-keypresses starting bloatware applications

(Seen on IdeaPad.)  Some pre-installed programs may steal C<Control-Shift>-keypresses;
it may be hard to understand what is the name of the application even when
the stealing results in user-visible changes.

One way to deal with it is to start C<Task Manager> in C<Processes> (or
C<Details>) panel, and click on CPU column until one gets decreasing-order
of CPU percentage.  Then one can try to detect which process is becoming
active by watching top rows when the action happens (or when one manages to
get back to the desktop from the full-screen bloatware); one may need to
repeat triggering this action several times in a row.  After you know
the name of executable, you can google to find out how to disable it, and/or
whether it is safe to kill this process.

B<Example:> On IdeaPad, it was F<TouchZone.exe> (safe to kill).  It was stealing 
C<Control-Shift-R> and C<Control-Shift-T>. 

=head2 "There was a problem loading the file" from F<MSKLC>

Make line endings in F<.klc> DOSish.

=head2 C<AltGr-keys> do not work

Make line endings in F<.klc> DOSish (when given as input to F<kbdutool> -
it gives no error messages, and deadkeys work [?!]).

=head2 Error 2011 (ooo-us, line 33): There are not enough columns in the layout list.

The maximal line end of F<kbdutool> is exceeded (a line or two ahead).  Try remoing
inline comments.  If helps, change he workflow to cut off long lines (250 bytes is OK).

=head2 Only the first 8 with-modifiers columns are processed by F<kbdutool>

Time to switch to direct generation of F<.c> file?

=head2 C<Error 2012 (ooo-us-shorten.klc, line 115):>

    <ScanCode e065 - too many scancodes here to parse.>

from F<MSKLC>.  This means that the internal table of virtual keys
mapped to non-C<e0> (sic!) scancodes is overloaded.

Time to switch to direct generation of F<.c> file?  Or you need to
triage the “added” virtual keys, and decide which are less important
so you can delete them from the F<.klc> file.

=back

=cut

# '
my ($AgeList, $NamesList, $DEBUG);
sub set_NamesList ($$;$) {
    my $class = shift;
    if (ref $class) {
      $class->{NamesList} = shift;
    } else {
      $NamesList = shift
    }
    $AgeList = shift, return unless ref $class;
    $class->{AgeList} = shift;
}
sub get_NamesList ($) {
    my $self = shift;
    return $NamesList unless ref $self and defined $self->{NamesList};
    $self->{NamesList};
}
sub get_AgeList ($) {
    my $self = shift;
    return $AgeList unless ref $self and defined $self->{AgeList};
    $self->{AgeList};
}
sub new ($;$) {
    my $class = shift;
    die "too many arguments to UI::KeyboardLayout->new" if @_ > 1;
    my $data = @_ ? {%{shift()}} : {};
    bless $data, (ref $class or $class);
}

sub put_deep($$$$@) {
  my($self, $hash, $v, $k) = (shift, shift, shift, shift);
  return $self->put_deep($hash->{$k} ||= {}, $v, @_) if @_;
  $hash->{$k} = $v;
}

# Sections [foo/bar] [visual -> foo/bar]; directives foo=bar or @foo=bar,baz
sub parse_configfile ($$) {		# Trailing whitespace is ignored, whitespace about "=" is not
  my ($self, $s, %v, @KEYS) = (shift, shift);
  $s =~ s/[^\S\n]+$//gm;
  $s =~ s/^\x{FEFF}//;			# BOM are not stripped by Perl from UTF-8 files with -C31
  (my $pre, my %f) =  split m(^\[((?:visual\s*->\s*)?[\w/]*)\]\s*$ \n?)mx, $s;	# //x is needed to avoid $\
  warn "Part before the first section in configfile ignored: `$pre'" if length $pre;
  for my $k (keys %f) {
# warn "Section `$k'";
    my($v, $V, @V) = $f{$k};
    if ($k =~ s{^visual\s*->\s*}{[unparsed]/}) {		# Make sure that prefixes do not allow visual line to be confused with a config
      $v =~ s[(^(?!#|[/\@+]?\w+=).*)]//ms;			# find non-comment non-assignment
      @V = "unparsed_data=$1";
    }
# warn "xxx: @V";
    push @KEYS, $k;
    my @k = split m(/), $k;
    @k = () if "@k" eq '';				# root
    for my $l ((grep !/^#/, split(/\n/, $v)), @V) {
      die "unrecognized config file line: `$l' in `$s'"
        unless my($arr, $at, $slash, $kk, $vv) = ($l =~ m[^((?:(\@)|(/)|\+)?)(\w+)=(.*)]s);
      my $spl = $at ? qr/,/ : ( $slash ? qr[/] : qr[(?!)] );
      $vv = [ length $vv ? (split $spl, $vv, -1) : $vv ] if $arr;	# create empty element if $vv is empty
      my $slot = $self->get_deep(\%v, @k);
      if ($slot and exists $slot->{$kk}) {
        if ($arr) {
          if (ref($slot->{$kk} || 0) eq 'ARRAY') {
            $vv = [@{$slot->{$kk}}, @$vv];
          } else {
            warn "Redefinition of non-array entry `$kk' in `$k' by array one, old value ignored"
          }
        } else {
          warn "Redefinition of entry `$kk' in `$k', old value ignored"
        }
      }
# warn "Putting to the root->@k->`$kk'";
      $self->put_deep(\%v, $vv, @k, $kk);
    }
  }
  $v{'[keys]'} = \@KEYS;
# warn "config parsed";
  \%v
}

sub process_key_chunk ($$$$$) {
  my $self = shift;
  my $name = shift;
  my $skip_first = shift;
  (my $k = shift) =~ s/\p{Blank}(?=\p{NonspacingMark})//g;	# Allow combining marks to be on top of SPACE
  my $sep2 = shift;
  $k = $self->stringHEX2string($k);
  my @k = split //, $k;
  if (defined $sep2 and 3 <= @k and $k =~ /$sep2/) {		# Allow separation by $sep2, but only if too long
    @k = split /$sep2/, $k;
    shift @k if not length $k[0] and @k == 2;
    warn "Zero length expansion in the key slot <$k>\n" if not @k or grep !length, @k;
  }
  undef $k[0] if ($k[0] || '') eq "\0" and $skip_first;
  push @k, ucfirst $k[0] if @k == 1 and defined $k[0] and 1==length $k[0] and $k[0] ne ucfirst $k[0];
  $name = "VisLr=$name" if $name;
#  warn "Multi-char key in <<@k>>" if grep $_ && 1<length, @k;
  warn "More that 2 Shift-states in <<@k>>" if @k > 2;
#warn "Sep2 in $name, $skip_first, <$k> ==> <@k>\n" if defined $sep2 and $k =~ /$sep2/;
  map {defined() ? [$_, undef, undef, $name] : $_} @k;
#  @k
}	# -> list of chars

sub process_key ($$$$$$;$) {		# $sep may appear only in a beginning of the first key chunk
  my ($self, $k, $limit, $sep, $ln, $l_off, $sep2, @tr)  = (shift, shift, shift, shift, shift, shift, shift);
  my @k = split m((?!^)\Q$sep), $k;
  die "Key descriptor `$k' separated by `$sep' has too many parts: expected $limit, got ", scalar @k
    if @k > $limit;
  defined $k[$_] and $k[$_] =~ s/^--(?=.)/\0/ and $tr[$_]++ for 0..$#k;
  $k[0] = '' if $k[0] eq '--';		# Allow a filler (multi)-chunk
  map [$self->process_key_chunk( $ln->[$l_off+$_], $tr[$_], (defined($k[$_]) ? $k[$_] : ''), $sep2)], 0..$#k;
}	# -> list of arrays of chars

sub decode_kbd_layers ($@) {
  my ($self, $lineN, $row, $line_in_row, $cur_layer, @out, $N, $l0) = (shift, 0, -1);
  my %needed = qw(unparsed_data x visual_rowcount 2 visual_per_row_counts [2;2] visual_prefixes * prefix_repeat 3 in_key_separator / layer_names ???);
  my %extra  = (qw(keyline_offsets 1 in_key_separator2), undef);
  my $opt;
  for my $k (keys %needed, keys %extra) {
     my ($from) = grep exists $_->{$k}, @_, (ref $self ? $self : ());
     die "option `$k' not specified" unless $from or exists $extra{$k};
     $opt->{$k} = $from->{$k};
  }
  die "option `visual_rowcount' differs from length of `visual_per_row_counts': $opt->{visual_rowcount} vs. ", 
      scalar @{$opt->{visual_per_row_counts}} unless $opt->{visual_rowcount} == @{$opt->{visual_per_row_counts}};
  my @lines = grep !/^#/, split /\s*\n/, $opt->{unparsed_data};
  my ($C, $lc, $pref) = map $opt->{$_}, qw(visual_rowcount visual_per_row_counts visual_prefixes);
  die "Number of uncommented rows (" . scalar @lines . ") in a visual template not divisible by the rowcount $C: `$opt->{unparsed_data}'"
    if @lines % $C;
  $pref = [map {$_ eq ' ' ? qr/\s/ : qr/\Q$_/ } split(//, $pref), (' ') x $C];
#  my $line_in_row = [];
  my @counts;
  my $sep2;
  $sep2 = qr/$opt->{in_key_separator2}/ if defined $opt->{in_key_separator2};
  while (@lines) {
#    push @out, $line_in_row = [] unless $C % $c;
    $row++, $line_in_row = $cur_layer = 0 unless $lineN % $C;
    $lineN++;
    my $l1 = shift @lines;
    my $PREF = qr/(?:$pref->[$line_in_row]){$opt->{prefix_repeat}}/;
    $PREF = '\s' if $pref->[$line_in_row] eq qr/\s/;
    $l1 =~ s/\s*\x{202c}$// if $l1 =~ s/^[\x{202d}\x{202e}]//;			# remove PDF if removed LRO, RLO
    die "line $lineN in visual layers has unexpected prefix:\n\tPREF=/$PREF/\n\tLINE=`$l1'"  unless $l1 =~ s/^$PREF\s*(?<=\s)//;
    my @k1 = split /\s+(?!\p{NonspacingMark})/, $l1;
    $l0 = $l1, $N = @k1 if $line_in_row == 0;
# warn "Got keys: ", scalar @k1;
    die sprintf "number of keys in lines differ: %s vs %s in:\n\t`%s'\n\t`%s'\n\t<%s>",
      scalar @k1, $N, $l0, $l1, join(">\t<", @k1) unless @k1 == $N;		# One can always fill by --
    for my $key (@k1) {
      my @kk = $self->process_key($key, $lc->[$line_in_row], $opt->{in_key_separator}, $opt->{layer_names}, $cur_layer, $sep2);
      push @{$out[$cur_layer + $_]}, $kk[$_] || [] # (defined $kk[$_] ? [$kk[$_],undef,undef,$opt->{layer_names}[$cur_layer + $_]] : []) 
        for 0..($lc->[$line_in_row]-1);
    }
    $cur_layer += $lc->[$line_in_row++];
    push @counts, scalar @k1 if 1 == $lineN % $C;
  }
# warn "layer[0] = ", join ', ', map "@$_", @{$out[0]};
  die "Got ", scalar @out, " layers, but ", scalar @{$opt->{layer_names}}, " layer names"
    unless @out == @{$opt->{layer_names}};
  my(%seen, %out);
  $seen{$_}++ and die "Duplicate layer name `$_'" for @{$opt->{layer_names}};
  @out{ @{$opt->{layer_names}} } = @out;
  \%out, \@counts, $opt->{keyline_offsets};
}

sub decode_rect_layers ($@) {
  my ($self, $cnt, %extra, $opt, @out) = (shift, 0, qw(empty N/A));
  my %needed = qw(unparsed_data x rect_rows_cols [4;4] rect_horizontal_counts [2;2] layer_names ???);
  for my $k (keys %needed, keys %extra) {
     my ($from) = grep exists $_->{$k}, @_, (ref $self ? $self : ());
     die "option `$k' not specified" unless $from or exists $extra{$k};
     $opt->{$k} = $from->{$k};
  }
  $cnt += $_ for @{ $opt->{rect_horizontal_counts} };
  die "total of option `rect_horizontal_counts' differs from count of `layer_names': $cnt vs. ", 
      scalar @{$opt->{layer_names}} unless $cnt == @{$opt->{layer_names}};
  $cnt = @{ $opt->{rect_horizontal_counts} };
  (my $D = $opt->{unparsed_data}) =~ s/^(#.*\n)+//;
  $D =~ s/^(#.*(\n|\z))+\z//m;
  my @lines = split /\s*\n/, $D;
  my ($C, $lc, $pref) = map $opt->{$_}, qw(visual_rowcount visual_per_row_counts visual_prefixes);
  die "Number of uncommented rows (" . scalar @lines . ") in a visual rect template not matching rows(rect_rows_cols) x cnt(rect_horizontal_counts) = $opt->{rect_rows_cols}[0] x $cnt: `$opt->{unparsed_data}'"
    if @lines != $cnt * $opt->{rect_rows_cols}[0];
  my $c = 0;
  while (@lines) {
    die "Too many rect vertically: expect only ", scalar @{ $opt->{rect_horizontal_counts} }, " in `" . join("\n",'',@lines,'') . "'"
      if $c >= @{ $opt->{rect_horizontal_counts} };
    my @L = splice @lines, 0, $opt->{rect_rows_cols}[0];
    my $l = length $L[0];
    $l == length or die "Lengths of lines encoding rect do not match: expect $l, got `" . join("\n",'',@L,'') . "'" for @L[1..$#L];
    $l == $opt->{rect_rows_cols}[1] * $opt->{rect_horizontal_counts}[$c] 
      or die "Wrong line length in rect: expect $opt->{rect_rows_cols}[1] * $opt->{rect_horizontal_counts}[$c], got $l in `" 
      	. join("\n",'',@L,'') . "'" for @L[1..$#L];
    while (length $L[0]) {
      my @c;
      push @c, split //, substr $_, 0, $opt->{rect_rows_cols}[1], '' for @L;
      $_ eq $opt->{empty} and $_ = undef for @c;
      push @out, [map [$_], @c];
    }
    $c++;
  }
  die "Too few vertical rect: got $c, expect ", scalar @{ $opt->{rect_horizontal_counts} }, " in `" . join("\n",'',@lines,'') . "'"
    if $c != @{ $opt->{rect_horizontal_counts} };
  my(%seen, %out);
  $seen{$_}++ and die "Duplicate layer name `$_'" for @{$opt->{layer_names}};
  @out{ @{$opt->{layer_names}} } = @out;
  \%out, [($opt->{rect_rows_cols}[1]) x $opt->{rect_rows_cols}[0]];
}

sub get_deep ($$@) {
  my($self, $h) = (shift, shift);
  return $h unless @_;
  my $k = shift @_;
  return unless exists $h->{$k};
  $self->get_deep($h->{$k}, @_);
}

sub get_deep_via_parents ($$$@) {	# quadratic algorithm
  my($self, $h, $idx, $IDX) = (shift, shift, shift);
#warn "Deep: `@_'";
  ((defined $h) ? return $h : return) unless @_;
  my $k = pop @_;
  {
#warn "Deep::: `@_'";
    my $H = $self->get_deep($h, @_);
    (@_ or return), $IDX++, 			# Start extraction from array
      pop, redo unless exists $H->{$k};
    my $v = $H->{$k};
#warn "Deep -> `$v'";
    return $v unless ref($v || 1) and $IDX and defined $idx;
    return $v->[$idx];
  }
  return;
}

sub fill_kbd_layers ($$) {			# We do not do deep processing here...
  my($self, $h, %o, %c, %O) = (shift, shift);
  my @K = grep m(^\[unparsed]/(KBD|RECT)\b), @{$h->{'[keys]'}};
#  my $H = $h->{'[unparsed]'};
  for my $k (@K) {
    my (@parts, @h) = split m(/), $k;
    ref $self and push @h, $self->get_deep($self, @parts[1..$_]) || {} for 0..$#parts;
    push @h, $self->get_deep($h, @parts[1..$_]) || {} for 0..$#parts;		# Drop [unparsed]/ prefix...
    push @h, $self->get_deep($h,    @parts[0..$_]) || {} for -1..$#parts;
    my ($in, $counts, $offsets) = ($k =~ m(^\[unparsed]/KBD\b) ? $self->decode_kbd_layers( reverse @h )
    							       : $self->decode_rect_layers( reverse @h ) );
    exists $o{$_} and die "Visual spec `$k' overwrites exiting layer `$k'" for keys %$in;
    my $cnt = (@o{keys %$in} = values %$in);
    @c{keys %$in} = ($counts)  x $cnt;
    @O{keys %$in} = ($offsets) x $cnt if $offsets;
  }
  \%o, \%c, \%O
}

sub key2hex ($$;$) {
  my ($self, $k, $ignore) = (shift, shift, shift);
  return -1 if $ignore and not defined $k;
  return sprintf '%04x', ord $k;		# if ord $k <= 0xFFFF;
#  sprintf '%06x', ord $k;
}

sub keyORarray2hex ($$;$) {
  my ($self, $k, $ignore) = (shift, shift, shift);
  return -1 if $ignore and not defined $k;
  $k = $k->[0] if $k and ref $k;
  $self->key2hex($k, $ignore);
}

sub coverage_hex_sub($$$) {	# Unfinished!!! XXXX  UNUSED
  my ($self, $layer, $to) = (shift, shift, shift);
  ++$to->{ $self->key2hex($_->[0], 'undef_ok') }, ++$to->{ $self->key2hex($_->[1], 'undef_ok') } 
    for @{$self->{layers}{$layer}};
}

# my %MANUAL_MAP = qw( 0020 0020 00a0 00a0 2007 2007 );	# We insert entry for SPACE manually
# my %MANUAL_MAP_ch = map chr hex, %MANUAL_MAP;

sub coverage_hex($$) {
  my ($self, $face) = (shift, shift);
  my $layers = $self->{faces}{$face}{layers};
  my $to = ($self->{faces}{$face}{'[coverage_hex]'} ||= {});	# or die "Panic!";	# Synthetic faces may not have this...
  my @Layers = map $self->{layers}{$_}, @$layers;
  for my $sub (@Layers) {
    ++$to->{ $self->keyORarray2hex($_, 'undef_ok') } for map +(@$_[0,1]), @$sub;
  }
}

sub deep_copy($$) {
  my ($self, $o) = (shift, shift);
  return $o unless ref $o;
  return [map $self->deep_copy($_), @$o] if "$o" =~ /^ARRAY\(/;	# We should not have overloaded elements
  return {map $self->deep_copy($_), %$o} if "$o" =~ /^HASH\(/;
}
sub DEEP_COPY($@) {
  my ($self) = (shift);
  map $self->deep_copy($_), @_;
}

sub deep_undef_by_hash($$@) {
  my ($self, $h) = (shift, shift);
  for (@_) {
    next unless defined;
    if (ref $_) {
      die "a reference not an ARRAY in deep_undef_by_hash()" unless 'ARRAY' eq ref $_;
      $self->deep_undef_by_hash($h, @$_);
    } elsif ($h->{$_}) {
      undef $_
    }
  }
}

# Make symbols from the first half-face ($h1) to be accessible in the second face ($H1/$H2)
sub pre_link_layers ($$$;$$) {	# Un-obscure non-alphanum bindings from the first face; assign in the direction $hh ---> $HH
  my ($self, $hh, $HH, $skipfix, $skipwarn) = (shift, shift, shift, shift, shift);	# [Main, AltGr-Main,...], [Secondary, AltGr-Secondary,...]
  my ($hn,$Hn, %seen_deobsc) = map $self->{faces}{$_}{layers}, $hh, $HH;
#warn "Link $hh --> $HH;\t(@$hn) -> (@$Hn)" if "$hh $HH" =~ /00a9/i;
  die "Can't link sets of layers `$hh' `$HH' of different sizes: ", scalar @$hn, " != ", scalar @$Hn if @$hn != @$Hn;
  
  my $already_linked = $self->{faces}{$hh}{'[linked]'}{$HH}++;
  $self->{faces}{$HH}{'[linked]'}{$hh}++;
  for my $L (@$Hn) {
    next if $skipfix;
    die "Layer `$L' of face `$HH' is being relinked via `$HH' -> `$hh'???"
      if $self->{layers}{'[ini_copy]'}{$L};
#warn "ini_copy: `$L'";
    $self->{layers}{'[ini_copy]'}{$L} = $self->deep_copy($self->{layers}{$L});
  }
  for my $K (0..$#{$self->{layers}{$hn->[0]}}) {	# key number
#warn "One key data, FROM: K=$K, layer=<", join( '> <', map $self->{layers}{$_}[$K], @$Hn), '>' if "$hh $HH" =~ /00a9/i;
    my @h = map $self->{layers}{$_}[$K], @$hn;		# arrays of [lowercase,uppercase]
#warn "One key data, TO: K=$K, layer=<", join( '> <', map $self->{layers}{$_}[$K], @$Hn), '>' if "$hh $HH" =~ /00a9/i;
    my @H = map $self->{layers}{$_}[$K], @$Hn;
    my @c = map [map {($_ and ref) ? $_->[0] : $_} @$_], @h;		# deep copy, remove extra info
    my @C = map [map {($_ and ref) ? $_->[0] : $_} @$_], @H;
    # Find which of keys on $H[0] obscure symbol keys from $h[0]
    my @symb0 = grep +($c[0][$_] || '') =~ /[\W_]/, 0, 1;	# not(wordchar but not _): symbols on $h[0]
    defined $H[0][$_] or not defined $C[0][$_] or $skipwarn 
      or warn "Symbol char `$c[0][$_]' not copied to the second face while the slot is empty" 
        for @symb0;
    my @obsc = grep { defined $C[0][$_] and $c[0][$_] ne $C[0][$_]} @symb0;	# undefined positions will be copied later
#warn "K=$K,\tobs=@obsc;\tsymb0=@symb0";
    # If @obsc == 1, put on non-shifted location; may overwrite only ?-binding if it exists
    #return unless @obsc;
    my %map; 
    my @free_first = ((grep {not defined $C[1][$_]} 0, 1), grep defined $C[1][$_], 0, 1);
    @free_first = (1,0) if 1 == ($obsc[0] || 0) and $free_first[0] = 0 and not defined defined $C[1][1]; # un-Shift ONLY if needed
    @map{@obsc} = @free_first[0 .. $#obsc] unless $skipfix;
#    %map = map +($_, $free_first[$map{$_}]), keys %map;
    for my $k (keys %map) {
      if ($skipfix) {
        my $s = $k ? ' (shifted)' : '';
        warn "Key `$C[0][$k]'$s in layer $Hn->[0] does not match symbol $c[0][$k] in layer $hn->[0], and skipfix is requested...\n"
          unless ref($skipwarn || '') ? $skipwarn->{$c[0][$k]} : $skipwarn;
      } elsif (defined $C[1][$map{$k}] and ($c[0][$k] =~ /\p{Blank}/ or $C[1][$map{$k}] =~ /\p{Blank}/)) {
	warn "A hack is needed: attempt to de-obscure `$c[0][$k]' on a supplementary key with `$C[1][$map{$k}]'"
      } else {
        if (defined $C[1][$map{$k}]) {
          next if $seen_deobsc{$c[0][$k]};	# See ъЪ + palochkas obscuring \| on the secondary \|-key in RussianPhonetic
          # So far, the only "obscuring" with useful de-obscuring is when the obscuring symbol is a letter
          die "existing secondary AltGr-binding `$C[1][$map{$k}]' blocks de-obscuring `$c[0][$k]';\n symbols to de-obscure are at positions [@symb0] in [@{$c[0]}]"
            unless ($C[0][$k] || '.') =~ /[\W\d_]/;
          next
        }
        $H[1][$map{$k}] = $h[0][$k];			# !!!! Modify in place
        $seen_deobsc{$c[0][$k]}++;
      }
    }
    # Inherit keys from $h
    for my $L (0..($skipfix? -1 : $#H)) {
      for my $shift (0,1) {
        next if defined $H[$L][$shift];
        $H[$L][$shift] = $h[$L][$shift];
      }
    }
    next if $already_linked;
    for my $i (0..@$hn) {						# layer type
      for my $j (0,1) {							# case
#???        ++$seen_hex[$_]{ key2hex(($_ ? $key2 : $key1)->[$i][$j], 'undef') } for 0,1;
        push @{$self->{faces}{$hh}{need_extra_keys_to_access}{$HH}}, $H[$i][$j] if defined $C[$i][$j] and not defined $h[$i][$j];
        push @{$self->{faces}{$HH}{need_extra_keys_to_access}{$hh}}, $h[$i][$j] if defined $c[$i][$j] and not defined $H[$i][$j];

      }
    }
  }
}

# Make symbols from the first half-face ($h1) to be accessible in the second face ($H1/$H2)
sub link_layers ($$$;$$) {	# Un-obscure non-alphanum bindings from the first keyboard
  my ($self, $hh, $HH, $skipfix, $skipwarn) = (shift, shift, shift, shift, shift);	# [Main, AltGr-Main,...], [Secondary, AltGr-Secondary,...]
  $self->pre_link_layers ($hh, $HH, $skipfix, $skipwarn);
#warn "Linking with FIX: $hh, $HH" unless $skipfix;
  $self->face_make_backlinks($HH, $self->{faces}{$HH}{'[char2key_prefer_first]'}, $self->{faces}{$HH}{'[char2key_prefer_last]'}, $skipfix, 'skipwarn');
  $self->face_make_backlinks($hh, $self->{faces}{$hh}{'[char2key_prefer_first]'}, $self->{faces}{$hh}{'[char2key_prefer_last]'}, 'skip');
  $self->faces_link_via_backlinks($hh, $HH);
#  $self->faces_link_via_backlinks($HH, $hh);
}

sub face_make_backlinks($$$$;$$) {		# It is crucial to proceed layers in 
#  parallel: otherwise the semantic of char2key_prefer_first suffers
  my ($self, $F, $prefer_first, $prefer_last, $skipfix, $skipwarn) = (shift, shift, shift || {}, shift || {}, shift, shift);
#warn "Making backlinks for `$F'";
  my $LL = $self->{faces}{$F}{layers};
  if ($self->{face_back}{$F}) {		# reuse old copy
    return if $skipfix;		# reuse old copy
    die "An obsolete copy of `$F' is cashed";
  }
  my $seen = ($self->{face_back}{$F} ||= {});	# maps char to array of possitions it appears in, each [key, shift]
  # Since prefer_first should better operate in terms of keys, not layers; so the loop in $k should be the external one
  my $last = $#{ $self->{layers}{$LL->[0]} };
  my %warn;
  for my $k (0..$last) {
    for my $Lc (0..$#$LL) {
      my $L = $LL->[$Lc];
  #    $self->layer_make_backlinks($_, $prefer_first) for @$L;
      my $a = $self->{layers}{$L};
      die "Layer `$L' has lastchar $#$a, expected $last" unless $#$a == $last;
##########
      for my $shift (0..$#{$a->[$k]}) {
        next unless defined (my $c = $a->[$k][$shift]);
        $c = $c->[0] if 'ARRAY' eq ref $c;			# Treat prefix keys as usual chars
        if ($prefer_first->{$c}) {
#warn "Layer `$L' char `$c': prefer first";
	  @{ $seen->{$c} } = reverse @{ $seen->{$c} } if $seen->{$c} and $prefer_last->{$c};	# prefer 2nd of 3 (2nd from the end)
          push    @{ $seen->{$c} }, [$Lc, $k, $shift];
        } else {
          $warn{$c}++ if @{ $seen->{$c} || [] } and not $prefer_last->{$c} and $c ne ' ';	# XXXX Special-case ' ' ????
          unshift @{ $seen->{$c} }, [$Lc, $k, $shift];
        }
      }
    }
  }
  warn "The following chars appear several times in face `$F', but are not clarified\n\t(by `char2key_prefer_first', `char2key_prefer_last'):\n\t<",
    join('> <', sort keys %warn), '>' if %warn and not $skipwarn;
}

sub flip_layer_N ($$$) {		# Increases layer number if number of layers is >2 (good for order Plain/AltGr/S-Ctrl)
  my ($self, $N, $max) = (shift, shift, shift);
  return 0 if $N == $max;
  $N + 1
}

sub faces_link_via_backlinks($$$;$) {		# It is crucial to proceed layers in 
#  parallel: otherwise the semantic of char2key_prefer_first suffers
  my ($self, $F1, $F2, $no_inic) = (shift, shift, shift, shift);
  return if $self->{faces}{$F1}{'Face_link_map'}{$F2};		# Reuse old copy
#warn "Making links for `$F1' -> `$F2'";
  my $seen = $self->{face_back}{$F1} or die "Panic!";	# maps char to array of possitions it appears in, each [layer, key, shift]
  my $LL = $self->{faces}{$F2}{layers};
#!$no_inic and $self->{layers}{'[ini_copy1]'}{$_} and warn "ini_copy1 of `$_' exists" for @$LL;
#!$no_inic and $self->{layers}{'[ini_copy]'}{$_}  and warn  "ini_copy of `$_' exists" for @$LL;
  my @LL = map $self->{layers}{'[ini_copy1]'}{$_} || $self->{layers}{'[ini_copy]'}{$_} || $self->{layers}{$_}, @$LL;
  @LL = map $self->{layers}{$_}, @$LL if $no_inic;
  my($maxL, %r, %altR) = $#LL;
  # XXXX Must use $self->{layers}{'[ini_copy]'}{$L} for the target
  for my $c (sort keys %$seen) {
    my $arr = $seen->{$c};
    warn "Empty back-mapping array for `$c' in face `$F1'" unless @$arr;
#    if (@$arr > 1) {
#    }
    my ($to) = grep defined, (map {
#warn "Check `$c': <@$_> ==> <", (defined $LL[$_->[0]][$_->[1]][$_->[2]] ? $LL[$_->[0]][$_->[1]][$_->[2]] : 'undef'), '>';
				    $LL[$_->[0]][$_->[1]][$_->[2]]
				  } @$arr);
    my ($To) = grep defined, (map { $LL[$self->flip_layer_N($_->[0], $maxL)][$_->[1]][$_->[2]] } @$arr);
    $r{$c}    = $to;					# Keep prefix keys as array refs
    $altR{$c} = $To;					# Ditto
  }
  $self->{faces}{$F1}{'Face_link_map'}{$F2} = \%r;
  $self->{faces}{$F1}{'Face_link_map_INV'}{$F2} = \%altR;
}

sub charhex2key ($$) {
  my ($self, $c) = (shift, shift);
  return chr hex $c if $c =~ /^[0-9a-f]{4,}$/i;
  $c
}

sub __manyHEX($$) {			# for internal use only
  my ($self, $s) = (shift, shift);
  $s =~ s/\.?(\b[0-9a-f]{4,}\b)\.?/ chr hex $1 /ieg;
  $s
}

sub stringHEX2string ($$) {		# One may surround HEX by ".", but only if needed.  If not needed, "." is preserved...
  my ($self, $s) = (shift, shift);
  $s =~ s/(?:\b\.)?((?:\b[0-9a-f]{4,}\b(?:\.\b)?)+)/ $self->__manyHEX("$1") /ieg;
  $s
}

sub layer_recipe ($$) {
  my ($self, $l) = (shift, shift);
  return unless exists $self->{layer_recipes}{$l};
  $self->recipe2str($self->{layer_recipes}{$l})
}

sub massage_faces ($) {
  my $self = shift;
# warn "Massaging faces...";
  for my $f (keys %{$self->{faces}}) {		# Needed for (pre_)link_layers...
    next if 'HASH' ne ref $self->{faces}{$f} or $f =~ m(\bVK$);			# "parent" taking keys for a child
#warn "Massaging face `$f'...";
    unless ($self->{faces}{$f}{layers}) {
      next unless $self->{face_recipes}{$f};
      die "Can't determine number of layers in face `$f': face_recipe exists, but not numLayers" 
        unless defined (my $n = $self->{faces}{$f}{numLayers});
      warn "Massaging face `$f': use face_recipes...\n" if debug_face_layout_recipes;
      $self->{faces}{$f}{layers} = [('Empty') x $n];		# Preliminary (so know the length???)
      $self->{faces}{$f}{layers} = $self->layers_by_face_recipe($f, $f);
    }
    for my $ln ( 0..$#{$self->{faces}{$f}{layers} || []} ) {
      my $ll = my $l = $self->{faces}{$f}{layers}[$ln];
      next if $self->{layers}{$l};		# Else, auto-vivify
#warn "Creating layer `$l' for face `$f'...";
      my @r = $self->layer_recipe($l);
      $ll = $r[0] if @r;
      warn "Massaging: Using layout_recipe `$ll' for layer '$l'\n" if debug_face_layout_recipes and exists $self->{layer_recipes}{$l};
      $ll = $self->make_translated_layers($ll, $f, [$ln], '0000');
#warn "... Result `@$ll' --> $self->{layers}{$ll->[0]}";
      $self->{layers}{$l} = $self->{layers}{$ll->[0]} unless $self->{layers}{$l};		# Could autovivify in between???
    }
    for my $key ( qw( Flip_AltGr_Key Diacritic_if_undef DeadChar_DefaultTranslation DeadChar_32bitTranslation extra_report_DeadChar
    		      PrefixChains ctrl_after_modcol create_alpha_ctrl keep_missing_ctrl output_layers layers_modifiers) ) {
      $self->{faces}{$f}{"[$key]"} = $self->get_deep_via_parents($self, undef, 'faces', (split m(/), $f), $key);
    }
    $self->{faces}{$f}{'[char2key_prefer_first]'}{$_}++ 		# Make a hash
      for @{ $self->{faces}{$f}{char2key_prefer_first} || [] } ;
    $self->{faces}{$f}{'[char2key_prefer_last]'}{$_}++ 		# Make a hash
      for @{ $self->{faces}{$f}{char2key_prefer_last} || [] } ;
    (my ($seen, $seen_dead), $self->{faces}{$f}{'[dead_in_VK]'}) = $self->massage_VK($f);
    $self->{faces}{$f}{'[dead_in_VK_array]'} = $seen_dead;
    $self->{faces}{$f}{'[coverage_hex]'}{$self->key2hex($_)}++ for @$seen;
    for my $S (@{ $self->{faces}{$f}{AltGrCharSubstitutions} || []}) {
      my $s = $self->stringHEX2string($S);
      $s =~ s/\p{Blank}(?=\p{NonspacingMark})//g;
      die "Expect 2 chars in AltGr-char substitution rule; I see <$s> (from <$S>)" unless 2 == (my @s = split //, $s);
      push @{ $self->{faces}{$f}{'[AltSubstitutions]'}{$s[0]} }, [$s[1], 'manual'];
      push @{ $self->{faces}{$f}{'[AltSubstitutions]'}{lc $s[0]} }, [lc $s[1], 'manual']
        if lc $s[0] ne $s[0] and lc $s[1] ne $s[1];
      push @{ $self->{faces}{$f}{'[AltSubstitutions]'}{uc $s[0]} }, [uc $s[1], 'manual']
        if uc $s[0] ne $s[0] and uc $s[1] ne $s[1];
    }
    s/^\s+//, s/\s+$//, $_ = $self->stringHEX2string($_) for @{ $self->{faces}{$f}{Import_Prefix_Keys} || []};
    my %h = @{ $self->{faces}{$f}{Import_Prefix_Keys} || []};
    $self->{faces}{$f}{'[imported2key]'} = \%h if %h;
    my ($l0, $c);
    unless ($c = $self->{layer_counts}{$l0 = $self->{faces}{$f}{layers}[0]}) {
      $l0 = $self->get_deep_via_parents($self, undef, 'faces', (split m(/), $f), 'geometry_via_layer');
      $c = $self->{layer_counts}{$l0} if defined $l0;
    }
    my $o = $self->{layer_offsets}{$l0} if defined $l0;
    $self->{faces}{$f}{'[geometry]'} = $c if $c;
    $self->{faces}{$f}{'[g_offsets]'} = $o if $o;
  }
  for my $f (keys %{$self->{faces}}) {	# Needed for face_make_backlinks: must know which keys in faces will be finally present
    next if 'HASH' ne ref $self->{faces}{$f} or $f =~ m(\bVK$);			# "parent" taking keys for a child
    for my $F (@{ $self->{faces}{$f}{AltGrCharSubstitutionFaces} || []}) {	# Now has a chance to have real layers
      for my $L (0..$#{$self->{faces}{$f}{layers}}) {
        my $from  = $self->{faces}{$f}{layers}[$L];
        next unless my $to = $self->{faces}{$F}{layers}[$L];
        $_ = $self->{layers}{$_} for $from, $to;
        for my $k (0..$#$from) {
          next unless $from->[$k] and $to->[$k];
          for my $shift (0..1) {
            next unless defined (my $s = $from->[$k][$shift]) and defined (my $ss = $to->[$k][$shift]);
            $_ and ref and $_ = $_->[0] for $s, $ss;
            push @{ $self->{faces}{$f}{'[AltSubstitutions]'}{$s} }, [$ss, "F=$F"];
          }
        }
      }
    }  
  }		# ^^^ This is not used yet???
  for my $f (keys %{$self->{faces}}) {	# Needed for face_make_backlinks: must know which keys in faces will be finally present
    next if 'HASH' ne ref $self->{faces}{$f} or $f =~ m(\bVK$);			# "parent" taking keys for a child
    for my $N (0..$#{ $self->{faces}{$f}{AltGrCharSubstitutionLayers} || []}) {	# Now has a chance to have real layers
      my $TO = my $to = $self->{faces}{$f}{AltGrCharSubstitutionLayers}[$N];
      my $from  = $self->{faces}{$f}{layers}[$N] or next;
      $_ = $self->{layers}{$_} for $from, $to;
      for my $k (0..$#$from) {
        next unless $from->[$k] and $to->[$k];
        for my $shift (0..1) {
          next unless defined (my $s = $from->[$k][$shift]) and defined (my $ss = $to->[$k][$shift]);
          $_ and ref and $_ = $_->[0] for $s, $ss;
          push @{ $self->{faces}{$f}{'[AltSubstitutions]'}{$s} }, [$ss, "L=$TO"];
        }
      }
    }  
  }
  for my $f (keys %{$self->{faces}}) {	# Needed for face_make_backlinks: must know which keys in faces will be finally present
    next if 'HASH' ne ref $self->{faces}{$f} or $f =~ m(\bVK$);			# "parent" taking keys for a child
    my $o = $self->{faces}{$f}{LinkFace};
    $self->pre_link_layers($o, $f) if defined $o;		# May add keys to $f
  }
  for my $f (keys %{$self->{faces}}) {
    next if 'HASH' ne ref $self->{faces}{$f} or $f =~ m(\bVK$);			# "parent" taking keys for a child
    $self->face_make_backlinks($f, $self->{faces}{$f}{'[char2key_prefer_first]'}, $self->{faces}{$f}{'[char2key_prefer_last]'});
  }
  for my $f (keys %{$self->{faces}}) {
    next if 'HASH' ne ref $self->{faces}{$f} or $f =~ m(\bVK$);			# "parent" taking keys for a child
    my $o = $self->{faces}{$f}{LinkFace};
    next unless defined $o;
    $self->faces_link_via_backlinks($f, $o);
    $self->faces_link_via_backlinks($o, $f);
  }
  for my $f (keys %{$self->{faces}}) {
    next if 'HASH' ne ref $self->{faces}{$f} or $f =~ m(\bVK$);			# "parent" taking keys for a child
    my ($DDD, $export, $vk)	= map $self->{faces}{$f}{"[$_]"} ||= {}, qw(DEAD export dead_in_VK);
    my ($ddd)		= map $self->{faces}{$f}{"[$_]"} ||= [], qw(dead);
    $self->coverage_hex($f);
    my $S = $self->{faces}{$f}{layers};
    my ($c,%s,@d) = 0;
    for my $D (@{$self->{faces}{$f}{layerDeadKeys} || []}) {		# deprecated...
      $c++, next unless length $D;	# or $D ~= /^\s*--+$/ ;	# XXX How to put empty elements in an array???
      $D =~ s/^\s+//;
      (my $name, my @k) = split /\s+/, $D;
      @k = map $self->charhex2key($_), @k;
      die "name of layerDeadKeys' element in face `$f' does not match:\n\tin `$D'\n\t`$name' vs `$self->{faces}{$f}{layers}[$c]'"
        unless $self->{faces}{$f}{layers}[$c] =~ /^\Q$name\E(<.*>)?$/;	# Name might have changed in VK processing
      1 < length and die "not a character as a deadkey: `$_'" for @k;
      $ddd->[$c] = {map +($_,1), @k};
      ($s{$_}++ or push @d, $_), $DDD->{$_} = 1 for @k;
      $c++;
    }
    for my $k (split /\p{Blank}+(?:\|{3}\p{Blank}+)?/, 
    		(defined $self->{faces}{$f}{faceDeadKeys} ? $self->{faces}{$f}{faceDeadKeys} : '')) {
      next unless length $k;
      $k = $self->charhex2key($k);
      1 < length $k and die "not a character as a deadkey: `$k'";
      $ddd->[$_]{$k} = 1 for 0..$#{ $self->{faces}{$f}{layers} };	# still used...
      $DDD->{$k} = 1;
      $s{$k}++ or push @d, $k;
    }
    for my $k (split /\p{Blank}+/, (defined $self->{faces}{$f}{ExportDeadKeys} ? $self->{faces}{$f}{ExportDeadKeys} : '')) {
      next unless length $k;
      $k = $self->charhex2key($k);
      1 < length $k and die "not a character as an exported deadkey: `$k'";
      $export->{$k} = 1;
    }
    if (my $LL = $self->{faces}{$f}{'[ini_layers]'}) {
      my @out;
      for my $L ( @$LL ) {
        push @out, "$L++prefix+";
        my $l = $self->{layers}{$out[-1]} = $self->deep_copy($self->{layers}{$L});
        for my $n (0 .. $#$l) {
          my $K = $l->[$n];
          for my $k (@$K) {
#warn "face `$f' layer `$L' ini_layers_prefix: key `$k' marked as a deadkey" if defined $k and $DDD->{$k};
            $k = [$k] if defined $k and not ref $k;		# Allow addition of doc strings
            if (defined $k and ($DDD->{$k->[0]} or $vk->{$k->[0]})) {
              @$k[1,2] = ($f, ($export->{$k->[0]} ? 2 : 1));	# Is exportable?
            }
          }
        }
      }
      $self->{faces}{$f}{'[ini_layers_prefix]'} = \@out;
      $LL = $self->{faces}{$f}{'[ini_filled_layers]'} = [ @{ $self->{faces}{$f}{layers} } ];	# Deep copy
      my @OUT;
      for my $L ( @$LL ) {
        push @OUT, "$L++PREFIX+";
        my $l = $self->{layers}{$OUT[-1]} = $self->deep_copy($self->{layers}{$L});
        for my $n (0 .. $#$l) {
          my $K = $l->[$n];
          for my $k (@$K) {
#warn "face `$f' layer `$L' layers_prefix: key `$k' marked as a deadkey" if defined $k and $DDD->{$k};
            $k = [$k] if defined $k and not ref $k;		# Allow addition of doc strings
            if (defined $k and ($DDD->{$k->[0]} or $vk->{$k->[0]})) {
              @$k[1,2] = ($f, ($export->{$k->[0]} ? 2 : 1));	# Is exportable?
            }
          }
        }
      }
      $self->{faces}{$f}{layers} = \@OUT;
    } else {
      warn "Face `$f' has no ini_layers";
    }
    $self->{faces}{$f}{'[dead_array]'} = \@d;
    for my $D (@{$self->{faces}{$f}{faceDeadKeys2} || $self->{faces}{$f}{layerDeadKeys2} || []}) {	# layerDeadKeys2 obsolete
      $D =~ s/^\s+//;	$D =~ s/\s+$//;
      my @k = split //, $self->stringHEX2string($D);
      2 != @k and die "not two characters as a chained deadkey: `@k'";
#warn "dead2 for <@k>";
      $self->{faces}{$f}{'[dead2]'}{$k[0]}{$k[1]}++;
      # $k[1] is "untranslated"; it is not good for [DEAD]:
      #$self->{faces}{"$f###" . $self->key2hex($k[0])}{'[DEAD]'}{$k[1]}++;
    }
  }
  $self
}

sub massage_hash_values($) {
  my($self) = (shift);
  for my $K ( @{$self->{'[keys]'}} ) {
    my $h = $self->get_deep($self, split m(/), $K);
    $_ = $self->charhex2key($_) for @{ $h->{char2key_prefer_first} || []}, @{ $h->{char2key_prefer_last} || []};
  }

}
#use Dumpvalue;

sub print_codepoint ($$;$) {
  my ($self, $k, $prefix) = (shift, shift, shift);
  my $K = ($k =~ /$rxCombining/ ? " $k" : $k);
  $prefix = '' unless defined $prefix;
  printf "%s%s\t<%s>\t%s\n", $prefix, $self->key2hex($k), $K, $self->UName($k, 'verbose', 'vbell');  
}

sub require_unidata_age ($) {
  my $self = shift;
  my $f = $self->get_NamesList;
  $self->load_compositions($f) if defined $f;
    
  $f = $self->get_AgeList;
  $self->load_uniage($f) if defined $f and not $self->{Age};
  $self;
}

sub print_coverage_string ($$) {
  my ($self, $s, %seen) = (shift, shift);
  $seen{$_}++ for split //, $s;

  my $f = $self->get_NamesList;
  $self->load_compositions($f) if defined $f;
    
  $f = $self->get_AgeList;
  $self->load_uniage($f) if defined $f and not $self->{Age};

  require Unicode::UCD;

  $self->print_codepoint($_) for sort keys %seen;
}

sub print_coverage ($$) {
  my ($self, $F) = (shift, shift);
  
  my $f = $self->get_NamesList;
  $self->load_compositions($f) if defined $f;
    
  $f = $self->get_AgeList;
  $self->load_uniage($f) if defined $f and not $self->{Age};

  my $file = $self->{'[file]'};
  $file = (defined $file) ? "file $file" : 'string descriptor';
  my $v = $self->{VERSION};
  $file .= " version $v" if defined $v;
  $file .= " Unicode tables version $self->{uniVersion}" if defined $self->{uniVersion};
 
  print "############# Generated with UI::KeyboardLayout v$UI::KeyboardLayout::VERSION for $file, face=$F\n#\n";

  my $is32 = $self->{faces}{$F}{'[32-bit]'};
  my $cnt32 = keys %{$is32 || {}};
  my $c1 = @{ $self->{faces}{$F}{'[coverage1only]'} } - $cnt32;
  my $c2 = @{ $self->{faces}{$F}{'[coverage1]'} } - @{ $self->{faces}{$F}{'[coverage1only]'} };
  my $more = $cnt32 ? " (and $cnt32 not available on Windows - at end of this section above FFFF)" : '';
  printf "############# %i = %i + %i + %i%s [direct + via single prefix keys (%i) + via repeated prefix key]\n", 
    @{ $self->{faces}{$F}{'[coverage0]'} } + $c1 + $c2,
    scalar @{ $self->{faces}{$F}{'[coverage0]'} },
    $c1, $c2, $more, @{ $self->{faces}{$F}{'[coverage0]'} } + $c1;
  for my $k (@{ $self->{faces}{$F}{'[coverage0]'} }) {
    $self->print_codepoint($k);
  }
  print "############# Via single prefix keys:\n";
  for my $k (@{ $self->{faces}{$F}{'[coverage1only]'} }) {
    $self->print_codepoint($k);
  }
  my $h1 = $self->{faces}{$F}{'[coverage1only_hash]'};
  print "############# Via repeated prefix keys:\n";
  for my $k (@{ $self->{faces}{$F}{'[coverage1]'} }) {
    $h1->{$k} or $self->print_codepoint($k);
  }
  print "############# Have lost the competition (for prefixed position), but available elsewhere:\n";
  for my $k (sort keys %{ $self->{faces}{$F}{'[in_dia_chains]'} }) {
    next unless $self->{faces}{$F}{'[coverage_hash]'}{$k} and not $self->{faces}{$F}{'[from_dia_chains]'}{$k};
    $self->print_codepoint($k, '+ ');		# May be in from_dia_chains, but be obscured later...
  }
  print "############# Have lost the competition (not counting those explicitly prohibited by \\\\):\n";
  for my $k (sort keys %{ $self->{faces}{$F}{'[in_dia_chains]'} }) {
    next if $self->{faces}{$F}{'[coverage_hash]'}{$k};
    $self->print_codepoint($k, '- ');
  }
  my ($tot_diac, $lost_diac) = (0,0);
  $tot_diac++, $self->{faces}{$F}{'[coverage_hash]'}{$_} || $lost_diac++ 
    for keys %{ $self->{'[map2diac]'} };
  print "############# Lost among known classified modifiers/standalone/combining ($lost_diac/$tot_diac):\n";
  for my $k (sort keys %{ $self->{'[map2diac]'} }) {
    next if $self->{faces}{$F}{'[coverage_hash]'}{$k};
    $self->print_codepoint($k, '?- ');
  }
  print "############# Per key list:\n";
  $self->print_table_coverage($F);
  my ($OUT, $CC, $CC1) = ('', 0, 0);
  for my $r ([0x2200, 0x40], [0x2240, 0x40], [0x2280, 0x40], [0x22c0, 0x40], 
  	     [0x27c0, 0x30], [0x2980, 0x40], [0x29c0, 0x40], 
             [0x2a00, 0x40], [0x2a40, 0x40], [0x2a80, 0x40], [0x2ac0, 0x40], [0xa720, 0x80-0x20], [0xa780, 0x80] ) {
    my $C = join '', grep { (0xa720 >= ord $_ or $self->{UNames}{$_}) and !$self->{faces}{$F}{'[coverage_hash]'}{$_} } 
    			  map chr($_), $r->[0]..($r->[0]+$r->[1]-1);	# before a720, the tables are filled up...
    ${ $r->[0] < 0xa720 ? \$CC : \$CC1 } += length $C;
    $OUT .= "-==-\t$C\n";
  }
  print "############# Not covered in the math+latin-D ranges ($CC+$CC1):\n$OUT";
  ($OUT, $CC, $CC1) = ('', 0, 0);
  for my $r ([0x2200, 0x80], [0x2280, 0x80], 
  	     [0x27c0, 0x30], [0x2980, 0x80], 
             [0x2a00, 0x80], [0x2a80, 0x80], [0xa720, 0x100-0x20] ) {
    my $C = join '', grep {(0xa720 >= ord $_ or $self->{UNames}{$_}) and !$self->{faces}{$F}{'[coverage_hash]'}{$_} 
    			   and !$self->{faces}{$F}{'[in_dia_chains]'}{$_}} map chr($_), $r->[0]..($r->[0]+$r->[1]-1);
    ${ $r->[0] < 0xa720 ? \$CC : \$CC1 } += length $C;
    $OUT .= "-==-\t$C\n";
  }
  print "############# Not competing, in the math+latin-D ranges ($CC+$CC1):\n$OUT";
}

my %html_esc = qw( & &amp; < &lt; > &gt; );
my %ctrl_special = qw( \r Enter \n Control-Enter \b BackSpace \x7f Control-Backspace \t Tab 
  		    \x1b Esc; Control-[ \x1d Control-] \x1c Control-\ ^C Control-Break );
my %alt_symb;
{ no warnings 'qw';
# 		ZWS	ZWNJ ZWJ	 LRM RLM WJ=ZWNBSP Func	  Times Sep Plus
  my %a = (qw(200b ∅ 200c ‸ 200d & 200e → 200f ← 2060 ⊕ 2061 () 2062 × 2063 | 2064 +),
		# SPC	NBSP	obs-N obs-M 	n	m 	m/3 m/4	  m/6 figure=digit punctuation thin hair    Soft-hyphen
	     qw(0020 ␣ 00a0 ⍽ 2000 N 2001 M 2002 n 2003 m 2004 ᵐ⁄₃ 2005 ᵐ⁄₄ 2006 ᵐ⁄₆ 2007 ᵈ 2008 , 2009 ᵐ⁄₅ 200a ᵐ⁄₈ 00ad -),
		# LineSep ParSep LRE	RLE PopDirForm LRO RLO narrowNBSP
	     qw(2028 ⏎ 2029 ¶ 202a ⇒ 202b ⇐ 202c ↺ 202d ⇉ 202e ⇇ 202f ⁿ));
  @alt_symb{map chr hex, keys %a} = values %a;
}

# Make: span for control, soft-hyphen, white-space; include in <span class=l> with popup; include in span with special highlight
sub char_2_html_span ($$$$$$;@) {
   my ($self, $base_c, $C, $c, $F, $opts, @types, $expl, $title, $vbell) = @_;
   my $aInv = $self->charhex2key($self->{faces}{$F}{'[Flip_AltGr_Key]'});
   $expl = $C->[3] if 'ARRAY' eq ref $C and $C->[3];
   $expl =~ s/(?=\p{NonspacingMark})/ /g if $expl;
   my $prefix = (ref $C and $C->[2]);
   my $cc = $c;
   $aInv = ($base_c || 'N/A') eq $aInv;
   my $docs = ($prefix and $self->{faces}{$F}{'[prefixDocs]'}{$self->key2hex($cc)});	# or $pre and warn "No docs: face=`$F', c=`$cc'\n";
   $docs =~ s/([''&])/sprintf '&#x%02x;', ord $1/ge if defined $docs;
# warn "... is_D2: ", $self->array2string([$c, $baseK[$L][$shift]]);
   $c =~ s/(?=$rxCombining)/\x{25cc}/go;	# dotted circle ◌ 25CC
   $c =~ s/([&<>])/$html_esc{$1}/g;
   my $create_a_c = $self->{faces}{$F}{'[create_alpha_ctrl]'};
   $create_a_c = $create_alpha_ctrl unless defined $create_a_c;
   my $alpha_ctrl = ($create_a_c and $cc =~ /[\cA-\cZ]/);
   my $with_shift = (($create_a_c > 1 and $alpha_ctrl) ? '(Shift-)' : '');
   $c =~ s{([\x00-\x1F\x7F])}{ my $C = $self->control2prt("$1"); my $S = $ctrl_special{$C} || '';
   			       ($S and $S .= ", "), $S .= "Control-$with_shift".chr(0x40+ord $1) if $alpha_ctrl;
                               $C = "<span class=yyy title='$S'>$C</span>" if $S; $C }ge;
   my $type = ($cc =~ /[^\P{Blank}\x00-\x1f]/ && 'WS');		# Blank and not control char
   my ($fill, $prefill, $zw) = ('', '');
   if ($type or $c =~ /(\p{Line_Break: ZW}|[\xAD\x{200b}-\x{200f}\x{2060}-\x{2064}\x{fe00}-\x{fe0f}])$/) {
     my $alt = ($alt_symb{$cc} ? qq( convention="$alt_symb{$cc}") : '');
     $fill = "<span$alt class=lFILL></span>";			# Soft hyphen etc
   }
   if ($type) {				# Putting WS inside l makes gaps between adjacent WS blocks
     $prefill = '<span class=WS>';
     $fill .= '</span>';
   }
   push @types, 'no-mirror-rtl' if "\x{34f}" eq $cc;	# CGJ
   $zw = !!$fill || $cc eq "\x{034f}";
   $vbell = !defined $C;
   unless (defined $title) {
           $title = ((ord $cc >= 0x80 or $cc eq ' ') && sprintf '%04X  %s', ord $cc, $self->UName($cc, 'verbose', $vbell));
           if ($title and $docs) {
             $title = "$docs (on $title)";
           }
           $title ||= ($docs || '');
           if (defined $expl and length $expl and (1 or 0x7f <= ord $cc)) {
             $title .= ' ' if length $title;
             $title .= " {via $expl}";
           }
           $title .= ' (visual bell indicates unassigned keypress)' if $title and !$expl and $vbell;
           $title = 'This prefix key accesses this column with AltGr-invertion' if $aInv;
           $title =~ s/([''&])/sprintf '&#x%02x;', ord $1/ge if $title;
           $title = qq( title='$title') if $title;
   }
   if ($type) {					# Already covered
   } elsif ($zw) {
     push @types,'ZW';
   } elsif (not defined $C) {
     push @types,'vbell';
   } elsif ($title =~ /(\b(N-ARY|BIG(?!\s+YUS\b)|GREEK\s+PROSGEGRAMMENI|KORONIS|SOF\s+PASUQ|PUNCTUATION\s+(?:GERESH|GERSHAYIM)|PALOCHKA|CYRILLIC\s.*\s(DZE|JE|QA|WE|A\s+IE)|ANO\s+TELEIA|GREEK\s+QUESTION\s+MARK)|"\w+\s+(?:BIG|LARGE))\b.*\s+\[/) {	# "0134	BIG GUY#"
     push @types,'nAry';
   } elsif ($title =~ /\b(OPERATOR|SIGN|SYMBOL|PROOF|EXISTS|FOR\s+ALL|(DIVISION|LOGICAL)\b.*)\s+\[/) {
     push @types,'operator';
   } elsif ($title =~ /\b(RELATION|PERPENDICULAR|PARALLEL\s*TO|DIVIDES|FRACTION\s+SLASH)\s+\[/) { 
     push @types,'relation';
   } elsif ($title =~ /\[.*\b(IPA)\b|\bCLICK\b/) { 
     push @types,'ipa';
   } elsif ($title =~ /\bLETTER\s+[AEUIYO]\b/ and 
            $title =~ /\b(WITH|AND)\s+(HOOK\s+ABOVE|HORN)|(\s+(WITH|AND)\s+(CIRCUMFLEX|BREVE|ACUTE|GRAVE|TILDE|DOT\s+BELOW)\b){2}/) { 
     push @types,'viet';
   } elsif (0 <= index(lc '⁊ǷꝥƕǶᵹ', lc $cc) or 0xa730 <= ord $cc and 0xa78b > ord $cc or 0xa7fb <= ord $cc and 0xa7ff >= ord $cc) { 
     push @types,'paleo';
   } elsif ($title =~ /(\s+(WITH|AND)\s+((DOUBLE\s+)?\w+(\s+(BELOW|ABOVE))?)\b){2}/) { 
     push @types,'doubleaccent';
   }
   push @types, ($1 ? 'withSubst' : 'isSubst') if ($expl || '') =~ /\sSubst\{(\S*\}\s+\S)?/;
   push @types, 'altGrInv' if $aInv;
   my $q = (@types > 1 ? "'" : '');
#   ($prefill, $fill) = ("<span class=l$title>$prefill", "$fill</span>");
   @types = " class=$q@types$q" if @types;
   my($T,$OPT) = ($opts && $opts->{ltr} ? ('bdo', ' dir=ltr') : ('span', ''));	# Just `span´ does not work in FF15
   $c = '†' if $aInv and $cc ne ($base_c || 'N/A');	# &nbsp;
   "<$T$OPT@types$title>$prefill$c$fill</$T>"
}

sub print_table_coverage ($$;$) {
  my ($self, $F, $html) = (shift, shift, shift);
  my $f = $self->{'[file]'};
  $f = (defined $f) ? "file $f" : 'string descriptor';
  my $v = $self->{VERSION};
  $f .= " version $v" if defined $v;
  $f .= " Unicode tables version $self->{uniVersion}" if defined $self->{uniVersion};
  print <<EOP if $html;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
  "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
<!-- Generated with UI::KeyboardLayout v$UI::KeyboardLayout::VERSION for $f, face=$F -->
<style type="text/css"><!--
  /* <!-- Font size 10pt OK with Landscape Letter PaperSize, 0.1in margins, no footer, %96 for Latin, %150 for Cyrillic of izKeys --> */
  table.coverage	{ font-size: 10pt; font-family: DejaVu Sans; }
  .dead			{ font-size: 50%; color: red; }
  .dead_i		{ font-size: 50%; background-color: red; color: white; }
  .altGrInv		{ font-size: 70%; background-color: red; }
  .vbell		{ color: SandyBrown; }
  .withSubst		{ outline: 1px dotted blue;  outline-offset: -1px; }
  .isSubst		{ outline: 1px solid blue;  outline-offset: -1px; }
  .operator		{ background-color: rgb(255,192,203)	/*pink*/; }
  .relation		{ background-color: rgb(255,160,122)	/*lightsalmon*/; }
  .ipa			{ background-color: rgb(173,255,47)	/*greenyellow*/; }
  .nAry			{ background-color: rgb(144,238,144)	/*lightgreen*/; }
  .paleo		{ background-color: rgb(240,230,140)	/*Khaki*/; }
  .viet			{ background-color: rgb(220,220,220)	/*Gainsboro*/; }
  .doubleaccent		{ background-color: rgb(255,228,196)	/*Bisque*/; }
  .ZW			{ background-color: rgb(220,20,60)	/*crimson*/; }
  .WS			{ background-color: rgb(128,0,0)	/*maroon*/; }
  span.lFILL[convention]:before		{ content: attr(convention); 
					  color: white; 
					  font-size: 50%; }
  .lFILL:not([convention])	{ margin: 0ex 0.35ex; }
  .l			{ margin: 0ex 0.06ex; }
  .yyy			{ padding: 0px !important; }
  td.headerbase		{ font-size: 50%; color: blue; }
  td.header		{ font-size: 50%; color: green; }
  table			{ border-collapse: collapse; margin: 0px; padding: 0px; }
  body			{ margin: 1px; padding: 0px; }
  tr, td, .yyy {
    padding: 0px 0.2ex !important;
    margin:  0px       !important;
    border:  0px       !important;
  }
  tr.headerRow		{ border-bottom:	1px solid green	!important;}
  tr.lastKeyInKRow	{ border-bottom:	1px solid red	!important;}
  tr:hover		{ background-color:	#fff6f6; }
  tr.headerRow:hover	{ background-color:	#fff; }

  col.column1		{ border-right:		1px solid green	!important;}
  col.endPair		{ border-right:		1px solid SandyBrown	!important;}
  col.pre_ExtraCols	{ border-right:		1px solid green	!important;}

//--></style> 
</head>
<body>
<table class=coverage>
EOP
  my($LL, $INV, %s, @d, %access, %docs) = ($self->{faces}{$F}{layers}, $self->{faces}{$F}{'[Flip_AltGr_Key]'});
  $s{$self->charhex2key($INV)}++ if defined $INV;	# Skip in reports	'
  my @LL = map $self->{layers}{$_}, @$LL;
  $s{$_}++ or push @d, $_ for map @{ $self->{faces}{$F}{"[$_]"} || [] }, qw(dead_array dead_in_VK_array extra_report_DeadChar);
  my (@A, %isD2, @Dface, %d_seen) = [];
#warn 'prefix keys to report: <', join('> <', @d), '>';
  for my $ddK (@d) {
    (my $dK = $ddK) =~ s/^\s+//;
    my $c = $self->key2hex($self->charhex2key($dK));
    next if $d_seen{$c}++;
    warn("??? Skip prefix key `$c' for face `$F', k=`$dK'"), next unless defined (my $FF = $self->{faces}{$F}{'[deadkeyFace]'}{$c});
    $access{$FF} = [$self->charhex2key($dK)];
    push @Dface, $FF;
    $docs{$FF} = $self->{faces}{$F}{'[prefixDocs]'}{$c};	# and warn "Found docs: face=`$F', c=`$c'\n";
    push @A, [$self->charhex2key($dK)];
  }

  my ($lastDface, $prevCol, $COLS, @colOrn, %S, @joinedPairs) = ($#Dface, -1, '', [qw(0 column1)]);
  for my $kk (split /\p{Blank}+\|{3}\p{Blank}+/, 
  		(defined $self->{faces}{$F}{faceDeadKeys} ? $self->{faces}{$F}{faceDeadKeys} : ''), -1) {
    my $cnt = 0;
    length and $cnt++ for split /\p{Blank}+/, $kk;
    push @joinedPairs, $cnt;
  }
  pop @joinedPairs;
  my $done = 0;
  push @colOrn, [$done += $_, 'endPair'] for @joinedPairs;

  for my $reported (1, 0) {
    for my $DD (@{ $self->{faces}{$F}{$reported ? 'LayoutTable_add_double_prefix_keys' : 'faceDeadKeys2'} }) {
      (my $dd = $DD) =~ s/^\s+//;
      # XXXX BUG in PERL???  This gives 3:  DB<4> x scalar (my ($x, $y) = split //, 'ab')
      2 == (my (@D) = split //, $self->stringHEX2string($dd)) or die "Not a double character in LayoutTable_add_double_prefix_keys for `$F': `$DD' -> `", $self->stringHEX2string($dd), "'";
      my $Dead1 = $self->{faces}{$F}{'[deadkeyFace]'}{$self->key2hex($D[0])} 
        or ($reported ? die "Can't find prefix key face for `$D[0]' in `$F'" : next);	# inverted faces bring havoc
      my $map1 = $self->linked_faces_2_hex_map($F, $Dead1);
      defined (my $Dead2 = $map1->{$self->key2hex($D[1])}) or die "Can't map `$D[1]' in `$F'+prefix `$D[0]'";	# in hex already
      $Dead2 = $Dead2->[0] if 'ARRAY' eq ref $Dead2;
      defined (my $ddd = $self->{faces}{$F}{'[deadkeyFace]'}{$Dead2}) or die "Can't find prefix key face for `$D[1]' -> `$Dead2' in `$F'+prefix `$D[0]'";
      next if $S{"@D"}++;
      push @Dface, $ddd if $reported;
      $access{$ddd} ||= \@D;
      $docs{$ddd} = $self->{faces}{$F}{'[prefixDocs]'}{$Dead2};
      push @A, \@D if $reported;
# warn "set is_D2: @D";
      $isD2{$D[0]}{$D[1]}++;
    }
  }
  push @colOrn, [$lastDface+1, 'pre_ExtraCols'] if $#Dface != $lastDface;
  for my $orn (@colOrn) {
    my $skip = $orn->[0] - $prevCol - 1;
    warn("Multiple classes on columns of report unsupported: face=$F, col [@$orn]"), next if $skip < 0;
    $prevCol = $orn->[0];
    my $many = $skip > 1 ? " span=$skip" : '';
    $skip = $skip > 0 ? "\n    <col$many />" : '';
    $COLS .= "$skip\n    <col class=$orn->[1] />";
  }
  print <<EOP if $html;
  <colgroup>$COLS
  </colgroup>
EOP
  my ($k, $first_ctrl, $post_ctrl, @last_in_row) = (-1, map $self->{faces}{$F}{"[$_]"} || 0, qw(start_ctrl end_ctrl));
  $last_in_row[ $k += $_ ]++ for @{ $self->{faces}{$F}{'[geometry]'} || [] };
#warn 'prefix key faces to report: <', join('> <', @Dface), '>';
  my @maps = (undef, map $_ && $self->linked_faces_2_hex_map($F, $_), @Dface);	# element of Dface may be false if this is non-autonamed AltGr-inverted face
  my $dead   = $html ? "<span class=dead   title='what follows is a prefix key; find the corresponding column'>\x{2620}</span>" : "\x{2620}";
  my $dead_i = $html ? "<span class=dead_i title='what follows is a prefix key with AltGr-invertion; find the matching column'>\x{2620}</span>" : "\x{2620}";
  my $header = '';
  for my $dFace ('', @Dface) {		# '' is no-dead
    my $base_t = 'Characters immediately on keys (without prefix keys); first two are without/with Shift, two others same with AltGr (excluding the special-key zone)';
    my $prefix_t = 'After tapping a prefix key, the base keys are replaced by what is in the column of the prefix key';
    $header .= qq(    <td align=center class=headerbase title=' '><span title='$base_t'>↓Base</span> <span title='$prefix_t'>Prefix→</span></td>), next unless $dFace;
    my @a = map {(my $a = $_) =~ s/^(?=$rxCombining)/\x{25cc}/o; $a } @{ $access{$dFace} };
    my $docs = $docs{$dFace};
    $docs =~ s/([''&])/sprintf '&#x%02x;', ord $1/ge if $docs;
    my $withDocs = (defined $docs ? "<span title='$docs'>@a</span>" : "@a");
    $header .= "    <td align=center class=header>$withDocs</td>";
  }
  print "  <thead><tr class=headerRow title='Prefix key (or key sequence) accessing this column.  To find how to type the prefix key, find it preceded by ☠ in the table below (mostly in the base column)'>$header</tr></thead>\n  <tbody>\n"
    if $html;
  my $vbell = '♪';
  for my $n ( 0 .. $#{ $LL[0] } ) {
    my ($out, @KKK, $base_c) = '';
    my @baseK;
    next if $n >= $first_ctrl and $n < $post_ctrl;
    for my $dn (0..@Dface) {		# 0 is no-dead
      next if $dn and not $maps[$dn];
      $out .= $html ? '</td><td>' : "\t" if length $out;
      my $is_D2 = $isD2{ @{$A[$dn]} == 1 ? $A[$dn][0] : 'n/a' };		
# warn "is_D2: ", $self->array2string([$dn, $is_D2, $A[$dn], $A[$dn][0]]);
      my $o = '';
      for my $L (0..$#$LL) {
        for my $shift (0..1) {
          my $c = $LL[$L][$n][$shift];
          my ($pre, $expl, $C, $expl1, $invert_dead) = ('', '', $c);
          $o .= ' ', next unless defined $c;
          $pre = $dead    if not $dn and 'ARRAY' eq ref $c and $c->[2];
          $c = $c->[0]    if 'ARRAY' eq ref $c;
          $KKK[$L][$shift] = $c unless $dn;
          $base_c = $KKK[$L][$shift];
#	warn "int_struct -> dead; face `$F', KeyPos=$n, Mods=$L, shift=$shift, ch=$c\n" if $pre;
          if ($dn) {
            $C = $c = $maps[$dn]{$self->key2hex($c)};
            $c = $vbell unless defined $c;
            $invert_dead = (3 == ($c->[2] || 0) || (3 << 3) == ($c->[2] || 0)) if ref $c;
            $pre = $invert_dead ? $dead_i : $dead if 'ARRAY' eq ref $c and $c->[2];
	    $c = $c->[0]    if 'ARRAY' eq ref $c;
	    $c = $self->charhex2key($c);
          } else {
#            warn "coverage0_prefix -> dead; face `$F', KeyPos=$n, Mods=$L, shift=$shift, ch=$c\n" if $self->{faces}{$F}{'[coverage0_prefix]'}{$c};
            $invert_dead = (3 == ($c->[2] || 0) || (3 << 3) == ($c->[2] || 0)) if ref $c;
            $pre = $invert_dead ? $dead_i : $dead if $pre or $self->{faces}{$F}{'[coverage0_prefix]'}{$c};
          }
	  $baseK[$L][$shift] = $c unless $dn;
	  $pre ||= $dead if $dn and $is_D2->{$baseK[$L][$shift]};

	  if ($html) {
	    $c = $self->char_2_html_span($base_c, $C, $c, $F, {ltr => 1}, 'l');
	  } else {
            $c =~ s/(?=$rxCombining)/\x{25cc}/go;	# dotted circle ◌ 25CC
            $c =~ s{([\x00-\x1F\x7F])}{ $self->control2prt("$1") }ge;
          }
          $c = "$pre$c";
          $o .= $c;
        }
      }
      $out .= $o;
    }
    my $class = $last_in_row[$n] ? ' class=lastKeyInKRow' : '';
    $out = "    <tr$class><td><bdo dir=ltr>$out</bdo></td></tr>" if $html;	# Do not make RTL chars mix up the order
    print "$out\n";
  }
  my @extra = map {(my $s = $_) =~ s/^\s+//; "\n\n<p>$s"} @{ $self->{faces}{$F}{TableSummaryAddHTML} || [] };
  print <<EOP if $html;
  </tbody>
</table>

@extra<p>Highlights (homographs and special needs): zero-width or SOFT HYPHEN: <span class=ZW><span class=l title="ANY ZEROWIDTH CHAR"><span class=lFILL></span></span></span>, whitespace: <span class=WS><span class=l title="ANY SPACE CHAR"> <span class=lFILL></span></span></span>, <span class=viet>Vietnamese</span>; <span class=doubleaccent>other double-accent</span>; <span class=paleo>paleo-Latin</span>; 
or <span class=ipa>IPA</span>.
Or name having <span class=relation>RELATION, PERPENDICULAR,
PARALLEL, DIVIDES, FRACTION SLASH</span>; or <span class=nAry>BIG, LARGE, N-ARY, CYRILLIC PALOCHKA/DZE/JE/QA/WE/A-IE, 
ANO TELEIA, KORONIS, PROSGEGRAMMENI, GREEK QUESTION MARK, SOF PASUQ, PUNCTUATION GERESH/GERSHAYIM</span>; or <span class=operator>OPERATOR, SIGN, 
SYMBOL, PROOF, EXISTS, FOR ALL, DIVISION, LOGICAL</span>; or <span class=altGrInv>AltGr-inverter prefix</span>;
or via a rule <span class=withSubst>involving</span>/<span class=isSubst>exposing</span> a “BlueKey” substitution rule.
(Some browsers fail to show highlights for whitespace/zero-width.)
<p>Vertical lines separate: the column of the base face, paired 
prefix keys with “inverted bindings”, and explicitly selected multi-key prefixes.  Horizontal lines separate key rows of
the keyboard (including a fake row with the “left extra key” [one with <code>&lt;&gt;</code> or <code>\\|</code> - it is missing on many keyboards]
and the <code>KP_Decimal</code> key [often marked as <code>. Del</code> on numeric keypad]); the last group is for semi-fake keys for
<code>Enter/C-Enter/Backspace/C-Backspace/Tab</code> and <code>C-Break/[/]/\\</code> (make sense after prefix keys) and special keys explicitly added
in <b>.kbdd</b> files (usually <code>SPACE</code>).
<p>Hover mouse over any appropriate place to get more information.
In popups: brackets enclose Script, Range, “1st Unicode version with this character”;
braces enclose “the reason why this position was assigned to this character” (<code>VisLr</code> means that a visual table was 
used; in <code>Subst{HOW}</code>, <code>L=Layer</code> and <code>F=Face</code> mean that a “BlueKey” substitution rule was defined
via a special layer/face).
</body>
</html>
EOP
}

sub coverage_face0 ($$;$) {
  my ($self, $F, $after_import) = (shift, shift, shift);
  my $H = $self->{faces}{$F};
  my $LL = $H->{layers};
  return $H->{'[coverage0]'} if exists $H->{'[coverage0]'};
  my (%seen, %seen_prefix, %imported);
  my $d = { %{ $H->{'[DEAD]'} || {} }, %{ $H->{'[dead_in_VK]'} || {} } };
  # warn "coverage0 for `$F'" if $after_import;
  for my $l (@$LL) {
    my $L = $self->{layers}{$l};
    for my $k (@$L) {
      warn "Face `$F', layer `$l': coverage check is run too late: after the importation translation is performed"         		   
      					    if not $after_import and $F !~ /^(.*)##Inv#([a-f0-9]{4,})$/is and grep {defined and ref and $_->[4]} @$k;
      $seen{ref() ? $_->[0] : $_}++	   for grep {defined and !(ref and $_->[2]) and !$d->{ref() ? $_->[0] : $_}} @$k;
      $seen_prefix{ref() ? $_->[0] : $_}++ for grep {defined and (ref and $_->[2] or $d->{ref() ? $_->[0] : $_})} @$k;
      $imported{"$_->[0]:$_->[1]"}++	   for grep {defined and ref and 2 == ($_->[2] || 0)} @$k;		# exportable
    }
  }
  $H->{'[coverage0_prefix]'} = \%seen_prefix;
  $H->{'[coverage0]'} = [sort keys %seen];
  $H->{'[imported]'} = [sort keys %imported];
}

# %imported is analysed: if manual deadkey is specified, this value is used, otherwised new value is generated and rememebered.
#   (but is not put in the keymap???]
sub massage_imported ($$) {
  my ($self, $f) = (shift, shift);
  return unless my ($F, $KKK) = $f =~ /^(.*)###([a-f0-9]{4,})$/is;
  my $H = $self->{faces}{$F};
  for my $i ( @{ $self->{faces}{$f}{'[imported]'} || [] } ) {
    my($k,$face) = $i =~ /^(.):(.*)/s or die "Unrecognized imported: `$i'";
    my $K;
    if (exists $H->{'[imported2key]'}{$i} or exists $H->{'[imported2key_auto]'}{$i}) {
      $K = exists $H->{'[imported2key]'}{$i} ? $H->{'[imported2key]'}{$i} : $H->{'[imported2key_auto]'}{$i};
    } elsif ($H->{'[coverage0_prefix]'}{$k} or $H->{'[auto_dead]'}{$k}) {	# it is already used
      # Assign a fake prefix key to imported map
      warn("Imported prefix keys exist, but Auto_Diacritic_Start is not defined in face `$F'"), return 
        unless defined $H->{'[first_auto_dead]'};
      $K = $H->{'[imported2key_auto]'}{$i} = $self->next_auto_dead($H);
    } else {		# preserve the prefix key
      $K = $H->{'[imported2key_auto]'}{$i} = $k;
      $H->{'[auto_dead]'}{$k}++;
    }
    my $LL = $self->{faces}{$face}{'[deadkeyLayers]'}{$self->key2hex($k)}
      or die "Cannot import a deadkey `$k' from `$face'";
    $LL = [@$LL];		# Deep copy, so may override
    my $KK = $self->key2hex($K);
    if (my $over = $H->{'[AdddeadkeyLayers]'}{$KK}) {
#warn "face `$F': additional bindings for deadkey $KK exist.\n";
      $LL = [$self->make_translated_layers_stack($over, $LL)];
    }
    $H->{'[imported2key_all]'}{"$k:$face"} = $self->charhex2key($KK);
    $H->{'[deadkeyLayers]'}{$KK} = $LL;
    my $new_facename = "$F#\@#\@#\@$i";
    $self->{faces}{$new_facename}{layers} = $LL;
    $H->{'[deadkeyFace]'}{$KK} = $new_facename;
    $self->link_layers($F, $new_facename, 'skipfix', 'no-slot-warn');

    $self->coverage_face0($new_facename);
  }
}

sub massage_imported2 ($$) {
  my ($self, $f) = (shift, shift);
  warn "... Importing into face=`$f" if debug_import;
  return unless my ($F, $KKK) = ($f =~ /^(.*)###([a-f0-9]{4,})$/is);		# what about multiple prefixes???
  return unless my $HH = $self->{faces}{$F}{'[imported2key_all]'};
  my $H  = $self->{faces}{$f};
  warn "Importing into face=`$F' prefix=$KKK" if debug_import;
  my $LL = $H->{layers};
  my @unresolved;
  for my $l (@$LL) {
    my $L = $self->{layers}{$l};
    for my $k (@$L) {
      for my $kk (grep {defined and ref and $_->[2]} @$k) {	# exportable
        $kk = [@$kk];		# deep copy
        if (2 == $kk->[2]) {	# exportable
          my $v = (defined $kk->[4] ? $kk->[4] : $kk->[0]);
          my $j = $HH->{"$v:$kk->[1]"};
  #        push(@unresolved, "$v:$kk->[1]"),
            warn "Can't resolve `$v:$kk->[1]' to an imported dead key, face=`$F' prefix=$KKK; layer=$l" 
              unless defined $j;
          warn "Importing `$v:$kk->[1]' as `$j', face=`$F' prefix=$KKK; layer=$l" if debug_import;
          @$kk[0,4] = ($j, $v);
        } else {
          #warn "massage_imported2: shift $kk->[2] <<= 3 key `$kk->[0]' face `$f' layer `$l'\n" if $kk->[2] >> 3;
          $kk->[2] >>= 3;		# ByPairs makes <<= 3 !
        }
      }
    }
  }
  delete $self->{faces}{$f}{'[coverage0]'};
  $self->coverage_face0($f, 'after_import');		# recalculate
#  $H->{'[unresolved_imported]'} = \@unresolved if @unresolved;
}

sub massage_char_substitutions($$) {	# Read $self->{Substitutions}
  my($self, $data) = (shift, shift);
  die "Too late to load char substitutions" if $self->{Compositions};
  for my $K (keys %{ $data->{Substitutions} || {}}) {
    my $arr = $data->{Substitutions}{$K};
    for my $S (@$arr) {
      my $s = $self->stringHEX2string($S);
      $s =~ s/\p{Blank}(?=\p{NonspacingMark})//g;
      die "Expect 2 chars in substitution rule; I see <$s> (from <$S>)" unless 2 == (my @s = split //, $s);
      $self->{'[Substitutions]'}{"<subst-$K>"}{$s[0]} = [[0, $s[1]]];	# Format as in Compositions
      $self->{'[Substitutions]'}{"<subst-$K>"}{lc $s[0]} = [[0, lc $s[1]]]
        if lc $s[0] ne $s[0] and lc $s[1] ne $s[1];
      $self->{'[Substitutions]'}{"<subst-$K>"}{uc $s[0]} = [[0, uc $s[1]]]
        if uc $s[0] ne $s[0] and uc $s[1] ne $s[1];
    }
  }
}

sub new_from_configfile ($$) {
  my ($class, $F) = (shift, shift);
  open my $f, '< :utf8', $F or die "Can't open `$F' for read: $!";
  my $s = do {local $/; <$f>};
  close $f or die "Can't close `$F' for read: $!";
#warn "Got `$s'";
  my $self = $class->new_from_configfile_string($s);
  $self->{'[file]'} = $F;
  $self;
}

sub new_from_configfile_string ($$) {
    my ($class, $ss) = (shift, shift);
    die "too many arguments to UI::KeyboardLayout->new_from_configfile" if @_;
    my $data = $class->parse_configfile($ss);
# Dumpvalue->new()->dumpValue($data);
    my ($layers, $counts, $offsets) = $class->fill_kbd_layers($data);
    @{$data->{layers}}{keys %$layers} = values %$layers;
    @{$data->{layer_counts} }{keys %$counts} = values %$counts;
    @{$data->{layer_offsets}}{keys %$offsets} = values %$offsets;
    $data = bless $data, (ref $class or $class);
    $data->massage_hash_values;
    $data->massage_diacritics;			# Read $self->{Diacritics}
    $data->massage_char_substitutions($data);	# Read $self->{Substitutions}
    $data->massage_faces;
    
    $data->massage_deadkeys_win($data);		# Process (embedded) MSKLC-style deadkey maps
    $data->create_composite_layers;		# Needs to be after simple deadkey maps are known

    for my $F (keys %{ $data->{faces} }) {
      next if 'HASH' ne ref $data->{faces}{$F} or $F =~ /\bVK$/;			# "parent" taking keys for a child
      $data->coverage_face0($F);		# creates coverage0, imported array (c0 excludes diacritics), coverage0_prefix hash
    }
    for my $F (keys %{ $data->{faces} }) {
      next if 'HASH' ne ref $data->{faces}{$F} or $F =~ /\bVK$/;			# "parent" taking keys for a child
      $data->massage_imported($F);		# calc new values for imported prefix keys, augments imported maps with Add-maps
    }
    for my $F (keys %{ $data->{faces} }) {
      next if 'HASH' ne ref $data->{faces}{$F} or $F =~ /\bVK$/;			# "parent" taking keys for a child
      $data->massage_imported2($F);		# changes imported prefix keys to appropriate values for the target personality
    }
    $data->create_prefix_chains;
    $data->create_inverted_faces;
    $data->link_composite_layers;		# Needs to be after imported keys are reassigned...

    for my $F (keys %{ $data->{faces} }) {	# Finally, collect the stats
      next if 'HASH' ne ref $data->{faces}{$F} or $F =~ /\bVK$/;			# "parent" taking keys for a child
      next if $F =~ /#\@?#\@?(Inv)?#\@?/;		# Face-on-a-deadkey
      my($seen_prefix, %seen0, %seen00, %seen1, %seen1only) = $data->{faces}{$F}{'[coverage0_prefix]'};
      # warn("Face `$F' has no [deadkeyFace]"), 
      next unless $data->{faces}{$F}{'[deadkeyFace]'};
#      next;
      my (%check_later, %coverage1_prefix);
#      warn "......  face `$F',\tprefixes0 ", keys %$seen_prefix;
#      $seen_prefix = {%$seen_prefix};			# Deep copy
#      $seen_prefix->{$_}++ for @{ $data->{faces}{$F}{'[dead_in_VK_array]'} || [] };
      for my $deadKEY ( sort keys %{ $data->{faces}{$F}{'[deadkeyFace]'}} ) {
        unless (%seen0) {				# Do not calculate if $F has no deadkeys...
          $seen0{$_}++ for @{ $data->{faces}{$F}{'[coverage0]'} };
          %seen00 = %seen0;
        }
        ### XXXXX Directly linked faces may have some chars unreachable via the switch-prefixKey
        my ($deadKey, $not_in_0) = $data->charhex2key($deadKEY);
        # It does not make sense to not include it into the summary: 0483 on US is such...
        $not_in_0++, $check_later{$deadKey}++ unless $seen_prefix->{$deadKey};
        my ($FFF, @dd2) = $data->{faces}{$F}{'[deadkeyFace]'}{$deadKEY};
        my $cov2 = $data->{faces}{$FFF}{'[coverage0]'} 
          or warn("Deadkey `$deadKey' on face `$F' -> unmassaged face"), next;
        ($seen0{$_}++ or $seen1{$_}++), $not_in_0 || $seen00{$_} || $seen1only{$_}++
          for map {ref() ? $_->[0] : $_} grep !(ref and $_->[2]), @$cov2;	# Skip 2nd level deadkeys
        if (my $d2 = $data->{faces}{$F}{'[dead2]'}{$deadKey}) {
          my $map = $data->linked_faces_2_hex_map($F, $FFF);
#          warn "linked map (face=$F) = ", keys %$d2;
          @dd2 = map $data->charhex2key($_), map {($_ and ref $_) ? $_->[0] : $_} map $map->{$data->key2hex($_)}, keys %$d2;
#          warn "sub-D2 (face=$F) = ", @dd2;
        }
        #warn "2nd level prefixes for `$deadKey': ",  keys %{$data->{faces}{$FFF}{'[coverage0_prefix]'} || {}};
        #warn "2nd level prefixes for `$deadKey':  <@dd2> ", keys %{$data->{faces}{$F}{'[dead2]'}{$deadKey} || {}};
        unless ($not_in_0) {
#          warn "sub-cov0 (face=$F) = ", keys %{ $data->{faces}{$FFF}{'[coverage0_prefix]'} || {} };
          $coverage1_prefix{$_}++  for keys %{ $data->{faces}{$FFF}{'[coverage0_prefix]'} || {} };
#          warn "sub-D2 (face=$F) = ", @dd2;
          $coverage1_prefix{$_}++  for @dd2;
        }
#        warn "......  deadkey `$deadKey' reached0 in face `$F'" unless $not_in_0;
      }
      my @check = grep !$coverage1_prefix{$_}, keys %check_later;
      my $_s = (@check > 1 ? 's' : '');
      warn("Prefix key$_s <@check> not reached (without double prefix keys?) in face `$F'; later=", keys %check_later, " ; cov1=", keys %coverage1_prefix) if @check;
      $data->{faces}{$F}{'[coverage1]'} = [sort keys %seen1];
      $data->{faces}{$F}{'[coverage1only]'} = [sort keys %seen1only];
      $data->{faces}{$F}{'[coverage1only_hash]'} = \%seen1only;
      $data->{faces}{$F}{'[coverage_hash]'} = \%seen0;
    }
    $data
}

sub massage_deadkeys_win ($$) {
  my($self, $h, @process, @to) = (shift, shift);
  my @K = grep m(^\[unparsed]/DEADKEYS\b), @{$h->{'[keys]'}};
# warn "Found deadkey sections `@K'";
#  my $H = $h->{'[unparsed]'};
  for my $k (@K) {
    push @process, $self->get_deep($h, (split m(/), $k), 'unparsed_data');
    (my $k1 = $k) =~ s(^\[unparsed]/)();
    push @to, $k1
  }
  @K = grep m(^DEADKEYS\b), @{$h->{'[keys]'}};
  for my $k (@K) {
    my $slot = $self->get_deep($h, split m(/), $k);
    next unless exists $slot->{klc_filename};
    open my $fh, '< :encoding(UTF-16)', $slot->{klc_filename}
      or die "open of <klc_filename>=`$slot->{klc_filename}' failed: $!";
    local $/;
    my $in = <$fh>;
    push @process, $in;
    push @to, $k;
  }
  for my $k1 (@to) {
#warn "DK sec `$k' -> `$v', <", join('> <', keys %{$h->{'[unparsed]'}{DEADKEYS}{la_ru}}), ">";
#warn "DK sec `$k' -> `$v', <$h->{'[unparsed]'}{DEADKEYS}{la_ru}{unparsed_data}>";
    my $v = shift @process; 
    my($o,$d,$t) = $self->read_deadkeys_win($v);	# Translation tables, names, rest of input
    my (@parts, @h) = split m(/), $k1;
    my %seen = (%$o, %$d);
    for my $kk (keys %seen) {
#warn "DK sec `$k1', deadkey `$kk'. Map: ", $self->array2string( [%{$o->{$kk} || {}}] );
      my $slot = $self->get_deep($h, @parts, $kk);
      warn "Deadkey `$kk' defined for `$k1' conflicts with previous definition" 
        if $slot and grep exists $slot->{$_}, qw(map name);
      $self->put_deep($h, $o->{$kk}, @parts, $kk, 'map')  if exists $o->{$kk};
      $self->put_deep($h, $d->{$kk}, @parts, $kk, 'name') if exists $d->{$kk};
    }
  }
  $self
}

# http://bepo.fr/wiki/Pilote_Windows
# http://www.phon.ucl.ac.uk/home/wells/dia/diacritics-revised.htm#two
# http://msdn.microsoft.com/en-us/library/windows/desktop/ms646280%28v=vs.85%29.aspx

my %oem_keys = do {{ no warnings 'qw' ; reverse (qw(
     OEM_MINUS	-
     OEM_PLUS	=
     OEM_4	[
     OEM_6	]
     OEM_1	;
     OEM_7	'
     OEM_3	`
     OEM_5	\
     OEM_COMMA	,
     OEM_PERIOD	.
     OEM_2	/
     OEM_102	\#
     SPACE	#
     DECIMAL	.#
     ABNT_C2	/#
     ABNT_C2	¥
     ABNT_C2	¦
)) }};			#'# Here # marks "second occurence" of keys...

	# For type 4 of keyboard (same as types 1,3, except OEM_AX, (NON)CONVERT, ABNT_C1)
	#   except KANA,(NON)CONVERT,; scancode of YEN,| for OEM_8 is our invention; after OEM_8 all is junk (non-scancodes???)...
my %scan_codes = (reverse qw(
  02	1
  03	2
  04	3
  05	4
  06	5
  07	6
  08	7
  09	8
  0a	9
  0b	0
  0c	OEM_MINUS
  0d	OEM_PLUS
  10	Q
  11	W
  12	E
  13	R
  14	T
  15	Y
  16	U
  17	I
  18	O
  19	P
  1a	OEM_4
  1b	OEM_6
  1e	A
  1f	S
  20	D
  21	F
  22	G
  23	H
  24	J
  25	K
  26	L
  27	OEM_1
  28	OEM_7
  29	OEM_3
  2b	OEM_5
  2c	Z
  2d	X
  2e	C
  2f	V
  30	B
  31	N
  32	M
  33	OEM_COMMA
  34	OEM_PERIOD
  35	OEM_2
  39	SPACE
  56	OEM_102
  53	DECIMAL

  01	ESCAPE
  0C	OEM_MINUS
  0D	OEM_PLUS
  0E	BACK
  0F	TAB
  1A	OEM_4
  1B	OEM_6
  1C	RETURN
  1D	LCONTROL
  27	OEM_1
  28	OEM_7
  29	OEM_3
  2A	LSHIFT
  2B	OEM_5
  33	OEM_COMMA
  34	OEM_PERIOD
  35	OEM_2
  36	RSHIFT
  37	MULTIPLY
  38	LMENU
  3A	CAPITAL
  3B	F1
  3C	F2
  3D	F3
  3E	F4
  3F	F5
  40	F6
  41	F7
  42	F8
  43	F9
  44	F10
  45	NUMLOCK
  46	SCROLL
  47	HOME
  48	UP
  49	PRIOR
  4A	SUBTRACT
  4B	LEFT
  4C	CLEAR
  4D	RIGHT
  4E	ADD
  4F	END
  50	DOWN
  51	NEXT
  52	INSERT
  e053	DELETE
  54	SNAPSHOT
  56	OEM_102
  57	F11
  58	F12
  59	CLEAR
  5A	OEM_WSCTRL
  5B	OEM_FINISH
  5C	OEM_JUMP
  5C	OEM_AX
  5D	EREOF
  5E	OEM_BACKTAB
  5F	OEM_AUTO
  62	ZOOM
  63	HELP
  64	F13
  65	F14
  66	F15
  67	F16
  68	F17
  69	F18
  6A	F19
  6B	F20
  6C	F21
  6D	F22
  6E	F23
  6F	OEM_PA3
  70	KANA
  71	OEM_RESET
  73	ABNT_C1
  76	F24
  79	CONVERT
  7B	NONCONVERT
  7B	OEM_PA1
  7C	TAB
  7E	ABNT_C2
  7F	OEM_PA2
  e010	MEDIA_PREV_TRACK
  e019	MEDIA_NEXT_TRACK
  e01C	RETURN
  e01D	RCONTROL
  e020	VOLUME_MUTE
  e021	LAUNCH_APP2
  e022	MEDIA_PLAY_PAUSE
  e024	MEDIA_STOP
  e02E	VOLUME_DOWN
  e030	VOLUME_UP
  e032	BROWSER_HOME
  e035	DIVIDE
  e037	SNAPSHOT
  e038	RMENU
  e046	CANCEL
  e047	HOME
  e048	UP
  e049	PRIOR
  e04B	LEFT
  e04D	RIGHT
  e04F	END
  e050	DOWN
  e051	NEXT
  e052	INSERT
  e053	DELETE
  e05B	LWIN
  e05C	RWIN
  e05D	APPS
  e05E	POWER
  e05F	SLEEP
  e065	BROWSER_SEARCH
  e066	BROWSER_FAVORITES
  e067	BROWSER_REFRESH
  e068	BROWSER_STOP
  e069	BROWSER_FORWARD
  e06A	BROWSER_BACK
  e06B	LAUNCH_APP1
  e06C	LAUNCH_MAIL
  e06D	LAUNCH_MEDIA_SELECT
  e11D	PAUSE

  7D	OEM_8

  10	SHIFT
  11	CONTROL
  12	MENU
  15	KANA
  15	HANGUL
  17	JUNJA
  18	FINAL
  19	HANJA
  19	KANJI
  1C	CONVERT
  1D	NONCONVERT
  1E	ACCEPT
  1F	MODECHANGE
  29	SELECT
  2A	PRINT
  2B	EXECUTE

  60	NUMPAD0
  61	NUMPAD1
  62	NUMPAD2
  63	NUMPAD3
  64	NUMPAD4
  65	NUMPAD5
  66	NUMPAD6
  67	NUMPAD7
  68	NUMPAD8
  69	NUMPAD9
  6C	SEPARATOR
  B4	MEDIA_LAUNCH_MAIL
  B5	MEDIA_LAUNCH_MEDIA_SELECT
  B6	MEDIA_LAUNCH_APP1
  B7	MEDIA_LAUNCH_APP2

  E5	PROCESSKEY
  E7	PACKET
  F6	ATTN
  F7	CRSEL
  F8	EXSEL
  FA	PLAY
  FC	NONAME
  FD	PA1
  FE	OEM_CLEAR

));	# http://www.opensource.apple.com/source/WebCore/WebCore-1C25/platform/gdk/KeyboardCodes.h
	# the part after PAUSE is junk...

# [ ] \ space
my %oem_control = (qw(
	OEM_4	[001b
	OEM_6	]001d
	OEM_5	\001c
	SPACE	0020
	OEM_102	\001c
));	# In ru layouts, only entries which match the char are present
my %do_control = map /^(.)(.+)/, values %oem_control;
$do_control{' '} = '0020';
delete $do_control{0};

my %default_bind = ( (map {( "NUMPAD$_" => [[$_]] )} 0..9 ),
		     TAB	=> [["\t", "\t"]],
		     ADD	=> [["+", "+"]],
		     SUBTRACT	=> [["-", "-"]],
		     MULTIPLY	=> [["*", "*"]],
		     DIVIDE	=> [["/", "/"]],
		     RETURN	=> [["\r", "\r"], ["\n"]],
		     BACK	=> [["\b", "\b"], ["\x7f"]],
		     ESCAPE	=> [["\e", "\e"], ["\e"]],
		     CANCEL	=> [["\cC", "\cC"], ["\cC"]],
		   );

sub get_VK ($$) {
  my ($self, $f) = (shift, shift);
  $self->get_deep_via_parents($self, undef, 'faces', (split m(/), $f), 'VK') || {}
#  $self->{faces}{$f}{VK} || {}
}

sub massage_VK ($$) {
  my ($self, $f, %seen, %seen_dead, @dead, @ctrl) = (shift, shift);
  my $l0 = $self->{faces}{$f}{layers}[0];
  $self->{faces}{$f}{'[non_VK]'} = @{ $self->{layers}{$l0} };
  my $create_a_c = $self->{faces}{$f}{'[create_alpha_ctrl]'};
  $create_a_c = $create_alpha_ctrl unless defined $create_a_c;
  my $EXTR = [["\r","\n"],["\b","\x7F"],["\t","\cC"],["\x1b","\x1d"],["\x1c", ($create_a_c ? "\cZ" : ())]]; # Enter/C-Enter/Bsp/C-Bsp/Tab/Cancel/Esc=C-[/C-]/C-\ C-z
  if ($create_a_c) {
    my %s;
    push @ctrl, scalar @$EXTR;
    $s{$_}++ for $self->flatten_arrays($EXTR);
    my @ctrl_l = grep !$s{$_}, map chr($_), 1..26;
    push @$EXTR, [shift @ctrl_l, shift @ctrl_l] while @ctrl_l > 1;
    push @$EXTR, [@ctrl_l] if @ctrl_l;
    push @ctrl, scalar @$EXTR;
  }
  my @extra = ( $EXTR, map [([]) x @$EXTR], 1..$#{ $self->{faces}{$f}{layers} } );
  my $VK = $self->get_VK($f);
  for my $k (sort keys %$VK) {
    my ($v, @C) = $VK->{$k};
    $v->[0] = $scan_codes{$k} or die("Can't find the scancode for the VK key `$k'")
      unless length $v->[0];
# warn 'Key: <', join('> <', @$v), '>';
    my $c = 0;
    for my $k (@$v[1..$#$v]) {
      ($k, my $dead) = ($k =~ /^(.+?)(\@?)$/) or die "Empty key in VK list";
      $seen{$k eq '-1' ? '' : ($k = $self->charhex2key($k))}++;
      $seen_dead{$k}++ or push @dead, $k if $dead and $k ne '-1';
      my $kk = ($k eq '-1' ? undef : $k);
      push @{ $extra[int($c/2)] }, [] unless $c % 2;
      push @{ $extra[int($c/2)][-1] }, $kk;		# $extra[$N] is [[$k0, $k1] ...]
      $kk .= $dead if defined $kk;
      push @C, $kk;
      $c++;
    }
# warn 'Key: <', join('> <', @C), '>';
    @$v = ($v->[0], @C);
  }
  $self->{faces}{$f}{'[ini_layers]'} = [ @{ $self->{faces}{$f}{layers} } ];	# Deep copy
  if (@extra) {
    my @Ln;
    for my $l (0 .. $#{ $self->{faces}{$f}{layers} } ) {
      my $oLn = my $Ln = $self->{faces}{$f}{layers}[$l];
      my $L = $self->{layers}{$Ln};
      my @L = map [$_->[0], $_->[1]], @$L;		# Each element is []; deep copy
      my $ln = @$L;
      $self->{faces}{$f}{'[start_ctrl0]'} = @$L;
      $self->{faces}{$f}{'[start_ctrl]'} = @$L + ($ctrl[0]||0);
      $self->{faces}{$f}{'[end_ctrl]'}   = @$L + ($ctrl[1]||0);
      push @L, @{ $extra[$l] };
      push @Ln, ($Ln .= "<$f>");
      $self->{layers}{$Ln} = \@L;
      # At this moment ini_copy should not exist yet
warn "ini_copy of `$oLn' exists; --> `$Ln'" if $self->{layers}{'[ini_copy]'}{$oLn};
#      $self->{layers}{'[ini_copy]'}{$Ln} = $self->{layers}{'[ini_copy]'}{$oLn} if $self->{layers}{'[ini_copy]'}{$oLn};
#???    Why does not this works???
#warn "ini_copy1: `$Ln' --> `$oLn'";
       $self->{layers}{'[ini_copy1]'}{$Ln} = $self->deep_copy($self->{layers}{$oLn});
    }
    $self->{faces}{$f}{layers} = \@Ln;
  }
  ([keys %seen], \@dead, \%seen_dead)
}

sub format_key ($$$$) {
  my ($self, $k, $dead, $used) = (shift, shift, shift, shift);
  return -1 unless defined $k;
  my $mod = ($dead ? '@' : '') and $used->{$k}++;
  return "$k$mod" if $k =~ /^[A-Z0-9]$/i;
  return '%%' if 1 != length $k or ord $k > 0xFFFF;
  $self->key2hex($k) . $mod;
}

sub auto_capslock($$) {
  my ($self, $u) = (shift, shift);
  my %fix = qw( ӏ Ӏ );		# Perl 5.8.8 uc is wrong
  return 1 if defined $u->[0] and defined $u->[1] and $u->[0] ne $u->[1] and ($fix{$u->[0]} || uc($u->[0])) eq $u->[1];
  return 0;
}

my %double_scan_VK = ('56 OEM_102' => '73 ABNT_C1',	# ISO vs JIS keyboard
		      '7E ABNT_C2' => '7D OEM_8',	# ABNT vs JIS keyboard
		      '7B NONCONVERT' => '79 CONVERT');	# JIS keyboard: left of SPACE, right of SPACE
{ my(%seen, %seen_scan, %seen_VK, @add_scan_VK, @ligatures, @decimal);
  sub reset_units ($) { @decimal = @ligatures = @add_scan_VK = %seen_scan = %seen_VK = %seen = () }

  sub output_unit00 ($$$$$$$;$$) {
    my ($self, $face, $k, $u, $N, $deadkeys, $Used, $known_scancode, $skippable) = (shift, shift, shift, shift, shift, shift, shift, shift, shift);
    my $sc = ($known_scancode or $scan_codes{$k}) or warn("Can't find the scancode for the key `$k'"), return;
    my(@cntrl, %s, $cnt);						# Set Control-KEY if is [ or ] or \
    $u = [map { defined() ? [map {($_ and ref $_) ? $_->[0] : $_} @$_] : $_ } @$u];	# deep copy with $_->[0] on a key-array
    @cntrl = chr hex $do_control{$u->[0][0]}		if $do_control{$u->[0][0] || 'N/A'};	# \ ---> ^\
    @cntrl = @{ $default_bind{$k}[1] } if !@cntrl and $default_bind{$k}[1];
    my $create_a_c = $self->{faces}{$face}{'[create_alpha_ctrl]'};
    $create_a_c = $create_alpha_ctrl unless defined $create_a_c;
    @cntrl = (chr(0x1F & ord $k)) x $create_a_c if $k =~ /^[A-Z]$/ and $create_a_c;
    $deadkeys ||= [];	# known_scancode is true when we start from VK, and $deadkeys is (arr of arrays) vs (hash per layer)
    my @KK = map [$_->[2], $_->[0], ($known_scancode ? $_->[3][$_->[1]]  :  $_->[3]{defined $_->[2] ? $_->[2] : 'n/a'})],
	       map [@$_[0,1], $u->[$_->[0]][$_->[1]], $deadkeys->[$_->[0]]], 
	         map +([$_, 0], [$_, 1]), 0..$#$u;
    defined and $s{$_}++ for map $_->[0], @KK;
    $cnt = keys %s || @cntrl;
    if (my $extra = $self->{faces}{$face}{'[output_layers]'} and defined $N) {	# $N not supported on VK...
      my $b = @{ $self->{faces}{$face}{layers} };
      for my $f ($b..$#$extra) {
#        warn "Extra layer number $f, base=$b requested while the character N=$N has " . (scalar @$u) . " layers" if $f+$b <= $#$u;
        (my $lll = $extra->[$f]) =~ s/^prefix(NOTSAME(case)?)?=// or die "Extra layer: expected `prefix=PREFIX', see: `$extra->[$f]'";
        my($notsame, $case) = ($1,$2);
        my $c = $self->key2hex($self->charhex2key($lll));
        my $L = $self->{faces}{$face}{'[deadkeyLayers]'}{$c} or die "Unknown prefix character `$c´ in extra layers";
        my @L = map $self->{layers}{$_}[$N], @$L;
        my(@CC, @pp, @OK);
        for my $l (@L[0 .. ($notsame ? $b-1 : 0)]) {
          my(%s1, @was);
          for my $sh (0..$#$l) {
            my @C = map {defined() ? (ref() ? $self->dead_with_inversion(!'hex', $_, $face, $self->{faces}{$face}) : $_) : $_} $l->[$sh];
            my @p = map {defined() ? (ref() ? $_->[2] : 0 ) : 0 } $l->[$sh];
            ($CC[$sh], $pp[$sh]) = ($C[0], $p[0]) if not defined $CC[$sh] and defined $C[0];
            ($CC[$sh], $pp[$sh], $OK[$sh], $s1{$C[0]}) = ($C[0], $p[0], 1,1) if !$OK[$sh] and defined $C[0] and not $s{$C[0]};
            ($CC[$sh], $pp[$sh], $OK[$sh], $s1{$was[0]}) = (@was, 1,1)		# use unshifted if needed
              if $sh and !$OK[$sh] and defined $C[0] and defined $was[0] and not $s{$was[0]} and not $s1{$was[0]};
            @was = ($C[0], $p[0]) unless $sh;		# may omit `unless´
            $cnt++ if defined $CC[$sh];
          }
        }
        # Avoid read-only values (can get via $#KK) which cannot be autovivified
        push @KK, ([]) x (2*$f - @KK) if @KK < 2*$f;		# splice can't do with a gap after the end of array
        splice @KK, 2*$f, 0, map [$CC[$_], $f-$b, $pp[$_]], 0..$#CC;
      }
    }
    return if $skippable and not $cnt;
    if ($skippable and not defined $KK[0][0] and not defined $KK[1][0]) {
      for my $shft (0,1) {
        $KK[$shft] = [$default_bind{$k}[0][$shft], 0] if defined $default_bind{$k}[0][$shft];
###        $KK[$shft] = [$decimal[$shft], 0] if $k eq 'DECIMAL' and @decimal;
      }
    }
    my $pre_ctrl = $self->{faces}{$face}{'[ctrl_after_modcol]'};
    $pre_ctrl = 2*$ctrl_after unless defined $pre_ctrl;
    $#cntrl = $create_a_c - 1 if $pre_ctrl < 2*@$u or $self->{faces}{$face}{'[keep_missing_ctrl]'};
    warn "cac=$create_a_c  #cntrl=$#cntrl pre=$pre_ctrl \@u=", scalar @$u if $#cntrl < 2*$ctrl_after - 1;
    splice @KK, $pre_ctrl, 0, map [$_, 0], @cntrl;
    
    if ($k eq 'DECIMAL') {	# may be described both via visual maps and NUMPAD
      my @d = @{ $decimal[1] || [] };
      !defined $KK[$_][0] and $KK[$_] = $d[$_] for 0..$#d;	# fill on the second round
      @decimal = ([$self->output_unit_KK($k, $u, $sc, $Used, @KK)], [@KK]); 
      return;
    }
    $self->output_unit_KK($k, $u, $sc, $Used, @KK);
  }
  
  sub output_unit_KK($$@) {
    my ($self, $k, $u, $sc, $Used, @KK) = @_;
    my @K = map $self->format_key($_->[0], $_->[2], $Used->[$_->[1] || 0]), @KK;
#warn "keys with ligatures: <@K>" if grep $K[$_] eq '%%', 0..$#K;
    push @ligatures, map [$k, $_, $KK[$_][0]], grep $K[$_] eq '%%', 0..$#K;
    my $keys = join "\t", @K;
    my @kk = map $_->[0], @KK;
    my $fill = ((8 <= length $k) ? '' : "\t");
    my $expl = join ", ", map +(defined() ? (0x20 > ord() ? '^'.chr(0x40+ord) : $_) : ' '), @kk;
    my $expl1 = exists $self->{UNames} ? "\t// " . join ", ", map +((defined $_) ? $self->UName($_) : ' '), @kk : '';
    my $capslock = ($self->auto_capslock($u->[0])) | (($self->auto_capslock($u->[1])) << 2);
    $seen_scan{$sc}++;
    $seen_VK{$k}++;
    ($sc, $k, $fill, <<EOP);
$capslock\t$keys\t// $expl$expl1
EOP
  }

  sub output_unit0 ($$$$$$$;$$) {
    my @i = &output_unit00 or return;
    my $add = $double_scan_VK{uc "$i[0] $i[1]"};
#warn "<<<<< Secondary key <$add> for <$i[0] $i[1]>" if $add;
    push @add_scan_VK, [split(/ /, $add), @i[2,3]] if $add;
    "$i[0]\t$i[1]$i[2]\t$i[3]"
  }
  
  sub output_added_units ($) {
    my (@i, @o);
    for my $i (@add_scan_VK) {
      next if $seen_scan{$i->[0]} or $seen_VK{$i->[1]};	# Cannot duplicate either one...
      push @i, $i;
    }
    for my $i (@i, (@decimal ? $decimal[0] : ()) ) {
      push @o, "$i->[0]\t$i->[1]$i->[2]\t$i->[3]";
    }
    @o
  }
  
  my $enc_UTF16LE;
  sub output_ligatures ($) {
    my ($self, @o) = shift;
    for my $l (@ligatures) {
      my $k = $l->[2];
      unless ($k =~ /^[\x00-\x{FFFF}]*$/) {
        (require Encode), $enc_UTF16LE = Encode::find_encoding('UTF-16LE') unless $enc_UTF16LE;
        die "Can't arrange encoding to UTF-16LE" unless $enc_UTF16LE;
        $k = $enc_UTF16LE->encode($k);
#        warn join '> <', ($k =~ /(..)/sg);	# Can't use decode() on surrogates...
#        warn join '> <', map {unpack 'v', $_} ($k =~ /(..)/sg);	# Can't use decode() on surrogates...
        $k = join '', map chr(unpack 'v', $_), ($k =~ /(..)/sg);	# Can't use decode() on surrogates...
      }
      my @k = ((map $self->key2hex($_), split //, $k), ('') x 4);
      my @expl = exists $self->{UNames} ? "// " . join " + ", map $self->UName($_), split //, $l->[2] : ();
      my $add = ((8 <= length $l->[0]) ? '' : "\t");
      push @o, (join "\t", "$l->[0]$add", $l->[1], @k[0..3], @expl) . "\n";
    }
    @o
  }

  sub output_unit ($$$$$$$$) {
    my ($self, $face, $layers, $basesub, $u, $deadkeys, $Used, $lim, $c, $k) = (shift, shift, shift, shift, shift, shift, shift, shift);
    my $U = [map $self->{layers}{$_}[$u], @$layers];
    if ($u < $lim) {
      $c = $self->{layers}{$basesub}[$u][0];
      $c = $c->[0] if 'ARRAY' eq ref $c;
      $k = uc $c;
      $c .= '#' if $seen{$c}++;
      $k = $oem_keys{$c} or warn("Can't find a key with VKEY `$c', unit=$u, lim=$lim"), return
        unless $k =~ /^[A-Z0-9]$/;
    } else {
      my $keys = grep defined, map $self->flatten_arrays($_->[$u]), @$U;
      for my $v (values %start_SEC) {
        $k = $v->[2]($self, $u, $v), last if $v->[0] <= $u and $v->[0] + $v->[1] > $u;
      }
      ($keys and warn("Can't find the range of keys to which unit `$u' belongs")), return unless defined $k;
    }
    $self->output_unit0($face, $k, $U, $u, $deadkeys, $Used, undef, $u >= $lim);
  }
}

sub output_layout_win ($$$$$$$) {
  my ($self, $face, $layers, $basesub, $deadkeys, $Used, $cnt) = (shift, shift, shift, shift, shift, shift, shift);
  $basesub = $layers->[0] unless defined $basesub;
  $self->reset_units;
  die "Count of non-VK entries mismatched: $cnt vs ", scalar @{$self->{layers}{$layers->[0]}}
    unless $cnt <= scalar @{$self->{layers}{$layers->[0]}};
  my $ocnt = $cnt;
####### Temporarily disable
  $cnt < $_->[0] + $_->[1] and $cnt = $_->[0] + $_->[1] for values %start_SEC;
  map $self->output_unit($face, $layers, $basesub, $_, $deadkeys, $Used, $ocnt), 0..$cnt-1;
}

sub output_VK_win ($$$) {
  my ($self, $face, $Used, @O) = (shift, shift, shift);
  my $VK = $self->get_VK($face);
  for my $k (keys %$VK) {
    my $v = $VK->{$k};
# warn 'Key: <', join('> <', @$v), '>';
    my (@dead) = map +(/^(.+)\@$/ ? [$1, 1] : [$_]), @$v[1..$#$v];
    my (@k, @o, @oo, $x, $y) = map $_->[0], @dead;
    @dead = map $_->[1], @dead;
    push @o,  [$x, $y] while @dead and ($x, $y) = splice @dead, 0, 2;
    push @oo, [$x, $y] while @k    and ($x, $y) = splice @k,    0, 2;
    push @O, $self->output_unit0($face, $k, \@oo, undef, \@o, $Used, $v->[0]);
  }
  @O
}

sub read_deadkeys_win ($$) {
   my ($self, $t, $dead, $next, @p, %o) = (shift, shift, '', '');

   $t =~ s(\s*//.*)()g;		# remove comments
   $t =~ s([^\S\n]+$)()gm;		# remove trailing whitespace (including \r!)
   # deadkey lines, empty lines, HEX HEX keymap lines
   $t =~ s/(^(?=DEADKEY)(?:(?:(?:DEADKEY|\s*[0-9a-f]{4,})\s+[0-9a-f]{4,})?(?:\n|\E))*)(?=(.*))/DEADKEYS\n\n/mi
     and ($dead, $next) = ($1, $2);
   warn "Unknown keyword follows deadkey descriptions in MSKLC map file: `$next'; dead=<$dead>"
     if length $next and not $next =~ /^(KEYNAME|KEYNAME_EXT|KEYNAME_DEAD|DESCRIPTIONS|LANGUAGENAMES|ENDKBD)$/i;
#   $dead =~ /\S/ or warn "EMPTY DEADKEY section";
#warn "got `$dead' from `$t'";

   # when a pattern has parens, split does not remove the leading empty fields (?!!!)
   (undef, my %d) = split /^DEADKEY\s+([0-9a-f]+)\s*\n/im, $dead;
   for my $d (keys %d) {
#warn "split `$d' from `$d{$d}'";
     @p = split /\n+/, $d{$d};
     my @bad;
     die "unrecognized part in deadkey map for $d: `@bad'"
       if @bad = grep !/^\s*([0-9a-f]+)\s+([0-9a-f]+)$/i, @p;
     %{$o{lc $d}} = map /^\s*([0-9a-f]+)\s+([0-9a-f]+)/i, @p;
   }
   
   # empty lines, HEX "NAME" lines
   if ($t =~ s/^KEYNAME_DEAD\n((?:(?:\s*[0-9a-f]{4,}\s+".*")?(?:\n|\E))*)(?=(.*))/KEYNAMES_DEAD\n\n/mi) {
     ($dead, $next) = ($1,$2);
     warn "Unknown keyword follows deadkey names descriptions in MSKLC map file: `$next'"
       if length $next and not $next =~ /^(DEADKEY|KEYNAME|KEYNAME_EXT|KEYNAME_DEAD|DESCRIPTIONS|LANGUAGENAMES|ENDKBD)$/i;
     $dead =~ /\S/ or warn "EMPTY KEYNAME_DEAD section";
     %d = map /^([0-9a-f]+)\s+"(.*)"\s*$/i, split /\n\s*/, $dead;
     $d{lc $_} = $d{$_} for keys %d;
     $self->{'[seen_knames]'} ||= {};
     @{$self->{'[seen_knames]'}}{map {chr hex $_} keys %d} = values %d;		# XXXX Overwrites older values
   } elsif ($dead =~ /\S/) {
     warn "no KEYNAME_DEAD section found" if 0;
   }
   \%o, \%d, $t;		# %o - translation tables; %d - names; $t is what is left of input
}

sub massage_template ($$$) {
   my ($self, $t, $r, %seen, %miss) = (shift, shift, shift);
   my $keys = join '|', keys %$r;
   $t =~ s/($keys)/ # warn "Plugging in `$1'"; 
   		    $seen{$1}++, $r->{$1} /ge;	# Can't use \b: see SORT_ORDER_ID_ LOCALE_ID
   $seen{$_} or $miss{$_}++ for keys %$r;
   warn "The following parts missing in the template: ", join ' ', sort keys %miss if %miss;
   $t
}

# http://msdn.microsoft.com/en-us/library/dd373763
# http://msdn.microsoft.com/en-us/library/dd374060
my $template_win = <<'EO_TEMPLATE';
KBD	DLLNAME		"LAYOUTNAME"

COPYRIGHT	"(c) COPYR_YEARS COMPANYNAME"

COMPANY	"COMPANYNAME"

LOCALENAME	"LOCALE_NAME"

LOCALEID	"SORT_ORDER_ID_LOCALE_ID"

VERSION	1.0

SHIFTSTATE

BITS_TEMPLATE

LAYOUT		;an extra '@' at the end is a dead key

//SC	VK_		Cap	COL_HEADERS
//--	----		----	COL_EXPL
LAYOUT_KEYS
DO_LIGA
DEADKEYS

KEYNAME

01	Esc
0e	Backspace
0f	Tab
1c	Enter
1d	Ctrl
2a	Shift
36	"Right Shift"
37	"Num *"
38	Alt
39	Space
3a	"Caps Lock"
3b	F1
3c	F2
3d	F3
3e	F4
3f	F5
40	F6
41	F7
42	F8
43	F9
44	F10
45	Pause
46	"Scroll Lock"
47	"Num 7"
48	"Num 8"
49	"Num 9"
4a	"Num -"
4b	"Num 4"
4c	"Num 5"
4d	"Num 6"
4e	"Num +"
4f	"Num 1"
50	"Num 2"
51	"Num 3"
52	"Num 0"
53	"Num Del"
54	"Sys Req"
57	F11
58	F12
5C	AX
70	KANA
73	"ABNT C1"
79	CONVERT
7c	F13
7d	F14
7e	F15
7f	F16
80	F17
81	F18
82	F19
83	F20
84	F21
85	F22
86	F23
87	F24

KEYNAME_EXT

1c	"Num Enter"
1d	"Right Ctrl"
35	"Num /"
37	"Prnt Scrn"
38	"Right Alt"
45	"Num Lock"
46	Break
47	Home
48	Up
49	"Page Up"
4b	Left
4d	Right
4f	End
50	Down
51	"Page Down"
52	Insert
53	Delete
54	<00>
56	Help
5b	"Left Windows"
5c	"Right Windows"
5d	Application

KEYNAMES_DEAD

DESCRIPTIONS

LOCALE_ID	LAYOUTNAME

LANGUAGENAMES

LOCALE_ID	LANGUAGE_NAME

ENDKBD

EO_TEMPLATE
			# "

sub KEY2hex ($$) {
  my ($self, $k) = (shift, shift);
  return $self->key2hex($k) unless 'ARRAY' eq ref $k;
#warn "see a deadkey `@$k'";
  $k = [@$k];				# deeper copy
  $k->[0] = $self->key2hex($k->[0]);
  $k;
}

sub linked_faces_2_hex_map ($$$$) {
  my ($self, $name, $b, $inv) = (shift, shift, shift, shift);
  my $L = $self->{faces}{$name};
  my $remap = $L->{$inv ? 'Face_link_map_INV' : 'Face_link_map'}{$b};
  die "Face `$b' not linked to face `$name'; HAVE: <", join('> <', keys %{$L->{Face_link_map}}), '>'
    if $self->{faces}{$b} != $L and not $remap;
  my $cover = $L->{'[coverage_hex]'} or die "Face $name not preprocessed";
# warn "Keys of the Map `$name' -> '$b': <", join('> <',  keys %$remap), '>';
#  $remap ||= {map +(chr hex $_, chr hex $remap->{$_}), keys %$cover};		# This one in terms of chars, not hex
  my @k = keys %$remap;
# warn "Map `$name' -> '$b': <", join('> <', map +($self->key2hex($_), $self->key2hex($remap->{$_})), @k), '>';
  return { map +($self->key2hex($_), (defined $remap->{$_} ? $self->KEY2hex($remap->{$_}) : undef)), @k }
}

my $dead_descr;
#my %control = split / /, "\n \\n \r \\r \t \\t \b \\b \cC \\x03 \x7f \\x7f \x1b \\x1b \x1c \\x1c \x1d \\x1d";
my %control = split / /, "\n \\n \r \\r \t \\t \b \\b";
$control{$_->[0]} ||= $_->[1] for map [chr($_), '^'.chr(0x40+$_)], 1..26;
sub control2prt ($$) {
  my($self, $c) = (shift, shift);
  return $c unless ord $c < 0x20 or ord $c == 0x7f;
  $control{$c} or sprintf '\\x%02x', ord $c;
}

sub dead_with_inversion ($$$$$) {
  my($self, $hex, $to, $nameF, $H) = (shift, shift, shift, shift, shift);
  my $invert_dead = (3 == ($to->[2] || 0));
  $to = $to->[0];
  if ($invert_dead) {
    $to = $self->key2hex($to) unless $hex;
    defined ($to = $H->{'[deadkeyInvAltGrKey]'}{$to}) or die "Cannot invert prefix key `$to' in face `$nameF'";
    # warn "invert $to in face=$nameF, inv=$invertAlt0 --> $inv\n";
    $to = $self->key2hex($to) if $hex;
  }
  $to;
}

sub print_deadkey_win ($$$$$$) {
  my ($self, $nameF, $d, $Dead2, $flip_AltGr_hex, $prefix_flippedMap_hex) = (shift, shift, shift, shift, shift, shift);
#warn "emit `$nameF' d=`$d'";
  my $H = $self->{faces}{$nameF};
#  if (my $unres = $H->{'[unresolved_imported]'}) {
#    warn "Can't resolve `@$unres' to an imported dead key; face=`$nameF'" unless $H->{'[unresolved_imported_warned]'}++;
#  }
#warn "See dead2 in <$nameF> for <$d>" if $dead2;
  my $dead2 = ($Dead2 || {})->{$self->charhex2key($d)} || {};
  my(@sp, %sp) = map {(my $in = $_) =~ s/(?<=.)\@$//s; $in} @{ ($self->get_VK($nameF))->{SPACE} || [] };
  @sp = map $self->charhex2key($_), @sp;
  @sp{@sp[1..$#sp]} = (0..$#sp);		# The leading elt is the scancode

  my $b = $H->{'[deadkeyFace]'}{$d};	# $d is hex
  my $b1 = $prefix_flippedMap_hex && $H->{'[deadkeyFaceInvAltGr]'}{$self->charhex2key($prefix_flippedMap_hex)};
  my @maps = map $self->linked_faces_2_hex_map($nameF, $_), $b, ($b1 ? $b1 : ());	# Invert AltGr???
  my($D, @DD) = ($d, $d, $prefix_flippedMap_hex);
  my ($OUT, $keys) = '';
  # There are 3 situations:
  # 0) process one map without AltGr-inversion; 1) Process one map which is the AltGr-inversion of the principal one;
  # 2) process one map with AltGr-inversion (in 1-2 the inversion may have a customization put over it).
  # The problem is to recognize when deadkeys in the inversion come from non-inverted one, or from customization
  # And, in case (1), we must consider flip_AltGr specially... (the case (2) is now treated during face preparation)
  my($is_invAltGr, $AMap, $default) = ($D eq ($flip_AltGr_hex || 'n/a') and $H->{'[dead2_AltGr_chain]'}{''});
  $default = $self->default_char($nameF);
  $default = $self->key2hex($default) if defined $default;
  if ($#maps or $is_invAltGr) {		# One of the maps we will process is AltGr-inverted; calculate AltGr-inversion
    $self->faces_link_via_backlinks($nameF, $nameF, 'no_ini');		# Create AltGr-invert self-mapping
    $AMap = $self->linked_faces_2_hex_map($nameF, $nameF, 1);
#warn "deadkey=$D flip=$flip_AltGr_hex" if defined $default;;
  }
  my($docs, $map_AltGr_over, $over_dead2) = ($H->{'[prefixDocs]'}{$D}, {}, {});
  if ($is_invAltGr) { 
    if (my $override_InvAltGr = $H->{"[InvAltGrFace]"}{''}) { # NOW: needed only for invAltGr
      $map_AltGr_over = $self->linked_faces_2_hex_map($nameF, $override_InvAltGr);
    }
    $over_dead2 = $Dead2->{$self->charhex2key($flip_AltGr_hex)} || {} if defined $flip_AltGr_hex;	# used in CyrPhonetic v0.04
    $dead2 = { %{ $H->{'[DEAD]'} }, %{ $H->{'[dead_in_VK]'} } };
    $docs ||= 'AltGr-inverted base face';
  }

# warn "output map for `$D' invert=", !!$is_invAltGr, ' <',join('> <', sort keys %$dead2),'>';
  for my $invertAlt0 (0..$#maps) {
    my $invertAlt = $invertAlt0 || $is_invAltGr;
    my $map = $maps[$invertAlt0];
    $d = $DD[$invertAlt0];
    my $docs1 = (defined $docs ? sprintf("\t// %s%s", ($invertAlt0 ? 'AltGr inverted: ' : ''), $docs) : '');
    $OUT .= "DEADKEY\t$d$docs1\n\n";
    # Good order: first alphanum, then punctuation, then space
    my @keys = sort keys %$map;			# Sorting not OK for 6-byte keys - but can't have them on Win
    @keys = (grep(( lc(chr hex $_) ne uc(chr hex $_)and not $sp{chr hex $_} ),		      @keys),
             grep(((lc(chr hex $_) eq uc chr hex $_ and (chr hex $_) !~ /\p{Blank}/) and not $sp{chr hex $_}), @keys),
            grep((((lc(chr hex $_) eq uc chr hex $_ and (chr hex $_) =~ /\p{Blank}/) or $sp{chr hex $_}) and $_ ne '0020'), @keys),
             grep(				                    $_ eq '0020',  @keys));	# make SPACE last
    for my $n (@keys) {	# Not OK for 6-byte keys (impossible on Win)
#      warn "doing $n\n";
      my ($to, $import_dead, $EXPL) = $map->{$n};
      warn "0000" if $to and $to eq '0000';
      if ($to and 'ARRAY' eq ref $to) {
        $EXPL = $to->[3]; 
        $EXPL =~ s/(?=\p{NonspacingMark})/ /g if $EXPL;
        $import_dead = (1 <= ($to->[2] || 0));					# was: exportable; now: any dead
        $to = $self->dead_with_inversion('hex', $to, $nameF, $H);
      }
      my $map_n = $map->{$n};
      $map_n = $map_n->[0] if $map_n and ref $map_n;
      $H->{'[32-bit]'}{chr hex $map_n}++, next if hex $n > 0xFFFF and $map_n;	# Cannot be put in a map...
      if ($to and hex $to > 0xFFFF) {		# Value cannot be put in a map...
#        warn "32-bit: n=$n map{n}=$map_n to=$to";
        $H->{'[32-bit]'}{chr hex $map_n}++;
        next unless defined ($to = $H->{'[DeadChar_32bitTranslation]'});
        $to =~ s/^\s+//;	$to =~ s/\s+$//;
        $to = $self->key2hex($to);
      }
      my $was_to = $to;
      $to ||= $default or next;
	#  Tricky: dead keys may come from the override map (which is indexed by NOT-INVERTED KEYS!); it is already merged into
	#  the map - unless for inverted base face
      my ($alt_n, $use_dead2) = (($is_invAltGr and defined $map_AltGr_over->{$n})
        			 ? ($n, $over_dead2) 
        			 : (($invertAlt ? $AMap->{$n} : $n), $dead2));
      $alt_n = $alt_n->[0] if $alt_n and ref $alt_n;	# AMap may have "complex" values
#warn "$D --> $d, `$n', `$alt_n', `$AMap->{$n}'; `$map_AltGr_over->{$n}' i=$invertAlt i0=$invertAlt0 d=$use_dead2->{chr hex $alt_n}";
#warn "... n=`$n', alt=`$alt_n' Amap=`$AMap->{$n}'\n" if $AMap->{$n};
      my $DEAD = ( (defined $alt_n and $use_dead2->{chr hex $alt_n}) ? '@' : '' );
#warn "AltGr flip: $nameF:$D: $n --> $H->{'[dead2_AltGr_chain]'}{$D}" if $n eq ($flip_AltGr_hex || 'n/a');
      my $from = $self->control2prt(chr hex $n);
      ($DEAD, $to) = ('@', $DD[1])	# Join b1 to b on $flip_AltGr_hex; Do not overwrite existing binding...  Warn???
        if (hex $n) == hex ($flip_AltGr_hex || 'ffffff') and @maps == 2 and not defined $was_to and !$invertAlt and !$DEAD ;	
      $to = $default if defined $default and (0x7f == hex $to or 0x20 > hex $to) and (0x7f == hex $n or 0x20 > hex $n);
      my $expl = exists $self->{UNames} ? "\t// " . join "\t-> ",		#  map $self->UName($_), 
  #                  chr hex $n, chr hex $map->{$n} : '';
                   $self->UName(chr hex $n), $self->UName(chr hex $to, 'verbose', 'vbell') : '';
      $expl .= " (via $EXPL)" if $expl and $EXPL;
      my $to1 = $self->control2prt(chr hex $to);
#      warn "Both import_dead and DEAD properties hold for `$from' --> '$to1' via deadkey $d face=$nameF" if $DEAD and $import_dead;
      $DEAD = '@' if $import_dead;
      $OUT .= sprintf "%s\t%s%s\t// %s -> %s%s\n", $n, $to, $DEAD, $from, $to1, $expl;
    }
    $OUT .= "\n";
    $keys ||= @keys;
  }
  warn "DEADKEY $d for face `$nameF' empty" unless $keys;
  (!!$keys, $OUT)
}

sub massage_diacritics ($) {			# "
  my ($self) = (shift);
  my %char2dia;
  for my $dia (sort keys %{$self->{Diacritics}}) {	# Make order deterministic
    my @v = map { s/\p{Blank}//g; $_ } @{ $self->{Diacritics}{$dia} };
#    $self->{'[map2diac]'}{$_} = $dia for split //, join '', @v;	# XXXX No check for duplicates???
    for my $cc ( [ split //, join '', @v[0..3] ], [ split //, join '', @v[4..$#v] ] ) {	# modifiers, combining
      $char2dia{$cc->[$_]}{$_} = $dia for 0..$#$cc;	# XXXX No check for duplicates???
    }
    my @vv = map [ split // ], @v;
    $self->{'[diacritics]'}{$dia} = \@vv;
  }
  for my $c (keys %char2dia) {
    my @pos = sort {$a <=> $b} keys %{ $char2dia{$c} };
# warn("map2diac( $c ): @pos; ", join '; ', values %{ $char2dia{$c} });
    $self->{'[map2diac]'}{$c} = $char2dia{$c}{$pos[0]};		# prefer the earliest possible occurence
  }
}

sub extract_diacritic ($$$$$$@) {
  my ($self, $dia, $idx, $which, $need, $skip2, @elt0) = (shift, shift, shift, shift, shift, shift);
  my @v  = map @$_, my $elt0 = shift;			# first one full
  push @v, map @$_[($skip2 ? 2 : 0)..$#$_], @_;		# join the rest, omitting the first 2 (assumed: accessible in other ways)
  @elt0 = $elt0 if $skip2 and $skip2 eq 'skip2-include0';
  push @v, grep defined, map @$_[0..1], @elt0, @_ if $skip2;
#  @v = grep +((ord $_) >= 128 and $_ ne $dia), @v;
  @v = grep +(ord $_) >= 0x80, @v;
  die "diacritic `  $dia  ' has no $which no.$idx (0-based) assigned" 
    unless $idx >= $need or defined $v[$idx];
# warn "Translating for dia=<$dia>: idx=$idx <$which> -> <$v[$idx]> of <@v>" if defined $v[$idx];
  return $v[$idx];
}

sub diacritic2self ($$$$$$$$) {
  my ($self, $dia, $c, $face, $N, $space, $c_base, $c_noalt) = (shift, shift, shift, shift, shift, shift, shift, shift);
#  warn("Translating for dia=<$dia>: got undef"),
  return $c unless defined $c;
#  $c = $c->[0] if 'ARRAY' eq ref $c;			# Prefix keys behave as usual keys
  $_ and 'ARRAY' eq ref $_ and $_ = $_->[0] for $c, $c_base, $c_noalt;			# Prefix keys behave as usual keys
#warn "  Translating for dia=<$dia>: got <$c>";
  die "`  $dia  ' not a known diacritic" unless my $name = $self->{'[map2diac]'}{$dia};
  my $v = $self->{'[diacritics]'}{$name} or die "Panic!";
  my ($first) = grep 0x80 <= ord, @{$v->[0]} or die "diacritic `  $dia  ' does not define any non-7bit modifier";
  return $first if $c eq ' ';
  my $spaces = keys %$space;
  if ($c eq $dia) {
#warn "Translating2combining dia=<$dia>: got <$c>  --> <$v->[4][0]>";
    # This happens with caron which reaches breve as the first:
#    warn "The diacritic `  $dia  ' differs from the first non-7bit entry `  $first  ' in its list" unless $dia eq $first;
    die "diacritic `  $dia  ' has no default combining char assigned" unless defined $v->[4][0];
    return $v->[4][0];
  }
  my $limits = $self->{Diacritics_Limits}{ALL} || [(0) x 7];
  if ($space->{$c}) {	# SPACE is handled above (we assume it is on index 0)...
    # ~ and ^ have only 3 spacing variants; one of them must be on ' ' - and we omit the first 2 of non-principal block...
    return $self->extract_diacritic($dia, $space->{$c}, 'spacing variant', $limits->[0], 'skip2', @$v[0..3]);
  } elsif (0 <= (my $off = index "\r\t\n\x1b\x1d\x1c\b\x7f", $c)) {	# Enter, Tab, C-Enter, C-[, C-], C-\, Bspc, C-Bspc
    # ~ and ^ have only 3 spacing variants; one of them must be on ' '
    return $self->extract_diacritic($dia, $spaces + $off, 'spacing variant', $limits->[0], 'skip2', @$v[0..3]);
  } elsif (!$spaces and $c =~ /^\p{Blank}$/) {	# NBSP and, (eg) Thin space 2007	-> second/third modifier
    # ~ and ^ have only 3 spacing variants; one of them must be on ' '
    return $self->extract_diacritic($dia, ($c ne "\x{A0}")+1, 'spacing variant', $limits->[0], 'skip2', @$v[0..3]);
  }
  if ($c eq "|" or $c eq "\\") {
#warn "Translating2vertical dia=<$dia>: got <$c>  --> <$v->[4][0]>";	# Skip2 would hurt, since macron+\ is defined:
    return $self->extract_diacritic($dia, ($c eq "|"), 'vertical+etc spacing variant', $limits->[2], !'skip2', @$v[2..3]);
  }
  if ($N == 1 and $c_noalt and ($c_noalt eq "|" or $c_noalt eq "\\")) {
#warn "Translating2vertical dia=<$dia>: got <$c>  --> <$v->[4][0]>";	# Skip2 would hurt, since macron+\ is defined:
    return $self->extract_diacritic($dia, ($c_noalt eq "|"), 'vertical+dotlike combining', $limits->[6], 'skip2', @$v[6,7,4,5]);
  }
  if ($c eq "/" or $c eq "?") {
    return $self->extract_diacritic($dia, ($c eq "?"), 'prime-like+etc spacing variant', $limits->[3], 'skip2', @$v[3]);
  }
  if ($c_noalt and ($c_noalt eq "'" or $c_noalt eq '"')) {
    return $self->extract_diacritic($dia, 1 + ($c_noalt eq '"') + 2*$N, 'combining', $limits->[4], 'skip2', @$v[4..7]);	# 1 for double-prefix
  }
  if ($c eq "_" or $c eq "-") {
    return $self->extract_diacritic($dia, ($c eq "_"), 'lowered+etc spacing variant', $limits->[1], 'skip2', @$v[1..3]);
  }
  if ($N == 1 and $c_noalt and ($c_noalt eq "_" or $c_noalt eq "-")) {
    return $self->extract_diacritic($dia, ($c_noalt eq "_"), 'lowered combining', $limits->[5], 'skip2', @$v[5..7,4]);
  }
  if ($N == 1 and $c_noalt and ($c_noalt eq ";" or $c_noalt eq ":")) {
    return $self->extract_diacritic($dia, ($c_noalt eq ":"), 'combining for symbols', $limits->[7], 'skip2', @$v[7,4..6]);
  }
  if ($N == 1 and defined $c_base and 0 <= (my $ind = index "`1234567890=[],.'", $c_base)) {
    return $self->extract_diacritic($dia, 2 + $ind, 'combining', $limits->[4], 'skip2-include0', @$v[4..7]);	# -1 for `, 1+2 for double-prefix and AltGr-/?
  }
  if ($N == 0 and 0 <= (my $ind = index "[{]}", $c)) {
    return $self->extract_diacritic($dia, 2 + $ind, 'combining for symbols', $limits->[7], 'skip2-include0', @$v[7,4..6]);
  }
  if ($N == 1 and $c_noalt and ($c_noalt eq "/" or $c_noalt eq "?")) {
    return $self->extract_diacritic($dia, 6 + ($c_noalt eq "?"), 'combining for symbols', $limits->[7], 'skip2-include0', @$v[7,4..6]);
  }
  return undef;
}

sub diacritic2self_2 ($$$$$$) {		# Takes a key: array of arrays [lc,uc]
  my ($self, $dia, $c, $face, $space, @out) = (shift, shift, shift, shift, shift);
  my $c0 = $c->[0][0];			# Base character
  for my $N (0..$#$c) {
    my $c1 = $c->[$N];
    push @out, [map $self->diacritic2self($dia, $c1->[$_], $face, $N, $space, $c0, $c->[0][$_]), 0..$#$c1];
  }
  @out
}

# Combining stuff:
# perl -C31 -MUnicode::UCD=charinfo -le 'sub n($) {(charinfo(ord shift) || {})->{name}} for (0x20..0x10ffff) {next unless (my $c = chr) =~ /\p{NonspacingMark}/; (my $n = n($c)) =~ /^COMBINING\b/ or next; printf qq(%04x\t%s\t%s\n), $_, $c, $n}' >cc
# perl -C31 -MUnicode::UCD=charinfo -le 'sub n($) {(charinfo(ord shift) || {})->{name}} for (0x20..0x10ffff) {next unless (my $c = chr) =~ /\p{NonspacingMark}/; (my $n = n($c)) =~ /^COMBINING\b/ and next; printf qq(%04x\t%s\t%s\n), $_, $c, $n}' >cc

sub cache_dialist ($@) {	# downstream, it is crucial that a case pair comes from "one conversion"
  my ($self, %seen, %caseseen, @out) = (shift);     
warn("caching dia: [@_]") if warnCACHECOMP;
  for my $d (@_) {
    next unless my $h = $self->{Compositions}{$d};
    $seen{$_}++ for keys %$h;
  }
  for my $c (keys %seen) {
    next if $caseseen{$c};
    # uc may include a wrong guy: uc(ſ) is S, and this may break the pair s/S if ſ comes before s, and S gets a separate binding;
    # so be very conservative with which case pair we include...
    my @case = grep { $_ ne $c and $seen{$_} and lc $_ eq lc $c } lc $c, uc $c or next;
    push @case, $c;
    $caseseen{$_} = \@case, delete $seen{$_} for @case;
  }				# Currently (?), downstream does not distinguish case pairs from Shift-pairs...
  for my $cases ( values %caseseen, map [$_], keys %seen ) {	# To avoid pairing symbols, keep them in separate slots too
    my (@dia, $to);
    for my $dia (@_) {
      push @dia, $dia if grep $self->{Compositions}{$dia}{$_}, @$cases;
    }
    for my $diaN (0..$#dia) {
      $to = $self->{Compositions}{$dia[$diaN]}{$_} and
(warnCACHECOMP and warn("cache dia; c=`$_' of `@$cases'; dia=[$dia[$diaN]]")),
         $out[$diaN]{$_} = $to for @$cases;
    }
  }
#warn("caching dia --> ", scalar @out);
  @out
}

my %cached_aggregate_Compositions;
sub dia2list ($$) {
  my ($self, $dia, @dia) = (shift, shift);
#warn "Split dia `$dia'";
  if ((my ($pre, $mid, $post) = split /(\+|--)/, $dia, 2) > 1) {	# $mid is not counted in that "2"
    for my $p ($self->dia2list($pre)) {
      push @dia, map "$p$mid$_", $self->dia2list($post);
    }
# warn "Split dia to `@dia'";
    return @dia;
  }
  return $dia if $dia =~ /^!?\\/;		# (De)Penalization lists
  $dia = $self->charhex2key($dia);
  unless ($dia =~ /^-?(\p{NonspacingMark}|<(?:font=)?[-\w!]+>|[ul]c(first)?|dectrl)$/) {
    die "`  $dia  ' not a known diacritic" unless my $name = $self->{'[map2diac]'}{$dia};
    my $v = $self->{'[diacritics]'}{$name} or die "A spacing character <$dia> was requested to be treated as a composition one, but we do not know translation";
    die "Panic!" unless defined ($dia = $v->[4][0]);
  }
  if ($dia =~ /^(-)?<(reverse-)?any(1)?-(other-)?\b([-\w]+?)\b((?:-![-\w]+\b)*)>$/) {
    my($neg, $rev, $one, $other, $match, $rx, $except, @except) 
      = ($1||'', $2, $3, $4, $5, "(?:(?<!<)|(?=font=))\\b$5\\b", qr((?!)), split /-!/, "$6");	# Allow only `font´ at start
    my $cached;
    (my $dia_raw = $dia) =~ s/^-//;
    $cached = $cached_aggregate_Compositions{$dia_raw} and return map "$neg$_", @$cached;

    @except = map { s/^(?=\w)/\\b/; s/(?<=\w)$/\\b/; $_} @except;
    $except = join('|', @except[1..$#except]), $except = qr($except) if @except;
#warn "Exceptions: $except" if @except;
    $rx =~ s/-/\\b\\W+\\b/g;
    my ($A, $B, $AA, $BB);
    my @out = keys %{$self->{Compositions}};
    @out = grep !/^Cached\d+=</, @out;
    @out = grep {length > 1 ? /$rx/ : (lc $self->UName($_) || '') =~ /$rx/ } @out;    	
    @out = grep {length > 1 ? !/$except/ : (lc $self->UName($_) || '') !~ /$except/ } @out;    	
    # make <a> before <a-b>; penalize those with and/over inside
    @out = sort {($A=$a) =~ s/>/\cA/g, ($B=$b) =~ s/>/\cA/g; ($AA=$a) =~ s/\w+\W*/a/g, ($BB=$b) =~ s/\w+\W*/a/g;	# Number of words
    		 /.\b(and|over)\b./ and s/^/~/ for $A,$B; $AA cmp $BB or $A cmp $B or $a cmp $b} @out;
    @out = grep length($match) != length, @out if $other;
    @out = grep !/\bAND\s/, @out if $one;
    @out = reverse @out if $rev;				# xor $reverse;
    if (!dontCOMPOSE_CACHE and @out > 1 and not $neg) {		# Optional caching; will modify composition tables
      my @cached = $self->cache_dialist(@out);			#     but not decomposition ones, hence `not $neg'
      @out = map "Cached$_=$dia_raw", 0..$#cached;
      $self->{Compositions}{$out[$_]} = $cached[$_] for 0..$#cached;
      $cached_aggregate_Compositions{$dia} = \@out;
    }
    @out = map "-$_", @out if $neg;
    return @out;
  } else {		# <pseudo-curl> <super> etc
#warn "Dia=`$dia'";
    return $dia;
  }
}

sub flatten_arrays ($$) {
  my ($self, $a) = (shift, shift);
  warn "method flatten_arrays() takes one argument" if @_;
  return $a unless ref($a  || '') eq 'ARRAY';
  map $self->flatten_arrays($_), @$a;
}

sub array2string ($$) {
  my ($self, $a) = (shift, shift);
  warn "method array2string() takes one argument" if @_;
  return '(undef)' unless defined $a;
  return "<$a>" unless ref($a  || '') eq 'ARRAY';
  '[ ' . join(', ', map $self->array2string($_), @$a) . ' ]';
}

sub dialist2lists ($$) {
  my ($self, $Dia, @groups) = (shift, shift);
  for my $group (split /\|/, $Dia, -1) {
    my @dia;
    for my $dia (split /,/, $group) {
      push @dia, $self->dia2list($dia);
    }
    push @groups, \@dia;		# Do not omit empty groups
  }			# Now get all the chars, and precompile results for them
  @groups
}

sub document_char ($$$;$) {
  my ($self, $c, $doc, $old) = (shift, shift, shift, shift);
  return $c if not defined $c or not defined $doc;
  $doc = "$old->[3] ⇒ $doc" if $old and ref $old and defined $old->[3];
  $c = [$c] unless ref $c;
  $c->[3] = $doc if defined $doc;
  $c
}

#use Dumpvalue;
my %translators = ( Id => sub ($)  {shift},   Empty => sub ($) { return undef },
	        dectrl =>  sub ($) {defined (my $c = shift) or return undef; $c = $c->[0] if 'ARRAY' eq ref $c;
	        		    return undef if 0x20 <= ord $c; chr(0x40 + ord $c)},
	       maybe_ucfirst =>  sub ($) {defined (my $c = shift) or return undef; $c = $c->[0] if 'ARRAY' eq ref $c; ucfirst $c},
		    maybe_lc =>  sub ($) {defined (my $c = shift) or return undef; $c = $c->[0] if 'ARRAY' eq ref $c; lc $c},
		    maybe_uc =>  sub ($) {defined (my $c = shift) or return undef; $c = $c->[0] if 'ARRAY' eq ref $c; uc $c},
	ucfirst =>  sub ($) {defined (my $c = shift) or return undef; $c = $c->[0] if 'ARRAY' eq ref $c;
				    my $c1 = ucfirst $c;	return undef if $c1 eq $c; $c1},
	     lc =>  sub ($) {defined (my $c = shift) or return undef; $c = $c->[0] if 'ARRAY' eq ref $c;
				    my $c1 = lc $c;		return undef if $c1 eq $c; $c1},
	     uc =>  sub ($) {defined (my $c = shift) or return undef; $c = $c->[0] if 'ARRAY' eq ref $c;
				    my $c1 = uc $c;		return undef if $c1 eq $c; $c1} );
sub make_translator ($$$$$) {		# translator may take some values from "environment" 
  # (such as which deadkey is processed), so caching is tricky: if does -> $used_deadkey reflects this
  # The translator should return exactly one value (possibly undef) so that map TRANSLATOR, list works intuitively.
  my ($self, $name, $deadkey, $face, $N, $used_deadkey) = (shift, shift, shift || 0, shift, shift, '');	# $deadkey used eg for diagnostics
  die "Undefined recipe in a translator for face `$face', layer $N on deadkey `$deadkey'" unless defined $name;
  if ($name =~ /^Imported\[([\/\w]+)(?:,([\da-fA-F]{4,}))?\]$/) {
    my($d, @sec) = (($2 ? "$2" : undef), split m(/), "$1");
    $d = $deadkey, $used_deadkey ="/$deadkey" unless defined $d;
    my $fromKBDD = $self->get_deep($self, 'DEADKEYS', @sec, lc $d, 'map')	# DEADKEYS/bepo with 00A4 ---> DEADKEYS/bepo/00a4
      or die "DEADKEYS section for `$d' with parts `@sec' not found";
	# indexed by lc hex
    return sub { my $cc=my $c=shift; return $c unless defined $c; $c = $c->[0] if 'ARRAY' eq ref $c; defined($c = $fromKBDD->{$self->key2hex($c)}) or return $c; $self->document_char(chr hex $c, $name, $cc) }, '';
  }
  die "unrecognized Imported argument: `$1'" if $name =~ /^Imported(\[.*)/s;
  return $translators{$name}, '' if $translators{$name};
  if ($name =~ /^PrefixDocs\[(.+)\]$/) {
    $self->{faces}{$face}{'[prefixDocs]'}{$deadkey} = $1;
    return $translators{Empty}, '';
  }
  if ($name =~ /^HTML_classes\[(.+)\]$/) {
    (my @c = split /,/, "$1") % 3 and die "HTML_classes[] for key `$deadkey' not come in triples";
    my $C = ( $self->{faces}{$face}{'[HTML_classes]'}{$deadkey || ''} ||= {} );		# Above, deadkey is ||= 0
#	warn "I create HTML_classes for face=$face, prefix=`$deadkey'";
    while (@c) {
      my ($where, $class, $chars) = splice @c, 0, 3;
      ( $chars = $self->stringHEX2string($chars) ) =~ s/\p{Blank}(?=\p{NonspacingMark})//g;
      push @{ $C->{$where}{$_} }, $class for split //, $chars;
    }
    return $translators{Empty}, '';
  }
  if ($name =~ /^Space(Self)?2Id(?:\[(.+)\])?$/) {
    my $dia = $self->charhex2key((defined $2) ? $2 : do {$used_deadkey = "/$deadkey"; $deadkey});	# XXXX `do' is needed, comma does not work
    my $self_OK = $1 ? $dia : 'n/a';
    return sub ($) { my $c = (shift() || '[none]'); $c = $c->[0] if 'ARRAY' eq ref $c;	# Prefix key as usual letter
    		    ($c eq ' ' or $c eq $self_OK and defined $dia) ? $self->document_char($dia, $name) : undef }, $used_deadkey;
  }
  if ($name =~ /^ShiftFromTo\[(.+)\]$/) {
    my ($f,$t) = split /,/, "$1";
    $_ = hex $self->key2hex($self->charhex2key($_)) for $f, $t;
    $t -= $f;					# Treat prefix keys as usual keys:
    return sub ($) { my $cc=my $c=shift; return $c unless defined $c; $c = $c->[0] if 'ARRAY' eq ref $c; $self->document_char(chr($t + ord $c), $name, $cc) }, '';
  }
  if ($name =~ /^SelectRX\[(.+)\]$/) {
    my ($rx) = qr/$1/;				# Treat prefix keys as usual keys:
    return sub ($) { my $cc = my $c=shift; defined $c or return $c; $c = $c->[0] if 'ARRAY' eq ref $c; return undef unless $c =~ $rx; $cc }, '';
  }
  if ($name =~ /^FlipShift$/) {
    return sub ($) { my $c = shift; defined $c or return $c; map [@$_[1,0]], @$c }, '', 'all_layers';
  }
  if ($name =~ /^AssignTo\[(\w+),(\d+)\]$/) {
    my ($sec, $cnt) = ($1, $2);
    $cnt = 0, warn "Unrecognized section `$sec' in AssignTo" unless my $S = $start_SEC{$sec};
    warn("Too many keys ($cnt) put into section `$sec', max=$S->[1]"), $cnt = $S->[1] if $cnt > $S->[1];
    my $toTarget = sub { my $slot = shift; return unless $slot < $cnt; $slot + $S->[0] };
    return sub ($) { @{shift()} }, '', ['all_layers', $toTarget];
  }
  if ($name =~ /^FromTo(FlipShift)?\[(.+)\]$/) {
    my $flip = $1;
    my ($f,$t) = split /,/, "$2", 2;
    exists $self->{layers}{$_} or $_ = ($self->make_translated_layers($_, $face, [$N], $deadkey))->[0]
      for $f, $t;		# Be conservative for caching...
    my $B = "~~~{$f>>>$t}";
    $_ = $self->{layers}{$_} for $f, $t;
    my (%h, $kk);
    for my $k (0..$#$f) {
      my @fr = map {($_ and ref) ? $_->[0] : $_} @{$f->[$k]};
      my @to = map {($_ and ref) ? $_->[0] : $_} @{$t->[$k]};
      if ($flip) {
        $h{defined($kk = $fr[$_]) ? $kk : ''} = $to[1-$_] for 0,1;
      } else {
        $h{defined($kk = $fr[$_]) ? $kk : ''} = $to[$_] for 0,1;
      }# 
    }						# Treat prefix keys as usual keys:
    return sub ($) { my $cc = my $c = shift; defined $c or return $c; $c = $c->[0] if 'ARRAY' eq ref $c; $self->document_char($h{$c}, $name, $cc) }, $B;
  }
  if ($name =~ /^InheritPrefixKeys\[(.+)\]$/) {
    my $base = $1;
    exists $self->{layers}{$_} or $_= ($self->make_translated_layers($_, $face, [$N], $deadkey))->[0]
      for $base;
    my $baseL = $self->{layers}{$base};
    my (%h);
    for my $k (0..$#$baseL) {
      for my $shift (0..1) {
        my $C = $baseL->[$k][$shift] or next;
        next unless ref $C and $C->[2];		# prefix
        $h{"$N $k $shift $C->[0]"} = $C;
      }
    }						# Treat prefix keys as usual keys:
    return sub ($) { my $c = shift; defined $c or return $c; return $c if 'ARRAY' eq ref $c and $c->[2]; $h{"@_ $c"} or $c }, $base;
  }
  if ($name =~ /^ByColumns\[(.+)\]$/) {
    my @chars = map {length() ? $self->charhex2key($_) : undef} split /,/, "$1";
    my $g = $self->{faces}{$face}{'[geometry]'}
      or die "Face `$face' has no associated layer with geometry info; did you set geometry_via_layer?";
    my $o = ($self->{faces}{$face}{'[g_offsets]'} or [(0) x @$g]);
    $o = [@$o];					# deep copy
    my ($tot, %c) = 0;
# warn "geometry: [@$g] [@$o]";
    for my $r (@$g) {
      my $off = shift @$o;
      $c{$tot + $_} = $_ + $off for 0..($r-1);
      $tot += $r;
    }
    return sub ($$$$) { (undef, my ($L, $k, $shift)) = @_; return undef if $L or $shift or $k >= $tot; $self->document_char($chars[$c{$k}], "ByColumn[$c{$k}]") }, '';
  }
  if ($name =~ /^ByRows\[(.+)\]$/) {
    s(^\s+(?!\s|///\s+))(), s((?<!\s)(?<!\s///)\s+$)() for my $recipes = $1;
    my (@recipes, @subs) = split m(\s+///\s+), $recipes;
    my $LL = $#{ $self->{faces}{$face}{layers} };		# Since all_layers, we are called only for layer 0; subrecipes may need more
    for my $rec (@recipes) {
      push(@subs, sub {return undef}), next unless length $rec;
#warn "recipe=`$rec'; face=`$face'; N=$N; deadkey=`$deadkey'; last_layer=$LL";
      my ($tr) = $self->make_translator_for_layers( $rec, $deadkey, $face, [0..$LL] );
#warn "  done";
      push @subs, $tr;
    }
    my $g = $self->{faces}{$face}{'[geometry]'}
      or die "Face `$face' has no associated layer with geometry info; did you set geometry_via_layer?";
    my ($tot, $row, %r) = (0, 0);
# warn "geometry: [@$g] [@$o]";
    for my $r (@$g) {
      $r{$tot + $_} = $row for 0..($r-1);
      $tot += $r;
      $row++;
    }
#    return sub ($$$$) { (undef, undef, my $k) = @_; return undef if $k >= $tot; return undef if $#recipes < (my $r = $r{$k}); 
#    			die "Undefined recipe: row=$row; face=`$face'; N=$N; deadkey=`$deadkey'; ARGV=(@_)" unless $subs[$r];
#    			goto &{$subs[$r]} }, '';
    return sub ($$) { (undef, my $k) = @_; return [] if $k >= $tot or $#recipes < (my $r = $r{$k}); 
    			die "Undefined recipe: row=$row; face=`$face'; N=$N; deadkey=`$deadkey'; ARGV=(@_)" unless $subs[$r];
    		      goto &{$subs[$r]} }, '', 'all_layers';
  }
  if ($name =~ /^(?:Diacritic|Mutate)(SpaceOK)?(Hack)?(2Self)?(DupsOK)?(32OK)?(?:\[(.+)\])?$/) {
    my ($spaceOK, $hack, $toSelf, $dupsOK, $w32OK) = ($1, $2, $3, $4, $5);
    my $Dia = ((defined $6) ? $6 : do {$used_deadkey ="/$deadkey"; $deadkey});	# XXXX `do' is needed, comma does not work
    if ($toSelf) {
      die "Mutate2Self does not make sense with SpaceOK/Hack/DupsOK/32OK" if grep $_, $hack, $spaceOK, $dupsOK, $w32OK;
      $Dia = $self->charhex2key($Dia);
      my(@sp, %sp) = map {(my $in = $_) =~ s/(?<=.)\@$//s; $in} @{ ($self->get_VK($face))->{SPACE} || [] };
      @sp = map $self->charhex2key($_), @sp;
      my $flip_AltGr = $self->{faces}{$face}{'[Flip_AltGr_Key]'};
      $flip_AltGr = $self->charhex2key($flip_AltGr) if defined $flip_AltGr;
      @sp = grep $flip_AltGr ne $_, @sp if defined $flip_AltGr;			# It has a different function...
      @sp{@sp[1..$#sp]} = (0..$#sp);		# The leading elt is the scancode
  #warn "SPACE: <", join('> <', %sp), '>';
  #    return sub ($) { $self->diacritic2self($Dia, shift, $face, $N, \%sp) }, $used_deadkey if $4;
      return sub ($) { 
  #        $self->document_char($self->diacritic2self_2($Dia, shift, $face, \%sp), $name) 
  #        my $c = 
          $self->diacritic2self_2($Dia, shift, $face, \%sp);
  #        $self->document_char($c, $name) 
        }, $used_deadkey, 'all_layers';
    }
    
    my $isPrimary;
    $Dia =~ s/^\+// and $isPrimary++;				# Wait until <NAMED-*> are expanded

    my $f = $self->get_NamesList;
    $self->load_compositions($f) if defined $f;
    
    $f = $self->get_AgeList;
    $self->load_uniage($f) if defined $f and not $self->{Age};
    # New processing: - = strip 1 from end; -3/ = strip 1 from the last 3
#warn "Doing `$Dia'";
#print "Doing `$Dia'\n";
#warn "Age of <à> is <$self->{Age}{à}>";
    $Dia =~ s(<NAMED-([-\w]+)>){ (my $R = $1) =~ s/-/_/g;
    				 die "Named recipe `$1' unknown" unless exists $self->{faces}{$face}{"Named_DIA_Recipe__$R"};
    				 (my $r = $self->{faces}{$face}{"Named_DIA_Recipe__$R"}) =~ s/^\s+//; $r }ge;
    $Dia =~ s/\|{3,4}/|/g if $isPrimary;
    my($skip, $limit, @groups, @groups2, @groups3) = (0);
    my($have4, @Dia) = (1, split /\|\|\|\|/, $Dia, -1);
    $have4 = 0, @Dia = split /\|\|\|/, $Dia, -1 if 1 == @Dia;
    if (1 < @Dia) {
      die "Too many |||- or ||||-sections in <$Dia>" if @Dia > 3;
      my @Dia2 = split /\|\|\|/, $Dia[1], -1;
      die "Too many |||-sections in the second ||||-section in <$Dia>" if @Dia2 > 2;
#      splice @Dia, 1, 1, @Dia2;
      @Dia2 = @Dia, shift @Dia2 unless $have4;
      $skip = (@Dia2 > 1 ?  1 + ($Dia2[0] =~ tr/|/|/) : 0);
      $Dia[1] .= "|$Dia[2]", pop @Dia if not $have4 and @Dia == 3;
#      $limit =  1 + ($Dia[-1] =~ tr/|/|/) + $skip;
      $limit = 0;						# Not needed with the current logic...
      my @G = map [$self->dialist2lists($_)], @Dia;	# will reverse when merging many into one cached...
      @groups = @{shift @G};      
      @groups2 = @{shift @G} if @G;
      @groups3 = @{shift @G} if @G;
    } else {
      @groups = $self->dialist2lists($Dia);
    }
#warn "Dia `$Dia' -> ", $self->array2string([$limit, $skip, @groups]);
    my $L = $self->{faces}{$face}{layers};
    my @L = map $self->{layers}{$_}, @$L;
    my $Sub = $self->{faces}{$face}{'[AltSubstitutions]'} || {};
# warn "got AltSubstitutions: <",join('> <', %$Sub),'>' if $Sub;
    return sub {
      my $K = shift;				# bindings of the key
      return ([]) x @$K unless grep defined, $self->flatten_arrays($K);		# E.g, ByPairs and SelectRX produce many empty entries...
#warn "Undefined base key for diacritic <$Dia>: <", join('> <', map {defined() ? $_ : '[undef]'} $self->flatten_arrays($K)), '>' unless defined $K->[0][0];
#warn "Input for <$Dia>: <", join('> <', map {defined() ? $_ : '[undef]'} $self->flatten_arrays($K)), '>';
      my $base = $K->[0][0];
      $base = '<?>' unless defined $base;
      $base = $base->[0] if ref $base;
      return ([]) x @$K if not $spaceOK and $base eq ' ';		# Ignore possiblity that SPACE is a deadKey
      my $sorted = $self->sort_compositions(\@groups, $K, $Sub, $dupsOK, $w32OK);
      my ($sorted2, $sorted3, @idx_sorted3);
      $sorted2 = $self->sort_compositions(\@groups2, $K, $Sub, $dupsOK, $w32OK) if @groups2;
      $sorted3 = $self->sort_compositions(\@groups3, $K, $Sub, $dupsOK, $w32OK) if @groups3;
      @idx_sorted3 = @$sorted + (@groups2 ? @$sorted2 : 0) if @groups3;		# used for warnings only
      $self->{faces}{$face}{'[in_dia_chains]'}{$_}++
        for grep defined, ($hack ? () : map {($_ and ref) ? $_->[0] : $_}
        			# index as $res->[group][penalty_N][double_occ][layer][NN][shift]
        			map {$_ ? @$_ : ()} map {$_ ? @$_ : ()} map {$_ ? @$_ : ()} map {$_ ? @$_ : ()} map {$_ ? @$_ : ()} 
        			  @$sorted, @{$sorted2 || []}, @{$sorted3 || []});
      # map {($_ and ref) ? $_->[0] : $_} map @{$_||[]}, @out
require Dumpvalue if printSORTEDLISTS;
Dumpvalue->new()->dumpValue(["Key $base", $sorted]) if printSORTEDLISTS;
      warn $self->report_sorted_l($base, [@$sorted, @{$sorted2 || []}, @{$sorted3 || []}], [scalar @$sorted, $skip + scalar @{$sorted || []}, @idx_sorted3])
        if warnSORTEDLISTS;
      my $LLL = '';
      if ($sorted2) {
        my (@slots, @LL);
        for my $l (0..$#L) {
          push @slots, $self->shift_pop_compositions($sorted2, $l, !'from end', !'omit', $limit, $skip, my $ll = []);
          push @LL, $ll;
print 'From Layers  <', join('> <', map {defined() ? $_ : 'undef'} @$ll), ">\n" if printSORTEDLISTS;
	  $LLL .= ' | ' . join(' ', map {defined() ? $_ : 'undef'} @$ll) if warnSORTEDLISTS;
        }
print 'TMP Extracted ', $self->array2string($slots[0]), "\n" if printSORTEDLISTS;
print 'TMP Extracted ', $self->array2string([@slots[1..$#slots]]), " deadKey=$deadkey\n" if printSORTEDLISTS;
        my $appended = $self->append_keys($sorted3 || $sorted2, \@slots, \@LL, !$sorted3 && 'prepend');
Dumpvalue->new()->dumpValue(["Key $base; II", $sorted2]) if printSORTEDLISTS;
	if (warnSORTEDLISTS) {
          $LLL =~ s/^[ |]+//;
          $_++ for @idx_sorted3;	# empty or 1 elt
          warn "TMP Extracted: ", $self->array2string(\@slots), " from layers $LLL\n";	# 1 is for what is prepended by append_keys()
          warn $self->report_sorted_l($base, [@$sorted, @$sorted2, @{$sorted3 || []}],		# Where to put bold/dotted-bold separators:
          			      [scalar @$sorted, !!$appended + $skip + scalar @$sorted, @idx_sorted3], ($appended ? [1 + scalar @$sorted] : ()));
	}
      }
      my(@out, %seen); 
      for my $Ln (0..$#L) {
        $out[$Ln] = $self->shift_pop_compositions($sorted, $Ln);
        $seen{$_}++ for grep defined, map {($_ and ref) ? $_->[0] : $_} @{$out[$Ln]};
      }
      for my $L (@out) {	# $L is an array indexed by shift state
        $L = [map {(not $_ or ref $_) ? $_ : [$_,undef,undef,'Diacritic operator']} @$L];
      }
      # Insert non-yet-inserted characters from $sorted2, $sorted3
      for my $extra (['from end', $sorted2, 2], [0, $sorted3, 3]) {
        next unless $extra->[1];
        $self->deep_undef_by_hash(\%seen, $extra->[1]);
        for my $Ln (0..$#L) {
          my $o = $out[$Ln];
          unless (defined $o->[0] and defined $o->[1]) {
            my $o2 = $self->shift_pop_compositions($extra->[1], $Ln, $extra->[0], !'omit', !'limit', 0, undef, defined $o->[0], defined $o->[1]);
            $o2 = [map {(!defined $_ or ref) ? $_ : [$_,undef,undef,"Diacritic operator (choice $extra->[2])"]} @$o2];
            defined $o->[$_] or $o->[$_] = $o2->[$_] for 0,1;
            $seen{$_}++ for grep defined, map {($_ and ref) ? $_->[0] : $_} @$o;
          }
        }
      }
print 'Extracted ', $self->array2string(\@out), " deadKey=$deadkey\n" if printSORTEDLISTS;
      warn 'Extracted ', $self->array2string(\@out), " deadKey=$deadkey\n" if warnSORTEDLISTS;
      $self->{faces}{$face}{'[from_dia_chains]'}{$_}++
        for grep defined, ($hack ? () : map {($_ and ref) ? $_->[0] : $_} map @{$_||[]}, @out);
#warn "Age of <à> is <$self->{Age}{à}>";
#warn "Output: <", join('> <', map {defined() ? $_ : '[undef]'} $self->flatten_arrays(\@out)), '>';
      return @out;
    }, $used_deadkey, 'all_layers';
  }
  if ($name =~ /^DefinedTo\[(.+)\]$/) {
    my $to = $self->charhex2key($1);
    return sub ($) { my $c = shift; defined $c or return $c; $self->document_char($to, 'DefinedTo', $c) }, '';
  }
  if ($name =~ /^ByPairs((Inv)?Prefix)?\[(.+)\]$/) {
    my ($prefix, $invert, $in, @Pairs, %Map) = ($1, $2, $3);
    $in =~ s/^\s+//;
    @Pairs = split /\s+(?!\p{NonspacingMark})/, $in;
    for my $p (@Pairs) {
      while (length $p) {
        die "Odd number of characters in a ByPairs map <$in>" 
          unless $p =~ s/^((?:\p{Blank}\p{NonspacingMark}|(?:\b\.)?[0-9a-f]{4,}\b(?:\.\b)?|.){2})//i;
        (my $Pair = $1) =~ s/\p{Blank}//g;
#warn "Pair = <$Pair>";
	# Cannot do it earlier, since HEX can introduce new blanks
	$Pair =~ s/(?<=[0-9a-f]{4})\.$//i;		# Remove . which was on \b before extracting substring
        $Pair = $self->stringHEX2string($Pair);
#warn "  -->  <$Pair>";
        die "Can't split ByPairs rule into a pair: I see <$Pair>" unless 2 == scalar (my @c = split //, $Pair);
        die qq("From" character <$c[0] duplicated in a ByPairs map <$in>)
          if exists $Map{$c[0]};
        $Map{$c[0]} = ($prefix ? [$c[1], undef, ($invert ? 3 : 1)<<3] : $c[1]);		# massage_imported2 makes >> 3
      }
    }
    die "Empty ByPairs map <$in>" unless %Map;			# Treat prefix keys as usual keys:
    return sub ($) { my $c = shift; defined $c or return $c; $c = $c->[0] if 'ARRAY' eq ref $c; $self->document_char($Map{$c}, 'explicit tuneup') }, '';
  }
  my $map = $self->get_deep($self, 'DEADKEYS', split m(/), $name);
  die "Can't resolve character map `$name'" unless defined $map;
  unless (exists $map->{map}) {{
    my($k1) = keys %$map;
    die "Character map `$name' does not contain HEX: `$k1'" if %$map and not $k1 =~ /^[0-9a-f]{4,}$/;
    die "Character map is a parent-type map, but no deadkey to use specified" unless defined $deadkey;
    my $Map = { map +(chr hex $_, $map->{$_}), keys %$map };
    die "Character map `$name' does not contain `$deadkey', contains <", (join '> <', keys %$map), ">"
      unless exists $Map->{chr hex $deadkey};
    $map = $Map->{chr hex $deadkey}, $used_deadkey = "/$deadkey" if %$Map;
    $map = {map => {}}, warn "Character map for `$name' empty" unless %$map;
  }}
  die "Can't resolve character map `$name' `map': <", (join '> <', %$map), ">" unless defined $map->{map};
  $map = $map->{map};
  my $Map = { map +(chr hex $_, chr hex($map->{$_})), keys %$map };	# hex form is not unique
  ( sub ($) {					# Treat prefix keys as usual keys:
      my $c = shift; defined $c or return $c; $c = $c->[0] if 'ARRAY' eq ref $c; $self->document_char($Map->{$c}, "DEADKEYS=$name")
    }, $used_deadkey )
}

sub depth1_A_translator($$) {		# takes a ref to an array of chars
  my ($self, $tr) = (shift, shift);
  return sub ($) {
    my $in = shift;
    [map $tr->($_), @$in]
  }
}

sub depth2_translator($$) {		# takes a ref to an array of arrays of chars
  my ($self, $tr) = (shift, shift);
  return sub ($$) {
    my ($in, $k, @out) = (shift, shift);
    for my $L (0..$#$in) {
      my $Tr = $tr->[$L];
      die "Undefined translator for layer=$L; total=", scalar @$tr unless defined $Tr;
      push @out, [map $Tr->($in->[$L][$_], $L, $k, $_), 0..$#{$in->[$L]}]
    }
    @out
  }
}

sub make_translator_for_layers ($$$$$) {		# translator may take some values from "environment" 
  # (such as which deadkey is processed), so caching is tricky: if does -> $used_deadkey reflects this
  # The translator should return exactly one value (possibly undef) so that map TRANSLATOR, list works intuitively.
  my ($self, $name, $deadkey, $face, $NN) = (shift, shift, shift || 0, shift, shift);	# $deadkey used eg for diagnostics
  my ($Tr, $used, $for_layers) = $self->make_translator( $name, $deadkey, $face, $NN->[0] );
  ($for_layers, my $cvt) = (ref $for_layers ? @$for_layers : $for_layers);
  return $Tr, [map "$used![$_]", @$NN], $cvt if $for_layers;
  my @Tr = map [$self->make_translator($name, $deadkey, $face, $_)], @$NN;
  $self->depth2_translator([map $_->[0], @Tr]), [map $_->[1], @Tr], $cvt;
}

sub make_translated_layers_tr ($$$$$$$) {		# Apply translation map
  my ($self, $layers, $tr, $append, $deadkey, $face, $NN) = (shift, shift, shift, shift, shift, shift, shift);
  my ($Tr, $used, $cvt) = $self->make_translator_for_layers($tr, $deadkey, $face, $NN);
#warn "  tr=<$tr>, key=<$deadkey>, used=<$used>";
  my @new_names = map "$tr$used->[$_]($layers->[$_])$append" . ($append and $NN->[$_]), 0..$#$NN;
  return @new_names unless grep {not exists $self->{layers}{$_}} @new_names;
# warn "Translating via `$tr' from layer [$layer]: <", join('> <', map "@$_", @{$self->{layers}{$layer}}), '>';
  my (@L, @LL) = map $self->{layers}{$_}, @$layers;
  for my $n (0..$#{$L[0]}) {				# key number
    my @C = $Tr->( [ map $L[$_][$n], 0..$#L ], $n );	# rearrange one key into $X[$Layer][$shift]
    if ($cvt) {
      defined $cvt->($n) and $LL[$_][$cvt->($n)] = $C[$_] for 0..$#L;
    } else {
      push @{$LL[$_]}, $C[$_] for 0..$#L;
    }
  }
  $self->{layers}{$new_names[$_]} = $LL[$_] for 0..$#L;
  @new_names
}

sub key2string ($$) {
  my ($self, $key, @o) = (shift, shift);
  return '<>' unless defined $key;
  return '[]' unless grep defined, @$key;
  for my $k (@$key) {
    push(@o, 'undef'), next unless defined $k;
    push @o, ((ref $k) ? (defined $k->[0] ? $k->[0] : '<undef>') : $k);
  }
  "[@o]"
}

sub layer2string ($$) {
  my ($self, $layer, $last, $rest) = (shift, shift, -1, '');
  my @o = map $self->key2string($_), @$layer;
  2 < length $o[$_] and $last = $_ for 0..$#o;
  $rest = '...' if $last != $#o;
  (join ' ', @o[0..$last]) . $rest
}

sub make_translated_layers_stack ($$@) {		# Stacking
  my ($self, @out, $ref) = (shift);
  my $c = @{$_[0]};
  @$_ == $c or die "Stacking: number of layers ", scalar(@$_), " != number of layers $c of the first elt"
    for @_;
  for my $lN (0..$c-1) {	# layer Number
    my @layers = map $_->[$lN], @_;
    push @out, "@layers";
    if (debug_stacking) {
      warn "Stack in-layer $lN `$_': ", $self->layer2string($self->{layers}{$_}), "\n" for @layers;
    }
    next if exists $self->{layers}{"@layers"};
    my (@L, @keys) = map $self->{layers}{$_}, @layers;
    for my $lI (0..$#L) {
      my $l = $L[$lI];
      # warn "... Layer$lN: `$layers[$lI]'..." if debug_stacking;
      for my $k (0..$#$l) {
        for my $kk (0..$#{$l->[$k]}) {
          if (debug_STACKING and defined( my $cc = $l->[$k][$kk] )) {
            $cc = $cc->[0] if ref $cc;
	    warn "...... On $k/$kk (${lI}th lN=$lN): I see `$cc': ", !defined $keys[$k][$kk], "\n" ;
	  }
          $keys[$k][$kk] = $l->[$k][$kk] if defined $l->[$k][$kk] and not defined $keys[$k][$kk];	# Shallow copy
        }
        $keys[$k] ||= [];
      }
    }
    $self->{layers}{"@layers"} = \@keys;
    warn "Stack out-layer $lN `@layers':\n\t", $self->layer2string(\@keys), "\n" if debug_stacking;
  }
  warn 'Stack out-layers:', (join "\n\t", '', @out), "\n" if debug_stacking;
  @out;
}

sub make_translated_layers_noid ($$$@) {		# Stacking
  my ($self, $whole, $refr, @out, $ref, @seen) = (shift, shift, shift);
  my $c = @$refr;
#warn "noid: join ", scalar @_, " faces of $c layers; ref=[@$refr] first=[@{$_[0]}]";
  @$_ == $c or die "Stacking: number of layers ", scalar(@$_), " != number of layers $c of the reference face"
    for @_;
  my @R = map $self->{layers}{$_}, @$refr;
  if ($whole) {
    my $last = $#{$R[0]};
    for my $key (0..$last) {
      for my $l (@R) {
        $seen[$key]{$_}++ for map {ref() ? $_->[0] : $_} grep defined, @{ $l->[$key] };
#warn "$key of $last: keys=", join(',',keys %{$seen[$key]});
      }
    }
  }
  my $name = 'NOID([' . join('], [', map {join ' +++ ', @$_} @_) . '])';
  for my $l (0..$c-1) {
    my (@layers) = map $_->[$l], @_;
    if ($whole) {
      $name .= "'"	# Keep names of layers distinct, but since they are all interdependent, do not construct basing on layer names
    } else {
      $name = "NOID[$refr->[$l]](" . (join ' +++ ', @layers) . ')'
    }
    push @out, $name;
#warn ". Doing layer number $l, name=`$name'...";
    next if exists $self->{layers}{$name};
    my ($Refr, @L, @keys) = map $self->{layers}{$_}, $refr->[$l], @layers;
    for my $ll (@L) {
#warn "... Another layer for $l...";
      for my $k (0..$#$ll) {
        for my $kk (0..$#{$ll->[$k]}) {
#warn "...... On $k/$kk: I see `$ll->[$k][$kk]'; seen=`$seen[$k]{$ll->[$k][$kk]}'; keys=", join(',',keys %{$seen[$k]}) if defined $ll->[$k][$kk];
	  my $ch = $ll->[$k][$kk];
	  my $rch = $R[$l][$k][$kk];
	  $ch = $ch->[0] if $ch and ref $ch;
	  $rch = $rch->[0] if $rch and ref $rch;
          $keys[$k][$kk] = $ll->[$k][$kk] 	# Deep copy
            if defined $ch and not defined $keys[$k][$kk] 
               and ($whole ? !$seen[$k]{$ch} : $ch ne ( defined $rch ? $rch : '' ));
        }
        $keys[$k] ||= [];
      }
    }
    $self->{layers}{$name} = \@keys;
  }
  warn "NOID --> <@out>\n" if debug_noid;
  @out;
}

sub paren_match_q ($$) {
  my ($self, $s) = (shift, shift);
  ($s =~ tr/(/(/) == ($s =~ tr/)/)/)
}

sub brackets_match_q ($$) {
  my ($self, $s) = (shift, shift);
  ($s =~ tr/[/[/) == ($s =~ tr/]/]/)
}

sub join_min_paren_brackets_matched ($$@) {
  my ($self, $join, @out) = (shift, shift, shift);
#warn 'joining <', join('> <', @out, @_),'>';
  while (@_) {
    while (@_ and not ($self->paren_match_q($out[-1]) and $self->brackets_match_q($out[-1]))) {
      $out[-1] .= $join . shift;
    }
    push @out, shift if @_;
  }
  @out
}

sub layers_by_face_recipe ($$$) {
  my ($self, $face, $base) = (shift, shift, shift);
  die "No face recipe for `$face' found" unless my $r = $self->{face_recipes}{$face};
  $r = $self->recipe2str($r);
#print "face recipe `$face'\n";
  my $LL = $self->{faces}{$base}{layers};
  warn "Using face_recipes for `$face', base=$base ==> `$r'\n" if debug_face_layout_recipes;
  my $L = $self->{faces}{$face}{layers} = $self->make_translated_layers($r, $base, [0..$#$LL]);
#print "face recipe `$face'  -> ", $self->array2string($L), "\n";
#  warn "Using face_recipes `$face'  -> ", $self->array2string($L) if debug_face_layout_recipes;
  warn "Massaged face `$face' ->", (join "\n\t", '', @$L), "\n" if debug_face_layout_recipes;
#warn "face recipe `$face' --> ", $self->array2string([map $self->{layers}{$_}, @$L]);
  $L;
}

sub export_layers ($$$) {
  my ($self, $face, $base) = (shift, shift, shift);
  $self->{faces}{$face}{'[ini_layers_prefix]'} || $self->{faces}{$face}{'[ini_layers]'} || 
    $self->{faces}{$face}{layers} 
      || $self->layers_by_face_recipe($face, $base)
}

sub pseudo_layer ($$$$) {
  my ($self, $recipe, $face, $N) = (shift, shift, shift, shift);
  my $ll = my $l = $self->pseudo_layer0($recipe, $face, $N);
#  warn "Pseudo-layer recipe `$recipe', face=`$face', N=$N ->\n\t$l\n" if $recipe =~ /Greek__/;
#warn("layer recipe: `$l'"), 
  ($l = $self->layer_recipe($l)) =~ s/^\s+// if exists $self->{layer_recipes}{$ll};
  warn "pseudo_layer(`$recipe'): Using layout_recipe `$l' for layer '$ll'\n" if debug_face_layout_recipes and exists $self->{layer_recipes}{$ll};
  return $l if $self->{layers}{$l};
  ($self->make_translated_layers($l, $face, [$N]))->[0]
#  die "Component `$l' of a pseudo-layer cannot be resolved"
}

sub pseudo_layer0 ($$$$) {
  my ($self, $recipe, $face, $N) = (shift, shift, shift, shift);
  if ($recipe eq 'LinkFace') {
    my $L = $self->{faces}{$face}{LinkFace} or die "Face `$face' has no LinkFace";
    return ($self->export_layers($L, $face))->[$N];
  }
  return ($self->export_layers($face, $face))->[$N] if $recipe eq 'Self';
  if ($recipe =~ /^Layers\((.*\+.*)\)$/) {
    my @L = split /\+/, "$1";
    return $L[$N];
  }
  my $N1 = $self->flip_layer_N($N, $#{ $self->{faces}{$face}{layers} });
  if ($recipe eq 'FlipLayersLinkFace') {
    my $L = $self->{faces}{$face}{LinkFace} or die "Face `$face' has no LinkFace";
    return ($self->export_layers($L, $face))->[$N1];
  }
#warn "Doing flip/face via `$recipe', N=$N, N1=$N1, face=`$face'";
  return ($self->export_layers($face, $face))->[$N1] if $recipe eq 'FlipLayers';
#  my $gr_debug = ($recipe =~ /Greek__/);
  if (debug_PERL_dollar1_scoping) {
    return ($self->export_layers("$2", $face))->[$1 ? $N : $N1]
      if $recipe =~ /^(?:(Face)|FlipLayers)\((.*)\)$/;
  } else {
    my $m1;	# Apparently, in perl5.10, if replace $m1 by $1 below, $1 loses its TRUE value between match and evaluation of $1
#  ($gr_debug and warn "Pseudo-layer `$recipe', face=`$face', N=$N, N1=$N1\n"),
    return ($self->export_layers("$2", $face))->[$m1 ? $N : $N1]
      if $recipe =~ /^(?:(Face)|FlipLayers)\((.*)\)$/ and ($m1 = $1, 1);
  }
  die "Unrecognized Face recipe `$recipe'"
}

#  my @LL = map $self->{layers}{'[ini_copy1]'}{$_} || $self->{layers}{'[ini_copy]'}{$_} || $self->{layers}{$_}, @$LL;

# A stand-alone word is either LinkFace, or is interpreted as a name of 
# translation function applied to the current face.
# A name which is an argument to a function is allowed to be a layer name
#  (but note that then both layers of the face will be mapped to that same 
#   layer - unless one restricts the recipe to a particular layer 0/1 of the 
#   face).  
# In particular: to specify a layer, use Id(LayerName).
#use Dumpvalue;
sub make_translated_layers ($$$$;$$) {		# support Self/FlipLayers/LinkFace/FlipShift, stacking and maps
  my ($self, $recipe, $face, $NN, $deadkey, $noid, $append, $ARG) = (shift, shift, shift, shift, shift, shift, '');
# XXX We can't cache created layer by name, since it depends on $recipe and $N too???
#  return $recipe if exists $self->{layers}{$recipe};
#  my $FACE = $recipe . join '===', '', @$NN, '';
#  return $self->{faces}{$FACE}{layers} if exists $self->{faces}{$FACE}{layers};
  return [map $self->pseudo_layer($recipe, $face, $_), @$NN]
    if $recipe =~ /^((FlipLayers)?LinkFace|FlipLayers|Self|(Face|FlipLayers|Layers)\([^()]+\))$/;
  $recipe =~ s/^(FlipShift)$/$1(Self)/;
  my @parts = grep /\S/, $self->join_min_paren_brackets_matched('', split /(\s+)/, $recipe)
    or die "Whitespace face recipe `$recipe'?!";
  if (@parts > 1) {
#warn "parts of the translation spec: <", join('> <', @parts), '>';
    my @layers = map $self->make_translated_layers($_, $face, $NN, $deadkey), @parts;
    warn "Stacking/NOID for layers `@parts'", (join "\n\t", '', map {join ' &&& ', @$_} @layers), "\n" if debug_noid or debug_stacking;
#print "Stacking for `$recipe'\n" if $DEBUG;
#Dumpvalue->new()->dumpValue(\@layers) if $DEBUG;
    return [$self->make_translated_layers_noid($noid eq 'NotSameKey', @layers)]
      if $noid;
    return [$self->make_translated_layers_stack(@layers)];
  }
  if ( $recipe =~ /\)$/ ) {
    if ( $recipe =~ /^[^(]*\[/ ) {		# Tricky: allow () inside Func[](args)
      my $pos;
      while ( $recipe =~ /(?=\]\()/g ) {
        $pos = 1 + pos $recipe, last if $self->brackets_match_q(substr $recipe, 0, 1 + pos $recipe)
      }
      die "Can't parse `$recipe' as Func[Arg1](Arg2)" unless $pos;
      $ARG = substr $recipe, $pos + 1, length($recipe) - $pos - 2;
      $recipe = substr $recipe, 0, $pos;
    } else {
      ($recipe, $ARG) = ($recipe =~ /^(.*?)\((.*)\)$/s);
    }
  } else {
    $ARG = '';
  }
#warn "Translation sub-spec: recipe = <$recipe>, ARG=<$ARG>";
  if (length $ARG) {
    if (exists $self->{layers}{$ARG}) {
      $ARG = [($ARG) x @$NN];
    } else {
      ($ARG = $self->layer_recipe($ARG)) =~ s/^\s+// if exists $self->{layer_recipes}{my $a = $ARG};
      warn "make_translated_layers: Using layout_recipe `$ARG' for layer '$a'\n" if debug_face_layout_recipes and exists $self->{layer_recipes}{$a};
      ($noid) = ($recipe =~ /^(NotId|NotSameKey)$/);
      $ARG = $self->make_translated_layers($ARG, $face, $NN, $deadkey, $noid);
      return $ARG if $noid;
    }
  } else {
    $ARG = [map $self->{faces}{$face}{layers}[$_], @$NN];
    $append = "#$face#";
  }
  [$self->make_translated_layers_tr($ARG, $recipe, $append, $deadkey, $face, $NN)];	# Either we saw (), or $recipe is not a face recipe!
}

sub massage_translated_layers ($$$$;$) {
  my ($self, $in, $face, $NN, $deadkey) = (shift, shift, shift, shift, shift, '');
#warn "Massaging `$deadkey' for `$face':$N";
  return $in unless my $r = $self->get_deep($self, 'faces', (my @p = split m(/), $face), '[Diacritic_if_undef]');
  $r =~ s/^\s+//;
#warn "	-> end recipe `$r'";
  my $post = $self->make_translated_layers($r, $face, $NN, $deadkey);
  return [$self->make_translated_layers_stack($in, $post)];
}

sub default_char ($$) {
  my ($self, $F) = (shift, shift);
  my $default = $self->get_deep($self, 'faces', $F, '[DeadChar_DefaultTranslation]');
  $default =~ s/^\s+//, $default = $self->charhex2key($default) if defined $default;
  $default;
}

sub create_inverted_face ($$$$$) {
  my ($self, $F, $KK, $chain, $flip_AltGr) = (shift, shift, shift, shift, shift);
  my $H = $self->{faces}{$F};
  my $auto_chr = $H->{'[deadkeyInvAltGrKey]'}{$KK};
  my $new_facename = $H->{'[deadkeyFaceInvAltGr]'}{$auto_chr};
  my ($LL, %Map) = $H->{'[deadkeyLayers]'}{$KK};
  $LL = $H->{layers} if $KK eq '';
  %Map = ($flip_AltGr, [$chain->{$KK and $self->charhex2key($KK)}, undef, 1, 'AltGrInv-faces-chain']) 
    if defined $flip_AltGr and defined $chain->{$KK and $self->charhex2key($KK)};  				    
  $self->patch_face($LL, $new_facename, $H->{"[InvdeadkeyLayers]"}{$KK}, $KK, \%Map, $F, 'invert');

# warn "Joining <$F>, <$new_facename>";
  $self->link_layers($F, $new_facename, 'skipfix', 'no-slot-warn');
  if ($KK eq '' and defined $flip_AltGr) {
    $H->{'[deadkeyFace]'}{$self->key2hex($flip_AltGr)} = $H->{'[deadkeyFaceInvAltGr]'}{$auto_chr};
  }
  if ($H->{"[InvdeadkeyLayers]"}{$KK}) {		# There are overrides for the inverted face.  Make a map for them...
#warn "Overriding face for inverted `$KK' in face $F; new_facename=$new_facename";
    $H->{'[InvAltGrFace]'}{$KK} = "$new_facename\@override";
    $self->{faces}{"$new_facename\@override"}{layers} = $H->{"[InvdeadkeyLayers]"}{$KK};
    $self->link_layers($F, "$new_facename\@override", 'skipfix', 'no-slot-warn');
  }
  $new_facename;
}

sub next_auto_dead ($$) {
  my ($self, $H, $o) = (shift, shift);
  1 while $H->{'[auto_dead]'}{ $o = $H->{'[first_auto_dead]'}++ }++;
  chr $o;
}

sub recipe2str ($$) {
  (undef, my $recipe) = (shift, shift);
   if ('ARRAY' eq ref $recipe) {
     $recipe = [@$recipe];			# deep copy
     s/\s+$//, s/^\s+// for @$recipe;
     s/(?<![|,])$/ / for @$recipe[0..($#$recipe - 1)];	# Join by spaces unless after comma or |
     $recipe = join '', @$recipe;
   }
   $recipe =~ s/^\s+//;
   $recipe
}

#use Dumpvalue;
sub create_composite_layers ($) {
  my ($self, %h, $expl) = (shift);
#Dumpvalue->new()->dumpValue($self);
  my $filter = qr(^faces(?:/(.*))?/DeadKey_Map([0-9a-f]{4+})?(_\d)?$)i;
  my @F = grep m(^faces(/.*)?$), @{$self->{'[keys]'}};
  for my $FF (@F) {
    (my $F = $FF) =~ s(^faces/?)();
    my(@FF, @HH) = split m(/), $FF;
    next if @FF == 1 or $FF[-1] eq 'VK';
    my @FF1 = @FF;
    push(@HH, $self->get_deep($self, @FF1)), pop @FF1 while @FF1;
    my $H = $HH[0];
    next if $H->{PartialFace};
    $self->{faces}{$F} = $H if $F =~ m(/) and exists $H->{layers};			# Make a direct-access copy
#warn "Face section `${FF}'s parents: ", scalar @HH;
#warn "Mismatch of hashes for `$FF'" unless $self->{faces}{$F} == $H;

    # warn "compositing: faces `$F'; -> <", (join '> <', %$H), ">";
    my (%seen, @H, @H1, %SEEN);
    for my $HH (@HH) {
      for my $k ( keys %$HH ) {
# warn "\t`$k' -> `$HH->{$k}'";
        next unless $k =~ m(^DeadKey_(Inv|Add)?Map([0-9a-f]{4,})?(?:_(\d+))?$)i;
#warn "\t`$k' -> `$HH->{$k}'";
        my($inv, $key, $layers) = ($1 || '', $2, $3);
        my $ref = ((defined $key) ? \@H : \@H1);	# Put undefined at the end
        $key = $self->key2hex($self->charhex2key($key)) if defined $key;			# get rid of uc/lc hex problem
        # XXXX The problem is that the parent may define layers in different ways (_0,_1 or no); ignore it for now...
        $seen{$key || ''}++;
        push @$ref, [$k, $key, $layers, $inv, $HH] unless $SEEN{($key || '') . "_$inv" . (defined $layers ? $layers : '')}++;
      }
    }
    # Treat first the specific maps (for one deadkey) then the deadkeys which were not seen via the universal map
    for my $k1 ( @H, @H1 ) {		# [ ConfigHash key, hex deadkey, layer number ]
      my($k, $key, $layers, $inv, $HH, $face) = (@$k1, $F);
      $layers = ((defined $layers) ? [$layers] : [ 0 .. $#{$self->{faces}{$face}{layers}} ]);
      my @keys = ((defined $key) ? $key : (grep {not $seen{$_}} map $self->key2hex($_), keys %{ $H->{'[DEAD]'} }));
      @keys = '' if $inv and "$inv @keys" eq "Inv 0000";
      my $recipe = $self->recipe2str($HH->{$k});
      my $massage = !($recipe =~ s/\s+NoDefaultTranslation$//);
      for my $KK (@keys) {
#warn "Doing key `$KK' inv=`$inv' face=`$face', recipe=`$recipe'";
        my $new = $self->make_translated_layers($recipe, $face, $layers, $KK);
	$new = $self->massage_translated_layers($new,    $face, $layers, $KK) if $massage and not $inv;
        for my $NN (0..$#$layers) {	# Create a layer according to the spec
#warn "DeadKey Layer for face=$face; layer=$layer, k=$k:\n\t$HH->{$k}, key=`", ($key||''),"'\n\t\t";
#$DEBUG = $key eq '0192';
#print "Doing key `$KK' face=$face  layer=`$layer' recipe=`$recipe'\n" if $DEBUG;
#Dumpvalue->new()->dumpValue($self->{layers}{$new}) if $DEBUG;
#warn "new=<<<", join('>>> <<<', @$new),'>>>';
          $H->{"[${inv}deadkeyLayers]"}{$KK}[$layers->[$NN]] = $new->[$NN];
#warn "Face `$face', layer=$layer key=$KK\t=> `$new'" if $H->{layers}[$layer] =~ /00a9/i;
#Dumpvalue->new()->dumpValue($self->{layers}{$new}) if $self->charhex2key($key) eq chr 0x00a9;
        }
      }
    }
    next unless $H->{'[deadkeyLayers]'};		# Are we in a no-nonsense Face-hash with defined deadkeys?
#warn "Face: <", join( '> <', %$H), ">";
    my $layerL = @{ $self->{layers}{ $H->{layers}[0] } };	# number of keys in the face (in the principal layer)
    my $first_auto_dead = $self->get_deep_via_parents($self, undef, @FF, 'Auto_Diacritic_Start');
    $H->{'[first_auto_dead]'} = ord $self->charhex2key($first_auto_dead) if defined $first_auto_dead;
    for my $KK (sort keys %{$H->{'[deadkeyLayers]'}}) {		# Given a deadkey: join layers into a face, and link to it
      for my $layer ( 0 .. $#{ $H->{layers} } ) {
#warn "Checking for empty layers, Face `$face', layer=$layer key=$KK";
        $self->{layers}{"[empty$layerL]"} ||= [map[], 1..$layerL], $H->{'[deadkeyLayers]'}{$KK}[$layer] = "[empty$layerL]"
          unless defined $H->{'[deadkeyLayers]'}{$KK}[$layer]
      }
      # Join the syntetic layers (now well-formed) into a new synthetic face:
      my $new_facename = "$F###$KK";
      $self->{faces}{$new_facename}{layers} = $H->{'[deadkeyLayers]'}{$KK};
      $H->{'[deadkeyFace]'}{$KK} = $new_facename;
#warn "Joining <$F>, <$new_facename>";
#      $self->link_layers($F, $new_facename, 'skipfix', 'no-slot-warn');	# Now moved to link_composite_layers
    }
  }
  $self
}

sub create_prefix_chains ($) {
  my ($self, %h, $expl) = (shift);
  my @F = grep m(^faces(/.*)?$), @{$self->{'[keys]'}};
  for my $FF (@F) {
    (my $F = $FF) =~ s(^faces/?)();
    my(@FF, @HH) = split m(/), $FF;
    next if @FF == 1 or $FF[-1] eq 'VK';
    push(@HH, $self->get_deep($self, @FF)), pop @FF while @FF;
    my($H, %KK) = $HH[0];
    for my $chain ( @{ $H->{'[PrefixChains]'} || [] } ) {
      (my $c = $chain) =~ s/^\s+//;
      my @prefix = map { $_ and $self->charhex2key($_) } split /,/, $c, -1;		# trailing empty means all are prefixes
      length(my $trail_nonprefix = $prefix[-1]) or pop @prefix;
      my $start = shift @prefix;
      warn "PrefixChain for `$start' in font `$F' is empty" unless @prefix > 1;
      for my $Kn (1..$#prefix) {
        my($from, $to) = @prefix[$Kn-1, $Kn];
        $KK{$from}{$start} = [$to, undef, $Kn != $#prefix || !$trail_nonprefix, 'PrefixChains'];
      }
    }
    for my $K (keys %KK) {
      my $KK = $self->key2hex($K);
      die "Key `$KK=$K' in PrefixChain for font=`$F' is not a prefix" unless my $KF = $H->{'[deadkeyFace]'}{$KK};
      my $new_facename = "$F*==>*Chain*$KK";
      my $LL = $H->{'[deadkeyLayers]'}{$KK};
      $self->patch_face($LL, $new_facename, undef, "chain-in-$KK", $KK{$K}, $F, !'invert');
      $H->{'[deadkeyFace]'}{$KK} = $new_facename;
      $H->{'[deadkeyLayers]'}{$KK} = $self->{faces}{$new_facename}{layers};
      $self->coverage_face0($new_facename, 'after import');
    }
  }
  $self
}

sub link_composite_layers ($) {		# as above, but finish 
  my ($self, %h, $expl) = (shift);
  my @F = grep m(^faces(/.*)?$), @{$self->{'[keys]'}};
  for my $FF (@F) {
    (my $F = $FF) =~ s(^faces/?)();
    my(@FF, @HH) = split m(/), $FF;
    next if @FF == 1 or $FF[-1] eq 'VK';
    push(@HH, $self->get_deep($self, @FF)), pop @FF while @FF;
    my $H = $HH[0];
    for my $new_facename (values %{$H->{'[deadkeyFace]'}}) {
#warn "Joining <$F>, <$new_facename>";
      $self->link_layers($F, $new_facename, 'skipfix', 'no-slot-warn');
    }
  }
  $self
}

sub create_inverted_faces ($) {
  my ($self) = (shift);
#Dumpvalue->new()->dumpValue($self);
  for my $F (keys %{$self->{faces} }) {
    next if 'HASH' ne ref $self->{faces}{$F} or $F =~ /\bVK$/;			# "parent" taking keys for a child
    my $H = $self->{faces}{$F};
    next unless $H->{'[deadkeyLayers]'};		# Are we in a no-nonsense Face-hash with defined deadkeys?
    my $expl = $self->get_deep($self, 'faces', (split m(/), $F), 'Explicit_AltGr_Invert') || [];
    $expl = [], warn "Odd number of elements of Explicit_AltGr_Invert in face $F, ignore" if @$expl % 2;
    $expl = {map $self->charhex2key($_), @$expl};

#warn "Face: <", join( '> <', %$H), ">";
    my $layerL = @{ $self->{layers}{ $H->{layers}[0] } };	# number of keys in the face (in the principal layer)
    for my $KK (sort keys %{$H->{'[deadkeyLayers]'}}) {  # Create AltGr-inverted face if there is at least one key in the AltGr face:
      my $LL = $H->{'[deadkeyLayers]'}{$KK};
      # To check that a key is defined, we do not care about whether a shift-state is encoded as a string, or as an array:
      next unless defined $H->{'[first_auto_dead]'} and grep defined, map $self->flatten_arrays($_), map $self->{layers}{$_}, @$LL[1..$#$LL];
      $H->{'[deadkeyInvAltGrKey]'}{''} = $self->next_auto_dead($H) unless exists $H->{'[deadkeyInvAltGrKey]'}{''};	# Prefix key for principal invertred face
      my $auto_chr = $H->{'[deadkeyInvAltGrKey]'}{$KK} = 
        ((exists $expl->{$self->charhex2key($KK)}) ? $expl->{$self->charhex2key($KK)} : $self->next_auto_dead($H));
      $H->{'[deadkeyFaceInvAltGr]'}{$auto_chr} = "$F##Inv#$KK";
    }
    next unless defined (my $flip_AltGr =  $H->{'[Flip_AltGr_Key]'});
    $flip_AltGr = $self->charhex2key($flip_AltGr) if defined $flip_AltGr;
    $H->{'[deadkeyFaceInvAltGr]'}{ $H->{'[deadkeyInvAltGrKey]'}{''} } = "$F##Inv#" if exists $H->{'[deadkeyInvAltGrKey]'}{''};
    my ($prev, %chain) = '';
    for my $k ( @{ $H->{chainAltGr} || [] }) {
      my $K  = $self->charhex2key($k);
      my $KK = $self->key2hex($K);
      warn("Deadkey `  $K  ' of face $F has no associated AltGr-inverted face"), next
        unless exists $H->{'[deadkeyInvAltGrKey]'}{$KK};
      $chain{$prev} = $H->{'[deadkeyInvAltGrKey]'}{$KK};
#warn "chain `$prev' --> `$K' => $H->{'[deadkeyInvAltGrKey]'}{$KK}";
      $H->{'[dead2_AltGr_chain]'}{(length $prev) ? $self->key2hex($prev) : ''}++;
      $prev = $K;
    }
    for my $KK (keys %{$H->{'[deadkeyInvAltGrKey]'}}) {	# Now know which deadkeys take inversion, and via what prefix
      my $new = $self->create_inverted_face($F, $KK, \%chain, $flip_AltGr);
      $self->coverage_face0($new);
    }
    # We do not link the AltGr-inverted faces to the "parent" faces here.  Currently, it should be done when
    # outputting a kbd description...
  }
  $self
}

#use Dumpvalue;
sub patch_face ($$$$$$$;$) {	# flip layers paying attention to linked AltGr-inverted faces, and overrides
  my ($self, $LL, $newname, $prefix, $mapId, $Map, $face, $inv, @K) = (shift, shift, shift, shift, shift, shift, shift, shift);
  if (%$Map) {			# Borrow from make_translated_layer_tr()
    my $Tr = sub ($) { my $c = shift; defined $c or return $c; $c = $c->[0] if ref $c; my $o = $Map->{$c} ;
#warn "Tr: `$c' --> `$o'" if defined $o;
#$o
    };
    $Tr = $self->depth1_A_translator($Tr);
    my $LLL = $self->{faces}{$face}{layers};
    my $mod_name = ($inv ? 'AltGr' : '');
    for my $n (0..$#$LL) {					# Layer number
      my $new_Name = "$face##Chain$mod_name#$n.." . $mapId;
#warn "AltGr-chaining: name=$new_Name; `$chainKey' => `$nextL'";
      $self->{layers}{$new_Name} ||= [ map $Tr->($_), @{ $self->{layers}{ $LLL->[$n] } }];
      push @K, $new_Name;
    }
  }
  my @prefix = $prefix ? $prefix : ();
  my @n1 = (0..$#$LL);
  @n1 = map $self->flip_layer_N($_, $#$LL), @n1 if $inv;
  my @invLL = @$LL[@n1];
  push @prefix, \@K if @K;
  $self->{faces}{$newname}{layers} = [$self->make_translated_layers_stack(@prefix, \@invLL)];
}

# use Dumpvalue;
sub fmt_bitmap_mods ($$;$) {
  my ($self, $b, $short, @b) = (shift, shift, shift, qw(Shift Ctrl Alt Kana Hyper));
  my ($j, $empty, @ind) = ($short ? ('', '-', 1..$#b, 0) : ("\t", '', 0..$#b));	# better have Shift at end (Ctrl-Alt-Shift)...
  join $j, map {($b & (1<<$_)) ? ($short ? substr $b[$_], 0, 1 : $b[$_]) : $empty} @ind;
}

sub fill_win_template ($$$) {
  my @K = qw( COMPANYNAME LAYOUTNAME COPYR_YEARS LOCALE_NAME LOCALE_ID DLLNAME SORT_ORDER_ID_ LANGUAGE_NAME );
  my ($self, $t, $k, %h) = (shift, shift, shift);
# Dumpvalue->new()->dumpValue($self);
  my $idx = $self->get_deep($self, @$k, 'MetaData_Index');
  @h{@K} = map $self->get_deep_via_parents($self, $idx, @$k, $_), @K;
# warn "Translate: ", %h;
  my $F = $self->get_deep($self, @$k);		# Presumably a face hash, as in $k = [qw(faces US)]
  my $b = $F->{BaseLayer};
  $b = $self->pseudo_layer($b, $k->[-1], 0) if defined $b and not $self->{layers}{$b};
  $F->{'[dead-used]'} = [map {}, @{$F->{layers}}];		# Which of deadkeys are reachable on the keyboard
  my $cnt = $F->{'[non_VK]'};
  $h{LAYOUT_KEYS}  = join '', $self->output_layout_win($k->[-1], $F->{layers}, $b, $F->{'[dead]'}, $F->{'[dead-used]'}, $cnt);
  $h{LAYOUT_KEYS} .= join '', $self->output_VK_win($k->[-1], $F->{'[dead-used]'});
  $h{LAYOUT_KEYS} .= join '', $self->output_added_units();

  $h{DO_LIGA} = join '', $self->output_ligatures();
  $h{DO_LIGA} = <<EOPREF . "$h{DO_LIGA}\n" if $h{DO_LIGA};

LIGATURE

// VK_		ModCol#	Char0	Char1	Char2	Char3
// ---------	-------	-----	-----	-----	-----


EOPREF

  ### Deadkeys???   need_extra_keys_to_access???
  my ($OUT, $OUT_NAMES) = ('', "KEYNAME_DEAD\n\n");
  
  my $f = $self->get_AgeList;
  $self->load_uniage($f) if defined $f and not $self->{Age};

  my $flip_AltGr_hex =  $F->{'[Flip_AltGr_Key]'};
  $flip_AltGr_hex = $self->key2hex($self->charhex2key($flip_AltGr_hex)) if defined $flip_AltGr_hex;
  for my $deadKey ( sort keys %{ $F->{'[deadkeyFace]'} } ) {
    my $auto_inv_AltGr = $F->{'[deadkeyInvAltGrKey]'}{$deadKey};
    $auto_inv_AltGr = $self->key2hex($auto_inv_AltGr) if defined $auto_inv_AltGr;
#warn "flipkey=$flip_AltGr_hex, dead=$deadKey" if defined $flip_AltGr_hex;
    (my $nonempty, my $MAP) = $self->print_deadkey_win($k->[-1], $deadKey, $F->{'[dead2]'}, $flip_AltGr_hex, $auto_inv_AltGr);
    $OUT .= "$MAP\n";
    my $N = $self->{DEADKEYS}{$deadKey} || $self->{'[seen_knames]'}{chr hex $deadKey}
	|| $self->UName($deadKey);		# = $map->[1]{name};
    if (defined $N and length $N) {
      $OUT_NAMES .= qq($deadKey\t"$N"\n);
    } else {
      warn "DeadKey `$deadKey' for face `@$k' has no name associated"
    }
  }
#warn "Translate: ", %h;
  $h{DEADKEYS} = $OUT;
  $h{KEYNAMES_DEAD} = $OUT_NAMES;
  my %mods = qw( S 1 C 2 A 4 K 8 H 16 );
  $_ += 0 for values %mods;			# Convert to numbers, so | works as expected
  my @cols;
  for my $mod ( @{ $self->get_deep($self, @$k, '[layers_modifiers]') || ['', 'CA'] } ) {	# Plain, and Control-Alt
    my $mask = 0;
    $mask |= $mods{$_} for split //, $mod;
    push @cols, $mask;
  }
  @cols = map {($_, $_ | $mods{S})} @cols;	# Add shift

  my $pre_ctrl = $self->get_deep($self, @$k, '[ctrl_after_modcol]');
  $pre_ctrl = 2*$ctrl_after unless defined $pre_ctrl;
  my $create_a_c = $self->get_deep($self, @$k, '[create_alpha_ctrl]');
  $create_a_c = $create_alpha_ctrl unless defined $create_a_c;
  splice @cols, $pre_ctrl, 0, $mods{C}, ($create_a_c>1 ? $mods{C}|$mods{S} : ());	# Control (and maybe Control-Shift)
  $h{COL_HEADERS} = join "\t", @cols;
  $h{COL_EXPL} = join "\t", map '-' . $self->fmt_bitmap_mods($_, 'short') . '-', @cols;
  $h{BITS_TEMPLATE} = join "\n", map { "$cols[$_]\t// Column " . (4+$_) . " :\t" . $self->fmt_bitmap_mods($cols[$_]) } 0..$#cols;
  $self->massage_template($template_win, \%h);
}

my $unused = <<'EOR';
	# extract compositions, add <upgrade> to char downgrades; -> composition, => compatibility composition
perl -wlne "$k=$1, next if /^([\da-f]+)/i; undef $a; $a = qq($k -> $1) if /^\s+:\s*([0-9A-F]+(?:\s+[0-9A-F]+)*)/; $a = qq($k => $2 $1) if /^\s+#\s*((?:<.*?>\s+)?)([0-9A-F]+(?:\s+[0-9A-F]+)*)/; next unless $a; $a =~ s/\s*$/ <upgrade>/ unless $a =~ />\s+\S.*\s\S/; print $a" NamesList.txt >compose2b-NamesList.txt
	# expand recursively
perl -wlne "/^(.+?)\s+([-=])>\s+(.+?)\s*$/ or die; $t{$1} = $3; $h{$1}=$2; sub t($); sub t($) {my $i=shift; return $n{$i} if exists $n{$i}; return $i unless $t{$i}; $t{$i} =~ /^(\S+)(.*)/ or die $i; return t($1).$2} END{print qq($_\t:$h{$_} ), join q( ), sort split /\s+/, t($_) for sort {hex $a <=> hex $b} keys %t}" compose2b-NamesList.txt >compose3c-NamesList.txt

#### perl -wlne "($k,$r)=/^(\S+)\s+:[-=]\s+(.*?)\s*$/ or die; $k{$r} = $k; $r{$k}=$r; END { for my $k (sort {hex $a <=> hex $b} keys %r) { my @r = split /\s+/, $r{$k}; for my $o (1..$#r) {my @rr = @r; splice @rr, $o, 1; my ($rr,$kk) = join q( ), @rr; print qq($k\t<= $kk ), $r[$o] if $kk = $k{$rr}} } }" compose3c-NamesList.txt >compose4-NamesList.txt
perl -wlne "($k,$h,$r)=/^(\S+)\s+:([-=])\s+(.*?)\s*$/ or die; $k{$r} = $k; $r{$k}=$r; $hk{$k}=$hr{$r}= ($h eq q(=)); END { for my $k (sort {hex $a <=> hex $b} keys %r) { my $h = $hk{$k}; my @r = split /\s+/, $r{$k}; print qq($k\t:$h $r{$k}) and next if @r == 2; for my $o (1..$#r) {my @rr = @r; splice @rr, $o, 1; my ($rr,$kk) = join q( ), @rr; print qq($k\t<= $kk ), $r[$o] if $kk = $k{$rr}} } }" compose3c-NamesList.txt >compose4-NamesList.txt


	# Recursively decompose;  :- composition, := compatibility composition
perl -wlne "/^(.+?)\s+([-=])>\s+(.+?)\s*$/ or die; $t{$1} = $3; $h{$1}=$2 if $2 eq q(=); sub t($); sub t($) {my $i=shift; return $n{$i} if exists $n{$i}; return $i unless $t{$i}; $t{$i} =~ /^(\S+)(.*)/ or die $i; my @rr = t($1); return $rr[0].$2, $h{$i} || $rr[1]} END{my(@rr, $h); @rr=t($_), $h = $rr[1] || q(-), (@i = split /\s+/, $rr[0]), print qq($_\t:$h ), join q( ), $i[0], sort @i[1..$#i] for sort {hex $a <=> hex $b} keys %t}" compose2b-NamesList.txt >compose3e-NamesList.txt
	# Recompose parts to get "merge 2" decompositions; <- and <= if involve composition, :- and := otherwise
perl -wlne "($k,$h,$r)=/^(\S+)\s+:([-=])\s+(.*?)\s*$/ or die; $k{$r} = $k; $r{$k}=$r; $hk{$k}=$hr{$r}= ($h eq q(=) ? q(=) : undef); END { for my $k (sort {hex $a <=> hex $b} keys %r) { my $h = $hk{$k} || q(-); my @r = split /\s+/, $r{$k}; print qq($k\t:$h $r{$k}) and next if @r == 2; my %s; for my $o (1..$#r) {my @rr = @r; next if $s{$rr[$o]}++; splice @rr, $o, 1; my ($rr,$kk) = join q( ), @rr; print qq($k\t<), $hk{$k} || $hr{$kk} || q(-), qq( $kk ), $r[$o] if $kk = $k{$rr}} } }" compose3e-NamesList.txt >compose4b-NamesList.txt
	# List of possible modifiers for each char, introduced by -->, separated by //
perl -C31 -wlne "sub f($) {my $i=shift; return $i unless $i=~/^\w/; qq($i ).chr hex $i} sub ff($) {join q( ), map f($_), split /\s+/, shift} my($c,$B,$m) = /^(\S+)\s+[:<][-=]\s+(\S+)\s+(\S+)\s*$/ or die; push @{$c{$B}}, ff qq($m $c); END { for my $k (sort {hex $a <=> hex $b} keys %c) { print f($k), qq(\t--> ), join q( // ), sort @{$c{$k}} } }" compose4b-NamesList.txt >compose5d-NamesList.txt
	# Find what appears as modifiers:
perl -F"\s+//\s+|\s+-->\s+" -wlane "s/\s+[0-9A-F]{4,}(\s\S+)?\s*$//, print for @F[1..$#F]" ! | sort -u >!-words

Duplicate: 0296 <== [ 003F <pseudo-calculated-inverted> <pseudo-phonetized> ] ==> <1 0295> (prefered)
	<ʖ>	LATIN LETTER INVERTED GLOTTAL STOP
	<ʕ>	LATIN LETTER PHARYNGEAL VOICED FRICATIVE at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: 0384 <== [ 0020 0301 ] ==> <1 00B4> (prefered)
	<΄>	GREEK TONOS
	<´>	ACUTE ACCENT at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: 1D43 <== [ 0061 <super> ] ==> <1 00AA> (prefered)
	<ᵃ>	MODIFIER LETTER SMALL A
	<ª>	FEMININE ORDINAL INDICATOR at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: 1D52 <== [ 006F <super> ] ==> <1 00BA> (prefered)
	<ᵒ>	MODIFIER LETTER SMALL O
	<º>	MASCULINE ORDINAL INDICATOR at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: 1D9F <== [ 0065 <pseudo-calculated-open> <pseudo-calculated-reversed> <super> ] ==> <1 1D4C> (prefered)
	<ᶟ>	MODIFIER LETTER SMALL REVERSED OPEN E
	<ᵌ>	MODIFIER LETTER SMALL TURNED OPEN E at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: 1E7A <== [ 0055 0304 0308 ] ==> <0 01D5> (prefered)
	<Ṻ>	LATIN CAPITAL LETTER U WITH MACRON AND DIAERESIS
	<Ǖ>	LATIN CAPITAL LETTER U WITH DIAERESIS AND MACRON at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: 1E7B <== [ 0075 0304 0308 ] ==> <0 01D6> (prefered)
	<ṻ>	LATIN SMALL LETTER U WITH MACRON AND DIAERESIS
	<ǖ>	LATIN SMALL LETTER U WITH DIAERESIS AND MACRON at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: 1FBF <== [ 0020 0313 ] ==> <1 1FBD> (prefered)
	<᾿>	GREEK PSILI
	<᾽>	GREEK KORONIS at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: 2007 <== [ 0020 <noBreak> ] ==> <1 00A0> (prefered)
	< >	FIGURE SPACE
	< >	NO-BREAK SPACE at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: 202F <== [ 0020 <noBreak> ] ==> <1 00A0> (prefered)
	< >	NARROW NO-BREAK SPACE
	< >	NO-BREAK SPACE at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: 2113 <== [ 006C <font=script> ] ==> <1 1D4C1> (prefered)
	<ℓ>	SCRIPT SMALL L
	<퓁>	MATHEMATICAL SCRIPT SMALL L at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: 24B8 <== [ 0043 <circle> ] ==> <1 1F12B> (prefered)
	<Ⓒ>	CIRCLED LATIN CAPITAL LETTER C
	<>	CIRCLED ITALIC LATIN CAPITAL LETTER C at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: 24C7 <== [ 0052 <circle> ] ==> <1 1F12C> (prefered)
	<Ⓡ>	CIRCLED LATIN CAPITAL LETTER R
	<>	CIRCLED ITALIC LATIN CAPITAL LETTER R at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: 2E1E <== [ 007E <pseudo-dot-above> ] ==> <1 2A6A> (prefered)
	<⸞>	TILDE WITH DOT ABOVE
	<⩪>	TILDE OPERATOR WITH DOT ABOVE at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: 33B9 <== [ 004D <square> 0056 ] ==> <1 1F14B> (prefered)
	<㎹>	SQUARE MV MEGA
	<>	SQUARED MV at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: FC03 <== [ 064A <isolated> 0649 0654 ] ==> <1 FBF9> (prefered)
	<ﰃ>	ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH ALEF MAKSURA ISOLATED FORM
	<ﯹ>	ARABIC LIGATURE UIGHUR KIRGHIZ YEH WITH HAMZA ABOVE WITH ALEF MAKSURA ISOLATED FORM at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: FC68 <== [ 064A <final> 0649 0654 ] ==> <1 FBFA> (prefered)
	<ﱨ>	ARABIC LIGATURE YEH WITH HAMZA ABOVE WITH ALEF MAKSURA FINAL FORM
	<ﯺ>	ARABIC LIGATURE UIGHUR KIRGHIZ YEH WITH HAMZA ABOVE WITH ALEF MAKSURA FINAL FORM at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: FD55 <== [ 062A <initial> 062C 0645 ] ==> <1 FD50> (prefered)
	<ﵕ>	ARABIC LIGATURE TEH WITH MEEM WITH JEEM INITIAL FORM
	<ﵐ>	ARABIC LIGATURE TEH WITH JEEM WITH MEEM INITIAL FORM at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: FD56 <== [ 062A <initial> 062D 0645 ] ==> <1 FD53> (prefered)
	<ﵖ>	ARABIC LIGATURE TEH WITH MEEM WITH HAH INITIAL FORM
	<ﵓ>	ARABIC LIGATURE TEH WITH HAH WITH MEEM INITIAL FORM at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: FD57 <== [ 062A <initial> 062E 0645 ] ==> <1 FD54> (prefered)
	<ﵗ>	ARABIC LIGATURE TEH WITH MEEM WITH KHAH INITIAL FORM
	<ﵔ>	ARABIC LIGATURE TEH WITH KHAH WITH MEEM INITIAL FORM at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: FD5D <== [ 0633 <initial> 062C 062D ] ==> <1 FD5C> (prefered)
	<ﵝ>	ARABIC LIGATURE SEEN WITH JEEM WITH HAH INITIAL FORM
	<ﵜ>	ARABIC LIGATURE SEEN WITH HAH WITH JEEM INITIAL FORM at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: FD87 <== [ 0644 <final> 062D 0645 ] ==> <1 FD80> (prefered)
	<ﶇ>	ARABIC LIGATURE LAM WITH MEEM WITH HAH FINAL FORM
	<ﶀ>	ARABIC LIGATURE LAM WITH HAH WITH MEEM FINAL FORM at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: FD8C <== [ 0645 <initial> 062C 062D ] ==> <1 FD89> (prefered)
	<ﶌ>	ARABIC LIGATURE MEEM WITH JEEM WITH HAH INITIAL FORM
	<ﶉ>	ARABIC LIGATURE MEEM WITH HAH WITH JEEM INITIAL FORM at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: FD92 <== [ 0645 <initial> 062C 062E ] ==> <1 FD8E> (prefered)
	<ﶒ>	ARABIC LIGATURE MEEM WITH JEEM WITH KHAH INITIAL FORM
	<ﶎ>	ARABIC LIGATURE MEEM WITH KHAH WITH JEEM INITIAL FORM at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: FDB5 <== [ 0644 <initial> 062D 0645 ] ==> <1 FD88> (prefered)
	<ﶵ>	ARABIC LIGATURE LAM WITH HAH WITH MEEM INITIAL FORM
	<ﶈ>	ARABIC LIGATURE LAM WITH MEEM WITH HAH INITIAL FORM at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.
Duplicate: FE34 <== [ 005F <vertical> ] ==> <1 FE33> (prefered)
	<︴>	PRESENTATION FORM FOR VERTICAL WAVY LOW LINE
	<︳>	PRESENTATION FORM FOR VERTICAL LOW LINE at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 4224, <$f> line 38879.

Duplicate: 0273 <== [ 006E <pseudo-manual-phonetized> ] ==> <1 014B> (prefered)
	<ɳ>	LATIN SMALL LETTER N WITH RETROFLEX HOOK
	<ŋ>	LATIN SMALL LETTER ENG at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 1DAF <== [ 006E <pseudo-manual-phonetized> <super> ] ==> <1 1D51> (prefered)
	<ᶯ>	MODIFIER LETTER SMALL N WITH RETROFLEX HOOK
	<ᵑ>	MODIFIER LETTER SMALL ENG at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2040 <== [ 007E <pseudo-manual-quasisynon> ] ==> <1 203F> (prefered)
	<⁀>	CHARACTER TIE
	<‿>	UNDERTIE at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 207F <== [ 004E <pseudo-manual-phonetized> ] ==> <1 014A> (prefered)
	<ⁿ>	SUPERSCRIPT LATIN SMALL LETTER N
	<Ŋ>	LATIN CAPITAL LETTER ENG at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 224B <== [ 007E <pseudo-manual-addtilde> ] ==> <1 2248> (prefered)
	<≋>	TRIPLE TILDE
	<≈>	ALMOST EQUAL TO at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2256 <== [ 003D <pseudo-manual-round> ] ==> <1 224D> (prefered)
	<≖>	RING IN EQUAL TO
	<≍>	EQUIVALENT TO at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2257 <== [ 003D <pseudo-manual-round> ] ==> <1 224D> (prefered)
	<≗>	RING EQUAL TO
	<≍>	EQUIVALENT TO at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 225E <== [ 225F <pseudo-manual-quasisynon> ] ==> <1 225C> (prefered)
	<≞>	MEASURED BY
	<≜>	DELTA EQUAL TO at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2263 <== [ 003D <pseudo-manual-addhline> ] ==> <1 2261> (prefered)
	<≣>	STRICTLY EQUIVALENT TO
	<≡>	IDENTICAL TO at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2277 <== [ 003D <pseudo-manual-quasisynon> 0338 ] ==> <1 2276> (prefered)
	<≷>	GREATER-THAN OR LESS-THAN
	<≶>	LESS-THAN OR GREATER-THAN at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2279 <== [ 003D <pseudo-manual-quasisynon> ] ==> <1 2278> (prefered)
	<≹>	NEITHER GREATER-THAN NOR LESS-THAN
	<≸>	NEITHER LESS-THAN NOR GREATER-THAN at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2279 <== [ 003D <pseudo-manual-quasisynon> 0338 0338 ] ==> <1 2278> (prefered)
	<≹>	NEITHER GREATER-THAN NOR LESS-THAN
	<≸>	NEITHER LESS-THAN NOR GREATER-THAN at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2982 <== [ 003A <pseudo-manual-amplify> ] ==> <1 2236> (prefered)
	<⦂>	Z NOTATION TYPE COLON
	<∶>	RATIO at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2993 <== [ 0028 <pseudo-manual-round> ] ==> <1 2985> (prefered)
	<⦓>	LEFT ARC LESS-THAN BRACKET
	<⦅>	LEFT WHITE PARENTHESIS at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2994 <== [ 0029 <pseudo-manual-round> ] ==> <1 2986> (prefered)
	<⦔>	RIGHT ARC GREATER-THAN BRACKET
	<⦆>	RIGHT WHITE PARENTHESIS at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2995 <== [ 0029 <pseudo-manual-round> ] ==> <1 2986> (prefered)
	<⦕>	DOUBLE LEFT ARC GREATER-THAN BRACKET
	<⦆>	RIGHT WHITE PARENTHESIS at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2996 <== [ 0028 <pseudo-manual-round> ] ==> <1 2985> (prefered)
	<⦖>	DOUBLE RIGHT ARC LESS-THAN BRACKET
	<⦅>	LEFT WHITE PARENTHESIS at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 29BC <== [ 0025 <pseudo-manual-round> ] ==> <1 2030> (prefered)
	<⦼>	CIRCLED ANTICLOCKWISE-ROTATED DIVISION SIGN
	<‰>	PER MILLE SIGN at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2A17 <== [ 222B <pseudo-manual-addleft> ] ==> <1 2A10> (prefered)
	<⨗>	INTEGRAL WITH LEFTWARDS ARROW WITH HOOK
	<⨐>	CIRCULATION FUNCTION at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2A34 <== [ 00D7 <pseudo-manual-addleft> ] ==> <1 22C9> (prefered)
	<⨴>	MULTIPLICATION SIGN IN LEFT HALF CIRCLE
	<⋉>	LEFT NORMAL FACTOR SEMIDIRECT PRODUCT at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2A35 <== [ 00D7 <pseudo-manual-addright> ] ==> <1 22CA> (prefered)
	<⨵>	MULTIPLICATION SIGN IN RIGHT HALF CIRCLE
	<⋊>	RIGHT NORMAL FACTOR SEMIDIRECT PRODUCT at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2A36 <== [ 00D7 <pseudo-manual-amplify> ] ==> <1 2A2F> (prefered)
	<⨶>	CIRCLED MULTIPLICATION SIGN WITH CIRCUMFLEX ACCENT
	<⨯>	VECTOR OR CROSS PRODUCT at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2A50 <== [ 00D7 <pseudo-manual-addline> ] ==> <1 2A33> (prefered)
	<⩐>	CLOSED UNION WITH SERIFS AND SMASH PRODUCT
	<⨳>	SMASH PRODUCT at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2ACF <== [ 25C1 <pseudo-manual-amplify> <pseudo-manual-amplify> ] ==> <1 2A1E> (prefered)
	<⫏>	CLOSED SUBSET
	<⨞>	LARGE LEFT TRIANGLE OPERATOR at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2AFB <== [ 2223 <pseudo-manual-amplify> <pseudo-manual-amplify> ] ==> <1 2AF4> (prefered)
	<⫻>	TRIPLE SOLIDUS BINARY RELATION
	<⫴>	TRIPLE VERTICAL BAR BINARY RELATION at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2AFB <== [ 007C <pseudo-manual-addvline> <pseudo-manual-amplify> <pseudo-manual-quasisynon> ] ==> <1 2AF4> (prefered)
	<⫻>	TRIPLE SOLIDUS BINARY RELATION
	<⫴>	TRIPLE VERTICAL BAR BINARY RELATION at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2AFD <== [ 002F <pseudo-manual-amplify> ] ==> <1 2215> (prefered)
	<⫽>	DOUBLE SOLIDUS OPERATOR
	<∕>	DIVISION SLASH at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 2AFF <== [ 007C <pseudo-manual-whiten> ] ==> <1 2AFE> (prefered)
	<⫿>	N-ARY WHITE VERTICAL BAR
	<⫾>	WHITE VERTICAL BAR at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 3018 <== [ 0028 <pseudo-manual-unsharpen> ] ==> <1 27EE> (prefered)
	<〘>	LEFT WHITE TORTOISE SHELL BRACKET
	<⟮>	MATHEMATICAL LEFT FLATTENED PARENTHESIS at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 3019 <== [ 0029 <pseudo-manual-unsharpen> ] ==> <1 27EF> (prefered)
	<〙>	RIGHT WHITE TORTOISE SHELL BRACKET
	<⟯>	MATHEMATICAL RIGHT FLATTENED PARENTHESIS at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: A760 <== [ 0059 <pseudo-fake-paleocontraction-by-last> ] ==> <1 A73C> (prefered)
	<Ꝡ>	LATIN CAPITAL LETTER VY
	<Ꜽ>	LATIN CAPITAL LETTER AY at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: A761 <== [ 0079 <pseudo-fake-paleocontraction-by-last> ] ==> <1 A73D> (prefered)
	<ꝡ>	LATIN SMALL LETTER VY
	<ꜽ>	LATIN SMALL LETTER AY at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 1D4C1 <== [ 006C <font=script> ] ==> <1 2113> (prefered)
	<𝓁>	MATHEMATICAL SCRIPT SMALL L
	<ℓ>	SCRIPT SMALL L at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 1F12B <== [ 0043 <circle> ] ==> <1 24B8> (prefered)
	<🄫>	CIRCLED ITALIC LATIN CAPITAL LETTER C
	<Ⓒ>	CIRCLED LATIN CAPITAL LETTER C at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 1F12C <== [ 0052 <circle> ] ==> <1 24C7> (prefered)
	<🄬>	CIRCLED ITALIC LATIN CAPITAL LETTER R
	<Ⓡ>	CIRCLED LATIN CAPITAL LETTER R at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.
Duplicate: 1F14B <== [ 004D <square> 0056 ] ==> <1 33B9> (prefered)
	<🅋>	SQUARED MV
	<㎹>	SQUARE MV MEGA at UI-KeyboardLayout/lib/UI/KeyboardLayout.pm line 5263, <$f> line 38876.

EOR

my (%known_dups) = map +($_,1), qw(0296 0384 1D43 1D52 1D9F 1E7A 1E7B 1FBF 2007
  202F 2113 24B8 24C7 2E1E 33B9 FC03 FC68 FD55 FD56 FD57 FD5D FD87 FD8C
  FD92 FDB5 FE34
  0273 1DAF 2040 207F 224B 2256 2257 225E 2263 2277 2279 2982 2993 2994 2995 2996 29BC
  2A17 2A34 2A35 2A36 2A50 2ACF 2AFB 2AFD 2AFF 3018 3019 A760 A761 1D4C1 1F12B 1F12C 1F14B);		# As of Unicode 6.1 (questionable: 2982 2ACF)

sub decompose_r($$$$);		# recursive
sub decompose_r($$$$) {		# returns array ref, elts are [$compat, @expand]
  my ($self, $t, $i, $cache, @expand) = (shift, shift, shift, shift);
  return $cache->{$i} if $cache->{$i};
  return $cache->{$i} = [[0, $i]] unless my $In = $t->{$i};
  for my $in (@$In) {
    my $compat = $in->[0];
#warn "i=<$i>, compat=<$compat>, rest=<$in->[1]>";
    my $expand_in = $self->decompose_r($t, $in->[1], $cache);
    $expand_in = $self->deep_copy($expand_in);
#warn "Got: $in->[1] -> <@$expand> from $i = <@$in>";
    for my $expand (@$expand_in) {
      warn "Expansion funny: <@$expand>" if @$expand < 2 or $expand->[0] !~ /^[01]$/;
      $compat = ( shift(@$expand) | $compat);
      warn "!Malformed: $i -> $compat <@$expand>" if $expand->[0] =~ /^[01]$/;
      push @expand, [ $compat, @$expand, @$in[2..$#$in] ];
    }
  }
  return $cache->{$i} = \@expand;
}

sub fromHEX ($) { my $i = shift; $i =~ /^\w/ and hex $i}

my %operators = (DOT => ['MIDDLE DOT', 'FULL STOP'], RING => ['DEGREE SIGN'], DIAMOND => ['WHITE DIAMOND'],
		 'DOUBLE SOLIDUS' => ['PARALLEL TO'], MINUS => ['HYPHEN-MINUS']);

#			THIS IS A MULTIMAP (later one wins)!			■□ ◼◻ ◾◽	◇◆◈⟐⟡⟢⟣⌺	△▲▵▴▽▼▿▾⟁⧊⧋
my %uni_manual = (phonetized => [qw( 0 ə  s ʃ  z ʒ  j ɟ  v ⱱ  n ɳ  N ⁿ  n ŋ  V ɤ  ! ǃ  ? ʔ  ¿ ʕ  | ǀ  f ʄ  F ǂ  x ʘ  X ǁ
				     g ʛ  m ɰ  h ɧ  d ᶑ  C ʗ)],	# z ɮ	(C ʗ is "extras")
		  phonetize2 => [qw( e ɘ  E ɞ  i ɻ  I ɺ)],	# Use some capitalized sources (no uc variants)...
		  phonetize3 => [qw( a ɒ  A Ɒ  e ɜ  E ɝ)],	# Use some capitalized sources (no uc variants)...
		  paleo	     => [qw( & ⁊  W Ƿ  w ƿ  h ƕ  H Ƕ  G Ȝ  g ȝ )],
                    # cut&paste from http://en.wikipedia.org/wiki/Coptic_alphabet
                    # perl -C31 -wne "chomp; ($uc,$lc,undef,undef,$gr) = split /\t/;($ug,$lg)=split /,\s+/, $gr; print qq( $lg $lc $ug $uc)" coptic2 >coptic-tr
                    # Fix stigma, koppa; p/P are actually 900; a/A are for AKHMIMIC KHEI (variant of KHEI on h/H); 
                    # 2e17 ⸗ double hyphen; sampi's are duplicated in both places
                  greek2coptic => [qw(
                     α ⲁ Α Ⲁ β ⲃ Β Ⲃ γ ⲅ Γ Ⲅ δ ⲇ Δ Ⲇ ε ⲉ Ε Ⲉ ϛ ⲋ Ϛ Ⲋ ζ ⲍ Ζ Ⲍ η ⲏ Η Ⲏ ϙ ϭ Ϙ Ϭ ϡ ⳁ Ϡ Ⳁ
                     θ ⲑ Θ Ⲑ ι ⲓ Ι Ⲓ κ ⲕ Κ Ⲕ λ ⲗ Λ Ⲗ μ ⲙ Μ Ⲙ ν ⲛ Ν Ⲛ ξ ⲝ Ξ Ⲝ ο ⲟ Ο Ⲟ 
                     π ⲡ Π Ⲡ ρ ⲣ Ρ Ⲣ σ ⲥ Σ Ⲥ τ ⲧ Τ Ⲧ υ ⲩ Υ Ⲩ φ ⲫ Φ Ⲫ χ ⲭ Χ Ⲭ ψ ⲯ Ψ Ⲯ ω ⲱ Ω Ⲱ  )],
		  latin2extracoptic => [qw( - ⸗
                     s ϣ S Ϣ f ϥ F Ϥ x ϧ X Ϧ h ϩ H Ϩ j ϫ J Ϫ t ϯ T Ϯ p ⳁ P Ⳁ a ⳉ A Ⳉ )],
		  addline    => [qw( 0 ∅  ∅ ⦱  + ∦  ∫ ⨏  • ⊝  / ⫽  ⫽ ⫻  ∮ ⨔  × ⨳  × ⩐ )],	#   ∮ ⨔ a cheat
		  addhline   => [qw( = ≣  = ≡  ≡ ≣  † ‡  + ∦  / ∠  | ∟  . ∸  ∨ ⊻  ∧ ⊼  ◁ ⩤  * ⩮ 
		  		     ⊨ ⫢  ⊦ ⊧  ⊤ ⫧  ⊥ ⫨  ⊣ ⫤  ⊳ ⩥  ⊲ ⩤  ⋄ ⟠  ∫ ⨍  ⨍ ⨎  • ⦵  ( ∈  ) ∋
		  		     ∪ ⩌  ∩ ⩍  ≃ ≅  ⨯ ⨲ )],	# conflict with modifiers: qw( _ ‗ ); ( ∈  ) ∋ not very useful - but logical - with ∈∋ as bluekeys...  2 ƻ destructive
		  addvline   => [qw( ⊢ ⊩  ⊣ ⫣  ⊤ ⫪  ⊥ ⫫  □ ⎅  | ‖  ‖ ⦀  ∫ ⨒  ≢ ⩨  ⩨ ⩩  • ⦶  
		  		     \ ⫮  ° ⫯  . ⫰  ⫲ ⫵  ∞ ⧞  = ⧧  ⧺ ⧻  + ⧺  ∩ ⨙  ∪ ⨚  0 ⦽ )],		#  + ⫲ 
		  addtilde   => [qw( 0 ∝  / ∡  \ ∢  ∫ ∱  ∮ ⨑  : ∻  - ≂  ≠ ≆  ~ ≋  ~ ≈  ∼ ≈  ≃ ≊  ≈ ≋  = ≌  
		  		     ≐ ≏  ( ⟅  ) ⟆  ∧ ⩄  ∨ ⩅  ∩ ⩆  ∪ ⩇  )],	# not on 2A**
		  adddot     => [qw( : ⫶  " ∵  ∫ ⨓  ∮ ⨕  □ ⊡  ◇ ⟐  ( ⦑  ) ⦒  ≟ ≗  ≐ ≑)],	# ⫶ is tricolon, not vert. …   "
		  adddottop  => [qw( + ∔ )],
		  addleft    => [qw( = ≔  × ⨴  × ⋉  \ ⋋  + ⨭  → ⧴  ∫ ⨐  ∫ ⨗  ∮ ∳  ⊂ ⟈  ⊃ ⫐  ⊳ ⧐  ⊢ ⊩  ⊩ ⊪  ⊣ ⟞  
		  		     ◇ ⟢  ▽ ⧨  ≡ ⫢  • ⥀  ⋈ ⧑  ≟ ⩻  ≐ ≓  | ⩘  ≔ ⩴  ⊲ ⫷)],	#  × ⨴ is hidden
		  addright   => [qw( = ≕  × ⨵  × ⋊  / ⋌  + ⨮  - ∹  ∫ ⨔  ∮ ∲  ⊂ ⫏  ⊃ ⟉  ⊲ ⧏  ⊢ ⟝  ⊣ ⫣  
		  		     ◇ ⟣  △ ⧩  • ⥁  ⋈ ⧒  ≟ ⩼  ≐ ≒  | ⩗  ⊳ ⫸  : ⧴)],	#  × ⨵ is hidden
		  sharpen    => [qw( < ≺  > ≻  { ⊰  } ⊱  ( ⟨  ) ⟩  ∧ ⋏  ∨ ⋎  . ⋄  ⟨ ⧼  ⟩ ⧽  ∫ ⨘  
		  		     ⊤ ⩚  ⊥ ⩛  ◇ ⟡  ▽ ⧍  • ⏣  ≟ ≙  + ⧾  - ⧿)],	# ⋆
		  unsharpen  => [qw( < ⊏  > ⊐  ( ⟮  ) ⟯  ∩ ⊓  ∪ ⊔  ∧ ⊓  ∨ ⊔  . ∷  ∫ ⨒  ∮ ⨖  { ⦉  } ⦊
		  		     / ⧄  \ ⧅  ° ⧇  ◇ ⌺  • ⌼  ≟ ≚  ≐ ∺  ( 〘  ) 〙  )],	#   + ⊞  - ⊟  * ⊠  . ⊡  × ⊠,   ( ⦗  ) ⦘  ( 〔  ) 〕
		  whiten     => [qw( [ ⟦  ] ⟧  ( ⟬  ) ⟭  { ⦃  } ⦄  ⊤ ⫪  ⊥ ⫫  ; ⨟  ⊢ ⊫  ⊣ ⫥  ⊔ ⩏  ⊓ ⩎  ∧ ⩓  ∨ ⩔
		  		     : ⦂  | ⫾  | ⫿  • ○  < ⪡  > ⪢  ⊓ ⩎  ⊔ ⩏  )],	# or blacken □ ■  ◻ ◼  ◽ ◾  ◇ ◆  △ ▲  ▵ ▴  ▽ ▼  ▿ ▾
		  quasisynon => [qw( ∈ ∊  ∋ ∍  ≠ ≶  ≠ ≷  = ≸  = ≹  ≼ ⊁  ≽ ⊀  ≺ ⋡  ≻ ⋠  < ≨  > ≩  Δ ∆
		  		     ≤ ⪕  ≥ ⪖  ⊆ ⊅  ⊇ ⊄  ⊂ ⊉  ⊃ ⊈  ⊏ ⋣  ⊐ ⋢  ⊳ ⋬  ⊲ ⋭  … ⋯  / ⟋  \ ⟍
		  		     ( ⦇  ) ⦈  [ ⨽  ] ⨼
		  		     ⊤ ⫟  ⊥ ⫠  ⟂ ⫛  □ ∎  ▽ ∀  ‖ ∥  ≟ ≞  ≟ ≜  ~ ‿  ~ ⁀  ■ ▬ )],	# ( ⟬  ) ⟭ < ≱  > ≰ ≤ ≯  ≥ ≮  * ⋆
		  amplify    => [qw( < ≪  > ≫  ≪ ⋘  ≫ ⋙  ∩ ⋒  ∪ ⋓  ⊂ ⋐  ⊃ ⋑  ( ⟪  ) ⟫  ∼ ∿  = ≝  ∣ ∥  . ⋮  
		  		     ∈ ∊  ∋ ∍  - −  / ∕  \ ∖  √ ∛  ∛ ∜  ∫ ∬  ∬ ∭  ∭ ⨌  ∮ ∯  ∯ ∰  : ⦂  ` ⎖
		  		     : ∶  ≈ ≋  ≏ ≎  ≡ ≣  × ⨯  + ∑  Π ∏  Σ ∑  ρ ∐  ∐ ⨿  ⊥ ⟘  ⊤ ⟙  ⟂ ⫡  ; ⨾  □ ⧈  ◇ ◈
		  		     ⊲ ⨞  ⊢ ⊦  △ ⟁  ∥ ⫴  ⫴ ⫼  / ⫽  ⫽ ⫻  • ●  ⊔ ⩏  ⊓ ⩎  ∧ ⩕  ∨ ⩖  ▷ ⊳  ◁ ⊲
		  		     ⋉ ⧔  ⋊ ⧕  ⋈ ⧓  ⪡ ⫷  ⪢ ⫸  ≟ ≛  ≐ ≎  ⊳ ⫐  ⊲ ⫏  { ❴  } ❵  × ⨶  )],	#   ⋆ ☆  ⋆ ★ ;  ˆ ∧ conflicts with combining-ˆ; * ∏ stops propagation *->×->⋈, : ⦂ hidden; ∥ ⫴; × ⋈ not needed; ∰ ⨌ - ???; ≃ ≌ not useful
		  turnaround => [qw( ∧ ∨  ∩ ∪  ∕ ∖  ⋏ ⋎  ∼ ≀  ⋯ ⋮  … ⋮  ⋰ ⋱  
		  		     8 ∞  ∆ ∇  Α ∀  Ε ∃  ∴ ∵  ≃ ≂
		  		     ∈ ∋  ∉ ∌  ∊ ∍  ∏ ∐  ± ∓  ⊓ ⊔  ≶ ≷  ≸ ≹  ⋀ ⋁  ⋂ ⋃  ⋉ ⋊  ⋋ ⋌  ⋚ ⋛  ≤ ⋜  ≥ ⋝  ≼ ⋞  ≽ ⋟  )],			# XXXX Can't do both directions
		  round      => [qw( < ⊂  > ⊃  = ≖  = ≗  = ≍  ∫ ∮  ∬ ∯  ∭ ∰  ∼ ∾  - ⊸  □ ▢  ∥ ≬  ‖ ≬  • ⦁
		  		     … ∴  ≡ ≋  ⊂ ⟃  ⊃ ⟄  ⊤ ⫙  ⊥ ⟒  ( ⦖  ) ⦕  ( ⦓  ) ⦔  ( ⦅  ) ⦆  ⊳ ⪧  ⊲ ⪦  ≟ ≘  ≐ ≖  . ∘
		  		     [ ⟬  ] ⟭  { ⧼  } ⧽  % ⦼  % ‰  × ⦻  ⨯ ⨷  ∧ ∩ ∨ ∪ )]);	#   = ≈

sub parse_NameList ($$) {
  my ($self, $f, $k, $kk, $name, $_c, %basic, %cached_full, %compose, $version,
      %into2, %ordered, %candidates, %N, %comp2, %NM, %BL, $BL, %G, %NS) = (shift, shift);
  binmode $f;			# NameList.txt is in Latin-1, not unicode
  while (my $s = <$f>) { # extract compositions, add <upgrade> to char downgrades; -> composition, => compatibility composition
    if ($s =~ /^\@\@\@\s+The\s+Unicode\s+Standard\s+(.*?)\s*$/i) {
      $version = $1;
    }
    if ($s =~ /^([\da-f]+)\b\s*(.*?)\s*$/i) {
      my ($K, $Name, $C, $t) = ($1, $2, $self->charhex2key("$1"));
      $N{$Name} = $K;
      $NM{$C} = $Name;		# Not needed for compositions, but handy for user-visible output
      $BL{$C} = $self->charhex2key($BL);		# Used for sorting
      # Finish processing of preceding text
      if (defined $kk) {				# Did not see (official) decomposition
#        warn("see combining: $K  $C  $Name"),
        $NS{$_c}++ if $name =~ /\bCOMBINING\b/ and not ($_c =~ /\p{NonSpacingMark}/);
        if ($name =~ /^(.*?)\s+(?:(WITH)\s+|(?=(?:OVER|ABOVE|PRECEDED\s+BY|BELOW(?=\s+LONG\s+DASH))\s+\b(?!WITH\b|AND\b)))(.*?)\s*$/) {
          push @{$candidates{$k}}, [$1, $3];
          my ($b, $with, $ext) = ($1, $2, $3);
          my @ext = split /\s+AND\s+/, $ext;
          if ($with and @ext > 1) {
            for my $i (0..$#ext) {
              my @ext1 = @ext;
              splice @ext1, $i, 1;
              push @{$candidates{$k}}, ["$b WITH ". (join ' AND ', @ext1), $ext[$i]];
            }
          }
        }
        if ($name =~ /^(.*)\s+(?=OR\s)(.*?)\s*$/) {	# Find the latest possible...
          push @{$candidates{$k}}, [$1, $2];
        }
        if (($t = $name) =~ s/\b(COMBINING(?=\s+CYRILLIC\s+LETTER)|BARRED|SLANTED|APPROXIMATELY|ASYMPTOTICALLY|(?<!\bLETTER\s)SMALL(?!\s+LETTER\b)|ALMOST|^(?:SQUARED|BIG|N-ARY|LARGE)|LUNATE|SIDEWAYS(?:\s+(?:DIAERESIZED|OPEN))?|INVERTED|ARCHAIC|SCRIPT|LONG|MATHEMATICAL|AFRICAN|INSULAR|VISIGOTHIC|MIDDLE-WELSH|BROKEN|TURNED(?:\s+(?:INSULAR|SANS-SERIF))?|REVERSED|OPEN|CLOSED|DOTLESS|TAILLESS|FINAL)\s+|\s+(BAR|SYMBOL|OPERATOR|SIGN|ROTUNDA|LONGA|IN\s+TRIANGLE)$//) {
          push @{$candidates{$k}}, [$t, "calculated-$+"];
          $candidates{$k}[-1][1] .= '-epigraphic'   if $t =~ /\bEPIGRAPHIC\b/;	# will be massaged away from $t later
          $candidates{$k}[-1][0] =~ s/\s+SYMBOL$// and $candidates{$k}[-1][1] .= '-symbol' 
            if $candidates{$k}[-1][1] =~ /\bLUNATE\b/;
# warn("smallcapital $name"),
          $candidates{$k}[-1][1] .= '-smallcaps' if $t =~ /\bSMALL\s+CAPITAL\b/;	# will be massaged away from $t later
# warn "Candidates: <$candidates{$k}[0]>; <$candidates{$k}[1]>";
        }
        if (($t = $name) =~ s/\b(WHITE|BLACK|CIRCLED)\s+//) {
          push @{$candidates{$k}}, [$t, "fake-$1"];
        }
        if (($t = $name) =~ s/\bBLACK\b/WHITE/) {
          push @{$candidates{$k}}, [$t, "fake-black"];
        }
        if (($t = $name) =~ s/\bBUT\s+NOT\b/OR/) {
          push @{$candidates{$k}}, [$t, "fake-but-not"];
        }
        if (($t = $name) =~ s/(^LATIN\b.*\b\w)UM((?:\s+ROTUNDA)?)$/$1$2/) {	# Paleo-latin
          push @{$candidates{$k}}, [$t, "fake-umify"];
        }
        if ((0xa7 == ((hex $k)>>8)) and ($t = $name) =~ s/\b(\w|CO|VEN)(?!\1)(\w)$/$2/) {	# Paleo-latin (CON/VEND + digraph)
          push @{$candidates{$k}}, [$t, "fake-paleocontraction-by-last"];
        }
        if (($t = $name) =~ s/(?:(\bMIDDLE-WELSH)\s+)?\b(\w)(?=\2$)//) {
          push @{$candidates{$k}}, [$t, "fake-doubleletter" . ($1 ? "-$1" : '')];
        }
        if (($t = $name) =~ s/\b(APL\s+FUNCTIONAL\s+SYMBOL)\s+\b(.*?)\b\s*\b(QUAD(?!$)|UNDERBAR|TILDE|DIAERESIS|VANE|STILE|JOT|OVERBAR|BAR)\b/$2/) {
#warn "APL: $k ($name) --> <$t>; <$1> <$3>";
          push @{$candidates{$k}}, [$t, "calculated-$1-$3"];
          my %s = qw(UP DOWN DOWN UP);				# mispring in the official name???
          $candidates{$k}[-1][0] =~ s/\b(UP|DOWN)(?=\s+TACK\b)/$s{$1}/;
        }
        if (($t = $name) =~ s/\b(LETTER\s+SMALL\s+CAPITAL)/CAPITAL LETTER/) {
          push @{$candidates{$k}}, [$t, "smallcaps"];
        }
        if (($t = $name) =~ s/\b(LETTER\s+)E([SZN])[HG]$/$1$2/			# esh/eng/ezh
                     # next two not triggered since this is actually decomposed:
                 or ($t = $name) =~ s/(?<=\bLETTER\sV\s)WITH\s+RIGHT\s+HOOK$// 
                 or ($t = $name) =~ s/\bDOTLESS\s+J\s+WITH\s+STROKE$/J/ 
                 or $name eq 'LATIN SMALL LETTER SCHWA' and $t = 'DIGIT ZERO') {
          push @{$candidates{$k}}, [$t, "phonetized"] if 0;
        }
      }
      ($k, $name, $_c) = ($K, $Name, $C); 
      $G{$k} = $name if $name =~ /^GREEK\s/;	# Indexed by hex
      $kk = $k;
      next;
    }
    if ($s =~ /^\@\@\s+([\da-f]+)\b/i) {
      die unless $s =~ /^\@\@\s+([\da-f]+)\s.*\s([\da-f]+)\s*$/i;
      $BL = $1;
    }
    my $a;					# compatibility_p, composed, decomposition string
    $a = [0, split /\s+/, "$1"] if $s =~ /^\s+:\s*([0-9A-F]+(?:\s+[0-9A-F]+)*)/; 
    $a = [1, split /\s+/, "$2"], ($1 and push @$a, $1) 
      if $s =~ /^\s+#\s*(?:(<.*?>)\s+)?([0-9A-F]+(?:\s+[0-9A-F]+)*)/;	# Put <compat> at end
    next unless $a; 
    if ($a->[-1] eq '<font>') {{		# Clarify
      my ($math, $type) = ('', '');
#      warn("Unexpected name with <font>: <$name>"), unless $name =~ s/^MATHEMATICAL\s+// and $math = "math-";
      warn("Unexpected name with <font>: $k <$name>"), last 	# In BMP, MATHEMATICAL is omited
        unless $name =~ /^(?:MATHEMATICAL\s+)?((?:(?:BLACK-LETTER|FRAKTUR|BOLD|ITALIC|SANS-SERIF|DOUBLE-STRUCK|MONOSPACE|SCRIPT)\b\s*?)+)(?=\s+(?:SMALL|CAPITAL|DIGIT|NABLA|PARTIAL|N-ARY|\w+\s+SYMBOL)\b)/
            or $name =~ /^HEBREW\s+LETTER\s+(WIDE|ALTERNATIVE)\b/
            or $name =~ /^(ARABIC\s+MATHEMATICAL(?:\s+(?:INITIAL|DOTLESS|STRETCHED|LOOPED|TAILED|DOUBLE-STRUCK))?)\b/
            or $name =~ /^(PLANCK|INFORMATION)/;	# information source
      $type = $1 if $1;
      $type =~ s/BLACK-LETTER/FRAKTUR/;		# http://en.wikipedia.org/wiki/Black-letter#Unicode
      $type =~ s/INFORMATION/Letterlike/;	# http://en.wikipedia.org/wiki/Letterlike_Symbols_%28Unicode_block%29
      $type = '=' . join '-', map lc($_), split /\s+/, $type if $type;
      $a->[-1] = "<font$type>";
    }}
    push @$a, '<pseudo-upgrade>' unless @$a > 2;
    push @{$basic{$k}}, $a;			# <fraction> 1 2044					--\
    undef $kk unless $a->[-1] eq '<pseudo-upgrade>' 				# Disable guesswork processing
      or @$a == 3 and (chr hex $a->[-2]) =~ /\W|\p{Lm}/ and $a->[-1] !~ /^</ and (chr hex $a->[-1]) =~ /\w/;
    # print "@$a";
  }
#  $candidates{'014A'} = ['LATIN CAPITAL LETTER N', 'faked-HOOK'];		# Pretend on ENG...
#  $candidates{'014B'} = ['LATIN SMALL LETTER N',   'faked-HOOK'];		# Pretend on ENG...
  	# XXXX Better have this together with pseudo-upgrade???
  push @{$candidates{'00b5'}}, ['GREEK SMALL LETTER MU',  'faked-calculated-SYMBOL'];	# Pretend on MICRO SIGN...
#  $candidates{'00b5'} = ['GREEK SMALL LETTER MU',  'calculated-SYMBOL'];	# Pretend on MICRO SIGN...
  for my $k (keys %basic) {			# hex
    for my $exp (@{$basic{$k}}) {
      my $base = $exp->[1];			# hex
      my $name = $NM{$self->charhex2key($base)};
      next if not $name and ($k =~ /^[12]?F[89A]..$/ or hex $base >= 0x4E00 and hex $base <= 0x9FCC);		# ideographs; there is also 3400 region...
      warn "Basic: `$k' --> `@$exp', base=`$base' --> `",$self->charhex2key($base),"'" unless $name;
      if ((my $NN = $name) =~ s/\s+OPERATOR$//) {
#warn "operator: `$k' --> <$NN>, `@$exp', base=`$base' --> `",$self->charhex2key($base),"'";
        push @{$candidates{$k}}, [$_, @$exp[2..$#$exp]] for $NN, @{ $operators{$NN} || []};
      }
    }
  }
  for my $how (keys %uni_manual) {	# Some stuff is easier to describe in terms of char, not names
    my $map = $uni_manual{$how};
    die "manual translation map for $how has an odd number of entries" if @$map % 2;
#    for my $from (keys %$map) {
    while (@$map) {
      my $to = pop @$map;		# Give precedence to later entries
      my $from = pop @$map;
      for my $shift (0,1) {
        if ($shift) {
          my ($F, $T) = (uc $from, uc $to);
          next unless $F ne $from and $T ne $to;
          ($from, $to) = ($F, $T);
        }
        push @{$candidates{uc $self->key2hex($to)}}, [$NM{$from}, "manual-$how"];
      }
    }
  }
  for my $g (keys %G) {
    (my $l = my $name = $G{$g}) =~ s/^GREEK\b/LATIN/ or die "Panic";
    next unless my $L = $N{$l};				# is HEX
#warn "latinize: $L\t$l";
    push @{$candidates{$L}}, [$name,  'faked-latinize'];
    next unless my ($lat, $first, $rest, $add) = ($l =~ /^(LATIN\s+(?:SMALL|CAPITAL)\s+LETTER\s+(\w))(\w+)(?:\s+(\S.*))?$/);
    $lat =~ s/P$/F/, $first = 'F' if "$first$rest" eq 'PHI';
    die unless my $LL = $N{$lat};
    $add = (defined $add ? "-$add" : '');		# None of 6.1; only iIuUaAgGdf present of 6.1
    push @{$candidates{$L}}, [$lat,  "faked-greekize$add"];
#warn "latinize++: $L\t$l;\t`$add'\t$lat";
  }
  my %iu_TR = qw(INTERSECTION CAP UNION CUP);
  my %_TR   = map { (my $in = $_) =~ s/_/ /g; $in } qw(SMALL_VEE		LOGICAL_OR   
  						       UNION_OPERATOR_WITH_DOT	MULTISET_MULTIPLICATION
  						       UNION_OPERATOR_WITH_PLUS	MULTISET_UNION);
  my $_TR_rx = map qr/$_/, join '|', keys %_TR;
  for my $c (keys %candidates) {		# Done after all the names are known
   my ($CAND, $app, $t, $base, $b) = ($candidates{$c}, '');
   for my $Cand (@$CAND) {	# (all keys in hex)
#warn "candidates: $c <$Cand->[0]>, <@$Cand[1..$#$Cand]>";
    # An experiment shows that the FORMS are properly marked as non-canonical decompositions; so they are not needed here
    (my $with = my $raw = $Cand->[1]) =~ s/\s+(SIGN|SYMBOL|(?:FINAL|ISOLATED|INITIAL|MEDIAL)\s+FORM)$//
      and $app = " $1";
    for my $Mod ( (map ['', $_], $app, '', ' SIGN', ' SYMBOL', ' OF', ' AS MEMBER', ' TO'),	# `SUBSET OF', `CONTAINS AS MEMBER', `PARALLEL TO'
		  (map [$_, ''], 'WHITE ', 'WHITE UP-POINTING ', 'N-ARY '), ['WHITE ', ' SUIT'] ) {
      my ($prepend, $append) = @$Mod;
      next if $raw =~ /-SYMBOL$/ and 0 <= index($append, "SYMBOL");	# <calculated-SYMBOL>
      warn "raw=`$raw', prepend=<$prepend>, append=<$append>, base=$Cand->[0]\n" if debug_GUESS_MASSAGE;
      $t++;
      $b = "$prepend$Cand->[0]$append";
      $b =~ s/\bTWO-HEADED\b/TWO HEADED/ unless $N{$b};
      $b =~ s/\bTIMES\b/MULTIPLICATION SIGN/ unless $N{$b};
      $b =~ s/(?:(?<=\bLEFT)|(?<=RIGHT))(?=\s+ARROW\b)/WARDS/ unless $N{$b};
      $b =~ s/\bLINE\s+INTEGRATION\b/CONTOUR INTEGRAL/ unless $N{$b};
      $b =~ s/\bINTEGRAL\s+AVERAGE\b/INTEGRAL/ unless $N{$b};
      $b =~ s/\s+(?:SHAPE|OPERATOR|NEGATED)$// unless $N{$b};
      $b =~ s/\bCIRCLED\s+MULTIPLICATION\s+SIGN\b/CIRCLED TIMES/ unless $N{$b};
      $b =~ s/^(CAPITAL|SMALL)\b/LATIN $1 LETTER/ unless $N{$b};			# TURNED SMALL F
      $b =~ s/\b(CAPITAL\s+LETTER)\s+SMALL\b/$1/ unless $N{$b};		# Q WITH HOOK TAIL
      $b =~ s/\bEPIGRAPHIC\b/CAPITAL/ unless $N{$b};			# XXXX is it actually capital?
      $b =~ s/^LATIN\s+LETTER\s+SMALL\s+CAPITAL\b/LATIN CAPITAL LETTER/ # and warn "smallcapital -> <$b>" 
        if not $N{$b} or $with=~ /smallcaps/;			# XXXX is it actually capital?
      $b =~ s/^GREEK\s+CAPITAL\b(?!=\s+LETTER)/GREEK CAPITAL LETTER/ unless $N{$b};
      $b =~ s/^GREEK\b(?!\s+(?:CAPITAL|SMALL)\s+LETTER)/GREEK SMALL LETTER/ unless $N{$b};
      $b =~ s/^CYRILLIC\b(?!\s+(?:CAPITAL|SMALL)\s+LETTER)(?=\s+LETTER\b)/CYRILLIC SMALL/ unless $N{$b};
      $b =~ s/\bEQUAL\s+TO\s+SIGN\b/EQUALS SIGN/ unless $N{$b};
      $b =~ s/\bMINUS\b/HYPHEN-MINUS/ unless $N{$b};
      $b =~ s/\b(SQUARE\s+)(INTERSECTION|UNION)(?:\s+OPERATOR)?\b/$1$iu_TR{$2}/ unless $N{$b};
      $b =~ s/(?<=WARDS)$/ ARROW/ unless $N{$b};	# APL VANE
      $b =~ s/\b($_TR_rx)\b/$_TR{$1}/ unless $N{$b};
#      $b =~ s/\bDOT\b/FULL STOP/ unless $N{$b};
#      $b =~ s/^MICRO$/GREEK SMALL LETTER MU/ unless $N{$b};

      warn "    b =`$b', prepend=<$prepend>, append=<$append>, base=$Cand->[0]\n" if debug_GUESS_MASSAGE;
      if (defined ($base = $N{$b})) {
        undef $base, next if $base eq $c;
        $with = $raw if $t;
	warn "<$Cand->[0]> WITH <$Cand->[1]> resolved via SIGN/SYMBOL/.* FORM: strip=<$app> add=<$prepend/$append>\n"
	  if debug_GUESS_MASSAGE and ($append or $app or $prepend);
        last 
      }
    }
    if (defined $base) {
      $base = [$base];
    } elsif ($raw =~ /\bOPERATOR$/) {
      $base = [map $N{$_}, @{ $operators{$Cand->[0]} }] if exists $operators{$Cand->[0]};
    }
    (warnUNRES and warn("Unresolved: <$Cand->[0]> WITH <$Cand->[1]>")), next unless defined $base;
    my @modifiers = split /\s+AND\s+/, $with;
    @modifiers = map { s/\s+/-/g; /^[\da-f]{4,}$/i ? $_ : "<pseudo-\L$_>" } @modifiers;
#warn " $c --> <@$base>; <@modifiers>...\t$b <- $NM{chr hex $c}" ;
    unshift @{$basic{$c}}, [1, $_, @modifiers] for @$base;
    if ($b =~ s/\s+(OPERATOR|SIGN)$//) {	# ASTERISK	(note that RING is a valid name, but has no relation to RING OPERATOR
      unshift @{$basic{$c}}, [1, $base, @modifiers] if defined ($base = $N{$b});	# ASTERISK
#$base = '[undef]' unless defined $base;
#warn("operator via <$b>, <$c> => `$base'");
      (debug_OPERATOR and warn "operator: `$c' ==> `$_', <@modifiers> via <$b>\n"),
        unshift @{$basic{$c}}, [1, $_,    @modifiers] for map $N{$_}, @{ $operators{$b} || [] };	# ASTERISK
    }
#        push @{$candidates{$k}}, [$_, @$exp[2..$#$exp]] for $NN, @{ $operators{$NN} || []};
#    $basic{$c} = [ [1, $base, @modifiers ] ]
   }
  }
  $self->decompose_r(\%basic, $_, \%cached_full) for keys %basic;	# Now %cached_full is fully expanded - has trivial expansions too
  for my $c (sort {fromHEX $a <=> fromHEX $b or $a cmp $b} keys %cached_full) {		# order of chars in Unicode matters (all keys in hex)
    my %seen_compose;
    for my $exp (@{ $cached_full{$c} }) {
      my @exp = @$exp;			# deep copy
      die "Expansion too short: <@exp>" if @exp < 2;	
      next if @exp < 3;			# Skip trivial decompositions
      my $compat = shift @exp;
      my @PRE = @exp;
      my $base = shift @exp;
      @exp = ($base, sort {fromHEX $a <=> fromHEX $b or $a cmp $b} @exp);	# Any order will do; do not care about Unicode rules
#warn "Malformed: [@exp]" if "@exp" =~ /^</ or $compat !~ /^[01]$/;
      next if $seen_compose{"$compat; @exp"}++;		# E.g., WHITE may be added in several ways...
      push @{$ordered{$c}}, [$compat, @exp > 3 ? @exp : @PRE];	# with 2 modifiers order does not matter for the algo below, but we catch U"¯ vs U¯".
      warn qq(Duplicate: $c <== [ @exp ] ==> <@{$compose{"@exp"}[0]}> (prefered)\n\t<), chr hex $c, 
        qq(>\t$NM{chr hex $c}\n\t<), chr hex $compose{"@exp"}[0][1], qq(>\t$NM{chr hex $compose{"@exp"}[0][1]})
          if $compose{"@exp"} and "@exp" !~ /<(font|pseudo-upgrade)>/ and $c ne $compose{"@exp"}[0][1] and not $known_dups{$c};
#warn "Compose rule: `@exp' ==> $compat, `$c'";
      push @{$compose{"@exp"}}, [$compat, $c];
    }
  }					# compose mapping done
  for my $c (sort {fromHEX $a <=> fromHEX $b or $a cmp $b} keys %ordered) {	# all nontrivial!  Order of chars in Unicode matters...
    my(%seen_compose, %seen_contract) = ();
    for my $v (@{ $ordered{$c} }) {		## When (FOO and FOO OPERATOR) + tilde are both remapped to X: X+operator == X
      my %seen;
      for my $off (reverse(2..$#$v)) {
#        next if $seen{$v->[$off]}++;		# chain of compat, or 2A76	->	?2A75 003D	< = = = >
        my @r = @$v;				# deep copy
        splice @r, $off, 1;
        my $compat = shift @r;
#warn "comp: $compat, $c; $off [@$v] -> $v->[$off] + [@r]";
	next if $seen_compose{"$compat; $v->[$off]; @r"}++;
#      next unless my $contracted = $compose{"@r"};	# This omits trivial compositions
        my $contracted = [@{$compose{"@r"} || []}];	# Deep copy
# warn "Panic $c" if @$contracted and @r == 1;
        push @$contracted, [0, @r] if @r == 1;		# Not in %compose
        # QUAD-INT: may be INT INT INT INT, may be INT amp INT INT etc; may lead to same compositions...
#warn "contraction: $_->[0]; $compat; $c; $v->[$off]; $_->[1]" for @$contracted;
        @$contracted = grep {$_->[1] ne $c and not $seen_contract{"$_->[0]; $compat; $v->[$off]; $_->[1]"}++} @$contracted;
#warn "  contraction: $_->[0]; $compat; $c; $v->[$off]; $_->[1]" for @$contracted;
        for my $contr (@$contracted) {		# May be empty: Eg, fractions decompose into 2 3 <fraction> and cannot be composed in 2 steps
          my $calculated = $contr->[0] || $off != $#$v;
          push @{ $into2{$self->charhex2key($c)} }, [(($compat | $contr->[0])<<1)|$calculated, $self->charhex2key($contr->[1]), $self->charhex2key($v->[$off])];	# each: compat, char, combine
          push @{ $comp2{$v->[$off]}{$contr->[1]} }, [ (($compat | $contr->[0])<<1)|$calculated, $c];	# each: compat, char
        }
      }
    }
  }					# (de)compose-into-2 mapping done
  for my $h2 (values %comp2) {	# Massage into the natural order - prefer canonical (de)compositions
    for my $h (values %$h2) {		# RValues!!!	[compat, charHEX] each
#      my @a = sort { "@$a" cmp "@$b" } @$h;
      my @a = sort { $a->[0] <=> $b->[0] or $self->charhex2key($a->[1]) cmp $self->charhex2key($b->[1]) } @$h;
      $h = \@a;
    }
  }
  \%into2, \%comp2, \%NM, \%BL, \%NS, $version
}

sub print_decompositions($;$) {
  my $self = shift;
  my $dec = @_ ? shift : do {  my $f = $self->get_NamesList;
	  $self->load_compositions($f) if defined $f;
	  $self->{Decompositions}} ;
  for my $c (sort keys %$dec) {
    my $arr = $dec->{$c};
    my @out = map +($_->[0] ? '? ' : '= ') . "@$_[1,2]", @$arr;
    print "$c\t->\t", join(",\t", @out), "\n";
  }
}

sub print_compositions($$) {
  goto &print_compositions_ch if @_ == 1;
  my ($self, $comp) = (shift, shift);
  for my $c (sort {fromHEX $a <=> fromHEX $b or $a cmp $b} keys %$comp) {	# composing char
    print "$c\n"; 
    for my $b (sort {fromHEX $a <=> fromHEX $b or $a cmp $b} keys %{$comp->{$c}}) {	# base char
      my $arr = $comp->{$c}{$b};
      my @out = map +($_->[0] ? '?' : '=') . $_->[1], @$arr;
      print "\t$b\t->\t", join(",\t\t", @out), "\n";
    }
  }
}

sub print_compositions_ch($$) {
  my $self = shift;
  my $comp = @_ ? shift : do {   my $f = $self->get_NamesList;
	  $self->load_compositions($f) if defined $f;
	  $self->{Compositions}} ;
  for my $c (sort keys %$comp) {	# composing char
    print "$c\n"; 
    for my $b (sort keys %{$comp->{$c}}) {	# base char
      my $arr = $comp->{$c}{$b};
      my @out = map +($_->[0] ? '? ' : '= ') . $_->[1], @$arr;
      print "\t$b\t->\t", join(",\t\t", @out), "\n";
    }
  }
}

sub load_compositions($$) {
  my ($self, $comp, @comb) = (shift, shift);
  return $self if $self->{Compositions};
  my %comp = %{ $self->{'[Substitutions]'} || {} };
  open my $f, '<', $comp or die "Can't open $comp for read";
  ($self->{Decompositions}, $comp, $self->{UNames}, $self->{UBlock}, $self->{exComb}, $self->{uniVersion}) = $self->parse_NameList($f);
  close $f or die "Can't close $comp for read";
#warn "(De)Compositions and UNames loaded";
  # Having hex as index is tricky: is it 4-digits or more?  Is it in uppercase?
  for my $c (sort {fromHEX $a <=> fromHEX $b or $a cmp $b} keys %$comp) {	# composing char
    for my $b (sort {fromHEX $a <=> fromHEX $b or $a cmp $b} keys %{$comp->{$c}}) {	# base char
      my $arr = $comp->{$c}{$b};
      my @out = map [$self->charhex2key($_->[0]), $self->charhex2key($_->[1])], @$arr;
      $comp{$self->charhex2key($c)}{$self->charhex2key($b)} = \@out;
    }
  }
  $self->{Compositions} = \%comp;
  my $comb = join '', keys %{$self->{exComb}};			# should not have metachars here...
  $rxCombining = qr/\p{nonSpacingMark}|[$comb]/ if $comb;
  $self
}

sub load_uniage($$) {
  my ($self, $fn) = (shift, shift);
  # get_AgeList
  open my $f, '<', $fn or die "Can't open `$fn' for read: $!";
  local $/;
  my $s = <$f>;
  close $f or die "Can't close `$fn' for read: $!";
  $self->{Age} = $self->parse_derivedAge($s);
  $self
}

sub load_unidata($$) {
  my ($self, $comp) = (shift, shift);
  $self->load_compositions($comp);
  return $self unless @_;
  $self->load_uniage(shift);
}

my(%charinfo, %UName_v);			# Unicode::UCD::charinfo extremely slow
sub UName($$$;$) {
  my ($self, $c, $verbose, $vbell, $app, $n, $i, $A) = (shift, shift, shift, shift, '');
  $c = $self->charhex2key($c);
  return $UName_v{$c} if $verbose and exists $UName_v{$c} and ($vbell or 0x266a != ord $c);
  if (not exists $self->{UNames} or $verbose) {
    require Unicode::UCD;
    $i = ($charinfo{$c} ||= Unicode::UCD::charinfo(ord $c) || {});
    $A = $self->{Age}{$c};
    $n = $self->{UNames}{$c} || ($i->{name}) || "<$c>";
    if ($verbose and (%$i or $A)) {
      my $scr = $i->{script};
      my $bl = $i->{block};
      $scr = join '; ', grep defined, $scr, $bl, $A;
      $scr = "Com/MiscSym1.1" if $vbell and 0x266a == ord $c;	# EIGHT NOTE: we use as "visual bell"
      $app = " [$scr]" if length $scr;
    }
    return($UName_v{$c} = "$n$app") if $verbose and ($vbell or 0x266a != ord $c);
    return "$n$app"
  }
  $self->{UNames}{$c} || "[$c]"
}

sub parse_derivedAge ($$) {
  my ($self, $s, %C) = (shift, shift);
  for my $l (split /\n/, $s) {
    next if $l =~ /^\s*(#|$)/;
    die "Unexpected line in DerivedAge: `$l'" 
      unless $l =~ /^([0-9a-f]{4,})(?:\.\.([0-9a-f]{4,}))?\s*;\s*(\d\.\d)\b/i;
    $C{chr $_} = $3 for (hex $1) .. hex($2 || $1);
  }
  \%C;
}

# use Dumpvalue;
# my $first_time_dump;
sub get_compositions ($$$$;$) {		# Now only the undo-brach is used...
  my ($self, $m, $C, $undo, $unAltGr, @out) = (shift, shift, shift, shift, shift);
#  return unless defined $C and defined (my $r = $self->{Compositions}{$m}{$C});
# Dumpvalue->new()->dumpValue($self->{Compositions}) unless $first_time_dump++;
  return undef unless defined $C;
  $C = $C->[0] if 'ARRAY' eq ref $C;			# Treat prefix keys as usual keys
warn "doing <$C> <@$m>: undo=$undo C=", $self->key2hex($C),  ", maps=", join ' ', map $self->key2hex($_), @$m if warnDO_COMPOSE; # if $m eq 'A';
  if ($undo) {
    return undef unless my $dec = $self->{Decompositions}{$C};
    # order in @$m matters; so does one in Decompositions - but less so
    # Hence the external loop should be in @$m
    for my $M (@$m) {
      push @out, $_ for grep $M eq $_->[2], @$dec;
      if (@out) {	# We took the first guy from $m which allows such decomposition
        warn "Decomposing <$C> <$M>: multiple answers: <", (join '> <', map "@$_", @out), ">" unless @out == 1;
warn "done undo <$C> <@$m>: -> ", $self->array2string(\@out) if warnDO_COMPOSE; # if $m eq 'A';
        return $out[0][1]
      }
    }
    return undef;
  }
  if ($unAltGr) {{
    last unless $unAltGr = $unAltGr->{$C};
    my(@seen, %seen);
    for my $comp ( @$m ) {
      my $a1 = $self->{Compositions}{$comp}{$unAltGr};;
      push @seen, $a1 if $a1 and not $seen{$a1->[0][1]}++;
#warn "Second binding `$a1->[0][1]' for `$unAltGr' (on `$C') - after $seen[0][0][1]" if @seen == 2;
      next unless defined (my $a2 = $self->{Compositions}{$comp}{$C}) or @seen == 2;
#warn "  --> AltGr-binding `$a2->[0][1]' (on `$C')" if @seen == 2 and defined $a2;
      warn "Conflict between the second binding `$a1->[0][1]' for `$unAltGr' and AltGr-binding `$a2->[0][1]' (on `$C')" 
        if $a2 and $a1 and @seen == 2 and $a1->[0][1] ne $a2->[0][1];
      return ((@seen == 2 and $a1) or $a2)->[0][1];
    }
  }}
  return undef unless my ($r) = grep defined, map $self->compound_composition($_,$C), @$m;
  warn "Composing <$C> <@$m>: multiple answers: <", (join '> <', map "@$_", @$r), ">" unless @$r == 1 or $C eq ' ';
# warn("done   <$C> <$m>: <$r->[0][1]>"); # if $m eq 'A';
  $r->[0][1]
}

sub compound_composition ($$$) {
  my ($self, $M, $C, $doc, $doc1, @res, %seen) = (shift, shift, shift, '', '');
  return undef unless defined $C;
  $doc1 = $C->[3] if 'ARRAY' eq ref $C and defined $C->[3];	# may be used via <reveal-substkeys, when $M is empty
  $doc = "$doc1 ⇒ " if length $doc1;
  $C = $C->[0] if 'ARRAY' eq ref $C;
warn "composing `$M' with base <$C>" if warnDO_COMPOSE;
  $C = [[0, $C, $doc1]];			# Emulate element of return of Compositions ("one translation, explicit")
  for my $m (reverse split /\+|-(?=-)/, $M) {
    my @res;
    if ($m =~ /^(?:-|(?:[ul]c(?:first)?|dectrl)$)/) {
      if ($m =~ s/^-//) {
        @res = map $self->get_compositions([$m], $_->[1], 'undo'), @$C;
        @res = map [[0,$_]], grep defined, @res;
      } elsif ($m eq 'lc') {
        @res = map {($_->[1] eq lc($_->[1]) or 1 != length lc($_->[1])) ? () : [[0, lc $_->[1]]]} @$C
      } elsif ($m eq 'uc') {
        @res = map {($_->[1] eq uc($_->[1]) or 1 != length uc($_->[1])) ? () : [[0, uc $_->[1]]]} @$C
      } elsif ($m eq 'ucfirst') {
        @res = map {($_->[1] eq ucfirst($_->[1]) or 1 != length ucfirst($_->[1])) ? () : [[0, ucfirst $_->[1]]]} @$C
      } elsif ($m eq 'dectrl') {
        @res = map {(0x20 <= ord($_->[1])) ? () : [[0, chr(0x40 + ord $_->[1])]]} @$C
      } else {
        die "Panic"
      }
    } else {
#warn "compose `$m' with bases <", join('> <', map $_->[1], @$C), '>';
      @res = map $self->{Compositions}{$m}{$_->[1]}, @$C;
    }
    @res = map @$_, grep defined, @res;
    return undef unless @res;
    $C = [map [$_->[0], $_->[1], "$doc$M"], @res];
  }
  $C
}

sub compound_composition_many ($$$$) {		# As above, but takes an array of [char, docs]
  my ($self, $M, $CC, $ini, @res) = (shift, shift, shift, shift);
  return undef unless $CC;
  my $doc = (($ini and ref $ini and defined $ini->[3]) ? "$ini->[3] ⇒ Subst{" : '');
  my $doc1 = $doc && '}';
  for my $C (@$CC) {
#    $C = $C->[0] if 'ARRAY' eq ref $C;
    next unless defined $C;
    my $in = $self->compound_composition($M, [$C->[0], undef, undef, "$doc$C->[1]$doc1"]);
    push @res, @$in if defined $in;
  }
  return undef unless @res;
  \@res
}

# Design goals: we assign several diacritics to a prefix key (possibly with 
# AltGr on the "Base key" and/or other "multiplexers" in between).  We want: 
#   *) a lc/uc paired result to sit on Shift-paired keypresses; 
#   *) avoid duplication among multiplexers (a secondary goal); 
#   *) allow some diacritics in the list to be prefered ("groups" below);
#   *) when there is a choice, prefer non-bizzare (read: with smaller Unicode 
#      "Age" version) binding to be non-multiplexed.  
# We allow something which was not on AltGr to acquire AltGr when it gets a 
# diacritic.

# It MAY happen that an earlier binding has empty slots, 
# but a later binding exists (to preserve lc/uc pairing, and shift-state)

### XXXX Unclear: how to catenate something in front of such a map...
# we do $composition->[0][1], which means we ignore additional compositions!  And we ignore HOW, instead of putting it into penalty

sub sort_compositions ($$$$$;$) {
  my ($self, $m, $C, $Sub, $dupsOK, $w32OK, @res, %seen, %Penalize, %penalize, %OK, %ok, @C) = (shift, shift, shift, shift, shift, shift);
warn "compounding ", $self->array2string($C) if warnSORTCOMPOSE;
  for my $c (@$C) {
    push @C, [map {($_ and 'ARRAY' eq ref $_) ? $_->[0] : $_} @$c]
  }
  my $char = $C[0][0];
  for my $MM (@$m) {			# |-groups
    my(%byPenalty, @byLayers);
    for my $M (@$MM) {			# diacritic in a group; may flatten each layer, but do not flatten separately each shift state: need to pair uc/lc
      if ((my $P = $M) =~ s/^(!)?\\(\\)?//) {
        my($neg, $strong) = ($1, $2);
# warn "Penalize: <$P>";	# Actually, it is not enough to penalize; one should better put it in a different group...
	if ($P =~ s/\[(.*)\]$//) {
	  #$P = $self->stringHEX2string($P);
	  my $match;
	  $char eq $_ and $match++ for split //, $self->stringHEX2string("$1");
	  next unless $match;
	}  
	#$P = $self->stringHEX2string($P);
	if ($neg) {
          $strong ? $OK{$_}++ : $ok{$_}++ for split //, $P;
        } else {
          $strong ? $Penalize{$_}++ : $penalize{$_}++ for split //, $P;
        }
        next
      }
      for my $L (0..$#C) {		# Layer number; indexes a shift-pair
#        my @res2 = map {defined($_) ? $self->{Compositions}{$M}{$_} : undef } @{ $C[$L] };
        my @Res2 = map $self->compound_composition($M, $_), @{ $C->[$L] };	# elt: [$synth, $char]
        my @working_with = grep defined, @{ $C[$L] };				# ., KP_Decimal gives [. undef]
warn "compound  `$M' of [@working_with] -> ", $self->array2string(\@Res2) if warnSORTCOMPOSE;
        (my $MMM = $M) =~ s/(^|\+)<reveal-(?:green|subst)key>$//; # Hack: the rule <reveal-substkey> always fails if present, empty always succeeds
        my @Res3 = map $self->compound_composition_many($MMM, (defined() ? $Sub->{($_ and ref) ? $_->[0] : $_} : $_), $_), 
        	   @{ $C->[$L] };
warn "compound+ `$M' of [@working_with] -> ", $self->array2string(\@Res3) if warnSORTCOMPOSE;
        for my $shift (0..$#Res3) {
          if (defined $Res2[$shift]) {
            push @{ $Res2[$shift]}, @{$Res3[$shift]} if $Res3[$shift]
          } else {
            $Res2[$shift] = $Res3[$shift]
          }
        }
#        defined $Res2[$_] ? ($Res3[$_] and push @{$Res2[$_]}, @{$Res2[$_]}) : ($Res2[$_] = $Res3[$_]) for 0..$#Res3;
        @Res2 = $self->DEEP_COPY(@Res2);
        my ($ok, @ini_compat);
        do {{							# Run over found translations
	  my @res2   = map {defined() ? $_->[0] : undef} @Res2;		# process next unprocessed translations
	  defined and (shift(@$_), (@$_ or undef $_)) for @Res2;	# remove what is being processed
	  $ok = grep $_, @res2;
          @res2    = map {(not defined() or (!$dupsOK and $seen{$_->[1]}++)) ? undef : $_} @res2;	# remove duplicates
	  my @compat = map {defined() ? $_->[0] : undef} @res2;
	  my @_from_ = map {defined() ? $_->[2] : undef} @res2;
	  defined and s/((?<![^+])|(?<=⇒ ))Cached\d+=//g for @_from_;
	  @res2      = map {defined() ? $_->[1] : undef} @res2;
          @res2      = map {0x10000 > ord($_ || 0) ? $_ : undef} @res2 unless $w32OK;	# remove those needing surrogates
	  defined $ini_compat[$_] or $ini_compat[$_] = $compat[$_] for 0..$#compat;
	  my @extra_penalty = map {!!$compat[$_] and $ini_compat[$_] < $compat[$_]} 0..$#compat;
          next unless my $cnt = grep defined, @res2;
          my($penalty, $p) = [('zzz') x @res2];	# above any "5.1", "undef" ("unassigned"???)
          # Take into account the "compatibility", but give it lower precedence than the layer:
          # for no-compatibility: do not store the level;
          defined $res2[$_] and $penalty->[$_] gt ( $p = ($OK{$res2[$_]} ? '+' : '-') . ($self->{Age}{$res2[$_]} || 'undef') .
          			($ok{$res2[$_]} ? '+' : '-') . "#$extra_penalty[$_]#" . ($self->{UBlock}{$res2[$_]} || '') )
            and $penalty->[$_] = $p for 0..$#res2;
          my $have1 = not (defined $res2[0] and defined $res2[1]);		# Prefer those with both entries
          # Break a non-lc/uc paired translations into separate groups
          my $double_occupancy = ($cnt == 2 and $res2[0] ne $res2[1] and lc $res2[0] eq lc $res2[1]);	# Case fold
warn "   seeing random-double, penalties <$penalty->[0]>, <$penalty->[1]>\n" if warnSORTCOMPOSE;
          next if $double_occupancy and grep {defined and $Penalize{$_}} @res2;
          if ($double_occupancy and grep {defined and $penalize{$_}} @res2) {
            defined $res2[$_] and $penalty->[$_] = "zzz$penalty->[$_]" for 0..$#res2;
          } else {
            defined and $Penalize{$_} and $cnt--, $have1=1, undef $_ for @res2;
            defined $res2[$_] and $penalize{$res2[$_]} and $penalty->[$_] = "zzz$penalty->[$_]" for 0..$#res2;
          }
          next unless $cnt;
          if (not $double_occupancy and $cnt == 2 and (1 or $penalty->[0] ne $penalty->[1])) {	# Break (penalty here is not a good idea???)
warn "   breaking random-double, penalties <$penalty->[0]>, <$penalty->[1]>\n" if warnSORTCOMPOSE;
            push @{ $byPenalty{"$penalty->[0]1"}[0][$L] }, [       [$res2[0],undef,undef,$_from_[0]]];
            push @{ $byPenalty{"$penalty->[1]1"}[0][$L] }, [undef, [$res2[1],undef,undef,$_from_[1]]];
            next;		# Now: $double_occupancy or $cnt == 1 or $penalty->[0] eq $penalty->[1]
          }
          $p = (defined $res2[0] ? $penalty->[0] : 'zzz');	# may have been undef()ed due to Penalty...
          $p = $penalty->[1] if @$penalty > 1 and defined $res2[1] and $p gt $penalty->[1];
          push @{ $byPenalty{"$p$have1"}[$double_occupancy][$L] }, 
#            [map {defined $res2[$_] ? $res2[$_] : undef} 0..$#res2];
            [map {defined $res2[$_] ? [$res2[$_],undef,undef,$_from_[$_]] : undef} 0..$#res2];
        }} while $ok;
warn " --> combined of [@working_with] -> ", $self->array2string([\@res, %byPenalty]) if warnSORTCOMPOSE;
      }
    }		# sorted bindings, per Layer
    push @res, [ @byPenalty{ sort keys %byPenalty } ];	# each elt is an array ref indexed by layer number; elt of this is [lc uc]
  }
#warn 'Compositions: ', $self->array2string(\@res);
  \@res
}	# index as $res->[group][penalty_N][double_occ][layer][NN][shift]

sub equalize_lengths ($$@) {
  my ($self, $extra, $l) = (shift, shift || 0, 0);
  $l <= length and  $l = length for @_;
  $l += $extra;
  $l >  length and $_ .= ' ' x ($l - length) for @_;
}

sub report_sorted_l ($$$;$$) {	# 6 levels: |-group, priority, double-occupancy, layer, count, shift
  my ($self, $k, $sorted, $bold, $bold1, $top2, %bold) = (shift, shift, shift, shift, shift);
  $k = $k->[0] if 'ARRAY' eq ref($k || 0);
  $k = '<undef>' unless defined $k;
  $k = "<$k>" if defined $k and $k !~ /[^┃┋║│┆\s]/;
  my @L = ($k, '');			# Up to 100 layers - an overkill, of course???  One extra level to store separators...
  $bold{$_} = '┋' for @{$bold1 || []};
  $bold{$_} = '┃' for @{$bold || []};
  for my $group (0..$#$sorted) { # Top level
    $self->equalize_lengths(0, @L);
    $_ .= ' ' . ($bold{$group} || '║') for @L;
    my $prio2;    
    for my $prio (@{ $sorted->[$group] }) {
      if ($prio2++) {
        $self->equalize_lengths(0, @L);
        $_ .= ' │' for @L;
      }
      my $double2;
      for my $double (reverse @$prio) {
        if ($double2++) {
          $self->equalize_lengths(0, @L);
          $_ .= ' ┆' for @L;
        }
        for my $layer (0..$#$double) {
          for my $set (@{$double->[$layer]}) {
            for my $shift (0,1) {
              next unless defined (my $k = $set->[$shift]);
              $k = $k->[0] if ref $k;
              $k = " $k" if $k =~ /$rxCombining/;
              if (2*$layer + $shift >= $#L) {		# Keep last layer pristine for correct separators...
                my $add = 2*$layer + $shift - $#L + 1;
                push @L, ($L[-1]) x $add;
              }
              $L[ 2*$layer + $shift ] .= " $k";
            }
          }
        }
      }
    }
  }
  pop @L while @L and $L[-1] !~ /[^┃┋║│┆\s]/;
  join "\n", @L, '';
}

sub append_keys ($$$$;$) {	# $KK is [[lc,uc], ...]; modifies $C in place
  my ($self, $C, $KK, $LL, $prepend, @KKK, $cnt) = (shift, shift, shift, shift, shift);
  for my $L (0..$#$KK) {	# $LL contains info about from which layer the given binding was stolen
    my $k = $KK->[$L];
    next unless defined $k and (defined $k->[0] or defined $k->[1]);
    $cnt++;
    my @kk = map {$_ and ref $_ ? $_->[0] : $_} @$k;
    my $paired = (@$k == 2 and defined $k->[0] and defined $k->[1] and $kk[0] ne $kk[1] and $kk[0] eq lc $kk[1]);
    my @need_special = map { $LL and $L and defined $k->[$_] and defined $LL->[$L][$_] and 0 == $LL->[$L][$_]} 0..$#$k;
    if (my $special = grep $_, @need_special) {	# count
       ($prepend ? push(@{ $KKK[$paired][0] }, $k) : unshift(@{ $KKK[$paired][0] }, $k)), 
         next if $special == grep defined, @$k;
       $paired = 0;
       my $to_level0 = [map { $need_special[$_] ? $k->[$_] : undef} 0..$#$k];
       $k            = [map {!$need_special[$_] ? $k->[$_] : undef} 0..$#$k];
       $prepend ? push @{ $KKK[$paired][0] }, $to_level0 : unshift @{ $KKK[$paired][0] }, $to_level0;
    }
    $prepend ? push @{ $KKK[$paired][$L] }, $k : unshift @{ $KKK[$paired][$L] }, $k;	# 0: layer has only one slot
  }
#print "cnt=$cnt\n";
  return unless $cnt;
  push    @$C, [[@KKK]] unless $prepend;	# one group of one level of penalty
  unshift @$C, [[@KKK]] if     $prepend;	# one group of one level of penalty
  1
}

sub shift_pop_compositions ($$$;$$$$) {	# Limit is how many groups to process
  my($self, $C, $L, $backwards, $omit, $limit, $ignore_groups, $store_level, $skip_lc, $skip_uc) 
    = (shift, shift, shift, shift, shift || 0, shift || 1e100, shift || 0, shift, shift, shift);
  my($do_lc, $do_uc) = (!$skip_lc, !$skip_uc);
  my($both, $first, $out_lc, $out_uc, @out, @out_levels, $have_out, $groupN) = ($do_lc and $do_uc);
  my @G = $backwards ? reverse @$C : @$C;
  for my $group (@G[$omit..$#G]) {
    last if --$limit < 0;
    $groupN++;
    for my $penalty_group (@$group) {	# each $penalty_group is indexed by double_occupancy and layer
      # each layer in sorted; if $both, we prefer to extract a paired translation; so it is enough to check the first elt on each layer
      my $group_both = $both;
      if ($both) {
        $group_both = 0 unless $penalty_group->[1] and @{ $penalty_group->[1][$L] || [] } or @{ $penalty_group->[1][0] || [] };
      }	# if $group_both == 0, and $both: double-group is empty, so we can look only in single/unrelated one.
              # if $both = $group_both == 0: may not look in double group, so can look only in single/unrelated one
              # if $both = $group_both == 1: must look in double-group only.
      for my $Set (($L ? [0, $penalty_group->[$group_both][0]] : ()), [$L, $penalty_group->[$group_both][$L]]) {
        my $set = $Set->[1];
        next unless $set and @$set;		# @$set consists of [unshifted, shifted] pairs
        if ($group_both) {	# we know we meet a double element at start of the group
          my $OUT = $backwards ? pop @$set : shift @$set;	# we know we meet a double element at start of the group
          return [] if $groupN <= $ignore_groups;
          @$store_level = ($Set->[0]) x 2 if $store_level;
          return $OUT;
        }
##          or ($both and defined $elt->[0] and defined $elt->[1]);
        my $spliced = 0;
        for my $eltA ($backwards ? map($#$set - $_, 0..$#$set) : 0..$#$set) {			
          my $elt = $eltA - $spliced;
          my $lc_ok = ($do_lc and defined $set->[$elt][0]);
          my $uc_ok = ($do_uc and defined $set->[$elt][1]);
          next if not ($lc_ok or $uc_ok);
          my $have_both = (defined $set->[$elt][0] and defined $set->[$elt][1]);
          my $found_both = ($lc_ok and $uc_ok);	# If defined $have_out, cannot have $found_both; moreover $have_out ne $uc_ok
	  die "Panic!" if defined $have_out and ($found_both or $have_out eq $uc_ok);
#          next if not $found_both and defined $have_out and $have_out eq $uc_ok;
          my $can_splice = $have_both ? $both : 1;
          my $can_return = $both ? $have_both : 1;
          my $OUT = my $out = $set->[$elt];			# Can't return yet: @out may contain a part of info...
          unless ($groupN <= $ignore_groups or defined $have_out and $have_out eq $uc_ok) {	# In case !$do_return or $have_out
            $out[$uc_ok] = $out->[$uc_ok];			# In case !$do_return or $have_out
            $out_levels[$uc_ok] = $Set->[0];
          }
#warn 'Doing <', join('> <', map {defined() ? $_ : 'undef'} @{ $set->[$elt] }), "> L=$L; splice=$can_splice; return=$can_return; lc=$lc_ok uc=$uc_ok";
          if ($can_splice) {		# Now: $both and not $have_both; must edit in place
            splice @$set, $elt, 1;
            $spliced++ unless $backwards;
          } else {			# Must edit in place
            $OUT = [@$out];					# Deep copy
            undef $out->[$uc_ok];				# only one matched...
          }
          $OUT = [] if $groupN <= $ignore_groups;
          if ($can_return) {
            if ($found_both) {
              @$store_level = map {$_ and $Set->[0]} @$OUT if $store_level;
              return $OUT;
            } else {
              @$store_level = @out_levels if $store_level;
              return \@out;
            }
#            return($found_both ? $OUT : \@out);
          }					# Now: had $both and !$had_both; must condinue
          $have_out = $uc_ok;
          $both = 0;						# $group_both is already FALSE
          ($lc_ok ? $do_lc : $do_uc) = 0;
#warn "lc/uc: $do_lc/$do_uc";
        }
      }
    }
  }
  @$store_level = @out_levels if $store_level;
  return \@out
}

my ($rebuild_fake, $rebuild_style) = ("\n\t\t\t/* To be auto-generated */\n", <<'EOR');

.klayout span, .klayout-wrapper .over-shift {
 font-size:   29pt ;
 font-weight: bolder; 
 text-wrap:   none;
 white-space: nowrap;
}
.klayout kbd, .asSpan		{ display: inline-block; }
.asSpan2			{ display: inline-table; }

	/* Not used; allows /-diagonals to be highlighted with nth-last-of-type() */
.klayout kbd.hidden-align	{ display: none; }

kbd span.lc, kbd span.uc	{ display: inline; }

/* Hide lc only if in .uc or hovering over -uc and not inside; similarly for uc */
/* States:	.klayout-wrapper:not(:hover)	|	.klayout.uclc:hover		NORMAL = UCLC
		.klayout-uc:hover .klayout:not(:hover)					UC
		.klayout-wrapper:hover .klayout-uc:not(:hover)				LC	*/
.klayout.lc kbd span.uc, .klayout.uc kbd span.lc, 
	.klayout-uc:hover:not(:active)		.klayout:not(.lc):not(:hover) kbd span.lc,
	.klayout-uc:hover:active		.klayout:not(.uc):not(:hover) kbd span.uc,
	.klayout-wrapper:hover:not(:active)	.klayout-uc:not(:hover) .klayout:not(.uc) kbd span.uc,
	.klayout-wrapper:hover:active		.klayout-uc:not(:hover) .klayout:not(.lc) kbd span.lc	{ display: none; }

/* These should be active unless hovering over wrapper, and not internal .klayout	*/
.klayout.uclc:hover kbd span.uc, .klayout.uclc:hover kbd span.lc,
	.klayout.uclc.force kbd span.uc, .klayout.uclc.force kbd span.lc,
	.klayout-wrapper:not(:hover) .klayout-uc .klayout.uclc:not(.do-alt) kbd span.uc,
	.klayout-wrapper:not(:hover) .klayout-uc .klayout.uclc:not(.do-alt) kbd span.lc {
    font-size: 70%;
}
.klayout.uclc:hover kbd span.uc, .klayout.uclc:hover kbd span.lc,
 .klayout.uclc:not(.in-wrapper) kbd span.uc, .klayout.uclc:not(.in-wrapper) kbd span.lc,
	.klayout.uclc.force kbd span.uc, .klayout.uclc.force kbd span.lc,
	.klayout-wrapper:not(:hover) .klayout-uc .klayout.uclc.do-alt kbd span.uc, 
	.klayout.uclc.do-alt:hover kbd span.uc,
	.klayout-wrapper:not(:hover) .klayout-uc .klayout.uclc.do-alt kbd span.lc, 
	.klayout.uclc.do-alt:hover kbd span.lc,
	.klayout-wrapper:not(:hover) .klayout-uc .klayout.uclc:not(.do-alt) kbd span.uc,
	.klayout-wrapper:not(:hover) .klayout-uc .klayout.uclc:not(.do-alt) kbd span.lc {
    position: absolute;
    z-index: 10;
    border: 1px dotted green;
    line-height: 0.8em;		/* decreasing this moves up; should be changed with padding-bottom */
}
.klayout-wrapper:not(:hover) .klayout-uc .klayout.uclc kbd span.uc,
	.klayout-wrapper .klayout-uc .klayout.uclc:hover kbd span.uc,
	.klayout.uclc kbd span.uc {
    right: 0.2em;
    top:  -0.05em;
    padding-bottom: 0.15em;	/* Less makes _ not fit inside border... */
}
.klayout-wrapper:not(:hover) .klayout-uc .klayout.uclc kbd span.lc,
	.klayout-wrapper .klayout-uc .klayout.uclc:hover kbd span.lc,
	.klayout.uclc kbd span.lc {
    left: 0.2em;
    bottom:  0em;
}
	/* Same for left/right placement */
.klayout-wrapper:not(:hover) .klayout-uc .klayout.uclc kbd span.uc.on-left,
	.klayout-wrapper .klayout-uc .klayout.uclc:hover kbd span.uc.on-left,
	.klayout.uclc:not(.in-wrapper) kbd span.uc.uc.on-left {	/* repeat is needed to protect against :not(.base) about 25lines below */
    left: 0.35em;
    right: auto;
}
.klayout-wrapper:not(:hover) .klayout-uc .klayout.uclc kbd span.lc.on-left,
	.klayout-wrapper .klayout-uc .klayout.uclc:hover kbd span.lc.on-left,
	.klayout.uclc:not(.in-wrapper) kbd span.lc.lc.on-left {
    left: 0.0em;
}
.klayout-wrapper:not(:hover) .klayout-uc .klayout.uclc kbd span.uc.on-right,
	.klayout-wrapper .klayout-uc .klayout.uclc:hover kbd span.uc.on-right,
	.klayout.uclc:not(.in-wrapper) kbd span.uc.uc.on-right {
    right: 0.0em;
}
.klayout-wrapper:not(:hover) .klayout-uc .klayout.uclc kbd span.lc.on-right,
	.klayout-wrapper .klayout-uc .klayout.uclc:hover kbd span.lc.on-right,
	.klayout.uclc:not(.in-wrapper) kbd span.lc.lc.on-right {
    left: auto;
    right: 0.35em;
}
.klayout kbd span:not(.base):not(.base-uc):not(.base-lc).on-right
    { left: auto;  right: 0.0em; position: absolute; }
.klayout kbd span:not(.base):not(.base-uc):not(.base-lc).on-left
    { left: 0.0em;  right: auto; position: absolute; }
.klayout kbd .on-right:not(.prefix), .on-right-ex		{ color: firebrick; }
.klayout kbd .on-right:not(.prefix).vbell			{ color: Coral; }
.klayout kbd .on-left { z-index: 10; }
.klayout kbd .on-right { z-index: 9; }

.klayout-wrapper:hover .klayout.uclc:not(:hover) kbd.shift {outline: 6px dotted green;}

kbd span, kbd div { vertical-align: bottom; }	/* no effect ???!!! */

kbd {
    color: #444;
/*    line-height: 1.6em;  */
    width: 1.4em;		/* +0.24em border +0.08em margin; total 1.72em */

    /* +0.3em border;  */
    min-height: 0.83em;		/* These two should be changed together to get uc letters centered... */
    line-height: 0.75em;	/* Increasing by the same amount works fine??? */
		/* One also needs to change the vertical offsets of arrows from_*, and System-key icon */

    text-align: center;
    cursor: pointer;
    padding: 0.0em 0.0em 0.0em 0.0em;
    margin: 0.04em;
    white-space: nowrap;
    vertical-align: top;
    position: relative;

    background-color: #FFFFFF;

    background-image: -moz-linear-gradient(left,  rgba(0,0,0,0.2), rgba(64,64,64,0.2),  rgba(64,64,64,0.2),  rgba(128,128,128,0.2));
    background-image: -webkit-gradient(linear, left top, right top, color-stop(0%,rgba(0,0,0,0.2)), color-stop(33%,rgba(64,64,64,0.2)), color-stop(66%,rgba(64,64,64,0.2)), color-stop(100%,rgba(128,128,128,0.2)));
    background-image: -webkit-linear-gradient(left,  rgba(0,0,0,0.2) 0%, rgba(64,64,64,0.2) 33%, rgba(64,64,64,0.2) 66%, rgba(128,128,128,0.2) 100%);
    background-image: -o-linear-gradient(left,  rgba(0,0,0,0.2) 0%, rgba(64,64,64,0.2) 33%, rgba(64,64,64,0.2) 66%, rgba(128,128,128,0.2) 100%);
    background-image: -ms-linear-gradient(left,  rgba(0,0,0,0.2) 0%, rgba(64,64,64,0.2) 33%, rgba(64,64,64,0.2) 66%, rgba(128,128,128,0.2) 100%);
    background-image: linear-gradient(0deg,  rgba(0,0,0,0.2) 0%, rgba(64,64,64,0.2) 33%, rgba(64,64,64,0.2) 66%, rgba(128,128,128,0.2) 100%);
    filter: progid:DXImageTransform.Microsoft.gradient( startColorstr='#dddddd', endColorstr='#e5e5e5',GradientType=1 );

    border-top: solid 0.1em #CCC;
    border-right: solid 0.12em #AAA;
    border-bottom: solid 0.2em #999;
    border-left: solid 0.12em #BBB;
    -webkit-border-radius: 0.22em;
    -moz-border-radius: 0.22em;
    border-radius: 0.22em;
    z-index: 0;

    -webkit-box-shadow:
        0.03em 0.1em 0.1em 0.06em #888,
        0.05em 0.1em 0.06em 0.06em #aaa;
    -moz-box-shadow:
        0.03em 0.1em 0.1em 0.06em #888,
        0.05em 0.1em 0.06em 0.06em #aaa;
    box-shadow:
        0.03em 0.1em 0.1em 0.00em #888 ,
        0.05em 0.1em 0.06em 0.0em #aaa ;
}

kbd:hover, .klayout-wrapper:hover .klayout:not(:hover) kbd.shift {
    color: #222;
    background-image: -moz-linear-gradient(left,  rgba(128,128,128,0.2), rgba(192,192,192,0.2),  rgba(192,192,192,0.2),  rgba(255,255,255,0.2));
    background-image: -webkit-gradient(linear, left top, right top, color-stop(0%,rgba(128,128,128,0.2)), color-stop(33%,rgba(192,192,192,0.2)), color-stop(66%,rgba(192,192,192,0.2)), color-stop(100%,rgba(255,255,255,0.2)));
    background-image: -webkit-linear-gradient(left,  rgba(128,128,128,0.2) 0%, rgba(192,192,192,0.2) 33%, rgba(192,192,192,0.2) 66%, rgba(255,255,255,0.2) 100%);
    background-image: -o-linear-gradient(left,  rgba(128,128,128,0.2) 0%, rgba(192,192,192,0.2) 33%, rgba(192,192,192,0.2) 66%, rgba(255,255,255,0.2) 100%);
    background-image: -ms-linear-gradient(left,  rgba(128,128,128,0.2) 0%, rgba(192,192,192,0.2) 33%, rgba(192,192,192,0.2) 66%, rgba(255,255,255,0.2) 100%);
    background-image: linear-gradient(0deg,  rgba(128,128,128,0.2) 0%, rgba(192,192,192,0.2) 33%, rgba(192,192,192,0.2) 66%, rgba(255,255,255,0.2) 100%);
    filter: progid:DXImageTransform.Microsoft.gradient( startColorstr='#e5e5e5', endColorstr='#ffffff',GradientType=1 );
}
kbd:active, kbd.selected, .klayout-uc:hover:not(:active) .klayout:not(:hover) kbd.shift, .klayout-wrapper:active .klayout-uc:not(:hover) kbd.shift {
    margin-top: 0.14em;			/* This variant is with "solid" buttons, the commented one is with "rubber" ones */
    border-top: solid 0.10em #CCC;
    border-right: solid 0.12em #9a9a9a;	/* Make right/bottom a tiny way darker */
    border-bottom: solid 0.1em #8a8a8a;
    border-left: solid 0.12em #BBB;
/*    margin-top: 0.11em;
    border-top: solid 0.13em #999;
    border-right: solid 0.12em #BBB;
    border-bottom: solid 0.1em #CCC;
    border-left: solid 0.12em #AAA;	*/
    padding: 0.0em 0.0em 0.0em 0.0em;

    -webkit-box-shadow:
        0.05em 0.03em 0.1em 0.1em #aaa;
    -moz-box-shadow:
        0.05em 0.03em 0.1em 0.1em #aaa;
    box-shadow:
        0.05em 0.03em 0.1em 0em #aaa;

}
kbd img {
    padding-left: 0.25em;
    vertical-align: middle;
    height: 22px; width: 22px;
    opacity: 0.8;
}
kbd:hover img {
    opacity: 1;
}
kbd span.shrink {
    font-size: 85%;
}
kbd .small {
    font-size: 62%;
}
kbd .vsmall {
    font-size: 39%;
}

kbd .base, kbd .base-lc, kbd .base-uc {
    -webkit-touch-callout: none;
    -webkit-user-select: none;
    -khtml-user-select: none;
    -moz-user-select: none;
    -ms-user-select: none;
    -o-user-select: none;
    user-select: none;
}

/* Special rules for do-alt-display.  Without alt2, places the base on left and right;
	with alt2, places base on the left (unless base-right is present) */

/* .klayout.do-alt.uclc kbd span.lc, .klayout.do-alt.uclc kbd span.uc { */
.klayout.do-alt.uclc:not(.in-wrapper) kbd span.uc, .klayout.do-alt.uclc:not(.in-wrapper) kbd span.lc,
.klayout.do-alt.uclc:hover kbd span.uc, .klayout.do-alt.uclc:hover kbd span.lc,
	.klayout.do-alt.uclc.force kbd span.uc, .klayout.do-alt.uclc.force kbd span.lc,
	.klayout-wrapper:not(:hover) .klayout-uc .klayout.do-alt.uclc kbd span.uc,
	.klayout-wrapper:not(:hover) .klayout-uc .klayout.do-alt.uclc kbd span.lc {
   font-size: 85%;
}

.klayout.do-alt.sz125 kbd span.uc, .klayout.do-alt.sz125 kbd span.lc,	/* exclude below: too specific otherwise */
	.klayout.do-alt.sz125 kbd span:not(.lc):not(.uc):not(.base):not(.base-uc):not(.base-lc):not(.shrink):not(.small):not(.vsmall) {
   font-size: 125%;
   line-height: 0.98em;		/* decreasing this moves up; should be changed with padding-bottom */
   /* padding-bottom: 0.1em; */	/* Less makes _ not fit inside border... */
}
.klayout.do-alt.sz120 kbd span.uc, .klayout.do-alt.sz120 kbd span.lc,	/* exclude below: too specific otherwise */
	.klayout.do-alt.sz120 kbd span:not(.lc):not(.uc):not(.base):not(.base-uc):not(.base-lc):not(.shrink):not(.small):not(.vsmall) {
   font-size: 120%;
   line-height: 1.02em;		/* decreasing this moves up; should be changed with padding-bottom */
   /* padding-bottom: 0.1em; */	/* Less makes _ not fit inside border... */
}
.klayout.do-alt kbd span.uc, .klayout.do-alt kbd span.lc,	/* exclude below: too specific otherwise */
	.klayout.do-alt.sz115 kbd span.uc, .klayout.do-alt.sz115 kbd span.lc,
	.klayout.do-alt kbd span:not(.lc):not(.uc):not(.base):not(.base-uc):not(.base-lc):not(.shrink):not(.small):not(.vsmall),
  .klayout.do-alt.sz115 kbd span:not(.lc):not(.uc):not(.base):not(.base-uc):not(.base-lc):not(.shrink):not(.small):not(.vsmall) {
   font-size: 115%;
   line-height: 1.05em;		/* decreasing this moves up; should be changed with padding-bottom */
   /* padding-bottom: 0.1em; */	/* Less makes _ not fit inside border... */
}
.klayout.do-alt.sz110 kbd span.uc, .klayout.do-alt.sz110 kbd span.lc,	/* exclude below: too specific otherwise */
	.klayout.do-alt.sz110 kbd span:not(.lc):not(.uc):not(.base):not(.base-uc):not(.base-lc):not(.shrink):not(.small):not(.vsmall) {
   font-size: 110%;
   line-height: 1.12em;		/* decreasing this moves up; should be changed with padding-bottom */
   /* padding-bottom: 0.1em; */	/* Less makes _ not fit inside border... */
}
.klayout.do-alt.sz100 kbd span.uc, .klayout.do-alt.sz100 kbd span.lc,	/* exclude below: too specific otherwise */
	.klayout.do-alt.sz100 kbd span:not(.lc):not(.uc):not(.base):not(.base-uc):not(.base-lc):not(.shrink):not(.small):not(.vsmall) {
   line-height: 1.2em;		/* decreasing this moves up; should be changed with padding-bottom */
   /* padding-bottom: 0.1em; */	/* Less makes _ not fit inside border... */
}

.klayout.do-alt kbd span.base-lc, .klayout.do-alt kbd span.base-uc {
    font-size: 90%;
}
.klayout.do-alt.alt2 kbd span.base-lc, .klayout.do-alt.alt2 kbd span.base-uc {
    font-size: 80%;
}

.klayout.do-alt kbd span.base-uc {
    right: 15%;
    top: 35%;		/* Combine rel-parent and rel-us offsets : */
}
.klayout.do-alt kbd span.base-lc {
    left: 15%;
    bottom: 25%;		/* Combine rel-parent and rel-us offsets : */
}
.klayout.do-alt.alt2 kbd span.base-uc {
    left: 35%;
    top: 30%;		/* Combine rel-parent and rel-us offsets : */
}
.klayout.do-alt.alt2 kbd span.base-lc {
    left: 15%;
    bottom: 25%;		/* Combine rel-parent and rel-us offsets : */
}
.klayout.do-alt.alt2.base-right kbd span.base-uc {
    right: 15%;
    left: auto;		/* Combine rel-parent and rel-us offsets : */
}
.klayout.do-alt.alt2.base-right kbd span.base-lc {
    right: 35%;
    left: auto;		/* Combine rel-parent and rel-us offsets : */
}
.klayout.do-alt.alt2.base-center kbd span.base-uc {
    left: 60%;		/* Combine rel-parent and rel-us offsets : */
}
.klayout.do-alt.alt2.base-center kbd span.base-lc {
    left: 40%;		/* Combine rel-parent and rel-us offsets : */
}

.klayout.do-alt kbd span.base {
    font-size: 120%;
    left: 25%;
    top: 65%;		/* Combine rel-parent and rel-us offsets : */
}
.klayout.do-alt.large-base.large-base kbd span.base {	/* Make .large-base override .alt2 */
    font-size: 200%;
    left: 50%;
    top: 50%;		/* Combine rel-parent and rel-us offsets : */
}
.klayout.do-alt.alt2 kbd span.base {
    font-size: 110%;
    left: 25%;
    top: 75%;		/* Combine rel-parent and rel-us offsets : */
}
.klayout.do-alt.alt2.base-right kbd span.base {
    right: 25%;
    left: auto;		/* Combine rel-parent and rel-us offsets : */
}
.klayout.do-alt.alt2.base-center kbd span.base {
    left: 50%;		/* Combine rel-parent and rel-us offsets : */
}
.klayout.do-alt kbd span.base, .klayout.do-alt kbd span.base-lc, .klayout.do-alt kbd span.base-uc {
    position: absolute;
    z-index: -1;

    opacity: 0.25;
    filter: alpha(opacity=25); /* IE6-IE8 */

    color: blue;
    line-height: 1em;	/* Tight-fitting box */
    height: 1em;
    width: 1em;
    margin: -0.5em -0.5em -0.5em -0.5em;	/* -0.5em is the geometric center */
}
.klayout.do-alt kbd {
    min-height: 1.2em;		/* Should be changed together to get uc letters centered... */
    line-height: 1.2em;	/* Increasing by the same amount works fine??? */
}
.klayout.do-altgr span.altgr {outline: 9px dotted green;} 

kbd.with_x-NONONO:before {
    position: absolute;
    z-index: -10;

    opacity: 0.25;
    filter: alpha(opacity=25); /* IE6-IE8 */

    content: "✖";
    color: red;
    font-size: 120%;

    line-height: 1em;	/* Tight-fitting box */
    height: 1em;
    width: 1em;

    top: 50%;		/* Combine rel-parent and rel-us offsets : */
    left: 50%;
    margin: -0.43em 0 0 -0.5em;	/* -0.5em is the geometric center; but it is not in the center of ✖...*/
}
kbd.from_sw:after, kbd.from_ne:after, kbd.from_nw:after, kbd.to_ne:after, kbd.to_nw:before, kbd.to_w:after, kbd.from_w:after {
    position: absolute;
    z-index: 1;
    font-size: 80%;
    color: red;
    text-shadow: 1px 1px #ffff88, -1px -1px #ffff88, -1px 1px #ffff88, 1px -1px #ffff88;
    text-shadow: 1px 1px rgba(255,255,0,0.3), -1px -1px rgba(255,255,0,0.3), -1px 1px rgba(255,255,0,0.3), 1px -1px rgba(255,255,0,0.3);
}
kbd.from_sw:not(.pure), kbd.xfrom_sw, kbd.from_ne:not(.pure), kbd.from_nw:not(.pure), kbd.to_ne:not(.pure), kbd.to_nw:not(.pure) {
    text-shadow: 1px 1px yellow, -1px -1px yellow, -1px 1px yellow, 1px -1px yellow;
}
kbd.from_sw:after {
    left: -0.0em;
    bottom:  -0.65em;
}
kbd.from_sw:after, kbd.to_ne:after {
    content: "⇗";
}
kbd.from_se:after, kbd.to_nw:before {
    content: "⇖";
}
kbd.from_ne:after, kbd.from_nw:after {
    top:  -0.55em;
}
kbd.to_ne:after, kbd.to_nw:before {    top:  -0.85em;}
kbd.to_nw:before {    left:  0.01em;}
kbd.from_ne:after { content: "⇙"; }
kbd.from_ne:after, kbd.to_ne:after { right: -0.0em; }
kbd.from_nw:after { content: "⇘"; left: -0.0em; }
kbd.to_w:after, kbd.from_w:after {
    top:  45%;
    left: -0.7em;
}
kbd.to_w:after { content: "⇐"; }
kbd.from_w:after { content: "⇒"; }

/* Compensate for higher keys */
.klayout.do-alt kbd.from_sw:after {
    bottom: -0.90em;
}
.klayout.do-alt kbd.from_ne:after, .klayout.do-alt kbd.from_nw:after {
    top:  -0.85em;
}

span.prefix {
    color: yellow;
    text-shadow: 1px 1px black, -1px -1px black, -1px 1px black, 1px -1px black;
}
span.prefix.prefix2 {
    text-shadow: 1px 1px black, -1px -1px black, -1px 1px black, 1px -1px black,
    		 3px 0px firebrick, -3px 0px firebrick, 0px 3px firebrick, 0px -3px firebrick;
}
span.very-special {
    text-shadow: 1px 1px lime, -1px -1px lime, -1px 1px lime, 1px -1px lime;
}
span.special {
    text-shadow: 2px 2px dodgerblue, -2px -2px dodgerblue, -2px 2px dodgerblue, 2px -2px dodgerblue;
}
.thinspecial span.special {
    text-shadow: 1px 1px dodgerblue, -1px -1px dodgerblue, -1px 1px dodgerblue, 1px -1px dodgerblue;
}
span.not-surr:not(.prefix) {
    text-shadow: 2px 2px white, -2px -2px white, -2px 2px white, 2px -2px white;
}
span.need-learn {
    text-shadow: 1px 1px coral, -1px -1px coral, -1px 1px coral, 1px -1px coral;
}
span.need-learn.on-right {
    text-shadow: 1px 1px black, -1px -1px black, -1px 1px black, 1px -1px black,
		 2px 2px coral, -2px -2px coral, -2px 2px coral, 2px -2px coral;
}
span.may-guess {
    text-shadow: 1px 1px yellow, -1px -1px yellow, -1px 1px yellow, 1px -1px yellow;
}

kbd.win_logo.ubuntu:before {
    content: url(http://linux.bihlman.com/wp-content/plugins/wp-useragent/img/24/os/ubuntu-2.png);
}
kbd.win_logo:before {
    position: absolute;
    z-index: -10;

    content: url(40px-computer_glenn_rolla_01.svg.med.png);
    height: 100%;
    width: 100%;

    top: 0%;		/* Combine rel-parent and rel-us offsets : */
    left: 0%;
/*    margin: -0.5em -0.5em -0.5em -0.5em; */	/* -0.5em is the geometric center */
}
.do-alt kbd.win_logo:before {	/* How to vcenter automatically??? */
    top: 20%;
}

/* Mark vowel's diagonals (for layout of diacritics) */
.ddiag .arow > kbd:nth-of-type(2),		.ddiag .arow > kbd:nth-last-of-type(7),
   .diag .arow > kbd:nth-of-type(2),		.diag .arow > kbd:nth-of-type(7),
   .diag .drow > kbd:nth-of-type(2),		.diag .drow > kbd:nth-of-type(7),
   .diag .arow > kbd:nth-of-type(10),		.diag .drow > kbd:nth-of-type(10),	kbd.red-bg
				{ background-color: #ffcccc; }
.ddiag .arow > kbd:nth-last-of-type(6),	.ddiag .arow > kbd:nth-of-type(4),
   .diag .arow > kbd:nth-of-type(8),	.diag .arow > kbd:nth-of-type(3),
   .diag .drow > kbd:nth-of-type(8),	.diag .drow > kbd:nth-of-type(3),		kbd.green-bg
				{ background-color: #ccffcc; }
.ddiag .arow > kbd:nth-last-of-type(8),	.ddiag .arow > kbd:nth-last-of-type(5),
  .diag .arow > kbd:nth-of-type(9),	.diag .arow > kbd:nth-of-type(4),
  .diag .drow > kbd:nth-of-type(9),	.diag .drow > kbd:nth-of-type(4),		kbd.blue-bg
				{ background-color: #ccccff; }

span.vbell		{ color: SandyBrown; }
span.three-cases	{ outline: 3px dotted yellow; }
span.three-cases-long	{ outline: 3px dotted MediumSpringGreen; }

span.withSubst	{ outline: 1px dotted blue;  outline-offset: -1px; }
span.isSubst		{ outline: 1px solid blue;  outline-offset: -1px; }
  
.use-operator span.operator		{ background-color: rgb(255,192,203)	/*pink*/; }
span.relation		{ background-color: rgb(255,160,122)	/*lightsalmon*/; }
span.ipa		{ background-color: rgb(173,255,47)	/*greenyellow*/; }
span.nAry		{ background-color: rgb(144,238,144)	/*lightgreen*/; }
span.paleo		{ background-color: rgb(240,230,140)	/*Khaki*/; }
.use-viet span.viet		{ background-color: rgb(220,220,220)	/*Gainsboro*/; }
div:not(.no-doubleaccent) span.doubleaccent	{ background-color: rgb(255,228,196)	/*Bisque*/; }
span.ZW		{ background-color: rgb(220,20,60)	/*crimson*/; }
span.WS		{ background-color: rgb(128,0,0)	/*maroon*/; }

.use-operator span.operator		{ background-color: rgba(255,192,203,0.5)	/*pink*/; }
span.relation		{ background-color: rgba(255,160,122,0.5)	/*lightsalmon*/; }
span.ipa		{ background-color: rgba(173,255,47,0.5)	/*greenyellow*/; }
span.nAry		{ background-color: rgba(144,238,144,0.5)	/*lightgreen*/; }
span.paleo		{ background-color: rgba(240,230,140,0.5)	/*Khaki*/; }
.use-viet span.viet		{ background-color: rgba(220,220,220,0.5)	/*Gainsboro*/; }
div:not(.no-doubleaccent) span.doubleaccent	{ background-color: rgba(255,228,196,0.5)	/*Bisque*/; }
span.ZW		{ background-color: rgba(220,20,60,0.5)		/*crimson*/; }
span.WS		{ background-color: rgba(128,0,0,0.5)		/*maroon*/; }

span.lFILL[convention]:before		{ content: attr(convention); 
					  color: white; 
					  font-size: 50%; }

span.lFILL:not([convention])	{ margin: 0ex 0.35ex; }
span.l-NONONO		{ margin: 0ex 0.06ex; }
span.yyy		{ padding: 0px !important; }

div.rtl-hover:hover div:not(:hover) kbd span:not(.no-mirror-rtl):not(.base):not(.base-uc):not(.base-lc) { direction: rtl; }

div.zero { position: relative;}
div.zero div.over-shift { position: absolute; height: 1.13em; z-order: 999;}
/* div.zero div.over-shift { outline: 3px dotted yellow;} */
.do-alt + div.zero div.over-shift { height: 1.5em; }
div.zero.l div.over-shift { left: 0.04pt; width: 4.24em;}
div.zero.r div.over-shift { left: 21.12em; width: 3.56em;}	/* (1.72em - 0.04em) × 10 + 4.24em + 0.08 */
div.zero.tp div.over-shift { top: 7.8em;}
.over-shift-outline div.zero.btm div.over-shift { outline: 3px dotted blue;}
div.zero.btm div.over-shift { bottom: 1.13em;}
.do-alt + div.zero.btm div.over-shift { bottom: 1.5em;}
/* div.zero:hover { outline: 6px dotted yellow;} */

EOR

sub apply_filter_div ($$;$) {
  my($self, $txt, $opt) = (shift, shift, shift || {});
  $txt =~ s(^(<div\b[^>]*\skbd_rebuild="([^""]*?)"[^'">]*>).*?^(</div)\b)
  	   ( $1 . ($opt->{fake} ? $rebuild_fake : $self->html_keyboard_diagram("$2", $opt)) . $3 )msge;
  $txt;
}
sub apply_filter_style ($$;$) {
  my($self, $txt, $opt) = (shift, shift, shift || {});
  $txt =~ s(^(\s*/\*\s*START\s+auto-generated\s+style\s*\*/).*?(/\*\s*END\s+auto-generated\s+style\s*\*/))
  	   ( $1 . ($opt->{fake} ? $rebuild_fake : $rebuild_style) . $2 )msge;
  $txt;
}

my @HTML_KBD_FIXED = ('

<span class=drow>',
	   '<kbd style="width: 2.4em"><span class=vsmall>Backspace</span></kbd><kbd class=hidden-align></kbd></span>

<br><span class=arow><kbd style="width: 2.4em">Tab</kbd>',
	   '</span>

<br><span class=arow><kbd style="width: 3em"><span class=small>CapsLock</span></kbd>',
	   '<kbd style="width: 2.52em"><span class=shrink>Enter</span></kbd></span>

<br><span class=arow><kbd style="width: 4em" class="shift">Shift</kbd>',
	   '<kbd style="width: 3.24em" class="shift">Shift</kbd></span>

<br><span class=srow><kbd style="width: 2.5em">Ctrl</kbd><kbd class=win_logo></kbd><kbd style="width: 2em">Alt</kbd>', 
	   '<kbd style="width: 8.08em"></kbd><kbd style="width: 2em"><span class="small altgr">AltGr</span></kbd><kbd style="width: 2.5em">Menu</kbd><kbd style="width: 2.5em">Ctrl</kbd></span>

');

sub classes_by_chars ($$$$$$$$$$) {
  my ($self, $h_classes, $opt, $layer, $lc0, $uc0, $lc, $uc, $k_base, $k, %cl) = 
       (shift, shift, shift, shift, shift, shift, shift, shift, shift, shift);
  for my $L ('', $layer) {
    for my $c (grep defined, $lc0, $uc0) {
      $cl{$_}++ for @{ $h_classes->{"$k_base$L"}{$c} };		# k	for key-based-on-background char
      for my $o (@$opt) {
        $cl{$_}++ for @{ $h_classes->{"$k_base$L=$o"}{$c} }	# k=opt	for key-based-on-background char
      }
    }
    for my $c (grep defined, $lc, $uc) {
      $cl{$_}++ for @{ $h_classes->{"$k$L"}{$c} };		# K	for key-based-on-foreground char
      for my $o (@$opt) {
        $cl{$_}++ for @{ $h_classes->{"$k$L=$o"}{$c} }	# K=opt	for key-based-on-background char
      }
    }
  }
  keys %cl;
}

sub apply_kmap($$$) {
  my ($self, $kmap, $c) = (shift, shift, shift);
  return $c unless $kmap;
  $c = $c->[0] if ref $c;
  return $c unless defined ($c = $kmap->{$self->key2hex($c)});
  return chr hex $c unless ref $c;
  $c = [@$c];			# deep copy
  $c->[0] = chr hex $c->[0];
  $c;
}

sub do_keys ($$$@) {		# calculate classes related to the “whole key”, and emit the “content” of the key
  my ($self, $opt, $base, $out, $lc0, $uc0, %c_classes) = (shift, shift, 1, '');
  for my $in (@_) {
    my ($lc, $uc, $f, $kmap, $layerN, $h_classes, $name, @classes) = @$in;
    $kmap and $_ = $self->apply_kmap($kmap, $_) for ($lc, $uc);
    ref and $_ = $_->[0] for $lc, $uc;
    ($lc0, $uc0) = ($lc, $uc), $base = 0 if $base;
    # k/K	for key-based-on-(background/foreground) char;	k=opt/K=opt	likewise
    $c_classes{$_}++ for $self->classes_by_chars($h_classes, $opt, $layerN, $lc0, $uc0, $lc, $uc, 'k', 'K');
  }
  my @extra = sort keys %c_classes;
  my $q = (@extra > 1 ? '"' : '');
  my $cl = @extra ? " class=$q@extra$q" : '';
#  push @extra, 'from_se' if $k[0][0] =~ /---/i;	# lc, uc, $h_classes, name, classes:
  join '', $out, "<kbd$cl>", (map $self->a_pair($opt, $lc0, $uc0, $self->apply_kmap($_->[3], $_->[0]),
  								  $self->apply_kmap($_->[3], $_->[1]),
  						$_->[2], $_->[4], $_->[5], $_->[6], [@$_[7..$#$_]]), @_), '</kbd>'
}

sub h($)  { (my $c = shift) =~ s/([&<>])/$html_esc{$1}/g; $c }
sub tags_by_rx {
  my ($c, @o) = shift;
  die "Need odd number of arguments" if @_ & 1;
  while (@_) {
    my $tag = shift;
    push @o, $tag if $c =~ shift;
  }
  return @o;
}

sub a_pair ($$$$$$$$$$;@) {
  my($self, $opts, $lc0, $uc0, $LC, $UC, $F, $layerN, $h_classes, $name, $extra) = 
  (shift, shift, shift, shift, shift, shift, shift, shift, shift, shift, shift || []);
#  warn "See lc prefix    $LC->[0]  " if ref $LC and $LC->[2];
  my ($lc1, $uc1) = map {(defined and ref()) ? $_->[0] : $_} $LC, $UC;

  $extra = [@$extra];
  my $e = @$extra;

  my ($lc, $uc) = map {defined() ? $_ : '♪'} $lc1, $uc1;
#  return join '', map {defined() ? $_ : ''} $lc, $uc;

  my $opt = { map {($_, 1)} @$opts };
  my $base = (($name || '') eq 'base');
  my $prefix2 = (ref($LC) and ref($UC) and $LC->[2] and $UC->[2] && $uc eq $lc);
  if ($prefix2 or ($uc eq ucfirst $lc and $lc eq lc $uc and $lc ne 'ß' and defined($lc1) == defined($uc1))) {
    if ($uc ne $lc) {
      ref and $_->[2] and die "Do not expect a character `$_->[0]' to be a deadkey..." for $LC, $UC;
    }
    my @pref_i = map { ref $_ and (3 == ($_->[2] || 0) or (3 << 3) == ($_->[2] || 0)) } $LC, $UC;
    $prefix2 and $pref_i[1] and not $pref_i[0] and unshift @$extra, 'prefix2';
    $LC and ref $LC and $LC->[2] and unshift @$extra, 'prefix';
    push @$extra, $self->classes_by_chars($h_classes, $opts, $layerN, $lc0, undef, $lc1, undef, 'c', 'C');
#    unshift @$extra, tags_by_rx $lc,	'need-learn'	=> ($opt->{cyr} ? qr/N-A/i : qr/[ϝϙϲͻϿϾͲ℧ϗ]N-A/i);
#    push @$extra, 'vbell' unless defined $lc1;
    push @$extra, (1 < length uc $lc1 ? 'three-cases-long' : 'three-cases') 
      if defined $lc1 and uc $lc1 ne ucfirst $lc1;
    push @$extra, $name if $name;
    my $q = (@$extra > 1 ? '"' : '');
    @$extra = sort @$extra;
    my $cl = @$extra ? " class=$q@$extra$q" : '';
    $base ? "<span$cl>" . h($uc) . "</span>" : $self->char_2_html_span(undef, $UC, $uc, $F, {}, @$extra)
#    "<span$cl>" . $out . "</span>";
  } else {
    my (@e_lc, @e_uc);
    my @do = ([$lc, [], 'lc', $LC, $lc0, $lc1], [$uc, [], 'uc', $UC, $uc0, $uc1]);
#    warn "See lc prefix    $LC->[0]  " if ref $LC and $LC->[2];
    $_->[3] and ref $_->[3] and $_->[3][2] and push @{$_->[1]}, 'prefix' for @do;
    $_->[3] and ref $_->[3] and (3 == ($_->[3][2] || 0) or (3 << 3) == ($_->[3][2] || 0)) and push @{$_->[1]}, 'prefix2' for @do;
    push @{$_->[1]}, $self->classes_by_chars($h_classes, $opts, $layerN, $_->[4], undef, $_->[5], undef, 'c', 'C'),
    		     tags_by_rx $_->[0],	'not-surr' => qr/[„‚“‘”’«‹»›‐–—―‒‑‵‶‷′″‴⁗〃´]/i			# white
    	for @do;
    push @{$_->[1]}, 'vbell' for grep !defined $_->[5], @do;
    join '', map {
       push @{$_->[1]}, ($name ? "$name-$_->[2]" : $_->[2]);
       my $q = ($e || @{$_->[1]}) ? '"' : '';
       my $ee = [sort @$extra, @{$_->[1]}];
       my $o = ($base	? "<span class=$q@$ee$q>" . h($_->[0]) . "</span>" 
       			: $self->char_2_html_span(undef, $_->[3], $_->[0], $F, {}, @$ee));
#       "<span class=$q@$e$j$_->[2]$q>$o</span>";
      } @do;
  }
}

sub keys2html_diagram ($$$$@) {
  my ($self, $opts, $cnt, $new_row) = (shift, shift, shift, shift);
  my @fixed = @HTML_KBD_FIXED;
  my $out = shift @fixed;
#  $cnt = $#{$layers_info->[0]} if $cnt > $#{$layers_info->[0]};
 KEY:
  for my $kn (0..($cnt-1)) {	# Ordinal of keyboard's key
    $out .= (shift(@fixed) || '') if $new_row->{$kn};
    my ($symb, @keys, $last) = 0;
    for my $KK (@_) {			# Layers
      my($layer, @rest) = @$KK;			# rest = face, kmap, layerN, class_hash, name, classes
      push @keys, [@{$layer->[$kn]}[0,1], @rest];
    }
    $out .= $self->do_keys($opts, @keys);
  }
  $out .= join '', @fixed;
  $out
}

sub html_keyboard_diagram ($$$) {
  my($self, $OPT, $global_opt, @opt, @layers, $face0) = (shift, shift, shift);
  my %tr = qw(l 0 c 1 h 2);
  for my $arg (split /\s+/, $OPT) {
    push(@opt, $arg), next if $arg =~ s(^/opt=)();	# BELOW: `base' becomes NAME, `on-right' becomes CLASSES
    die "unrecognized `rebuild' option: `$arg'" 	#  +=l,0,0           +base=l,0,0 +=l,0,1	 +=l,ƒ,0	 on-right+=c,0,1
      unless my($classes, $name, $f, $prefix, $which) = ( $arg =~ m{^((?:[-\w]+(?:,[-\w]+)*)?)\+([-\w]*)=(\w+),([\da-f]{4}|[^\x20-\x7e][^,]*|[02]?),(\d+)$}i );
    $f = $self->{face_shortcuts}{$f} if exists $self->{face_shortcuts}{$f};
    $face0 ||= $f;
    $prefix =~ s/◌(?=\p{NonspacingMark})//g;
    $prefix = $self->charhex2key($prefix);
    die "output_html_keyboard_diagram(): unknown face `$f'" unless my $L = $self->{faces}{$f}{layers};
#    $which =~ s/^([^\x20-\x7e][^,]*)(?=,)/$col{$g}{$1}/;	# 0,0, or ƒ,0
    my $kmap;
    $b = $self->{faces}{$f}{'[deadkeyFace]'}{$self->key2hex($prefix)} 
      or not length $prefix or die "output_html_keyboard_diagram(): Unknown prefix key `$prefix' for face $f";
    $kmap = $self->linked_faces_2_hex_map($f, $b) if length $prefix;
#    $L = $self->{faces}{$f}{'[deadkeyLayers]'}{$self->key2hex($prefix)} 
#      or die "output_html_keyboard_diagram(): unknown prefix `$prefix' in face `$f'" if length $prefix;
    # create_composite_layers() translates 0000 key to ''
#	warn "I see HTML_classes for face=$f, prefix=`$prefix'" if $self->{faces}{$f}{'[HTML_classes]'}{length $prefix ? $self->key2hex($prefix) : ''};
    my $h_classes = $self->{faces}{$f}{'[HTML_classes]'}{length $prefix ? $self->key2hex($prefix) : ''} || {};
    push(@layers, [$self->{layers}{$L->[$which]}, $f, $kmap, $which, $h_classes, $name, split /,/, $classes]);
#    push(@layers, [$g, $layer, split(/,/, $which), $name, split /,/, $pre]);
  }
  die "there must be exactly one /opt= argument in <<$OPT>>" unless @opt == 1;
  my $opt = [split /,/, $opt[0], -1];
  my ($cnt, @g, %new_row) = (0, @{ $self->{faces}{$face0}{'[geometry]'} || [] });	# keep only 1 from the last row
  @g or die "Face `$face0' has no associated layer with geometry info; did you set geometry_via_layer?";
  pop @g;
  $new_row{ $cnt += $_ }++ for @g;
  my ($pre, $post) = ('', '');
  ($pre, $post) = ("\n<div>", "</div>\nHover mouse here to see how characters look in RTL context.\n") 
    if grep /^rtl-hover(-Trivia)?$/, @$opt;
  $post .= "  <b>Trivia:</b> note <a href=http://en.wikipedia.org/wiki/Mapping_of_Unicode_characters#Bidirectional_Neutral_Formatting>mirroring</a> of <code>&lt;{[()]}&gt;</code>." if grep /^rtl-hover-Trivia$/, @$opt;
  $pre . $self->keys2html_diagram($opt, $cnt+1, \%new_row, @layers) . $post;
}


1;

__END__


=head1 On principles of intuitive design of Latin keyboard

Some common (meaning: from Latin-1-10 of ISO 8859) Latin alphabet letters 
are not composed (at least not by using 3 simplest modifiers out of 8 modifiers).
We mean B<ÆÐÞÇĲØŒß>
(and B<¡¿> for non-alphatetical symbols). It is crucial that they may be
entered by an intuitively clear key of the keyboard.    There is an obvious
ASCII letter associated to each of these (e.g., B<T> associated to the thorn
B<Þ>), and in the best world just pressing this letter with C<AltGr>-modifier
would produce the desired symbol.

  But what to do with ª,º?

There is only one conflict: both B<Ø>,B<Œ> "want" to be entered as C<AltGr-O>;
this is the ONLY piece of arbitrariness in the design so far.  After
resolving this conflict, C<AltGr>-keys B<!ASDCTIO?> are assigned their meanings,
and cannot carry other letters (call them "stuck in stone keys").

(Other keys "stuck in stone" are dead keys: it is important to have the
glyph etched on these keyboard's keys similar to the task they perform.)

Then there are several non-alphabetical symbols accessible through ISO 8859
encodings.  Assigning them C<AltGr>- access is another task to perform.
Some of these symbols come in pairs, such as ≤≥, «», ‹›, “”, ‘’; it makes
sense to assign them to paired keyboard's keys: <> or [] or ().

However, this task is in conflict of interests with the following task, so
let us explain the needs answered by that task first.

One can always enter accented letters using dead keys; but many people desire a
quickier way to access them, by just pressing AltGr-key (possibly with
shift).  The most primitive keyboard designs (such as IBM International,

   http://www.borgendale.com/uls.htm

) omit this step and assign only the NECESSARY letters for AltGr- access.
(Others, like MicroSoft International, assign only a very small set.)

This problem breaks into two tasks, choosing a repertoir of letters which
will be typable this way, and map them to the keys of the keyboard.
For example, EurKey choses to use ´¨`-accented characters B<AEUIO> (except
for B<Ỳ>), plus B<ÅÑ>; MicroSoft International does C<ÄÅÉÚÍÓÖÁÑß> only (and IBM
International does
none); Bepo does only B<ÉÈÀÙŸ> (but also has the Azeri B<Ə> available - which is
not in ISO 8819 - and has B<Ê> on the 105th key "C<2nd \|>"), Mac Extended has
only B<ÝŸ> (?!)

   http://bepo.fr/wiki/Manuel
   http://bepo.fr/wiki/Utilisateur:Masaru					# old version of .klc
   http://www.jlg-utilities.com/download/us_jlg.klc
   http://tlt.its.psu.edu/suggestions/international/accents/codemacext.html
		or look for "a graphic of the special characters" on
   http://homepage.mac.com/thgewecke/mlingos9.html


Keyboards on Mac: L<http://homepage.mac.com/thgewecke/mlingos9.html>
Tool to produce: L<http://wordherd.com/keyboards/>
L<http://developer.apple.com/library/mac/#technotes/tn2056/_index.html>

=head2 Our solution

First, the answer:

=over 10

=item Rule 0:

letters which are not accented by B<`´¨˜ˆˇ°¯> are entered by
C<AltGr>-keys "obviously associated" to them.  Supported: B<ÆÐÞÇĲØß>.
 
=item Rule 0a: 

Same is applicable to B<Ê> and B<Ñ>.

=item Rule 1:

Vowels B<AEYUIO> accented by B<`´¨> are assigned the so called I<"natural position">:
3 Bottom row of keyboard are allocated to accents (B<¨> is the top, B<´> is the middle, B<`> is
the bottom row of 3 letter-rows on keyboard - so B<À> is on B<ZXCV>-row),
and are on the same diagonal as the base letter.  For left-hand
vowels (B<A>,B<E>) the diagonal is in the direction of \, for right hand
voweles (B<Y>,B<U>,B<I>,B<O>) - in the direction of /.

=item Rule 1a: 

If the "natural position" is occupied, the neighbor key in the
direction of "the other diagonal" is chosen.  (So for B<A>,B<E> it is
the /-diagonal, and for right-hand vowels B<YUIO> it is the \-diag.)

=item Rule 1b: 

The neighbor key is down unless the key is on bottom row - then it is up.

Supported by rules "1": all but B<ÏËỲ>.

=item Rule 2:  

Additionally, B<Å>,B<Œ>,B<Ì> are available on keys B<R>,B<P>,B<V>.

=back

=head2 Clarification:

If you remember only Rule 0, you still can enter all Latin-1 letter using
Rule 0; all you need to memorize are dead keys: B<`';~6^7&> for B<`´¨˜ˆˇ°¯>
on EurKey keyboard (but better locations I<ARE> possible).
   
   (What the rule 0 actually says is: "You do not need to memorize me". ;-)

If all you remember are rules 1,1a, you can calculate the position of the
AltGr-key for AEYUIO accented by `´¨ up to a choice of 3 keys (the "natural
key" and its 2 neighbors) - which are quick to try all if you forgot the
precise position.  If you remember rules 1,1ab, then this choice is down to
2 possible candidates.

Essentially, all you must remember in details is that the "natural positions"
form a V-shape # - \ on left, / on right, and in case of bad luck you
should move in the direction of other diagonal one step.  Then a letter is
either in its "obvious position", or in one of 3 modifications of the
natural position".  Only Å and Œ need a special memorization.

=head2 Motivations: 

It is important to have a logical way to quickly understand whether a letter
is quickly accessible from a keyboard, and on which key (or, maybe, to find
a small set of keys on which a letter may be present - then, if one forgets,
it is possible to quickly un-forget by trying a small number of keys).

The idea: we assign alphabetical Latin symbols only to alphabetical keys
on the keyboard; this way we can use (pared) symbol keys to enter pared
Unicode symbols.  Now consider diagonals on the alphabetic part of the
keyboard: \-diagonals (like EDC) and /-diagonals (like UHB).  Each diagonal
contains 3 (or less) alphabetic keys; we WANT to assign ¨-accent to the top
one, ´-accent to the middle one, and `-accent to the bottom one.

On the left-hand part of the keyboard, use \-diagonals, on the right-hand
part use /-diagonals; now each diagonal contains EXACTLY 3 alphabetic keys.
Moreover, the diagonals which contain vowels AEYUIO do not intersect.

If we have not decided to have keys set in stone, this would be all - we
would get "completely predictable" access to ´¨`-accented characters AEUIO.
For example, Ÿ would be accessible on AltGr-Y, Ý on AltGr-G, Ỳ on AltGr-V.
Unfortunately, the diagonals contain keys ASDCIO set in stone.  So we need
a way to "move away" from these keys.  The rule is very simple: we move
one step away in the direction of "other" diagonal (/-diagonal on the left
half, and \-diagonal on the right half) one step down (unless we start
on keys A, C where "down" is impossible and we move up to W or F).

Examples: Ä is on Q, Á "wants to be" on A (used for Æ), so it is moved to
W; Ö wants to be on O (already used for Ø or Œ), and is moved away to L;
È wants to be on C (occupied by Ç), but is moved away to F.

There is no way to enter Ï using this layout (unless we agree to move it
to the "8*" key, which may conflict with convenience of entering typographic
quotation marks).  Fortunately, this letter is rare (comparing even to Ë
which is quite frequent in Dutch).  So there is no big deal that it is not
available for "handy" input - remember that one can always use deadkeys.

 http://en.wikipedia.org/wiki/Letter_frequency#Relative_frequencies_of_letters_in_other_languages

Note that the keys "P" and "R" are not engaged by this layout; since "P"
is a neighbor of "O", it is natural to use it to resolve the conflict
between Ø or Œ (which both want to be set in stone on "O").  This leaves
only the key "R" unengaged; but what we do not cover are two keys Å and Ñ
which are relatively frequent in Latin-derived European languages.

Note that Ì is moderately frequent in Italian, but Ñ is much more frequent
in Spanish.  Since Ì occupies the key which on many keyboards is taken by
Ñ, maybe it makes sense to switch them...  Likewise, Ê is much more frequent
than Ë; switch them.

=head2 (OLD?) TODO

U-caron: ǔ, Ǔ which is used to indicate u in the third tone of Chinese language pinyin.
But U-breve is used in Latin encodings.
Ǧ/ǧ (G with caron) is used, but only in "exotic" or old languages (has no
combined form - while G-breve is in Latin encodings.
A-breve Ă: A-caron Ǎ is not in Latin-N; apparently, is used only in pinyin,
zarma, Hokkien, vietnamese, IPA, transliteration of Old Latin, Bible and Cyrillic's big yus.

In EurKey: only a takes breve, the rest take caron (including G but not U)

out of accents ° and dot-accent ˙ in Latin-N: only A and U take °, and they
do not take dot-accent.  In EurKey: also small w,y take ring accent; same in
Bepo - but they do not take dot accent in Latin-N.

Double-´ and cornu (both on a,u only) can be taken by ¨ or ˙ on letters with
¨ already present (in Unicode ¨ is not precombined with diaeresis or dots).
But one must special-case Ë and Ï and Ø (have Ê and Ĳ instead; Ĳ takes no accents,
but Ê takes acute, grave, tilde and dot below...).!  Æ takes acute and macron; Ø takes acute.

Actually, cornu=horn is only on o,u, so using dot/ring on ö and ü is very viable...

So for using AltGr-letter after deadkeys: diaresis can take dot above, hat and wedge, diaresis.
Likewise, ` and ´ are not precombined together (but there is a combined
combining mark).  So one can do something else on vowels (ogonek?).

Applying ´ to `-accented forms: we do not have `y, so must use "the natural position"
which is mixed with Ñ (takes no accents) and Ç (takes acute!!!).

s, t do not precombine with `; so can use for the "alternative cedilla".

Only auwy take ring, and they do not take cedilla.  Can merge.

Bepo's hook above; ảɓƈɗẻểƒɠɦỉƙɱỏƥʠʂɚƭủʋⱳƴỷȥ ẢƁƇƊẺỂƑƓỈƘⱮỎƤƬỦƲⱲƳỶȤ
  perl -wlnae "next unless /HOOK/; push @F, shift @F; print qq(@F)" NamesList.txt | sort | less
Of capital letters only T and Y take different kinds of hooks... (And for T both are in Latin-Extended-B...)
