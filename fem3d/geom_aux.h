
!        integer ilinkv(nkndim+1)
!        common /ilinkv/ilinkv

!        integer lenkv(nlkdim)
!        common /lenkv/lenkv
!        integer linkv(nlkdim)
!        common /linkv/linkv

        integer ieltv(3,neldim)
        common /ieltv/ieltv

        integer kantv(2,nkndim)
        common /kantv/kantv

        real dxv(nkndim), dyv(nkndim)
        common /dxv/dxv, /dyv/dyv

!        save /ilinkv/,/lenkv/,/linkv/
        save /ieltv/,/kantv/,/dxv/,/dyv/

