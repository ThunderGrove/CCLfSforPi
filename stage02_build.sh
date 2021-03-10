#!/bin/bash
#
# PiCLFS toolchain build script
# Optional parameteres below:
set +h
set -o nounset
set -o errexit
umask 022

export LC_ALL=POSIX
export PARALLEL_JOBS=`cat /proc/cpuinfo | grep cores | wc -l`
export CONFIG_LINUX_ARCH="arm64"
export CONFIG_TARGET="aarch64-linux-gnu"
export CONFIG_HOST=`echo ${MACHTYPE} | sed -e 's/-[^-]*/-cross/'`

export WORKSPACE_DIR=$PWD
export SOURCES_DIR=$WORKSPACE_DIR/src
export OUTPUT_DIR=$WORKSPACE_DIR/out
export BUILD_DIR=$WORKSPACE_DIR/build
export TOOLS_DIR=$OUTPUT_DIR/tools
export SYSROOT_DIR=$PWD/sysroot

export CFLAGS="-Os"
export CPPFLAGS="-Os"
export CXXFLAGS="-Os"

export PKG_CONFIG_SYSROOT_DIR="/"
export PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1
export PKG_CONFIG_ALLOW_SYSTEM_LIBS=1

CONFIG_STRIP_AND_DELETE_DOCS=1

#End of optional parameters
function step() {
    echo -e "\e[7m\e[1m>>> $1\e[0m"
}

function success() {
    echo -e "\e[1m\e[32m$1\e[0m"
}

function error() {
    echo -e "\e[1m\e[31m$1\e[0m"
}

function extract() {
    case $1 in
        *.tgz) tar -zxf $1 -C $2 ;;
        *.tar.gz) tar -zxf $1 -C $2 ;;
        *.tar.bz2) tar -jxf $1 -C $2 ;;
        *.tar.xz) tar -Jxf $1 -C $2 ;;
    esac
}

totalsteps=18

step "[1/$totalsteps] Raspberry Pi Linux Kernel API Headers"
#Required to be completed before the glibc step
extract $SOURCES_DIR/linux-raspberrypi-kernel_1.20210201-1.tar.gz $BUILD_DIR
make -j$PARALLEL_JOBS ARCH=$CONFIG_LINUX_ARCH mrproper -C $BUILD_DIR/linux-raspberrypi-kernel_1.20210201-1
make -j$PARALLEL_JOBS ARCH=$CONFIG_LINUX_ARCH headers_check -C $BUILD_DIR/linux-raspberrypi-kernel_1.20210201-1
make -j$PARALLEL_JOBS ARCH=$CONFIG_LINUX_ARCH INSTALL_HDR_PATH=$SYSROOT_DIR/usr headers_install -C $BUILD_DIR/linux-raspberrypi-kernel_1.20210201-1
rm -rf $BUILD_DIR/linux-raspberrypi-kernel_1.20210201-1

step "[2/$totalsteps] man pages"
extract $SOURCES_DIR/man-pages-5.10.tar.xz $BUILD_DIR
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/man-pages-5.10
rm -rf $BUILD_DIR/man-pages-5.10

step "[3/$totalsteps] glibc"
extract $SOURCES_DIR/glibc-2.33.tar.xz $BUILD_DIR
mkdir $BUILD_DIR/glibc-2.33/glibc-build
( cd $BUILD_DIR/glibc-2.33/glibc-build && \
    CFLAGS="-O2 " CPPFLAGS="" CXXFLAGS="-Os " LDFLAGS="" \
    ac_cv_path_BASH_SHELL=/bin/sh \
    libc_cv_forced_unwind=yes \
    libc_cv_ssp=no \
    $BUILD_DIR/glibc-2.33/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST \
    --prefix=/usr \
    --enable-shared \
    --without-cvs \
    --disable-profile \
    --without-gd \
    --enable-obsolete-rpc \
    --enable-kernel=5.10 \
    --with-headers=$SYSROOT_DIR/usr/include )
make -j$PARALLEL_JOBS -C $BUILD_DIR/glibc-2.33/glibc-build
make -j$PARALLEL_JOBS install_root=$SYSROOT_DIR install -C $BUILD_DIR/glibc-2.33/glibc-build
rm -rf $BUILD_DIR/glibc-2.33

step "[4/$totalsteps] tcl"
extract $SOURCES_DIR/tcl8.6.11-src.tar.gz $BUILD_DIR
mkdir $BUILD_DIR/tcl8.6.11/unix/tcl-build
( cd $BUILD_DIR/tcl8.6.11/unix/tcl-build && \
    CFLAGS="-Os " CPPFLAGS="" CXXFLAGS="-Os " LDFLAGS="" \
    ac_cv_path_BASH_SHELL=/bin/sh \
    libc_cv_forced_unwind=yes \
    libc_cv_ssp=no \
    $BUILD_DIR/tcl8.6.11/unix/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/tcl8.6.11/unix/tcl-build
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/tcl8.6.11/unix/tcl-build
rm -rf $BUILD_DIR/tcl8.6.11

step "[5/$totalsteps] help2man"
extract $SOURCES_DIR/help2man-1.48.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/help2man-1.48.1 && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/help2man-1.48.1/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST \
	--disable-static \
	--enable-shared)
