import React from 'react';

export interface SpinnerProps {
  /** Tamaño del spinner: pequeño, mediano o grande */
  size?: 'sm' | 'md' | 'lg';
  /** Color CSS (ej. 'red', '#2563eb'). Se aplica mediante la propiedad style. */
  color?: string;
  /** Clases adicionales para el contenedor (ej. clases de Tailwind) */
  className?: string;
}

const sizeClasses = {
  sm: 'w-4 h-4',
  md: 'w-8 h-8',
  lg: 'w-12 h-12',
};

export const Spinner: React.FC<SpinnerProps> = ({
  size = 'md',
  color,
  className = '',
}) => {
  return (
    <span
      role="status"
      style={{ color }}
      className={`inline-block ${sizeClasses[size]} ${className}`}
    >
      <svg
        aria-hidden="true"
        className="w-full h-full animate-spin motion-reduce:animate-none"
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
    </span>
  );
};
