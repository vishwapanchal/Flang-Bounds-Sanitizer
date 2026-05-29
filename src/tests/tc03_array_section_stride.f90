! ==========================================================================
! TC-03: Array section with stride — triplet access violation
! Category: Array Section (FR-2)
! Expected: Bounds violation when section index exceeds parent array
! ==========================================================================
subroutine process_section(sec)
  implicit none
  real, intent(inout) :: sec(:)

  ! Access an index beyond the section's extent
  sec(40) = 999.0
end subroutine process_section

program tc03_array_section_stride
  implicit none
  real :: source(100)
  integer :: i

  interface
    subroutine process_section(sec)
      real, intent(inout) :: sec(:)
    end subroutine
  end interface

  do i = 1, 100
    source(i) = real(i)
  end do

  ! Pass a strided section: elements 1, 4, 7, ..., 100 => 34 elements
  ! Accessing index 40 on this section exceeds its extent of 34
  call process_section(source(1:100:3))

  print *, "ERROR: Sanitizer failed to intercept OOB access."
end program tc03_array_section_stride
