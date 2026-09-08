import type { ReactNode } from 'react';
import { Spinner, EmptyState } from './ui';

export interface Column<T> {
  key: string;
  header: string;
  render: (row: T) => ReactNode;
  align?: 'left' | 'right' | 'center';
  width?: string;
  mono?: boolean;
}

export function DataTable<T>({
  columns,
  rows,
  loading,
  keyOf,
  empty,
  onRowClick,
}: {
  columns: Column<T>[];
  rows: T[];
  loading?: boolean;
  keyOf: (row: T) => string;
  empty?: { title: string; subtitle?: string; icon?: string; action?: ReactNode };
  onRowClick?: (row: T) => void;
}) {
  return (
    <div className="thin-sb overflow-x-auto rounded-card border border-line bg-white shadow-card">
      <table className="w-full border-collapse text-[13px]">
        <thead>
          <tr className="border-b border-line bg-[#FAFAFA]">
            {columns.map((c) => (
              <th
                key={c.key}
                style={{ width: c.width }}
                className={`px-4 py-2.5 text-[11px] font-bold uppercase tracking-wide text-muted ${
                  c.align === 'right' ? 'text-right' : c.align === 'center' ? 'text-center' : 'text-left'
                }`}
              >
                {c.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {loading ? (
            <tr>
              <td colSpan={columns.length} className="py-16 text-center text-muted">
                <Spinner />
              </td>
            </tr>
          ) : rows.length === 0 ? (
            <tr>
              <td colSpan={columns.length}>
                <EmptyState
                  title={empty?.title ?? 'Belum ada data'}
                  subtitle={empty?.subtitle}
                  icon={empty?.icon}
                  action={empty?.action}
                />
              </td>
            </tr>
          ) : (
            rows.map((row, i) => (
              <tr
                key={keyOf(row)}
                onClick={() => onRowClick?.(row)}
                className={`border-b border-line last:border-0 ${i % 2 ? 'bg-[#FAFAFA]' : 'bg-white'} ${
                  onRowClick ? 'cursor-pointer hover:bg-brand-light' : 'hover:bg-brand-light/40'
                }`}
              >
                {columns.map((c) => (
                  <td
                    key={c.key}
                    className={`px-4 py-2.5 align-middle ${
                      c.align === 'right' ? 'text-right' : c.align === 'center' ? 'text-center' : 'text-left'
                    } ${c.mono ? 'num' : ''}`}
                  >
                    {c.render(row)}
                  </td>
                ))}
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  );
}
