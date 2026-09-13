set renderer none
set sound_driver null
set throttle off
set save_settings_on_exit false
set master_volume 65
set out $::env(OPENMSX_HOME)
after time 8 {
 foreach d [machine_info sounddevice] {set ::${d}_volume 0}
 set {::Y8960 OPL2 1_volume} 75
 set f [open "$::out/sample-ram.bin" wb];puts -nonewline $f [debug read_block {Y8960 ADPCM RAM} 0 4096];close $f
 keymatrixdown 0 16
 after time 0.1 {keymatrixup 0 16}
 after time 0.8 {record start -audioonly "$::out/adpcm-solo.wav"}
}
after time 14.8 {record stop;exit}
