! RUN: flang-new -fc1 -fcheck=bounds -emit-hlfir %s -o - | FileCheck %s
! RUN: flang-new -fc1 -emit-hlfir %s -o - | FileCheck %s --check-prefix=NO-CHECK

! Test Case: TC-01 Assumed-Shape Scalar Index OOB
subroutine test_assumed_shape(a, n)
  integer :: a(:)
  integer :: n
  
  ! CHECK: %[[C1:.*]] = arith.constant 1 : i64
  ! CHECK: %[[EXT:.*]] = arith.extsi %{{.*}} : i{{.*}} to i64
  ! CHECK: %[[SUB:.*]] = arith.subi
  ! CHECK: %[[SLT:.*]] = arith.cmpi slt, %{{.*}}, %[[C1]]
  ! CHECK: %[[SGT:.*]] = arith.cmpi sgt, %{{.*}}, %[[SUB]]
  ! CHECK: %[[OOB:.*]] = arith.ori %[[SLT]], %[[SGT]]
  ! CHECK: scf.if %[[OOB]] {
  ! CHECK:   func.call @_FortranABoundsCheck
  ! CHECK: }
  ! CHECK: hlfir.designate %{{.*}}
  
  ! NO-CHECK-NOT: func.call @_FortranABoundsCheck
  ! NO-CHECK: hlfir.designate %{{.*}}
  a(n) = 1
end subroutine test_assumed_shape

! Test Case: TC-05 Allocatable Array OOB
subroutine test_allocatable()
  integer, allocatable :: arr(:)
  allocate(arr(10))
  
  ! CHECK: scf.if %{{.*}} {
  ! CHECK:   func.call @_FortranABoundsCheck
  ! CHECK: }
  arr(15) = 2
end subroutine test_allocatable
