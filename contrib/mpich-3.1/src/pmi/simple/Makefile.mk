## -*- Mode: Makefile; -*-
## vim: set ft=automake :
##
## (C) 2011 by Argonne National Laboratory.
##     See COPYRIGHT in top-level directory.
##

if BUILD_PMI_SIMPLE

lib_lib@MPILIBNAME@_la_SOURCES +=       \
    src/pmi/simple/simple_pmiutil.c \
    src/pmi/simple/simple_pmi.c

noinst_HEADERS +=                   \
    src/pmi/simple/simple_pmiutil.h

AM_CPPFLAGS += -I$(top_srcdir)/src/pmi/simple

endif BUILD_PMI_SIMPLE

