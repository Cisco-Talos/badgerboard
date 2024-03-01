# Copyright 2024 Cisco and/or its affiliates
# SPDX-License-Identifier: Apache-2.0

proc generate {drv_handle} {
	xdefine_include_file $drv_handle "xparameters.h" "BackplaneReader_AXILite" "NUM_INSTANCES" "DEVICE_ID"  "C_S00_AXI_BASEADDR" "C_S00_AXI_HIGHADDR"
}
