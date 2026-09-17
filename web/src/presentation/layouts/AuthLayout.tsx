import { Outlet } from 'react-router-dom';

export function AuthLayout() {
  return (
    <div className="min-h-screen w-full overflow-x-hidden lg:h-screen lg:overflow-hidden">
      <Outlet />
    </div>
  );
}