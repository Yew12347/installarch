#!/bin/bash
set -euo pipefail

echo "== Starting Arch Linux Installation =="

# Format partitions
echo "Formatting root partition /dev/vda4 as ext4"
mkfs.ext4 /dev/vda4



# Mount partitions
echo "Mounting root partition /dev/vda4 to /mnt"
mount /dev/vda4 /mnt


echo "Installing base system and packages"
pacstrap /mnt base base-devel linux linux-headers linux-lts linux-lts-headers linux-firmware sudo networkmanager nano os-prober mtools dosfstools efibootmgr sudo openssh

echo "Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

# Prepare chroot setup script
cat > /mnt/root/setup.sh <<'EOF'
#!/bin/bash
set -euo pipefail

echo "== Inside chroot setup =="


echo "Set root password:"
passwd

echo "Set password for user 'yewgamer':"
passwd "yewgamer"
    

useradd -m -g users -G wheel yewgamer

echo "Enabling wheel group sudo privileges"
sed -i '/^# %wheel ALL=(ALL) ALL/s/^# //' /etc/sudoers

echo "Setting locale"
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "Setting timezone to UTC"
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

echo "Setting hostname to archlinux"
echo "archlinux" > /etc/hostname
cat >> /etc/hosts <<HOSTS
127.0.0.1 localhost
::1       localhost
127.0.1.1 archlinux.localdomain archlinux
HOSTS

echo "Installing additional packages"
pacman -S --noconfirm base-devel dosfstools grub efibootmgr plasma plasma-wayland-session sddm gnome-tweaks nano networkmanager os-prober mesa libva-mesa-driver

systemctl enable sddm

echo "Regenerating initramfs"
mkinitcpio -p linux
mkinitcpio -p linux-lts

echo "Enable NetworkManager"
systemctl enable NetworkManager

echo "Installing bootloader"

pacman -S --noconfirm grub efibootmgr
if [[ -d /sys/firmware/efi ]]; then
  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
else
  grub-install --target=i386-pc /dev/sda
fi
grub-mkconfig -o /boot/grub/grub.cfg
    

echo "Setup complete."
EOF

echo "Entering chroot to finish installation"
arch-chroot /mnt /root/setup.sh

echo "Cleaning up"
rm /mnt/root/setup.sh

echo "Unmounting partitions"
umount -R /mnt

read -rp "Installation complete. Reboot now? (y/n): " reboot_now
if [[ $reboot_now =~ ^[Yy] ]]; then
  reboot
else
  echo "Please reboot manually later."
fi
