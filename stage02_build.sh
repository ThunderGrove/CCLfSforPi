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
export ROOTFS_DIR=$WORKSPACE_DIR/sysroot

export CFLAGS="-Os"
export CPPFLAGS="-Os"
export CXXFLAGS="-Os"

export PKG_CONFIG_SYSROOT_DIR="/"
export PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1
export PKG_CONFIG_ALLOW_SYSTEM_LIBS=1

CONFIG_STRIP_AND_DELETE_DOCS=1

#End of optional parameters
totalsteps=68
count=0

function step(){
	((count=$count+1))
    echo -e "\e[7m\e[1m>>> [$count/$1\e[0m"
}

function extract(){
    case $1 in
        *.tgz) tar -zxf $1 -C $2 ;;
        *.tar.gz) tar -zxf $1 -C $2 ;;
        *.tar.bz2) tar -jxf $1 -C $2 ;;
        *.tar.xz) tar -Jxf $1 -C $2 ;;
    esac
}

step "$totalsteps] Create root file system directory."
rm -rf $ROOTFS_DIR
mkdir -pv $ROOTFS_DIR/{boot,bin,dev,etc,lib,media,mnt,opt,proc,root,run,sbin,sys,tmp,usr}
ln -snvf lib $ROOTFS_DIR/lib64
mkdir -pv $ROOTFS_DIR/dev/{pts,shm}
mkdir -pv $ROOTFS_DIR/etc/{network,profile.d}
mkdir -pv $ROOTFS_DIR/etc/network/{if-down.d,if-post-down.d,if-pre-up.d,if-up.d}
mkdir -pv $ROOTFS_DIR/usr/{bin,lib,sbin}
ln -snvf lib $ROOTFS_DIR/usr/lib64
mkdir -pv $ROOTFS_DIR/var/lib

step "$totalsteps] Creating Essential Files and Symlinks."
# Create /etc/passwd
cat > $ROOTFS_DIR/etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/sh
daemon:x:1:1:daemon:/usr/sbin:/bin/false
bin:x:2:2:bin:/bin:/bin/false
sys:x:3:3:sys:/dev:/bin/false
sync:x:4:100:sync:/bin:/bin/sync
mail:x:8:8:mail:/var/spool/mail:/bin/false
www-data:x:33:33:www-data:/var/www:/bin/false
operator:x:37:37:Operator:/var:/bin/false
nobody:x:65534:65534:nobody:/home:/bin/false
EOF
# Create /etc/shadow
cat > $ROOTFS_DIR/etc/shadow << "EOF"
root::10933:0:99999:7:::
daemon:*:10933:0:99999:7:::
bin:*:10933:0:99999:7:::
sys:*:10933:0:99999:7:::
sync:*:10933:0:99999:7:::
mail:*:10933:0:99999:7:::
www-data:*:10933:0:99999:7:::
operator:*:10933:0:99999:7:::
nobody:*:10933:0:99999:7:::
EOF
# Create /etc/passwd
cat > $ROOTFS_DIR/etc/group << "EOF"
root:x:0:
daemon:x:1:
bin:x:2:
sys:x:3:
adm:x:4:
tty:x:5:
disk:x:6:
lp:x:7:
mail:x:8:
kmem:x:9:
wheel:x:10:root
cdrom:x:11:
dialout:x:18:
floppy:x:19:
video:x:28:
audio:x:29:
tape:x:32:
www-data:x:33:
operator:x:37:
utmp:x:43:
plugdev:x:46:
staff:x:50:
lock:x:54:
netdev:x:82:
users:x:100:
nogroup:x:65534:
EOF
echo "Welcome to CCLfSforPi" > $ROOTFS_DIR/etc/issue
ln -svf /proc/self/mounts $ROOTFS_DIR/etc/mtab
ln -svf /tmp $ROOTFS_DIR/var/cache
ln -svf /tmp $ROOTFS_DIR/var/lib/misc
ln -svf /tmp $ROOTFS_DIR/var/lock
ln -svf /tmp $ROOTFS_DIR/var/log
ln -svf /tmp $ROOTFS_DIR/var/run
ln -svf /tmp $ROOTFS_DIR/var/spool
ln -svf /tmp $ROOTFS_DIR/var/tmp
ln -svf /tmp/log $ROOTFS_DIR/dev/log
ln -svf /tmp/resolv.conf $ROOTFS_DIR/etc/resolv.conf

