`timescale 1ns / 1ps
`include "config.vh"

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "interface.sv"
`include "transaction.sv"
`include "sequencer.sv"
`include "stimulus.sv"
`include "driver.sv"
`include "monitor.sv"
`include "agent.sv"
`include "scoreboard.sv"
`include "env.sv"
`include "test.sv"

`include "darkpll.v"
`include "darkuart.v"
`include "darkriscv.v"
`include "darksocv.v"

`include "assertions.sv"
`include "top.sv"