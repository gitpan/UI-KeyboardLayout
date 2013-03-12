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

%Keyboard_Layout_Creator%\bin\i386\kbdutool.exe -v -w -s ooo-us-shorten
%Keyboard_Layout_Creator%\bin\i386\kbdutool.exe -v -w -s ooo-ru-shorten

patch -p0 -b <%ex%\izKeys.patch

%ex%\compile_link_kbd.cmd iz-la-ru 2>&1 | tee 00cl
%ex%\compile_link_kbd.cmd iz-ru-la 2>&1 | tee 00cr

zip -ru iz-la-ru iz-la-ru
zip -ru iz-ru-la iz-ru-la
zip -ju src %src%/ooo-us %src%/ooo-ru %ex%\izKeys.kbdd %ex%\build-iz.pl %ex%\compile_link_kbd.cmd %ex%\izKeys.patch %~f0 *.C *.H *.RC *.DEF
zip -ju html %src%/izKeys-visual-maps-out.html %src%/coverage-1prefix-Cyrillic.html %src%/coverage-1prefix-Latin.html

for %%d in (iz-la-ru iz-ru-la) do ls -l %%d\i386\%%d.dll %%d\ia64\%%d.dll %%d\amd64\%%d.dll %%d\wow64\%%d.dll
