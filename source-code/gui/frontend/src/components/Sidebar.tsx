import { For } from 'solid-js';
import type { SimpleCommand } from '../api';
import { APP_VERSION, install, run, store } from '../store';
import { Icon, IconName } from '../icons';

type Variant = 'primary' | 'secondary' | 'warning' | 'danger' | 'ghost';
interface Action { cmd: SimpleCommand; label: string; icon: IconName; variant: Variant }
interface Section { label: string; actions: Action[] }

const SECTIONS: Section[] = [
  { label: 'STEAM', actions: [
    { cmd: 'cmd_run',         icon: 'play',    label: 'Launch Steam',    variant: 'primary' },
    { cmd: 'cmd_run_gamepad', icon: 'monitor', label: 'Big Picture',     variant: 'secondary' },
    { cmd: 'cmd_run_deck',    icon: 'deck',    label: 'Steam Deck Mode', variant: 'secondary' },
  ] },
  { label: 'CONTAINER', actions: [
    { cmd: 'cmd_create', icon: 'plus',   label: 'Create',         variant: 'secondary' },
    { cmd: 'cmd_setup',  icon: 'gear',   label: 'Setup / Repair', variant: 'secondary' },
    { cmd: 'cmd_update', icon: 'update', label: 'Update',         variant: 'secondary' },
    { cmd: 'cmd_stop',   icon: 'stop',   label: 'Stop',           variant: 'warning' },
    { cmd: 'cmd_remove', icon: 'trash',  label: 'Remove',         variant: 'danger' },
  ] },
];

const TOOLS: Action[] = [
  { cmd: 'cmd_export', icon: 'export',   label: 'Export to Desktop', variant: 'ghost' },
  { cmd: 'cmd_shell',  icon: 'terminal', label: 'Open Shell',        variant: 'ghost' },
  { cmd: 'cmd_doctor', icon: 'pulse',    label: 'Diagnostics',       variant: 'ghost' },
  { cmd: 'cmd_list',   icon: 'list',     label: 'All Containers',    variant: 'ghost' },
];

const LOG_ACTIONS: Action[] = [
  { cmd: 'cmd_logs',   icon: 'logs',    label: 'View Logs',      variant: 'ghost' },
  { cmd: 'cmd_status', icon: 'refresh', label: 'Refresh Status', variant: 'ghost' },
  { cmd: 'cmd_clear',  icon: 'clear',   label: 'Clear Log',      variant: 'ghost' },
];

function ActionButton(props: { action: Action }) {
  return (
    <button type="button" class={`action-btn btn-${props.action.variant}`}
            on:click={() => void run(props.action.cmd)}>
      <Icon name={props.action.icon} />
      <span class="btn-label">{props.action.label}</span>
    </button>
  );
}

function Actions(props: { items: Action[] }) {
  return <For each={props.items}>{(a) => <ActionButton action={a} />}</For>;
}

export function Sidebar() {
  return (
    <div class="sidebar">
      <For each={SECTIONS}>{(s, i) => (
        <>
          {i() > 0 && <div class="section-sep" />}
          <div class="section-label">{s.label}</div>
          <Actions items={s.actions} />
        </>
      )}</For>

      <div class="section-sep" />
      <div class="section-label">TOOLS</div>
      <Actions items={TOOLS} />

      <form class="install-row" on:submit={(e) => { e.preventDefault(); void install(); }}>
        <input class="pkgs-input" placeholder="mangohud lib32-mangohud ..."
               value={store.pkgs()}
               on:input={(e) => store.setPkgs((e.currentTarget as HTMLInputElement).value)} />
        <button type="submit" class="action-btn btn-ghost install-btn">
          <Icon name="download" />
          <span class="btn-label">Install</span>
        </button>
      </form>

      <Actions items={LOG_ACTIONS} />

      <div class="sidebar-spacer" />
      <div class="version-label">{APP_VERSION}</div>
    </div>
  );
}
