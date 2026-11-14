import { batch, createSignal, createRoot } from 'solid-js';
import { call, STATE_EVENT, SimpleCommand, SteamState, ContainerStatus } from './api';

export const APP_VERSION = 'v2.2.0';
export const CONTAINER_NAME = 'HackerOS-Steam';
export const CONTAINER_IMAGE = 'docker.io/archlinux:latest';

export const INITIAL_LOG =
  '  HackerOS Steam GUI — ready.\n  Use the sidebar to manage your container.\n';

// Module-level signals live in their own root so they are never disposed with a component.
export const store = createRoot(() => {
  const [log, setLog] = createSignal(INITIAL_LOG);
  const [status, setStatus] = createSignal<ContainerStatus>('checking');
  const [backendBusy, setBackendBusy] = createSignal(false);
  // true from the click until its `invoke` promise settles (covers the gap before the first push)
  const [pending, setPending] = createSignal(0);
  const [pkgs, setPkgs] = createSignal('');
  const busy = () => backendBusy() || pending() > 0;
  return { log, status, busy, pkgs, setPkgs, setLog, setStatus, setBackendBusy, setPending };
});

export function applyState(s: SteamState): void {
  batch(() => {
    store.setLog(s.log);
    store.setStatus(s.status);
    store.setBackendBusy(s.busy);
  });
}

/** Runs a no-argument back-end command; the log/status come back through the pushed state. */
export async function run(cmd: SimpleCommand): Promise<void> {
  store.setPending(n => n + 1);
  try {
    await call(cmd);
  } catch (e) {
    store.setLog(l => l + `\n  ✖  ${cmd}: ${String(e)}\n`);
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
    store.setLog(l => l + `\n  ✖  cmd_install: ${String(e)}\n`);
  } finally {
    store.setPending(n => n - 1);
  }
}

/** Subscribes to pushed state and pulls the first snapshot. Returns an unsubscribe function. */
export function connect(): () => void {
  const off = silver.listen<SteamState>(STATE_EVENT, applyState);
  call('get_state').then(applyState).catch(() => { /* push will catch up on the next tick */ });
  return off;
}
