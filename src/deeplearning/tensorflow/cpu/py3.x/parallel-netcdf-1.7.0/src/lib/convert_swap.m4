dnl Process this m4 file to produce 'C' language file.
dnl
dnl If you see this line, you can ignore the next one.
/* Do not edit this file. It is produced from the corresponding .m4 source */
dnl
/*
 *  Copyright (C) 2014, Northwestern University and Argonne National Laboratory
 *  See COPYRIGHT notice in top-level directory.
 */
/* $Id: convert_swap.m4 2290 2016-01-02 18:37:46Z wkliao $ */

#if HAVE_CONFIG_H
# include "ncconfig.h"
#endif

#include <stdio.h>
#include <unistd.h>
#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif
#include <assert.h>
#include <arpa/inet.h>   /* htonl(), htons() */

#include <mpi.h>

#include "nc.h"
#include "ncx.h"
#include "macro.h"

/* Prototypes for functions used only in this file */
#if 0
static void swapn(void *dst, const void *src, MPI_Offset nn, int xsize);
#endif

/*
 *  Datatype Mapping:
 *
 *  NETCDF    <--> MPI                    Description
 *   NC_BYTE       MPI_SIGNED_CHAR        signed 1-byte integer
 *   NC_CHAR       MPI_CHAR               char, text (cannot convert to other types)
 *   NC_SHORT      MPI_SHORT              signed 2-byte integer
 *   NC_INT        MPI_INT                signed 4-byte integer
 *   NC_FLOAT      MPI_FLOAT              single precision floating point
 *   NC_DOUBLE     MPI_DOUBLE             double precision floating point
 *   NC_UBYTE      MPI_UNSIGNED_CHAR      unsigned 1-byte int
 *   NC_USHORT     MPI_UNSIGNED_SHORT     unsigned 2-byte int
 *   NC_UINT       MPI_UNSIGNED           unsigned 4-byte int
 *   NC_INT64      MPI_LONG_LONG_INT      signed 8-byte int
 *   NC_UINT64     MPI_UNSIGNED_LONG_LONG unsigned 8-byte int
 *
 *  Assume: MPI_Datatype and nc_type are both enumerable types
 *          (this might not conform with MPI, as MPI_Datatype is intended to be
 *           an opaque data type.)
 *
 *  In OpenMPI, this assumption will fail
 */

inline MPI_Datatype
ncmpii_nc2mpitype(nc_type type)
{
    switch(type){
        case NC_BYTE :   return MPI_SIGNED_CHAR;
        case NC_CHAR :   return MPI_CHAR;
        case NC_SHORT :  return MPI_SHORT;
        case NC_INT :    return MPI_INT;
        case NC_FLOAT :  return MPI_FLOAT;
        case NC_DOUBLE : return MPI_DOUBLE;
        case NC_UBYTE :  return MPI_UNSIGNED_CHAR;
        case NC_USHORT : return MPI_UNSIGNED_SHORT;
        case NC_UINT :   return MPI_UNSIGNED;
        case NC_INT64 :  return MPI_LONG_LONG_INT;
        case NC_UINT64 : return MPI_UNSIGNED_LONG_LONG;
        default:         return MPI_DATATYPE_NULL;
    }
}

/*----< ncmpii_need_convert() >----------------------------------------------*/
/* netCDF specification make a special case for type conversion between
 * uchar and scahr: do not check for range error. See
 * http://www.unidata.ucar.edu/software/netcdf/docs_rc/data_type.html#type_conversion
 */
inline int
ncmpii_need_convert(nc_type nctype,MPI_Datatype mpitype) {
    return !( (nctype == NC_CHAR   && mpitype == MPI_CHAR)           ||
              (nctype == NC_BYTE   && mpitype == MPI_SIGNED_CHAR)    ||
              (nctype == NC_BYTE   && mpitype == MPI_UNSIGNED_CHAR)  ||
#if defined(__CHAR_UNSIGNED__) && __CHAR_UNSIGNED__ != 0
              (nctype == NC_BYTE   && mpitype == MPI_CHAR)           ||
#endif
              (nctype == NC_SHORT  && mpitype == MPI_SHORT)          ||
              (nctype == NC_INT    && mpitype == MPI_INT)            ||
              (nctype == NC_INT    && mpitype == MPI_LONG &&
               X_SIZEOF_INT == SIZEOF_LONG)                          ||
              (nctype == NC_FLOAT  && mpitype == MPI_FLOAT)          ||
              (nctype == NC_DOUBLE && mpitype == MPI_DOUBLE)         ||
              (nctype == NC_UBYTE  && mpitype == MPI_UNSIGNED_CHAR)  ||
              (nctype == NC_USHORT && mpitype == MPI_UNSIGNED_SHORT) ||
              (nctype == NC_UINT   && mpitype == MPI_UNSIGNED)       ||
              (nctype == NC_INT64  && mpitype == MPI_LONG_LONG_INT)  ||
              (nctype == NC_UINT64 && mpitype == MPI_UNSIGNED_LONG_LONG)
            );
}