step "$totalsteps] Raspberry Pi Linux Kernel"
extract $SOURCES_DIR/linux-raspberrypi-kernel_1.20210201-1.tar.gz $BUILD_DIR
KERNEL=kernel8 make bcm2711_defconfig ARCH=arm64 CROSS_COMPILE=$CONFIG_TARGET- -C $BUILD_DIR/linux-raspberrypi-kernel_1.20210201-1
make oldconfig ARCH=arm64 CROSS_COMPILE=$CONFIG_TARGET- -C $BUILD_DIR/linux-raspberrypi-kernel_1.20210201-1
make prepare ARCH=arm64 CROSS_COMPILE=$CONFIG_TARGET- -C $BUILD_DIR/linux-raspberrypi-kernel_1.20210201-1
make -j$PARALLEL_JOBS ARCH=arm64 CROSS_COMPILE=$CONFIG_TARGET- Image modules dtbs -C $BUILD_DIR/linux-raspberrypi-kernel_1.20210201-1
make -j$PARALLEL_JOBS ARCH=$CONFIG_LINUX_ARCH INSTALL_MOD_PATH=$SYSROOT_DIR modules_install -C $BUILD_DIR/linux-raspberrypi-kernel_1.20210201-1

step "$totalsteps] Raspberry Pi Linux Kernel API Headers"
#Required to be completed before the glibc step
make -j$PARALLEL_JOBS ARCH=arm64 CROSS_COMPILE=$CONFIG_TARGET- mrproper headers_check -C $BUILD_DIR/linux-raspberrypi-kernel_1.20210201-1
make -j$PARALLEL_JOBS ARCH=$CONFIG_LINUX_ARCH INSTALL_HDR_PATH=$SYSROOT_DIR/usr headers_install -C $BUILD_DIR/linux-raspberrypi-kernel_1.20210201-1

#rm -rf $BUILD_DIR/linux-raspberrypi-kernel_1.20210201-1

step "$totalsteps] man pages"
extract $SOURCES_DIR/man-pages-5.10.tar.xz $BUILD_DIR
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/man-pages-5.10
rm -rf $BUILD_DIR/man-pages-5.10

step "$totalsteps] glibc"
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

step "$totalsteps] tcl"
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

step "$totalsteps] help2man"
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

step "$totalsteps] m4"
extract $SOURCES_DIR/m4-branch-1.4.tar.gz $BUILD_DIR
#The bootstrap script bootstrap needs to be executed before ./configure else ./configure will fail
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
    --build=$CONFIG_HOST )
#ADDs --no-discard-stderr to a line in m4-branch-1.4/doc/Makefile.am so make commands does complete
filename4="$BUILD_DIR/m4-branch-1.4/doc/Makefile.am"
search4="HELP2MAN = \$(SHELL) \$(top_srcdir)\/build-aux\/missing --run help2man"
replace4="HELP2MAN = \$(SHELL) \$(top_srcdir)\/build-aux\/missing --run help2man --no-discard-stderr"
if [[ $search4 != "" && $replace4 != "" ]]; then
	sed -i "s/$search4/$replace4/" $filename4
fi
#When cross compiling m4 the number threads used has to be set 1 else the make commands fails.
make -j1 -C $BUILD_DIR/m4-branch-1.4
make -j1 DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/m4-branch-1.4
rm -rf $BUILD_DIR/m4-branch-1.4

