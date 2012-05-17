package UI::KeyboardLayout;

$VERSION = $VERSION ="0.10";
use strict;
use utf8;

sub toU($) { substr+(qq(\x{fff}).shift),1 }	# Some bullshit one must do to make perl's Unicode 8-bit-aware (!)

#use subs qw(chr lc);
use subs qw(chr lc uc);

#BEGIN { *CORE::GLOGAL::chr = sub ($) { toU CORE::chr shift };
#        *CORE::GLOGAL::lc  = sub ($)  { CORE::lc  toU shift };
#}
my %fix = qw( ӏ Ӏ ɀ Ɀ ꙡ Ꙡ ꞑ Ꞑ  ꞧ Ꞧ  ɋ Ɋ  ß ẞ  ꞩ Ꞩ  ȿ Ȿ  ꞓ Ꞓ  ꞥ Ꞥ );		# Perl 5.8.8 uc is wrong with palochka, 5.10 with z with swash tail
my %unfix = reverse %fix;

sub chr($)  { local $^W = 0; toU CORE::chr shift }	# Avoid illegal character 0xfffe etc warnings...
sub lc($)   { my $in = shift; $unfix{$in} || CORE::lc toU $in }
sub uc($)   { my $in = shift;   $fix{$in} || CORE::uc toU $in }

# We use this for printing, not for reading (so we can use //o AFTER the UCD is read)
my $rxCombining = qr/\p{NonspacingMark}/;	# The initial version matches what Perl knows

my $warnUNRES = $ENV{UI_KEYBOARDLAYOUT_UNRESOLVED};
BEGIN { my $warnSORTEDLISTS = $ENV{UI_KEYBOARDLAYOUT_REPORT_MUTATORS} || 0;
	my @warnSORTEDLISTS = map $warnSORTEDLISTS & $_, map 1<<$_, 0..31;
	my $c = 0;		# printSORTEDLISTS: Dumpvalue to STDOUT (implementation detail!)
	for (qw(warnSORTEDLISTS printSORTEDLISTS warnSORTCOMPOSE warnDO_COMPOSE warnCACHECOMP dontCOMPOSE_CACHE )) {
	  eval "sub $_ () {$warnSORTEDLISTS[$c++]}";
	}
}

=pod

=encoding UTF-8

=head1 NAME

UI::KeyboardLayout - Module for designing keyboard layouts

=head1 SYNOPSIS

  #!/usr/bin/perl -wC31
  use UI::KeyboardLayout; 
  use strict;
  
  UI::KeyboardLayout::->set_NamesList("$ENV{HOME}/Downloads/NamesList.txt"); 
  
  my $i = do {local $/; open $in, '<', 'MultiUni.kbdd' or die; <$in>}; 
  # Init from in-memory copy of the configfile
  my $k = UI::KeyboardLayout:: -> new_from_configfile($i)
             -> fill_win_template( 1, [qw(faces CyrillicPhonetic)] ); 
  print $k;
  
  open my $f, '<', "$ENV{HOME}/Downloads/NamesList.txt" or die;
  my $k = UI::KeyboardLayout::->new();
  my ($d,$c,$names,$blocks,$extraComb) = $k->parse_NameList($f);
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

