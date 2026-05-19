! ==============================================================================
! Flang HLFIR-Aware Array Bounds Sanitizer - Comprehensive Edge Case Tests
! ==============================================================================
!
! This file tests the stability of the bounds sanitizer compiler pass
! across various edge cases to ensure absolutely no MLIR/LLVM crashes occur.
!
! ==============================================================================

program bounds_edge_cases
  implicit none

  ! 1. Normal Array
  real :: standard_array(10)
  
  ! 2. Zero-sized Array
  real :: zero_array(0)
  
  ! 3. Negative bounds array
  real :: negative_bounds(-5:5)
  
  ! 4. Multi-dimensional weird bounds
  integer :: weird_array(-2:2, 0:5, 10:15)

  ! 5. Allocatable array (Deferred shape)
  real, allocatable :: dyn_array(:)

  ! --- Tests ---
  
  print *, "[*] Initiating edge case compile-time & runtime stability test..."

  ! Standard array safe access
  standard_array(1) = 1.0

  ! Zero-sized array
  ! Should not crash the compiler, but will crash at runtime if OOB checking triggers.
  ! We just assign something safe if possible, or bypass execution to test compile-time.
  if (.false.) then
      zero_array(1) = 1.0
  end if

  ! Negative bound safe access
  negative_bounds(-5) = 1.0
  negative_bounds(0) = 1.0
  negative_bounds(5) = 1.0

  ! Weird bounds safe access
  weird_array(-2, 0, 10) = 1
  weird_array(2, 5, 15) = 1

  ! Allocatable (deferred shape)
  allocate(dyn_array(100))
  dyn_array(50) = 1.0
  deallocate(dyn_array)

  print *, "[*] All edge cases compiled and ran successfully without SegFaults!"

end program bounds_edge_cases