step "$totalsteps] gmp"
#Required to be completed before the mpfr step and the mpc step
extract $SOURCES_DIR/gmp-6.1.2.tar.xz $BUILD_DIR
( cd $BUILD_DIR/gmp-6.1.2 && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    ac_cv_path_BASH_SHELL=/bin/sh \
    $BUILD_DIR/gmp-6.1.2/configure \
    --target=$CONFIG_TARGET \
    --host=aarch64-linux-gnu \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gmp-6.1.2
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/gmp-6.1.2
#The uncompresed sources does not get removed here since they are need when compilling GCC later

step "$totalsteps] mpfr"
extract $SOURCES_DIR/mpfr-4.1.0.tar.xz $BUILD_DIR
( cd $BUILD_DIR/mpfr-4.1.0/ && \
	CC="gcc -isystem $SYSROOT_DIR/usr/include" \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
	CPP=/usr/bin/cpp \
    $BUILD_DIR/mpfr-4.1.0/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST \
	--with-gmp=/usr )
make -j$PARALLEL_JOBS -C $BUILD_DIR/mpfr-4.1.0
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/mpfr-4.1.0
#The uncompresed sources does not get here since the are need when compilling GCC later

step "$totalsteps] e2fsprogs"
extract $SOURCES_DIR/e2fsprogs-1.46.1.tar.gz $BUILD_DIR
( cd $BUILD_DIR/e2fsprogs-1.46.1/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/e2fsprogs-1.46.1/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/e2fsprogs-1.46.1
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/e2fsprogs-1.46.1
rm -rf $BUILD_DIR/e2fsprogs-1.46.1

step "$totalsteps] kmod"
extract $SOURCES_DIR/kmod-28.tar.gz $BUILD_DIR
( cd $BUILD_DIR/kmod-28/ && \
	./autogen.sh && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/kmod-28/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/kmod-28
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/kmod-28
rm -rf $BUILD_DIR/kmod-28

step "$totalsteps] mpc"
extract $SOURCES_DIR/mpc-1.2.1.tar.gz $BUILD_DIR
( cd $BUILD_DIR/mpc-1.2.1/ && \
	CC="gcc -isystem $SYSROOT_DIR/usr/include" \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
	CPP=/usr/bin/cpp \
    $BUILD_DIR/mpc-1.2.1/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/mpc-1.2.1
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/mpc-1.2.1
#The uncompresed sources does not get here since the are need when compilling GCC later

step "$totalsteps] zlib"
extract $SOURCES_DIR/zlib-1.2.11.tar.xz $BUILD_DIR
( cd $BUILD_DIR/zlib-1.2.11/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
	CC="$CONFIG_TARGET-gcc" \
    $BUILD_DIR/zlib-1.2.11/configure )
make -j$PARALLEL_JOBS -C $BUILD_DIR/zlib-1.2.11
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/zlib-1.2.11
rm -rf $BUILD_DIR/zlib-1.2.11

step "$totalsteps] flex"
extract $SOURCES_DIR/flex-2.6.4.tar.gz $BUILD_DIR
( cd $BUILD_DIR/flex-2.6.4/ && \
	./autogen.sh && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/flex-2.6.4/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/flex-2.6.4
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/flex-2.6.4
rm -rf $BUILD_DIR/flex-2.6.4

step "$totalsteps] bison"
extract $SOURCES_DIR/bison-3.6.93.tar.xz $BUILD_DIR
( cd $BUILD_DIR/bison-3.6.93/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/bison-3.6.93/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/bison-3.6.93
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/bison-3.6.93
rm -rf $BUILD_DIR/bison-3.6.93

step "$totalsteps] binutils"
extract $SOURCES_DIR/binutils-2.36.tar.xz $BUILD_DIR
( cd $BUILD_DIR/binutils-2.36/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/binutils-2.36/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/binutils-2.36
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/binutils-2.36
rm -rf $BUILD_DIR/binutils-2.36

#step "$totalsteps] gcc"
#extract $SOURCES_DIR/gcc-10.2.0.tar.xz $BUILD_DIR
#cp -ar $SOURCES_DIR/gcc-releases-gcc-10 $BUILD_DIR
#mv -v $BUILD_DIR/gcc-releases-gcc-10 $BUILD_DIR/gcc-10.2.0
#extract $SOURCES_DIR/isl-0.23.tar.xz $BUILD_DIR
#mv -v $BUILD_DIR/gmp-6.1.2 $BUILD_DIR/gcc-10.2.0/gmp
#mv -v $BUILD_DIR/mpfr-4.1.0 $BUILD_DIR/gcc-10.2.0/mpfc
#mv -v $BUILD_DIR/mpc-1.2.1 $BUILD_DIR/gcc-10.2.0/mpc
#mv -v $BUILD_DIR/isl-0.23 $BUILD_DIR/gcc-10.2.0/isl
#( cd $BUILD_DIR/gcc-10.2.0/ && \
#    CFLAGS="-O2" CPPFLAGS="" CXXFLAGS="-O2" LDFLAGS="" \
#    $BUILD_DIR/gcc-10.2.0/configure \
#    --target=$CONFIG_TARGET \
#    --host=aarch64-linux-gnu \
#    --build=$CONFIG_HOST \
#	--disable-libgomp \
#	--with-sysroot=$SYSROOT_DIR \
#	--disable-libgomp )
#ADDs --no-discard-stderr to a line in m4-branch-1.4/doc/Makefile.am so make commands does complete
#filename5="$BUILD_DIR/gcc-10.2.0/configure"
#search5="for ac_option in --version -v -V -qversion; do"
#replace5="for ac_option in --version -v; do"
#if [[ $search5 != "" && $replace5 != "" ]]; then
#	sed -i "s/$search5/$replace5/" $filename5
#fi
#make -j$PARALLEL_JOBS -C $BUILD_DIR/gcc-10.2.0
#make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/gcc-10.2.0
#rm -rf $BUILD_DIR/gcc-10.2.0

step "$totalsteps] gdbm"
extract $SOURCES_DIR/gdbm-1.19.tar.gz $BUILD_DIR
( cd $BUILD_DIR/gdbm-1.19/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/gdbm-1.19/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gdbm-1.19
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/gdbm-1.19
rm -rf $BUILD_DIR/gdbm-1.19

step "$totalsteps] attr"
extract $SOURCES_DIR/attr-2.4.48.tar.gz $BUILD_DIR
( cd $BUILD_DIR/attr-2.4.48/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/attr-2.4.48/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/attr-2.4.48
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/attr-2.4.48
rm -rf $BUILD_DIR/attr-2.4.48

step "$totalsteps] acl"
extract $SOURCES_DIR/acl-2.3.0.tar.xz $BUILD_DIR
( cd $BUILD_DIR/acl-2.3.0/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/acl-2.3.0/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/acl-2.3.0
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/acl-2.3.0
rm -rf $BUILD_DIR/acl-2.3.0

step "$totalsteps] sed"
extract $SOURCES_DIR/sed-4.8.tar.xz $BUILD_DIR
( cd $BUILD_DIR/sed-4.8/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/sed-4.8/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/sed-4.8
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/sed-4.8
rm -rf $BUILD_DIR/sed-4.8

#step "$totalsteps] pkg-config"
#extract $SOURCES_DIR/pkg-config-0.29.2.tar.gz $BUILD_DIR
#( cd $BUILD_DIR/pkg-config-0.29.2/ && \
#    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
#    $BUILD_DIR/pkg-config-0.29.2/configure \
#    --target=$CONFIG_TARGET \
#    --host=$CONFIG_TARGET \
#    --build=$CONFIG_HOST )
#make -j$PARALLEL_JOBS -C $BUILD_DIR/pkg-config-0.29.2
#make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/pkg-config-0.29.2
#rm -rf $BUILD_DIR/pkg-config-0.29.2

step "$totalsteps] ncurses"
extract $SOURCES_DIR/ncurses.tar.gz $BUILD_DIR
#Without --disable-stripping as a flag on configure the make install command will fail
( cd $BUILD_DIR/ncurses-6.2/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/ncurses-6.2/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST \
	--disable-stripping \
	--without-tests )
make -j$PARALLEL_JOBS -C $BUILD_DIR/ncurses-6.2
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/ncurses-6.2
rm -rf $BUILD_DIR/ncurses-6.2

step "$totalsteps] shadow"
extract $SOURCES_DIR/shadow-4.8.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/shadow-4.8.1/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/shadow-4.8.1/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/shadow-4.8.1
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/shadow-4.8.1
rm -rf $BUILD_DIR/shadow-4.8.1

step "$totalsteps] procps"
extract $SOURCES_DIR/procps-v3.3.16.tar.gz $BUILD_DIR
#Procps are unable to find ncurses when cross compiling
( cd $BUILD_DIR/procps-v3.3.16/ && \
	./autogen.sh && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/procps-v3.3.16/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST \
	--without-ncurses )
make -j$PARALLEL_JOBS -C $BUILD_DIR/procps-v3.3.16
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/procps-v3.3.16
rm -rf $BUILD_DIR/procps-v3.3.16

step "$totalsteps] libcap"
extract $SOURCES_DIR/libcap-2.49.tar.gz $BUILD_DIR
#Libcap do not use the configure command.
make -j$PARALLEL_JOBS CC=$CONFIG_TARGET-gcc BUILD_CC=gcc LIBATTR=no PAM_CAP=no -C $BUILD_DIR/libcap-2.49
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/libcap-2.49
rm -rf $BUILD_DIR/libcap-2.49

step "$totalsteps] libtool"
extract $SOURCES_DIR/libtool-2.4.6.tar.xz $BUILD_DIR
( cd $BUILD_DIR/libtool-2.4.6/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/libtool-2.4.6/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/libtool-2.4.6
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/libtool-2.4.6
rm -rf $BUILD_DIR/libtool-2.4.6

step "$totalsteps] iana-etc"
extract $SOURCES_DIR/iana-etc-20210202.tar.gz $BUILD_DIR
( cd $BUILD_DIR/iana-etc-20210202/ && \
    cp services protocols $SYSROOT_DIR/etc )
rm -rf $BUILD_DIR/iana-etc-20210202

step "$totalsteps] coreutils"
extract $SOURCES_DIR/coreutils-8.32.tar.xz $BUILD_DIR
#When compiling for 64-bit ARM the command SYS_getdents are called SYS_getdents64. This is not cross compiler specefic as compiling native on 64-bit ARM will fail with same error.
filename6="$BUILD_DIR/coreutils-8.32/src/ls.c"
search6="SYS_getdents,"
replace6="SYS_getdents64,"
if [[ $search6 != "" && $replace6 != "" ]]; then
	sed -i "s/$search6/$replace6/" $filename6
fi
( cd $BUILD_DIR/coreutils-8.32/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/coreutils-8.32/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/coreutils-8.32
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/coreutils-8.32
rm -rf $BUILD_DIR/coreutils-8.32

step "$totalsteps] iproute2"
extract $SOURCES_DIR/iproute2-5.9.0.tar.xz $BUILD_DIR
( cd $BUILD_DIR/iproute2-5.9.0/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/iproute2-5.9.0/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/iproute2-5.9.0
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/iproute2-5.9.0
rm -rf $BUILD_DIR/iproute2-5.9.0

#step "$totalsteps] bzip2-1.0.8"
#extract $SOURCES_DIR/bzip2-1.0.8.tar.gz $BUILD_DIR
#This sed command are from the offecial Cross Linux from Scratch to diasable test commands that does not work when Cross Compiling.
#sed -e "/^all:/s/ test//" $BUILD_DIR/bzip2-1.0.8/Makefile
#make -j$PARALLEL_JOBS -f Makefile-libbz2_so CC=$CONFIG_TARGET-gcc BUILD_CC=gcc -C $BUILD_DIR/bzip2-1.0.8
#make -j$PARALLEL_JOBS CC=$CONFIG_TARGET-gcc BUILD_CC=gcc -C $BUILD_DIR/bzip2-1.0.8
#make -j$PARALLEL_JOBS PREFIX=$SYSROOT_DIR/usr install -C $BUILD_DIR/bzip2-1.0.8
#cp -v bzip2-shared $SYSROOT_DIR/bin/bzip2
#cp -av libbz2.so* $SYSROOT_DIR/lib
#rm -rf $BUILD_DIR/bzip2-1.0.8

#step "$totalsteps] perl"
#extract $SOURCES_DIR/perl-5.32.1.tar.gz $BUILD_DIR
#( cd $BUILD_DIR/perl-5.32.1/ && \
#    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
#    $BUILD_DIR/perl-5.32.1/configure.gnu \
#    --target=$CONFIG_TARGET \
#    --host=$CONFIG_TARGET \
#    --build=$CONFIG_HOST )
#make -j$PARALLEL_JOBS -C $BUILD_DIR/perl-5.32.1
#make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/perl-5.32.1
#rm -rf $BUILD_DIR/perl-5.32.1

step "$totalsteps] readline"
extract $SOURCES_DIR/readline-8.1.tar.gz $BUILD_DIR
( cd $BUILD_DIR/readline-8.1/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/readline-8.1/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/readline-8.1
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/readline-8.1
rm -rf $BUILD_DIR/readline-8.1

step "$totalsteps] autoconf"
extract $SOURCES_DIR/autoconf-2.71.tar.xz $BUILD_DIR
( cd $BUILD_DIR/autoconf-2.71/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/autoconf-2.71/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/autoconf-2.71
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/autoconf-2.71
rm -rf $BUILD_DIR/autoconf-2.71

step "$totalsteps] automake"
extract $SOURCES_DIR/automake-1.16.3.tar.xz $BUILD_DIR
( cd $BUILD_DIR/automake-1.16.3/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/automake-1.16.3/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/automake-1.16.3
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/automake-1.16.3
rm -rf $BUILD_DIR/automake-1.16.3

step "$totalsteps] bash"
extract $SOURCES_DIR/bash-5.1.tar.gz $BUILD_DIR
( cd $BUILD_DIR/bash-5.1/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/bash-5.1/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/bash-5.1
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/bash-5.1
rm -rf $BUILD_DIR/bash-5.1

#step "$totalsteps] bc"
#The GNU bc can not be cross compiled use this as repalcement: https://github.com/gavinhoward/bc/releases
#extract $SOURCES_DIR/bc-3.3.4.tar.xz $BUILD_DIR
#( cd $BUILD_DIR/bc-3.3.4/ && \
#    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
#	CC=$CONFIG_TARGET-gcc HOST_CC="/usr/bin/cpp" \
#    $BUILD_DIR/bc-3.3.4/configure )
#make -j$PARALLEL_JOBS -C $BUILD_DIR/bc-3.3.4
#make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/bc-3.3.4
#rm -rf $BUILD_DIR/bc-3.3.4

step "$totalsteps] diffutils"
extract $SOURCES_DIR/diffutils-3.7.tar.xz $BUILD_DIR
( cd $BUILD_DIR/diffutils-3.7/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/diffutils-3.7/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/diffutils-3.7
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/diffutils-3.7
rm -rf $BUILD_DIR/diffutils-3.7

step "$totalsteps] file"
#When cross compiling file you need to compile the same version that are installed on host system else make fails.
extract $SOURCES_DIR/file-5.40.tar.gz $BUILD_DIR
( cd $BUILD_DIR/file-5.40/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/file-5.40/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/file-5.40
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/file-5.40
rm -rf $BUILD_DIR/file-5.40

step "$totalsteps] gawk"
extract $SOURCES_DIR/gawk-5.1.0.tar.xz $BUILD_DIR
( cd $BUILD_DIR/gawk-5.1.0/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/gawk-5.1.0/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gawk-5.1.0
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/gawk-5.1.0
rm -rf $BUILD_DIR/gawk-5.1.0

step "$totalsteps] findutils"
extract $SOURCES_DIR/findutils-4.8.0.tar.xz $BUILD_DIR
( cd $BUILD_DIR/findutils-4.8.0/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/findutils-4.8.0/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/findutils-4.8.0
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/findutils-4.8.0
rm -rf $BUILD_DIR/findutils-4.8.0

step "$totalsteps] gettext"
extract $SOURCES_DIR/gettext-0.21.tar.gz $BUILD_DIR
( cd $BUILD_DIR/gettext-0.21/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/gettext-0.21/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gettext-0.21
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/gettext-0.21
rm -rf $BUILD_DIR/gettext-0.21

step "$totalsteps] gperf"
extract $SOURCES_DIR/gperf-3.1.tar.gz $BUILD_DIR
( cd $BUILD_DIR/gperf-3.1/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/gperf-3.1/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gperf-3.1
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/gperf-3.1
rm -rf $BUILD_DIR/gperf-3.1

step "$totalsteps] grep-3.6"
extract $SOURCES_DIR/grep-3.6.tar.xz $BUILD_DIR
( cd $BUILD_DIR/grep-3.6/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/grep-3.6/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/grep-3.6
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/grep-3.6
rm -rf $BUILD_DIR/grep-3.6

step "$totalsteps] systemd"
#Has to be compiled before util-linux when cross compiling
extract $SOURCES_DIR/systemd-247.tar.gz $BUILD_DIR
#The flags for defining target CPU have to be set on "make" commands instead of on the "configure" command.
( cd $BUILD_DIR/systemd-247/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/systemd-247/configure)
make -j$PARALLEL_JOBS CC=$CONFIG_TARGET BUILD_CC=gcc LIBATTR=no PAM_CAP=no -C $BUILD_DIR/systemd-247
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/systemd-247
rm -rf $BUILD_DIR/systemd-247

#step "$totalsteps] groff"
#extract $SOURCES_DIR/groff-1.22.4.tar.gz $BUILD_DIR
#The flag PAGE is set to A4 for international support.
#( cd $BUILD_DIR/groff-1.22.4/ && \
	CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
#	PAGE="A4" \
#	$BUILD_DIR/groff-1.22.4/configure \
#	--target=$CONFIG_TARGET \
#	--host=$CONFIG_TARGET \
#	--build=$CONFIG_HOST )
#GROFF_BIN_PATH="/usr/local/bin" GROFFBIN="groff" make -j$PARALLEL_JOBS -C $BUILD_DIR/groff-1.22.4
#GROFF_BIN_PATH="/usr/local/bin" GROFFBIN="groff" make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/gperf-3.1
#rm -rf $BUILD_DIR/groff-1.22.4

step "$totalsteps] gzip"
extract $SOURCES_DIR/gzip-1.10.tar.xz $BUILD_DIR
( cd $BUILD_DIR/gzip-1.10/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/gzip-1.10/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gzip-1.10
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/gzip-1.10
rm -rf $BUILD_DIR/gzip-1.10

step "$totalsteps] iputils"
#iputilsare moved to https://github.com/iputils/iputils/releases
extract $SOURCES_DIR/iputils-20210202.tar.gz $BUILD_DIR
( cd $BUILD_DIR/iputils-20210202/ && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/iputils-20210202/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST )
make -j$PARALLEL_JOBS IPV4_TARGETS="tracepath ping clockdiff rdisc" IPV6_TARGETS="tracepath6 traceroute6" -C $BUILD_DIR/iputils-20210202
#( cd $BUILD_DIR/iputils-20210202/ && \
#	install -v -m755 ping "$SYSROOT_DIR/bin" && \
#	install -v -m755 clockdiff "$SYSROOT_DIR/usr/bin" && \
#	install -v -m755 rdisc "$SYSROOT_DIR/usr/bin" && \
#	install -v -m755 tracepath "$SYSROOT_DIR/usr/bin" && \
#	install -v -m755 trace{path,route}6 "$SYSROOT_DIR/usr/bin" && \
#	install -v -m644 doc/*.8 "$SYSROOT_DIR/usr/share/man/man8" )
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/iputils-20210202
rm -rf $BUILD_DIR/iputils-20210202

step "$totalsteps] kbd"
extract $SOURCES_DIR/kbd-2.4.0.tar.gz $BUILD_DIR
#When crosscompiling or compiling inside a fakeroot setup the configure will fail with missing libpam-devel dependency if the flag --disable-vlock is not set
( cd $BUILD_DIR/kbd-2.4.0/ && \
	./autogen.sh && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/kbd-2.4.0/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST \
	--disable-vlock )
make -j$PARALLEL_JOBS -C $BUILD_DIR/kbd-2.4.0
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/kbd-2.4.0
rm -rf $BUILD_DIR/kbd-2.4.0

#step "$totalsteps] less-563"
#extract $SOURCES_DIR/less-563.tar.gz $BUILD_DIR
#The --with-editor flag sets the default editor and without defining it it will use vi as default
#The --with-secure flag disable some less functions that can be a security risk
#The --with-regex flag defines the regex lib less should use. The source of less includes the source of reqcomp where regcomp-local tells less to use the included regcomp.
#( cd $BUILD_DIR/less-563/ && \
#	CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
#	$BUILD_DIR/less-563/configure \
#	--target=$CONFIG_TARGET \
#	--host=$CONFIG_TARGET \
#	--build=$CONFIG_HOST \
#	--with-editor=nano \
#	--with-secure \
#	--with-regex=regcomp-local )
#make -j$PARALLEL_JOBS -C $BUILD_DIR/less-563
#make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/less-563
#rm -rf $BUILD_DIR/less-563

step "$totalsteps] libpipeline"
extract $SOURCES_DIR/libpipeline-1.5.3.tar.gz $BUILD_DIR
( cd $BUILD_DIR/libpipeline-1.5.3/ && \
	CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
	$BUILD_DIR/libpipeline-1.5.3/configure \
	--target=$CONFIG_TARGET \
	--host=$CONFIG_TARGET \
	--build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/libpipeline-1.5.3
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/libpipeline-1.5.3
rm -rf $BUILD_DIR/libpipeline-1.5.3

#step "$totalsteps] man-db"
#extract $SOURCES_DIR/man-db-2.9.4.tar.xz $BUILD_DIR
#( cd $BUILD_DIR/man-db-2.9.4/ && \
#	CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
#	$BUILD_DIR/man-db-2.9.4/configure \
#	--target=$CONFIG_TARGET \
#	--host=$CONFIG_TARGET \
#	--build=$CONFIG_HOST \
#	--disable-setuid )
#make -j$PARALLEL_JOBS -C $BUILD_DIR/man-db-2.9.4
#make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/man-db-2.9.4
#rm -rf $BUILD_DIR/man-db-2.9.4

step "$totalsteps] make"
extract $SOURCES_DIR/make-4.3.tar.gz $BUILD_DIR
( cd $BUILD_DIR/make-4.3/ && \
	CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
	$BUILD_DIR/make-4.3/configure \
	--target=$CONFIG_TARGET \
	--host=$CONFIG_TARGET \
	--build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/make-4.3
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/make-4.3
rm -rf $BUILD_DIR/make-4.3

step "$totalsteps] xz"
extract $SOURCES_DIR/xz-5.2.5.tar.xz $BUILD_DIR
( cd $BUILD_DIR/xz-5.2.5/ && \
	CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
	$BUILD_DIR/xz-5.2.5/configure \
	--target=$CONFIG_TARGET \
	--host=$CONFIG_TARGET \
	--build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/xz-5.2.5
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/xz-5.2.5
rm -rf $BUILD_DIR/xz-5.2.5

step "$totalsteps] expat"
extract $SOURCES_DIR/expat-2.3.0.tar.xz $BUILD_DIR
( cd $BUILD_DIR/expat-2.3.0/ && \
	CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
	$BUILD_DIR/expat-2.3.0/configure \
	--target=$CONFIG_TARGET \
	--host=$CONFIG_TARGET \
	--build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/expat-2.3.0
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/expat-2.3.0
rm -rf $BUILD_DIR/expat-2.3.0

#step "$totalsteps] XML-Parser"
#extract $SOURCES_DIR/XML-Parser-2.46.tar.gz $BUILD_DIR
#( cd $BUILD_DIR/XML-Parser-2.46/ && \
#	perl Makefile.PL )
#make -j$PARALLEL_JOBS CC=$CONFIG_TARGET-gcc BUILD_CC=gcc LIBATTR=no PAM_CAP=no -C $BUILD_DIR/XML-Parser-2.46
#make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/XML-Parser-2.46
#rm -rf $BUILD_DIR/XML-Parser-2.46

step "$totalsteps] intltool"
extract $SOURCES_DIR/intltool-0.51.0.tar.gz $BUILD_DIR
( cd $BUILD_DIR/intltool-0.51.0/ && \
	CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
	$BUILD_DIR/intltool-0.51.0/configure \
	--target=$CONFIG_TARGET \
	--host=$CONFIG_TARGET \
	--build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/intltool-0.51.0
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/intltool-0.51.0
rm -rf $BUILD_DIR/intltool-0.51.0

step "$totalsteps] patch"
extract $SOURCES_DIR/patch-2.7.6.tar.xz $BUILD_DIR
( cd $BUILD_DIR/patch-2.7.6/ && \
	CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
	$BUILD_DIR/patch-2.7.6/configure \
	--target=$CONFIG_TARGET \
	--host=$CONFIG_TARGET \
	--build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/patch-2.7.6
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/patch-2.7.6
rm -rf $BUILD_DIR/patch-2.7.6

#step "$totalsteps] dbus"
#extract $SOURCES_DIR/dbus-1.12.20.tar.gz $BUILD_DIR
#( cd $BUILD_DIR/dbus-1.12.20/ && \
#	CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
#	$BUILD_DIR/dbus-1.12.20/configure \
#	--target=$CONFIG_TARGET \
#	--host=$CONFIG_TARGET \
#	--build=$CONFIG_HOST \
#	--with-systemdsystemunitdir=$SYSROOT_DIR/lib/systemd/system )
#make -j$PARALLEL_JOBS -C $BUILD_DIR/dbus-1.12.20
#make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/dbus-1.12.20
#rm -rf $BUILD_DIR/dbus-1.12.20

#step "$totalsteps] psmisc"
#extract $SOURCES_DIR/psmisc-v22.21.tar.gz $BUILD_DIR
#The flag --exec-prefix is set to empty string so psmisc gets install in /bin instead for /usr/bin
#( cd $BUILD_DIR/psmisc-v22.21/ && \
#	./autogen.sh && \
#	CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
#	$BUILD_DIR/psmisc-v22.21/configure \
#	--target=$CONFIG_TARGET \
#	--host=$CONFIG_TARGET \
#	--build=$CONFIG_HOST \
#	--exec-prefix="" )
#make -j$PARALLEL_JOBS -C $BUILD_DIR/psmisc-v22.21
#make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/psmisc-v22.21
#rm -rf $BUILD_DIR/psmisc-v22.21

step "$totalsteps] tar"
extract $SOURCES_DIR/tar-1.34.tar.xz $BUILD_DIR
( cd $BUILD_DIR/tar-1.34/ && \
	CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
	$BUILD_DIR/tar-1.34/configure \
	--target=$CONFIG_TARGET \
	--host=$CONFIG_TARGET \
	--build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/tar-1.34
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/tar-1.34
rm -rf $BUILD_DIR/tar-1.34

step "$totalsteps] texinfo"
extract $SOURCES_DIR/texinfo-6.7.tar.xz $BUILD_DIR
( cd $BUILD_DIR/texinfo-6.7/ && \
	CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
	$BUILD_DIR/texinfo-6.7/configure \
	--target=$CONFIG_TARGET \
	--host=$CONFIG_TARGET \
	--build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/texinfo-6.7
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/texinfo-6.7
rm -rf $BUILD_DIR/texinfo-6.7

#step "$totalsteps] vim"
#extract $SOURCES_DIR/vim-8.2.tar.bz2 $BUILD_DIR
#When cross compiling vim the flags starting with "vim_cv" is needed else configure fails.
#The --enable-multibyte flag are needed to support multibyte charset.
#When cross compiling vim the flag --with-tlib is set to ncurses because the auto detect can not find ncurses without this flag.
#The flags after --with-tlib are recommended by CLFS.
#( cd $BUILD_DIR/vim82/ && \
#	CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="-L$SYSROOT_DIR/usr/include" \
#	vim_cv_toupper_broken="yes" vim_cv_terminfo="yes" vim_cv_tgetent=non-zero vim_cv_tty_group=world vim_cv_getcwd_broken=no vim_cv_stat_ignores_slash=no vim_cv_memmove_handles_overlap=yes vim_cv_getcwd_broken=no \
#	$BUILD_DIR/vim82/configure \
#	--target=$CONFIG_TARGET \
#	--host=$CONFIG_TARGET \
#	--build=$CONFIG_HOST \
#	--without-tests \
#	--disable-stripping \
#	--enable-multibyte \
#	--with-tlib="ncurses" \
#	--enable-gui=no \
#	--disable-gtktest \
#	--disable-xim \
#	--disable-gpm \
#	--without-x \
#	--disable-netbeans )
#make -j1 -C $BUILD_DIR/vim82
#make -j1 DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/vim82
#rm -rf $BUILD_DIR/vim82

step "$totalsteps] fish"
extract $SOURCES_DIR/fish-3.2.1.tar.xz $BUILD_DIR
#( cd $BUILD_DIR/fish-3.2.1/ && \
#	CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
#	$BUILD_DIR/fish-3.2.1/configure \
#	--target=$CONFIG_TARGET \
#	--host=$CONFIG_TARGET \
#	--build=$CONFIG_HOST )
make -j$PARALLEL_JOBS CC=$CONFIG_TARGET-gcc BUILD_CC=gcc LIBATTR=no PAM_CAP=no -C $BUILD_DIR/fish-3.2.1
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/fish-3.2.1
rm -rf $BUILD_DIR/fish-3.2.1

step "$totalsteps] nano"
extract $SOURCES_DIR/nano-5.6.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/nano-5.6.1/ && \
	CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
	$BUILD_DIR/nano-5.6.1/configure \
	--target=$CONFIG_TARGET \
	--host=$CONFIG_TARGET \
	--build=$CONFIG_HOST )
make -j$PARALLEL_JOBS -C $BUILD_DIR/nano-5.6.1
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/nano-5.6.1
rm -rf $BUILD_DIR/nano-5.6.1

step "$totalsteps] util-linux"
extract $SOURCES_DIR/util-linux-2.36.2.tar.xz $BUILD_DIR
( cd $BUILD_DIR/util-linux-2.36.2/ && \
	./autogen.sh && \
    CFLAGS="-Os" CPPFLAGS="" CXXFLAGS="-Os" LDFLAGS="" \
    $BUILD_DIR/util-linux-2.36.2/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST \
	--disable-stripping \
	--without-python )
make -j$PARALLEL_JOBS -C $BUILD_DIR/util-linux-2.36.2
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/util-linux-2.36.2
rm -rf $BUILD_DIR/util-linux-2.36.2
