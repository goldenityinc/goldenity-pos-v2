import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { createBrowserRouter, Navigate, RouterProvider } from 'react-router-dom';
import './index.css';
import { useStore } from './store';
import SessionGate from './pages/SessionGate';
import Menu from './pages/Menu';
import Checkout from './pages/Checkout';
import Orders from './pages/Orders';

function RequireSession({ children }: { children: React.ReactNode }) {
  const session = useStore((s) => s.session);
  if (!session) return <Navigate to="/" replace />;
  return <>{children}</>;
}

const router = createBrowserRouter([
  { path: '/', element: <SessionGate /> },
  { path: '/t/:qrToken', element: <SessionGate /> },
  { path: '/:slug/:branchId/t/:qrToken', element: <SessionGate /> },
  {
    path: '/menu',
    element: (
      <RequireSession>
        <Menu />
      </RequireSession>
    ),
  },
  {
    path: '/checkout',
    element: (
      <RequireSession>
        <Checkout />
      </RequireSession>
    ),
  },
  {
    path: '/orders',
    element: (
      <RequireSession>
        <Orders />
      </RequireSession>
    ),
  },
  { path: '*', element: <Navigate to="/" replace /> },
]);

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <div className="app-shell">
      <RouterProvider router={router} />
    </div>
  </StrictMode>,
);
