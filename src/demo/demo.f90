! ==============================================================================
! Flang HLFIR-Aware Array Bounds Sanitizer - Demonstration
! ==============================================================================
!
! This file is intentionally designed to trigger an out-of-bounds error
! to demonstrate the precise diagnostic output of the sanitizer.
!
! ==============================================================================

program bounds_demo
  implicit none
  integer, parameter :: N = 5
  real(8), allocatable :: A(:,:)
  integer :: i, j

  print *, "========================================================="
  print *, "   FLANG HLFIR BOUNDS SANITIZER - SELF DEMONSTRATION"
  print *, "========================================================="
  print *, "[*] Allocating 2D array A(5, 5)..."
  allocate(A(N, N))

  print *, "[*] Accessing valid indices (1..5)..."
  do j = 1, N
    do i = 1, N
      A(i, j) = 1.0d0
    end do
  end do
  print *, "[*] Valid accesses completed successfully."

  print *, "---------------------------------------------------------"
  print *, "[!] Now attempting to access OUT-OF-BOUNDS index A(6, 3)..."
  print *, "[!] This should trigger the HLFIR bounds sanitizer!"
  print *, "---------------------------------------------------------"
  
  ! Intentional out-of-bounds access on dimension 1 (6 > 5)
  A(6, 3) = 99.9d0

  print *, "If you see this, the sanitizer failed to catch the error!"
end program bounds_demo
