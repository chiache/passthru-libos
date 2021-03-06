/* Copyright (C) 2014 Stony Brook University
   This file is part of Graphene Library OS.

   Graphene Library OS is free software: you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public License
   as published by the Free Software Foundation, either version 3 of the
   License, or (at your option) any later version.

   Graphene Library OS is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/*
 * syscall_trap.S
 *
 * This file contains the entry point of system call table in library OS.
 */

#include <shim_defs.h>
#include <asm-offsets.h>

        .global syscall_trap
        .type syscall_trap, @function
        .extern shim_table

syscall_trap:
        .cfi_startproc

        # Create shim_regs struct on the stack.
        pushfq

        # Under GDB, single-stepping sets Trap Flag (TP) of EFLAGS,
        # thus TP=1 is stored on pushfq above. Upon consequent popfq,
        # TP is 1, resulting in spurious trap. Reset TP here.
        andq $~0x100, (%rsp)

        cld
        pushq %rbp
        pushq %rbx
        pushq %rdi
        pushq %rsi
        pushq %rdx
        pushq %rcx
        pushq %r8
        pushq %r9
        pushq %r10
        pushq %r11
        pushq %r12
        pushq %r13
        pushq %r14
        pushq %r15
        leaq SHIM_REGS_SIZE - SHIM_REGS_R15(%rsp), %rbx
        pushq %rbx
        pushq %rax
        # shim_regs struct ends here.

        movq %rsp, %rbp
        .cfi_def_cfa_offset SHIM_REGS_SIZE
        .cfi_offset %rbp, -3 * 8    # saved_rbp is at CFA-24 (saved_rflags + saved_rbp)
        .cfi_def_cfa_register %rbp  # %rbp

        cmp $SYSCALLNR, %rax
        jae isundef

        leaq shim_table(%rip), %rbx
        movq (%rbx,%rax,8), %rbx
        cmp $0, %rbx
        je isundef

        /* Translating x86_64 kernel calling convention to user-space
         * calling convention */
        movq %r10, %rcx
        andq $~0xF, %rsp  # Required by System V AMD64 ABI.
        call *%rbx

ret:
        movq %rbp, %rsp
        addq $2 * 8, %rsp   # skip orig_rax and rsp
        popq %r15
        popq %r14
        popq %r13
        popq %r12
        popq %r11
        popq %r10
        popq %r9
        popq %r8
        popq %rcx
        popq %rdx
        popq %rsi
        popq %rdi
        popq %rbx
        popq %rbp
        .cfi_def_cfa %rsp, 2 * 8  # +8 for ret_addr, +8 for saved_rflags
        popfq
        .cfi_def_cfa_offset 8     # +8 for ret_addr
        retq

isundef:
        movq $-38, %rax  # ENOSYS
        jmp ret

        .cfi_endproc
        .size syscall_trap, .-syscall_trap
