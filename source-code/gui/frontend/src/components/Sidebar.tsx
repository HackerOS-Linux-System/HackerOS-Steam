import { For } from 'solid-js';
import type { SimpleCommand } from '../api';
import { APP_VERSION, install, run, store } from '../store';

type Variant = 'primary' | 'secondary' | 'warning' | 'danger' | 'ghost';
interface Action { cmd: SimpleCommand; label: string; variant: Variant }
interface Section { label: string; actions: Action[] }

const SECTIONS: Section[] = [
  { label: 'STEAM', actions: [
    { cmd: 'cmd_run',         label: '▶ Launch Steam',      variant: 'primary' },
    { cmd: 'cmd_run_gamepad', label: '⬛ Big Picture',       variant: 'secondary' },
    { cmd: 'cmd_run_deck',    label: '⬛ Steam Deck Mode',   variant: 'secondary' },
  ] },
  { label: 'CONTAINER', actions: [
    { cmd: 'cmd_create', label: '+ Create',        variant: 'secondary' },
    { cmd: 'cmd_setup',  label: '⚙ Setup / Repair', variant: 'secondary' },
    { cmd: 'cmd_update', label: '↑ Update',        variant: 'secondary' },
    { cmd: 'cmd_stop',   label: '■ Stop',          variant: 'warning' },
    { cmd: 'cmd_remove', label: '✕ Remove',        variant: 'danger' },
  ] },
];

const TOOLS: Action[] = [
  { cmd: 'cmd_export', label: '↗ Export to Desktop', variant: 'ghost' },
  { cmd: 'cmd_shell',  label: '⬜ Open Shell',        variant: 'ghost' },
];

const LOG_ACTIONS: Action[] = [
  { cmd: 'cmd_logs',   label: '≡ View Logs',       variant: 'ghost' },
  { cmd: 'cmd_status', label: '⟳ Refresh Status',  variant: 'ghost' },
  { cmd: 'cmd_clear',  label: '⌫ Clear Log',       variant: 'ghost' },
];

function ActionButton(props: { action: Action }) {
  return (
    <button type="button" class={`action-btn btn-${props.action.variant}`}
            on:click={() => void run(props.action.cmd)}>
      <span>{props.action.label}</span>
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
        <input class="pkgs-input" placeholder="mangohud lib32-mangohud …"
               value={store.pkgs()}
               on:input={(e) => store.setPkgs((e.currentTarget as HTMLInputElement).value)} />
        <button type="submit" class="action-btn btn-ghost install-btn"><span>+ Install</span></button>
      </form>

      <Actions items={LOG_ACTIONS} />

      <div class="sidebar-spacer" />
      <div class="version-label">{APP_VERSION}</div>
    </div>
  );
}
