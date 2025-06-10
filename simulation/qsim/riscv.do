onerror {exit -code 1}
vlib work
vcom -work work riscv.vho
vcom -work work wave.vwf.vht
vsim -c -t 1ps -sdfmax TopDE_vhd_vec_tst/i1=riscv_vhd.sdo -L cycloneive -L altera -L altera_mf -L 220model -L sgate -L altera_lnsim work.TopDE_vhd_vec_tst
vcd file -direction riscv.msim.vcd
vcd add -internal TopDE_vhd_vec_tst/*
vcd add -internal TopDE_vhd_vec_tst/i1/*
proc simTimestamp {} {
    echo "Simulation time: $::now ps"
    if { [string equal running [runStatus]] } {
        after 2500 simTimestamp
    }
}
after 2500 simTimestamp
run -all
quit -f










