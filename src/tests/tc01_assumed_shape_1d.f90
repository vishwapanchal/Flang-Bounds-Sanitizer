! ==========================================================================
! TC-01: Assumed-shape array, scalar index out of bounds (1D)
! Category: Assumed-Shape (FR-1)
! Expected: Bounds violation detected at dimension 1
! ==========================================================================
subroutine access_assumed_shape_1d(arr, idx)
  implicit none
  integer, intent(inout) :: arr(:)
  integer, intent(in)    :: idx

  ! This access should trigger a bounds violation when idx > size(arr)
  arr(idx) = 42
end subroutine access_assumed_shape_1d

program tc01_assumed_shape_1d
  implicit none
  integer :: data(10)
  integer :: i

  interface
    subroutine access_assumed_shape_1d(arr, idx)
      integer, intent(inout) :: arr(:)
      integer, intent(in)    :: idx
    end subroutine
  end interface

  do i = 1, 10
    data(i) = i
  end do

  ! Valid access
  call access_assumed_shape_1d(data, 5)

  ! Out-of-bounds access: index 11 exceeds upper bound 10
  call access_assumed_shape_1d(data, 11)

  print *, "ERROR: Sanitizer failed to intercept OOB access."
end program tc01_assumed_shape_1d
