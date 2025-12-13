use clap::{Parser, Subcommand};
use std::path::{Path, PathBuf};
use anyhow::bail;
use log::{info, warn, LevelFilter};
use std::fs;
use which::which;
use std::env;
use nix::unistd::{getuid, getgid};
use std::process::{Command, Stdio};
use std::fs::read_dir;

const CONTAINER_NAME: &str = "hackerosteam";
const RELEASE: &str = "43";
#[derive(thiserror::Error, Debug)]
enum ContainerError {
    #[error("Brak sterowników GPU (brak /dev/dri)")]
    NoGpu,
    #[error("Nie znaleziono sesji graficznej (X11/Wayland)")]
    NoDisplay,
    #[error("NVIDIA wykryte, ale brak sterowników (nvidia-container-toolkit)")]
    NvidiaMissing,
}
#[derive(Parser)]
#[command(name = "HackerOS-Steam", about = "Najlepszy kontener Steam dla Linuxa", version)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}
#[derive(Subcommand)]
enum Commands {
    Create,
    Run { session: Option<String> },
    Update,
    Kill,
    Restart,
    Remove,
    Status,
}
fn get_container_root() -> anyhow::Result<PathBuf> {
    let home = env::var("HOME")?;
    Ok(PathBuf::from(home).join(".hackeros").join("HackerOS-Steam"))
}
fn get_data_dir() -> anyhow::Result<PathBuf> {
    let xdg = env::var("XDG_DATA_HOME").ok();
    let base = if let Some(x) = xdg {
        PathBuf::from(x)
    } else {
        PathBuf::from(env::var("HOME")?).join(".local/share")
    }.join("hackerosteam");
    Ok(base)
}
fn get_host_data_dirs() -> anyhow::Result<(PathBuf, PathBuf, PathBuf, PathBuf)> {
    let base = get_data_dir()?;
    fs::create_dir_all(&base)?;
    let empty = base.join("empty");
    fs::create_dir_all(&empty)?;
    let upper = base.join("upper");
    fs::create_dir_all(&upper)?;
    let work = base.join("work");
    fs::create_dir_all(&work)?;
    Ok((base, upper, work, empty))
}
fn detect_display_server() -> &'static str {
    if std::env::var("WAYLAND_DISPLAY").is_ok() {
        "wayland"
    } else if std::env::var("DISPLAY").is_ok() {
        "x11"
    } else {
        "none"
    }
}
fn check_gpu_drivers() -> anyhow::Result<bool> {
    if !Path::new("/dev/dri").exists() {
        bail!(ContainerError::NoGpu);
    }
    let is_nvidia = Path::new("/dev/nvidia0").exists();
    if is_nvidia {
        if which("nvidia-container-toolkit").is_err() {
            bail!(ContainerError::NvidiaMissing);
        }
        info!("NVIDIA wykryte – używamy nvidia-container-runtime");
    } else {
        info!("GPU: Intel/AMD (Mesa) – pełna akceleracja");
    }
    Ok(is_nvidia)
}
async fn ensure_overlay() -> anyhow::Result<()> {
    let (_base, upper, work, _empty) = get_host_data_dirs()?;
    let mut is_empty = true;
    if upper.exists() {
        let mut dir = tokio::fs::read_dir(&upper).await?;
        if dir.next_entry().await?.is_some() {
            is_empty = false;
        }
    }
    if !upper.exists() || is_empty {
        info!("Inicjalizacja overlayfs dla Steam...");
        tokio::fs::create_dir_all(&upper).await?;
        tokio::fs::create_dir_all(&work).await?;
    }
    Ok(())
}
async fn create_container() -> anyhow::Result<()> {
    let is_nvidia = check_gpu_drivers()?;
    let display = detect_display_server();
    if display == "none" {
        bail!(ContainerError::NoDisplay);
    }
    let container_root = get_container_root()?;
    let (_base, upper, work, empty) = get_host_data_dirs()?;
    ensure_overlay().await?;
    let uid = getuid().as_raw();
    let gid = getgid().as_raw();
    if container_root.join("etc").exists() {
        info!("Kontener już istnieje – pomijamy tworzenie.");
        return Ok(());
    }
    fs::create_dir_all(&container_root)?;
    info!("Tworzenie bezpiecznego kontenera Steam...");
    let mut cmd = Command::new("sudo");
    cmd.arg("dnf");
    cmd.arg("--installroot");
    cmd.arg(&container_root);
    cmd.arg("--releasever");
    cmd.arg(RELEASE);
    cmd.arg("--assumeyes");
    cmd.arg("--setopt");
    cmd.arg("install_weak_deps=False");
    cmd.arg("install");
    cmd.arg("fedora-release-container");
    cmd.arg("bash");
    cmd.arg("dnf");
    cmd.arg("glibc-minimal-langpack");
    cmd.arg("util-linux");
    cmd.arg("shadow-utils");
    let output = cmd.output()?;
    if !output.status.success() {
        bail!("Błąd instalowania base system: {}", String::from_utf8_lossy(&output.stderr));
    }
    print!("{}", String::from_utf8_lossy(&output.stdout));
    let install_cmd = format!(
        r#"dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm &&
        dnf update -y &&
        packages="steam gamescope vulkan-tools pipewire-pulseaudio gamemode bzip2-libs bzip2-libs.i686 glibc-langpack-en util-linux" &&
        dnf install -y $packages &&
        ln -s $(readlink -f /usr/lib/libbz2.so.1) /usr/lib/libbz2.so.1.0 || true &&
        ln -s $(readlink -f /usr/lib64/libbz2.so.1) /usr/lib64/libbz2.so.1.0 || true &&
        [ -f /etc/gshadow ] || touch /etc/gshadow &&
        chmod 600 /etc/gshadow || true &&
        gid={} &&
        uid={} &&
        group_name="steamgroup" &&
        user_name="steam" &&
        if getent passwd $uid >/dev/null; then
            existing_user=$(getent passwd $uid | cut -d: -f1)
    userdel -r $existing_user || true
    fi &&
    if getent group $gid >/dev/null; then
        existing_group=$(getent group $gid | cut -d: -f1)
    groupdel $existing_group || true
    fi &&
    groupadd -g $gid $group_name || true &&
    useradd -m -u $uid -g $gid $user_name || true &&
    mkdir -p /home/steam/.steam || true &&
    chown -R $uid:$gid /home/steam || true &&
    echo "Kontener Steam gotowy!""#,
    gid, uid
    );
    let mut cmd = Command::new("sudo");
    cmd.arg("systemd-nspawn");
    cmd.arg("-D");
    cmd.arg(&container_root);
    cmd.arg("--quiet");
    cmd.arg("/bin/bash");
    cmd.arg("-c");
    cmd.arg(&install_cmd);
    cmd.stdout(Stdio::inherit());
    cmd.stderr(Stdio::inherit());
    cmd.status()?;
    info!("Kontener {} utworzony!", CONTAINER_NAME);
    Ok(())
}
async fn run_container(session: Option<String>) -> anyhow::Result<()> {
    let container_root = get_container_root()?;
    let is_nvidia = check_gpu_drivers()?;
    let display = detect_display_server();
    if display == "none" {
        bail!(ContainerError::NoDisplay);
    }
    let uid = getuid().as_raw();
    let gid = getgid().as_raw();
    let run_user = format!("/run/user/{}", uid);
    let (_base, upper, work, empty) = get_host_data_dirs()?;
    let mount_overlay = format!("mkdir -p /home/steam && mount -t overlay overlay -o lowerdir={},upperdir={},workdir={} /home/steam && chown {}:{} /home/steam", empty.display(), upper.display(), work.display(), uid, gid);
    let session_cmd = match session.as_deref() {
        Some("gamescope-session-steam") | Some("deck") => {
            "rm -f ~/.steam/steam.pid ~/.steam/.crash && gamescope -e -- steam -gamepadui".to_string()
        }
        _ => "rm -f ~/.steam/steam.pid ~/.steam/.crash && steam".to_string(),
    };
    let exec_cmd = format!("{} && su - steam -c '{}'", mount_overlay, session_cmd);
    info!("Uruchamianie: {}", session_cmd);
    let mut cmd = Command::new("sudo");
    cmd.arg("systemd-nspawn");
    cmd.arg("-D");
    cmd.arg(&container_root);
    cmd.arg("--quiet");
    cmd.arg("--private-users=no");
    cmd.arg("--network-namespace-path=/proc/1/ns/net");
    cmd.arg("--ipc-namespace-path=/proc/1/ns/ipc");
    cmd.arg("--pid-namespace-path=/proc/1/ns/pid");
    cmd.arg("--uts-namespace-path=/proc/1/ns/uts");
    cmd.arg("--no-new-privileges=yes");
    cmd.arg("--capability=SYS_NICE");
    cmd.arg("--capability=IPC_LOCK");
    cmd.arg("--property=CPUQuota=90%");
    cmd.arg("--property=MemoryMax=17179869184");
    cmd.arg("--property=TasksMax=4096");
    cmd.arg("--property=IOWeight=1000");
    cmd.arg("--property=DeviceAllow=char-226 rwm");
    cmd.arg("--property=DeviceAllow=char-116 rwm");
    cmd.arg("--property=DeviceAllow=char-13 rwm");
    let mut binds = vec![
        "--bind=/tmp/.X11-unix:/tmp/.X11-unix".to_string(),
        format!("--bind={}:{}", run_user, run_user),
            format!("--bind={}: /mnt/upper", upper.display()),
                format!("--bind={}: /mnt/work", work.display()),
                    format!("--bind={}: /mnt/empty", empty.display()),
                        "--bind=/dev/dri:/dev/dri".to_string(),
                        "--bind=/dev/snd:/dev/snd".to_string(),
                        "--bind=/dev/input:/dev/input".to_string(),
    ];
    if Path::new("/usr/share/vulkan").exists() {
        binds.push("--bind-ro=/usr/share/vulkan:/usr/share/vulkan".to_string());
    }
    if Path::new("/usr/share/glvnd").exists() {
        binds.push("--bind-ro=/usr/share/glvnd:/usr/share/glvnd".to_string());
    }
    if Path::new("/usr/share/drirc.d").exists() {
        binds.push("--bind-ro=/usr/share/drirc.d:/usr/share/drirc.d".to_string());
    }
    if !is_nvidia {
        if Path::new("/usr/lib64/dri").exists() {
            binds.push("--bind-ro=/usr/lib64/dri:/usr/lib64/dri".to_string());
        }
        if Path::new("/usr/lib/dri").exists() {
            binds.push("--bind-ro=/usr/lib/dri:/usr/lib/dri".to_string());
        }
    } else {
        cmd.arg("--property=DeviceAllow=char-195 rwm");
        cmd.arg("--property=DeviceAllow=char-235 rwm");
        for dev in &["/dev/nvidia0", "/dev/nvidiactl", "/dev/nvidia-modeset", "/dev/nvidia-uvm", "/dev/nvidia-uvm-tools"] {
            if Path::new(dev).exists() {
                binds.push(format!("--bind={}:{}", dev, dev));
            }
        }
        // Bind NVIDIA libs
        let lib_dirs = vec!["/usr/lib64", "/usr/lib"];
        for lib_dir_str in lib_dirs {
            let lib_dir = Path::new(lib_dir_str);
            if lib_dir.exists() {
                for entry in read_dir(lib_dir)? {
                    let path = entry?.path();
                    if let Some(filename) = path.file_name() {
                        if let Some(s) = filename.to_str() {
                            if s.starts_with("libnvidia-") || s.starts_with("libcuda") || s.starts_with("libnvrtc") || s.starts_with("libGLX_nvidia") || s.starts_with("libEGL_nvidia") || s.starts_with("libGLESv1_CM_nvidia") || s.starts_with("libGLESv2_nvidia") {
                                binds.push(format!("--bind-ro={}:{}", path.display(), path.display()));
                            }
                        }
                    }
                }
            }
        }
        let bin_dir = Path::new("/usr/bin");
        if bin_dir.exists() {
            for entry in read_dir(bin_dir)? {
                let path = entry?.path();
                if let Some(filename) = path.file_name() {
                    if let Some(s) = filename.to_str() {
                        if s.starts_with("nvidia-") {
                            binds.push(format!("--bind-ro={}:{}", path.display(), path.display()));
                        }
                    }
                }
            }
        }
        if Path::new("/etc/OpenCL/vendors/nvidia.icd").exists() {
            binds.push("--bind-ro=/etc/OpenCL/vendors/nvidia.icd:/etc/OpenCL/vendors/nvidia.icd".to_string());
        }
    }
    for b in &binds {
        cmd.arg(b);
    }
    let mut envs = vec![
        format!("PULSE_SERVER=unix:{}/pulse/native", run_user),
            "STEAMOS=1".to_string(),
            "STEAM_RUNTIME=1".to_string(),
            format!("XDG_RUNTIME_DIR={}", run_user),
                format!("DBUS_SESSION_BUS_ADDRESS=unix:path={}/bus", run_user),
                    "LANG=en_US.UTF-8".to_string(),
                    format!("IS_NVIDIA={}", if is_nvidia { "true" } else { "false" }),
    ];
    if display == "x11" {
        envs.push(format!("DISPLAY={}", env::var("DISPLAY").unwrap_or(":0".to_string())));
    }
    if display == "wayland" {
        envs.push(format!("WAYLAND_DISPLAY={}", env::var("WAYLAND_DISPLAY").unwrap_or("wayland-0".to_string())));
    }
    if is_nvidia {
        envs.push("NVIDIA_VISIBLE_DEVICES=all".to_string());
        envs.push("NVIDIA_DRIVER_CAPABILITIES=all".to_string());
        envs.push("__GLX_VENDOR_LIBRARY_NAME=nvidia".to_string());
    }
    for e in envs {
        cmd.arg("-E");
        cmd.arg(e);
    }
    cmd.arg("--console=interactive");
    cmd.arg("--");
    cmd.arg("/bin/bash");
    cmd.arg("-c");
    cmd.arg(&exec_cmd);
    cmd.stdin(Stdio::inherit());
    cmd.stdout(Stdio::inherit());
    cmd.stderr(Stdio::inherit());
    cmd.status()?;
    Ok(())
}
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    env_logger::Builder::new()
    .filter(None, LevelFilter::Info)
    .init();
    let cli = Cli::parse();
    match cli.command {
        Commands::Create => create_container().await?,
        Commands::Run { session } => {
            create_container().await?;
            run_container(session).await?
        }
        Commands::Update => {
            let container_root = get_container_root()?;
            info!("Aktualizacja obrazu Fedora...");
            let mut cmd = Command::new("sudo");
            cmd.arg("systemd-nspawn");
            cmd.arg("-D");
            cmd.arg(&container_root);
            cmd.arg("--quiet");
            cmd.arg("/bin/bash");
            cmd.arg("-c");
            cmd.arg("dnf update -y");
            cmd.stdout(Stdio::inherit());
            cmd.stderr(Stdio::inherit());
            cmd.status()?;
            info!("Obraz zaktualizowany. Uruchom `hackerosteam remove && hackerosteam create` aby zainstalować nowe pakiety.");
        }
        Commands::Kill => {
            let container_root = get_container_root()?;
            let pattern = format!("systemd-nspawn -D {}", container_root.display());
            let mut cmd = Command::new("sudo");
            cmd.arg("pkill");
            cmd.arg("-f");
            cmd.arg(&pattern);
            cmd.status()?;
            info!("Steam zatrzymany.");
        }
        Commands::Restart => {
            let container_root = get_container_root()?;
            let pattern = format!("systemd-nspawn -D {}", container_root.display());
            let mut cmd = Command::new("sudo");
            cmd.arg("pkill");
            cmd.arg("-f");
            cmd.arg(&pattern);
            cmd.status()?;
            warn!("Kontener zrestartowany – dane w overlayfs zachowane!");
            run_container(None).await?
        }
        Commands::Remove => {
            let container_root = get_container_root()?;
            let mut cmd = Command::new("sudo");
            cmd.arg("rm");
            cmd.arg("-rf");
            cmd.arg(&container_root);
            cmd.status()?;
            info!("Kontener usunięty.");
        }
        Commands::Status => {
            let container_root = get_container_root()?;
            let mut cmd = Command::new("ps");
            cmd.arg("-ef");
            cmd.arg("--forest");
            let output = cmd.output()?;
            let out = String::from_utf8_lossy(&output.stdout);
            let lines = out.lines();
            let mut found = false;
            for line in lines {
                if line.contains(container_root.to_str().unwrap()) {
                    println!("{}", line);
                    found = true;
                }
            }
            if !found {
                println!("Kontener nie istnieje.");
            }
        }
    }
    Ok(())
}
