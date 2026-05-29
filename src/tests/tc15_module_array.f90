! ==========================================================================
! TC-15: Module-level array accessed from external subroutine
! Category: Module
! Expected: Bounds violation on module array
! ==========================================================================
module shared_data
  implicit none
  integer, parameter :: GRID_SIZE = 20
  real(8) :: grid(GRID_SIZE)
end module shared_data

subroutine initialize_grid()
  use shared_data
  implicit none
  integer :: i

  do i = 1, GRID_SIZE
    grid(i) = dble(i) * 0.5d0
  end do
end subroutine initialize_grid

subroutine access_grid(idx)
  use shared_data
  implicit none
  integer, intent(in) :: idx

  ! This access may be OOB depending on idx
  grid(idx) = -1.0d0
end subroutine access_grid

program tc15_module_array
  implicit none

  call initialize_grid()

  ! Valid access
  call access_grid(10)

  ! OOB: index 25 exceeds module array extent of 20
  call access_grid(25)

  print *, "ERROR: Sanitizer failed to intercept OOB access."
end program tc15_module_array
