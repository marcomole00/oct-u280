#!/usr/bin/env bash
fix_dependecy_for_config_fpga() {
    wget http://nz2.archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.23_amd64.deb
    apt-get install -y ./libssl1.1_1.1.1f-1ubuntu2.23_amd64.deb
}

install_dpdk() {
    cp /proj/octfpga-PG0/tools/dpdk.sh /opt/.
    cd /opt/
    apt-get install -y liblua5.4-dev
    ./dpdk.sh
    cd /opt/dpdk/pktgen-dpdk-pktgen-23.03.0
    sudo make clean
    export  RTE_SDK=../dpdk-$DPDK_VERSION
    export  RTE_TARGET=build
    sudo make buildlua
    }

install_cpufreq() {
    apt-get install -y cpufrequtils
    cpufreq-set -g performance
}

install_perf(){
    apt-get install -y  linux-tools-common linux-tools-generic linux-tools-`uname -r`
    git clone https://github.com/brendangregg/FlameGraph /users/markmole/flamegraph
}

set_grub_for_dpdk() {
    grub='GRUB_CMDLINE_LINUX_DEFAULT="default_hugepagesz=1G hugepagesz=1G hugepages=8 intel_iommu=on"'
	echo $grub | sudo tee -a /etc/default/grub
	sudo update-grub
}

bpf_dependencies() {
    apt-get install -y libbpf-dev clang llvm libc6-dev-i386 libelf-dev libpcap-dev pkg-config m4
}

clone_repos() {
    git clone https://github.com/marcomole00/open-nic-driver.git /users/markmole/open-nic-driver
    git clone --recurse-submodules https://github.com/marcomole00/ebpf-xdp-test-suite  /users/markmole/ebpf-xdp-test-suite
}

install_xrt() {
    echo "Install XRT"
    if [[ "$OSVERSION" == "ubuntu-20.04" ]] || [[ "$OSVERSION" == "ubuntu-22.04" ]]; then
        echo "Ubuntu XRT install"
        echo "Installing XRT dependencies..."
        apt update
        echo "Installing XRT package..."
        apt install -y $XRT_BASE_PATH/$TOOLVERSION/$OSVERSION/$XRT_PACKAGE
    fi
    sudo bash -c "echo 'source /opt/xilinx/xrt/setup.sh' >> /etc/profile"
    sudo bash -c "echo 'source $VITIS_BASE_PATH/$VITISVERSION/settings64.sh' >> /etc/profile"
}


check_xrt() {
    if [[ "$OSVERSION" == "ubuntu-20.04" ]] || [[ "$OSVERSION" == "ubuntu-22.04" ]]; then
        XRT_INSTALL_INFO=`apt list --installed 2>/dev/null | grep "xrt" | grep "$XRT_VERSION"`
    elif [[ "$OSVERSION" == "centos-8" ]]; then
        XRT_INSTALL_INFO=`yum list installed 2>/dev/null | grep "xrt" | grep "$XRT_VERSION"`
    fi
}