/*----< ncmpii_need_swap() >-------------------------------------------------*/
inline int
ncmpii_need_swap(nc_type      nctype,
                 MPI_Datatype mpitype)
{
#ifdef WORDS_BIGENDIAN
    return 0;
#else
    if ((nctype == NC_CHAR   && mpitype == MPI_CHAR)           ||
        (nctype == NC_BYTE   && mpitype == MPI_SIGNED_CHAR)    ||
        (nctype == NC_UBYTE  && mpitype == MPI_UNSIGNED_CHAR))
        return 0;

    return 1;
#endif
}

#if 0
/*----< swapn() >------------------------------------------------------------*/
inline static void
swapn(void       *dst,
      const void *src,
      MPI_Offset  nn,
      int         xsize)
{
    int i;
    uchar *op = dst;
    const uchar *ip = src;
    while (nn-- != 0) {
        for (i=0; i<xsize; i++)
            op[i] = ip[xsize-1-i];
        op += xsize;
        ip += xsize;
    }
}
#endif

/* Endianness byte swap: done in-place */
#define SWAP(x,y) {tmp = (x); (x) = (y); (y) = tmp;}

/*----< ncmpii_swap() >-------------------------------------------------------*/
void
ncmpii_swapn(void       *dest_p,  /* destination array */
             const void *src_p,   /* source array */
             MPI_Offset  nelems,  /* number of elements in buf[] */
             int         esize)   /* byte size of each element */
{
    int  i;

    if (esize <= 1 || nelems <= 0) return;  /* no need */

    if (esize == 4) { /* this is the most common case */
              uint32_t *dest = (uint32_t*)       dest_p;
        const uint32_t *src  = (const uint32_t*) src_p;
        for (i=0; i<nelems; i++)
            dest[i] = htonl(src[i]);
    }
    else if (esize == 2) {
              uint16_t *dest =       (uint16_t*) dest_p;
        const uint16_t *src  = (const uint16_t*) src_p;
        for (i=0; i<nelems; i++)
            dest[i] = htons(src[i]);
    }
    else {
              uchar *op = (uchar*) dest_p;
        const uchar *ip = (uchar*) src_p;
        /* for esize is not 1, 2, or 4 */
        while (nelems-- > 0) {
            for (i=0; i<esize; i++)
                op[i] = ip[esize-1-i];
            op += esize;
            ip += esize;
        }
    }
}

/*----< ncmpii_in_swap() >---------------------------------------------------*/
void
ncmpii_in_swapn(void       *buf,
                MPI_Offset  nelems,  /* number of elements in buf[] */
                int         esize)   /* byte size of each element */
{
    int  i;
    uchar tmp, *op = (uchar*)buf;

    if (esize <= 1 || nelems <= 0) return;  /* no need */

    if (esize == 4) { /* this is the most common case */
        uint32_t *dest = (uint32_t*) buf;
        for (i=0; i<nelems; i++)
            dest[i] = htonl(dest[i]);
    }
    else if (esize == 2) {
        uint16_t *dest = (uint16_t*) buf;
        for (i=0; i<nelems; i++)
            dest[i] = htons(dest[i]);
    }
    else {
        /* for esize is not 1, 2, or 4 */
        while (nelems-- > 0) {
            for (i=0; i<esize/2; i++)
                SWAP(op[i], op[esize-1-i])
            op += esize;
        }
    }
}


