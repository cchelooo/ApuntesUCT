import { createBrowserRouter } from 'react-router-dom';
import { MainLayout } from '../presentation/layouts/MainLayout';
import { AuthLayout } from '../presentation/layouts/AuthLayout';
import {
  HomePage,
  LoginPage,
  RegisterPage,
  ProfilePage,
  CatalogPage,
  SearchPage,
  LibraryPage,
  NotFoundPage,
} from '../presentation/pages';

export const router = createBrowserRouter([
  {
    path: '/',
    element: <MainLayout />,
    errorElement: <NotFoundPage />,
    children: [
      { index: true, element: <HomePage /> },
      { path: 'register', element: <RegisterPage /> },
      { path: 'profile', element: <ProfilePage /> },
      { path: 'catalog', element: <CatalogPage /> },
      { path: 'search', element: <SearchPage /> },
      { path: 'library', element: <LibraryPage /> },
      { path: '*', element: <NotFoundPage /> },
    ],
  },
  {
    path: '/login',
    element: <AuthLayout />,
    errorElement: <NotFoundPage />,
    children: [{ index: true, element: <LoginPage /> }],
  },
]);
