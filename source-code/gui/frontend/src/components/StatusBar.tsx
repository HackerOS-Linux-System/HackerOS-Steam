import { CONTAINER_IMAGE, CONTAINER_NAME, STATUS_LABEL, store } from '../store';

export function StatusBar() {
  return (
    <div class="status-bar">
      <span class="status-container-name">{CONTAINER_NAME}</span>
      <span class="status-sep">|</span>
      <span class={`status-dot dot-${store.status()}`} />
      <span class="status-text">{STATUS_LABEL[store.status()]}</span>
      {!store.cli() && <span class="status-warn">hackeros-steam CLI not found</span>}
      <div class="status-spacer" />
      <span class="status-image">{CONTAINER_IMAGE}</span>
    </div>
  );
}
