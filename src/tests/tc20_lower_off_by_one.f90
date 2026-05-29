! ==========================================================================
! TC-20: Off-by-one at lower bound (lb - 1)
! Category: Edge Case
! Expected: Bounds violation at index 0 (lower bound is 1)
! ==========================================================================
subroutine off_by_one_lower(arr, idx)
  implicit none
  real(8), intent(inout) :: arr(:)
  integer, intent(in) :: idx

  arr(idx) = 0.0d0
end subroutine off_by_one_lower

program tc20_lower_off_by_one
  implicit none
  real(8) :: data(10)

  interface
    subroutine off_by_one_lower(arr, idx)
      real(8), intent(inout) :: arr(:)
      integer, intent(in) :: idx
    end subroutine
  end interface

  data = 1.0d0

  ! Valid access at the lower bound
  call off_by_one_lower(data, 1)

  ! Off-by-one: index 0 is below lower bound 1
  call off_by_one_lower(data, 0)

  print *, "ERROR: Sanitizer failed to intercept OOB access."
end program tc20_lower_off_by_one
