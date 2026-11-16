import type { JSX } from 'solid-js';

/**
 * Inline SVG icons.
 *
 * Why not Unicode symbols (play/gear/arrow glyphs, bullets ...)? silver draws all text with ONE
 * system font and has no glyph fallback: whatever that font lacks shows up as an empty "tofu"
 * box (exactly what the old sidebar looked like). SVG shapes are drawn by the engine itself,
 * so they always render, and `currentColor` follows the text colour of the button.
 *
 * Every icon is one fully static <svg> (a single template, no spreads / dynamic children) and is
 * sized from CSS (`.icon`, `.header-logo .icon`, ...), because that is the least exotic thing
 * for silver's DOM mirror to handle.
 */
export type IconName = 'play' | 'stop' | 'monitor' | 'deck' | 'plus' | 'gear' | 'update' | 'trash' | 'export' | 'terminal' | 'download' | 'logs' | 'refresh' | 'clear' | 'pulse' | 'list' | 'logo' | 'spinner';

const ICONS: Record<IconName, () => JSX.Element> = {
  play: () => (
    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="6,4 20,12 6,20" fill="currentColor" stroke="currentColor" stroke-width="1" /></svg>
  ),
  stop: () => (
    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="6" y="6" width="12" height="12" rx="1" fill="currentColor" stroke="none" /></svg>
  ),
  monitor: () => (
    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="12" rx="2" /><line x1="8" y1="20" x2="16" y2="20" /><line x1="12" y1="16" x2="12" y2="20" /></svg>
  ),
  deck: () => (
    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="7" width="20" height="10" rx="4" /><line x1="7" y1="10.5" x2="7" y2="13.5" /><line x1="5.5" y1="12" x2="8.5" y2="12" /><line x1="16" y1="12" x2="18" y2="12" /></svg>
  ),
  plus: () => (
    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" /></svg>
  ),
  gear: () => (
    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3" /><line x1="12" y1="3" x2="12" y2="6" /><line x1="12" y1="18" x2="12" y2="21" /><line x1="3" y1="12" x2="6" y2="12" /><line x1="18" y1="12" x2="21" y2="12" /><line x1="5.6" y1="5.6" x2="7.7" y2="7.7" /><line x1="16.3" y1="16.3" x2="18.4" y2="18.4" /><line x1="5.6" y1="18.4" x2="7.7" y2="16.3" /><line x1="16.3" y1="7.7" x2="18.4" y2="5.6" /></svg>
  ),
  update: () => (
    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="19" x2="12" y2="5" /><polyline points="6,11 12,5 18,11" /></svg>
  ),
  trash: () => (
    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="4" y1="7" x2="20" y2="7" /><polyline points="6,7 7,20 17,20 18,7" /><polyline points="9,7 9,4 15,4 15,7" /></svg>
  ),
  export: () => (
    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="7" y1="17" x2="17" y2="7" /><polyline points="8,7 17,7 17,16" /></svg>
  ),
  terminal: () => (
    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="5,8 10,12 5,16" /><line x1="12" y1="17" x2="19" y2="17" /></svg>
  ),
  download: () => (
    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="4" x2="12" y2="15" /><polyline points="6,10 12,16 18,10" /><line x1="5" y1="20" x2="19" y2="20" /></svg>
  ),
  logs: () => (
    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="7" x2="19" y2="7" /><line x1="5" y1="12" x2="19" y2="12" /><line x1="5" y1="17" x2="14" y2="17" /></svg>
  ),
  refresh: () => (
    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 12a8 8 0 1 1-2.5-5.8" /><polyline points="20,4 20,9 15,9" /></svg>
  ),
  clear: () => (
    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9" /><line x1="9" y1="9" x2="15" y2="15" /><line x1="15" y1="9" x2="9" y2="15" /></svg>
  ),
  pulse: () => (
    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3,12 8,12 10,6 14,18 16,12 21,12" /></svg>
  ),
  list: () => (
    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="9" y1="7" x2="20" y2="7" /><line x1="9" y1="12" x2="20" y2="12" /><line x1="9" y1="17" x2="20" y2="17" /><circle cx="4.5" cy="7" r="1" fill="currentColor" /><circle cx="4.5" cy="12" r="1" fill="currentColor" /><circle cx="4.5" cy="17" r="1" fill="currentColor" /></svg>
  ),
  logo: () => (
    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10" /><polygon points="10,8 16,12 10,16" fill="currentColor" stroke="currentColor" stroke-width="1" /></svg>
  ),
  spinner: () => (
    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3a9 9 0 0 1 9 9" /></svg>
  ),
};

export function Icon(props: { name: IconName }): JSX.Element {
  return ICONS[props.name]();
}
