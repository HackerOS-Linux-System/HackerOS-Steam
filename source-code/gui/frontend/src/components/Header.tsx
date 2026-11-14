import { store } from '../store';

export function Header() {
  return (
    <div class="app-header">
      <div class="title-box">
        <span class="header-logo">▶</span>
        <div class="title-col">
          <div class="app-title">HackerOS Steam</div>
          <div class="app-subtitle">Distrobox · Arch Linux · Container Manager</div>
        </div>
      </div>
      <span class="header-spinner" classList={{ spinning: store.busy() }}>◐</span>
    </div>
  );
}
