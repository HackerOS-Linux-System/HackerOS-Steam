use clap::{Parser, Subcommand};
use podman_api::opts::*;
use podman_api::{Podman};
use std::path::{Path, PathBuf};
use anyhow::bail;
use log::{info, warn, LevelFilter};
use podman_api::models::{ContainerMount, Namespace, LinuxDeviceCgroup, LinuxResources, LinuxCpu, LinuxMemory, LinuxPids, LinuxBlockIo};
use podman_api::opts::UserOpt;
use std::fs;
use futures_util::stream::StreamExt;
use which;
use podman_api::conn::TtyChunk;

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

fn get_podman() -> anyhow::Result<Podman> {
    let user_socket = format!("/run/user/{}/podman/podman.sock", nix::unistd::getuid().as_raw());
    if Path::new(&user_socket).exists() {
        Ok(Podman::unix(user_socket))
    } else {
        Ok(Podman::unix("/run/podman/podman.sock"))
    }
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
    if Path::new("/dev/nvidia0").exists() {
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
    let (_, upper, work, _lower) = get_host_data_dirs()?;
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

async fn create_container(podman: &Podman) -> anyhow::Result<()> {
    check_gpu_drivers()?;
    let display = detect_display_server();
    if display == "none" {
        bail!(ContainerError::NoDisplay);
    }
    let (_, upper, work, lower) = get_host_data_dirs()?;
    ensure_overlay().await?;
    let overlay_opts = vec![
        format!("upperdir={}", upper.display()),
        format!("lowerdir={}", lower.display()),
        format!("workdir={}", work.display())
    ];
    let mut mounts = vec![
        ContainerMount {
            _type: Some("bind".to_string()),
            source: Some("/tmp/.X11-unix".to_string()),
            destination: Some("/tmp/.X11-unix".to_string()),
            options: None,
            uid_mappings: None,
            gid_mappings: None,
        },
        ContainerMount {
            _type: Some("bind".to_string()),
            source: Some("/run/user/1000".to_string()),
            destination: Some("/run/user/1000".to_string()),
            options: None,
            uid_mappings: None,
            gid_mappings: None,
        },
        ContainerMount {
            _type: Some("overlay".to_string()),
            source: None,
            destination: Some("/home/steam".to_string()),
            options: Some(overlay_opts),
            uid_mappings: None,
            gid_mappings: None,
        },
        ContainerMount {
            _type: Some("bind".to_string()),
            source: Some("/dev/dri".to_string()),
            destination: Some("/dev/dri".to_string()),
            options: None,
            uid_mappings: None,
            gid_mappings: None,
        },
        ContainerMount {
            _type: Some("bind".to_string()),
            source: Some("/dev/snd".to_string()),
            destination: Some("/dev/snd".to_string()),
            options: None,
            uid_mappings: None,
            gid_mappings: None,
        },
        ContainerMount {
            _type: Some("bind".to_string()),
            source: Some("/dev/input".to_string()),
            destination: Some("/dev/input".to_string()),
            options: None,
            uid_mappings: None,
            gid_mappings: None,
        },
    ];
    if Path::new("/dev/nvidia0").exists() {
        mounts.push(ContainerMount {
            _type: Some("bind".to_string()),
            source: Some("/dev/nvidia0".to_string()),
            destination: Some("/dev/nvidia0".to_string()),
            options: None,
            uid_mappings: None,
            gid_mappings: None,
        });
        mounts.push(ContainerMount {
            _type: Some("bind".to_string()),
            source: Some("/dev/nvidiactl".to_string()),
            destination: Some("/dev/nvidiactl".to_string()),
            options: None,
            uid_mappings: None,
            gid_mappings: None,
        });
    }
    let device_cgroup_rules = vec![
        LinuxDeviceCgroup {
            type_: Some("c".to_string()),
            major: Some(226),
            minor: Some(-1),
            access: Some("rwm".to_string()),
            allow: Some(true),
        },
        LinuxDeviceCgroup {
            type_: Some("c".to_string()),
            major: Some(116),
            minor: Some(-1),
            access: Some("rwm".to_string()),
            allow: Some(true),
        },
        LinuxDeviceCgroup {
            type_: Some("c".to_string()),
            major: Some(13),
            minor: Some(-1),
            access: Some("rwm".to_string()),
            allow: Some(true),
        },
    ];
    let resources = LinuxResources {
        cpu: Some(LinuxCpu {
            quota: Some(90000),
            period: None,
            realtime_period: None,
            realtime_runtime: None,
            shares: None,
            cpus: None,
            mems: None,
        }),
        memory: Some(LinuxMemory {
            limit: Some(17179869184), // 16G
            reservation: None,
            swap: None,
            kernel: None,
            kernel_tcp: None,
            swappiness: None,
            disable_oom_killer: None,
            use_hierarchy: None,
        }),
        pids: Some(LinuxPids {
            limit: Some(4096),
        }),
        block_io: Some(LinuxBlockIo {
            weight: Some(1000),
            leaf_weight: None,
            weight_device: None,
            throttle_read_bps_device: None,
            throttle_read_iops_device: None,
            throttle_write_bps_device: None,
            throttle_write_iops_device: None,
        }),
        devices: Some(device_cgroup_rules),
        hugepage_limits: None,
        network: None,
        rdma: None,
        unified: None,
    };
    let opts = ContainerCreateOpts::builder()
        .image(IMAGE_NAME)
        .name(CONTAINER_NAME)
        .hostname("hackerosteam")
        .terminal(true)
        .user_namespace(Namespace { nsmode: Some("keep-id".to_string()), value: None })
        .ipc_namespace(Namespace { nsmode: Some("host".to_string()), value: None })
        .pid_namespace(Namespace { nsmode: Some("host".to_string()), value: None })
        .uts_namespace(Namespace { nsmode: Some("host".to_string()), value: None })
        .mounts(mounts)
        .add_capabilities(vec!["SYS_NICE".to_string(), "IPC_LOCK".to_string()])
        .drop_capabilities(vec!["ALL".to_string()])
        .selinux_opts(vec!["label=disable".to_string()])
        .no_new_privilages(true)
        .env(vec![
            ("DISPLAY".to_string(), ":0".to_string()),
            ("WAYLAND_DISPLAY".to_string(), "wayland-0".to_string()),
            ("XDG_RUNTIME_DIR".to_string(), "/run/user/1000".to_string()),
            ("PULSE_SERVER".to_string(), "unix:/run/user/1000/pulse/native".to_string()),
            ("STEAMOS".to_string(), "1".to_string()),
            ("STEAM_RUNTIME".to_string(), "0".to_string()),
        ])
        .resource_limits(resources)
        .build();
    if podman.containers().get(CONTAINER_NAME).inspect().await.is_ok() {
        info!("Kontener już istnieje.");
        return Ok(());
    }
    info!("Tworzenie bezpiecznego kontenera Steam...");
    podman.containers().create(&opts).await?;
    info!("Kontener {} utworzony!", CONTAINER_NAME);
    // Pierwsze uruchomienie – instalacja Steam + gamescope
    let exec = podman.containers().get(CONTAINER_NAME).create_exec(
        &ExecCreateOpts::builder()
            .command(vec!["/bin/bash".to_string(), "-c".to_string(), r#"
        dnf install -y steam gamescope vulkan-tools mesa-vulkan-drivers \
        libva-vdpau-driver pipewire-pulseaudio \
        xorg-x11-server-Xvfb gamemode && \
        useradd -m -u 1000 -g 1000 steam && \
        mkdir -p /home/steam/.steam && \
        chown -R steam:steam /home/steam && \
        echo "Kontener Steam gotowy!"
        "#.to_string()])
            .user(UserOpt::User("root".to_string()))
            .privileged(false)
            .build(),
    ).await?;
    let start_opts = ExecStartOpts::builder().tty(true).build();
    let output = exec.start(&start_opts).await?;
    if let Some(mut stream) = output {
        while let Some(item) = stream.next().await {
            let chunk = item?;
            match chunk {
                TtyChunk::StdOut(bytes) | TtyChunk::StdErr(bytes) => {
                    print!("{}", String::from_utf8_lossy(&bytes));
                }
                TtyChunk::StdIn(_) => {}
            }
        }
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
                    "su - steam -c 'gamescope -e -- steam -gamepadui'".to_string()
                }
                _ => "su - steam -c 'steam -silent || steam'".to_string(),
            };
            info!("Uruchamianie: {}", session_cmd);
            container.start(None).await?;
            let exec = container.create_exec(&ExecCreateOpts::builder()
                .command(vec!["/bin/bash".to_string(), "-c".to_string(), session_cmd])
                .attach_stdout(true)
                .attach_stderr(true)
                .tty(true)
                .user(UserOpt::User("steam".to_string()))
                .build()).await?;
            let start_opts = ExecStartOpts::builder().tty(true).build();
            let output = exec.start(&start_opts).await?;
            if let Some(mut stream) = output {
                while let Some(item) = stream.next().await {
                    let chunk = item?;
                    match chunk {
                        TtyChunk::StdOut(bytes) | TtyChunk::StdErr(bytes) => {
                            print!("{}", String::from_utf8_lossy(&bytes));
                        }
                        TtyChunk::StdIn(_) => {}
                    }
                }
            }
        }
        Commands::Update => {
            info!("Aktualizacja obrazu i pakietów...");
            let pull_opts = PullOpts::builder().reference(IMAGE_NAME).build();
            let images = podman.images();
            let mut pull_stream = images.pull(&pull_opts);
            while let Some(item) = pull_stream.next().await {
                let _ = item?;
            }
            // TODO: rebuild z nowymi warstwami
        }
        Commands::Kill => {
            podman.containers().get(CONTAINER_NAME).kill().await?;
            info!("Steam zatrzymany.");
        }
        Commands::Restart => {
            let c = podman.containers().get(CONTAINER_NAME);
            c.restart().await?;
            warn!("Kontener zrestartowany – dane w overlayfs zachowane!");
        }
        Commands::Remove => {
            let c = podman.containers().get(CONTAINER_NAME);
            c.stop(&ContainerStopOpts::builder().build()).await.ok();
            c.delete(&ContainerDeleteOpts::builder().force(true).build()).await?;
            info!("Kontener usunięty.");
        }
        Commands::Status => {
            let c = podman.containers().get(CONTAINER_NAME);
            match c.inspect().await {
                Ok(info) => {
                    if let Some(state) = info.state {
                        println!("Status: {} | PID: {}", state.status.unwrap_or_default(), state.pid.unwrap_or(0));
                    } else {
                        println!("Brak stanu kontenera.");
                    }
                }
                Err(_) => println!("Kontener nie istnieje."),
            }
        }
    }
    Ok(())
}
