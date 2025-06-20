mod app;
mod ui;

use crossterm::terminal::{enable_raw_mode, disable_raw_mode};
use ratatui::backend::CrosstermBackend;
use ratatui::Terminal;
use std::io::stdout;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    enable_raw_mode()?;
    let stdout = stdout();
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let mut app = app::AppState::default();

    let res = ui::run_app(&mut terminal, &mut app);

    disable_raw_mode()?;
    terminal.show_cursor()?;
    if let Err(err) = res {
        println!("Error: {:?}", err);
    }

    Ok(())
}
