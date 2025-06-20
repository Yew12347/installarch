#!/bin/bash
set -euo pipefail

echo "Welcome to Custom Arch Installer!"

# Helper function for yes/no prompt
yesno() {
  while true; do
    read -rp "$1 (y/n): " yn
    case $yn in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

# 1. Select target drive (show disks)
echo "Available block devices:"
lsblk -d -o NAME,SIZE,MODEL | grep -v loop

while true; do
  read -rp "Enter your target drive (e.g. sda): /dev/" DRIVE
  if [[ -b "/dev/$DRIVE" ]]; then
    echo "Selected drive: /dev/$DRIVE"
    break
  else
    echo "Invalid drive, please try again."
  fi
done

# 2. Ask if partition already exists or create partition
if yesno "Do you want to format and use an existing partition?"; then
  lsblk "/dev/$DRIVE"
  while true; do
    read -rp "Enter partition to install on (e.g. sda3): /dev/" PARTITION
    if [[ -b "/dev/$PARTITION" ]]; then
      echo "Selected partition: /dev/$PARTITION"
      break
    else
      echo "Invalid partition, try again."
    fi
  done
  echo "Formatting /dev/$PARTITION as ext4..."
  mkfs.ext4 "/dev/$PARTITION"
else
  echo "Partitioning is not automated by this script. Please partition manually and rerun."
  exit 1
fi

# 3. Mount partitions
mount "/dev/$PARTITION" /mnt

# 4. EFI partition mounting (optional)
if yesno "Do you have an EFI partition to mount?"; then
  lsblk "/dev/$DRIVE"
  while true; do
    read -rp "Enter EFI partition (e.g. sda1): /dev/" EFIPART
    if [[ -b "/dev/$EFIPART" ]]; then
      mkdir -p /mnt/boot/efi
      mount "/dev/$EFIPART" /mnt/boot/efi
      echo "Mounted EFI partition /dev/$EFIPART to /mnt/boot/efi"
      break
    else
      echo "Invalid EFI partition, try again."
    fi
  done
fi

# 5. Install base system
echo "Installing base packages (base, linux, linux-headers, linux-lts, linux-lts-headers, linux-firmware)..."
pacstrap -i /mnt base linux linux-headers linux-lts linux-lts-headers linux-firmware --noconfirm

# 6. Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# 7. Chroot setup
arch-chroot /mnt /bin/bash <<EOF

echo "Setting root password"
echo "root:root" | chpasswd  # Replace 'root' with desired password or prompt

echo "Creating user"
useradd -m -G wheel username  # Replace username or prompt
echo "username:password" | chpasswd  # Replace password or prompt

echo "Allowing wheel group sudo access"
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "Installing necessary packages"
pacman -Syu --noconfirm base-devel dosfstools grub efibootmgr mtools nano networkmanager openssh os-prober sudo

EOF

# 8. Select desktop environment
echo "Select desktop environment:"
PS3="Choose your desktop manager: "
options=("GNOME" "KDE Plasma" "None")
select opt in "${options[@]}"; do
  case $opt in
    "GNOME")
      DESKTOP="gnome gnome-tweaks"
      ;;
    "KDE Plasma")
      DESKTOP="plasma kde-applications"
      ;;
    "None")
      DESKTOP=""
      ;;
    *)
      echo "Invalid option."
      continue
      ;;
  esac
  break
done

# 9. Install desktop environment inside chroot
if [[ -n "$DESKTOP" ]]; then
  arch-chroot /mnt pacman -Syu --noconfirm $DESKTOP
fi

# 10. GPU driver selection
echo "Select GPU vendor for driver installation:"
PS3="Choose GPU driver: "
drivers=("Intel" "NVIDIA" "AMD" "None")
select drv in "${drivers[@]}"; do
  case $drv in
    "Intel")
      arch-chroot /mnt pacman -Syu --noconfirm mesa intel-media-driver
      ;;
    "NVIDIA")
      arch-chroot /mnt pacman -Syu --noconfirm nvidia nvidia-utils nvidia-lts
      ;;
    "AMD")
      arch-chroot /mnt pacman -Syu --noconfirm mesa libva-mesa-driver
      ;;
    "None")
      echo "Skipping GPU driver installation."
      ;;
    *)
      echo "Invalid option."
      continue
      ;;
  esac
  break
done

# 11. Kernel hooks
arch-chroot /mnt mkinitcpio -p linux
arch-chroot /mnt mkinitcpio -p linux-lts

# 12. Locale selection
echo "Locale selection"
echo "Available locales example: en_US.UTF-8 UTF-8, en_GB.UTF-8 UTF-8, etc."
read -rp "Enter locale (e.g. en_US.UTF-8): " USER_LOCALE

arch-chroot /mnt /bin/bash <<EOF
sed -i "s/^#${USER_LOCALE}/${USER_LOCALE}/" /etc/locale.gen
locale-gen
echo "LANG=${USER_LOCALE}" > /etc/locale.conf
EOF

# 13. Bootloader installation option
if yesno "Do you want to install GRUB bootloader?"; then
  arch-chroot /mnt /bin/bash <<EOF
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
EOF
else
  echo "Skipping bootloader installation."
fi

# 14. Enable NetworkManager service
arch-chroot /mnt systemctl enable NetworkManager

# 15. Finish installation
echo "Installation done. You can now exit chroot and unmount partitions."

if yesno "Unmount partitions now?"; then
  umount -R /mnt
fi

if yesno "Reboot now?"; then
  reboot
else
  echo "You can reboot later."
fi
