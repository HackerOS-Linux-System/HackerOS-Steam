import { CONTAINER_IMAGE, CONTAINER_NAME, store } from '../store';

export function StatusBar() {
  return (
    <div class="status-bar">
      <span class="status-container-name">{CONTAINER_NAME}</span>
      <span class="status-sep">·</span>
      <span class={`status-dot dot-${store.status()}`}>●</span>
      <span class="status-text">{store.status()}</span>
      <div class="status-spacer" />
      <span class="status-image">{CONTAINER_IMAGE}</span>
    </div>
  );
}
