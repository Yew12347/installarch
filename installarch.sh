#!/bin/bash
set -euo pipefail

echo "=== Arch Linux Automated Installer ==="

# Helper function for yes/no
confirm() {
    while true; do
        read -rp "$1 (y/n): " yn
        case $yn in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
        esac
    done
}

# Select target root partition (assumes partition exists)
echo "Available disks:"
lsblk -dpno NAME,SIZE,TYPE | grep disk
read -rp "Enter root partition device (e.g. /dev/sda2): " ROOT_PART

read -rp "Is your system UEFI? (y/n): " IS_UEFI
if [[ $IS_UEFI =~ ^[Yy] ]]; then
    read -rp "Enter EFI partition device (e.g. /dev/sda1): " EFI_PART
fi

# Mount partitions
echo "Mounting root partition $ROOT_PART to /mnt"
mount "$ROOT_PART" /mnt

if [[ $IS_UEFI =~ ^[Yy] ]]; then
    echo "Mounting EFI partition $EFI_PART to /mnt/boot"
    mkdir -p /mnt/boot
    mount "$EFI_PART" /mnt/boot
fi

# Install base system
echo "Installing base system..."
pacstrap /mnt base base-devel linux linux-headers linux-lts linux-lts-headers linux-firmware sudo nano networkmanager os-prober

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Setup chroot script
cat > /mnt/root/setup.sh <<'EOF'
#!/bin/bash
set -euo pipefail

echo "=== Inside chroot setup ==="

# Set root password
echo "Set root password:"
passwd

# Add user
read -rp "Enter username for new user: " username
useradd -m -G wheel "$username"
echo "Set password for $username:"
passwd "$username"

# Enable wheel group for sudo
sed -i '/^# %wheel ALL=(ALL) ALL/s/^# //' /etc/sudoers

# Locale setup
echo "Available locales: en_US.UTF-8, en_GB.UTF-8, de_DE.UTF-8, etc."
read -rp "Enter locale to enable (e.g. en_US.UTF-8): " locale
sed -i "/^#$locale/s/^#//" /etc/locale.gen
locale-gen
echo "LANG=$locale" > /etc/locale.conf

# Timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

# Hostname
read -rp "Enter hostname: " hostname
echo "$hostname" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $hostname.localdomain $hostname" >> /etc/hosts

# Install desktop environment
echo "Select Desktop Environment:"
echo "1) GNOME"
echo "2) KDE Plasma"
echo "3) None (server)"
read -rp "Choose (1-3): " de_choice

case $de_choice in
    1)
        pacman -S --noconfirm gnome gnome-tweaks gnome-extra
        systemctl enable gdm
        ;;
    2)
        pacman -S --noconfirm plasma plasma-wayland-session sddm
        systemctl enable sddm
        ;;
    3)
        echo "No DE selected"
        ;;
    *)
        echo "Invalid choice, skipping DE"
        ;;
esac

# Optionally install your preferred lock screen if mixing KDE + GNOME lock screen
# (This is a bit tricky and usually not done, but you can install gnome-screensaver or other)

# Graphics drivers
echo "Select GPU type:"
echo "1) Intel"
echo "2) AMD"
echo "3) Nvidia"
read -rp "Choose (1-3): " gpu_choice

case $gpu_choice in
    1)
        pacman -S --noconfirm mesa intel-media-driver
        ;;
    2)
        pacman -S --noconfirm mesa libva-mesa-driver
        ;;
    3)
        pacman -S --noconfirm nvidia nvidia-utils nvidia-lts
        ;;
    *)
        echo "Unknown GPU choice, skipping GPU drivers"
        ;;
esac

# Initramfs
mkinitcpio -P

# Bootloader install
echo "Install and configure GRUB? (y/n)"
read -r install_grub
if [[ $install_grub =~ ^[Yy] ]]; then
    pacman -S --noconfirm grub efibootmgr
    if [[ -d /sys/firmware/efi ]]; then
        grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    else
        grub-install --target=i386-pc /dev/sda
    fi
    grub-mkconfig -o /boot/grub/grub.cfg
fi

echo "Enable NetworkManager"
systemctl enable NetworkManager

echo "Setup complete inside chroot."
EOF

chmod +x /mnt/root/setup.sh

echo "Chrooting into /mnt to finish installation..."
arch-chroot /mnt /root/setup.sh

echo "Cleaning up..."
rm /mnt/root/setup.sh

echo "Unmounting partitions..."
umount -R /mnt

echo "Installation finished."
if confirm "Reboot now?"; then
    reboot
else
    echo "You can reboot later."
fi
