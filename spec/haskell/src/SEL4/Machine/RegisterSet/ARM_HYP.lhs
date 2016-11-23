%
% Copyright 2014, General Dynamics C4 Systems
%
% This software may be distributed and modified according to the terms of
% the GNU General Public License version 2. Note that NO WARRANTY is provided.
% See "LICENSE_GPLv2.txt" for details.
%
% @TAG(GD_GPL)
%

\begin{impdetails}

> {-# LANGUAGE CPP, GeneralizedNewtypeDeriving #-}

\end{impdetails}

This module defines the ARM register set.

> module SEL4.Machine.RegisterSet.ARM_HYP where

\begin{impdetails}

> import qualified Data.Word
> import Data.Array
> import Data.Bits

\end{impdetails}

> data Register =
>     R0 | R1 | R2 | R3 | R4 | R5 | R6 | R7 | R8 | R9 | SL | FP | IP | SP |
>     LR | LR_svc | FaultInstruction | CPSR | TPIDRURW
>     deriving (Eq, Enum, Bounded, Ord, Ix, Show)

> type Word = Data.Word.Word32

> capRegister = R0
> msgInfoRegister = R1
> msgRegisters = [R2 .. R5]
> badgeRegister = R0
> frameRegisters = FaultInstruction : SP : CPSR : [R0, R1] ++ [R8 .. IP]
> gpRegisters = [R2, R3, R4, R5, R6, R7, LR]
> tpidrurwRegister = TPIDRURW
> exceptionMessage = [FaultInstruction, SP, CPSR]
> syscallMessage = [R0 .. R7] ++ [FaultInstruction, SP, LR, CPSR]

#ifdef CONFIG_ARM_HYPERVISOR_SUPPORT
> elr_hyp = LR_svc
#endif

> initContext :: [(Register, Word)]
> initContext = [(CPSR,0x150)] -- User mode

> sanitiseRegister :: Register -> Word -> Word
#ifndef CONFIG_ARM_HYPERVISOR_SUPPORT
> sanitiseRegister CPSR v = (v .&. 0xf8000000) .|. 0x150
#else
> sanitiseRegister CPSR v =
>     if v .&. 0x1f == 0x1f then v else (v .&. 0xf8000000) .|. 0x150
#endif
> sanitiseRegister _ v = v

