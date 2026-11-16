import { useId } from 'react';
import type { InputHTMLAttributes, ReactNode } from 'react';

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label: string;
  error?: string;
  helperText?: ReactNode;
  fullWidth?: boolean;
  containerClassName?: string;
  hideLabel?: boolean;
}

export const Input = ({
  label,
  error,
  helperText,
  fullWidth = true,
  className = '',
  containerClassName = '',
  hideLabel = false,
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
    'block w-full rounded-md border text-sm transition-colors px-3 py-2 outline-hidden focus-visible:ring-2 focus-visible:ring-offset-2';

  const stateClass = error
    ? 'border-red-500 text-red-900 placeholder-red-300 focus-visible:border-red-500 focus-visible:ring-red-500'
    : 'border-catalog-line bg-catalog-paper text-catalog-ink placeholder-uct-muted focus-visible:border-uct-sky focus-visible:ring-uct-sky';

  const disabledClass = disabled
    ? 'bg-catalog-bg opacity-75 cursor-not-allowed'
    : 'bg-catalog-paper';

  const combinedDescribedBy =
    [ariaDescribedBy, descriptionId].filter(Boolean).join(' ') || undefined;

  return (
    <div
      className={`flex flex-col gap-1.5 ${containerWidthClass} ${containerClassName}`.trim()}
    >
      <label
        htmlFor={inputId}
        className={`text-sm font-medium text-catalog-ink ${hideLabel ? 'sr-only' : ''}`}
      >
        {label}
      </label>
      <input
        id={inputId}
        disabled={disabled}
        className={`${baseInputClass} ${stateClass} ${disabledClass} ${className}`.trim()}
        aria-describedby={combinedDescribedBy}
        {...props}
        aria-invalid={error ? true : props['aria-invalid']}
      />
      {(error || helperText) && (
        <p
          id={descriptionId}
          className={`text-xs ${error ? 'text-red-700' : 'text-uct-muted'}`}
        >
          {error || helperText}
        </p>
      )}
    </div>
  );
};
