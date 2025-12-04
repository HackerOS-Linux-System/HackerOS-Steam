use clap::{Parser, Subcommand};
use podman_api::opts::*;
use podman_api::{Podman, Result};
use std::path::{Path, PathBuf};
use anyhow::{Context, bail};
use log::{info, warn, error, LevelFilter};
use sysinfo::{System, SystemExt, DiskExt};
use regex::Regex;
use std::fs;

const CONTAINER_NAME: &str = "hackerosteam";
const IMAGE_NAME: &str = "registry.fedoraproject.org/fedora:41";
const DATA_DIR: &str = "/home/steam/.local/share/Steam";
const OVERLAY_LOWER: &str = "/var/lib/hackerosteam/empty";
const OVERLAY_UPPER: &str = "/var/lib/hackerosteam/upper";
const OVERLAY_WORK: &str = "/var/lib/hackerosteam/work";
const OVERLAY_MOUNT: &str = "/home/steam";

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

fn get_podman() -> Result<Podman> {
    Podman::connect_with_unix("/run/user/1000/podman/podman.sock")
        .or_else(|_| Podman::connect_with_defaults())
        .map_err(Into::into)
}

fn get_host_data_dirs() -> anyhow::Result<(PathBuf, PathBuf, PathBuf, PathBuf)> {
    let base = Path::new("/var/lib/hackerosteam");
    fs::create_dir_all(base)?;
    fs::create_dir_all(base.join("empty"))?;
    fs::create_dir_all(base.join("upper"))?;
    fs::create_dir_all(base.join("work"))?;
    Ok((
        base.to_path_buf(),
        base.join("upper"),
        base.join("work"),
        base.join("empty"),
    ))
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

fn check_gpu_drivers() -> anyhow::Result<()> {
    if !Path::new("/dev/dri").exists() {
        bail!(ContainerError::NoGpu);
    }

    // NVIDIA?
    if Path::new("/dev/nvidia0").exists() || System::new_all().gpus().iter().any(|g| g.vendor().contains("NVIDIA")) {
        if which::which("nvidia-container-toolkit").is_err() {
            bail!(ContainerError::NvidiaMissing);
        }
        info!("NVIDIA wykryte – używamy nvidia-container-runtime");
    } else {
        info!("GPU: Intel/AMD (Mesa) – pełna akceleracja");
    }
    Ok(())
}

async fn ensure_overlay() -> anyhow::Result<()> {
    let (_, upper, work, lower) = get_host_data_dirs()?;
    if !upper.exists() || fs::metadata(&upper)?.len() == 0 {
        info!("Inicjalizacja overlayfs dla Steam...");
        tokio::fs::create_dir_all(&upper).await?;
        tokio::fs::create_dir_all(&work).await?;
    }
    Ok(())
}

async fn create_container(podman: &Podman) -> anyhow::Result<()> {
    check_gpu_drivers()?;
    let display = detect_display_server();
    if display == "none" {
        bail!(ContainerError::NoDisplay);
    }

    let (_, upper, work, lower) = get_host_data_dirs()?;
    ensure_overlay().await?;

    let overlay = format!(
        "{}:{}:{}:/home/steam:rw",
        upper.display(),
        lower.display(),
        work.display()
    );

    let mut mounts = vec![
        Mount::builder()
            .type_("bind")
            .source("/tmp/.X11-unix")
            .target("/tmp/.X11-unix")
            .build(),
        Mount::builder()
            .type_("bind")
            .source("/run/user/1000")
            .target("/run/user/1000")
            .build(),
        Mount::builder()
            .type_("overlay")
            .source(&overlay)
            .target("/home/steam")
            .build(),
    ];

    if Path::new("/dev/nvidia0").exists() {
        mounts.push(Mount::builder().type_("bind").source("/dev/nvidia0").target("/dev/nvidia0").build());
        mounts.push(Mount::builder().type_("bind").source("/dev/nvidiactl").target("/dev/nvidiactl").build());
    }

    let opts = ContainerCreateOpts::builder()
        .image(IMAGE_NAME)
        .name(CONTAINER_NAME)
        .hostname("hackerosteam")
        .tty(true)
        .userns("keep-id")
        .user_ns("host")
        .ipc("host")
        .pid("host")
        .uts("host")
        .mounts(mounts)
        .devices(vec![
            "/dev/dri:/dev/dri",
            "/dev/snd:/dev/snd",
            "/dev/input:/dev/input",
        ])
        .device_cgroup_rules(vec![
            "c 226:* rwm", // dri
            "c 116:* rwm", // snd
            "c 13:* rwm",  // input
        ])
        .cap_add(vec!["SYS_NICE", "IPC_LOCK"])
        .cap_drop("ALL")
        .security_opt("label=disable")
        .security_opt("no-new-privileges")
        .env(vec![
            "DISPLAY=:0".to_string(),
            "WAYLAND_DISPLAY=wayland-0".to_string(),
            "XDG_RUNTIME_DIR=/run/user/1000".to_string(),
            "PULSE_SERVER=unix:/run/user/1000/pulse/native".to_string(),
            "STEAMOS=1".to_string(),
            "STEAM_RUNTIME=0".to_string(),
        ])
        .cgroups(CgroupConfig::builder()
            .cpu_quota(90000)
            .memory_limit("16G")
            .pids_limit(4096)
            .io_weight(1000)
            .build())
        .build();

    if podman.containers().get(CONTAINER_NAME).inspect().await.is_ok() {
        info!("Kontener już istnieje.");
        return Ok(());
    }

    info!("Tworzenie bezpiecznego kontenera Steam...");
    podman.containers().create(&opts).await?;
    info!("Kontener {} utworzony!", CONTAINER_NAME);

    // Pierwsze uruchomienie – instalacja Steam + gamescope
    let exec = podman.containers().get(CONTAINER_NAME).exec(
        &ExecCreateOpts::builder()
            .command(vec!["/bin/bash", "-c", r#"
                dnf install -y steam gamescope vulkan-tools mesa-vulkan-drivers \
                               libva-vdpau-driver pipewire-pulseaudio \
                               xorg-x11-server-Xvfb gamemode && \
                useradd -m -u 1000 -g 1000 steam && \
                mkdir -p /home/steam/.steam && \
                chown -R steam:steam /home/steam && \
                echo "Kontener Steam gotowy!"
            "#])
            .user("root")
            .privileged(false)
            .build(),
    ).await?;

    let mut stream = exec.start().await?;
    while let Some(chunk) = stream.next().await {
        print!("{}", chunk?);
    }

    Ok(())
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    env_logger::Builder::new()
        .filter(None, LevelFilter::Info)
        .init();

    let cli = Cli::parse();
    let podman = get_podman()?;

    match cli.command {
        Commands::Create => {
            create_container(&podman).await?;
        }
        Commands::Run { session } => {
            create_container(&podman).await?;
            let container = podman.containers().get(CONTAINER_NAME);

            let session_cmd = match session.as_deref() {
                Some("gamescope-session-steam") | Some("deck") => {
                    "su - steam -c 'gamescope -e -- steam -gamepadui'"
                }
                _ => "su - steam -c 'steam -silent || steam'",
            };

            info!("Uruchamianie: {}", session_cmd);
            container.start(&ContainerStartOpts::default()).await?;

            let exec = container.exec(&ExecCreateOpts::builder()
                .command(vec!["/bin/bash", "-c", session_cmd])
                .attach_stdout(true)
                .attach_stderr(true)
                .tty(true)
                .user("steam")
                .build()).await?;

            let mut stream = exec.start().await?;
            while let Some(chunk) = stream.next().await {
                print!("{}", chunk?);
            }
        }
        Commands::Update => {
            info!("Aktualizacja obrazu i pakietów...");
            let img = podman.images().get(IMAGE_NAME);
            img.pull(&PullOpts::builder().build()).await?;
            // TODO: rebuild z nowymi warstwami
        }
        Commands::Kill => {
            podman.containers().get(CONTAINER_NAME).kill(None).await?;
            info!("Steam zatrzymany.");
        }
        Commands::Restart => {
            let c = podman.containers().get(CONTAINER_NAME);
            c.restart(&ContainerRestartOpts::default()).await?;
            warn!("Kontener zrestartowany – dane w overlayfs zachowane!");
        }
        Commands::Remove => {
            let c = podman.containers().get(CONTAINER_NAME);
            c.stop(None).await.ok();
            c.delete(&ContainerDeleteOpts::builder().force(true).build()).await?;
            info!("Kontener usunięty.");
        }
        Commands::Status => {
            let c = podman.containers().get(CONTAINER_NAME);
            match c.inspect().await {
                Ok(info) => println!("Status: {} | PID: {}", info.state.status, info.state.pid.unwrap_or(0)),
                Err(_) => println!("Kontener nie istnieje."),
            }
        }
    }

    Ok(())
  }
