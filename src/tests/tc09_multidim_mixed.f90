! ==========================================================================
! TC-09: Multi-dimensional mixed — 3D array, OOB in dimension 2 only
! Category: Multi-dimensional
! Expected: Bounds violation in dimension 2
! ==========================================================================
subroutine modify_3d(grid, i, j, k)
  implicit none
  real, intent(inout) :: grid(:,:,:)
  integer, intent(in) :: i, j, k

  grid(i, j, k) = 1.0
end subroutine modify_3d

program tc09_multidim_mixed
  implicit none
  real :: field(10, 8, 6)

  interface
    subroutine modify_3d(grid, i, j, k)
      real, intent(inout) :: grid(:,:,:)
      integer, intent(in) :: i, j, k
    end subroutine
  end interface

  field = 0.0

  ! Valid access
  call modify_3d(field, 5, 4, 3)

  ! OOB in dimension 2: j=10 exceeds upper bound 8
  call modify_3d(field, 5, 10, 3)

  print *, "ERROR: Sanitizer failed to intercept OOB access."
end program tc09_multidim_mixed
