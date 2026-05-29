! ==========================================================================
! TC-06: Allocatable reallocation — access old valid index after shrink
! Category: Allocatable (FR-4)
! Expected: Bounds violation at index 8 after reallocation to size 5
! ==========================================================================
program tc06_allocatable_realloc
  implicit none
  real(8), allocatable :: buffer(:)

  allocate(buffer(10))
  buffer = 1.0d0

  ! Valid access before reallocation
  buffer(8) = 99.0d0

  ! Shrink the array
  deallocate(buffer)
  allocate(buffer(5))
  buffer = 2.0d0

  ! Access index 8 — was valid before reallocation, now OOB
  buffer(8) = 77.0d0

  print *, "ERROR: Sanitizer failed to intercept OOB access."
  deallocate(buffer)
end program tc06_allocatable_realloc
