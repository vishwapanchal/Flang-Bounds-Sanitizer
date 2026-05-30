! ==========================================================================
! TC-18: FORALL construct with OOB index
! Category: FORALL
! Expected: Bounds violation when access exceeds array bounds
! ==========================================================================
program tc18_forall_oob
  implicit none
  integer :: matrix(5, 5)
  integer :: i, j
  integer :: bad_idx

  matrix = 0

  ! Valid FORALL
  forall (i = 1:5, j = 1:5)
    matrix(i, j) = i + j
  end forall

  ! Direct OOB access after FORALL via variable index
  bad_idx = 6
  matrix(bad_idx, 3) = 999

  print *, "ERROR: Sanitizer failed to intercept OOB access."
end program tc18_forall_oob
