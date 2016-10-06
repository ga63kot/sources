#include "obj_dir/Vtb_compute_tile__Syms.h"
#include "obj_dir/Vtb_compute_tile__Dpi.h"

#include <VerilatedToplevel.h>
#include <VerilatedControl.h>

#include <ctime>
#include <cstdlib>

using namespace simutilVerilator;

VERILATED_TOPLEVEL(tb_compute_tile,clk, rst)

int main(int argc, char *argv[])
{
    tb_compute_tile ct("TOP");

    VerilatedControl &simctrl = VerilatedControl::instance();
    simctrl.init(ct, argc, argv);

<<<<<<< HEAD
//    simctrl.addMemory("TOP.tb_compute_tile.u_compute_tile.u_ram.sp_ram.gen_sram_sp_impl.u_impl");
    simctrl.addMemory("TOP.tb_compute_tile.u_compute_tile.gen_cores[0].genblk1.u_debug_processor.u_debug_coprocessor.u_ram.sp_ram.gen_sram_sp_impl.u_impl");
=======
    simctrl.addMemory("TOP.tb_compute_tile.u_compute_tile.gen_sram.u_ram.sp_ram.gen_sram_sp_impl.u_impl");
>>>>>>> upstream/master
    simctrl.setMemoryFuncs(do_readmemh, do_readmemh_file);
    simctrl.run();

    return 0;
}
