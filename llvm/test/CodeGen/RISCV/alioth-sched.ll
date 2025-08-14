; RUN: llc -mtriple=riscv32 -mcpu=alioth-rv32 -o - < %s | FileCheck %s

; Test basic code generation for Alioth processor
; This test verifies that the Alioth scheduling model is properly loaded
; and can generate code for basic RISC-V instructions with IMFD extensions.

; CHECK-LABEL: test_alioth_basic:
; CHECK: add {{.*}}
; CHECK: mul {{.*}}
; CHECK: sub {{.*}}
define i32 @test_alioth_basic(i32 %a, i32 %b) {
entry:
  %add = add i32 %a, %b
  %mul = mul i32 %add, %a
  %sub = sub i32 %mul, %b
  ret i32 %sub
}

; CHECK-LABEL: test_alioth_fp:
; CHECK: fadd.s {{.*}}
; CHECK: fmul.s {{.*}}
; CHECK: fdiv.s {{.*}}
define float @test_alioth_fp(float %a, float %b) {
entry:
  %add = fadd float %a, %b
  %mul = fmul float %add, %a
  %div = fdiv float %mul, %b
  ret float %div
}

; CHECK-LABEL: test_alioth_fp64:
; CHECK: fadd.d {{.*}}
; CHECK: fmul.d {{.*}}
; CHECK: fsqrt.d {{.*}}
define double @test_alioth_fp64(double %a, double %b) {
entry:
  %add = fadd double %a, %b
  %mul = fmul double %add, %a
  %sqrt = call double @llvm.sqrt.f64(double %mul)
  ret double %sqrt
}

declare double @llvm.sqrt.f64(double)
