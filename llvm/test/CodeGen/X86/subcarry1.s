	.text
	.file	"subcarry1.ll"
	.globl	subcarry_ult_2x64_2             # -- Begin function subcarry_ult_2x64_2
	.p2align	4, 0x90
	.type	subcarry_ult_2x64_2,@function
subcarry_ult_2x64_2:                    # @subcarry_ult_2x64_2
# %bb.0:                                # %entry
	cmpq	%rdx, %rdi
	setb	%dl
	cmpq	%rcx, %rsi
	setb	%cl
	sete	%al
	andb	%dl, %al
	orb	%cl, %al
	retq
.Lfunc_end0:
	.size	subcarry_ult_2x64_2, .Lfunc_end0-subcarry_ult_2x64_2
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
