import { batch, createSignal, createRoot } from 'solid-js';
import { call, STATE_EVENT, SimpleCommand, SteamState, ContainerStatus } from './api';

export const APP_VERSION = 'v2.3.0';
export const CONTAINER_NAME = 'HackerOS-Steam';
export const CONTAINER_IMAGE = 'docker.io/archlinux:latest';

export const INITIAL_LOG =
  '  HackerOS Steam GUI - ready.\n  Use the sidebar to manage your container.\n';

/** Human label for each container state (the status bar never shows the raw word). */
export const STATUS_LABEL: Record<ContainerStatus, string> = {
  checking: 'Checking...',
  running: 'Running',
  stopped: 'Stopped',
  missing: 'Not created',
  error: 'Unavailable',
};

// Module-level signals live in their own root so they are never disposed with a component.
export const store = createRoot(() => {
  const [log, setLog] = createSignal(INITIAL_LOG);
  const [status, setStatus] = createSignal<ContainerStatus>('checking');
  const [backendBusy, setBackendBusy] = createSignal(false);
  const [cli, setCli] = createSignal(true);
  // true from the click until its `invoke` promise settles (covers the gap before the first push)
  const [pending, setPending] = createSignal(0);
  const [pkgs, setPkgs] = createSignal('');
  const busy = () => backendBusy() || pending() > 0;
  return { log, status, cli, busy, pkgs, setPkgs, setLog, setStatus, setCli, setBackendBusy, setPending };
});

let lastEventAt = 0;

export function applyState(s: SteamState): void {
  lastEventAt = Date.now();
  batch(() => {
    store.setLog(s.log);
    store.setStatus(s.status);
    store.setBackendBusy(s.busy);
    store.setCli(s.cli !== false);
  });
}

function logError(what: string, e: unknown): void {
  store.setLog(l => l + `\n  [x]  ${what}: ${String(e)}\n`);
}

/** Runs a no-argument back-end command; the log/status come back through the pushed state. */
export async function run(cmd: SimpleCommand): Promise<void> {
  store.setPending(n => n + 1);
  try {
    await call(cmd);
  } catch (e) {
    logError(cmd, e);
  } finally {
    store.setPending(n => n - 1);
  }
}

export async function install(): Promise<void> {
  const pkgs = store.pkgs().trim();
  store.setPending(n => n + 1);
  try {
    await call('cmd_install', { pkgs });          // an empty value makes H# show the warning dialog
  } catch (e) {
    logError('cmd_install', e);
  } finally {
    store.setPending(n => n - 1);
  }
}

/**
 * Subscribes to pushed state and pulls the first snapshot. Returns an unsubscribe function.
 *
 * The back-end pushes a snapshot only when something CHANGED, so one that is emitted before the
 * page has registered its listener is lost for good (that is how the status bar could stay on
 * "checking" forever). Hence a heartbeat: whenever no push has arrived for 3 s we pull
 * `get_state` ourselves.
 */
export function connect(): () => void {
  const off = silver.listen<SteamState>(STATE_EVENT, applyState);
  const pull = () => { call('get_state').then(applyState).catch(() => { /* retried by the heartbeat */ }); };
  pull();
  const timer = setInterval(() => { if (Date.now() - lastEventAt > 3000) pull(); }, 1500);
  return () => { off(); clearInterval(timer); };
}
