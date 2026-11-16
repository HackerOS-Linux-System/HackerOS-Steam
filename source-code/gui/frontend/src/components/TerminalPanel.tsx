import { createEffect } from 'solid-js';
import { store } from '../store';

export function TerminalPanel() {
  let body!: HTMLPreElement;
  // keep the newest output in view
  createEffect(() => {
    store.log();
    queueMicrotask(() => { body.scrollTop = body.scrollHeight; });
  });
  return (
    <div class="terminal-panel">
      <div class="terminal-header">
        <span class="wm-dot dot-red" />
        <span class="wm-dot dot-yellow" />
        <span class="wm-dot dot-green" />
        <span class="terminal-title">Output Log</span>
      </div>
      <pre class="terminal-body" ref={body}>{store.log()}</pre>
    </div>
  );
}
