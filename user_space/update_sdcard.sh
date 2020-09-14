  
#!/bin/bash
if [ "$#" -ne 4 ]; then
    echo "You have input $# arguments."
    echo "You must enter exactly 4 arguments: \$OPENWIFI_DIR \$XILINX_DIR \$BOARD_NAME \$SDCARD_DIR"
    exit 1
fi

OPENWIFI_DIR=$1
XILINX_DIR=$2
BOARD_NAME=$3
SDCARD_DIR=$4

if [ -f "$OPENWIFI_DIR/LICENSE" ]; then
    echo "\$OPENWIFI_DIR is found!"
else
    echo "\$OPENWIFI_DIR is not correct. Please check!"
    exit 1
fi

if [ -d "$XILINX_DIR/SDK" ]; then
    echo "\$XILINX_DIR is found!"
else
    echo "\$XILINX_DIR is not correct. Please check!"
    exit 1
fi

if [ "$BOARD_NAME" != "zc706_fmcs2" ] && [ "$BOARD_NAME" != "zc702_fmcs2" ] && [ "$BOARD_NAME" != "zed_fmcs2" ] && [ "$BOARD_NAME" != "adrv9361z7035" ] && [ "$BOARD_NAME" != "adrv9364z7020" ] && [ "$BOARD_NAME" != "zcu102_fmcs2" ] && [ "$BOARD_NAME" != "zcu102_9371" ]; then
    echo "\$BOARD_NAME is not correct. Please check!"
    exit 1
else
    echo "\$BOARD_NAME is found!"
fi

# detect SD card mounting status
if [ -d "$SDCARD_DIR/BOOT/" ]; then
    echo "$SDCARD_DIR/BOOT/"
    sudo mkdir $SDCARD_DIR/BOOT/openwifi
    sudo rm -rf $SDCARD_DIR/BOOT/README.txt
else
    echo "$SDCARD_DIR/BOOT/ does not exist!"
    exit 1
fi

if [ -d "$SDCARD_DIR/rootfs/" ]; then
    echo "$SDCARD_DIR/rootfs/"
else
    echo "$SDCARD_DIR/rootfs/ does not exist!"
    exit 1
fi

if [ "$BOARD_NAME" == "zcu102_fmcs2" ] || [ "$BOARD_NAME" == "zcu102_9371" ]; then
    dtb_filename="system.dtb"
    dts_filename="system.dts"
else
    dtb_filename="devicetree.dtb"
    dts_filename="devicetree.dts"
fi
echo $dtb_filename
echo $dts_filename

sudo true

home_dir=$(pwd)

set -x

cd $OPENWIFI_DIR/user_space/
./prepare_kernel.sh $OPENWIFI_DIR $XILINX_DIR 32 build
sudo true
./prepare_kernel.sh $OPENWIFI_DIR $XILINX_DIR 64 build
sudo true

LINUX_KERNEL_SRC_DIR_NAME32=adi-linux
LINUX_KERNEL_SRC_DIR_NAME64=adi-linux-64

$OPENWIFI_DIR/user_space/get_fpga.sh $OPENWIFI_DIR

BOARD_NAME_ALL="zc706_fmcs2 zed_fmcs2 zc702_fmcs2 adrv9361z7035 adrv9364z7020 zcu102_fmcs2 zcu102_9371"
# BOARD_NAME_ALL="zcu102_fmcs2"
# BOARD_NAME_ALL="adrv9361z7035"
for BOARD_NAME_TMP in $BOARD_NAME_ALL
do
    if [ "$BOARD_NAME_TMP" == "zcu102_fmcs2" ] || [ "$BOARD_NAME_TMP" == "zcu102_9371" ]; then
        dtb_filename_tmp="system.dtb"
        dts_filename_tmp="system.dts"
        $OPENWIFI_DIR/user_space/boot_bin_gen_zynqmp.sh $OPENWIFI_DIR $XILINX_DIR $BOARD_NAME_TMP
    else
        dtb_filename_tmp="devicetree.dtb"
        dts_filename_tmp="devicetree.dts"
        $OPENWIFI_DIR/user_space/boot_bin_gen.sh $OPENWIFI_DIR $XILINX_DIR $BOARD_NAME_TMP
    fi
    echo $dtb_filename_tmp
    echo $dts_filename_tmp

    dtc -I dts -O dtb -o $OPENWIFI_DIR/kernel_boot/boards/$BOARD_NAME_TMP/$dtb_filename_tmp $OPENWIFI_DIR/kernel_boot/boards/$BOARD_NAME_TMP/$dts_filename_tmp
    mkdir $SDCARD_DIR/BOOT/openwifi/$BOARD_NAME_TMP
    sudo cp $OPENWIFI_DIR/kernel_boot/boards/$BOARD_NAME_TMP/$dtb_filename_tmp $SDCARD_DIR/BOOT/openwifi/$BOARD_NAME_TMP
    sudo cp $OPENWIFI_DIR/kernel_boot/boards/$BOARD_NAME_TMP/output_boot_bin/BOOT.BIN $SDCARD_DIR/BOOT/openwifi/$BOARD_NAME_TMP
    sudo true
done

sudo mkdir $SDCARD_DIR/BOOT/openwifi/zynq-common
sudo cp $OPENWIFI_DIR/$LINUX_KERNEL_SRC_DIR_NAME32/arch/arm/boot/uImage  $SDCARD_DIR/BOOT/openwifi/zynq-common/
sudo mkdir $SDCARD_DIR/BOOT/openwifi/zynqmp-common
sudo cp $OPENWIFI_DIR/$LINUX_KERNEL_SRC_DIR_NAME64/arch/arm64/boot/Image $SDCARD_DIR/BOOT/openwifi/zynqmp-common/

