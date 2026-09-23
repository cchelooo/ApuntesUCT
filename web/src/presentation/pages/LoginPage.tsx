import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useMutation } from '@tanstack/react-query';
import { Button } from '../components/Button';
import { Input } from '../components/Input';
import { Alert } from '../components/Alert';

type LoginAlert = {
  variant: 'error' | 'success';
  message: string;
};

export function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loginAlert, setLoginAlert] = useState<LoginAlert | null>(null);

  const loginMutation = useMutation({
    mutationFn: async (credentials: Record<string, string>) => {
      let response: Response;

      try {
        response = await fetch(`${import.meta.env.VITE_API_URL}/auth/login`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(credentials),
        });
      } catch {
        throw new Error(
          'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo nuevamente.'
        );
      }

      if (response.status === 400) {
        throw new Error(
          'Los datos ingresados no son válidos. Revisa tu correo y contraseña.'
        );
      }

      if (response.status === 502) {
        throw new Error(
          'El servicio de autenticación no está disponible. Inténtalo nuevamente más tarde.'
        );
      }

      if (!response.ok) {
        throw new Error(
          'No fue posible iniciar sesión. Inténtalo nuevamente más tarde.'
        );
      }

      return response.json();
    },
    onSuccess: () => {
      setLoginAlert({
        variant: 'success',
        message: 'Inicio de sesión exitoso.',
      });
    },
    onError: (error) => {
      setLoginAlert({
        variant: 'error',
        message:
          error instanceof Error
            ? error.message
            : 'No fue posible iniciar sesión. Inténtalo nuevamente.',
      });
    },
  });

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault();
    setLoginAlert(null);

    if (!email.trim() || !password.trim()) {
      setLoginAlert({
        variant: 'error',
        message: 'Por favor, completa tu correo y contraseña.',
      });
      return;
    }

    loginMutation.mutate({ email, password });
  };

  return (
    <div className="min-h-screen w-full flex">
      {/* Panel Izquierdo (Oculto en móviles, visible en pantallas lg) */}
      <div className="hidden lg:flex lg:w-1/2 bg-slate-900 text-white p-12 flex-col justify-between relative overflow-hidden">
        {/* Fondo con degradado sutil */}
        <div className="absolute inset-0 bg-gradient-to-br from-blue-900/40 to-slate-900 z-0"></div>

        <div className="relative z-10">
          {/* Logo (Placeholder temporal) */}
          <div className="flex items-center gap-2 font-bold text-xl mb-16">
            <div className="w-8 h-8 bg-blue-600 rounded-md flex items-center justify-center">
              📄
            </div>
            ApuntesUCT
          </div>

          <h1 className="text-4xl font-bold mb-6 tracking-tight">
            Bienvenido de vuelta.
          </h1>
          <p className="text-slate-300 text-lg max-w-md leading-relaxed mb-12">
            El material que necesitas para tus pruebas, organizado por profesor
            y validado por cientos de estudiantes UCT.
          </p>

          {/* Tarjeta de testimonio */}
          <div className="bg-white/10 backdrop-blur-md border border-white/20 p-6 rounded-xl max-w-md shadow-xl">
            <p className="text-sm italic mb-4 leading-relaxed">
              "Encontré los apuntes del Prof. Caro en menos de un minuto. Pasé
              Hardware gracias a ApuntesUCT."
            </p>
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-blue-500 rounded-full flex items-center justify-center font-bold shadow-inner">
                FP
              </div>
              <div>
                <div className="font-semibold text-sm">Felipe Pereira</div>
                <div className="text-xs text-slate-400">
                  Ing. Civil Informática - 2do año
                </div>
              </div>
              <div className="ml-auto text-yellow-400 text-xs tracking-widest">
                ★★★★★
              </div>
            </div>
          </div>
        </div>

        {/* Footer del panel izquierdo */}
        <div className="relative z-10 text-xs text-slate-400 flex gap-4 mt-8">
          <span>© 2025 ApuntesUCT</span>
          <a href="#" className="hover:text-white transition-colors">
            Privacidad
          </a>
          <a href="#" className="hover:text-white transition-colors">
            Términos
          </a>
        </div>
      </div>

      {/* Panel Derecho (Formulario) */}
      <div className="w-full lg:w-1/2 flex items-center justify-center p-8 bg-white">
        <div className="w-full max-w-sm space-y-8">
          <div className="text-center">
            <h2 className="text-3xl font-semibold text-gray-900">Ingresar</h2>
            <p className="mt-2 text-sm text-gray-500">
              Accede a tu cuenta de ApuntesUCT
            </p>
          </div>

          <div className="space-y-6">
            {/* Botón de Google */}
            <Button
              variant="secondary"
              className="w-full bg-white border border-gray-300 shadow-sm flex gap-2 items-center justify-center hover:bg-gray-50"
            >
              <svg className="w-5 h-5" viewBox="0 0 24 24">
                <path
                  fill="#4285F4"
                  d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                />
                <path
                  fill="#34A853"
                  d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                />
                <path
                  fill="#FBBC05"
                  d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                />
                <path
                  fill="#EA4335"
                  d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                />
              </svg>
              Continuar con Google
            </Button>

            {/* Separador visual */}
            <div className="relative">
              <div className="absolute inset-0 flex items-center">
                <div className="w-full border-t border-gray-200"></div>
              </div>
              <div className="relative flex justify-center text-sm">
                <span className="px-2 bg-white text-gray-500">
                  o con correo
                </span>
              </div>
            </div>

            <form className="space-y-4" onSubmit={handleSubmit}>
              {loginAlert && (
                <Alert
                  variant={loginAlert.variant}
                  message={loginAlert.message}
                />
              )}

              <Input
                label="Correo electrónico"
                placeholder="tu@correo.cl"
                type="email"
                value={email}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
                  setEmail(e.target.value)
                }
              />

              <div className="space-y-1">
                <Input
                  label="Contraseña"
                  placeholder="••••••••"
                  type="password"
                  value={password}
                  onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
                    setPassword(e.target.value)
                  }
                />
                <div className="flex justify-end">
                  <a
                    href="#"
                    className="text-xs text-blue-600 hover:text-blue-500 font-medium transition-colors"
                  >
                    Olvidé mi contraseña
                  </a>
                </div>
              </div>

              <div className="pt-2">
                <Button
                  type="submit"
                  className="w-full"
                  disabled={loginMutation.isPending}
                >
                  {loginMutation.isPending ? 'Ingresando...' : 'Ingresar'}
                </Button>
              </div>
            </form>
          </div>

          <p className="text-center text-sm text-gray-600">
            ¿No tienes cuenta?{' '}
            <Link
              to="/register"
              className="font-semibold text-blue-600 hover:text-blue-500 transition-colors"
            >
              Registrarse
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}