install_xbflash() {
    cp -r $XBFLASH_BASE_PATH/${OSVERSION} /tmp
    echo "Installing xbflash."
    if [[ "$OSVERSION" == "ubuntu-18.04" ]] || [[ "$OSVERSION" == "ubuntu-20.04" ]]; then
        apt install /tmp/${OSVERSION}/*.deb
    elif [[ "$OSVERSION" == "centos-7" ]] || [[ "$OSVERSION" == "centos-8" ]]; then
        yum install /tmp/${OSVERSION}/*.rpm
    fi    
}


detect_cards() {
    lspci > /dev/null
    if [ $? != 0 ] ; then
        if [[ "$OSVERSION" == "ubuntu-20.04" ]] || [[ "$OSVERSION" == "ubuntu-22.04" ]]; then
            apt-get install -y pciutils
        elif [[ "$OSVERSION" == "centos-7" ]] || [[ "$OSVERSION" == "centos-8" ]]; then
            yum install -y pciutils
        fi
    fi
    if [[ "$OSVERSION" == "ubuntu-20.04" ]] || [[ "$OSVERSION" == "ubuntu-22.04" ]]; then
        PCI_ADDR=$(lspci -d 10ee: | awk '{print $1}' | head -n 1)
        if [ -n "$PCI_ADDR" ]; then
            U280=$((U280 + 1))
        else
            echo "Error: No card detected."
            exit 1
        fi
    fi
}

install_config_fpga() {
    echo "Installing config-fpga."
    cp $CONFIG_FPGA_PATH/* /usr/local/bin
}

disable_pcie_fatal_error() {

    echo "Disabling PCIe fatal error reporting for node: $NODE_ID"
    
    #local group1=("pc151" "pc153" "pc154" "pc155" "pc156" "pc157" "pc158" "pc159" "pc160" "pc161" "pc162" "pc163" "pc164" "pc165" "pc166" "pc167")
    #local group2=("pc168" "pc169" "pc170" "pc171" "pc172" "pc173" "pc174" "pc175")

    # Check which group the node id belongs to and run the corresponding command
    #if [[ " ${group1[@]} " =~ " $NODE_ID " ]]; then
    sudo /proj/octfpga-PG0/tools/pcie_disable_fatal.sh $PCI_ADDR
    #elif [[ " ${group2[@]} " =~ " $NODE_ID " ]]; then
    #    sudo /proj/octfpga-PG0/tools/pcie_disable_fatal.sh 37:00.0
    #else
    #    echo "Unknown node: $NODE_ID. No action taken."
    #fi
}

XRT_BASE_PATH="/proj/octfpga-PG0/tools/deployment/xrt"
SHELL_BASE_PATH="/proj/octfpga-PG0/tools/deployment/shell"
XBFLASH_BASE_PATH="/proj/octfpga-PG0/tools/xbflash"
VITIS_BASE_PATH="/proj/octfpga-PG0/tools/Xilinx/Vitis"
CONFIG_FPGA_PATH="/proj/octfpga-PG0/tools/post-boot"

OSVERSION=`grep '^ID=' /etc/os-release | awk -F= '{print $2}'`
OSVERSION=`echo $OSVERSION | tr -d '"'`
VERSION_ID=`grep '^VERSION_ID=' /etc/os-release | awk -F= '{print $2}'`
VERSION_ID=`echo $VERSION_ID | tr -d '"'`
OSVERSION="$OSVERSION-$VERSION_ID"
WORKFLOW=$1
TOOLVERSION=$2
VITISVERSION="2023.1"
SCRIPT_PATH=/local/repository
COMB="${TOOLVERSION}_${OSVERSION}"
XRT_PACKAGE=`grep ^$COMB: $SCRIPT_PATH/spec.txt | awk -F':' '{print $2}' | awk -F';' '{print $1}' | awk -F= '{print $2}'`
SHELL_PACKAGE=`grep ^$COMB: $SCRIPT_PATH/spec.txt | awk -F':' '{print $2}' | awk -F';' '{print $2}' | awk -F= '{print $2}'`
DSA=`grep ^$COMB: $SCRIPT_PATH/spec.txt | awk -F':' '{print $2}' | awk -F';' '{print $3}' | awk -F= '{print $2}'`
PACKAGE_NAME=`grep ^$COMB: $SCRIPT_PATH/spec.txt | awk -F':' '{print $2}' | awk -F';' '{print $5}' | awk -F= '{print $2}'`
PACKAGE_VERSION=`grep ^$COMB: $SCRIPT_PATH/spec.txt | awk -F':' '{print $2}' | awk -F';' '{print $6}' | awk -F= '{print $2}'`
XRT_VERSION=`grep ^$COMB: $SCRIPT_PATH/spec.txt | awk -F':' '{print $2}' | awk -F';' '{print $7}' | awk -F= '{print $2}'`
FACTORY_SHELL="xilinx_u280_GOLDEN_8"
NODE_ID=$(hostname | cut -d'.' -f1)
#PCI_ADDR=$(lspci -d 10ee: | awk '{print $1}' | head -n 1)

echo "User name: , $USER!"
detect_cards
check_xrt
if [ $? == 0 ]; then
    echo "XRT is already installed."
else
    echo "XRT is not installed. Attempting to install XRT..."
    install_xrt

    check_xrt
    if [ $? == 0 ]; then
        echo "XRT was successfully installed."
    else
        echo "Error: XRT installation failed."
        exit 1
    fi
fi


if [[ "$OSVERSION" == "ubuntu-22.04" ]]; then
    fix_dependecy_for_config_fpga
    bpf_dependencies
    clone_repos
    install_perf
fi

if [ "$3" == "dpdk"]; then
    echo "Installing dpdk on this machine"
    install_dpdk
    cp -r /proj/octfpga-PG0/tools/deployment/opennic/ /users/markmole/
    set_grub_for_dpdk
fi

# Disable PCIe fatal error reporting
disable_pcie_fatal_error 
install_config_fpga
install_xbflash
install_cpufreq
