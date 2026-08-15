//! Spawns the bundled DeepSeek Harness server and waits for its URL.
//!
//! The app ships a self-contained Node.js runtime plus the `@deepseek-ai/dsh`
//! npm install under `<Resources>/runtime`. On startup we launch
//! `node .../dsh/lib/bin.js web --port 0`, read the announced URL from stdout
//! (`dsh web: http://127.0.0.1:<port>`), and hand it to the window. `--port 0`
//! lets the OS pick a free port so the desktop app never collides with a
//! browser instance already serving on 3080.

use std::io::{BufRead, BufReader};
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicI32, Ordering};
use std::sync::Mutex;
use std::time::Duration;

use tauri::{AppHandle, Manager};

/// PID of the spawned server child, published for the signal-handler thread.
static SERVER_PID: AtomicI32 = AtomicI32::new(0);

/// Block SIGTERM/SIGINT and reap the server child when one arrives.
///
/// macOS delivers SIGTERM on logout/shutdown and when the app is killed from a
/// terminal, neither of which goes through Tauri's normal exit path (window
/// close / Cmd+Q). Without this, the bundled node server would be orphaned.
/// Must be called before `tauri::Builder::run()` so every Tauri thread inherits
/// the blocked mask and the signal lands in the `sigwait` thread.
#[cfg(unix)]
pub fn install_signal_handler() {
    use std::sync::OnceLock;

    static INSTALLED: OnceLock<()> = OnceLock::new();
    INSTALLED.get_or_init(|| {
        unsafe {
            let mut set: libc::sigset_t = std::mem::zeroed();
            libc::sigemptyset(&mut set);
            libc::sigaddset(&mut set, libc::SIGTERM);
            libc::sigaddset(&mut set, libc::SIGINT);
            // Block in the current thread; child threads inherit the mask.
            libc::pthread_sigmask(libc::SIG_BLOCK, &set, std::ptr::null_mut());
        }
        std::thread::spawn(move || {
            let mut set: libc::sigset_t = unsafe { std::mem::zeroed() };
            unsafe {
                libc::sigemptyset(&mut set);
                libc::sigaddset(&mut set, libc::SIGTERM);
                libc::sigaddset(&mut set, libc::SIGINT);
            }
            loop {
                let mut sig: libc::c_int = 0;
                let ret = unsafe { libc::sigwait(&set, &mut sig) };
                if ret != 0 {
                    continue;
                }
                let pid = SERVER_PID.load(Ordering::SeqCst);
                if pid > 0 {
                    unsafe {
                        libc::kill(pid, libc::SIGKILL);
                    }
                }
                // Match Tauri's exit status for SIGTERM/SIGINT.
                let code = if sig == libc::SIGINT { 130 } else { 143 };
                std::process::exit(code);
            }
        });
    });
}

/// Holds the spawned server process so it can be killed when the app exits.
pub struct ServerProcess(pub Mutex<Option<Child>>);

impl ServerProcess {
    pub fn new() -> Self {
        Self(Mutex::new(None))
    }

    /// Kill and reap the server child (no-op when none is running).
    pub fn kill(&self) {
        if let Ok(mut guard) = self.0.lock() {
            if let Some(mut child) = guard.take() {
                let _ = child.kill();
                let _ = child.wait();
            }
        }
    }
}

impl Default for ServerProcess {
    fn default() -> Self {
        Self::new()
    }
}

/// Resolve the bundled runtime directory: `<Resources>/runtime`.
fn runtime_dir(app: &AppHandle) -> PathBuf {
    app.path()
        .resource_dir()
        .unwrap_or_else(|_| PathBuf::from("."))
        .join("runtime")
}

/// Pull `http://127.0.0.1:<port>` out of a stdout line like
/// `dsh web: http://127.0.0.1:52647`.
fn extract_url(line: &str) -> Option<String> {
    let line = line.trim();
    let start = line.find("http://")?;
    let rest = &line[start..];
    let end = rest.find(char::is_whitespace).unwrap_or(rest.len());
    let url = &rest[..end];
    if url.starts_with("http://127.0.0.1:") || url.starts_with("http://localhost:") {
        Some(url.to_string())
    } else {
        None
    }
}

/// Spawn the bundled harness server, block until it announces its URL, and
/// return `(child, url)`. The caller stores `child` in `ServerProcess` state.
/// Returns `None` when the runtime is missing or the server never starts.
pub fn start(app: &AppHandle) -> Option<(Child, String)> {
    let rt = runtime_dir(app);
    let node = rt.join("node");
    let entry = rt.join("app/node_modules/@deepseek-ai/dsh/lib/bin.js");

    if !node.is_file() || !entry.is_file() {
        eprintln!(
            "[dsh] bundled runtime missing: node={:?} entry={:?}",
            node, entry
        );
        return None;
    }

    // Route server stderr to a log file under the app data dir.
    let log_path = app
        .path()
        .app_log_dir()
        .map(|dir| dir.join("dsh-server.log"))
        .unwrap_or_else(|_| PathBuf::from("/tmp/dsh-server.log"));
    if let Some(parent) = log_path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    let log_file = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&log_path)
        .ok();

    // The invoking directory becomes the harness workspace root; use the
    // user's home as a sane default (the GUI can switch workspaces itself).
    let home = std::env::var("HOME").unwrap_or_else(|_| "/".to_string());

    let mut command = Command::new(&node);
    command
        .arg(&entry)
        .arg("web")
        .arg("--port")
        .arg("0")
        .current_dir(&home)
        .stdout(Stdio::piped())
        .stderr(match &log_file {
            Some(file) => match file.try_clone() {
                Ok(clone) => Stdio::from(clone),
                Err(_) => Stdio::inherit(),
            },
            None => Stdio::inherit(),
        });

    let mut child = match command.spawn() {
        Ok(child) => child,
        Err(err) => {
            eprintln!("[dsh] failed to spawn server: {err}");
            return None;
        }
    };

    // Publish the pid so the SIGTERM/SIGINT handler can reap the server.
    SERVER_PID.store(child.id() as i32, Ordering::SeqCst);

    // Take the stdout pipe first so the child can be moved into state below.
    let stdout = match child.stdout.take() {
        Some(stdout) => stdout,
        None => {
            let _ = child.kill();
            return None;
        }
    };

    let (tx, rx) = std::sync::mpsc::channel::<String>();
    std::thread::spawn(move || {
        let reader = BufReader::new(stdout);
        for line in reader.lines() {
            let line = match line {
                Ok(line) => line,
                Err(_) => break,
            };
            if let Some(url) = extract_url(&line) {
                let _ = tx.send(url);
                break;
            }
        }
    });

    // The server announces its URL within a second or two; 90s is a generous
    // cap so a broken runtime degrades to an error page instead of hanging.
    match rx.recv_timeout(Duration::from_secs(90)) {
        Ok(url) => {
            eprintln!("[dsh] server URL: {url}");
            Some((child, url))
        }
        Err(_) => {
            eprintln!("[dsh] timed out waiting for server URL");
            let _ = child.kill();
            None
        }
    }
}