make -j1 -C $BUILD_DIR/help2man-1.48.1
make -j1 DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/help2man-1.48.1
rm -rf $BUILD_DIR/help2man-1.48.1

step "[6/10] m4"

extract $SOURCES_DIR/m4-branch-1.4.tar.gz $BUILD_DIR
#The bootstrap script tries to download translation files but the files have disappeared from translationproject.org so the code between this comment and the next will download the files from the waybackmachine and disable the use of the original download function
( cd $BUILD_DIR/m4-branch-1.4/po && \
	mkdir .reference && \
	cd .reference && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/bg.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/cs.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/da.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/de.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/el.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/eo.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/es.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/fi.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/fr.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/ga.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/gl.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/hr.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/id.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/ja.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/nl.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/pl.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/pt_BR.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/ro.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/ru.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/sr.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/sv.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/vi.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/zh_CN.po && \
	wget https://web.archive.org/web/20190921162930/https://translationproject.org/latest/m4/zh_TW.po )
filename1="$BUILD_DIR/m4-branch-1.4/bootstrap"
search1="test -d \"\$_G_ref_po_dir\" || mkdir \$_G_ref_po_dir || return"
replace1="#test -d \"\$_G_ref_po_dir\" || mkdir \$_G_ref_po_dir || return"
if [[ $search1 != "" && $replace1 != "" ]]; then
	sed -i "s/$search1/$replace1/" $filename1
fi
filename2="$BUILD_DIR/m4-branch-1.4/bootstrap"
search2="func_download_po_files \$_G_ref_po_dir \$_G_domain"
replace2="#func_download_po_files \$_G_ref_po_dir \$_G_domain"
if [[ $search2 != "" && $replace2 != "" ]]; then
	sed -i "s/$search2/$replace2/" $filename2
fi
filename3="$BUILD_DIR/m4-branch-1.4/bootstrap"
search3='&& ls "$_G_ref_po_dir"\/\*.po 2>\/dev\/null'
replace3='ls "$_G_ref_po_dir"\/\*.po 2>\/dev\/null'
if [[ $search3 != "" && $replace3 != "" ]]; then
	sed -i "s/$search3/$replace3/" $filename3
fi
#CFLAGS have to be set to -O2 when cross compiling m4 to prevent configure to get terminated with errors
( cd $BUILD_DIR/m4-branch-1.4 && \
	./bootstrap && \
	automake && \
    CFLAGS="-O2" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/m4-branch-1.4/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST)
#ADDs --no-discard-stderr to a line in m4-branch-1.4/doc/Makefile.am so make commands does complete
filename="$BUILD_DIR/m4-branch-1.4/doc/Makefile.am"
search="HELP2MAN = \$(SHELL) \$(top_srcdir)\/build-aux\/missing --run help2man"
replace="HELP2MAN = \$(SHELL) \$(top_srcdir)\/build-aux\/missing --run help2man --no-discard-stderr"
if [[ $search != "" && $replace != "" ]]; then
	sed -i "s/$search/$replace/" $filename
fi
#When cross compiling m4 the number threads used has to be set 1 else the make commands fails.
make -j1 -C $BUILD_DIR/m4-branch-1.4
make -j1 DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/m4-branch-1.4
rm -rf $BUILD_DIR/m4-branch-1.4

step "[7/10] gmp"
#Required to be completed before the mpfr step and the mpc step
extract $SOURCES_DIR/gmp-6.1.2.tar.xz $BUILD_DIR
mkdir $BUILD_DIR/gmp-6.1.2/gmp-build
( cd $BUILD_DIR/gmp-6.1.2/gmp-build && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    ac_cv_path_BASH_SHELL=/bin/sh \
    libc_cv_forced_unwind=yes \
    libc_cv_ssp=no \
    $BUILD_DIR/gmp-6.1.2/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gmp-6.1.2/gmp-build
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/gmp-6.1.2/gmp-build
rm -rf $BUILD_DIR/gmp-6.1.2

step "[8/10] mpfr"
extract $SOURCES_DIR/mpfr-4.1.0.tar.xz $BUILD_DIR
( cd $BUILD_DIR/mpfr-4.1.0/ && \
	CC="gcc -isystem $SYSROOT_DIR/usr/include" \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
	CPP=/usr/bin/cpp \
    $BUILD_DIR/mpfr-4.1.0/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST \
	--with-gmp=/usr)
make -j$PARALLEL_JOBS -C $BUILD_DIR/mpfr-4.1.0
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/mpfr-4.1.0
rm -rf $BUILD_DIR/mpfr-4.1.0

step "[9/$totalsteps] e2fsprogs"
extract $SOURCES_DIR/e2fsprogs-1.46.1.tar.gz $BUILD_DIR
( cd $BUILD_DIR/e2fsprogs-1.46.1/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/e2fsprogs-1.46.1/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST)
make -j$PARALLEL_JOBS -C $BUILD_DIR/e2fsprogs-1.46.1
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/e2fsprogs-1.46.1
rm -rf $BUILD_DIR/e2fsprogs-1.46.1

step "[10/$totalsteps] kmod"
extract $SOURCES_DIR/kmod-28.tar.gz $BUILD_DIR
( cd $BUILD_DIR/kmod-28/ && \
	./autogen.sh && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/kmod-28/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST)
make -j$PARALLEL_JOBS -C $BUILD_DIR/kmod-28
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/kmod-28
rm -rf $BUILD_DIR/kmod-28

step "[11/$totalsteps] mpc"
extract $SOURCES_DIR/mpc-1.2.1.tar.gz $BUILD_DIR
( cd $BUILD_DIR/mpc-1.2.1/ && \
	CC="gcc -isystem $SYSROOT_DIR/usr/include" \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
	CPP=/usr/bin/cpp \
    $BUILD_DIR/mpc-1.2.1/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST)
make -j$PARALLEL_JOBS -C $BUILD_DIR/mpc-1.2.1
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/mpc-1.2.1
rm -rf $BUILD_DIR/mpc-1.2.1

step "[12/$totalsteps] zlib"
extract $SOURCES_DIR/zlib-1.2.11.tar.xz $BUILD_DIR
( cd $BUILD_DIR/zlib-1.2.11/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
	CC="$CONFIG_TARGET-gcc" \
    $BUILD_DIR/zlib-1.2.11/configure )
make -j$PARALLEL_JOBS -C $BUILD_DIR/zlib-1.2.11
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/zlib-1.2.11
rm -rf $BUILD_DIR/zlib-1.2.11

step "[13/$totalsteps] flex"
extract $SOURCES_DIR/flex-2.6.4.tar.gz $BUILD_DIR
( cd $BUILD_DIR/flex-2.6.4/ && \
	./autogen.sh && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/flex-2.6.4/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST)
make -j$PARALLEL_JOBS -C $BUILD_DIR/flex-2.6.4
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/flex-2.6.4
rm -rf $BUILD_DIR/flex-2.6.4

step "[14/$totalsteps] bison"
extract $SOURCES_DIR/bison-3.6.93.tar.xz $BUILD_DIR
( cd $BUILD_DIR/bison-3.6.93/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/bison-3.6.93/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST)
make -j$PARALLEL_JOBS -C $BUILD_DIR/bison-3.6.93
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/bison-3.6.93
rm -rf $BUILD_DIR/bison-3.6.93

step "[15/$totalsteps] binutils"
extract $SOURCES_DIR/binutils-2.36.tar.xz $BUILD_DIR
( cd $BUILD_DIR/binutils-2.36/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/binutils-2.36/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST)
make -j$PARALLEL_JOBS -C $BUILD_DIR/binutils-2.36
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/binutils-2.36
rm -rf $BUILD_DIR/binutils-2.36

step "[16/$totalsteps] gcc"
extract $SOURCES_DIR/gcc-10.2.0.tar.xz $BUILD_DIR
( cd $BUILD_DIR/gcc-10.2.0/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/gcc-10.2.0/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST \
	--with-gmp=$SYSROOT_DIR/usr/local/include/ \
	--with-mpfr=$SYSROOT_DIR/usr/local/include/ \
	--with-mpc=$SYSROOT_DIR/usr/local/include/ )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gcc-10.2.0
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/gcc-10.2.0
rm -rf $BUILD_DIR/gcc-10.2.0

step "[17/$totalsteps] gdbm"
extract $SOURCES_DIR/gdbm-1.19.tar.gz $BUILD_DIR
( cd $BUILD_DIR/gdbm-1.19/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/gdbm-1.19/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST)
make -j$PARALLEL_JOBS -C $BUILD_DIR/gdbm-1.19
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/gdbm-1.19
rm -rf $BUILD_DIR/gdbm-1.19

step "[18/$totalsteps] attr"
extract $SOURCES_DIR/attr-2.4.48-2.36.tar.gz $BUILD_DIR
( cd $BUILD_DIR/attr-2.4.48/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/attr-2.4.48/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST)
make -j$PARALLEL_JOBS -C $BUILD_DIR/attr-2.4.48
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/attr-2.4.48
rm -rf $BUILD_DIR/attr-2.4.48
