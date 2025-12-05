use clap::{Parser, Subcommand};
use podman_api::opts::*;
use podman_api::{Podman};
use std::path::{Path, PathBuf};
use anyhow::bail;
use log::{info, warn, LevelFilter};
use podman_api::models::{ContainerMount, Namespace, LinuxDeviceCgroup, LinuxResources, LinuxCpu, LinuxMemory, LinuxPids, LinuxBlockIo};
use std::fs;
use futures_util::stream::StreamExt;
use which::which;
use podman_api::conn::TtyChunk;
use std::env;
use nix::unistd::{getuid, getgid};

const CONTAINER_NAME: &str = "hackerosteam";
const IMAGE_NAME: &str = "registry.fedoraproject.org/fedora:43";

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
    let user_socket = format!("/run/user/{}/podman/podman.sock", getuid().as_raw());
    if Path::new(&user_socket).exists() {
        Ok(Podman::unix(user_socket))
    } else {
        bail!("Nie znaleziono gniazda Podman użytkownika. Uruchom `systemctl --user start podman.socket`");
    }
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

async fn create_container(podman: &Podman) -> anyhow::Result<()> {
    let is_nvidia = check_gpu_drivers()?;
    let display = detect_display_server();
    if display == "none" {
        bail!(ContainerError::NoDisplay);
    }

    let (_base, upper, work, empty) = get_host_data_dirs()?;
    ensure_overlay().await?;

    let uid = getuid().as_raw();
    let gid = getgid().as_raw();
    let run_user = format!("/run/user/{}", uid);

    let overlay_opts = vec![
        format!("upperdir={}", upper.display()),
            format!("lowerdir={}", empty.display()),
                format!("workdir={}", work.display()),
    ];

    let mut mounts = vec![
        ContainerMount {
            _type: Some("bind".to_string()),
            source: Some("/tmp/.X11-unix".to_string()),
            destination: Some("/tmp/.X11-unix".to_string()),
            options: Some(vec!["rbind".to_string(), "ro".to_string()]),
            uid_mappings: None,
            gid_mappings: None,
        },
        ContainerMount {
            _type: Some("bind".to_string()),
            source: Some(run_user.clone()),
            destination: Some(run_user.clone()),
            options: Some(vec!["rbind".to_string(), "rprivate".to_string()]),
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
            options: Some(vec!["rbind".to_string(), "rprivate".to_string()]),
            uid_mappings: None,
            gid_mappings: None,
        },
        ContainerMount {
            _type: Some("bind".to_string()),
            source: Some("/dev/snd".to_string()),
            destination: Some("/dev/snd".to_string()),
            options: Some(vec!["rbind".to_string(), "rprivate".to_string()]),
            uid_mappings: None,
            gid_mappings: None,
        },
        ContainerMount {
            _type: Some("bind".to_string()),
            source: Some("/dev/input".to_string()),
            destination: Some("/dev/input".to_string()),
            options: Some(vec!["rbind".to_string(), "rprivate".to_string()]),
            uid_mappings: None,
            gid_mappings: None,
        },
    ];

    let mut device_cgroup_rules = vec![
        LinuxDeviceCgroup { type_: Some("c".to_string()), major: Some(226), minor: Some(-1), access: Some("rwm".to_string()), allow: Some(true) }, // drm
        LinuxDeviceCgroup { type_: Some("c".to_string()), major: Some(116), minor: Some(-1), access: Some("rwm".to_string()), allow: Some(true) }, // snd
        LinuxDeviceCgroup { type_: Some("c".to_string()), major: Some(13),  minor: Some(-1), access: Some("rwm".to_string()), allow: Some(true) }, // input
    ];

    let mut envs = vec![
        ("PULSE_SERVER".to_string(), format!("unix:{}/pulse/native", run_user)),
        ("STEAMOS".to_string(), "1".to_string()),
        ("STEAM_RUNTIME".to_string(), "0".to_string()),
        ("XDG_RUNTIME_DIR".to_string(), run_user.clone()),
    ];

    if display == "x11" {
        envs.push(("DISPLAY".to_string(), env::var("DISPLAY").unwrap_or(":0".to_string())));
    }
    if display == "wayland" {
        envs.push(("WAYLAND_DISPLAY".to_string(), env::var("WAYLAND_DISPLAY").unwrap_or("wayland-0".to_string())));
    }

    if is_nvidia {
        envs.push(("NVIDIA_VISIBLE_DEVICES".to_string(), "all".to_string()));
        envs.push(("NVIDIA_DRIVER_CAPABILITIES".to_string(), "all".to_string()));

        for dev in &["/dev/nvidia0", "/dev/nvidiactl", "/dev/nvidia-modeset", "/dev/nvidia-uvm", "/dev/nvidia-uvm-tools"] {
            if Path::new(dev).exists() {
                mounts.push(ContainerMount {
                    _type: Some("bind".to_string()),
                            source: Some(dev.to_string()),
                            destination: Some(dev.to_string()),
                            options: Some(vec!["rbind".to_string(), "rprivate".to_string()]),
                            uid_mappings: None,
                            gid_mappings: None,
                });
            }
        }

        device_cgroup_rules.push(LinuxDeviceCgroup { type_: Some("c".to_string()), major: Some(195), minor: Some(-1), access: Some("rwm".to_string()), allow: Some(true) });
        device_cgroup_rules.push(LinuxDeviceCgroup { type_: Some("c".to_string()), major: Some(235), minor: Some(-1), access: Some("rwm".to_string()), allow: Some(true) });
    }

    let mut opts_builder = ContainerCreateOpts::builder()
    .image(IMAGE_NAME)
    .name(CONTAINER_NAME)
    .terminal(true)
    .user_namespace(Namespace { nsmode: Some("keep-id".to_string()), value: None })
    .ipc_namespace(Namespace { nsmode: Some("host".to_string()), value: None })
    .pid_namespace(Namespace { nsmode: Some("host".to_string()), value: None })
    .uts_namespace(Namespace { nsmode: Some("host".to_string()), value: None })
    .net_namespace(Namespace { nsmode: Some("host".to_string()), value: None })
    .mounts(mounts)
    .add_capabilities(vec!["SYS_NICE".to_string(), "IPC_LOCK".to_string()])
    .drop_capabilities(vec!["ALL".to_string()])
    .selinux_opts(vec!["disable".to_string()])
    .no_new_privilages(true)
    .privileged(false)
    .env(envs)
    .resource_limits(LinuxResources {
        cpu: Some(LinuxCpu { quota: Some(90000), period: None, realtime_period: None, realtime_runtime: None, shares: None, cpus: None, mems: None }),
                     memory: Some(LinuxMemory { limit: Some(17_179_869_184), reservation: None, swap: None, kernel: None, kernel_tcp: None, swappiness: None, disable_oom_killer: None, use_hierarchy: None }),
                     pids: Some(LinuxPids { limit: Some(4096) }),
                     block_io: Some(LinuxBlockIo { weight: Some(1000), leaf_weight: None, weight_device: None, throttle_read_bps_device: None, throttle_read_iops_device: None, throttle_write_bps_device: None, throttle_write_iops_device: None }),
                     devices: Some(device_cgroup_rules),
                     hugepage_limits: None,
                     network: None,
                     rdma: None,
                     unified: None,
    });

    if is_nvidia {
        opts_builder = opts_builder.oci_runtime(Some("nvidia".to_string()));
    }

    let opts = opts_builder.build();

    let container = podman.containers().get(CONTAINER_NAME);
    if container.inspect().await.is_ok() {
        info!("Kontener już istnieje – pomijamy tworzenie.");
        return Ok(());
    }

    info!("Tworzenie bezpiecznego kontenera Steam...");
    podman.containers().create(&opts).await?;
    info!("Kontener {} utworzony!", CONTAINER_NAME);

    // Pierwsze uruchomienie – instalacja
    let containers_api = podman.containers();
    let container = containers_api.get(CONTAINER_NAME);
    container.start(None).await?;

    let install_cmd = format!(
        r#"dnf install -y steam gamescope vulkan-tools mesa-vulkan-drivers libva-vdpau-driver pipewire-pulseaudio gamemode &&
        groupadd -g {} steamgroup || true &&
        useradd -m -u {} -g {} steam || true &&
        mkdir -p /home/steam/.steam &&
        chown -R steam:steamgroup /home/steam &&
        echo "Kontener Steam gotowy!""#,
        gid, uid, gid
    );

    let exec_opts = ExecCreateOpts::builder()
    .command(vec!["/bin/bash".to_string(), "-c".to_string(), install_cmd])
    .attach_stdout(true)
    .attach_stderr(true)
    .tty(false)
    .user(UserOpt::User("root".to_string()))
    .build();

    let exec = container.create_exec(&exec_opts).await?;

    let start_opts = ExecStartOpts::builder().tty(false).build();
    let output = exec.start(&start_opts).await?;

    if let Some(mut stream) = output {
        while let Some(result) = stream.next().await {
            let chunk = result?;
            if let TtyChunk::StdOut(bytes) | TtyChunk::StdErr(bytes) = chunk {
                print!("{}", String::from_utf8_lossy(&bytes));
            }
        }
    }

    container.stop(&ContainerStopOpts::builder().build()).await?;
    Ok(())
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    env_logger::Builder::new()
    .filter(None, LevelFilter::Info)
    .init();

    if getuid().is_root() {
        bail!("NIE uruchamiaj z sudo! Ten skrypt działa TYLKO w trybie rootless Podman.");
    }

    let cli = Cli::parse();
    let podman = get_podman()?;

    match cli.command {
        Commands::Create => create_container(&podman).await?,
        Commands::Run { session } => {
            create_container(&podman).await?;
            let containers_api = podman.containers();
            let container = containers_api.get(CONTAINER_NAME);

            let session_cmd = match session.as_deref() {
                Some("gamescope-session-steam") | Some("deck") => {
                    "su - steam -c 'gamescope -e -- steam -gamepadui'".to_string()
                }
                _ => "su - steam -c 'steam -silent || steam'".to_string(),
            };

            info!("Uruchamianie: {}", session_cmd);
            container.start(None).await?;

            let exec_opts = ExecCreateOpts::builder()
            .command(vec!["/bin/bash".to_string(), "-c".to_string(), session_cmd])
            .attach_stdout(true)
            .attach_stderr(true)
            .attach_stdin(true)
            .tty(true)
            .user(UserOpt::User("steam".to_string()))
            .build();

            let exec = container.create_exec(&exec_opts).await?;

            let start_opts = ExecStartOpts::builder().tty(true).build();
            let output = exec.start(&start_opts).await?;

            if let Some(mut stream) = output {
                while let Some(result) = stream.next().await {
                    let chunk = result?;
                    if let TtyChunk::StdOut(bytes) | TtyChunk::StdErr(bytes) = chunk {
                        print!("{}", String::from_utf8_lossy(&bytes));
                    }
                }
            }
        }
        Commands::Update => {
            info!("Aktualizacja obrazu Fedora...");
            let pull_opts = PullOpts::builder().reference(IMAGE_NAME).build();
            let images_api = podman.images();
            let mut stream = images_api.pull(&pull_opts);
            while let Some(result) = stream.next().await {
                let _ = result?;
            }
            info!("Obraz zaktualizowany. Uruchom `hackerosteam remove && hackerosteam create` aby zainstalować nowe pakiety.");
        }
        Commands::Kill => {
            let containers_api = podman.containers();
            let container = containers_api.get(CONTAINER_NAME);
            container.kill().await?;
            info!("Steam zatrzymany.");
        }
        Commands::Restart => {
            let containers_api = podman.containers();
            let container = containers_api.get(CONTAINER_NAME);
            container.restart().await?;
            warn!("Kontener zrestartowany – dane w overlayfs zachowane!");
        }
        Commands::Remove => {
            let containers_api = podman.containers();
            let container = containers_api.get(CONTAINER_NAME);
            let _ = container.stop(&ContainerStopOpts::builder().build()).await;
            container.delete(&ContainerDeleteOpts::builder().force(true).build()).await?;
            info!("Kontener usunięty.");
        }
        Commands::Status => {
            let containers_api = podman.containers();
            let container = containers_api.get(CONTAINER_NAME);
            match container.inspect().await {
                Ok(info) => {
                    if let Some(state) = info.state {
                        println!("Status: {} | PID: {}", state.status.unwrap_or_default(), state.pid.unwrap_or(0));
                    } else {
                        println!("Kontener istnieje, ale brak informacji o stanie.");
                    }
                }
                Err(_) => println!("Kontener nie istnieje."),
            }
        }
    }
    Ok(())
}
