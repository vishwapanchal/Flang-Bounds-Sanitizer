! ==========================================================================
! TC-17: WHERE block with array access
! Category: WHERE construct
! Expected: Bounds violation in WHERE body via assumed-shape
! ==========================================================================
subroutine clamp_negatives(arr)
  implicit none
  real, intent(inout) :: arr(:)

  where (arr < 0.0)
    arr = 0.0
  end where
end subroutine clamp_negatives

program tc17_where_block
  implicit none
  real :: data(10)
  real :: small(3)

  interface
    subroutine clamp_negatives(arr)
      real, intent(inout) :: arr(:)
    end subroutine
  end interface

  data = -1.0
  small = -2.0

  ! Valid use of WHERE through assumed-shape
  call clamp_negatives(data)

  ! Pass a section that is valid
  call clamp_negatives(data(1:5))

  ! Now access with scalar OOB through a different path
  data(11) = 999.0

  print *, "ERROR: Sanitizer failed to intercept OOB access."
end program tc17_where_block
