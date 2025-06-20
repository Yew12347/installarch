use crate::app::{AppState, DesktopEnv, GpuDriver, KernelSelection, Page};
use crossterm::event::{self, Event, KeyCode};
use ratatui::{
    backend::Backend,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Span, Line},
    widgets::{Block, Borders, List, ListItem, ListState, Paragraph},
    Frame, Terminal,
};
use std::io;

fn render_text_input(f: &mut Frame, area: Rect, title: &str, value: &str, selected: bool) {
    let block = Block::default()
        .borders(Borders::ALL)
        .title(Span::styled(title, Style::default().fg(Color::Yellow)));
    let para = Paragraph::new(value.to_string()).block(block);
    f.render_widget(para, area);
    if selected {
        f.set_cursor(area.x + value.len() as u16 + 1, area.y + 1);
    }
}

fn render_selection_list(f: &mut Frame, area: Rect, title: &str, items: &[&str], selected_index: usize) {
    let list_items: Vec<ListItem> = items.iter().map(|i| ListItem::new(*i)).collect();
    let mut state = ListState::default();
    state.select(Some(selected_index));
    let list = List::new(list_items)
        .block(Block::default().title(title).borders(Borders::ALL))
        .highlight_style(Style::default().fg(Color::LightGreen).add_modifier(Modifier::BOLD))
        .highlight_symbol(">> ");
    f.render_stateful_widget(list, area, &mut state);
}

