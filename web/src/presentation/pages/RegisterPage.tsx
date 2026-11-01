import { useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { Button } from '../components/Button';
import { Input } from '../components/Input';
import { Select } from '../components/Select';
import { Alert } from '../components/Alert';

type RegisterField = 'name' | 'email' | 'password' | 'career';
type RegisterValues = Record<RegisterField, string>;
type RegisterErrors = Partial<Record<RegisterField, string>>;

const CAREER_OPTIONS = [
  { value: '1', label: 'Ingeniería Civil Informática' },
  { value: '2', label: 'Medicina Veterinaria' },
  { value: '3', label: 'Derecho' },
  { value: '4', label: 'Arquitectura' },
];

export function RegisterPage() {
  const formRef = useRef<HTMLFormElement>(null);
  const [values, setValues] = useState<RegisterValues>({
    name: '',
    email: '',
    password: '',
    career: '',
  });
  const [errors, setErrors] = useState<RegisterErrors>({});
  const [status, setStatus] = useState('');
  const [hasAttemptedSubmit, setHasAttemptedSubmit] = useState(false);

  function updateField(field: RegisterField, value: string) {
    setValues((current) => ({ ...current, [field]: value }));
    setStatus('');
    if (errors[field]) {
      setErrors((current) => ({ ...current, [field]: undefined }));
    }
  }

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setHasAttemptedSubmit(true);

    const nextErrors: RegisterErrors = {};
    if (!values.name.trim()) {
      nextErrors.name = 'Ingresa tu nombre completo.';
    }
    if (!values.email.trim()) {
      nextErrors.email = 'Ingresa tu correo electrónico.';
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(values.email.trim())) {
      nextErrors.email = 'Ingresa un correo electrónico válido.';
    }
    if (!values.password) {
      nextErrors.password = 'Ingresa una contraseña.';
    } else if (values.password.length < 8) {
      nextErrors.password = 'La contraseña debe tener al menos 8 caracteres.';
    }
    if (!values.career) {
      nextErrors.career = 'Selecciona tu carrera.';
    }

    setErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) {
      setStatus('');
      requestAnimationFrame(() => {
        formRef.current
          ?.querySelector<HTMLElement>('[aria-invalid="true"]')
          ?.focus();
      });
      return;
    }

    setStatus(
      'Los datos son válidos, pero el registro de cuentas aún no está habilitado.'
    );
  }

  return (
    <div className="min-h-screen flex lg:h-screen">
      {/* Panel Izquierdo */}
      <div className="hidden lg:flex lg:w-1/2 bg-uct-navy text-white p-12 flex-col justify-between relative overflow-hidden">
        <div className="absolute inset-0 bg-linear-to-br from-uct-blueDark/40 to-uct-navy z-0"></div>

        <div className="relative z-10">
          <div className="flex items-center gap-2 font-bold text-xl mb-16">
            <div className="w-8 h-8 bg-uct-blue rounded-md flex items-center justify-center">
              📄
            </div>
            ApuntesUCT
          </div>

          <h1 className="text-4xl font-bold mb-6 tracking-tight">
            Tu repositorio académico te espera.
          </h1>
          <p className="text-slate-300 text-lg max-w-md leading-relaxed mb-12">
            Accede a miles de apuntes ordenados por carrera, asignatura y
            docente. Sube el tuyo y gana prestigio en la comunidad.
          </p>

          <div className="bg-white/10 backdrop-blur-md border border-white/20 p-6 rounded-xl max-w-md shadow-xl">
            <p className="text-sm italic mb-4 leading-relaxed">
              "Encontré los apuntes del Prof. Caro en menos de un minuto. Pasé
              Hardware gracias a ApuntesUCT."
            </p>
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-uct-sky rounded-full flex items-center justify-center font-bold shadow-inner">
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

        <div className="relative z-10 text-xs text-slate-400 flex gap-4 mt-8">
          <span>© 2026 ApuntesUCT</span>
          <a href="#" className="hover:text-white transition-colors">
            Privacidad
          </a>
          <a href="#" className="hover:text-white transition-colors">
            Términos
          </a>
        </div>
      </div>

      {/* Panel Derecho (Formulario de Registro) */}
      <div className="w-full lg:w-1/2 flex items-center justify-center px-4 py-10 sm:p-8 md:p-12 bg-white lg:h-screen lg:overflow-y-auto">
        <div className="w-full max-w-sm space-y-6 my-auto">
          <div className="text-center">
            <h2 className="text-3xl font-semibold text-gray-900">
              Crear cuenta
            </h2>
            <p className="mt-2 text-sm text-gray-500">
              Únete a la comunidad de estudiantes UCT
            </p>
          </div>

          <div className="space-y-6">
            {/* Botón de Google */}
            <Button
              variant="secondary"
              className="w-full bg-white border border-gray-300 shadow-xs flex gap-2 items-center justify-center hover:bg-gray-50"
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
              Registrarse con Google
            </Button>

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

            <form
              ref={formRef}
              className="space-y-4"
              onSubmit={handleSubmit}
              noValidate
              aria-describedby={status ? 'register-status' : undefined}
            >
              {hasAttemptedSubmit && Object.keys(errors).length > 0 && (
                <Alert
                  variant="error"
                  message="Revisa los campos indicados antes de continuar."
                />
              )}
              {status && (
                <p id="register-status" role="status" className="text-sm text-uct-navy">
                  {status}
                </p>
              )}
              <Input
                label="Nombre completo"
                name="name"
                placeholder="Valentina Torres"
                type="text"
                autoComplete="name"
                required
                value={values.name}
                error={errors.name}
                onChange={(event) => updateField('name', event.target.value)}
              />

              <Input
                label="Correo electrónico"
                name="email"
                placeholder="v.torres@uct.cl"
                type="email"
                autoComplete="email"
                required
                value={values.email}
                error={errors.email}
                onChange={(event) => updateField('email', event.target.value)}
                helperText={
                  <span className="flex items-center gap-1 text-uct-sky mt-1">
                    Te recomendamos usar tu correo institucional UCT
                  </span>
                }
              />

              <Input
                label="Contraseña"
                name="password"
                placeholder="••••••••"
                type="password"
                autoComplete="new-password"
                minLength={8}
                required
                value={values.password}
                error={errors.password}
                onChange={(event) =>
                  updateField('password', event.target.value)
                }
              />

              <Select
                label="Carrera"
                name="career"
                required
                value={values.career}
                error={errors.career}
                placeholder="Selecciona tu carrera"
                options={CAREER_OPTIONS}
                onChange={(event) => updateField('career', event.target.value)}
              />

              <div className="pt-2">
                <Button type="submit" className="w-full">
                  Crear cuenta
                </Button>
              </div>
            </form>
          </div>

          <div className="space-y-4 pt-4">
            <p className="text-center text-sm text-gray-600">
              ¿Ya tienes cuenta?{' '}
              <Link
                to="/login"
                className="font-semibold text-uct-blue hover:text-uct-sky transition-colors focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-uct-sky focus-visible:ring-offset-2"
              >
                Ingresar
              </Link>
            </p>

            <p className="text-center text-xs text-gray-400 px-4">
              Al crear una cuenta aceptas nuestros{' '}
              <a
                href="#"
                className="text-black hover:text-gray-500 transition-colors focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-uct-sky focus-visible:ring-offset-2"
              >
                Términos de uso y Política de privacidad.
              </a>
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
