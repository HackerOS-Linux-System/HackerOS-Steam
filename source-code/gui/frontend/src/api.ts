export type ContainerStatus = 'checking' | 'running' | 'stopped' | 'missing';

export interface SteamState {
  log: string;
  status: ContainerStatus;
  busy: boolean;
}

export interface CommandResult { ok: boolean }

interface Commands {
  get_state:       { args: undefined;              result: SteamState };
  cmd_run:         { args: undefined;              result: CommandResult };
  cmd_run_gamepad: { args: undefined;              result: CommandResult };
  cmd_run_deck:    { args: undefined;              result: CommandResult };
  cmd_create:      { args: undefined;              result: CommandResult };
  cmd_setup:       { args: undefined;              result: CommandResult };
  cmd_update:      { args: undefined;              result: CommandResult };
  cmd_stop:        { args: undefined;              result: CommandResult };
  cmd_remove:      { args: undefined;              result: CommandResult };
  cmd_export:      { args: undefined;              result: CommandResult };
  cmd_logs:        { args: undefined;              result: CommandResult };
  cmd_status:      { args: undefined;              result: CommandResult };
  cmd_clear:       { args: undefined;              result: CommandResult };
  cmd_install:     { args: { pkgs: string };       result: CommandResult };
  cmd_shell:       { args: undefined;              result: CommandResult };
}

export type CommandName = keyof Commands;
/** Commands that take no arguments — what the sidebar buttons call. */
export type SimpleCommand = {
  [K in CommandName]: Commands[K]['args'] extends undefined ? K : never;
}[CommandName];

export function call<K extends CommandName>(
  cmd: K,
  ...args: Commands[K]['args'] extends undefined ? [] : [Commands[K]['args']]
): Promise<Commands[K]['result']> {
  return silver.invoke(cmd, args[0] as Record<string, unknown> | undefined);
}

/** Event pushed by `sync()` in main.h# (`app::emit`) whenever log / status / busy change. */
export const STATE_EVENT = 'steam://state';
