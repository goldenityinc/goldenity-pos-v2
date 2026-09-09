import { StrictMode, useEffect, type ReactNode } from 'react';
import { createRoot } from 'react-dom/client';
import { createBrowserRouter, Navigate, RouterProvider } from 'react-router-dom';
import './index.css';
import { useAuth } from './lib/auth';
import { Spinner, ToastHost } from './components/ui';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import SalesReportPage from './pages/SalesReportPage';
import InventoryPage from './pages/InventoryPage';
import CategoriesPage from './pages/CategoriesPage';
import UsersPage from './pages/UsersPage';
import RolesPage from './pages/RolesPage';
import SubscriptionPage from './pages/SubscriptionPage';
import BranchesPage from './pages/BranchesPage';

function Gate({ children }: { children: ReactNode }) {
  const { me, loading, bootstrap } = useAuth();
  useEffect(() => {
    void bootstrap();
  }, [bootstrap]);
  if (loading)
    return (
      <div className="flex min-h-screen items-center justify-center text-brand">
        <Spinner size={28} />
      </div>
    );
  if (!me) return <Navigate to="/login" replace />;
  return <>{children}</>;
}

const router = createBrowserRouter([
  { path: '/login', element: <LoginPage /> },
  { path: '/', element: <Gate><DashboardPage /></Gate> },
  { path: '/penjualan', element: <Gate><SalesReportPage /></Gate> },
  { path: '/inventaris', element: <Gate><InventoryPage /></Gate> },
  { path: '/kategori', element: <Gate><CategoriesPage /></Gate> },
  { path: '/karyawan', element: <Gate><UsersPage /></Gate> },
  { path: '/role', element: <Gate><RolesPage /></Gate> },
  { path: '/langganan', element: <Gate><SubscriptionPage /></Gate> },
  { path: '/cabang', element: <Gate><BranchesPage /></Gate> },
  // Redirect rute lama.
  { path: '/pengaturan', element: <Navigate to="/cabang" replace /> },
  { path: '*', element: <Navigate to="/" replace /> },
]);

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ToastHost>
      <RouterProvider router={router} />
    </ToastHost>
  </StrictMode>,
);
