! ==========================================================================
! TC-16: DO loop exceeding array bounds
! Category: Loop
! Expected: Bounds violation when loop counter exceeds array extent
! ==========================================================================
subroutine fill_array(arr, n)
  implicit none
  real, intent(inout) :: arr(:)
  integer, intent(in) :: n
  integer :: i

  ! Loop iterates beyond the array's actual extent
  do i = 1, n
    arr(i) = real(i * i)
  end do
end subroutine fill_array

program tc16_do_loop_oob
  implicit none
  real :: values(10)

  interface
    subroutine fill_array(arr, n)
      real, intent(inout) :: arr(:)
      integer, intent(in) :: n
    end subroutine
  end interface

  values = 0.0

  ! Request 15 iterations on a 10-element array
  call fill_array(values, 15)

  print *, "ERROR: Sanitizer failed to intercept OOB access."
end program tc16_do_loop_oob
