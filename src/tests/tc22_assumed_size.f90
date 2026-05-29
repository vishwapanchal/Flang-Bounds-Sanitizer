! ==========================================================================
! TC-22: Assumed-size array — partial bounds check
! Category: Assumed-size (A(*))
! Expected: The sanitizer may skip this (assumed-size has no upper bound
!           metadata in HLFIR), but it must not crash the compiler.
!           This test verifies compiler stability.
! ==========================================================================
subroutine process_assumed_size(arr, n)
  implicit none
  integer, intent(inout) :: arr(*)
  integer, intent(in) :: n
  integer :: i

  ! Access up to caller-specified extent
  do i = 1, n
    arr(i) = i * 100
  end do
end subroutine process_assumed_size

program tc22_assumed_size
  implicit none
  integer :: data(10)

  data = 0

  ! Valid: caller knows the actual extent
  call process_assumed_size(data, 10)

  ! OOB: requesting 15 elements from a 10-element array
  ! The sanitizer may not catch this (assumed-size lacks upper bound info),
  ! but the pass must handle the case without crashing.
  call process_assumed_size(data, 15)

  print *, "Assumed-size test completed. Check for compiler stability."
end program tc22_assumed_size
