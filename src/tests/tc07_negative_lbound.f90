! ==========================================================================
! TC-07: Non-unity lower bound — A(-5:5) accessed at index -6
! Category: Non-unity Lower Bound
! Expected: Bounds violation at index -6, valid range [-5:5]
! ==========================================================================
subroutine access_negative_lb(arr, idx)
  implicit none
  integer, intent(inout) :: arr(-5:5)
  integer, intent(in)    :: idx

  arr(idx) = 77
end subroutine access_negative_lb

program tc07_negative_lbound
  implicit none
  integer :: data(-5:5)

  data = 0

  ! Valid access at lower bound
  call access_negative_lb(data, -5)

  ! Valid access at upper bound
  call access_negative_lb(data, 5)

  ! OOB: index -6 is below lower bound -5
  call access_negative_lb(data, -6)

  print *, "ERROR: Sanitizer failed to intercept OOB access."
end program tc07_negative_lbound