dnl
dnl X_PUTN_FILETYPE(xtype)
dnl
define(`X_PUTN_FILETYPE',dnl
`dnl
/*----< ncmpii_x_putn_$1() >--------------------------------------------------*/
inline int
ncmpii_x_putn_$1(void         *xp,      /* file buffer of type schar */
                 const void   *putbuf,  /* put buffer of type puttype */
                 MPI_Offset    nelems,
                 MPI_Datatype  puttype)
{
    if (puttype == MPI_CHAR || /* assume ECHAR has been checked before */
        puttype == MPI_SIGNED_CHAR)
        return ncmpix_putn_$1_schar    (&xp, nelems, (const schar*)     putbuf);
    else if (puttype == MPI_UNSIGNED_CHAR)
        return ncmpix_putn_$1_uchar    (&xp, nelems, (const uchar*)     putbuf);
    else if (puttype == MPI_SHORT)
        return ncmpix_putn_$1_short    (&xp, nelems, (const short*)     putbuf);
    else if (puttype == MPI_UNSIGNED_SHORT)
        return ncmpix_putn_$1_ushort   (&xp, nelems, (const ushort*)    putbuf);
    else if (puttype == MPI_INT)
        return ncmpix_putn_$1_int      (&xp, nelems, (const int*)       putbuf);
    else if (puttype == MPI_UNSIGNED)
        return ncmpix_putn_$1_uint     (&xp, nelems, (const uint*)      putbuf);
    else if (puttype == MPI_LONG)
        return ncmpix_putn_$1_long     (&xp, nelems, (const long*)      putbuf);
    else if (puttype == MPI_FLOAT)
        return ncmpix_putn_$1_float    (&xp, nelems, (const float*)     putbuf);
    else if (puttype == MPI_DOUBLE)
        return ncmpix_putn_$1_double   (&xp, nelems, (const double*)    putbuf);
    else if (puttype == MPI_LONG_LONG_INT)
        return ncmpix_putn_$1_longlong (&xp, nelems, (const longlong*)  putbuf);
    else if (puttype == MPI_UNSIGNED_LONG_LONG)
        return ncmpix_putn_$1_ulonglong(&xp, nelems, (const ulonglong*) putbuf);
    DEBUG_RETURN_ERROR(NC_EBADTYPE)
}
')dnl

X_PUTN_FILETYPE(schar)
X_PUTN_FILETYPE(uchar)
X_PUTN_FILETYPE(short)
X_PUTN_FILETYPE(ushort)
X_PUTN_FILETYPE(int)
X_PUTN_FILETYPE(uint)
X_PUTN_FILETYPE(float)
X_PUTN_FILETYPE(double)
X_PUTN_FILETYPE(int64)
X_PUTN_FILETYPE(uint64)

dnl
dnl X_GETN_FILETYPE(xtype)
dnl
define(`X_GETN_FILETYPE',dnl
`dnl
/*----< ncmpii_x_getn_$1() >-------------------------------------------------*/
inline int
ncmpii_x_getn_$1(const void   *xp,      /* file buffer of type schar */
                 void         *getbuf,  /* get buffer of type gettype */
                 MPI_Offset    nelems,
                 MPI_Datatype  gettype)
{
    if (gettype == MPI_CHAR || /* assume ECHAR has been checked before */
        gettype == MPI_SIGNED_CHAR)
        return ncmpix_getn_$1_schar    (&xp, nelems, (schar*)     getbuf);
    else if (gettype == MPI_UNSIGNED_CHAR)
        return ncmpix_getn_$1_uchar    (&xp, nelems, (uchar*)     getbuf);
    else if (gettype == MPI_SHORT)
        return ncmpix_getn_$1_short    (&xp, nelems, (short*)     getbuf);
    else if (gettype == MPI_UNSIGNED_SHORT)
        return ncmpix_getn_$1_ushort   (&xp, nelems, (ushort*)    getbuf);
    else if (gettype == MPI_INT)
        return ncmpix_getn_$1_int      (&xp, nelems, (int*)       getbuf);
    else if (gettype == MPI_UNSIGNED)
        return ncmpix_getn_$1_uint     (&xp, nelems, (uint*)      getbuf);
    else if (gettype == MPI_LONG)
        return ncmpix_getn_$1_long     (&xp, nelems, (long*)      getbuf);
    else if (gettype == MPI_FLOAT)
        return ncmpix_getn_$1_float    (&xp, nelems, (float*)     getbuf);
    else if (gettype == MPI_DOUBLE)
        return ncmpix_getn_$1_double   (&xp, nelems, (double*)    getbuf);
    else if (gettype == MPI_LONG_LONG_INT)
        return ncmpix_getn_$1_longlong (&xp, nelems, (longlong*)  getbuf);
    else if (gettype == MPI_UNSIGNED_LONG_LONG)
        return ncmpix_getn_$1_ulonglong(&xp, nelems, (ulonglong*) getbuf);
    DEBUG_RETURN_ERROR(NC_EBADTYPE)
}
')dnl

X_GETN_FILETYPE(schar)
X_GETN_FILETYPE(uchar)
X_GETN_FILETYPE(short)
X_GETN_FILETYPE(ushort)
X_GETN_FILETYPE(int)
X_GETN_FILETYPE(uint)
X_GETN_FILETYPE(float)
X_GETN_FILETYPE(double)
X_GETN_FILETYPE(int64)
X_GETN_FILETYPE(uint64)

