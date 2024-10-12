#!/bin/bash

KERNEL_VERSION=6.11.3
BUSYBOX_VERSION=1.37.0

mkdir -p src
cd src

# Kiểm tra và tải về Linux Kernel nếu chưa có
KERNEL_MAJOR=$(echo $KERNEL_VERSION | sed 's/\([0-9]*\)[^0-9].*/\1/')
if [ ! -d "linux-$KERNEL_VERSION" ]; then
    if [ ! -f "linux-$KERNEL_VERSION.tar.xz" ]; then
        wget https://mirrors.edge.kernel.org/pub/linux/kernel/v$KERNEL_MAJOR.x/linux-$KERNEL_VERSION.tar.xz
    fi
    tar -xf linux-$KERNEL_VERSION.tar.xz
fi

# Compile Linux Kernel
cd linux-$KERNEL_VERSION
make defconfig
make -j8 || exit
cd ..

# Kiểm tra và tải về BusyBox nếu chưa có
if [ ! -d "busybox-$BUSYBOX_VERSION" ]; then
    if [ ! -f "busybox-$BUSYBOX_VERSION.tar.bz2" ]; then
        wget https://www.busybox.net/downloads/busybox-$BUSYBOX_VERSION.tar.bz2
    fi
    tar -xf busybox-$BUSYBOX_VERSION.tar.bz2
fi

# Compile BusyBox
cd busybox-$BUSYBOX_VERSION
make defconfig
sed -i 's/^CONFIG_TC=y$/CONFIG_TC=n/' .config
sed 's/^.*CONFIG_STATIC.*$/CONFIG_STATIC=y/g' -i .config
make -j8 || exit
cd ..
cd ..

# Copy Kernel image
cp src/linux-$KERNEL_VERSION/arch/x86_64/boot/bzImage ./

# Tạo initrd
mkdir -p initrd
cd initrd
mkdir -p bin dev proc sys

# Copy BusyBox
cd bin
cp ../../src/busybox-$BUSYBOX_VERSION/busybox ./
for prog in $(./busybox --list); do
    ln -s ./busybox ./$prog
done
cd ..

# Tạo init script
cat << EOF > init
#!/bin/sh
mount -t sysfs sysfs /sys
mount -t proc proc /proc
mount -t devtmpfs udev /dev
sysctl -w kernel.printk="2 4 1 7"
/bin/sh
EOF

# Thiết lập quyền cho init script
chmod 755 init

# Tạo file initrd.img
find . | cpio -o -H newc > ../initrd.img
cd ..

# Chạy QEMU
qemu-system-x86_64 -kernel bzImage -initrd initrd.img

