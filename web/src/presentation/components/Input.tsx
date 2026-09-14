import { useId } from 'react';
import type { InputHTMLAttributes, ReactNode } from 'react';

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
  helperText?: ReactNode;
  fullWidth?: boolean;
  containerClassName?: string;
}

export const Input = ({
  label,
  error,
  helperText,
  fullWidth = true,
  className = '',
  containerClassName = '',
  disabled = false,
  id,
  'aria-describedby': ariaDescribedBy,
  ...props
}: InputProps) => {
  const defaultId = useId();
  const inputId = id || defaultId;
  const descriptionId =
    error || helperText ? `${inputId}-description` : undefined;

  const containerWidthClass = fullWidth ? 'w-full' : 'w-auto';

  const baseInputClass =
    'block w-full rounded-md border text-sm transition-colors px-3 py-2 outline-none focus:ring-2 focus:ring-offset-2';

  const stateClass = error
    ? 'border-red-500 text-red-900 placeholder-red-300 focus:border-red-500 focus:ring-red-500'
    : 'border-gray-300 text-gray-900 placeholder-gray-400 focus:border-blue-500 focus:ring-blue-500';

  const disabledClass = disabled
    ? 'bg-gray-100 opacity-75 cursor-not-allowed'
    : 'bg-white';

  const combinedDescribedBy =
    [ariaDescribedBy, descriptionId].filter(Boolean).join(' ') || undefined;

  return (
    <div
      className={`flex flex-col gap-1.5 ${containerWidthClass} ${containerClassName}`.trim()}
    >
      {label && (
        <label htmlFor={inputId} className="text-sm font-medium text-gray-700">
          {label}
        </label>
      )}
      <input
        id={inputId}
        disabled={disabled}
        className={`${baseInputClass} ${stateClass} ${disabledClass} ${className}`.trim()}
        aria-invalid={Boolean(error)}
        aria-describedby={combinedDescribedBy}
        {...props}
      />
      {(error || helperText) && (
        <p
          id={descriptionId}
          className={`text-xs ${error ? 'text-red-500' : 'text-gray-500'}`}
        >
          {error || helperText}
        </p>
      )}
    </div>
  );
};
