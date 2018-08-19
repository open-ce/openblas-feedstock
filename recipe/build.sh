#!/bin/bash

# https://github.com/xianyi/OpenBLAS/wiki/faq#Linux_SEGFAULT
patch < segfaults.patch

# See this workaround
# ( https://github.com/xianyi/OpenBLAS/issues/818#issuecomment-207365134 ).
unset CFLAGS
unset LDFLAGS
unset CXXFLAGS
unset FFLAGS
# CF="${CFLAGS}"
# unset CFLAGS
# export LAPACK_FFLAGS="${FFLAGS}"

# Build all CPU targets and allow dynamic configuration
# Build LAPACK.
# Enable threading. This can be controlled to a certain number by
# setting OPENBLAS_NUM_THREADS before loading the library.
# Because -Wno-missing-include-dirs does not work with gfortran:
[[ -d "${PREFIX}"/include ]] || mkdir "${PREFIX}"/include
export FFLAGS="${FFLAGS} -frecursive -g -fcheck=all -Wall"
make DYNAMIC_ARCH=0 BINARY=${ARCH} NO_LAPACK=0 NO_AFFINITY=1 USE_THREAD=1 NUM_THREADS=24 DEBUG=1
OPENBLAS_NUM_THREADS=${CPU_COUNT} make test
make install PREFIX="${PREFIX}"

# As OpenBLAS, now will have all symbols that BLAS, CBLAS or LAPACK have,
# create libraries with the standard names that are linked back to
# OpenBLAS. This will make it easier for packages that are looking for them.
for arg in blas cblas lapack; do
    ln -fs "${PREFIX}"/lib/pkgconfig/openblas.pc "${PREFIX}"/lib/pkgconfig/$arg.pc
    ln -fs "${PREFIX}"/lib/libopenblas.a "${PREFIX}"/lib/lib$arg.a
    ln -fs "${PREFIX}"/lib/libopenblas$SHLIB_EXT "${PREFIX}"/lib/lib$arg$SHLIB_EXT
done

if [[ ${target_platform} == osx-64 ]]; then
    # Needs to fix the install name of the dylib so that the downstream projects will link
    # to libopenblas.dylib instead of libopenblasp-r0.2.20.dylib
    # In linux, SONAME is libopenblas.so.0 instead of libopenblasp-r0.2.20.so, so no change needed
    ${INSTALL_NAME_TOOL} -id "${PREFIX}"/lib/libopenblas.dylib "${PREFIX}"/lib/libopenblas.dylib
fi

cp "${RECIPE_DIR}"/site.cfg "${PREFIX}"/site.cfg
echo library_dirs = ${PREFIX}/lib >> "${PREFIX}"/site.cfg
echo include_dirs = ${PREFIX}/include >> "${PREFIX}"/site.cfg
echo runtime_include_dirs = ${PREFIX}/lib >> "${PREFIX}"/site.cfg
