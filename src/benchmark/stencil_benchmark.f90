! ==========================================================================
! Benchmark 2: 2D Five-Point Stencil Kernel
!
! Exercises assumed-shape array passing and multi-dimensional access
! patterns typical of computational fluid dynamics and PDE solvers.
!
! Compile baseline:     flang-new -O2 stencil_benchmark.f90 -o stencil_base
! Compile instrumented: flang-new -O2 -fcheck=bounds stencil_benchmark.f90 -o stencil_instr
! ==========================================================================
module stencil_mod
  implicit none
contains

  subroutine apply_stencil(grid_in, grid_out, nx, ny)
    real(8), intent(in)    :: grid_in(:,:)
    real(8), intent(inout) :: grid_out(:,:)
    integer, intent(in)    :: nx, ny
    integer :: i, j

    ! Five-point stencil: average of cardinal neighbors
    do j = 2, ny - 1
      do i = 2, nx - 1
        grid_out(i, j) = 0.25d0 * ( &
            grid_in(i-1, j) + grid_in(i+1, j) + &
            grid_in(i, j-1) + grid_in(i, j+1) )
      end do
    end do
  end subroutine apply_stencil

end module stencil_mod

program stencil_benchmark
  use stencil_mod
  implicit none

  integer, parameter :: NX = 512, NY = 512, NSTEPS = 50
  real(8), allocatable :: grid_a(:,:), grid_b(:,:)
  real(8) :: t_start, t_end
  integer :: step

  allocate(grid_a(NX, NY), grid_b(NX, NY))

  ! Initialize with a thermal gradient
  call random_number(grid_a)
  grid_b = grid_a

  print *, "Stencil Benchmark: ", NX, "x", NY, " grid, ", NSTEPS, " steps"
  call cpu_time(t_start)

  do step = 1, NSTEPS
    if (mod(step, 2) == 1) then
      call apply_stencil(grid_a, grid_b, NX, NY)
    else
      call apply_stencil(grid_b, grid_a, NX, NY)
    end if
  end do

  call cpu_time(t_end)

  print *, "---------------------------------------------------"
  print *, "Stencil Benchmark Completed."
  print *, "Execution Time: ", t_end - t_start, " seconds"
  print *, "Grid checksum:  ", sum(grid_a) + sum(grid_b)
  print *, "---------------------------------------------------"

  deallocate(grid_a, grid_b)
end program stencil_benchmark
