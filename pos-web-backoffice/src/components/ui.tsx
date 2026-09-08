import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
  type ButtonHTMLAttributes,
  type InputHTMLAttributes,
  type ReactNode,
  type SelectHTMLAttributes,
  type TextareaHTMLAttributes,
} from 'react';

// ─────────────────────────── Button ───────────────────────────

type BtnVariant = 'primary' | 'outline' | 'danger' | 'ghost' | 'subtle';
interface BtnProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: BtnVariant;
  loading?: boolean;
  size?: 'sm' | 'md';
}
export function Button({ variant = 'primary', loading, size = 'md', className = '', children, disabled, ...rest }: BtnProps) {
  const base =
    'inline-flex items-center justify-center gap-2 font-semibold rounded-md transition select-none disabled:opacity-50 disabled:cursor-not-allowed';
  const sz = size === 'sm' ? 'h-8 px-3 text-[13px]' : 'h-11 px-4 text-[14px]';
  const styles: Record<BtnVariant, string> = {
    primary: 'bg-brand text-white shadow-btn hover:bg-brand-hover',
    outline: 'bg-white border border-line2 text-ink2 hover:bg-surface2',
    danger: 'bg-white border border-err text-err hover:bg-errl',
    ghost: 'text-ink2 hover:bg-surface2',
    subtle: 'bg-brand-light text-brand hover:bg-brand-light/70',
  };
  return (
    <button className={`${base} ${sz} ${styles[variant]} ${className}`} disabled={disabled || loading} {...rest}>
      {loading && <Spinner size={14} />}
      {children}
    </button>
  );
}

// ─────────────────────────── Fields ───────────────────────────

function FieldWrap({ label, error, hint, children }: { label?: string; error?: string; hint?: string; children: ReactNode }) {
  return (
    <label className="block">
      {label && <span className="mb-1 block text-[12px] font-semibold text-ink2">{label}</span>}
      {children}
      {error ? (
        <span className="mt-1 block text-[12px] text-err">{error}</span>
      ) : hint ? (
        <span className="mt-1 block text-[12px] text-muted">{hint}</span>
      ) : null}
    </label>
  );
}

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
  hint?: string;
  mono?: boolean;
}
export function Input({ label, error, hint, mono, className = '', ...rest }: InputProps) {
  return (
    <FieldWrap label={label} error={error} hint={hint}>
      <input
        className={`h-11 w-full rounded-md border ${error ? 'border-err' : 'border-line'} bg-white px-3 text-[14px] outline-none focus:border-brand ${
          mono ? 'num' : ''
        } ${className}`}
        {...rest}
      />
    </FieldWrap>
  );
}

interface SelectProps extends SelectHTMLAttributes<HTMLSelectElement> {
  label?: string;
  error?: string;
  hint?: string;
}
export function Select({ label, error, hint, className = '', children, ...rest }: SelectProps) {
  return (
    <FieldWrap label={label} error={error} hint={hint}>
      <select
        className={`h-11 w-full rounded-md border ${error ? 'border-err' : 'border-line'} bg-white px-3 text-[14px] outline-none focus:border-brand ${className}`}
        {...rest}
      >
        {children}
      </select>
    </FieldWrap>
  );
}

interface TextareaProps extends TextareaHTMLAttributes<HTMLTextAreaElement> {
  label?: string;
  error?: string;
  hint?: string;
}
export function Textarea({ label, error, hint, className = '', ...rest }: TextareaProps) {
  return (
    <FieldWrap label={label} error={error} hint={hint}>
      <textarea
        className={`w-full rounded-md border ${error ? 'border-err' : 'border-line'} bg-white px-3 py-2 text-[14px] outline-none focus:border-brand ${className}`}
        {...rest}
      />
    </FieldWrap>
  );
}

// ─────────────────────────── Badge ───────────────────────────

