! ==========================================================================
! TC-21: Off-by-one at upper bound (ub + 1)
! Category: Edge Case
! Expected: Bounds violation at index 11 (upper bound is 10)
! ==========================================================================
subroutine off_by_one_upper(arr, idx)
  implicit none
  integer, intent(inout) :: arr(:)
  integer, intent(in) :: idx

  arr(idx) = -999
end subroutine off_by_one_upper

program tc21_upper_off_by_one
  implicit none
  integer :: data(10)

  interface
    subroutine off_by_one_upper(arr, idx)
      integer, intent(inout) :: arr(:)
      integer, intent(in) :: idx
    end subroutine
  end interface

  data = 0

  ! Valid access at the upper bound
  call off_by_one_upper(data, 10)

  ! Off-by-one: index 11 exceeds upper bound 10
  call off_by_one_upper(data, 11)

  print *, "ERROR: Sanitizer failed to intercept OOB access."
end program tc21_upper_off_by_one
