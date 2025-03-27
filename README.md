# AXI_lite
The AXI4-Lite (Advanced eXtensible Interface Lite) protocol is a lightweight subset of AXI4, designed for simple, low-bandwidth memory-mapped communication. It is widely used for register access and peripheral control in SoC designs. Unlike full AXI4, AXI4-Lite does not support burst transactions, making it a straightforward, single-transfer protocol.

This project implements an AXI4-Lite Slave Interface in Verilog, handling read and write transactions using a finite state machine (FSM). The module ensures proper handshaking, memory management, and address validation, following AXI4-Lite protocol specifications. It includes error detection for invalid addresses and a structured testbench in SystemVerilog for thorough verification.

Key Features:
Designed and implemented an AXI Lite Slave module in Verilog using an FSM-based approach for efficient read/write transactions.

Implemented address validation and memory management for error handling and reliable data transfer.

Developed a testbench using SystemVerilog to verify AXI Lite protocol compliance and functional correctness.

This implementation ensures a robust and scalable AXI4-Lite interface, making it suitable for SoC-based memory-mapped peripheral designs
