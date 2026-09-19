import React from 'react';

export interface SpinnerProps {
  /** Tamaño del spinner: pequeño, mediano o grande */
  size?: 'sm' | 'md' | 'lg';
  /** Color CSS o clases de Tailwind (ej. 'text-blue-500'). Por defecto utiliza 'text-current' */
  color?: string;
  /** Clases adicionales para el contenedor */
  className?: string;
}

const sizeClasses = {
  sm: 'w-4 h-4',
  md: 'w-8 h-8',
  lg: 'w-12 h-12',
};

export const Spinner: React.FC<SpinnerProps> = ({
  size = 'md',
  color = 'text-current',
  className = '',
}) => {
  return (
    <div
      role="status"
      aria-label="Cargando..."
      className={`inline-block animate-spin ${sizeClasses[size]} ${color} ${className}`}
    >
      <svg
        className="w-full h-full"
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
      >
        <circle
          className="opacity-25"
          cx="12"
          cy="12"
          r="10"
          stroke="currentColor"
          strokeWidth="4"
        />
        <path
          className="opacity-75"
          fill="currentColor"
          d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
        />
      </svg>
      <span className="sr-only">Cargando...</span>
    </div>
  );
};
