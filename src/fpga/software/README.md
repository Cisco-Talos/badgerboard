# fpga-software

This zip file is an export archive from the Xilinx Vitis software suite. Importing this zip file directly will give you the best results, but feel free to browse internally prior to import. This will contain mostly files generated from Vivado and Vitis directly for header files and C files corresponding to the hardware that was sythesized by Vivado. 

This zip file is not meant to be used outside of Vitis, but it is likely possible to compile it. The only code of note is the interrupt handler associated with the `BackplaneReader` peripheral.