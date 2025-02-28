//===-- BufferizableOpInterface.td - Compreh. Bufferize ----*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef BUFFERIZABLE_OP_INTERFACE
#define BUFFERIZABLE_OP_INTERFACE

include "mlir/IR/OpBase.td"

def BufferizableOpInterface : OpInterface<"BufferizableOpInterface"> {
  let description = [{
    An op interface for Comprehensive Bufferization. Ops that implement this
    interface can be bufferized using Comprehensive Bufferization.
  }];
  let cppNamespace = "::mlir::linalg::comprehensive_bufferize";
  let methods = [
      InterfaceMethod<
        /*desc=*/[{
          Return `true` if the given OpOperand bufferizes to a memory read. This
          method will never be called on OpOperands that do not have a tensor
          type.

          Note: It is always safe to consider an OpOperand as a memory read,
          even if it does actually not read; however, this can introduce
          unnecessary out-of-place bufferization decisions. The analysis of
          Comprehensive Bufferize considers OpOperands of unknown ops (that do
          not implement this interface) as reading OpOperands.
        }],
        /*retType=*/"bool",
        /*methodName=*/"bufferizesToMemoryRead",
        /*args=*/(ins "OpOperand &":$opOperand,
                      "BufferizationState &":$state),
        /*methodBody=*/"",
        /*defaultImplementation=*/[{
          // Does not have to be implemented for ops without tensor OpOperands.
          llvm_unreachable("bufferizesToMemoryRead not implemented");
         }]
      >,
      InterfaceMethod<
        /*desc=*/[{
          Return `true` if the given OpOperand bufferizes to a memory write.

          This method will never be called on OpOperands that do not have a
          tensor type.

          This method will never be called on OpOperands that do not have an
          aliasing OpResult. Intuitively, it does not make sense for an
          OpOperand to bufferize to a memory write without returning an aliasing
          tensor, because the write would have no visible effect outside of the
          op.

          Note: It is always safe to consider an OpOperand as a memory write,
          even if it does actually not write; however, this can introduce
          unnecessary out-of-place bufferization decisions. The analysis of
          Comprehensive Bufferize considers OpOperands of unknown ops (that do
          not implement this interface) as writing OpOperands.
        }],
        /*retType=*/"bool",
        /*methodName=*/"bufferizesToMemoryWrite",
        /*args=*/(ins "OpOperand &":$opOperand,
                      "BufferizationState &":$state),
        /*methodBody=*/"",
        /*defaultImplementation=*/[{
          // Does not have to be implemented for ops without tensor OpOperands.
          // Does not have to be implemented for OpOperands that do not have an
          // aliasing OpResult.
          llvm_unreachable("bufferizesToMemoryWrite not implemented");
         }]
      >,
      InterfaceMethod<
          /*desc=*/[{
            Return `true` if the given OpResult is a memory write. This is the
            case if in the following cases:

            * The corresponding aliasing OpOperand bufferizes to a memory write.
            * Or: There is no corresponding aliasing OpOperand.

            If the OpResult has multiple aliasing OpOperands, this method
            returns `true` if at least one of them bufferizes to a memory write.
          }],
          /*retType=*/"bool",
          /*methodName=*/"isMemoryWrite",
          /*args=*/(ins "OpResult":$opResult,
                        "BufferizationState &":$state),
          /*methodBody=*/"",
          /*defaultImplementation=*/[{
            auto bufferizableOp =
                cast<BufferizableOpInterface>($_op.getOperation());
            SmallVector<OpOperand*> opOperands =
              bufferizableOp.getAliasingOpOperand(opResult, state);
            if (opOperands.empty())
              return true;
            return llvm::any_of(
                opOperands,
                [&](OpOperand *operand) {
                  return bufferizableOp.bufferizesToMemoryWrite(*operand,
                                                                state);
                });
          }]
      >,
      InterfaceMethod<
        /*desc=*/[{
          Return `true` if the given OpResult must bufferize in-place with its
          corresponding aliasing OpOperand. Alias sets and inplace attributes
          will be set up accordingly before making any other bufferization
          decisions. This method will never be called on OpResults that do not
          have a tensor type.

          Note: This method may not return `true` if the given OpResult does not
          have an aliasing OpOperand.
        }],
        /*retType=*/"bool",
        /*methodName=*/"mustBufferizeInPlace",
        /*args=*/(ins "OpResult":$opResult,
                      "BufferizationState &":$state),
        /*methodBody=*/"",
        /*defaultImplementation=*/[{
          return false;
        }]
      >,
      InterfaceMethod<
        /*desc=*/[{
          Return the OpResult that aliases with a given OpOperand when
          bufferized in-place. This method will never be called on OpOperands
          that do not have a tensor type.
        }],
        /*retType=*/"OpResult",
        /*methodName=*/"getAliasingOpResult",
        /*args=*/(ins "OpOperand &":$opOperand,
                      "BufferizationState &":$state),
        /*methodBody=*/"",
        /*defaultImplementation=*/[{
          // Does not have to be implemented for ops without tensor OpOperands.
          llvm_unreachable("getAliasingOpResult not implemented");
        }]
      >,
      InterfaceMethod<
        /*desc=*/[{
          Return the OpOperands that alias with a given OpResult when
          bufferized in-place. This method will never be called on OpResults
          that do not have a tensor type.

          By default, this method is the inverse of `getAliasingOpResult`. Ops
          with a region that yield values may want to override this method to
          return the OpOperands that are yielded by the terminator.

          Note: This method can return multiple OpOperands, indicating that the
          given OpResult may at runtime alias with any of the OpOperands. This
          is useful for branches and for ops such as `std.select`.
        }],
        /*retType=*/"SmallVector<OpOperand *>",
        /*methodName=*/"getAliasingOpOperand",
        /*args=*/(ins "OpResult":$opResult,
                      "BufferizationState &":$state),
        /*methodBody=*/"",
        /*defaultImplementation=*/[{
          assert(opResult.getType().isa<TensorType>() &&
                 "expected OpResult with tensor type");
          SmallVector<OpOperand *> result;
          auto bufferizableOp =
              cast<BufferizableOpInterface>($_op.getOperation());
          for (OpOperand &opOperand : $_op.getOperation()->getOpOperands()) {
            if (!opOperand.get().getType().isa<TensorType>())
              continue;
            if (bufferizableOp.getAliasingOpResult(opOperand, state) ==
                    opResult)
              result.push_back(&opOperand);
          }
          return result;
        }]
      >,
      InterfaceMethod<
        /*desc=*/[{
          Return the buffer relation between the given OpResult and its aliasing
          OpOperands when bufferized in-place. Most OpOperands have an
          "equivalence" relation. This method will never be called on OpResults
          that do not have a tensor type. It will also never be called on
          OpResults that do not have at least one aliasing OpOperand.

          TODO: Support other relations such as "OpOperand is included in
          OpResult".
        }],
        /*retType=*/"BufferRelation",
        /*methodName=*/"bufferRelation",
        /*args=*/(ins "OpResult":$opResult,
                      "const BufferizationAliasInfo &":$aliasInfo,
                      "BufferizationState &":$state),
        /*methodBody=*/"",
        /*defaultImplementation=*/[{
          // Does not have to be implemented for ops without tensor OpResults
          // that have an aliasing OpOperand.
          llvm_unreachable("bufferRelation not implemented");
        }]
      >,
      InterfaceMethod<
        /*desc=*/[{
          Bufferize this op, i.e., rewrite it into a memref-based equivalent.
          Tensor values should be mapped to buffer values using `state`.

          Implementations are required to required to bufferize nested ops
          before returning. Otherwise, nested ops will not be bufferized.

          This method will never be called on ops that do not have at least one
          tensor operand/result or a region.
        }],
        /*retType=*/"LogicalResult",
        /*methodName=*/"bufferize",
        /*args=*/(ins "OpBuilder &":$b,
                      "BufferizationState &":$state),
        /*methodBody=*/"",
        /*defaultImplementation=*/[{
          llvm_unreachable("bufferize not implemented");
          return failure();
        }]
      >,
      InterfaceMethod<
        /*desc=*/[{
          Return `true` if the given Value can be written to in-place. Value is
          either an OpResult of this operation or a BlockArgument of a block of
          this operation.

          Most OpResult buffers can be written to, but some ops such as
          ConstantOp may bufferize to non-writable (read-only) memory locations.
          Therefore, by default, this method returns `true` for OpResults. This
          method will never be called on OpResults that do not have a tensor
          type.

          Whether a BlockArgument can be written to or not depends on the
          operation. This method conservatively returns `false`. This method
          will never be called on BlockArguments that do not have a tensor type.
        }],
        /*retType=*/"bool",
        /*methodName=*/"isWritable",
        /*args=*/(ins "Value":$value,
                      "BufferizationState &":$state),
        /*methodBody=*/"",
        /*defaultImplementation=*/[{
          return value.isa<OpResult>();
        }]
      >,
      InterfaceMethod<
        /*desc=*/[{
          Return `true` if the op is an allocation hoisting barrier. Buffer
          allocations will never be beyond such ops. E.g., ops with certain
          parallel semantics may be allocation hoisting barriers. The majority
          of ops, however, is not a barrier. Therefore, this method returns
          `false` by default.
        }],
        /*retType=*/"bool",
        /*methodName=*/"isAllocationHoistingBarrier",
        /*args=*/(ins),
        /*methodBody=*/"",
        /*defaultImplementation=*/[{
          return false;
        }]
      >,
      InterfaceMethod<
        /*desc=*/[{
          Return `true` if the `uRead` and `uWrite` do not constitute a RaW
          conflict. If they are conflicting or if it is unknown whether they are
          conflicting, return `false`. This method will never be called with
          OpOperands that do not have a tensor type. At least one of the two
          given OpOperands belongs to this operation.

          This method can be implemented to specify custom RaW analysis rules.
          If this method returns `true` the given OpOperands are not considered
          to be conflicting and do not force out-of-place bufferization. (There
          may still be other conflicts that do.)
        }],
        /*retType=*/"bool",
        /*methodName=*/"isNotConflicting",
        /*args=*/(ins "OpOperand *":$uRead,
                      "OpOperand *":$uWrite,
                      "BufferizationState &":$state,
                      "const BufferizationAliasInfo &":$aliasInfo),
        /*methodBody=*/"",
        /*defaultImplementation=*/[{
          return false;
        }]
      >
  ];

  let extraClassDeclaration = [{
    /// Return `true` if the given OpOperand creates an alias but does neither
    /// read nor write. This implies that `bufferizesToMemoryRead` and
    /// `bufferizesToMemoryWrite` must return `false`. This method will never
    /// be called on OpOperands that do not have a tensor type.
    ///
    /// Examples of such ops are `tensor.extract_slice` and `tensor.cast`.
    bool bufferizesToAliasOnly(OpOperand &opOperand,
                               BufferizationState &state) {
      auto bufferizableOp =
          cast<BufferizableOpInterface>(getOperation());
      return !bufferizableOp.bufferizesToMemoryRead(opOperand, state)
          && !bufferizableOp.bufferizesToMemoryWrite(opOperand, state)
          && static_cast<bool>(
              bufferizableOp.getAliasingOpResult(opOperand, state));
    }

    // TODO: The following two attributes should belong to the tensor dialect.
    // The corresponding verifier should also be in the tensor dialect.
    /// Attribute name used to mark region arguments that can be bufferized
    /// in-place during linalg comprehensive bufferization.
    constexpr const static ::llvm::StringLiteral
      kInplaceableAttrName = "linalg.inplaceable";

    /// Attribute name used to mark the bufferization layout for region
    /// arguments during linalg comprehensive bufferization.
    constexpr const static ::llvm::StringLiteral
      kBufferLayoutAttrName = "linalg.buffer_layout";
  }];
}

#endif  // BUFFERIZABLE_OP_INTERFACE