type Tone = 'ok' | 'warn' | 'err' | 'info' | 'neutral';
export function Badge({ tone = 'neutral', children }: { tone?: Tone; children: ReactNode }) {
  const map: Record<Tone, string> = {
    ok: 'bg-okl text-[#14532D]',
    warn: 'bg-warnl text-[#713F12]',
    err: 'bg-errl text-[#7F1D1D]',
    info: 'bg-infol text-[#1E3A8A]',
    neutral: 'bg-surface2 text-ink2',
  };
  return (
    <span className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-[11px] font-bold ${map[tone]}`}>
      {children}
    </span>
  );
}

// ─────────────────────────── Spinner ───────────────────────────

export function Spinner({ size = 18 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" className="animate-spin">
      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="3" fill="none" opacity="0.25" />
      <path d="M21 12a9 9 0 0 0-9-9" stroke="currentColor" strokeWidth="3" fill="none" strokeLinecap="round" />
    </svg>
  );
}

// ─────────────────────────── EmptyState ───────────────────────────

export function EmptyState({ title, subtitle, icon = '📭', action }: { title: string; subtitle?: string; icon?: string; action?: ReactNode }) {
  return (
    <div className="flex flex-col items-center justify-center py-14 text-center">
      <div className="flex h-24 w-24 items-center justify-center rounded-2xl bg-surface2 text-4xl">{icon}</div>
      <div className="mt-4 text-[14px] font-extrabold text-ink">{title}</div>
      {subtitle && <div className="mt-1 max-w-sm text-[13px] text-muted">{subtitle}</div>}
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
}

// ─────────────────────────── ErrorBanner ───────────────────────────

export function ErrorBanner({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className="flex items-center justify-between gap-3 rounded-md border-l-4 border-err bg-errl px-4 py-3 text-[13px] text-[#7F1D1D]">
      <span>{message}</span>
      {onRetry && (
        <button className="shrink-0 font-bold underline" onClick={onRetry}>
          Coba lagi
        </button>
      )}
    </div>
  );
}

// ─────────────────────────── Modal ───────────────────────────

export function Modal({
  open,
  onClose,
  title,
  children,
  size = 'md',
  footer,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  size?: 'sm' | 'md' | 'lg';
  footer?: ReactNode;
}) {
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);
  if (!open) return null;
  const w = { sm: 'max-w-[420px]', md: 'max-w-[640px]', lg: 'max-w-[880px]' }[size];
  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-[rgba(15,23,42,.55)] p-4 backdrop-blur-[2px]"
      onMouseDown={onClose}
    >
      <div
        className={`fade-in my-8 w-full ${w} rounded-modal bg-white shadow-modal`}
        onMouseDown={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between border-b border-line px-6 py-4">
          <h3 className="text-[16px] font-extrabold text-ink">{title}</h3>
          <button onClick={onClose} className="rounded p-1 text-muted hover:bg-surface2" aria-label="Tutup">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M18 6 6 18M6 6l12 12" />
            </svg>
          </button>
        </div>
        <div className="px-6 py-5">{children}</div>
        {footer && <div className="flex justify-end gap-2 border-t border-line px-6 py-4">{footer}</div>}
      </div>
    </div>
  );
}

// ─────────────────────────── Confirm ───────────────────────────

export function ConfirmDialog({
  open,
  onClose,
  onConfirm,
  title,
  message,
  confirmLabel = 'Ya, lanjutkan',
  danger,
  loading,
}: {
  open: boolean;
  onClose: () => void;
  onConfirm: () => void;
  title: string;
  message: string;
  confirmLabel?: string;
  danger?: boolean;
  loading?: boolean;
}) {
  return (
    <Modal
      open={open}
      onClose={onClose}
      title={title}
      size="sm"
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            Batal
          </Button>
          <Button variant={danger ? 'danger' : 'primary'} loading={loading} onClick={onConfirm}>
            {confirmLabel}
          </Button>
        </>
      }
    >
      <p className="text-[14px] text-ink2">{message}</p>
    </Modal>
  );
}

// ─────────────────────────── Tabs ───────────────────────────

export function Tabs({ tabs, active, onChange }: { tabs: { key: string; label: string; count?: number }[]; active: string; onChange: (k: string) => void }) {
  return (
    <div className="inline-flex rounded-lg bg-surface2 p-1">
      {tabs.map((t) => (
        <button
          key={t.key}
          onClick={() => onChange(t.key)}
          className={`rounded-md px-3.5 py-1.5 text-[13px] font-semibold transition ${
            active === t.key ? 'bg-white text-ink shadow-card' : 'text-muted hover:text-ink2'
          }`}
        >
          {t.label}
          {typeof t.count === 'number' && <span className="num ml-1.5 text-[12px] opacity-60">{t.count}</span>}
        </button>
      ))}
    </div>
  );
}

// ─────────────────────────── Toast ───────────────────────────

type Toast = { id: number; msg: string; tone: Tone };
const ToastCtx = createContext<{ push: (msg: string, tone?: Tone) => void }>({ push: () => {} });
export const useToast = () => useContext(ToastCtx);

export function ToastHost({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<Toast[]>([]);
  const idRef = useRef(0);
  const push = useCallback((msg: string, tone: Tone = 'info') => {
    const id = ++idRef.current;
    setItems((s) => [...s, { id, msg, tone }]);
    setTimeout(() => setItems((s) => s.filter((t) => t.id !== id)), 4000);
  }, []);
  const border: Record<Tone, string> = {
    ok: 'border-ok',
    warn: 'border-warn',
    err: 'border-err',
    info: 'border-brand',
    neutral: 'border-line2',
  };
  return (
    <ToastCtx.Provider value={{ push }}>
      {children}
      <div className="fixed right-4 top-4 z-[60] flex w-[340px] flex-col gap-2">
        {items.map((t) => (
          <div key={t.id} className={`fade-in rounded-md border-l-4 ${border[t.tone]} bg-white px-4 py-3 text-[13px] text-ink2 shadow-modal`}>
            {t.msg}
          </div>
        ))}
      </div>
    </ToastCtx.Provider>
  );
}
