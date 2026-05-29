! ==========================================================================
! TC-10: Non-contiguous section passed to subroutine
! Category: Non-contiguous Array Section (FR-2)
! Expected: Bounds violation on section extent
! ==========================================================================
subroutine sum_column(col, n, result)
  implicit none
  real(8), intent(in) :: col(:)
  integer, intent(in) :: n
  real(8), intent(out) :: result
  integer :: i

  result = 0.0d0
  do i = 1, n
    result = result + col(i)
  end do
end subroutine sum_column

program tc10_noncontiguous_section
  implicit none
  real(8) :: matrix(10, 5)
  real(8) :: total
  integer :: i, j

  interface
    subroutine sum_column(col, n, result)
      real(8), intent(in) :: col(:)
      integer, intent(in) :: n
      real(8), intent(out) :: result
    end subroutine
  end interface

  do j = 1, 5
    do i = 1, 10
      matrix(i, j) = dble(i + j)
    end do
  end do

  ! Pass strided section: matrix(1:10:2, 3) = elements {1,3,5,7,9} => 5 elements
  ! Request sum of 8 elements — exceeds section extent of 5
  call sum_column(matrix(1:10:2, 3), 8, total)

  print *, "ERROR: Sanitizer failed to intercept OOB access. Sum =", total
end program tc10_noncontiguous_section
