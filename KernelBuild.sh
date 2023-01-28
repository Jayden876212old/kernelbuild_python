version=$(pacman -Ss linux | grep -oP '(?<=core/linux ).*(?=.arch)')

echo "Building kernel version: $version"

rm -rf $HOME/kernelbuild # Delete the previous directory where the built kernel lies
mkdir $HOME/kernelbuild # Create a new empty build directory
cd $HOME/kernelbuild # Change your working directory to the new build directory

#wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.19.7.tar.xz
wget "https://cdn.kernel.org/pub/linux/kernel/v${version:0:1}.x/linux-$version.tar.xz" # Grab the linux kernel from kernel.org using wget
wget "https://cdn.kernel.org/pub/linux/kernel/v${version:0:1}.x/linux-$version.tar.sign" # Grab the signature for the signing process

# Check that the source is legitimate and the code hasn't been tampered with
key=$(gpg --list-packets linux-$version.tar.sign | grep -oP '(?<=keyid ).*?(3E)')
gpg --recv-keys $key
unxz linux-$version.tar.xz
if gpg --verify linux-$version.tar.sign linux-$version.tar 2>&1 | grep -q 'Good signature from'; then

	echo "Good signature!"
	
	# Prepare kernel source code
	tar -xvf linux-$version.tar
	chown -R tdljayden:tdljayden linux-$version
	cd linux-$version
	
	# Start compilation and makeconfig
	threads=12
	make -j$threads mrproper
	zcat /proc/config.gz > .config
	modprobed-db store
	make nconfig
	make -j$threads LSMOD=$HOME/.config/modprobed.db localmodconfig
	# Compile with the binderfs modules for waydroid support to run android apps
	scripts/config --enable  CONFIG_ANDROID
	scripts/config --enable  CONFIG_NET
	scripts/config --enable  CONFIG_BRIDGE
	scripts/config --enable  CONFIG_NETLINK_DIAG
	scripts/config --enable  CONFIG_NFT_COMPAT
	scripts/config --enable  CONFIG_NF_TABLES
	scripts/config --enable  CONFIG_NF_TABLES_INET
	scripts/config --enable  CONFIG_NF_TABLES_NETDEV
	scripts/config --enable  CONFIG_NFT_NUMGEN
	scripts/config --enable  CONFIG_NFT_CT
	scripts/config --enable  CONFIG_ANDROID_BINDER_IPC
	scripts/config --enable  CONFIG_ANDROID_BINDERFS
	scripts/config --set-str CONFIG_ANDROID_BINDER_DEVICES ""
	# Compile the kernel with exfat modules
	git clone https://github.com/arter97/exfat-linux.git
	mv exfat-linux fs/exfat
	# Optimise GCC for the CPU's instructions
	# Build kernel and its modules
	make -j$threads
	make -j$threads modules
	sudo make -j$threads modules_install
	
	# Prepare kernel for boot
	make -j$threads bzImage
	sudo cp -v arch/x86/boot/bzImage /boot/vmlinuz-linux-tdljaydencustom
	sudo mkinitcpio --config /etc/mkinitcpio.conf -k $version -g /boot/initramfs-linux-tdljaydencustom.img
	
	# Prepare kernel for use with secure boot via signing
	sudo sbsign --key $HOME/MOK.key --cert $HOME/MOK.crt --output /boot/vmlinuz-linux-tdljaydencustom /boot/vmlinuz-linux-tdljaydencustom
	sudo sbsign --key $HOME/MOK.key --cert $HOME/MOK.crt --output /boot/EFI/systemd/grubx64.efi /boot/EFI/systemd/grubx64.efi
	sudo sbsign --key $HOME/MOK.key --cert $HOME/MOK.crt --output /boot/EFI/systemd/fbx64.efi /boot/EFI/systemd/fbx64.efi
	sudo sbsign --key $HOME/MOK.key --cert $HOME/MOK.crt --output /boot/EFI/systemd/mmx64.efi /boot/EFI/systemd/mmx64.efi
fi