# Copy uImage BOOT.BIN and devicetree to SD card BOOT partition
sudo cp $OPENWIFI_DIR/kernel_boot/boards/$BOARD_NAME/$dtb_filename $SDCARD_DIR/BOOT/
sudo cp $OPENWIFI_DIR/kernel_boot/boards/$BOARD_NAME/output_boot_bin/BOOT.BIN $SDCARD_DIR/BOOT/
if [ "$BOARD_NAME" == "zcu102_fmcs2" ] || [ "$BOARD_NAME" == "zcu102_9371" ]; then
    sudo cp $OPENWIFI_DIR/$LINUX_KERNEL_SRC_DIR_NAME64/arch/arm64/boot/Image $SDCARD_DIR/BOOT/
else
    sudo cp $OPENWIFI_DIR/$LINUX_KERNEL_SRC_DIR_NAME32/arch/arm/boot/uImage $SDCARD_DIR/BOOT/
fi

sudo mkdir $SDCARD_DIR/rootfs/root/openwifi
sudo cp $OPENWIFI_DIR/user_space/* $SDCARD_DIR/rootfs/root/openwifi/ -rf
sudo wget -P $SDCARD_DIR/rootfs/root/openwifi/webserver/ https://users.ugent.be/~xjiao/openwifi-low-aac.mp4

# build openwifi driver
$OPENWIFI_DIR/driver/make_all.sh $OPENWIFI_DIR $XILINX_DIR 32
# Copy files to SD card rootfs partition
sudo mkdir $SDCARD_DIR/rootfs/root/openwifi/drv32
sudo find $OPENWIFI_DIR/driver -name \*.ko -exec cp {} $SDCARD_DIR/rootfs/root/openwifi/drv32 \;

# build openwifi driver
$OPENWIFI_DIR/driver/make_all.sh $OPENWIFI_DIR $XILINX_DIR 64
# Copy files to SD card rootfs partition
sudo mkdir $SDCARD_DIR/rootfs/root/openwifi/drv64
sudo find $OPENWIFI_DIR/driver -name \*.ko -exec cp {} $SDCARD_DIR/rootfs/root/openwifi/drv64 \;

sudo mkdir $SDCARD_DIR/rootfs/lib/modules

sudo mkdir $SDCARD_DIR/rootfs/lib/modules/$LINUX_KERNEL_SRC_DIR_NAME32
sudo find $OPENWIFI_DIR/$LINUX_KERNEL_SRC_DIR_NAME32 -name \*.ko -exec cp {} $SDCARD_DIR/rootfs/lib/modules/$LINUX_KERNEL_SRC_DIR_NAME32/ \;
sudo rm $SDCARD_DIR/rootfs/lib/modules/$LINUX_KERNEL_SRC_DIR_NAME32/{axidmatest.ko,xilinx_dma.ko,adi_axi_hdmi.ko,ad9361_drv.ko} -f

sudo mkdir $SDCARD_DIR/rootfs/lib/modules/$LINUX_KERNEL_SRC_DIR_NAME64
sudo find $OPENWIFI_DIR/$LINUX_KERNEL_SRC_DIR_NAME64 -name \*.ko -exec cp {} $SDCARD_DIR/rootfs/lib/modules/$LINUX_KERNEL_SRC_DIR_NAME64/ \;
sudo rm $SDCARD_DIR/rootfs/lib/modules/$LINUX_KERNEL_SRC_DIR_NAME64/{axidmatest.ko,xilinx_dma.ko,adi_axi_hdmi.ko,ad9361_drv.ko} -f

sudo rm $SDCARD_DIR/rootfs/etc/udev/rules.d/70-persistent-net.rules
sudo cp $OPENWIFI_DIR/kernel_boot/70-persistent-net.rules $SDCARD_DIR/rootfs/etc/udev/rules.d/
sudo mv $SDCARD_DIR/rootfs/lib/udev/rules.d/75-persistent-net-generator.rules $SDCARD_DIR/rootfs/lib/udev/rules.d/75-persistent-net-generator.rules.bak

# Some setup
sudo echo -e "\nauto lo eth0\niface lo inet loopback\niface eth0 inet static\naddress 192.168.10.122\nnetmask 255.255.255.0\n" | sudo tee -a $SDCARD_DIR/rootfs/etc/network/interfaces
sudo echo -e "\nnameserver 8.8.8.8\nnameserver 4.4.4.4\n" | sudo tee -a $SDCARD_DIR/rootfs/etc/resolv.conf
sudo echo -e "\nUseDNS no\n" | sudo tee -a $SDCARD_DIR/rootfs/etc/ssh/sshd_config
sudo echo -e "\nnet.ipv4.ip_forward=1\n" | sudo tee -a $SDCARD_DIR/rootfs/etc/sysctl.conf
sudo chmod -x $SDCARD_DIR/rootfs/etc/update-motd.d/90-updates-available
sudo chmod -x $SDCARD_DIR/rootfs/etc/update-motd.d/91-release-upgrade

cd $SDCARD_DIR/BOOT
sync
cd $SDCARD_DIR/rootfs
sync

cd $home_dir

umount $SDCARD_DIR/BOOT/
umount $SDCARD_DIR/rootfs/
