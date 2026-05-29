! ==========================================================================
! TC-02: Assumed-shape array, rank-3, OOB in dimension 3 only
! Category: Assumed-Shape (FR-1)
! Expected: Bounds violation detected at dimension 3
! ==========================================================================
subroutine fill_3d_assumed(cube, i, j, k)
  implicit none
  real(8), intent(inout) :: cube(:,:,:)
  integer, intent(in)    :: i, j, k

  cube(i, j, k) = 3.14d0
end subroutine fill_3d_assumed

program tc02_assumed_shape_3d
  implicit none
  real(8) :: volume(4, 6, 8)

  interface
    subroutine fill_3d_assumed(cube, i, j, k)
      real(8), intent(inout) :: cube(:,:,:)
      integer, intent(in)    :: i, j, k
    end subroutine
  end interface

  volume = 0.0d0

  ! Valid access within all dimensions
  call fill_3d_assumed(volume, 2, 3, 4)

  ! OOB in dimension 3 only: k=9 exceeds upper bound 8
  call fill_3d_assumed(volume, 2, 3, 9)

  print *, "ERROR: Sanitizer failed to intercept OOB access."
end program tc02_assumed_shape_3d
