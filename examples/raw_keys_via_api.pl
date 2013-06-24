#!/usr/bin/perl -w
#perl -C31 -we "
use strict;
use Win32API::File 'GetOsFHandle';

$Win32::API::DEBUG = 1;				# XXXX Too early now, when we load-when-needed
my %pointer_ints = qw(4 int 8 __int64);
my $HANDLE_t = $pointer_ints{length pack 'p', ''} or die "Cannot deduce pointer size";

use Keyboard_API;

sub ReadConsoleEvent () { @{(ReadConsoleEvents)[0]} }

sub checkConsole ($) {  __ConsoleMode shift or not $^E  }		# returns success if cannot load
sub try_checkConsole ($) {		# returns success if cannot load
  my $o;
  return 1 unless eval {$o = checkConsole shift; 1};	# Fake success if cannot do better
  return $o;
}

sub printConsole ($;$) {
  my($s, $fh) = (shift, shift);
  $fh = \*STDOUT unless defined $fh;
  (print $fh $s), return unless -t $fh and try_checkConsole $fh;	# -t is very successful, but just in case...
  require Encode;
  WriteConsole(Encode::encode('UTF-16LE', $s), $fh);
}


#print $f->Call($stdin_h, $i, 10, $o), q( ), unpack 'l', $o for 1..3;
#exit;

# http://msdn.microsoft.com/en-us/library/ms927178.aspx
my %_VK = qw(
VK_SHIFT 	10 
VK_CONTROL 	11
VK_MENU 	12
VK_PAUSE 	13
VK_CAPITAL 	14

VK_NUMLOCK 	90
VK_SCROLL 	91
VK_LSHIFT	0xA0
VK_RSHIFT	0xA1
VK_LCONTROL	0xA2
VK_RCONTROL	0xA3
VK_LMENU	0xA4
VK_RMENU	0xA5	);
my %VK;
while (my ($f,$t) = each %_VK) {
  (my $ff = $f) =~ s/^VK_// or die;
  $VK{$ff} = hex $t;
}

{ my $high_surrogate;
sub c($;$) { 
  my $i = shift; 
  my $buffer = (@_ ? \shift : \$high_surrogate);
  return q() if $i<33 or $i==0x7f; 
  (defined $$buffer and die("Doubled high surrogate (function called multiple times per event?)")), 
    $$buffer = $i, return q() if $i<0xDC00 and $i >= 0xD800; 
  $i += ($$buffer - 0xD800)*0x400 - 0xDC00 + 0x10000, undef $$buffer if $i>=0xDC00 and $i < 0xE000;
  die("Loner high surrogate") if defined $$buffer;
  chr $i
}}

sub mode2s ($) {
  my $in = shift; 
  my @o; 
  $in & (1<<$_) and push @o, (qw(rAlt lAlt rCtrl lCtrl Shft NumL ScrL CapL Enh ? ??))[$_] for 0..10; 
  qq(@o)
} 

#use Win32::Console;
#my $c = Win32::Console->new( STD_INPUT_HANDLE); 

