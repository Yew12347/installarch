use dialoguer::Password;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum KernelSelection {
    Linux,
    LinuxLTS,
    Both,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GpuDriver {
    Intel,
    AMD,
    Nvidia,
    None,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DesktopEnv {
    None,
    KDE,
    GNOME,
    GnomeLockKDE,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Page {
    Welcome,
    GrubInstall,
    EfiPartition,
    RootPartition,
    RootFormat,
    Filesystem,
    Locale,
    Hostname,
    Username,
    UserPassword,
    RootPassword,
    Kernel,
    GpuDriver,
    DesktopEnv,
    Summary,
    Finished,
}

pub struct AppState {
    pub page: Page,

    // Installer options:
    pub install_grub: Option<bool>,
    pub efi_partition: Option<String>,
    pub root_partition: Option<String>,
    pub format_root: Option<bool>,
    pub filesystem: Option<String>,
    pub locale: Option<String>,
    pub hostname: Option<String>,
    pub username: Option<String>,
    pub user_password: Option<String>,
    pub root_password: Option<String>,
    pub kernel: Option<KernelSelection>,
    pub gpu_driver: Option<GpuDriver>,
    pub desktop_env: Option<DesktopEnv>,
}

impl Default for AppState {
    fn default() -> Self {
        Self {
            page: Page::Welcome,
            install_grub: None,
            efi_partition: None,
            root_partition: None,
            format_root: None,
            filesystem: Some("ext4".to_string()),
            locale: Some("en_US.UTF-8".to_string()),
            hostname: Some("archlinux".to_string()),
            username: Some("user".to_string()),
            user_password: None,
            root_password: None,
            kernel: Some(KernelSelection::Both),
            gpu_driver: Some(GpuDriver::None),
            desktop_env: Some(DesktopEnv::None),
        }
    }
}

impl AppState {
    pub fn next_page(&mut self) {
        use Page::*;
        self.page = match self.page {
            Welcome => GrubInstall,
            GrubInstall => EfiPartition,
            EfiPartition => RootPartition,
            RootPartition => RootFormat,
            RootFormat => Filesystem,
            Filesystem => Locale,
            Locale => Hostname,
            Hostname => Username,
            Username => UserPassword,
            UserPassword => RootPassword,
            RootPassword => Kernel,
            Kernel => GpuDriver,
            GpuDriver => DesktopEnv,
            DesktopEnv => Summary,
            Summary => Finished,
            Finished => Finished,
        }
    }

    pub fn prev_page(&mut self) {
        use Page::*;
        self.page = match self.page {
            Welcome => Welcome,
            GrubInstall => Welcome,
            EfiPartition => GrubInstall,
            RootPartition => EfiPartition,
            RootFormat => RootPartition,
            Filesystem => RootFormat,
            Locale => Filesystem,
            Hostname => Locale,
            Username => Hostname,
            UserPassword => Username,
            RootPassword => UserPassword,
            Kernel => RootPassword,
            GpuDriver => Kernel,
            DesktopEnv => GpuDriver,
            Summary => DesktopEnv,
            Finished => Summary,
        }
    }

    pub fn prompt_password(&mut self, prompt: &str) {
        let pw = Password::new().with_prompt(prompt).interact().unwrap_or_default();
        if prompt.to_lowercase().contains("root") {
            self.root_password = Some(pw);
        } else {
            self.user_password = Some(pw);
        }
    }
}