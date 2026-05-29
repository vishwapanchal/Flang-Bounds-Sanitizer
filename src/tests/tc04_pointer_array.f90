! ==========================================================================
! TC-04: Pointer array — OOB access through pointer association
! Category: Pointer (FR-3)
! Expected: Bounds violation via pointer
! ==========================================================================
program tc04_pointer_array
  implicit none
  integer, target    :: target_arr(10)
  integer, pointer   :: ptr(:)
  integer :: i

  do i = 1, 10
    target_arr(i) = i * 10
  end do

  ptr => target_arr

  ! Valid access through pointer
  ptr(5) = 999

  ! OOB access through pointer: index 12 exceeds target bounds [1:10]
  ptr(12) = -1

  print *, "ERROR: Sanitizer failed to intercept OOB access."
end program tc04_pointer_array