Each line consists of prefix (which is ignored except for sanity checking), and
whitespace-separated list of key descriptions.  (Whitespace followed by a
combining character is not separating.)  Each key description is split using
C<in_key_separator> into slots, one slot per layout.  (The leading 
C<in_key_separator> is not separating.)  Each key/layout
description consists of one or two entries.  An entry is either two dashes
C<--> (standing for empty), or a character, or a hex number of length >=4.
(A hex numbers must be separated by C<.> from neighbor word
characters.)  A loner character which has a different uppercase is
auto-replicated in uppercase form.  Missing or empty key/layout description
gives two empty entries (note that the leading key/layout description cannot
be empty; same for "the whole key description" - use the leading C<-->.

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
personality defines C<MetaData_Index> which chooses the element of the array.
The entries

  COMPANYNAME LAYOUTNAME COPYR_YEARS LOCALE_NAME LOCALE_ID
  DLLNAME SORT_ORDER_ID_ LANGUAGE_NAME

should be defined in the personality section, or above this section in the
configuration tree.  (Used for output Windows F<.klc> files.)

Optional metadata currently consists only of C<VERSION> key.

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
and C<[]>-balanced; so must be C<MUTATOR>; in turn, the C<BASE> is either a 
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

The simplest forms of C<MUTATORS> are C<Id, lc, uc, Empty>.  Recall that a layer
is nothing more than a structure associating a pair "unshifted/shifted character" to the key number, and that
these characters may be undefined.  These simplest mutators modify these characters
independently of their key numbers and shift state (with C<Empty> making all of
them undefined).  Similar user-defined simple mutators are C<ByPairs[PAIRS]>;
here C<PAIRS> consists of pairs "FROM TO" of characters (with optional spaces between pairs);
"unknown" characters are undefined.
(As usual, characters may be replaced by hex numbers with 4 or more hex digits;
separate the number from a neighboring word character by C<.> [dot].)

All mutators must have a form C<WORD> or C<WORD[PARAMETERS]>, with C<PARAMETERS>
C<(),[]>-balanced.  Other simple mutators are C<FlipShift> ..................
.........................  Note that C<Id(LAYERNAME)> is similar to a selector;
it is the only way to insert a
layer without a selector, since a bareword is interpreted as a C<MUTATOR>; C<Id(LAYERNAME)> is a synonym
of C<Layers(LAYERNAME+LAYERNAME+...)> (repeated as many times as there are layers
in the parameter "base face").

C<Mutate> (and its flavors) is the most important mutator.

The recipes in a space-separated list of recipes ("first comer wins") are 
interpreted independently to give a collection of layers to combine; then,
for every key numbers and both shift states, one takes the leftmost recipe 
which produces a defined character for this position, and the result is put 
into the resulting layer.

Keep in mind that sometimes to understand what a recipe does, one should trace 
its description in opposite order: for example, C<ByPairs[.:](FlipLayers)> creates
a layout where C<:> is at position of C<.>, but on the second [=other] layer (essentially,
if the base layout is the standard one, it binds character C<:> to keypress C<AltGr-.>).

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
 Modifiers below
 Vertical (or Comma-like or Doubled or Dotlike or Rotated or letter-like) Modifiers
 Prime-like or Centered modifiers
 Combining 
 Combining below
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
  
     Typesetting Old and Modern Church Slavonic
  http://www.sanu.ac.rs/Cirilica/Prilozi/Skup.pdf
  http://irmologion.ru/ucsenc/ucslay8.html
  http://irmologion.ru/csscript/csscript.html
  http://cslav.org/success.htm
  http://irmologion.ru/developer/fontdev.html#allocating

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
      Discussion of layout changes:
  https://www.libreoffice.org/bugzilla/show_bug.cgi?id=5981

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
      Suggest a topic:
  http://blogs.msdn.com/b/michkap/archive/2007/07/29/4120528.aspx#7119166

VK_OEM_8 Kana modifier - Using instead of AltGr
  http://www.kbdedit.com/manual/ex13_replacing_altgr_with_kana.html
Limitations of using KANA toggle
  http://www.kbdedit.com/manual/ex12_trilang_ser_cyr_lat_gre.html

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

IPA

  http://upload.wikimedia.org/wikipedia/commons/f/f5/IPA_chart_2005_png.svg
  http://en.wikipedia.org/wiki/Obsolete_and_nonstandard_symbols_in_the_International_Phonetic_Alphabet
  http://en.wikipedia.org/wiki/Case_variants_of_IPA_letters
    Table with Unicode points marked:
  http://www.staff.uni-marburg.de/~luedersb/IPA_CHART2005-UNICODE.pdf
			(except for "Lateral flap" and "Epiglottal" column/row.
    (Extended) IPA explained by consortium:
  http://www.unicode.org/charts/PDF/U0250.pdf
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
	  all flavors but one, THEN enable it for the console...  Then reinstall
	  (preferably newer versions).

Display (how WikiPedia does it):

  http://en.wikipedia.org/wiki/Help:Special_characters#Displaying_special_characters
  http://en.wikipedia.org/wiki/Template:Unicode
  http://en.wikipedia.org/wiki/Template:Unichar
  http://en.wikipedia.org/wiki/User:Ruud_Koot/Unicode_typefaces
    In CSS:  .IPA, .Unicode { font-family: "Arial Unicode MS", "Lucida Sans Unicode"; }
  http://web.archive.org/web/20060913000000/http://en.wikipedia.org/wiki/Template:Unicode_fonts

Windows shortcuts:

  http://windows.microsoft.com/en-US/windows7/Keyboard-shortcuts
  http://www.redgage.com/blogs/pankajugale/all-keyboard-shortcuts--very-useful.html

On meaning of Unicode math codepoints

  http://milde.users.sourceforge.net/LUCR/Math/unimathsymbols.pdf
  http://milde.users.sourceforge.net/LUCR/Math/data/unimathsymbols.txt
  http://unicode.org/Public/math/revision-09/MathClass-9.txt

Zapf dingbats encoding, and other fine points of AdobeGL:

  ftp://ftp.unicode.org/Public/MAPPINGS/VENDORS/ADOBE/zdingbat.txt
  http://web.archive.org/web/20001015040951/http://partners.adobe.com/asn/developer/typeforum/unicodegn.html

Quoting tchrist:
I<You can snag C<unichars>, C<uniprops>, and C<uninames> from L<http://training.perl.com> if you like.>

=head1 LIMITATIONS

Currently only output for Windows keyboard layout drivers (via MSKLC) is available.

Currently only the keyboards with US-mapping of hardware keys to "the etched
symbols" are supported (think of German physical keyboards where Y/Z keycaps
are swapped: Z is etched between T and U, and Y is to the left of X, or French
which swaps A and Q, or French or Russian physical keyboards which have more
alphabetical keys than 26).

Currently no C<LIGATURES> are supported.

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

Copyright (c) 2011-2012 Ilya Zakharevich <ilyaz@cpan.org>

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

When linking two layers, consider prefer_first as a suggestion only: if the prefered slot
results in no link, try the second one.

Translation map "functions" for flipping AltGr-register (cannot one use FromTo[] between
explicit layers???).

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

=over 4

=item Several similar F<MSKLC> created keyboards may confuse the system

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

Possible workaround: manually remove the entry in C<HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Keyboard Layouts>
(the last 4 digits match the codepage in the F<.klc> file).
   
=item Too long description (or funny characters in description?)

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
   
=item F<MSKLC> ruins names of dead key when reading a F<.klc>

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

=item Double bug in F<KBDUTOOL> with dead characters above 0x0fff

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

=item Default keyboard of an application

Apparently, there is no way to choose a default keyboard for a certain
language.  The configuration UI allows moving keyboards up and down in
the list, but, apparently, this order is not related to which keyboard
is selected when an application starts.

=item C<AltGr>-keypresses going nowhere

Some C<AltGr>-keypresses do not result in the corresponding letter on
keyboard being inserted.  It looks like they are stolen by some system-wide
hotkeys.  See:

  http://www.kbdedit.com/manual/ex13_replacing_altgr_with_kana.html

If these keypresses would perform some action, one might be able to deduce
how to disable the hotkeys.  So the real problem comes when the keypress
is silently dropped.

I found out one scenario how this might happen, and how to fix this particular
situation.  (Unfortunately, it is not fixed what I see, when C<AltGr-s> [but not
C<AltGr-S>] is stolen.  Installing a shortcut, one can associate a hotkey to
the shortcut.  Unfortunately, the UI allows (and encourages!) hotkeys of the
form <Control-Alt-letter> (which are equivalent to C<AltGr-letter>) - instead
of safe combinations like C<Control-Alt-F4> or
C<Alt-Shift-letter> (which do not go to keyboard drivers, so cannot generate
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

=item "There was a problem loading the file" from C<MSKLC>

Make line endings in F<.klc> DOSish.

=item C<AltGr-keys> do not work

Make line endings in F<.klc> DOSish (when given as input to F<kbdutool> -
it gives no error messages, and deadkeys work [?!]).

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
  my $skip_first = shift;
  (my $k = shift) =~ s/\p{Blank}(?=\p{NonspacingMark})//g;	# Allow combining marks to be on top of SPACE
  $k = $self->stringHEX2string($k);
  my @k = split //, $k;
  undef $k[0] if ($k[0] || '') eq "\0" and $skip_first;
  push @k, uc $k[0] if @k == 1 and defined $k[0] and $k[0] ne uc $k[0];
  @k
}	# -> list of chars

sub process_key ($$$$) {		# $sep may appear only in a beginning of the first key chunk
  my ($self, $k, $limit, $sep, @tr)  = (shift, shift, shift, shift);
  my @k = split m((?!^)\Q$sep), $k;
  die "Key descriptor `$k' separated by `$sep' has too many parts: expected $limit, got ", scalar @k
    if @k > $limit;
  defined $k[$_] and $k[$_] =~ s/^--(?=.)/\0/ and $tr[$_]++ for 0..$#k;
  $k[0] = '' if $k[0] eq '--';		# Allow a filler (multi)-chunk
  map [$self->process_key_chunk( $tr[$_], (defined($k[$_]) ? $k[$_] : ''))], 0..$#k;
}	# -> list of arrays of chars

sub decode_kbd_layers ($@) {
  my ($self, $lineN, $row, $line_in_row, $cur_layer, @out, $N, $l0) = (shift, 0, -1);
  my %needed = qw(unparsed_data x visual_rowcount 2 visual_per_row_counts [2;2] visual_prefixes * prefix_repeat 3 in_key_separator / layer_names ???);
  my %extra  = qw(keyline_offsets 1);
  my $opt;
  for my $k (keys %needed, keys %extra) {
     my ($from) = grep exists $_->{$k}, @_, (ref $self ? $self : ());
     die "option `$k' not specified" unless $from or $extra{$k};
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
  while (@lines) {
#    push @out, $line_in_row = [] unless $C % $c;
    $row++, $line_in_row = $cur_layer = 0 unless $lineN % $C;
    $lineN++;
    my $l1 = shift @lines;
    my $PREF = qr/(?:$pref->[$line_in_row]){$opt->{prefix_repeat}}/;
    $PREF = '\s' if $pref->[$line_in_row] eq qr/\s/;
    die "line $lineN in visual layers has unexpected prefix:\n\tPREF=/$PREF/\n\tLINE=`$l1'"  unless $l1 =~ s/^$PREF\s*(?<=\s)//;
    my @k1 = split /\s+(?!\p{NonspacingMark})/, $l1;
    $l0 = $l1, $N = @k1 if $line_in_row == 0;
# warn "Got keys: ", scalar @k1;
    die sprintf "number of keys in lines differ: %s vs %s in:\n\t`$l0'\n\t`$l1'", 
      scalar @k1, $N unless @k1 == $N;		# One can always fill by --
    for my $key (@k1) {
      my @kk = $self->process_key($key, $lc->[$line_in_row], $opt->{in_key_separator});
      push @{$out[$cur_layer + $_]}, $kk[$_] || [] for 0..($lc->[$line_in_row]-1);
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
  my @K = grep m(^\[unparsed]/KBD\b), @{$h->{'[keys]'}};
#  my $H = $h->{'[unparsed]'};
  for my $k (@K) {
    my (@parts, @h) = split m(/), $k;
    ref $self and push @h, $self->get_deep($self, @parts[1..$_]) || {} for 0..$#parts;
    push @h, $self->get_deep($h, @parts[1..$_]) || {} for 0..$#parts;		# Drop [unparsed]/ prefix...
    push @h, $self->get_deep($h,    @parts[0..$_]) || {} for -1..$#parts;
    my ($in, $counts, $offsets) = $self->decode_kbd_layers( reverse @h );
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
    ++$to->{ $self->key2hex($_->[0], 'undef_ok') }, ++$to->{ $self->key2hex($_->[1], 'undef_ok') } 
      for @$sub;
  }
}

sub deep_copy($$) {
  my ($self, $o) = (shift, shift);
  return $o unless ref $o;
  return [map $self->deep_copy($_), @$o] if "$o" =~ /^ARRAY\(/;	# We should not have overloaded elements
  return {map $self->deep_copy($_), %$o} if "$o" =~ /^HASH\(/;
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
  my ($hn,$Hn) = map $self->{faces}{$_}{layers}, $hh, $HH;
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
  for my $K (0..$#{$self->{layers}{$hn->[0]}}) {
#warn "One key data, FROM: K=$K, layer=<", join( '> <', map $self->{layers}{$_}[$K], @$Hn), '>' if "$hh $HH" =~ /00a9/i;
    my @h = map $self->{layers}{$_}[$K], @$hn;		# arrays of [lowercase,uppercase]
#warn "One key data, TO: K=$K, layer=<", join( '> <', map $self->{layers}{$_}[$K], @$Hn), '>' if "$hh $HH" =~ /00a9/i;
    my @H = map $self->{layers}{$_}[$K], @$Hn;
    my @c = map [@$_], @h;								# deep copy
    my @C = map [@$_], @H;
    # Find which of keys on $H[0] obscure symbol keys from $h[0]
    my @symb0 = grep +($h[0][$_] || '') =~ /[\W_]/, 0, 1;	# not(wordchar but not _): symbols on $h[0]
    $H[0][$_] or $skipwarn or warn "Symbol char `$h[0][$_]' not copied to the second face while the slot is empty" for @symb0;
    my @obsc = grep $h[0][$_] ne ($H[0][$_] || ''), @symb0;
#warn "K=$K,\tobs=@obsc;\tsymb0=@symb0";
    # If @obsc == 1, put on non-shifted location; may overwrite only ?-binding if it exists
    #return unless @obsc;
    my %map = ((@obsc and not $skipfix) ? (@obsc == 1 ? ($obsc[0] => 0) : ( 0 => 0, 1 => 1)) : ());
    for my $k (keys %map) {
      if ($skipfix) {
        my $s = $k ? ' (shifted)' : '';
        warn "Key `$H[0][$k]'$s in layer $Hn->[0] does not match symbol $h[0][$k] in layer $hn->[0], and skipfix is requested...\n"
          unless ref($skipwarn || '') ? $skipwarn->{$h[0][$k]} : $skipwarn;
      } elsif (defined $H[1][$map{$k}] and ($h[0][$k] =~ /\p{Blank}/ or $H[1][$map{$k}] =~ /\p{Blank}/)) {
	warn "A hack is needed: attempt to de-obscure `$h[0][$k]' on a supplementary key with `$H[1][$map{$k}]'"
      } else {
        if (defined $H[1][$map{$k}]) {
          # So far, the only "obscuring" with useful de-obscuring is when the obscuring symbol is a letter
          die "existing secondary AltGr-binding `$H[1][$map{$k}]' blocks de-obscuring `$h[0][$k]'; symb=[@symb0] in [@{$h[0]}]"
            unless ($H[0][$k] || '.') =~ /[\W\d_]/;
          next
        }
        $H[1][$map{$k}] = $h[0][$k];			# !!!! Modify in place
      }
    }
    # Join in blue keys, and inherit keys from $h
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
sub link_layers ($$$;$$$) {	# Un-obscure non-alphanum bindings from the first keyboard
  my ($self, $hh, $HH, $skipfix, $skipwarn, $default_char) = (shift, shift, shift, shift, shift, shift);	# [Main, AltGr-Main,...], [Secondary, AltGr-Secondary,...]
  $self->pre_link_layers ($hh, $HH, $skipfix, $skipwarn);
#warn "Linking with FIX: $hh, $HH" unless $skipfix;
  $self->face_make_backlinks($HH, $self->{faces}{$HH}{'[char2key_prefer_first]'}, $self->{faces}{$HH}{'[char2key_prefer_last]'}, $skipfix, 'skipwarn');
  $self->face_make_backlinks($hh, $self->{faces}{$hh}{'[char2key_prefer_first]'}, $self->{faces}{$hh}{'[char2key_prefer_last]'}, 'skip');
  $self->faces_link_via_backlinks($hh, $HH, $default_char);
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

sub faces_link_via_backlinks($$$;$$) {		# It is crucial to proceed layers in 
#  parallel: otherwise the semantic of char2key_prefer_first suffers
  my ($self, $F1, $F2, $default, $no_inic) = (shift, shift, shift, shift, shift);
  return if $self->{faces}{$F1}{"AltGr_SPACE_map"}{$F2};		# Reuse old copy
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
				  } @$arr), $default or next;
    my ($To) = grep defined, (map { $LL[$self->flip_layer_N($_->[0], $maxL)][$_->[1]][$_->[2]] } @$arr), $default or next;
    $r{$c}    = $to;					# Keep prefix keys as array refs
    $altR{$c} = $To;					# Ditto
  }
  $self->{faces}{$F1}{"AltGr_SPACE_map"}{$F2} = \%r;
  $self->{faces}{$F1}{"AltGr_SPACE_map_INV"}{$F2} = \%altR;
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
      $self->{faces}{$f}{layers} = [('Empty') x $n];		# Preliminary
      $self->{faces}{$f}{layers} = $self->layers_by_face_recipe($f, $f);
    }
    for my $ln ( 0..$#{$self->{faces}{$f}{layers} || []} ) {
      my $ll = my $l = $self->{faces}{$f}{layers}[$ln];
      next if $self->{layers}{$l};		# Else, auto-vivify
#warn "Creating layer `$l' for face `$f'...";
      ($ll = $self->{layer_recipes}{$ll}) =~ s/^\s+// if exists $self->{layer_recipes}{$ll};
#warn "... Using recipe `$ll'";
      $ll = $self->make_translated_layers($ll, $f, [$ln], '0000');
#warn "... Result `@$ll' --> $self->{layers}{$ll->[0]}";
      $self->{layers}{$l} = $self->{layers}{$ll->[0]} unless $self->{layers}{$l};		# Could autovivify in between???
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
      push @{ $self->{faces}{$f}{'[AltSubstitutions]'}{$s[0]} }, $s[1];
      push @{ $self->{faces}{$f}{'[AltSubstitutions]'}{lc $s[0]} }, lc $s[1]
        if lc $s[0] ne $s[0] and lc $s[1] ne $s[1];
      push @{ $self->{faces}{$f}{'[AltSubstitutions]'}{uc $s[0]} }, uc $s[1]
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
            push @{ $self->{faces}{$f}{'[AltSubstitutions]'}{$s} }, $ss;
          }
        }
      }
    }  
  }		# This is not used yet???
  for my $f (keys %{$self->{faces}}) {	# Needed for face_make_backlinks: must know which keys in faces will be finally present
    next if 'HASH' ne ref $self->{faces}{$f} or $f =~ m(\bVK$);			# "parent" taking keys for a child
    for my $N (0..$#{ $self->{faces}{$f}{AltGrCharSubstitutionLayers} || []}) {	# Now has a chance to have real layers
      my $to = $self->{faces}{$f}{AltGrCharSubstitutionLayers}[$N];
      my $from  = $self->{faces}{$f}{layers}[$N] or next;
      $_ = $self->{layers}{$_} for $from, $to;
      for my $k (0..$#$from) {
        next unless $from->[$k] and $to->[$k];
        for my $shift (0..1) {
          next unless defined (my $s = $from->[$k][$shift]) and defined (my $ss = $to->[$k][$shift]);
          push @{ $self->{faces}{$f}{'[AltSubstitutions]'}{$s} }, $ss;
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
    my ($DDD, $export)	= map $self->{faces}{$f}{"[$_]"} ||= {}, qw(DEAD export);
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
    for my $k (split /\p{Blank}+(?:\|{3}\p{Blank}+)?/, (defined $self->{faces}{$f}{faceDeadKeys} ? $self->{faces}{$f}{faceDeadKeys} : '')) {
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
            $k = [$k, $f, ($export->{$k} ? () : 1)] if defined $k and $DDD->{$k};
          }
        }
      }
      $self->{faces}{$f}{'[ini_layers_prefix]'} = \@out;
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
  printf "%s%s\t<%s>\t%s\n", $prefix, $self->key2hex($k), $K, $self->UName($k, 'verbose');  
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
  print "############# Generated with UI::KeyboardLayout v$UI::KeyboardLayout::VERSION for $file, face=$F\n#\n";

  my $is32 = $self->{faces}{$F}{'[32-bit]'};
  my $cnt32 = keys %{$is32 || {}};
  my $c1 = @{ $self->{faces}{$F}{'[coverage1]'} } - $cnt32;
  my $more = $cnt32 ? " (and $cnt32 not available on Windows - at end of this section above FFFF)" : '';
  printf "############# %i = %i + %i%s [direct + single prefix keys]\n", 
    @{ $self->{faces}{$F}{'[coverage0]'} } + $c1,
    scalar @{ $self->{faces}{$F}{'[coverage0]'} },
    $c1, $more;
  for my $k (@{ $self->{faces}{$F}{'[coverage0]'} }) {
    $self->print_codepoint($k);
  }
  print "############# Via (single) prefix keys:\n";
  for my $k (@{ $self->{faces}{$F}{'[coverage1]'} }) {
    $self->print_codepoint($k);
  }
  print "############# In prefix keys, but available only elsewhere:\n";
  for my $k (sort keys %{ $self->{faces}{$F}{'[in_dia_chains]'} }) {
    next unless $self->{faces}{$F}{'[coverage_hash]'}{$k} and not $self->{faces}{$F}{'[from_dia_chains]'}{$k};
    $self->print_codepoint($k, '+ ');		# May be in from_dia_chains, but be obscured later...
  }
  print "############# Lost in prefix keys (not counting those explicitly prohibited by \\\\):\n";
  for my $k (sort keys %{ $self->{faces}{$F}{'[in_dia_chains]'} }) {
    next if $self->{faces}{$F}{'[coverage_hash]'}{$k};
    $self->print_codepoint($k, '- ');
  }
  print "############# Lost in known classified modifiers/standalone/combining:\n";
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
sub print_table_coverage ($$;$) {
  my ($self, $F, $html) = (shift, shift, shift);
  my $f = $self->{'[file]'};
  $f = (defined $f) ? "file $f" : 'string descriptor';
  my $v = $self->{VERSION};
  $f .= " version $v" if defined $v;
  print <<EOP if $html;
<html>
<head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
<!-- Generated with UI::KeyboardLayout v$UI::KeyboardLayout::VERSION for $f, face=$F -->
<style type="text/css"><!--
  /* <!-- Font size 10pt OK with Landscape Letter PaperSize, 0.1in margins, no footer, %96 for Latin, %150 for Cyrillic of izKeys --> */
  table.coverage	{ font-size: 10pt; font-family: DejaVu Sans; }
  span.dead		{ font-size: 50%; color: red; }
  span.operator		{ background-color: pink; }
  span.relation		{ background-color: lightsalmon; }
  span.ipa		{ background-color: greenyellow; }
  span.nAry		{ background-color: lightgreen; }
  span.paleo		{ background-color: Khaki; }
  span.viet		{ background-color: Gainsboro; }
  span.doubleaccent	{ background-color: Bisque; }
  span.ZW		{ background-color: crimson; }
  span.WS		{ background-color: maroon; }
  span.lFILL		{ margin: 0ex 0.35ex; }
  span.l		{ margin: 0ex 0.06ex; }
  span.yyy		{ padding: 0px !important; }
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
  my($LL, $INV, %s, @d, %access) = ($self->{faces}{$F}{layers}, $self->{faces}{$F}{Flip_AltGr_Key});
  $s{$self->charhex2key($INV)}++ if defined $INV;	# Skip in reports	'
  my @LL = map $self->{layers}{$_}, @$LL;
  $s{$_}++ or push @d, $_ for map @{ $self->{faces}{$F}{"[$_]"} || [] }, qw(dead_array dead_in_VK_array);
  my (@A, %isD2, @Dface) = [];
#warn 'prefix keys to report: <', join('> <', @d), '>';
  for my $dK (@d) {
    my $c = $self->key2hex($dK);
    next unless defined (my $FF = $self->{faces}{$F}{'[deadkeyFace]'}{$c});
    $access{$FF} = [$self->charhex2key($dK)];
    push @Dface, $FF;
    push @A, [$self->charhex2key($dK)];
  }

  my ($lastDface, $prevCol, $COLS, @colOrn, %S, @joinedPairs) = ($#Dface, -1, '', [qw(0 column1)]);
  for my $kk (split /\p{Blank}+\|{3}\p{Blank}+/, (defined $self->{faces}{$F}{faceDeadKeys} ? $self->{faces}{$F}{faceDeadKeys} : ''), -1) {
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
      defined (my $ddd = $self->{faces}{$F}{'[deadkeyFace]'}{$Dead2}) or die "Can't find prefix key face for `$D[1]' -> `$Dead2' in `$F'+prefix `$D[0]'";
      next if $S{"@D"}++;
      push @Dface, $ddd if $reported;
      $access{$ddd} = \@D;
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
  my ($k, @last_in_row) = -1;
  $last_in_row[ $k += $_ ]++ for @{ $self->{faces}{$F}{'[geometry]'} || [] };
#warn 'prefix key faces to report: <', join('> <', @Dface), '>';
  my @maps = (undef, map $_ && $self->linked_faces_2_hex_map($F, $_), @Dface);	# element of Dface may be false if this is non-autonamed AltGr-inverted face
  my $dead = $html ? "<span class=dead title='what follows is a prefix key; find the corresponding column'>\x{2620}</span>" : "\x{2620}";
  my $header = '';
  for my $dFace ('', @Dface) {		# '' is no-dead
    $header .= "    <td align=center class=headerbase title=' '>↓Base Prefix→</td>", next unless $dFace;
    my @a = map {(my $a = $_) =~ s/^(?=$rxCombining)/\x{25cc}/o; $a } @{ $access{$dFace} };
    $header .= "    <td align=center class=header>@a</td>";
  }
  print "  <thead><tr class=headerRow title='Prefix key (or key sequence) accessing this column; in the table below, ☠ is put before the corresponding keypresses'>$header</tr></thead>\n  <tbody>\n"
    if $html;
  my %special = qw( \r Enter \n Control-Enter \b BackSpace \x7f Control-Backspace \t Tab 
  		    \x1b Control-[ \x1c Control-] \x1d Control-\ \x03 Control-Break );
  for my $n ( 0 .. $#{ $LL[0] } ) {
    my $out = '';
    my @baseK;
    for my $dn (0..@Dface) {		# 0 is no-dead
      next if $dn and not $maps[$dn];
      $out .= $html ? '</td><td>' : "\t" if length $out;
      my $is_D2 = $isD2{ @{$A[$dn]} == 1 ? $A[$dn][0] : 'n/a' };		
# warn "is_D2: ", $self->array2string([$dn, $is_D2, $A[$dn], $A[$dn][0]]);
      my $o = '';
      for my $L (0..$#$LL) {
        for my $shift (0..1) {
          my $pre = '';
          my $c = $LL[$L][$n][$shift];
          $o .= ' ', next unless defined $c;
          $pre = $dead, $c = $c->[0] if 'ARRAY' eq ref $c;
          if ($dn) {
            $c = $maps[$dn]{$self->key2hex($c)};
            $c = '♫' unless defined $c;				# Should not appear...
            $pre = $dead, $c = $c->[0] if 'ARRAY' eq ref $c;
            $c = $self->charhex2key($c);
          } else {
            $pre = $dead if $self->{faces}{$F}{'[coverage0_prefix]'}{$c};
          }
	  my $cc = $c;
	  $baseK[$L][$shift] = $c unless $dn;
	  $pre ||= $dead if $dn and $is_D2->{$baseK[$L][$shift]};
# warn "... is_D2: ", $self->array2string([$c, $baseK[$L][$shift]]);
          $c =~ s/(?=$rxCombining)/\x{25cc}/go;	# dotted circle ◌ 25CC
          $c =~ s/([&<>])/$html_esc{$1}/g if $html;
	  my $type = ($cc =~ /[^\P{Blank}\x00-\x1f]/ && 'WS');		# Blank and not control char
	  my ($fill, $prefill) = ((($type or $c =~ /(\p{Line_Break: ZW}|\xAD)$/) and '<span class=lFILL></span>'), '');	# Soft hyphen
	  if ($type) {				# Putting WS inside l makes gaps between adjacent WS blocks
	    $prefill = '<span class=WS>';
	    $fill .= '</span>';
	  }
	  $c =~ s{(.*(.))}{ 
	  	  my $title = ((ord $2 >= 0x80 or $cc eq ' ') && sprintf ' title="%04X  %s"', ord $2, $self->UName("$2", 'verbose'));
	  	  "<span class=l$title>$prefill$1$fill</span>" }ge if $html;
	  if ($type or not $html) {					# Do nothing if not HTML
	    undef $type 
	  } elsif ($fill) {
	    $type = 'ZW';
	  } elsif ($c =~ /(\bN-ARY|"\w+\s+(?:BIG|LARGE))\b.*\s+\[/) {	# "0134	BIG GUY#"
	    $type = 'nAry';
	  } elsif ($c =~ /\b(OPERATOR|SIGN|SYMBOL|PROOF|EXISTS|FOR\s+ALL|(DIVISION|LOGICAL)\b.*)\s+\[/) {
	    $type = 'operator';
	  } elsif ($c =~ /\b(RELATION|PERPENDICULAR|PARALLEL\s*TO|DIVIDES|FRACTION\s+SLASH)\s+\[/) { 
	    $type = 'relation';
	  } elsif ($c =~ /\[.*\b(IPA)\b|\bCLICK\b/) { 
	    $type = 'ipa';
	  } elsif ($c =~ /\bLETTER\s+[AEUIYO]\b/ and 
	  	   $c =~ /\b(WITH|AND)\s+(HOOK\s+ABOVE|HORN)|(\s+(WITH|AND)\s+(CIRCUMFLEX|BREVE|ACUTE|GRAVE|TILDE|DOT\s+BELOW)\b){2}/) { 
	    $type = 'viet';
	  } elsif (0 <= index(lc '⁊ǷꝥƕǶᵹ', lc $cc) or 0xa730 <= ord $cc and 0xa78b > ord $cc or 0xa7fb <= ord $cc and 0xa7ff >= ord $cc) { 
	    $type = 'paleo';
	  } elsif ($c =~ /(\s+(WITH|AND)\s+((DOUBLE\s+)?\w+(\s+(BELOW|ABOVE))?)\b){2}/) { 
	    $type = 'doubleaccent';
	  }
	  $c = "<span class=$type>$c</span>" if $html and $type;
          $c = "$pre$c";
          $c =~ s{([\x00-\x1F\x7F])}{ my $C = $self->control2prt("$1"); my $S = $special{$C};
          			      $C = "<span class=yyy title='$S'>$C</span>" if $html and $S; $C }ge;
          $o .= $c;
        }
      }
      $out .= $o;
    }
    my $class = $last_in_row[$n] ? ' class=lastKeyInKRow' : '';
    $out = "    <tr$class><td>$out</td></tr>" if $html;
    print "$out\n";
  }
  my @extra = map {(my $s = $_) =~ s/^\s+//; "\n\n<p>$s"} @{ $self->{faces}{$F}{TableSummaryAddHTML} || [] };
  print <<EOP if $html;
  </tbody>
</table>

@extra<p>Highlights (homographs and special needs): zero-width or SOFT HYPHEN: <span class=ZW><span class=l title="ANY ZEROWIDTH CHAR"><span class=lFILL></span></span></span>, whitespace: <span class=WS><span class=l title="ANY SPACE CHAR"> <span class=lFILL></span></span></span>, <span class=viet>Vietnamese</span>; <span class=doubleaccent>other double-accent</span>; <span class=paleo>paleo-Latin</span>; 
or <span class=ipa>IPA</span>.
Or name having <span class=relation>RELATION, PERPENDICULAR,
PARALLEL, DIVIDES, FRACTION SLASH</span>; or <span class=nAry>BIG, LARGE, N-ARY</span>; or <span class=operator>OPERATOR, SIGN, 
SYMBOL, PROOF, EXISTS, FOR ALL, DIVISION, LOGICAL</span>.
(Some browsers fail to show highlights for whitespace/zero-width.)
<p>Vertical lines separate: the column of the base face, paired 
prefix keys with "inverted bindings", and explicitly selected multi-key prefixes.  Horizontal lines separate key rows of
the keyboard (including a fake row with the "left extra key" [one with &lt;&gt; or \\| - it is missing on many keyboards]
and the KP_Decimal key [often marked as . Del on numeric keypad]); the last group is for semi-fake keys for
Enter/C-Enter/Tab/Backspace/C-Backspace and C-[/]/\\/Break (make sense after prefix keys) and special keys explicitly added
in .kbdd files (usually SPACE).
<p>Hover mouse over specific elements to get more information.
</body>
</html>
EOP
}

sub coverage_face0 ($$) {
  my ($self, $F) = (shift, shift);
  my $LL = $self->{faces}{$F}{layers};
  return $self->{faces}{$F}{'[coverage0]'} if exists $self->{faces}{$F}{'[coverage0]'};
  my (%seen, %seen_prefix, %imported);
  my $d = { %{ $self->{faces}{$F}{'[DEAD]'} || {} }, %{ $self->{faces}{$F}{'[dead_in_VK]'} || {} } };
  for my $l (@$LL) {
    my $L = $self->{layers}{$l};
    for my $k (@$L) {
      $seen{$_}++        		   for grep {defined and !ref and !$d->{$_}} @$k;
      $seen_prefix{ref() ? $_->[0] : $_}++ for grep {defined and (ref or $d->{$_})} @$k;
      $imported{"$_->[0]:$_->[1]"}++	   for grep {defined and ref and !$_->[2]} @$k;
    }
  }
  $self->{faces}{$F}{'[coverage0_prefix]'} = \%seen_prefix;
  $self->{faces}{$F}{'[coverage0]'} = [sort keys %seen];
  $self->{faces}{$F}{'[imported]'} = [sort keys %imported];
}

sub massage_imported ($$) {
  my ($self, $f, $K) = (shift, shift);
  return unless my ($F, $KKK) = $f =~ /^(.*)###([a-f0-9]{4,})$/is;
  my $H = $self->{faces}{$F};
  for my $i ( @{ $self->{faces}{$f}{'[imported]'} || [] } ) {
    my($k,$face) = $i =~ /^(.):(.*)/s or die "Unrecognized imported: `$i'";
    if (exists $H->{'[imported2key]'}{$i} or exists $H->{'[imported2key_auto]'}{$i}) {
      $K = exists $H->{'[imported2key]'}{$i} ? $H->{'[imported2key]'}{$i} : $H->{'[imported2key_auto]'}{$i};
    } elsif ($H->{'[coverage0_prefix]'}{$k} or $H->{'[auto_dead]'}{$k}) {
      # Assign a fake prefix key to imported map
      warn("Imported prefix keys exist, but Auto_Diacritic_Start is not defined in face `$F'"), return 
        unless defined $H->{'[first_auto_dead]'};
      $K = $H->{'[imported2key_auto]'}{$i} = $self->next_auto_dead($H);
    } else {		# preserve the prefix key
      $K = $H->{'[imported2key_auto]'}{$i} = $k;
      $H->{'[auto_dead]'}{$k}++;
    }
    my $LL = $self->{faces}{$face}{'[deadkeyLayer]'}{$self->key2hex($k)}
      or die "Cannot import a deadkey `$k' from `$face'";
    $LL = [@$LL];		# So may override
    my $KK = $self->key2hex($K);
    if (my $over = $H->{'[AdddeadkeyLayer]'}{$KK}) {
#warn "face `$F': additional bindings for deadkey $KK exist.\n";
      $LL = [$self->make_translated_layers_stack($over, $LL)];
    }
    $H->{'[imported2key_all]'}{"$k:$face"} = $KK;
    $H->{'[deadkeyLayer]'}{$KK} = $LL;
    my $new_facename = "$F#\@#\@#\@$i";
    $self->{faces}{$new_facename}{layers} = $LL;
    $H->{'[deadkeyFace]'}{$KK} = $new_facename;
    $self->link_layers($F, $new_facename, 'skipfix', 'no-slot-warn', $self->default_char($F));

    $self->coverage_face0($new_facename);
  }
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
    
    $data->massage_deadkeys_win($data);
    $data->create_composite_layers;		# Needs to be after simple deadkey maps are known

    for my $F (keys %{ $data->{faces} }) {
      next if 'HASH' ne ref $data->{faces}{$F} or $F =~ /\bVK$/;			# "parent" taking keys for a child
      $data->coverage_face0($F);		# creates coverage0,imported array (c0 excludes diacritics), coverage0_prefix hash
    }
    for my $F (keys %{ $data->{faces} }) {
      next if 'HASH' ne ref $data->{faces}{$F} or $F =~ /\bVK$/;			# "parent" taking keys for a child
      $data->massage_imported($F);		# creates coverage0,imported array (c0 excludes diacritics), coverage0_prefix hash
    }
    $data->create_inverted_faces;

    for my $F (keys %{ $data->{faces} }) {
      next if 'HASH' ne ref $data->{faces}{$F} or $F =~ /\bVK$/;			# "parent" taking keys for a child
      next if $F =~ /#\@?#\@?(Inv)?#\@?/;		# Face-on-a-deadkey
      my($seen_prefix, %seen0, %seen1) = $data->{faces}{$F}{'[coverage0_prefix]'};
      warn("Face `$F' has no [deadkeyFace]"), next unless $data->{faces}{$F}{'[deadkeyFace]'};
#      next;
      for my $deadKEY ( sort keys %{ $data->{faces}{$F}{'[deadkeyFace]'}} ) {
        unless (%seen0) {				# Do not calculate if $F has no deadkeys...
          $seen0{$_}++ for @{ $data->{faces}{$F}{'[coverage0]'} };
        }
        ### XXXXX Directly linked faces may have some chars unreachable via the switch-prefixKey
        my $deadKey = $data->charhex2key($deadKEY);
        # It does not make sense to not include it into the summary: 0483 on US is such...
        warn("Prefix key `$deadKey' not reached (without other prefix keys?) in face `$F'")
          unless $seen_prefix->{$deadKey};
        my $FFF = $data->{faces}{$F}{'[deadkeyFace]'}{$deadKEY};
        my $cov2 = $data->{faces}{$FFF}{'[coverage0]'} 
          or warn("Deadkey `$deadKey' on face `$F' -> unmassaged face"), next;
        ref or $seen0{$_}++ or $seen1{$_}++ for @$cov2;		# Skip inherited deadkeys
      }
      $data->{faces}{$F}{'[coverage1]'} = [sort keys %seen1];
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

my %oem_keys = reverse (qw(
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
));			#'# Here # marks keys which need special attention...

	# For type 4 of keyboard (same as types 1,3)
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
  53	DELETE
  54	SNAPSHOT
  56	OEM_102
  57	F11
  58	F12
  59	CLEAR
  5A	OEM_WSCTRL
  5B	OEM_FINISH
  5C	OEM_JUMP
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
  71	OEM_RESET
  73	ABNT_C1
  76	F24
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

sub get_VK ($$) {
  my ($self, $f) = (shift, shift);
  $self->get_deep_via_parents($self, undef, 'faces', (split m(/), $f), 'VK') || {}
#  $self->{faces}{$f}{VK} || {}
}

sub massage_VK ($$) {
  my ($self, $f, %seen, %seen_dead, @dead) = (shift, shift);
  my $l0 = $self->{faces}{$f}{layers}[0];
  $self->{faces}{$f}{'[non_VK]'} = @{ $self->{layers}{$l0} };
  my @extra = map [[],[],[],[],[]], 0..$#{ $self->{faces}{$f}{layers} };
  $extra[0] = [["\r","\n"],["\b","\x7F"],["\t","\x1b"],["\x1c","\x1d"],["\cC"]];	# Enter, C-Enter, Bsp, C-Bsp, Tab, Esc, Cancel
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
  my ($self, $k, $dead_keys, $used) = (shift, shift, shift, shift);
  return -1 unless defined $k;
  my $mod = ($dead_keys->{$k} ? '@' : '') and $used->{$k}++;
  return "$k$mod" if $k =~ /^[A-Z0-9]$/i;
  $self->key2hex($k) . $mod;
}

sub auto_capslock($$) {
  my ($self, $u) = (shift, shift);
  my %fix = qw( ӏ Ӏ );		# Perl 5.8.8 uc is wrong
  return 1 if defined $u->[0] and defined $u->[1] and $u->[0] ne $u->[1] and ($fix{$u->[0]} || uc($u->[0])) eq $u->[1];
  return 0;
}

{ my %seen;
  sub reset_units ($) { %seen = () }

  sub output_unit0 ($$$$$;$) {
    my ($self, $k, $u, $deadkeys, $Used, $known_dead) = (shift, shift, shift, shift, shift, shift);  
    my $sc = ($known_dead or $scan_codes{$k}) or warn("Can't find the scancode for the key `$k'"), return;
    my $cntrl;	# Set Control-KEY if is [ or ] or \
  #  $cntrl = $u->[0][0] if $u->[0][0] =~ /^[\\\[\]]$/;	# $do_control{$u->[0][0]} if $do_control{$u->[0][0]};
    $cntrl = chr hex $do_control{$u->[0][0]} if $do_control{$u->[0][0]};
    $deadkeys ||= [];
    my @K = map $self->format_key($u->[$_->[0]][$_->[1]], ($known_dead ? $deadkeys->[$_->[0]][$_->[1]] : $deadkeys->[$_->[0]]), $Used->[$_->[0]]), 
      [0,0],[0,1], [1,0],[1,1];
    my $keys = join "\t", @K[0,1], $self->format_key($cntrl, undef, {}), @K[2,3];
    my $fill = ((8 <= length $k) ? '' : "\t");
    my $expl = join ", ", map +((defined $_) ? $_ : ' '), 
                  $u->[0][0], $u->[0][1], $cntrl, $u->[1][0], $u->[1][1];
    my $expl1 = exists $self->{UNames} ? "\t// " . join ", ", map +((defined $_) ? $self->UName($_) : ' '), 
                  $u->[0][0], $u->[0][1], $cntrl, $u->[1][0], $u->[1][1] : '';
    my $capslock = ($self->auto_capslock($u->[0])) | (($self->auto_capslock($u->[1])) << 2);
    <<EOP;
$sc\t$k$fill\t$capslock\t$keys\t// $expl$expl1
EOP
  }
  
  sub output_unit ($$$$$$) {
    my ($self, $layers, $basesub, $u, $deadkeys, $Used) = (shift, shift, shift, shift, shift, shift);  
    my $c = $self->{layers}{$basesub}[$u][0];
    my $k = uc $c;
    $c .= '#' if $seen{$c}++;
    $k = $oem_keys{$c} or warn("Can't find a key with character `$k'"), return
      unless $k =~ /^[A-Z0-9]$/;
    $u = [map $self->{layers}{$_}[$u], @$layers];
    $self->output_unit0($k, $u, $deadkeys, $Used);
  }
}

sub output_layout_win ($$$$$$) {
  my ($self, $layers, $basesub, $deadkeys, $Used, $cnt) = (shift, shift, shift, shift, shift, shift);
  $basesub = $layers->[0] unless defined $basesub;
  $self->reset_units;
  die "Count of non-VK entries mismatched: $cnt vs ", scalar @{$self->{layers}{$layers->[0]}}
    unless $cnt <= scalar @{$self->{layers}{$layers->[0]}};
  map $self->output_unit($layers, $basesub, $_, $deadkeys, $Used),
    0..$cnt-1;
}

sub output_VK_win ($$$) {
  my ($self, $face, $Used, @O) = (shift, shift, shift);
  my $VK = $self->get_VK($face);
  for my $k (keys %$VK) {
    my $v = $VK->{$k};
# warn 'Key: <', join('> <', @$v), '>';
    my (@dead) = map +(/^(.+)\@$/ ? [$1, {$1 => 1}] : [$_]), @$v[1..$#$v];
    my (@k, @o, @oo, $x, $y) = map $_->[0], @dead;
    @dead = map $_->[1], @dead;
    push @o,  [$x, $y] while @dead and ($x, $y) = splice @dead, 0, 2;
    push @oo, [$x, $y] while @k    and ($x, $y) = splice @k,    0, 2;
    push @O, $self->output_unit0($k, \@oo, \@o, $Used, $v->[0]);
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
     warn "no KEYNAME_DEAD section found"
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

0	//Column 4
1	//Column 5 : Shft
2	//Column 6 :       Ctrl
6	//Column 7 :       Ctrl Alt
7	//Column 8 : Shft  Ctrl Alt

LAYOUT		;an extra '@' at the end is a dead key

//SC	VK_		Cap	0	1	2	6	7
//--	----		----	----	----	----	----	----
LAYOUT_KEYS

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
sub filter_hex_map ($$$$$$) {				# XXXX Not used???
  my ($self, $map, $L, $name, $b, $d) = (shift, shift, shift, shift, shift, shift);
  ($map, my $mapname) = @$map{ qw(map name) };
#  my @MAP = %$map;
# warn "filtering hex map `$mapname'=`$d' for face `$name': @MAP";
  $self->link_layers($name, $b, 'skip-fix', 'no-slot-warn')
    if $self->{faces}{$b} != $L;
  my $remap = $L->{AltGr_SPACE_mapPlain}{$b};
  die "Face `$b' not linked to face `$name'" 
    if $self->{faces}{$b} != $L and not $remap;
  my $cover = $L->{'[coverage_hex]'} or die "Face $name not preprocessed";
  $remap ||= {map +(chr hex $_, [chr hex $_]), keys %$cover};		# This one in terms of chars, not hex
  my $Map = { map +(chr hex $_, chr hex $map->{$_}), keys %$map};
  my @k = grep { exists $Map->{$remap->{$_}[0]} } keys %$remap;
  return { map +($self->key2hex($_), $self->key2hex($Map->{$remap->{$_}[0]})), @k }
}

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
  my $remap = $L->{$inv ? 'AltGr_SPACE_map_INV' : 'AltGr_SPACE_map'}{$b};
  die "Face `$b' not linked to face `$name'; HAVE: <", join('> <', keys %{$L->{AltGr_SPACE_map}}), '>'
    if $self->{faces}{$b} != $L and not $remap;
  my $cover = $L->{'[coverage_hex]'} or die "Face $name not preprocessed";
# warn "Keys of the Map `$name' -> '$b': <", join('> <',  keys %$remap), '>';
  $remap ||= {map +(chr hex $_, chr hex $remap->{$_}), keys %$cover};		# This one in terms of chars, not hex
  my @k = keys %$remap;
# warn "Map `$name' -> '$b': <", join('> <', map +($self->key2hex($_), $self->key2hex($remap->{$_})), @k), '>';
  return { map +($self->key2hex($_), $self->KEY2hex($remap->{$_})), @k }
}

my $dead_descr;
#my %control = split / /, "\n \\n \r \\r \t \\t \b \\b \cC \\x03 \x7f \\x7f \x1b \\x1b \x1c \\x1c \x1d \\x1d";
my %control = split / /, "\n \\n \r \\r \t \\t \b \\b";
sub control2prt ($$) {
  my($self, $c) = (shift, shift);
  return $c unless ord $c < 0x20 or ord $c == 0x7f;
  $control{$c} or sprintf '\\x%02x', ord $c;
}
sub print_deadkey_win ($$$$$$) {
  my ($self, $nameF, $d, $dead2, $flip_AltGr_hex, $altGr_key_hex) = (shift, shift, shift, shift, shift, shift);
#warn "emit `$nameF' d=`$d'";
  my $H = $self->{faces}{$nameF};
  my $b = $H->{'[deadkeyFace]'}{$d};
  my $b1 = $altGr_key_hex && $H->{'[deadkeyFaceInvFace]'}{$self->charhex2key($altGr_key_hex)};
#warn "See dead2 in <$nameF> for <$d>" if $dead2;
  my $Dead2 = $dead2;
  $dead2 = ($dead2 || {})->{$self->charhex2key($d)} || {};
  my(@sp, %sp) = map {(my $in = $_) =~ s/(?<=.)\@$//s; $in} @{ ($self->get_VK($nameF))->{SPACE} || [] };
  @sp = map $self->charhex2key($_), @sp;
  @sp{@sp[1..$#sp]} = (0..$#sp);		# The leading elt is the scancode
  my @maps = map $self->linked_faces_2_hex_map($nameF, $_), $b, ($b1 ? $b1 : ());	# Invert AltGr???
  my($D, @DD) = ($d, $d, $altGr_key_hex);
  my ($OUT, $keys) = '';
  # There are 3 situations:
  # 0) process one map without AltGr-inversion; 1) Process one map which is the AltGr-inversion of the principal one;
  # 2) process one map with AltGr-inversion (in 1-2 the inversion may have a customization put over it).
  # The problem is to recognize when deadkeys in the inversion come from non-inverted one, or from customization
  # And, in case (1), we must consider flip_AltGr specially...
  my($is_invAltGr, $AMap, $default) = ($D eq ($flip_AltGr_hex || 'n/a') and $H->{'[dead2_AltGr_chain]'}{''});
  if ($#maps or $is_invAltGr) {
    $self->faces_link_via_backlinks($nameF, $nameF, undef, 'no_ini');		# Create AltGr-invert self-mapping
    $AMap = $self->linked_faces_2_hex_map($nameF, $nameF, 1);
    $default = $self->default_char($nameF);
    $default = $self->key2hex($default) if defined $default;
#warn "default=$default deadkey=$D flip=$flip_AltGr_hex" if defined $default;;
  }
  my($ini_dead2, $map_AltGr_over, $over_dead2) = ($dead2, {}, {});
  if (my $override_InvAltGr = $H->{"[InvAltGrFace]"}{$is_invAltGr ? '' : $d}) {
    $map_AltGr_over = $self->linked_faces_2_hex_map($nameF, $override_InvAltGr);
    my $inverted_key = $is_invAltGr ? $flip_AltGr_hex : $altGr_key_hex;
    $over_dead2 = $Dead2->{$self->charhex2key($inverted_key)} || {} if defined $inverted_key;	# ?????
  }
  $dead2 = { %{ $H->{'[DEAD]'} }, %{ $H->{'[dead_in_VK]'} } } if $is_invAltGr;
  
# warn "output map for `$D' invert=", !!$is_invAltGr, ' <',join('> <', sort keys %$dead2),'>';
  for my $invertAlt0 (0..$#maps) {
    my $invertAlt = $invertAlt0 || $is_invAltGr;
    my $map = $maps[$invertAlt0];
    $d = $DD[$invertAlt0];
    $OUT .= "DEADKEY\t$d\n\n";
    # Good order: first alphanum, then punctuation, then space
    my @keys = sort keys %$map;			# Not OK for 6-byte keys
    @keys = (grep(( lc(chr hex $_) ne uc(chr hex $_) and not $sp{chr hex $_} ),		      @keys),
             grep(((lc(chr hex $_) eq uc chr hex $_ and (chr hex $_) !~ /\p{Blank}/) and not $sp{chr hex $_}), @keys),
             grep((((lc(chr hex $_) eq uc chr hex $_ and (chr hex $_) =~ /\p{Blank}/) or $sp{chr hex $_}) and $_ ne '0020'), @keys),
             grep(				                    $_ eq '0020',  @keys));
    for my $n (@keys) {	# Not OK for 6-byte keys (impossible on Win): make SPACE last
#      warn "doing $n\n";
      my ($to, $int_dead) = $map->{$n};
      if ('ARRAY' eq ref $to) {
        $int_dead = !$to->[2]; 
        my $i = $self->charhex2key($to->[0]) . ":$to->[1]";
        if (defined (my $j = exists $H->{'[imported2key_auto]'}{$i} ? $H->{'[imported2key_auto]'}{$i} : $H->{'[imported2key]'}{$i})) {
          $to = $self->key2hex($j);
        } else {
          warn "Can't resolve `$to->[0]:$to->[1]' to an imported dead key" if $int_dead;
          $to = $to->[0];
        }
        
      }
      $H->{'[32-bit]'}{chr hex $map->{$n}}++, next if hex $n > 0xFFFF;	# Cannot be put in a map...
      if (hex $to > 0xFFFF) {		# Value cannot be put in a map...
        $H->{'[32-bit]'}{chr hex $map->{$n}}++;
        next unless defined ($to = $H->{DeadChar_32bitTranslation});
        $to =~ s/^\s+//;	$to =~ s/\s+$//;
        $to = $self->key2hex($to);
      }
#      my $alt_n = $invertAlt ? $AMap->{$n} : $n;
      my ($alt_n, $use_dead2) = (($invertAlt and defined $map_AltGr_over->{$n} and (!defined $default or $default ne $map_AltGr_over->{$n})) 
        			 ? ($n, $over_dead2) 
        			 : (($invertAlt ? $AMap->{$n} : $n), $dead2));
#warn "$D --> $d, `$n', `$alt_n', `$AMap->{$n}'; `$map_AltGr_over->{$n}' i=$invertAlt i0=$invertAlt0 d=$use_dead2->{chr hex $alt_n}";
      my $DEAD = ((defined $alt_n and $use_dead2->{chr hex $alt_n}	# Or are we doing a chain of flip_AltGr :
      		   or $invertAlt and $n eq ($flip_AltGr_hex || 'n/a') and $H->{'[dead2_AltGr_chain]'}{$invertAlt0 ? $D : ''})
      		  ? '@' : '');
#warn "AltGr flip: $nameF:$D: $n --> $H->{'[dead2_AltGr_chain]'}{$D}" if $n eq ($flip_AltGr_hex || 'n/a');
      my $from = $self->control2prt(chr hex $n);
      ($DEAD, $to) = ('@', $DD[1])	# Join b1 to b on $flip_AltGr_hex
        if @maps == 2 and defined $default and !$invertAlt and !$DEAD and defined $flip_AltGr_hex 
           and (hex $n) == hex $flip_AltGr_hex and (hex $to) == hex $default;	# Do not overwrite existing binding...  Warn???
      $to = $default if defined $default and (0x7f == hex $to or 0x20 > hex $to) and (0x7f == hex $n or 0x20 > hex $n);
      my $expl = exists $self->{UNames} ? "\t// " . join "\t-> ",		#  map $self->UName($_), 
  #                  chr hex $n, chr hex $map->{$n} : '';
                   $self->UName(chr hex $n), $self->UName(chr hex $to, 1) : '';
      my $to1 = $self->control2prt(chr hex $to);
      warn "Both int_dead and DEAD properties hold for `$from' --> '$to1' via deadkey $d face=$nameF" if $DEAD and $int_dead;
      $DEAD = '@' if $int_dead;
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
  for my $dia (keys %{$self->{Diacritics}}) {
    my @v = map { s/\p{Blank}//g; $_ } @{ $self->{Diacritics}{$dia} };
    $self->{'[map2diac]'}{$_} = $dia for split //, join '', @v;	# XXXX No check for duplicates???
    my @vv = map [ split // ], @v;
    $self->{'[diacritics]'}{$dia} = \@vv;
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
  if ($space->{$c}) {	# SPACE is handled above (we assume it is on index 0...
    # ~ and ^ have only 3 spacing variants; one of them must be on ' ' - and we omit the first 2 of non-principal block...
    return $self->extract_diacritic($dia, $space->{$c}, 'spacing variant', $limits->[0], 'skip2', @$v[0..3]);
  } elsif (0 <= (my $off = index "\r\t\n\x1b\x1d\x1c\b\x7f", $c)) {	# Enter, Tab, C-Enter, C-[, C-], C-\, Bspc, C-Bspc
    # ~ and ^ have only 3 spacing variants; one of them must be on ' '
    return $self->extract_diacritic($dia, $spaces + $off, 'spacing variant', $limits->[0], 'skip2', @$v[0..3]);
  } elsif (!$spaces and $c =~ /^\p{Blank}$/) {	# NBSP, Thin space 2007	-> second/third modifier
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
  if ($N == 1 and $c_noalt and ($c_noalt eq "/" or $c_noalt eq "?")) {
    return $self->extract_diacritic($dia, 1 + ($c_noalt eq "?"), 'combining', $limits->[4], 'skip2', @$v[4..7]);	# 1 for double-prefix
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
  if ($N == 0 and 0 <= (my $ind = index "[{]}'\"", $c)) {
    return $self->extract_diacritic($dia, 2 + $ind, 'combining for symbols', $limits->[7], 'skip2-include0', @$v[7,4..6]);
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
  return $dia if $dia =~ /^\\/;		# Penalization lists
  $dia = $self->charhex2key($dia);
  unless ($dia =~ /^-?(\p{NonspacingMark}|<(?:font=)?[-\w!]+>|[ul]c(first)?)$/) {
    die "`  $dia  ' not a known diacritic" unless my $name = $self->{'[map2diac]'}{$dia};
    my $v = $self->{'[diacritics]'}{$name} or die "A spacing character <$dia> was requested to be treated as a composition one, but we do not know translation";
    die "Panic!" unless defined ($dia = $v->[4][0]);
  }
  if ($dia =~ /^(-)?<(reverse-)?any(1)?-(other-)?\b([-\w]+?)\b((?:-![-\w]+\b)*)>$/) {
    my($neg, $rev, $one, $other, $match, $rx, $except, @except) 
      = ($1||'', $2, $3, $4, $5, "(?<!<)\\b$5\\b", qr((?!)), split /-!/, $6);
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

#use Dumpvalue;
my %translators = ( Id => sub ($) {shift},   Empty => sub ($) { return undef },
		    lc =>  sub ($) {defined (my $c = shift) or return undef; $c = $c->[0] if 'ARRAY' eq ref $c; lc $c},
		    uc =>  sub ($) {defined (my $c = shift) or return undef; $c = $c->[0] if 'ARRAY' eq ref $c; uc $c});
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
    return sub { my $c=shift; return $c unless defined $c; $c = $c->[0] if 'ARRAY' eq ref $c; $c = $fromKBDD->{$self->key2hex($c)} or return; chr hex $c }, '';
  }
  die "unrecognized Imported argument: `$1'" if $name =~ /^Imported(\[.*)/s;
  return $translators{$name}, '' if $translators{$name};
  if ($name =~ /^Space(Self)?2Id(?:\[(.+)\])?$/) {
    my $dia = $self->charhex2key((defined $2) ? $2 : do {$used_deadkey = "/$deadkey"; $deadkey});	# XXXX `do' is needed, comma does not work
    my $self_OK = $1 ? $dia : 'n/a';
    return sub ($) { my $c = (shift() || '[none]'); $c = $c->[0] if 'ARRAY' eq ref $c;	# Prefix key as usual letter
    		    ($c eq ' ' or $c eq $self_OK) ? $dia : undef }, $used_deadkey;
  }
  if ($name =~ /^ShiftFromTo\[(.+)\]$/) {
    my ($f,$t) = split /,/, "$1";
    $_ = hex $self->key2hex($_) for $f, $t;
    $t -= $f;					# Treat prefix keys as usual keys:
    return sub ($) { my $c=shift; return $c unless defined $c; $c = $c->[0] if 'ARRAY' eq ref $c; chr($t + ord $c) }, '';
  }
  if ($name =~ /^SelectRX\[(.+)\]$/) {
    my ($rx) = qr/$1/;				# Treat prefix keys as usual keys:
    return sub ($) { my $c=shift; defined $c or return $c; $c = $c->[0] if 'ARRAY' eq ref $c; return undef unless $c =~ $rx; $c }, '';
  }
  if ($name =~ /^FlipShift$/) {
    return sub ($) { my $c = shift; defined $c or return $c; map [@$_[1,0]], @$c }, '', 'all_layers';
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
      if ($flip) {
        $h{defined($kk = $f->[$k][$_]) ? $kk : ''} = $t->[$k][1-$_] for 0,1;
      } else {
        $h{defined($kk = $f->[$k][$_]) ? $kk : ''} = $t->[$k][$_] for 0,1;
      }# 
    }						# Treat prefix keys as usual keys:
    return sub ($) { my $c = shift; defined $c or return $c; $c = $c->[0] if 'ARRAY' eq ref $c; $h{$c} }, $B;
  }
  if ($name =~ /^InheritPrefixKeys\[(.+)\]$/) {
    my $base = $1;
    exists $self->{layers}{$_} or $_= ($self->make_translated_layers($_, $face, [$N], $deadkey))->[0]
      for $base;
    $base = $self->{layers}{my $B = $base};
    my (%h);
    for my $k (0..$#$base) {
      for my $shift (0..1) {
        my $C = $base->[$k][$shift] or next;
        next unless ref $C;
        my $c = $C->[0];
        $h{"$N $k $shift $C->[0]"} = $C;
      }						# Treat prefix keys as usual keys:
    }						# Treat prefix keys as usual keys:
    return sub ($) { my $c = shift; defined $c or return $c; return $c if ref $c; $h{"@_ $c"} or $c }, $B;
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
    return sub ($$$$) { (undef, my ($L, $k, $shift)) = @_; return undef if $L or $shift or $k >= $tot; return $chars[$c{$k}] }, '';
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
  if ($name =~ /^(De)?(?:Diacritic|Mutate)(SpaceOK)?(Hack)?(2Self)?(DupsOK)?(32OK)?(?:\[(.+)\])?$/) {
    die "DeDiacritic2Self does not make sense" if my $undo = $1 and $4;
    my ($hack, $spaceOK, $toSelf, $dupsOK, $w32OK) = ($3, $2, $4, $5, $6);
    my $Dia = ((defined $7) ? $7 : do {$used_deadkey ="/$deadkey"; $deadkey});	# XXXX `do' is needed, comma does not work
    my $isPrimary;
    $Dia =~ s/^\+// and $isPrimary++;				# Wait until <NAMED-*> are expanded
    $Dia = $self->charhex2key($Dia);				# Needed for 2Self
    my(@sp, %sp) = map {(my $in = $_) =~ s/(?<=.)\@$//s; $in} @{ ($self->get_VK($face))->{SPACE} || [] };
    @sp = map $self->charhex2key($_), @sp;
    my $flip_AltGr = $self->{faces}{$face}{Flip_AltGr_Key};
    $flip_AltGr = $self->charhex2key($flip_AltGr) if defined $flip_AltGr;
    @sp = grep $flip_AltGr ne $_, @sp if defined $flip_AltGr;			# It has a different function...
    @sp{@sp[1..$#sp]} = (0..$#sp);		# The leading elt is the scancode
#warn "SPACE: <", join('> <', %sp), '>';
#    return sub ($) { $self->diacritic2self($Dia, shift, $face, $N, \%sp) }, $used_deadkey if $4;
    return sub ($) { $self->diacritic2self_2($Dia, shift, $face, \%sp) }, $used_deadkey, 'all_layers' if $toSelf;
#    die "DeDiacritic[...] is not supported yet" if $undo;
    
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
      return ([]) x @$K if not $spaceOK and $base eq ' ';		# Ignore possiblity that SPACE is a deadKey
      my $sorted = $self->sort_compositions(\@groups, $K, $Sub, $dupsOK, $w32OK);
      my ($sorted2, $sorted3, @idx_sorted3);
      $sorted2 = $self->sort_compositions(\@groups2, $K, $Sub, $dupsOK, $w32OK) if @groups2;
      $sorted3 = $self->sort_compositions(\@groups3, $K, $Sub, $dupsOK, $w32OK) if @groups3;
      @idx_sorted3 = @$sorted + (@groups2 ? @$sorted2 : 0) if @groups3;
      $self->{faces}{$face}{'[in_dia_chains]'}{$_}++
        for grep defined, ($hack ? () : $self->flatten_arrays([$sorted, $sorted2 || [], $sorted3 || [] ]));
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
print 'TMP Extracted <', join('> <', map {defined() ? $_ : 'undef'} map @$_, $slots[0]), ">\n" if printSORTEDLISTS;
print 'TMP Extracted <', join('> <', map {defined() ? $_ : 'undef'} map @$_, @slots[1..$#slots]), "> deadKey=$deadkey\n" if printSORTEDLISTS;
        my $appended = $self->append_keys($sorted3 || $sorted2, \@slots, \@LL, !$sorted3 && 'prepend');
Dumpvalue->new()->dumpValue(["Key $base; II", $sorted2]) if printSORTEDLISTS;
	if (warnSORTEDLISTS) {
          $LLL =~ s/^[ |]+//;
          my @KK;
          for my $slot (@slots) {
            push @KK, '<' . join('> <', map {defined() ? $_ : 'undef'} map @$_, $slot) . '>';
          }
          $_++ for @idx_sorted3;
          warn "TMP Extracted: ", join(' | ', @KK), " from layers $LLL\n";	# 1 is for what is prepended by append_keys()
          warn $self->report_sorted_l($base, [@$sorted, @$sorted2, @{$sorted3 || []}],		# Where to put bold/dotted-bold separators:
          			      [scalar @$sorted, !!$appended + $skip + scalar @$sorted, @idx_sorted3], ($appended ? [1 + scalar @$sorted] : ()));
	}
      }
      my(@out, %seen); 
      for my $Ln (0..$#L) {
        $out[$Ln] = $self->shift_pop_compositions($sorted, $Ln);
        $seen{$_}++ for grep defined, @{$out[$Ln]};
      }
      for my $extra (['from end', $sorted2], [0, $sorted3]) {
        next unless $extra->[1];
        $self->deep_undef_by_hash(\%seen, $extra->[1]);
        for my $Ln (0..$#L) {
          my $o = $out[$Ln];
          unless (defined $o->[0] and defined $o->[1]) {
            my $o2 = $self->shift_pop_compositions($extra->[1], $Ln, $extra->[0], !'omit', !'limit', 0, undef, defined $o->[0], defined $o->[1]);
            defined $o->[$_] or $o->[$_] = $o2->[$_] for 0,1;
            $seen{$_}++ for grep defined, @$o;
          }
        }
      }
print 'Extracted ', $self->array2string(\@out), " deadKey=$deadkey\n" if printSORTEDLISTS;
      warn 'Extracted ', $self->array2string(\@out), " deadKey=$deadkey\n" if warnSORTEDLISTS;
      $self->{faces}{$face}{'[from_dia_chains]'}{$_}++
        for grep defined, ($hack ? () : map $self->flatten_arrays($_), @out);
#warn "Age of <à> is <$self->{Age}{à}>";
#warn "Output: <", join('> <', map {defined() ? $_ : '[undef]'} $self->flatten_arrays(\@out)), '>';
      return @out;
    }, $used_deadkey, 'all_layers';
  }
  if ($name =~ /^DefinedTo\[(.+)\]$/) {
    my $to = $self->charhex2key($1);
    return sub ($) { my $c = shift; defined $c or return $c; $to }, '';
  }
  if ($name =~ /^ByPairs\[(.+)\]$/) {
    my ($in, @Pairs, %Map) = $1;
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
        die "Panic! <$Pair>" unless 2 == scalar (my @c = split //, $Pair);
        die qq("From" character <$c[0] duplicated in a ByPairs map <$in>)
          if exists $Map{$c[0]};
        $Map{$c[0]} = $c[1];
      }
    }
    die "Empty ByPairs map <$in>" unless %Map;			# Treat prefix keys as usual keys:
    return sub ($) { my $c = shift; defined $c or return $c; $c = $c->[0] if 'ARRAY' eq ref $c; $Map{$c} }, '';
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
      my $c = shift; defined $c or return $c; $c = $c->[0] if 'ARRAY' eq ref $c; $Map->{$c} 
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
  return $Tr, [map "$used![$_]", @$NN] if $for_layers;
  my @Tr = map [$self->make_translator($name, $deadkey, $face, $_)], @$NN;
  $self->depth2_translator([map $_->[0], @Tr]), [map $_->[1], @Tr];
}

sub make_translated_layers_tr ($$$$$$$) {		# Apply translation map
  my ($self, $layers, $tr, $append, $deadkey, $face, $NN) = (shift, shift, shift, shift, shift, shift, shift);
  my ($Tr, $used) = $self->make_translator_for_layers($tr, $deadkey, $face, $NN);
#warn "  tr=<$tr>, key=<$deadkey>, used=<$used>";
  my @new_names = map "$tr$used->[$_]($layers->[$_])$append" . ($append and $NN->[$_]), 0..$#$NN;
  return @new_names unless grep {not exists $self->{layers}{$_}} @new_names;
# warn "Translating via `$tr' from layer [$layer]: <", join('> <', map "@$_", @{$self->{layers}{$layer}}), '>';
  my (@L, @LL) = map $self->{layers}{$_}, @$layers;
  for my $n (0..$#{$L[0]}) {
    my @C = $Tr->( [ map $L[$_][$n], 0..$#L ], $n );
    push @{$LL[$_]}, $C[$_] for 0..$#L;
  }
  $self->{layers}{$new_names[$_]} = $LL[$_] for 0..$#L;
  @new_names
}

sub make_translated_layers_stack ($$@) {		# Stacking
  my ($self, @out, $ref) = (shift);
  my $c = @{$_[0]};
  @$_ == $c or die "Stacking: number of layers ", scalar(@$_), " != number of layers $c of the first elt"
    for @_;
  for my $l (0..$c-1) {
    my @layers = map $_->[$l], @_;
    push @out, "@layers";
    next if exists $self->{layers}{"@layers"};
    my (@L, @keys) = map $self->{layers}{$_}, @layers;
    for my $l (@L) {
  # warn "... Another layer...";
      for my $k (0..$#$l) {
        for my $kk (0..$#{$l->[$k]}) {
  # warn "...... On $k/$kk: I see `$l->[$k][$kk]'" if defined $l->[$k][$kk];
          $keys[$k][$kk] = $l->[$k][$kk] if defined $l->[$k][$kk] and not defined $keys[$k][$kk];	# Deep copy
        }
        $keys[$k] ||= [];
      }
    }
    $self->{layers}{"@layers"} = \@keys;
  }
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
        $seen[$key]{$_}++ for grep defined, @{ $l->[$key] };
#warn "$key of $last: keys=", join(',',keys %{$seen[$key]});
      }
    }
  }
  my $name = 'NOID([' . join('], [', map "@$_", @_) . '])';
  for my $l (0..$c-1) {
    my (@layers) = map $_->[$l], @_;
    if ($whole) {
      $name .= "'"
    } else {
      $name = "NOID[$refr->[$l]](@layers)"
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
          $keys[$k][$kk] = $ll->[$k][$kk] 	# Deep copy
            if defined $ll->[$k][$kk] and not defined $keys[$k][$kk] 
               and ($whole ? !$seen[$k]{$ll->[$k][$kk]} : $ll->[$k][$kk] ne ( defined $R[$l][$k][$kk] ? $R[$l][$k][$kk] : '' ));
        }
        $keys[$k] ||= [];
      }
    }
    $self->{layers}{$name} = \@keys;
  }
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
  $r =~ s/^\s+//;
#print "face recipe `$face'\n";
  my $LL = $self->{faces}{$base}{layers};
  my $L = $self->{faces}{$face}{layers} = $self->make_translated_layers($r, $base, [0..$#$LL]);
#print "face recipe `$face'  -> ", $self->array2string($L), "\n";
#warn "face recipe `$face'  -> ", $self->array2string($L);
#warn "face recipe `$face' --> ", $self->array2string([map $self->{layers}{$_}, @$L]);
  $L;
}

sub export_layers ($$$) {
  my ($self, $face, $base) = (shift, shift, shift);
  $self->{faces}{$face}{'[ini_layers_prefix]'} || $self->{faces}{$face}{'[ini_layers]'} || $self->{faces}{$face}{layers} 
    || $self->layers_by_face_recipe($face, $base)
}

sub pseudo_layer ($$$$) {
  my ($self, $recipe, $face, $N) = (shift, shift, shift, shift);
  my $l = $self->pseudo_layer0($recipe, $face, $N);
#warn("layer recipe: `$l'"), 
  ($l = $self->{layer_recipes}{$l}) =~ s/^\s+// if exists $self->{layer_recipes}{$l};
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
  return ($1, $2)[$N]			     if $recipe =~ /^Layers\((.*)\+(.*)\)$/;
  my $N1 = $self->flip_layer_N($N, $#{ $self->{faces}{$face}{layers} });
  if ($recipe eq 'FlipLayersLinkFace') {
    my $L = $self->{faces}{$face}{LinkFace} or die "Face `$face' has no LinkFace";
    return ($self->export_layers($L, $face))->[$N1];
  }
#warn "Doing flip/face via `$recipe', N=$N, N1=$N1, face=`$face'";
  return ($self->export_layers($face, $face))->[$N1] if $recipe eq 'FlipLayers';
  return ($self->export_layers("$2", $face))->[$1 ? $N : $N1]
    if $recipe =~ /^(?:(Face)|FlipLayers)\((.*)\)$/;
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
      ($ARG = $self->{layer_recipes}{$ARG}) =~ s/^\s+// if exists $self->{layer_recipes}{$ARG};
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
  return $in unless my $r = $self->get_deep($self, 'faces', (my @p = split m(/), $face), 'Diacritic_if_undef');
  $r =~ s/^\s+//;
#warn "	-> end recipe `$r'";
  my $post = $self->make_translated_layers($r, $face, $NN, $deadkey);
  return [$self->make_translated_layers_stack($in, $post)];
}

sub default_char ($$) {
  my ($self, $F) = (shift, shift);
  my $default = $self->get_deep($self, 'faces', $F, 'DeadChar_DefaultTranslation');
  $default =~ s/^\s+//, $default = $self->charhex2key($default) if defined $default;
  $default;
}

sub create_inverted_face ($$$$$) {
  my ($self, $F, $KK, $chain, $flip_AltGr) = (shift, shift, shift, shift, shift);
  my $H = $self->{faces}{$F};
  my $auto_chr = $H->{'[deadkeyInvFace]'}{$KK};
  my $new_facename = $H->{'[deadkeyFaceInvFace]'}{$auto_chr};
  my $LL = $H->{'[deadkeyLayer]'}{$KK};
  $LL = $H->{layers} if $KK eq '';
  $self->create_inverted_AltGr_face($LL, $new_facename, $H->{"[InvdeadkeyLayer]"}{$KK}, $chain->{$KK and $self->charhex2key($KK)}, $flip_AltGr, $F);

# warn "Joining <$F>, <$new_facename>";
  $self->link_layers($F, $new_facename, 'skipfix', 'no-slot-warn', $self->default_char($F));
  if ($KK eq '' and defined $flip_AltGr) {
    $H->{'[deadkeyFace]'}{$self->key2hex($flip_AltGr)} = $H->{'[deadkeyFaceInvFace]'}{$auto_chr};
  }
  if ($H->{"[InvdeadkeyLayer]"}{$KK}) {		# There are overrides for the inverted face.  Make a map for them...
#warn "Overriding face for inverted `$KK' in face $F; new_facename=$new_facename";
    $H->{'[InvAltGrFace]'}{$KK} = "$new_facename\@override";
    $self->{faces}{"$new_facename\@override"}{layers} = $H->{"[InvdeadkeyLayer]"}{$KK};
    $self->link_layers($F, "$new_facename\@override", 'skipfix', 'no-slot-warn', $self->default_char($F));
  }
  $new_facename;
}

sub next_auto_dead ($$) {
  my ($self, $H, $o) = (shift, shift);
  1 while $H->{'[auto_dead]'}{ $o = $H->{'[first_auto_dead]'}++ }++;
  chr $o;
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
    push(@HH, $self->get_deep($self, @FF)), pop @FF while @FF;
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
      (my $recipe = $HH->{$k}) =~ s/^\s+//;
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
          $H->{"[${inv}deadkeyLayer]"}{$KK}[$layers->[$NN]] = $new->[$NN];
#warn "Face `$face', layer=$layer key=$KK\t=> `$new'" if $H->{layers}[$layer] =~ /00a9/i;
#Dumpvalue->new()->dumpValue($self->{layers}{$new}) if $self->charhex2key($key) eq chr 0x00a9;
        }
      }
    }
    next unless $H->{'[deadkeyLayer]'};		# Are we in a no-nonsense Face-hash with defined deadkeys?
#warn "Face: <", join( '> <', %$H), ">";
    my $layerL = @{ $self->{layers}{ $H->{layers}[0] } };	# number of keys in the face (in the principal layer)
    my $first_auto_dead = $H->{Auto_Diacritic_Start};
    $H->{'[first_auto_dead]'} = ord $self->charhex2key($first_auto_dead) if defined $first_auto_dead;
    for my $KK (sort keys %{$H->{'[deadkeyLayer]'}}) {		# Given a deadkey: join layers into a face, and link to it
      for my $layer ( 0 .. $#{ $H->{layers} } ) {
#warn "Checking for empty layers, Face `$face', layer=$layer key=$KK";
        $self->{layers}{"[empty$layerL]"} ||= [map[], 1..$layerL], $H->{'[deadkeyLayer]'}{$KK}[$layer] = "[empty$layerL]"
          unless defined $H->{'[deadkeyLayer]'}{$KK}[$layer]
      }
      # Join the syntetic layers (now well-formed) into a new synthetic face:
      my $new_facename = "$F###$KK";
      $self->{faces}{$new_facename}{layers} = $H->{'[deadkeyLayer]'}{$KK};
      $H->{'[deadkeyFace]'}{$KK} = $new_facename;
#warn "Joining <$F>, <$new_facename>";
      $self->link_layers($F, $new_facename, 'skipfix', 'no-slot-warn', $self->default_char($F));
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
    next unless $H->{'[deadkeyLayer]'};		# Are we in a no-nonsense Face-hash with defined deadkeys?
    my $expl = $self->get_deep($self, 'faces', (split m(/), $F), 'Explicit_AltGr_Invert') || [];
    $expl = [], warn "Odd number of elements of Explicit_AltGr_Invert in face $F, ignore" if @$expl % 2;
    $expl = {map $self->charhex2key($_), @$expl};

#warn "Face: <", join( '> <', %$H), ">";
    my $layerL = @{ $self->{layers}{ $H->{layers}[0] } };	# number of keys in the face (in the principal layer)
    for my $KK (sort keys %{$H->{'[deadkeyLayer]'}}) {  # Create AltGr-inverted face if there is at least one key in the AltGr face:
      my $LL = $H->{'[deadkeyLayer]'}{$KK};
      next unless defined $H->{'[first_auto_dead]'} and grep defined, map $self->flatten_arrays($_), map $self->{layers}{$_}, @$LL[1..$#$LL];
      $H->{'[deadkeyInvFace]'}{''} = $self->next_auto_dead($H) unless exists $H->{'[deadkeyInvFace]'}{''};	# Make principal invertred face
      my $auto_chr = $H->{'[deadkeyInvFace]'}{$KK} = 
        ((exists $expl->{$self->charhex2key($KK)}) ? $expl->{$self->charhex2key($KK)} : $self->next_auto_dead($H));
      $H->{'[deadkeyFaceInvFace]'}{$auto_chr} = "$F##Inv#$KK";
    }
    next unless defined (my $flip_AltGr =  $H->{Flip_AltGr_Key});
    $flip_AltGr = $self->charhex2key($flip_AltGr) if defined $flip_AltGr;
    $H->{'[deadkeyFaceInvFace]'}{ $H->{'[deadkeyInvFace]'}{''} } = "$F##Inv#" if exists $H->{'[deadkeyInvFace]'}{''};
    my ($prev, %chain) = '';
    for my $k ( @{ $H->{chainAltGr} || [] }) {
      my $K  = $self->charhex2key($k);
      my $KK = $self->key2hex($K);
      warn("Deadkey `  $K  ' of face $F has no associated AltGr-inverted face"), next
        unless exists $H->{'[deadkeyInvFace]'}{$KK};
      $chain{$prev} = $H->{'[deadkeyInvFace]'}{$KK};
#warn "chain `$prev' --> `$K' => $H->{'[deadkeyInvFace]'}{$KK}";
      $H->{'[dead2_AltGr_chain]'}{(length $prev) ? $self->key2hex($prev) : ''}++;
      $prev = $K;
    }
    for my $KK (keys %{$H->{'[deadkeyInvFace]'}}) {	# Now know which deadkeys take inversion, and via what prefix
      my $new = $self->create_inverted_face($F, $KK, \%chain, $flip_AltGr);
      $self->coverage_face0($new);
    }
    # We do not link the AltGr-inverted faces to the "parent" faces here.  Currently, it should be done when
    # outputting a kbd description...
  }
  $self
}

#use Dumpvalue;
sub create_inverted_AltGr_face ($$$$$$$) {	# flip layers paying attention to linked AltGr-inverted faces, and overrides
  my ($self, $LL, $newname, $prefix, $nextL, $chainKey, $face, @K) = (shift, shift, shift, shift, shift, shift, shift);
  if (defined $nextL) {			# Borrow from make_translated_layer_tr()
    my %Map = ($chainKey, $nextL);
    my $Tr = sub ($) { my $c = shift; defined $c or return $c; my $o = $Map{$c} ;
#warn "Tr: `$c' --> `$o'" if defined $o;
#$o
    };
    $Tr = $self->depth1_A_translator($Tr);
    my $LLL = $self->{faces}{$face}{layers};
    for my $n (0..$#$LL) {					# Layer number
      my $new_Name = "$face##ChainAltGr#$n.." . $self->key2hex($nextL);
#warn "AltGr-chaining: name=$new_Name; `$chainKey' => `$nextL'";
      $self->{layers}{$new_Name} ||= [ map $Tr->($_), @{ $self->{layers}{ $LLL->[$n] } }];
      push @K, $new_Name;
    }
  }
  my @prefix = $prefix ? $prefix : ();
  my @n1 = map $self->flip_layer_N($_, $#$LL), 0..$#$LL;
  my @invLL = @$LL[@n1];
  push @prefix, \@K if @K;
  $self->{faces}{$newname}{layers} = [$self->make_translated_layers_stack(@prefix, \@invLL)];
}

# use Dumpvalue;

sub fill_win_template ($$$) {
  my @K = qw( COMPANYNAME LAYOUTNAME COPYR_YEARS LOCALE_NAME LOCALE_ID DLLNAME SORT_ORDER_ID_ LANGUAGE_NAME );
  my ($self, $t, $k, %h) = (shift, shift, shift);
# Dumpvalue->new()->dumpValue($self);
  my $idx = $self->get_deep($self, @$k, 'MetaData_Index');
  @h{@K} = map $self->get_deep_via_parents($self, $idx, @$k, $_), @K;
# warn "Translate: ", %h;
  my $F = $self->get_deep($self, @$k);		# Presumably a face, as in $k = [qw(faces US)]
  my $b = $F->{BaseLayer};
  $F->{'[dead-used]'} = [map {}, @{$F->{layers}}];		# Which of deadkeys are reachable on the keyboard
  my $cnt = $F->{'[non_VK]'};
  $h{LAYOUT_KEYS} = join '', $self->output_layout_win($F->{layers}, $b, $F->{'[dead]'}, $F->{'[dead-used]'}, $cnt);
  $h{LAYOUT_KEYS} .= join '', $self->output_VK_win($k->[-1], $F->{'[dead-used]'});

  if (0) {
#warn "Translate: ", %h;
    my($dm, $DM, %warn_dm, @maps, %maps_seen, $w, $via) = ($F->{DeadKey_Map}, $F->{DeadKey_Maps});
    defined $dm or $dm = '';
    $dm =~ s/^\s+//;
    ($dm, $via) = ($1, $2) if $dm =~ /^(.*)\((.*)\)$/;
    $via = $k->[-1] unless defined $via;
    $via = $F->{LinkFace} if ($via || '') eq 'LinkFace' and defined $F->{LinkFace};
    for my $s ( 0..$#{$F->{layers}} ) {
      my @unused = grep { not exists $F->{'[dead-used]'}[$s]{$_} } (my @used = keys %{$F->{'[dead]'}[$s] || {}});
      warn "The following deadkeys are not reachable in face `@$k' layer `$F->{layers}[$s]': <<", (join ">> <<", sort @unused), '>>'
        if @unused;
      next unless @used;
      if (defined $dm) {
        my $map = $self->get_deep($self, 'DEADKEYS', split m(/), $dm);
        if (defined $map) {
          my @K = keys %$map;
# warn "deadkey map `$dm' for face `@$k' has keys: @K";
          my $Map = { map +(chr hex $_, $map->{$_}), keys %$map };	# hex form is not unique
          $warn_dm{$_}++ for grep { not exists $Map->{$_} } @used;
          @used = grep { exists $Map->{$_} } @used;
          $maps_seen{$_}++ or push @maps, [$self->key2hex($_), $Map->{$_}] for @used;
        } else {
          warn "The DeadKey_Map `$dm' for face `@$k' could not be resolved";
          $warn_dm{$_}++ for @used;
        }
      } else {
        warn "DeadKeys present, but DeadKey_Map not present in face `@$k'" unless $w++;
        $warn_dm{$_}++ for @used;
      }
    }
    warn "The binding for following deadkeys are unknown in face `@$k': <<", (join '>> <<', sort keys %warn_dm), ">>"
      if %warn_dm;
  }
  ### Deadkeys???   need_extra_keys_to_access???
  my ($OUT, $OUT_NAMES) = ('', "KEYNAME_DEAD\n\n");
  
  my $f = $self->get_AgeList;
  $self->load_uniage($f) if defined $f and not $self->{Age};

  my $flip_AltGr_hex =  $F->{Flip_AltGr_Key};
  $flip_AltGr_hex = $self->key2hex($self->charhex2key($flip_AltGr_hex)) if defined $flip_AltGr_hex;
  for my $deadKey ( sort keys %{ $F->{'[deadkeyFace]'} } ) {
    my $auto_inv_AltGr = $F->{'[deadkeyInvFace]'}{$deadKey};
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

EOR

my (%known_dups) = map +($_,1), qw(0296 0384 1D43 1D52 1D9F 1E7A 1E7B 1FBF 2007
  202F 2113 24B8 24C7 2E1E 33B9 FC03 FC68 FD55 FD56 FD57 FD5D FD87 FD8C
  FD92 FDB5 FE34);		# As of Unicode 6.1-beta

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
		  		     ⊨ ⫢  ⊦ ⊧  ⊤ ⫧  ⊥ ⫨  ⊣ ⫤  ⊳ ⩥  ⊲ ⩤  ⋄ ⟠  ∫ ⨍  ⨍ ⨎  • ⦵
		  		     ∪ ⩌  ∩ ⩍  ≃ ≅  ⨯ ⨲ )],	# conflict with modifiers: qw( _ ‗ ); ( ∈  ) ∋ not useful with ∈∋ as greenkeys...
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
		  		     ∈ ∊  ∋ ∍  - −  / ∕  \ ∖  √ ∛  ∛ ∜  ∫ ∬  ∬ ∭  ∭ ⨌  ∮ ∯  ∯ ∰  : ⦂
		  		     : ∶  ≈ ≋  ≏ ≎  ≡ ≣  × ⨯  + ∑  Π ∏  Σ ∑  ρ ∐  ∐ ⨿  ⊥ ⟘  ⊤ ⟙  ⟂ ⫡  ; ⨾  □ ⧈  ◇ ◈
		  		     ⊲ ⨞  ⊢ ⊦  △ ⟁  ∥ ⫴  ⫴ ⫼  / ⫽  ⫽ ⫻  • ●  ⊔ ⩏  ⊓ ⩎  ∧ ⩕  ∨ ⩖  ▷ ⊳  ◁ ⊲
		  		     ⋉ ⧔  ⋊ ⧕  ⋈ ⧓  ⪡ ⫷  ⪢ ⫸  ≟ ≛  ≐ ≎  ⊳ ⫐  ⊲ ⫏  { ❴  } ❵  × ⨶  )],	#   ⋆ ☆  ⋆ ★ ;  ˆ ∧ conflicts with combining-ˆ; * ∏ stops propagation *->×->⋈, : ⦂ hidden; ∥ ⫴; × ⋈ not needed; ∰ ⨌ - ???; ≃ ≌ not useful
		  turnaround => [qw( ∧ ∨  ∩ ∪  ∕ ∖  ⋏ ⋎  ∼ ≀  ⋯ ⋮  … ⋮  ⋰ ⋱  
		  		     8 ∞  ∆ ∇  Α ∀  Ε ∃  ∴ ∵  ≃ ≂
		  		     ∈ ∋  ∉ ∌  ∊ ∍  ∏ ∐  ± ∓  ⊓ ⊔  ≶ ≷  ≸ ≹  ⋀ ⋁  ⋂ ⋃  ⋉ ⋊  ⋋ ⋌  ⋚ ⋛  ≤ ⋜  ≥ ⋝  ≼ ⋞  ≽ ⋟  )],			# XXXX Can't do both directions
		  round      => [qw( < ⊂  > ⊃  = ≖  = ≗  = ≍  ∫ ∮  ∬ ∯  ∭ ∰  ∼ ∾  - ⊸  □ ▢  ∥ ≬  ‖ ≬  • ⦁
		  		     … ∴  ≡ ≋  ⊂ ⟃  ⊃ ⟄  ⊤ ⫙  ⊥ ⟒  ( ⦖  ) ⦕  ( ⦓  ) ⦔  ( ⦅  ) ⦆  ⊳ ⪧  ⊲ ⪦  ≟ ≘  ≐ ≖  . ∘
		  		     [ ⟬  ] ⟭  { ⧼  } ⧽  % ⦼  % ‰  × ⦻  ⨯ ⨷  )]);	#   = ≖  = ≗ hidden = ≈

sub parse_NameList ($$) {
  my ($self, $f, $k, $kk, $name, %basic, %cached_full, %compose, 
      %into2, %ordered, %candidates, %N, %comp2, %NM, %BL, $BL, %G, %NS) = (shift, shift);
  binmode $f;			# NameList.txt is in Latin-1, not unicode
  while (my $s = <$f>) { # extract compositions, add <upgrade> to char downgrades; -> composition, => compatibility composition
    if ($s =~ /^([\da-f]+)\b\s*(.*?)\s*$/i) {
      my ($K, $Name, $C, $t) = ($1, $2, $self->charhex2key("$1"));
      $N{$Name} = $K;
      $NM{$C} = $Name;		# Not needed for compositions, but handy for user-visible output
      $BL{$C} = $self->charhex2key($BL);		# Used for sorting
      # Finish processing of preceding text
      if (defined $kk) {				# Did not see (official) decomposition
        $NS{$C}++ if $name =~ /\bCOMBINING\b/ and not ($C =~ /\p{NonSpacingMark}/);
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
      ($k, $name) = ($K, $Name); 
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
#warn "raw=`$raw', prepend=<$prepend>, append=<$append>, base=$Cand->[0]";
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

#warn "    b =`$b', prepend=<$prepend>, append=<$append>, base=$Cand->[0]";
      if (defined ($base = $N{$b})) {
        undef $base, next if $base eq $c;
        $with = $raw if $t;
#warn "<$Cand->[0]> WITH <$Cand->[1]> resolved via SIGN/SYMBOL/.* FORM: strip=<$app> add=<$prepend/$append>" if $append or $app or $prepend;
        last 
      }
    }
    if (defined $base) {
      $base = [$base];
    } elsif ($raw =~ /\bOPERATOR$/) {
      $base = [map $N{$_}, @{ $operators{$Cand->[0]} }] if exists $operators{$Cand->[0]};
    }
    ($warnUNRES and warn("Unresolved: <$Cand->[0]> WITH <$Cand->[1]>")), next unless defined $base;
    my @modifiers = split /\s+AND\s+/, $with;
    @modifiers = map { s/\s+/-/g; /^[\da-f]{4,}$/i ? $_ : "<pseudo-\L$_>" } @modifiers;
#warn " $c --> <@$base>; <@modifiers>...\t$b <- $NM{chr hex $c}" ;
    unshift @{$basic{$c}}, [1, $_, @modifiers] for @$base;
    if ($b =~ s/\s+(OPERATOR|SIGN)$//) {	# ASTERISK	(note that RING is a valid name, but has no relation to RING OPERATOR
      unshift @{$basic{$c}}, [1, $base, @modifiers] if defined ($base = $N{$b});	# ASTERISK
#$base = '[undef]' unless defined $base;
#warn("operator via <$b>, <$c> => `$base'");
#warn("operator: `$c' ==> `$_', <@modifiers> via <$b>"),
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
  \%into2, \%comp2, \%NM, \%BL, \%NS
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
  ($self->{Decompositions}, $comp, $self->{UNames}, $self->{UBlock}, $self->{exComb}) = $self->parse_NameList($f);
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
sub UName($$$) {
  my ($self, $c, $verbose, $app, $n, $i, $A) = (shift, shift, shift, '');
  $c = $self->charhex2key($c);
  return $UName_v{$c} if $verbose and exists $UName_v{$c};
  if (not exists $self->{UNames} or $verbose) {
    require Unicode::UCD;
    $i = ($charinfo{$c} ||= Unicode::UCD::charinfo(ord $c) || {});
    $A = $self->{Age}{$c};
    $n = $self->{UNames}{$c} || ($i->{name}) || "<$c>";
    if ($verbose and (%$i or $A)) {
      my $scr = $i->{script};
      my $bl = $i->{block};
      $scr = join '; ', grep defined, $scr, $bl, $A;
      $scr = "Com/MiscSym1.1" if 0x266a == ord $c;	# EIGHT NOTE: we use as "visual bell"
      $app = " [$scr]" if length $scr;
    }
    return($UName_v{$c} = "$n$app") if $verbose;
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
sub get_compositions ($$$$;$) {
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
  my ($self, $M, $C, @res, %seen) = (shift, shift, shift);
  return undef unless defined $C;
warn "composing `$M' with base <$C>" if warnDO_COMPOSE;
  $C = [[0,$C]];			# Emulate element of return of Compositions
  for my $m (reverse split /\+|-(?=-)/, $M) {
    my @res;
    if ($m =~ /^(?:-|(?:[ul]c(?:first)?)$)/) {
      if ($m =~ s/^-//) {
        @res = map $self->get_compositions([$m], $_->[1], 'undo'), @$C;
        @res = map [[0,$_]], grep defined, @res;
      } elsif ($m eq 'lc') {
        @res = map {($_->[1] eq lc($_->[1]) or 1 != length lc($_->[1])) ? () : [[0, lc $_->[1]]]} @$C
      } elsif ($m eq 'uc') {
        @res = map {($_->[1] eq uc($_->[1]) or 1 != length uc($_->[1])) ? () : [[0, uc $_->[1]]]} @$C
      } elsif ($m eq 'lcfirst') {
        @res = map {($_->[1] eq lcfirst($_->[1]) or 1 != length lcfirst($_->[1])) ? () : [[0, lcfirst $_->[1]]]} @$C
      } elsif ($m eq 'ucfirst') {
        @res = map {($_->[1] eq ucfirst($_->[1]) or 1 != length ucfirst($_->[1])) ? () : [[0, ucfirst $_->[1]]]} @$C
      } else {
        die "Panic"
      }
    } else {
#warn "compose `$m' with bases <", join('> <', map $_->[1], @$C), '>';
      @res = map $self->{Compositions}{$m}{$_->[1]}, @$C;
    }
    @res = map @$_, grep defined, @res;
    return undef unless @res;
    $C = \@res;
  }
  $C
}

sub compound_composition_many ($$$) {		# As above, but takes an array of chars
  my ($self, $M, $CC, @res) = (shift, shift, shift);
  return undef unless $CC;
  for my $C (@$CC) {
    my $in = $self->compound_composition($M, $C);
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
  my ($self, $m, $C, $Sub, $dupsOK, $w32OK, @res, %seen, %Penalize, %penalize, @C) = (shift, shift, shift, shift, shift, shift);
  for my $c (@$C) {
    push @C, [map {($_ and 'ARRAY' eq ref $_) ? $_->[0] : $_} @$c]
  }
  my $char = $C[0][0];
  for my $MM (@$m) {			# |-groups
    my(%byPenalty, @byLayers);
    for my $M (@$MM) {			# diacritic in a group; may flatten each layer, but do not flatten separately each shift state: need to pair uc/lc
      if ((my $P = $M) =~ s/^\\(\\)?//) {
        my $kill = $1;
# warn "Penalize: <$P>";	# Actually, it is not enough to penalize; one should better put it in a different group...
	if ($P =~ s/\[(.*)\]$//) {
	  #$P = $self->stringHEX2string($P);
	  my $match;
	  $char eq $_ and $match++ for split //, $self->stringHEX2string("$1");
	  next unless $match;
	}  
	#$P = $self->stringHEX2string($P);
        $kill ? $Penalize{$_}++ : $penalize{$_}++ for split //, $P;		# XXXX Temporarily, we ignore them completely
        next
      }
      for my $L (0..$#C) {		# Layer number; indexes a shift-pair
#        my @res2 = map {defined($_) ? $self->{Compositions}{$M}{$_} : undef } @{ $C[$L] };
        my @Res2 = map $self->compound_composition($M, $_), @{ $C[$L] };	# elt: [$synth, $char]
        my @working_with = grep defined, @{ $C[$L] };				# ., KP_Decimal gives [. undef]
warn "compound  `$M' of [@working_with] -> ", $self->array2string(\@Res2) if warnSORTCOMPOSE;
        (my $MMM = $M) =~ s/(^|\+)<reveal-greenkey>$//;
        my @Res3 = map $self->compound_composition_many($MMM, ((defined $_) ? $Sub->{$_} : $_)), @{ $C[$L] };
warn "compound+ `$M' of [@working_with] -> ", $self->array2string(\@Res3) if warnSORTCOMPOSE;
        for my $shift (0..$#Res3) {
          if (defined $Res2[$shift]) {
            push @{ $Res2[$shift]}, @{$Res3[$shift]} if $Res3[$shift]
          } else {
            $Res2[$shift] = $Res3[$shift]
          }
        }
#        defined $Res2[$_] ? ($Res3[$_] and push @{$Res2[$_]}, @{$Res2[$_]}) : ($Res2[$_] = $Res3[$_]) for 0..$#Res3;
        @Res2 = @{ $self->deep_copy(\@Res2) };
        my ($ok, @ini_compat);
        do {{
	  my @res2   = map {defined() ? $_->[0] : undef} @Res2;
	  $ok = grep $_, @res2;
	  defined and (shift(@$_), (@$_ or undef $_)) for @Res2;
          @res2    = map {(not defined() or (!$dupsOK and $seen{$_->[1]}++)) ? undef : $_} @res2;	# remove duplicates
	  my @compat = map {defined() ? $_->[0] : undef} @res2;
	  @res2      = map {defined() ? $_->[1] : undef} @res2;
          @res2      = map {0x10000 > ord($_ || 0) ? $_ : undef} @res2 unless $w32OK;	# remove those needing surrogates
	  defined $ini_compat[$_] or $ini_compat[$_] = $compat[$_] for 0..$#compat;
	  my @extra_penalty = map {!!$compat[$_] and $ini_compat[$_] < $compat[$_]} 0..$#compat;
          next unless my $cnt = grep defined, @res2;
          my($penalty, $p) = [('zzz') x @res2];	# above any "5.1", "undef" ("unassigned"???)
          # Take into account the "compatibility", but give it lower precedence than the layer:
          # for no-compatibility: do not store the level;
          defined $res2[$_] and $penalty->[$_] gt ( $p = ($self->{Age}{$res2[$_]} || 'undef') . "#$extra_penalty[$_]#$self->{UBlock}{$res2[$_]}" )
            and $penalty->[$_] = $p for 0..$#res2;
          my $have1 = not (defined $res2[0] and defined $res2[1]);		# Prefer those with both entries
          # Break a non-lc/uc paired translations into separate groups
          my $double_occupancy = ($cnt == 2 and $res2[0] ne $res2[1] and $res2[0] eq lc $res2[1]);
          next if $double_occupancy and grep {defined and $Penalize{$_}} @res2;
          if ($double_occupancy and grep {defined and $penalize{$_}} @res2) {
            defined $res2[$_] and $penalty->[$_] = "zzz$penalty->[$_]" for 0..$#res2;
          } else {
            defined and $Penalize{$_} and $cnt--, $have1=1, undef $_ for @res2;
            defined $res2[$_] and $penalize{$res2[$_]} and $penalty->[$_] = "zzz$penalty->[$_]" for 0..$#res2;
          }
          next unless $cnt;
          if (not $double_occupancy and $cnt == 2 and (1 or $penalty->[0] ne $penalty->[1])) {	# Break (penalty here is not a good idea???)
            push @{ $byPenalty{"$penalty->[0]1"}[0][$L] }, [$res2[0]];
            push @{ $byPenalty{"$penalty->[1]1"}[0][$L] }, [undef, $res2[1]];
            next;		# Now: $double_occupancy or $cnt == 1 or $penalty->[0] eq $penalty->[1]
          }
          $p = $penalty->[0];
          $p = $penalty->[1] if @$penalty > 1 and defined $res2[1] and $p gt $penalty->[1];
          push @{ $byPenalty{"$p$have1"}[$double_occupancy][$L] }, \@res2;
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

sub append_keys ($$$$;$) {	# $k is [[lc,uc], ...]; modifies $C in place
  my ($self, $C, $KK, $LL, $prepend, @KKK, $cnt) = (shift, shift, shift, shift, shift);
  for my $L (0..$#$KK) {	# $LL contains info about from which layer the given binding was stolen
    my $k = $KK->[$L];
    next unless defined $k and (defined $k->[0] or defined $k->[1]);
    $cnt++;
    my $paired = (@$k == 2 and defined $k->[0] and defined $k->[1] and $k->[0] ne $k->[1] and $k->[0] eq lc $k->[1]);
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

(Other keys "stuck in stone" are dead key: it is important to have the
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
