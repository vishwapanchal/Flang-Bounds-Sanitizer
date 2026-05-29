! ==========================================================================
! Benchmark 3: PolyBench 2mm Kernel (Two Matrix Multiplications)
!
! Computes D = alpha * A * B * C + beta * D
! Standard PolyBench kernel adapted to Fortran for overhead measurement.
!
! Compile baseline:     flang-new -O2 polybench_2mm.f90 -o poly_base
! Compile instrumented: flang-new -O2 -fcheck=bounds polybench_2mm.f90 -o poly_instr
! ==========================================================================
module polybench_mod
  implicit none
contains

  subroutine kernel_2mm(ni, nj, nk, nl, alpha, beta, A, B, C, D, tmp)
    integer, intent(in) :: ni, nj, nk, nl
    real(8), intent(in) :: alpha, beta
    real(8), intent(in)    :: A(:,:), B(:,:), C(:,:)
    real(8), intent(inout) :: D(:,:), tmp(:,:)
    integer :: i, j, k

    ! tmp = alpha * A * B
    do i = 1, ni
      do j = 1, nj
        tmp(i, j) = 0.0d0
        do k = 1, nk
          tmp(i, j) = tmp(i, j) + alpha * A(i, k) * B(k, j)
        end do
      end do
    end do

    ! D = tmp * C + beta * D
    do i = 1, ni
      do j = 1, nl
        D(i, j) = D(i, j) * beta
        do k = 1, nj
          D(i, j) = D(i, j) + tmp(i, k) * C(k, j)
        end do
      end do
    end do
  end subroutine kernel_2mm

end module polybench_mod

program polybench_2mm
  use polybench_mod
  implicit none

  integer, parameter :: NI = 256, NJ = 256, NK = 256, NL = 256
  real(8), allocatable :: A(:,:), B(:,:), C(:,:), D(:,:), tmp(:,:)
  real(8) :: t_start, t_end

  allocate(A(NI, NK), B(NK, NJ), C(NJ, NL), D(NI, NL), tmp(NI, NJ))

  call random_number(A)
  call random_number(B)
  call random_number(C)
  D = 0.0d0

  print *, "PolyBench 2mm: NI=", NI, " NJ=", NJ, " NK=", NK, " NL=", NL
  call cpu_time(t_start)

  call kernel_2mm(NI, NJ, NK, NL, 1.5d0, 1.2d0, A, B, C, D, tmp)

  call cpu_time(t_end)

  print *, "---------------------------------------------------"
  print *, "PolyBench 2mm Completed."
  print *, "Execution Time: ", t_end - t_start, " seconds"
  print *, "Result checksum:", sum(D)
  print *, "---------------------------------------------------"

  deallocate(A, B, C, D, tmp)
end program polybench_2mm
