! ==========================================================================
! TC-08: Zero-size array — any access is OOB
! Category: Zero-size Array
! Expected: Bounds violation on any access to a zero-extent array
! ==========================================================================
subroutine touch_zero_size(arr)
  implicit none
  integer, intent(inout) :: arr(:)

  ! Any access to a zero-size assumed-shape is invalid
  arr(1) = 99
end subroutine touch_zero_size

program tc08_zero_size
  implicit none
  integer :: empty(0)

  interface
    subroutine touch_zero_size(arr)
      integer, intent(inout) :: arr(:)
    end subroutine
  end interface

  ! Passing a zero-size array; index 1 is OOB since extent is 0
  call touch_zero_size(empty)

  print *, "ERROR: Sanitizer failed to intercept OOB access."
end program tc08_zero_size
