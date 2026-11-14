import { render } from 'solid-js/web';
import { onCleanup, onMount } from 'solid-js';
import { connect } from './store';
import { Header } from './components/Header';
import { Sidebar } from './components/Sidebar';
import { TerminalPanel } from './components/TerminalPanel';
import { StatusBar } from './components/StatusBar';

function App() {
  onMount(() => { const off = connect(); onCleanup(off); });
  return (
    <div class="app-shell">
      <Header />
      <div class="content">
        <Sidebar />
        <div class="sidebar-sep-v" />
        <TerminalPanel />
      </div>
      <StatusBar />
    </div>
  );
}

render(() => <App />, document.getElementById('root')!);
