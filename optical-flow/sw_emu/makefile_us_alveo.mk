#
# Copyright 2019-2021 Xilinx, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# makefile-generator v1.0.3
#

############################## Help Section ##############################
ifneq ($(findstring Makefile, $(MAKEFILE_LIST)), Makefile)
help:
	$(ECHO) "Makefile Usage:"
	$(ECHO) "  make all TARGET=<sw_emu/hw_emu/hw> PLATFORM=<FPGA platform>"
	$(ECHO) "      Command to generate the design for specified Target and Shell."
	$(ECHO) ""
	$(ECHO) "  make clean "
	$(ECHO) "      Command to remove the generated non-hardware files."
	$(ECHO) ""
	$(ECHO) "  make cleanall"
	$(ECHO) "      Command to remove all the generated files."
	$(ECHO) ""
	$(ECHO) "  make test PLATFORM=<FPGA platform>"
	$(ECHO) "      Command to run the application. This is same as 'run' target but does not have any makefile dependency."
	$(ECHO) ""
	$(ECHO) "  make run TARGET=<sw_emu/hw_emu/hw> PLATFORM=<FPGA platform>"
	$(ECHO) "      Command to run application in emulation."
	$(ECHO) ""
	$(ECHO) "  make build TARGET=<sw_emu/hw_emu/hw> PLATFORM=<FPGA platform>"
	$(ECHO) "      Command to build xclbin application."
	$(ECHO) ""
	$(ECHO) "  make host"
	$(ECHO) "      Command to build host application."
	$(ECHO) ""
endif

############################## Setting up Project Variables ##############################
TARGET := sw_emu
include ../utils.mk

TEMP_DIR := ./_x.$(TARGET).$(XSA)
BUILD_DIR := ./build_dir.$(TARGET).$(XSA)
SRC_DIR=..
ACCEL=MONO

