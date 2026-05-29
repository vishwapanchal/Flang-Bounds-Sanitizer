! ==========================================================================
! TC-18: FORALL construct with OOB index
! Category: FORALL
! Expected: Bounds violation when FORALL triplet exceeds array bounds
! ==========================================================================
program tc18_forall_oob
  implicit none
  integer :: matrix(5, 5)
  integer :: i, j

  matrix = 0

  ! Valid FORALL
  forall (i = 1:5, j = 1:5)
    matrix(i, j) = i + j
  end forall

  ! Direct OOB access after FORALL
  matrix(6, 3) = 999

  print *, "ERROR: Sanitizer failed to intercept OOB access."
end program tc18_forall_oob
