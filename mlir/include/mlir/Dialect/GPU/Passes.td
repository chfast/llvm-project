//===-- Passes.td - GPU pass definition file ---------------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef MLIR_DIALECT_GPU_PASSES
#define MLIR_DIALECT_GPU_PASSES

include "mlir/Pass/PassBase.td"

def GpuKernelOutlining : Pass<"gpu-kernel-outlining", "ModuleOp"> {
  let summary = "Outline gpu.launch bodies to kernel functions";
  let constructor = "mlir::createGpuKernelOutliningPass()";
  let dependentDialects = ["mlir::DLTIDialect"];
}

def GpuAsyncRegionPass : FunctionPass<"gpu-async-region"> {
  let summary = "Make GPU ops async";
  let constructor = "mlir::createGpuAsyncRegionPass()";
  let dependentDialects = ["async::AsyncDialect"];
}

#endif // MLIR_DIALECT_GPU_PASSES
