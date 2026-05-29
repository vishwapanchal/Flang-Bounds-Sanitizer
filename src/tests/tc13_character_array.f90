! ==========================================================================
! TC-13: Character array — bounds check on character string array
! Category: Character Array
! Expected: Bounds violation at index 6 (array has 5 elements)
! ==========================================================================
subroutine set_name(names, idx, val)
  implicit none
  character(len=20), intent(inout) :: names(:)
  integer, intent(in) :: idx
  character(len=*), intent(in) :: val

  names(idx) = val
end subroutine set_name

program tc13_character_array
  implicit none
  character(len=20) :: labels(5)

  interface
    subroutine set_name(names, idx, val)
      character(len=20), intent(inout) :: names(:)
      integer, intent(in) :: idx
      character(len=*), intent(in) :: val
    end subroutine
  end interface

  labels = "empty"

  ! Valid access
  call set_name(labels, 3, "temperature")

  ! OOB: index 6 exceeds array extent of 5
  call set_name(labels, 6, "overflow")

  print *, "ERROR: Sanitizer failed to intercept OOB access."
end program tc13_character_array
