@if not exist %Keyboard_Layout_Creator%\bin\i386\kbdutool.exe (
  echo Set Keyboard_Layout_Creator=SOMETHING
  echo so that %%Keyboard_Layout_Creator%%\bin\i386\kbdutool.exe exists
  exit
)

%Keyboard_Layout_Creator%\bin\i386\kbdutool.exe -v -w -s ../ooo-us
%Keyboard_Layout_Creator%\bin\i386\kbdutool.exe -v -w -s ../ooo-ru
..\UI-KeyboardLayout\examples\compile_link_kbd.cmd iz-la-ru 2>&1 | tee 00cl
..\UI-KeyboardLayout\examples\compile_link_kbd.cmd iz-ru-la 2>&1 | tee 00cr
