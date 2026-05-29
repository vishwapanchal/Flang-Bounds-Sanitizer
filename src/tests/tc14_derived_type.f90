! ==========================================================================
! TC-14: Derived type component — array inside a derived type
! Category: Derived Type
! Expected: Bounds violation on the component array
! ==========================================================================
program tc14_derived_type
  implicit none

  type :: particle_t
    real(8) :: position(3)
    real(8) :: velocity(3)
    real(8) :: mass
  end type particle_t

  type(particle_t) :: p

  p%mass = 1.0d0
  p%position = 0.0d0
  p%velocity = 0.0d0

  ! Valid access to component array
  p%position(1) = 10.0d0
  p%position(2) = 20.0d0
  p%position(3) = 30.0d0

  ! OOB: dimension 1 index 4 exceeds upper bound 3
  p%position(4) = 40.0d0

  print *, "ERROR: Sanitizer failed to intercept OOB access."
end program tc14_derived_type
