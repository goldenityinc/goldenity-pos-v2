import { Component, type ErrorInfo, type ReactNode } from 'react';

/**
 * Jaring pengaman terakhir supaya error render (mis. quirk Safari lama) TIDAK
 * bikin layar putih total — customer masih lihat pesan + tombol muat ulang.
 */
export class ErrorBoundary extends Component<{ children: ReactNode }, { err: Error | null }> {
  state = { err: null as Error | null };

  static getDerivedStateFromError(err: Error) {
    return { err };
  }

  componentDidCatch(err: Error, info: ErrorInfo) {
    // eslint-disable-next-line no-console
    console.error('[weborder] render error', err, info.componentStack);
  }

  render() {
    if (!this.state.err) return this.props.children;
    return (
      <div className="flex min-h-screen flex-col items-center justify-center bg-bg px-6 text-center">
        <div className="mb-3 flex h-14 w-14 items-center justify-center rounded-2xl bg-errl text-2xl">⚠️</div>
        <h1 className="text-lg font-extrabold text-ink">Terjadi kendala</h1>
        <p className="mt-1 max-w-xs text-sm text-muted">
          Halaman gagal dimuat. Coba muat ulang, atau scan ulang QR di meja Anda.
        </p>
        <button
          onClick={() => window.location.reload()}
          className="mt-5 rounded-xl bg-brand px-6 py-3 text-sm font-extrabold text-white"
        >
          Muat Ulang
        </button>
      </div>
    );
  }
}