my @k = qw(T down rep vkey vscan ch ctrl);
sub format_ConsoleEvent ($) {
  my @in = @{shift()};
  join '; ', (map { "$k[$_]=" . ($in[$_] < 0 ? $in[$_] + 256 : $in[$_]) } 0..$#in),
    (@in ? mode2s($in[-1]) . ' [' . (c $in[-2]) . ']' : 'empty'); 
}

if ("@ARGV" eq 'cooked') {	# Control-letter are read as is (except C-Enter??? and C-c), Alt-letters as letters
  my $omode;
  eval {$omode = ConsoleFlag_s \*STDIN, 0x2, 0; 1} or warn "unset ENABLE_LINE_INPUT on STDIN: $@";
  for (1..5) {
    printConsole "$_: I see «" . readConsole(10) . "»\n";
  }
  defined $omode and ConsoleFlag_s \*STDIN, $omode;	# OR with the old value
  exit;
}

my($use_kbd, $do_ToUnicode);
($use_kbd, $do_ToUnicode) = ($1, shift) if ($ARGV[0] || '') =~ /^U(\d+)?$/;

my %vk_short = qw(CAPITAL CapsL NUMLOCK NumL SCROLL ScrL SHIFT Shft CONTROL Ctrl MENU Alt);
sub __mods($$@) { 
  my ($s, $k) = (shift,shift);
  my $kk = $vk_short{$k} || $k;
  $kk . (join '/', @_) . '=' . join '/', map sprintf('%x', ord substr $s, $VK{$_.$k}), @_
}
#sub modsLR($$) { my ($s, $k) = @_; '$k/L/R=' . join '/', map sprintf('%#x', ord substr $s, $VK{$_.$k}), '','L','R' }
sub mod1($$)    { __mods shift, shift, '' }
sub modsLR($$)  { __mods shift, shift, '', 'L', 'R' }

my $fh = \*STDIN;
warn "STDIN is not from a console" unless -t $fh and try_checkConsole $fh;	# -t is very successful, but just in case...
my $in_dead;
if ($do_ToUnicode) {
  my ($c_tid, $c_pid) = GetWindowThreadProcessId(my $c_w = GetConsoleWindow);
  my @l = GetKeyboardLayoutList;
  printConsole "My PID=$$, console's PID=$c_pid, console's TID=$c_tid.\n";
  printConsole(sprintf("\t\tConsoleWin: %#x of thread %#x with kbd %#x", $c_w, $c_tid, GetKeyboardLayout($c_tid))
          .",\n\t\tKeyboard layouts: <" . (join ', ', map {sprintf '%#x', $_ } @l) . ">\n");
  ActivateKeyboardLayout($l[$use_kbd]) if defined $use_kbd;
}
for (1..shift||20) {
  my @in = ReadConsoleEvents $fh, 8; #$c->Input;
  for (0..$#in) {
    my $s;
    printConsole "$_: " . (format_ConsoleEvent $in[$_]) . "\n";
    next unless $do_ToUnicode;
    GetKeyState(0);		# Voodoo to enable GKbS in non-message queue context???  (Works in Win7 SP1; must call every time)
    GetKeyboardState($s);	#    see http://msdn.microsoft.com/en-us/library/windows/desktop/ms646299%28v=vs.85%29.aspx
    printConsole "\t".join(', ', (map mod1($s, $_), qw(CAPITAL NUMLOCK SCROLL)), (map modsLR($s, $_), qw(SHIFT CONTROL MENU))) . "\n";
    next unless $in[$_]->[0] == 1;	# keyboard event
    my ($c) = ToUnicodeEx($in[$_][3], $in[$_][4], $s) or next;
    $in_dead = 1, printConsole("\tprefix key, expecting more input...\n"), next unless defined $c;
    if ($in_dead) {
      if (1 < length $c) {
        warn "I'm puzzled: more than 2 chars arrived after a prefix key: «$c»\n" if 2 < length $c;
        my ($p, $r) = split //, $c, 2;
        printConsole "\tprefix key = «$p» was followed by unrecognized suffix «$r»...\n";
      } else {
        printConsole "\tkey sequence results in «$c».\n";
      }
      $in_dead = 0;
    } else {
      my $s = (1 < length $c) && 's';
      printConsole sprintf "\t==> char$s «%s»; keyboard layout %#x.\n", $c, GetKeyboardLayout;
    }
  }
}

# http://www.winprog.org/tutorial/start.html	(simple window)  saved to ===> winprog-org-tutorial-source.zip
# gcc -s -Os -mno-cygwin -o <outputfilename> <inputfilename>
# gcc -s -Os -mwindows -mno-cygwin -o <outputfilename> <inputfilename> -lopengl32 -lwinmm
# for command-line programs and windows programs
