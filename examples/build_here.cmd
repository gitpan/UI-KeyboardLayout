@if not exist %Keyboard_Layout_Creator%\bin\i386\kbdutool.exe (
  echo Set Keyboard_Layout_Creator=SOMETHING
  echo so that %%Keyboard_Layout_Creator%%\bin\i386\kbdutool.exe exists
  exit
)

@rem Sometimes it may be better to make these into .   ...
set ex=..\UI-KeyboardLayout\examples
set src=..

@rem It is assumed that in the parent directory the .klc are already constructed as
@rem perl -wC31 -I UI-KeyboardLayout/lib UI-KeyboardLayout/examples/build-iz.pl UI-KeyboardLayout/examples/izKeys.kbdd

@rem For best results, put the previous version of the distribution into subdirectories of this directory
@rem For the initial build, remove everything in SHIFTSTATE, LAYOUT and DEADKEY sections, load in MSKLC, and build from GUI
@rem (There may be problems on 64-bit systems???)

@rem Shorten (but do not cut in the middle of utf-8 char
perl -wlpe "s/^(.{250}[\x80-\xBF]*).*/$1/s" %src%/ooo-us >ooo-us-shorten
perl -wlpe "s/^(.{250}[\x80-\xBF]*).*/$1/s" %src%/ooo-ru >ooo-ru-shorten

set ARROWSK=qw(HOME UP PRIOR DIVIDE LEFT F13 RIGHT MULTIPLY END DOWN NEXT SUBTRACT INSERT F15 F14 ADD)

@rem Remove Fkeys (except F2), NUMPADn, CLEAR from oo-LANG-shorten
perl -i~ -wlpe "BEGIN {@K = %ARROWSK%; $k = join q(|), @K[1..$#K]; $rx = qr/\b(F[13-9]\d?|NUMPAD\d|CLEAR)\b/} $_ = q() if /^[0-9A-F]{2,4}\s+$rx/" ooo-us-shorten ooo-ru-shorten

%Keyboard_Layout_Creator%\bin\i386\kbdutool.exe -v -w -s ooo-us-shorten
%Keyboard_Layout_Creator%\bin\i386\kbdutool.exe -v -w -s ooo-ru-shorten

@rem INSERT is handled OK by kbdutool ...  Replace #ERROR# by F2 and elts of ARROWSK (except Fn and INSERT) in order
perl -i~ -wlpe "BEGIN { @ARGV = <*.[CH]>; $c=1; @K = (%ARROWSK%); @KK = (map(qq(F$_), 0,2), grep(!/^F\d+$/ && !/^INSERT$/, @K), qw(F2 F2 ?)); }; $vk = ($ARGV =~ /C$/i && q(VK_)); s/#ERROR#/${vk}$KK[$c]/ and $c++; $c=1 if eof"

@rem the "old" short rows contain -1 instead of WCH_NONE
perl -i~~ -wlpe "BEGIN { @ARGV = <*.C>; $k = {qw( ADD '+' SUBTRACT '-' MULTIPLY '*' DIVIDE '/' RETURN '\r' )}; $rx = join q(|), keys %%$k; }; s/^(\s+\{VK_($rx)\s*,\s*0\s*,\s*)'\S*\s+\S+\s+\S+\s*$//"

patch -p0 -b <%ex%\izKeys.patch

%ex%\compile_link_kbd.cmd iz-la-ru 2>&1 | tee 00cl
%ex%\compile_link_kbd.cmd iz-ru-la 2>&1 | tee 00cr

zip -ru iz-la-ru iz-la-ru
zip -ru iz-ru-la iz-ru-la
zip -ju src %src%/ooo-us %src%/ooo-ru %ex%\izKeys.kbdd %ex%\build-iz.pl %ex%\compile_link_kbd.cmd %ex%\izKeys.patch %~f0 *.C *.H *.RC *.DEF
zip -ju html %src%/izKeys-visual-maps-out.html %src%/coverage-1prefix-Cyrillic.html %src%/coverage-1prefix-Latin.html

for %%d in (iz-la-ru iz-ru-la) do ls -l %%d\i386\%%d.dll %%d\ia64\%%d.dll %%d\amd64\%%d.dll %%d\wow64\%%d.dll
