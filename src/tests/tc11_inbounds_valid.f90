! ==========================================================================
! TC-11: Negative test — all accesses are valid, no violations expected
! Category: Negative Test (FR-7)
! Expected: Program completes normally, no diagnostics emitted
! ==========================================================================
subroutine scale_vector(vec, factor)
  implicit none
  real(8), intent(inout) :: vec(:)
  real(8), intent(in)    :: factor
  integer :: i

  do i = 1, size(vec)
    vec(i) = vec(i) * factor
  end do
end subroutine scale_vector

program tc11_inbounds_valid
  implicit none
  real(8), allocatable :: data(:)
  real(8) :: matrix(4, 4)
  integer :: i, j

  interface
    subroutine scale_vector(vec, factor)
      real(8), intent(inout) :: vec(:)
      real(8), intent(in)    :: factor
    end subroutine
  end interface

  allocate(data(100))
  do i = 1, 100
    data(i) = dble(i)
  end do

  ! All of these accesses are within bounds
  call scale_vector(data, 2.0d0)
  call scale_vector(data(1:50), 0.5d0)
  call scale_vector(data(51:100), 1.5d0)

  do j = 1, 4
    do i = 1, 4
      matrix(i, j) = dble(i * j)
    end do
  end do

  deallocate(data)
  print *, "SUCCESS: All accesses were within bounds. Checksum =", sum(matrix)
end program tc11_inbounds_valid
