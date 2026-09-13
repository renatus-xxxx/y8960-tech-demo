set sound_driver null
set throttle on
set save_settings_on_exit false
after time 9 {screenshot -raw "$::env(OPENMSX_HOME)/section-1.png";keymatrixdown 0 16;after time 0.2 {keymatrixup 0 16}}
after time 11 {
 set f [open "$::env(OPENMSX_HOME)/state.txt" w]
 puts $f "telemetry=[binary encode hex [debug read_block memory 0xc100 8]]"
 close $f
 set f [open "$::env(OPENMSX_HOME)/screen.bin" wb]
 puts -nonewline $f [debug read_block VRAM 0 27136];close $f
 set f [open "$::env(OPENMSX_HOME)/sprites.bin" wb];puts -nonewline $f [debug read_block VRAM 0x7400 1568];close $f
 set f [open "$::env(OPENMSX_HOME)/vdp-regs.bin" wb];puts -nonewline $f [debug read_block {VDP regs} 0 32];close $f
 screenshot -raw "$::env(OPENMSX_HOME)/section-4.png";exit
}
