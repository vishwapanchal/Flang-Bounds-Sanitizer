! ==========================================================================
! TC-05: Allocatable array — access beyond allocated extent
! Category: Allocatable (FR-4)
! Expected: Bounds violation at index 15 (allocated size is 10)
! ==========================================================================
program tc05_allocatable_oob
  implicit none
  integer, allocatable :: arr(:)

  allocate(arr(10))
  arr = 0

  ! Valid access
  arr(10) = 100

  ! OOB access: index 15 exceeds allocated extent of 10
  arr(15) = 200

  print *, "ERROR: Sanitizer failed to intercept OOB access."
  deallocate(arr)
end program tc05_allocatable_oob
