#!/bin/bash
set -euo pipefail

echo "=== Arch Linux Installer ==="

# Function to check if device exists and is a partition
device_exists() {
    lsblk -no NAME | grep -w "$(basename "$1")" &>/dev/null
}

# Ask for root partition, loop until valid
while true; do
    echo "Available partitions:"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep part
    read -rp "Enter root partition device (e.g. /dev/sda2): " ROOT_PART
    if [[ -b "$ROOT_PART" ]] && device_exists "$ROOT_PART"; then
        echo "Using root partition: $ROOT_PART"
        break
    else
        echo "Invalid partition device, try again."
    fi
done

# Ask if UEFI system
while true; do
    read -rp "Is this a UEFI system? (y/n): " IS_UEFI
    case $IS_UEFI in
        [Yy]* )
            while true; do
                echo "Available EFI partitions (usually type 'part' and size ~100-500M):"
                lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT | grep part
                read -rp "Enter EFI partition device (e.g. /dev/sda1): " EFI_PART
                if [[ -b "$EFI_PART" ]] && device_exists "$EFI_PART"; then
                    echo "Using EFI partition: $EFI_PART"
                    break
                else
                    echo "Invalid EFI partition device, try again."
                fi
            done
            break
            ;;
        [Nn]* )
            EFI_PART=""
            break
            ;;
        *)
            echo "Please answer y or n."
            ;;
    esac
done

# Format confirmation (do not auto format, ask user first!)
if confirm "Do you want to format the root partition $ROOT_PART as ext4? WARNING: This will erase all data on it"; then
    mkfs.ext4 "$ROOT_PART"
fi

if [[ -n "$EFI_PART" ]]; then
    if confirm "Do you want to format the EFI partition $EFI_PART as FAT32? WARNING: This will erase all data on it"; then
        mkfs.fat -F32 "$EFI_PART"
    fi
fi

# Mount partitions
echo "Mounting $ROOT_PART to /mnt"
mount "$ROOT_PART" /mnt || { echo "Failed to mount root partition"; exit 1; }

if [[ -n "$EFI_PART" ]]; then
    echo "Mounting EFI partition $EFI_PART to /mnt/boot"
    mkdir -p /mnt/boot
    mount "$EFI_PART" /mnt/boot || { echo "Failed to mount EFI partition"; exit 1; }
fi

# Install base system with auto yes (-y) and no confirm prompts
echo "Installing base system (base, base-devel, linux, linux-headers, linux-lts, linux-lts-headers, firmware, sudo, networkmanager, nano, os-prober)..."
pacstrap -K /mnt base base-devel linux linux-headers linux-lts linux-lts-headers linux-firmware sudo networkmanager nano os-prober --noconfirm

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt > /mnt/etc/fstab

# Copy chroot setup script
cat > /mnt/root/setup.sh <<'EOF'
#!/bin/bash
set -euo pipefail

echo "Inside chroot setup"

# Set root password
echo "Set root password:"
passwd

# Create user
while true; do
    read -rp "Enter username to create: " username
    if [[ -n "$username" ]]; then
        break
    else
        echo "Username cannot be empty."
    fi
done

useradd -m -G wheel "$username"
echo "Set password for user $username:"
passwd "$username"

# Enable wheel sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Locale setup
echo "Available locales:"
grep -E '^[^#].*UTF-8' /etc/locale.gen
while true; do
    read -rp "Enter locale to enable (e.g. en_US.UTF-8): " locale
    if grep -q "^#$locale" /etc/locale.gen; then
        sed -i "s/^#$locale/$locale/" /etc/locale.gen
        locale-gen
        echo "LANG=$locale" > /etc/locale.conf
        break
    else
        echo "Locale not found or already enabled. Check spelling."
    fi
done

# Timezone setup (default UTC)
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

# Hostname setup
while true; do
    read -rp "Enter hostname for this system: " hostname
    if [[ -n "$hostname" ]]; then
        echo "$hostname" > /etc/hostname
        echo "127.0.0.1 localhost" >> /etc/hosts
        echo "::1 localhost" >> /etc/hosts
        echo "127.0.1.1 $hostname.localdomain $hostname" >> /etc/hosts
        break
    else
        echo "Hostname cannot be empty."
    fi
done

# Desktop Environment selection
echo "Select Desktop Environment:"
echo "1) GNOME"
echo "2) KDE Plasma"
echo "3) None"
while true; do
    read -rp "Choice (1-3): " de_choice
    case $de_choice in
        1)
            pacman -S --noconfirm gnome gnome-tweaks gnome-extra
            systemctl enable gdm
            break
            ;;
        2)
            pacman -S --noconfirm plasma plasma-wayland-session sddm
            systemctl enable sddm
            break
            ;;
        3)
            echo "No desktop environment selected."
            break
            ;;
        *)
            echo "Invalid choice."
            ;;
    esac
done

# GPU driver selection
echo "Select GPU driver to install:"
echo "1) Intel"
echo "2) AMD"
echo "3) Nvidia"
while true; do
    read -rp "Choice (1-3): " gpu_choice
    case $gpu_choice in
        1)
            pacman -S --noconfirm mesa intel-media-driver
            break
            ;;
        2)
            pacman -S --noconfirm mesa libva-mesa-driver
            break
            ;;
        3)
            pacman -S --noconfirm nvidia nvidia-utils nvidia-lts
            break
            ;;
        *)
            echo "Invalid choice."
            ;;
    esac
done

# Regenerate initramfs
mkinitcpio -P

# Bootloader installation
echo "Install GRUB bootloader? (y/n)"
read -r grub_install
if [[ "$grub_install" =~ ^[Yy] ]]; then
    pacman -S --noconfirm grub efibootmgr
    if [[ -d /sys/firmware/efi ]]; then
        grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    else
        grub-install --target=i386-pc /dev/sda
    fi
    grub-mkconfig -o /boot/grub/grub.cfg
fi

# Enable NetworkManager
systemctl enable NetworkManager

echo "Chroot setup complete."
EOF

chmod +x /mnt/root/setup.sh

echo "Entering chroot to finalize installation..."
arch-chroot /mnt /root/setup.sh

echo "Cleaning up..."
rm /mnt/root/setup.sh

echo "Unmounting all partitions..."
umount -R /mnt

read -rp "Installation complete. Reboot now? (y/n): " reboot_choice
if [[ "$reboot_choice" =~ ^[Yy] ]]; then
    reboot
else
    echo "Reboot manually to start your new Arch system."
fi
