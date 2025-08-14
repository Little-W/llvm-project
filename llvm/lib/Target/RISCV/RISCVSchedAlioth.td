//==- RISCVSchedAlioth.td - Alioth Scheduling Definitions ----*- tablegen -*-=//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Alioth machine model for scheduling and other instruction cost heuristics.
// Based on single-issue in-order pipeline with separate load/store unit,
// dual integer multiplication units, dual integer division units, and
// unified floating-point unit. Supports RV32IMFD.
//===----------------------------------------------------------------------===//

def AliothModel : SchedMachineModel {
  let MicroOpBufferSize = 0; // Alioth is in-order.
  let IssueWidth = 1;        // Single-issue pipeline.
  let LoadLatency = 2;       // Load latency is 2 cycles.
  let MispredictPenalty = 5; // Branch misprediction penalty.
  let CompleteModel = false;
  let UnsupportedFeatures = [
    HasStdExtA, HasStdExtZbkb, HasStdExtZbkc, HasStdExtZbkx,
    HasStdExtZcmt, HasStdExtZknd, HasStdExtZkne,
    HasStdExtZknh, HasStdExtZksed, HasStdExtZksh,
    HasStdExtZkr, HasVInstructions, HasVInstructionsI64
  ];
}

//===----------------------------------------------------------------------===//
// Instruction Scheduling Definitions
//===----------------------------------------------------------------------===//

