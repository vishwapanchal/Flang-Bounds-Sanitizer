! ==============================================================================
! Flang HLFIR-Aware Array Bounds Sanitizer Benchmark
! ==============================================================================
!
! Simulates a compute-bound kernel to measure overhead (NFR-1).
!
! To run baseline:
!   flang-new -O2 benchmark.f90 -o benchmark_baseline
!   ./benchmark_baseline
!
! To run instrumented:
!   flang-new -O2 -fcheck=bounds benchmark.f90 -o benchmark_instrumented
!   ./benchmark_instrumented
!
! ==============================================================================

program bounds_check_benchmark
  implicit none
  integer, parameter :: N = 1024
  real(8), allocatable :: A(:,:), B(:,:), C(:,:)
  integer :: i, j, k
  real(8) :: start_time, end_time

  print *, "Starting benchmark initialization (N=", N, ")..."
  allocate(A(N, N), B(N, N), C(N, N))

  ! Initialize matrices
  call random_number(A)
  call random_number(B)
  C = 0.0d0

  print *, "Running matrix multiplication kernel..."
  call cpu_time(start_time)

  ! Compute C = A * B
  ! Using Fortran conventional column-major optimization layout
  do j = 1, N
    do k = 1, N
      do i = 1, N
        C(i, j) = C(i, j) + A(i, k) * B(k, j)
      end do
    end do
  end do

  call cpu_time(end_time)

  print *, "---------------------------------------------------"
  print *, "Benchmark Completed."
  print *, "Execution Time: ", end_time - start_time, " seconds"
  print *, "Result checksum: ", sum(C)
  print *, "---------------------------------------------------"

  deallocate(A, B, C)
end program bounds_check_benchmark