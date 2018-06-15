-- Copyright 2018, Data61, CSIRO
--
-- This software may be distributed and modified according to the terms of
-- the GNU General Public License version 2. Note that NO WARRANTY is provided.
-- See "LICENSE_GPLv2.txt" for details.
--
-- @TAG(DATA61_GPL)

-- This module contains operations on machine-specific object types.

module SEL4.Object.ObjectType.RISCV64 where

import SEL4.Machine.RegisterSet
import SEL4.Machine.Hardware.RISCV64
import SEL4.Model
import SEL4.Model.StateData.RISCV64
import SEL4.API.Types
import SEL4.API.Failures
import SEL4.API.Invocation.RISCV64 as ArchInv
import SEL4.Object.Structures
import SEL4.Kernel.VSpace.RISCV64

import Data.Bits
import Data.Word(Word16)
import Data.Array

-- The architecture-specific types and structures are qualified with the
-- "Arch.Types" and "Arch.Structures" prefixes, respectively. This is to avoid
-- namespace conflicts with the platform-independent modules.

import qualified SEL4.API.Types.RISCV64 as Arch.Types

{- Copying and Mutating Capabilities -}

deriveCap :: PPtr CTE -> ArchCapability -> KernelF SyscallError Capability
-- It is not possible to copy a page table or page directory capability unless
-- it has been mapped.
deriveCap _ (c@PageTableCap { capPTMappedAddress = Just _ }) = return $ ArchObjectCap c
deriveCap _ (PageTableCap { capPTMappedAddress = Nothing })
    = throw IllegalOperation
-- Page capabilities are copied without their mapping information, to allow
-- them to be mapped in multiple locations.
deriveCap _ (c@FrameCap {})
    = return $ ArchObjectCap $ c { capFMappedAddress = Nothing }
-- ASID capabilities can be copied without modification
deriveCap _ c@ASIDControlCap = return $ ArchObjectCap c
deriveCap _ (c@ASIDPoolCap {}) = return $ ArchObjectCap c

isCapRevocable :: Capability -> Capability -> Bool
isCapRevocable newCap srcCap = False

updateCapData :: Bool -> Word -> ArchCapability -> Capability
updateCapData _ _ c = ArchObjectCap c

-- these seem to refer to extraction of fields from seL4_CNode_CapData

cteRightsBits :: Int
cteRightsBits = 0

cteGuardBits :: Int
cteGuardBits = 58

-- Page capabilities have read and write permission bits, which are used to
-- restrict virtual memory accesses to their contents. Note that the ability to
-- map objects into a page table or page directory is granted by possession of
-- a capability to it; there is no specific permission bit restricting this
-- ability.
-- FIXME RISCV does not mask any rights unlike other platforms, investigate whether that is intentional

maskCapRights :: CapRights -> ArchCapability -> Capability
maskCapRights _ c = ArchObjectCap c

{- Deleting Capabilities -}

postCapDeletion :: ArchCapability -> Kernel ()
postCapDeletion c = error "FIXME RISCV TODO"

finaliseCap :: ArchCapability -> Bool -> Kernel (Capability, Capability)
finaliseCap = error "FIXME RISCV TODO"

-- FIXME RISCV TODO

{- Identifying Capabilities -}

sameRegionAs :: ArchCapability -> ArchCapability -> Bool
sameRegionAs = error "FIXME RISCV TODO"

isPhysicalCap :: ArchCapability -> Bool
isPhysicalCap ASIDControlCap = False
isPhysicalCap _ = True

sameObjectAs :: ArchCapability -> ArchCapability -> Bool
sameObjectAs = error "FIXME RISCV TODO"

-- FIXME RISCV TODO

{- Creating New Capabilities -}

-- Create an architecture-specific object.

-- % FIXME: it is not clear wheather we can have large device page

createObject :: ObjectType -> PPtr () -> Int -> Bool -> Kernel ArchCapability
createObject t regionBase _ isDevice =
    error "FIXME RISCV TODO"

{- Capability Invocation -}

decodeInvocation :: Word -> [Word] -> CPtr -> PPtr CTE ->
        ArchCapability -> [(Capability, PPtr CTE)] ->
        KernelF SyscallError ArchInv.Invocation
decodeInvocation label args capIndex slot cap extraCaps =
    error "FIXME RISCV TODO"

performInvocation :: ArchInv.Invocation -> KernelP [Word]
performInvocation = error "FIXME RISCV TODO"

{- Helper Functions -}

capUntypedPtr :: ArchCapability -> PPtr ()
capUntypedPtr (FrameCap { capFBasePtr = PPtr p }) = PPtr p
capUntypedPtr (PageTableCap { capPTBasePtr = PPtr p }) = PPtr p
capUntypedPtr ASIDControlCap = error "ASID control has no pointer"
capUntypedPtr (ASIDPoolCap { capASIDPool = PPtr p }) = PPtr p

asidPoolBits :: Int
asidPoolBits = 12

capUntypedSize :: ArchCapability -> Word
capUntypedSize (FrameCap {capFSize = sz}) = 1 `shiftL` pageBitsForSize sz
capUntypedSize (PageTableCap {}) = 1 `shiftL` ptBits
capUntypedSize (ASIDControlCap {}) = 0
capUntypedSize (ASIDPoolCap {}) = 1 `shiftL` asidPoolBits

-- No arch-specific thread deletion operations needed on RISC-V platform.

prepareThreadDelete :: PPtr TCB -> Kernel ()
prepareThreadDelete _ = return ()