pub fn run_app<B: Backend>(terminal: &mut Terminal<B>, app: &mut AppState) -> io::Result<()> {
    let mut input = String::new();
    let mut select_idx = 0;

    loop {
        terminal.draw(|f| {
            let size = f.size();
            let chunks = Layout::default()
                .direction(Direction::Vertical)
                .margin(2)
                .constraints([Constraint::Length(3), Constraint::Min(5), Constraint::Length(3)].as_ref())
                .split(size);

            let title = format!("Arch Linux Installer - Step: {:?}", app.page);
            let title_block = Block::default().title(title).borders(Borders::ALL);
            f.render_widget(title_block, size);

            match app.page {
                Page::Welcome => {
                    let text = vec![
                        Line::from("Welcome to the Arch Linux Installer TUI!"),
                        Line::from("Press Enter to start."),
                    ];
                    let para = Paragraph::new(text).block(Block::default().borders(Borders::ALL).title("Welcome"));
                    f.render_widget(para, chunks[1]);
                }
                Page::GrubInstall => {
                    let options = ["Yes", "No"];
                    render_selection_list(f, chunks[1], "Install GRUB bootloader?", &options, select_idx);
                }
                Page::EfiPartition => {
                    let val = app.efi_partition.as_deref().unwrap_or("");
                    render_text_input(f, chunks[1], "EFI Partition (e.g. /dev/sda1)", val, true);
                }
                Page::RootPartition => {
                    let val = app.root_partition.as_deref().unwrap_or("");
                    render_text_input(f, chunks[1], "Root Partition (e.g. /dev/sda2)", val, true);
                }
                Page::RootFormat => {
                    let options = ["Yes", "No"];
                    render_selection_list(f, chunks[1], "Format root partition?", &options, select_idx);
                }
                Page::Filesystem => {
                    let options = ["ext4", "btrfs", "xfs"];
                    let current_fs = app.filesystem.as_deref().unwrap_or("ext4");
                    let idx = options.iter().position(|&x| x == current_fs).unwrap_or(0);
                    render_selection_list(f, chunks[1], "Filesystem type", &options, idx);
                }
                Page::Locale => {
                    let val = app.locale.as_deref().unwrap_or("");
                    render_text_input(f, chunks[1], "Locale (e.g. en_US.UTF-8)", val, true);
                }
                Page::Hostname => {
                    let val = app.hostname.as_deref().unwrap_or("");
                    render_text_input(f, chunks[1], "Hostname", val, true);
                }
                Page::Username => {
                    let val = app.username.as_deref().unwrap_or("");
                    render_text_input(f, chunks[1], "Username", val, true);
                }
                Page::UserPassword => {
                    let text = vec![Line::from("Press Enter to enter your user password.")];
                    let para = Paragraph::new(text).block(Block::default().borders(Borders::ALL).title("User Password"));
                    f.render_widget(para, chunks[1]);
                }
                Page::RootPassword => {
                    let text = vec![Line::from("Press Enter to enter the root password.")];
                    let para = Paragraph::new(text).block(Block::default().borders(Borders::ALL).title("Root Password"));
                    f.render_widget(para, chunks[1]);
                }
                Page::Kernel => {
                    let options = ["linux", "linux-lts", "both"];
                    let idx = match app.kernel.unwrap_or(KernelSelection::Both) {
                        KernelSelection::Linux => 0,
                        KernelSelection::LinuxLTS => 1,
                        KernelSelection::Both => 2,
                    };
                    render_selection_list(f, chunks[1], "Kernel to install", &options, idx);
                }
                Page::GpuDriver => {
                    let options = ["Intel", "AMD", "NVIDIA", "None"];
                    let idx = match app.gpu_driver.unwrap_or(GpuDriver::None) {
                        GpuDriver::Intel => 0,
                        GpuDriver::AMD => 1,
                        GpuDriver::Nvidia => 2,
                        GpuDriver::None => 3,
                    };
                    render_selection_list(f, chunks[1], "GPU Driver", &options, idx);
                }
                Page::DesktopEnv => {
                    let options = ["None", "KDE Plasma", "GNOME", "GNOME lock screen + KDE"];
                    let idx = match app.desktop_env.unwrap_or(DesktopEnv::None) {
                        DesktopEnv::None => 0,
                        DesktopEnv::KDE => 1,
                        DesktopEnv::GNOME => 2,
                        DesktopEnv::GnomeLockKDE => 3,
                    };
                    render_selection_list(f, chunks[1], "Desktop Environment", &options, idx);
                }
                Page::Summary => {
                    let mut lines = Vec::new();
                    lines.push(Line::from(format!("Install GRUB: {:?}", app.install_grub)));
                    lines.push(Line::from(format!("EFI Partition: {:?}", app.efi_partition)));
                    lines.push(Line::from(format!("Root Partition: {:?}", app.root_partition)));
                    lines.push(Line::from(format!("Format root: {:?}", app.format_root)));
                    lines.push(Line::from(format!("Filesystem: {:?}", app.filesystem)));
                    lines.push(Line::from(format!("Locale: {:?}", app.locale)));
                    lines.push(Line::from(format!("Hostname: {:?}", app.hostname)));
                    lines.push(Line::from(format!("Username: {:?}", app.username)));
                    lines.push(Line::from(format!("Kernel: {:?}", app.kernel)));
                    lines.push(Line::from(format!("GPU Driver: {:?}", app.gpu_driver)));
                    lines.push(Line::from(format!("Desktop Environment: {:?}", app.desktop_env)));
                    lines.push(Line::from("Press Enter to confirm and start installation."));
                    let para = Paragraph::new(lines).block(Block::default().borders(Borders::ALL).title("Summary"));
                    f.render_widget(para, chunks[1]);
                }
                Page::Finished => {
                    let text = vec![Line::from("Installation finished! Please reboot your system.")];
                    let para = Paragraph::new(text).block(Block::default().borders(Borders::ALL).title("Finished"));
                    f.render_widget(para, chunks[1]);
                }
            }
        })?;

        if event::poll(std::time::Duration::from_millis(200))? {
            match event::read()? {
                Event::Key(key) => {
                    match app.page {
                        Page::Welcome => {
                            if key.code == KeyCode::Enter {
                                app.next_page();
                                select_idx = 0;
                            }
                        }
                        Page::GrubInstall | Page::RootFormat => {
                            let options_len = 2;
                            match key.code {
                                KeyCode::Up => {
                                    select_idx = (select_idx + options_len - 1) % options_len;
                                }
                                KeyCode::Down => {
                                    select_idx = (select_idx + 1) % options_len;
                                }
                                KeyCode::Enter => {
                                    let val = select_idx == 0;
                                    match app.page {
                                        Page::GrubInstall => app.install_grub = Some(val),
                                        Page::RootFormat => app.format_root = Some(val),
                                        _ => {}
                                    }
                                    select_idx = 0;
                                    app.next_page();
                                }
                                KeyCode::Esc | KeyCode::Backspace => {
                                    app.prev_page();
                                    select_idx = 0;
                                }
                                _ => {}
                            }
                        }
                        Page::Filesystem => {
                            let options = ["ext4", "btrfs", "xfs"];
                            let options_len = options.len();
                            match key.code {
                                KeyCode::Up => select_idx = (select_idx + options_len - 1) % options_len,
                                KeyCode::Down => select_idx = (select_idx + 1) % options_len,
                                KeyCode::Enter => {
                                    app.filesystem = Some(options[select_idx].to_string());
                                    select_idx = 0;
                                    app.next_page();
                                }
                                KeyCode::Esc | KeyCode::Backspace => {
                                    app.prev_page();
                                    select_idx = 0;
                                }
                                _ => {}
                            }
                        }
                        Page::Kernel => {
                            let options = ["linux", "linux-lts", "both"];
                            let options_len = options.len();
                            match key.code {
                                KeyCode::Up => select_idx = (select_idx + options_len - 1) % options_len,
                                KeyCode::Down => select_idx = (select_idx + 1) % options_len,
                                KeyCode::Enter => {
                                    app.kernel = match select_idx {
                                        0 => Some(KernelSelection::Linux),
                                        1 => Some(KernelSelection::LinuxLTS),
                                        2 => Some(KernelSelection::Both),
                                        _ => None,
                                    };
                                    select_idx = 0;
                                    app.next_page();
                                }
                                KeyCode::Esc | KeyCode::Backspace => {
                                    app.prev_page();
                                    select_idx = 0;
                                }
                                _ => {}
                            }
                        }
                        Page::GpuDriver => {
                            let options = ["Intel", "AMD", "NVIDIA", "None"];
                            let options_len = options.len();
                            match key.code {
                                KeyCode::Up => select_idx = (select_idx + options_len - 1) % options_len,
                                KeyCode::Down => select_idx = (select_idx + 1) % options_len,
                                KeyCode::Enter => {
                                    app.gpu_driver = match select_idx {
                                        0 => Some(GpuDriver::Intel),
                                        1 => Some(GpuDriver::AMD),
                                        2 => Some(GpuDriver::Nvidia),
                                        3 => Some(GpuDriver::None),
                                        _ => None,
                                    };
                                    select_idx = 0;
                                    app.next_page();
                                }
                                KeyCode::Esc | KeyCode::Backspace => {
                                    app.prev_page();
                                    select_idx = 0;
                                }
                                _ => {}
                            }
                        }
                        Page::DesktopEnv => {
                            let options = ["None", "KDE Plasma", "GNOME", "GNOME lock screen + KDE"];
                            let options_len = options.len();
                            match key.code {
                                KeyCode::Up => select_idx = (select_idx + options_len - 1) % options_len,
                                KeyCode::Down => select_idx = (select_idx + 1) % options_len,
                                KeyCode::Enter => {
                                    app.desktop_env = match select_idx {
                                        0 => Some(DesktopEnv::None),
                                        1 => Some(DesktopEnv::KDE),
                                        2 => Some(DesktopEnv::GNOME),
                                        3 => Some(DesktopEnv::GnomeLockKDE),
                                        _ => None,
                                    };
                                    select_idx = 0;
                                    app.next_page();
                                }
                                KeyCode::Esc | KeyCode::Backspace => {
                                    app.prev_page();
                                    select_idx = 0;
                                }
                                _ => {}
                            }
                        }
                        Page::EfiPartition | Page::RootPartition | Page::Locale | Page::Hostname | Page::Username => {
                            match key.code {
                                KeyCode::Char(c) => {
                                    input.push(c);
                                }
                                KeyCode::Backspace => {
                                    input.pop();
                                }
                                KeyCode::Enter => {
                                    match app.page {
                                        Page::EfiPartition => app.efi_partition = Some(input.trim().to_string()),
                                        Page::RootPartition => app.root_partition = Some(input.trim().to_string()),
                                        Page::Locale => app.locale = Some(input.trim().to_string()),
                                        Page::Hostname => app.hostname = Some(input.trim().to_string()),
                                        Page::Username => app.username = Some(input.trim().to_string()),
                                        _ => {}
                                    }
                                    input.clear();
                                    app.next_page();
                                    select_idx = 0;
                                }
                                KeyCode::Esc | KeyCode::Backspace if input.is_empty() => {
                                    app.prev_page();
                                    select_idx = 0;
                                }
                                _ => {}
                            }
                        }
                        Page::UserPassword => {
                            if key.code == KeyCode::Enter {
                                app.prompt_password("User Password");
                                app.next_page();
                                select_idx = 0;
                            } else if key.code == KeyCode::Esc {
                                app.prev_page();
                                select_idx = 0;
                            }
                        }
                        Page::RootPassword => {
                            if key.code == KeyCode::Enter {
                                app.prompt_password("Root Password");
                                app.next_page();
                                select_idx = 0;
                            } else if key.code == KeyCode::Esc {
                                app.prev_page();
                                select_idx = 0;
                            }
                        }
                        Page::Summary => {
                            if key.code == KeyCode::Enter {
                                app.next_page();
                                select_idx = 0;
                            } else if key.code == KeyCode::Esc {
                                app.prev_page();
                                select_idx = 0;
                            }
                        }
                        Page::Finished => {
                            if key.code == KeyCode::Esc || key.code == KeyCode::Char('q') {
                                break;
                            }
                        }
                    }
                }
                _ => {}
            }
        }
    }
    Ok(())
}