let SchedModel = AliothModel in {

  //===----------------------------------------------------------------------===//
  // Define each kind of processor resource and number available.
  //===----------------------------------------------------------------------===//

  // Modeling each pipeline resource using BufferSize = 0 since Alioth is in-order.
  let BufferSize = 0 in {
    def AliothUnitALU    : ProcResource<1>; // Integer execution pipeline
    def AliothUnitMem    : ProcResource<1>; // Load/Store unit
    def AliothUnitBranch : ProcResource<1>; // Branch unit
    def AliothUnitFPU    : ProcResource<1>; // Floating-point unit
    def AliothUnitWB     : ProcResource<1>; // Write-back pipeline
    def AliothUnitIDiv0  : ProcResource<1>; // Integer division unit 0
    def AliothUnitIDiv1  : ProcResource<1>; // Integer division unit 1
  }

  // Use either division unit
  def AliothUnitIDivEither : ProcResGroup<[AliothUnitIDiv0, AliothUnitIDiv1]>;

  //===----------------------------------------------------------------------===//
  // Integer ALU Operations (1 cycle)
  //===----------------------------------------------------------------------===//

  // Basic ALU operations - 1 cycle latency
  def : WriteRes<WriteIALU32, [AliothUnitALU, AliothUnitWB]>;
  def : WriteRes<WriteIALU, [AliothUnitALU, AliothUnitWB]>;
  def : WriteRes<WriteShiftImm32, [AliothUnitALU, AliothUnitWB]>;
  def : WriteRes<WriteShiftImm, [AliothUnitALU, AliothUnitWB]>;
  def : WriteRes<WriteShiftReg32, [AliothUnitALU, AliothUnitWB]>;
  def : WriteRes<WriteShiftReg, [AliothUnitALU, AliothUnitWB]>;
  def : WriteRes<WriteNop, [AliothUnitALU, AliothUnitWB]>;

  //===----------------------------------------------------------------------===//
  // Branch Operations
  //===----------------------------------------------------------------------===//

  def : WriteRes<WriteJmp, [AliothUnitBranch]> { let Latency = 5; }
  def : WriteRes<WriteJal, [AliothUnitBranch]> { let Latency = 2; }
  def : WriteRes<WriteJalr, [AliothUnitBranch]> { let Latency = 5; }

  //===----------------------------------------------------------------------===//
  // Memory Operations
  //===----------------------------------------------------------------------===//

  // Load operations - 2 cycles latency
  let Latency = 2 in {
    def : WriteRes<WriteLDB, [AliothUnitMem]> { let Latency = 2; }
    def : WriteRes<WriteLDH, [AliothUnitMem]> { let Latency = 2; }
    def : WriteRes<WriteLDW, [AliothUnitMem]> { let Latency = 2; }
    def : WriteRes<WriteLDD, [AliothUnitMem]> { let Latency = 2; }
    def : WriteRes<WriteFLD32, [AliothUnitMem]> { let Latency = 2; }
    def : WriteRes<WriteFLD64, [AliothUnitMem]> { let Latency = 2; }
  }

  // Store operations - 1 cycle
  def : WriteRes<WriteSTB, [AliothUnitMem]>;
  def : WriteRes<WriteSTH, [AliothUnitMem]>;
  def : WriteRes<WriteSTW, [AliothUnitMem]>;
  def : WriteRes<WriteSTD, [AliothUnitMem]>;
  def : WriteRes<WriteFST32, [AliothUnitMem]>;
  def : WriteRes<WriteFST64, [AliothUnitMem]>;

  //===----------------------------------------------------------------------===//
  // Integer Multiplication (4 cycles, pipelined)
  //===----------------------------------------------------------------------===//

  let Latency = 4 in {
    def : WriteRes<WriteIMul, [AliothUnitALU]> {
      let Latency = 4;
      let ReleaseAtCycles = [1]; // Pipelined operation
    }
    def : WriteRes<WriteIMul32, [AliothUnitALU]> {
      let Latency = 4;
      let ReleaseAtCycles = [1]; // Pipelined operation
    }
  }

  //===----------------------------------------------------------------------===//
  // Integer Division (34 cycles for 32-bit, dual units)
  //===----------------------------------------------------------------------===//

  def : WriteRes<WriteIDiv32, [AliothUnitIDivEither]> {
    let Latency = 34;
    let ReleaseAtCycles = [34];
  }
  def : WriteRes<WriteIDiv, [AliothUnitIDivEither]> {
    let Latency = 34;
    let ReleaseAtCycles = [34];
  }
  def : WriteRes<WriteIRem32, [AliothUnitIDivEither]> {
    let Latency = 34;
    let ReleaseAtCycles = [34];
  }
  def : WriteRes<WriteIRem, [AliothUnitIDivEither]> {
    let Latency = 34;
    let ReleaseAtCycles = [34];
  }

  //===----------------------------------------------------------------------===//
  // Floating-Point Operations
  //===----------------------------------------------------------------------===//

  // FP transfer/move/comparison/class/sign injection - 3 cycles
  let Latency = 3 in {
    def : WriteRes<WriteFMovF32ToI32, [AliothUnitFPU]> {
      let Latency = 3;
      let ReleaseAtCycles = [2];
    }
    def : WriteRes<WriteFMovI32ToF32, [AliothUnitFPU]> {
      let Latency = 3;
      let ReleaseAtCycles = [2];
    }
    def : WriteRes<WriteFMovF64ToI64, [AliothUnitFPU]> {
      let Latency = 3;
      let ReleaseAtCycles = [2];
    }
    def : WriteRes<WriteFMovI64ToF64, [AliothUnitFPU]> {
      let Latency = 3;
      let ReleaseAtCycles = [2];
    }
    def : WriteRes<WriteFCmp32, [AliothUnitFPU]> {
      let Latency = 3;
      let ReleaseAtCycles = [2];
    }
    def : WriteRes<WriteFCmp64, [AliothUnitFPU]> {
      let Latency = 3;
      let ReleaseAtCycles = [2];
    }
    def : WriteRes<WriteFClass32, [AliothUnitFPU]> {
      let Latency = 3;
      let ReleaseAtCycles = [2];
    }
    def : WriteRes<WriteFClass64, [AliothUnitFPU]> {
      let Latency = 3;
      let ReleaseAtCycles = [2];
    }
    def : WriteRes<WriteFSGNJ32, [AliothUnitFPU]> {
      let Latency = 3;
      let ReleaseAtCycles = [2];
    }
    def : WriteRes<WriteFSGNJ64, [AliothUnitFPU]> {
      let Latency = 3;
      let ReleaseAtCycles = [2];
    }
  }

  // FP min/max - 4 cycles
  let Latency = 4 in {
    def : WriteRes<WriteFMinMax32, [AliothUnitFPU]> {
      let Latency = 4;
      let ReleaseAtCycles = [3];
    }
    def : WriteRes<WriteFMinMax64, [AliothUnitFPU]> {
      let Latency = 4;
      let ReleaseAtCycles = [3];
    }
  }

  // FP conversion from float to integer - 6 cycles
  let Latency = 6 in {
    def : WriteRes<WriteFCvtF32ToI32, [AliothUnitFPU]> {
      let Latency = 6;
      let ReleaseAtCycles = [5];
    }
    def : WriteRes<WriteFCvtF32ToI64, [AliothUnitFPU]> {
      let Latency = 6;
      let ReleaseAtCycles = [5];
    }
    def : WriteRes<WriteFCvtF64ToI32, [AliothUnitFPU]> {
      let Latency = 6;
      let ReleaseAtCycles = [5];
    }
    def : WriteRes<WriteFCvtF64ToI64, [AliothUnitFPU]> {
      let Latency = 6;
      let ReleaseAtCycles = [5];
    }
  }

  // FP conversion from integer to float and float to float - 7 cycles
  let Latency = 7 in {
    def : WriteRes<WriteFCvtI32ToF32, [AliothUnitFPU]> {
      let Latency = 7;
      let ReleaseAtCycles = [6];
    }
    def : WriteRes<WriteFCvtI32ToF64, [AliothUnitFPU]> {
      let Latency = 7;
      let ReleaseAtCycles = [6];
    }
    def : WriteRes<WriteFCvtI64ToF32, [AliothUnitFPU]> {
      let Latency = 7;
      let ReleaseAtCycles = [6];
    }
    def : WriteRes<WriteFCvtI64ToF64, [AliothUnitFPU]> {
      let Latency = 7;
      let ReleaseAtCycles = [6];
    }
    def : WriteRes<WriteFCvtF32ToF64, [AliothUnitFPU]> {
      let Latency = 7;
      let ReleaseAtCycles = [6];
    }
    def : WriteRes<WriteFCvtF64ToF32, [AliothUnitFPU]> {
      let Latency = 7;
      let ReleaseAtCycles = [6];
    }
  }

  // FP addition/subtraction - 9 cycles
  let Latency = 9 in {
    def : WriteRes<WriteFAdd32, [AliothUnitFPU]> {
      let Latency = 9;
      let ReleaseAtCycles = [8];
    }
    def : WriteRes<WriteFAdd64, [AliothUnitFPU]> {
      let Latency = 9;
      let ReleaseAtCycles = [8];
    }
  }

  // FP multiplication and fused multiply-add - 11 cycles
  let Latency = 11 in {
    def : WriteRes<WriteFMul32, [AliothUnitFPU]> {
      let Latency = 11;
      let ReleaseAtCycles = [10];
    }
    def : WriteRes<WriteFMul64, [AliothUnitFPU]> {
      let Latency = 11;
      let ReleaseAtCycles = [10];
    }
    def : WriteRes<WriteFMA32, [AliothUnitFPU]> {
      let Latency = 11;
      let ReleaseAtCycles = [10];
    }
    def : WriteRes<WriteFMA64, [AliothUnitFPU]> {
      let Latency = 11;
      let ReleaseAtCycles = [10];
    }
  }

  // FP division - 29 cycles
  let Latency = 29 in {
    def : WriteRes<WriteFDiv32, [AliothUnitFPU]> {
      let Latency = 29;
      let ReleaseAtCycles = [28];
    }
    def : WriteRes<WriteFDiv64, [AliothUnitFPU]> {
      let Latency = 29;
      let ReleaseAtCycles = [28];
    }
  }

  // FP square root - 35 cycles
  let Latency = 35 in {
    def : WriteRes<WriteFSqrt32, [AliothUnitFPU]> {
      let Latency = 35;
      let ReleaseAtCycles = [34];
    }
    def : WriteRes<WriteFSqrt64, [AliothUnitFPU]> {
      let Latency = 35;
      let ReleaseAtCycles = [34];
    }
  }

  //===----------------------------------------------------------------------===//
  // CSR Operations
  //===----------------------------------------------------------------------===//

  def : WriteRes<WriteCSR, [AliothUnitALU, AliothUnitWB]>;

  //===----------------------------------------------------------------------===//
  // Bypass and advance definitions
  //===----------------------------------------------------------------------===//

  // Define read advance for all read operations (0 means no advance needed)
  def : ReadAdvance<ReadJmp, 0>;
  def : ReadAdvance<ReadJalr, 0>;
  def : ReadAdvance<ReadCSR, 0>;

  def : ReadAdvance<ReadStoreData, 0>;
  def : ReadAdvance<ReadFStoreData, 0>;
  def : ReadAdvance<ReadMemBase, 0>;
  def : ReadAdvance<ReadFMemBase, 0>;
  def : ReadAdvance<ReadIALU, 0>;
  def : ReadAdvance<ReadIALU32, 0>;
  def : ReadAdvance<ReadShiftImm, 0>;
  def : ReadAdvance<ReadShiftImm32, 0>;
  def : ReadAdvance<ReadShiftReg, 0>;
  def : ReadAdvance<ReadShiftReg32, 0>;
  def : ReadAdvance<ReadIDiv, 0>;
  def : ReadAdvance<ReadIDiv32, 0>;
  def : ReadAdvance<ReadIRem, 0>;
  def : ReadAdvance<ReadIRem32, 0>;
  def : ReadAdvance<ReadIMul, 0>;
  def : ReadAdvance<ReadIMul32, 0>;

  // Floating-point operations
  def : ReadAdvance<ReadFAdd32, 0>;
  def : ReadAdvance<ReadFAdd64, 0>;
  def : ReadAdvance<ReadFMul32, 0>;
  def : ReadAdvance<ReadFMul64, 0>;
  def : ReadAdvance<ReadFMA32, 0>;
  def : ReadAdvance<ReadFMA32Addend, 0>;
  def : ReadAdvance<ReadFMA64, 0>;
  def : ReadAdvance<ReadFMA64Addend, 0>;
  def : ReadAdvance<ReadFDiv32, 0>;
  def : ReadAdvance<ReadFDiv64, 0>;
  def : ReadAdvance<ReadFSqrt32, 0>;
  def : ReadAdvance<ReadFSqrt64, 0>;
  def : ReadAdvance<ReadFCmp32, 0>;
  def : ReadAdvance<ReadFCmp64, 0>;
  def : ReadAdvance<ReadFSGNJ32, 0>;
  def : ReadAdvance<ReadFSGNJ64, 0>;
  def : ReadAdvance<ReadFMinMax32, 0>;
  def : ReadAdvance<ReadFMinMax64, 0>;
  def : ReadAdvance<ReadFCvtF32ToI32, 0>;
  def : ReadAdvance<ReadFCvtF32ToI64, 0>;
  def : ReadAdvance<ReadFCvtF64ToI32, 0>;
  def : ReadAdvance<ReadFCvtF64ToI64, 0>;
  def : ReadAdvance<ReadFCvtI32ToF32, 0>;
  def : ReadAdvance<ReadFCvtI32ToF64, 0>;
  def : ReadAdvance<ReadFCvtI64ToF32, 0>;
  def : ReadAdvance<ReadFCvtI64ToF64, 0>;
  def : ReadAdvance<ReadFCvtF32ToF64, 0>;
  def : ReadAdvance<ReadFCvtF64ToF32, 0>;
  def : ReadAdvance<ReadFMovF32ToI32, 0>;
  def : ReadAdvance<ReadFMovI32ToF32, 0>;
  def : ReadAdvance<ReadFMovF64ToI64, 0>;
  def : ReadAdvance<ReadFMovI64ToF64, 0>;
  def : ReadAdvance<ReadFClass32, 0>;
  def : ReadAdvance<ReadFClass64, 0>;

  //===----------------------------------------------------------------------===//
  // Unsupported extensions
  //===----------------------------------------------------------------------===//

  defm : UnsupportedSchedQ;
  defm : UnsupportedSchedV;
  defm : UnsupportedSchedZabha;
  defm : UnsupportedSchedZba;
  defm : UnsupportedSchedZbb;
  defm : UnsupportedSchedZbc;
  defm : UnsupportedSchedZbs;
  defm : UnsupportedSchedZbkb;
  defm : UnsupportedSchedZbkx;
  defm : UnsupportedSchedZfa;
  defm : UnsupportedSchedZfhmin;
  defm : UnsupportedSchedSFB;
  defm : UnsupportedSchedXsfvcp;
  defm : UnsupportedSchedZvk;
  defm : UnsupportedSchedA;

} // SchedModel = AliothModel