ifeq ($(ACCEL), MONO)
  OPERATORS_SRC=$(wildcard $(SRC_DIR)/mono/*.cpp)
else
  OPERATORS_SRC=$(wildcard $(SRC_DIR)/operators/*.cpp)
endif

img_name=$(basename $(wildcard $(SRC_DIR)/host/imageLib/*.cpp))
img_obj=$(addsuffix .o, $(img_name))

LINK_OUTPUT := $(BUILD_DIR)/krnl_incr.link.xclbin
PACKAGE_OUT = ./package.$(TARGET)

VPP_PFLAGS := 
CMD_ARGS = $(BUILD_DIR)/krnl_incr.xclbin
CXXFLAGS += -I$(XILINX_XRT)/include -I$(XILINX_HLS)/include -Wall -O0 -g -std=c++1y
LDFLAGS += -L$(XILINX_XRT)/lib -pthread -lOpenCL

########################## Checking if PLATFORM in allowlist #######################
PLATFORM_BLOCKLIST += 2018 qep aws-vu9p-f1 samsung u2_ zc702 nodma 
############################## Setting up Host Variables ##############################
#Include Required Host Source Files
CXXFLAGS += -I../common/includes/xcl2
HOST_SRCS += ../common/includes/xcl2/xcl2.cpp ../host/host.cpp 
# Host compiler global settings
CXXFLAGS += -fmessage-length=0
LDFLAGS += -lrt -lstdc++ 

############################## Setting up Kernel Variables ##############################
# Kernel compiler global settings
VPP_FLAGS += -t $(TARGET) --platform $(PLATFORM) --save-temps 


# Kernel linker flags
VPP_LDFLAGS_krnl_incr += --config ../krnl_incr.cfg
# EXECUTABLE = streaming_free_running_k2k
EXECUTABLE = app.exe
EMCONFIG_DIR = $(TEMP_DIR)

############################## Setting Targets ##############################
.PHONY: all clean cleanall docs emconfig
all: check-platform check-device check-vitis $(EXECUTABLE) $(BUILD_DIR)/krnl_incr.xclbin emconfig

.PHONY: host
host: $(EXECUTABLE)

.PHONY: build
build: check-vitis check-device $(BUILD_DIR)/krnl_incr.xclbin

.PHONY: xclbin
xclbin: build

############################## Setting Rules for Binary Containers (Building Kernels) ##############################
$(TEMP_DIR)/mem_read1.xo: ../host/mem_read1.cpp
	mkdir -p $(TEMP_DIR)
	v++ $(VPP_FLAGS) -c -k mem_read1 --temp_dir $(TEMP_DIR)  -I'$(<D)' -o'$@' '$<'
$(TEMP_DIR)/mem_read2.xo: ../host/mem_read2.cpp
	mkdir -p $(TEMP_DIR)
	v++ $(VPP_FLAGS) -c -k mem_read2 --temp_dir $(TEMP_DIR)  -I'$(<D)' -o'$@' '$<'
$(TEMP_DIR)/mem_read3.xo: ../host/mem_read3.cpp
	mkdir -p $(TEMP_DIR)
	v++ $(VPP_FLAGS) -c -k mem_read3 --temp_dir $(TEMP_DIR)  -I'$(<D)' -o'$@' '$<'

$(TEMP_DIR)/increment.xo: ../host/top.cpp $(OPERATORS_SRC)
	mkdir -p $(TEMP_DIR)
	echo $+
	v++ $(VPP_FLAGS) -c -k increment --temp_dir $(TEMP_DIR) -D$(ACCEL) -I$(XILINX_VIVADO)/include -I'$(<D)' -o'$@' $^


$(TEMP_DIR)/mem_write1.xo: ../host/mem_write1.cpp
	mkdir -p $(TEMP_DIR)
	v++ $(VPP_FLAGS) -c -k mem_write1 --temp_dir $(TEMP_DIR)  -I'$(<D)' -o'$@' '$<'
$(TEMP_DIR)/mem_write2.xo: ../host/mem_write2.cpp
	mkdir -p $(TEMP_DIR)
	v++ $(VPP_FLAGS) -c -k mem_write2 --temp_dir $(TEMP_DIR)  -I'$(<D)' -o'$@' '$<'
$(TEMP_DIR)/mem_write3.xo: ../host/mem_write3.cpp
	mkdir -p $(TEMP_DIR)
	v++ $(VPP_FLAGS) -c -k mem_write3 --temp_dir $(TEMP_DIR)  -I'$(<D)' -o'$@' '$<'

$(BUILD_DIR)/krnl_incr.xclbin:   $(TEMP_DIR)/mem_read1.xo $(TEMP_DIR)/increment.xo $(TEMP_DIR)/mem_write1.xo $(TEMP_DIR)/mem_read2.xo $(TEMP_DIR)/mem_write2.xo $(TEMP_DIR)/mem_read3.xo $(TEMP_DIR)/mem_write3.xo
	mkdir -p $(BUILD_DIR)
	v++ $(VPP_FLAGS) -l $(VPP_LDFLAGS) --temp_dir $(TEMP_DIR) $(VPP_LDFLAGS_krnl_incr) --vivado.synth.jobs $(shell nproc) --vivado.impl.jobs $(shell nproc) -o'$(LINK_OUTPUT)' $(+)
	v++ -p $(LINK_OUTPUT) $(VPP_FLAGS) --package.out_dir $(PACKAGE_OUT) --vivado.synth.jobs $(shell nproc) --vivado.impl.jobs $(shell nproc) -o $(BUILD_DIR)/krnl_incr.xclbin

############################## Setting Rules for Host (Building Host Executable) ##############################
$(EXECUTABLE): $(HOST_SRCS) $(img_obj) | check-xrt
	g++ -o $@ $^ $(CXXFLAGS) $(LDFLAGS)

$(img_obj):$(SRC_DIR)/%.o:$(SRC_DIR)/%.cpp 
	g++ -Wall -g -std=c++11 -c $^ -o $@


emconfig:$(EMCONFIG_DIR)/emconfig.json
$(EMCONFIG_DIR)/emconfig.json:
	emconfigutil --platform $(PLATFORM) --od $(EMCONFIG_DIR)

############################## Setting Essential Checks and Running Rules ##############################
run: all
ifeq ($(TARGET),$(filter $(TARGET),sw_emu hw_emu))
	cp -rf $(EMCONFIG_DIR)/emconfig.json .
	XCL_EMULATION_MODE=$(TARGET) ./$(EXECUTABLE) $(CMD_ARGS)

else
	$(EXECUTABLE) $(CMD_ARGS)
endif

.PHONY: test
test: $(EXECUTABLE)
ifeq ($(TARGET),$(filter $(TARGET),sw_emu hw_emu))
	XCL_EMULATION_MODE=$(TARGET) $(EXECUTABLE) $(CMD_ARGS)
else
	$(EXECUTABLE) $(CMD_ARGS)
endif

############################## Cleaning Rules ##############################
# Cleaning stuff
clean:
	-$(RMDIR) $(EXECUTABLE) $(XCLBIN)/{*sw_emu*,*hw_emu*} 
	-$(RMDIR) profile_* TempConfig system_estimate.xtxt *.rpt *.csv 
	-$(RMDIR) src/*.ll *v++* .Xil emconfig.json dltmp* xmltmp* *.log *.jou *.wcfg *.wdb

cleanall: clean
	-$(RMDIR) build_dir*
	-$(RMDIR) package.*
	-$(RMDIR) _x* *xclbin.run_summary qemu-memory-_* emulation _vimage pl* start_simulation.sh *.xclbin
	-$(RMDIR) .ipcache
	-$(RMDIR) .run
	-$(RMDIR) halout

