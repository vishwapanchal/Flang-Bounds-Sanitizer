! ==========================================================================
! TC-12: High-rank array — rank 7, OOB in the last dimension
! Category: High Rank
! Expected: Bounds violation in dimension 7
! ==========================================================================
program tc12_high_rank
  implicit none
  real :: tensor(2, 2, 2, 2, 2, 2, 3)

  tensor = 0.0

  ! Valid access: all indices within bounds
  tensor(1, 1, 1, 1, 1, 1, 2) = 1.0

  ! OOB in dimension 7: index 4 exceeds upper bound 3
  tensor(1, 1, 1, 1, 1, 1, 4) = 2.0

  print *, "ERROR: Sanitizer failed to intercept OOB access."
end program tc12_high_rank
