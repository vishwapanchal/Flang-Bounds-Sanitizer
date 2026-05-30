! ==========================================================================
! TC-19: RESHAPE result accessed out of bounds
! Category: Intrinsic
! Expected: Bounds violation on reshaped array
! ==========================================================================
program tc19_reshape_access
  implicit none
  integer :: flat(12)
  integer :: grid(3, 4)
  integer :: i
  integer :: bad_idx

  do i = 1, 12
    flat(i) = i * 10
  end do

  grid = reshape(flat, shape=[3, 4])

  ! Valid access
  print *, "grid(2,3) =", grid(2, 3)

  ! OOB: dimension 1, index 4 exceeds upper bound 3
  bad_idx = 4
  grid(bad_idx, 2) = -1

  print *, "ERROR: Sanitizer failed to intercept OOB access."
end program tc19_reshape_access
