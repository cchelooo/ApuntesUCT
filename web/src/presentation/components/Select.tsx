import { useId } from 'react';
import type { SelectHTMLAttributes, ReactNode } from 'react';

export interface SelectOption {
  value: string;
  label: string;
}

interface SelectProps extends SelectHTMLAttributes<HTMLSelectElement> {
  label?: string;
  error?: string;
  helperText?: ReactNode;
  options: SelectOption[];
  fullWidth?: boolean;
  containerClassName?: string;
  placeholder?: string;
}

export const Select = ({
  label,
  error,
  helperText,
  options,
  fullWidth = true,
  className = '',
  containerClassName = '',
  disabled = false,
  id,
  placeholder,
  'aria-describedby': ariaDescribedBy,
  ...props
}: SelectProps) => {
  const defaultId = useId();
  const selectId = id || defaultId;
  const descriptionId =
    error || helperText ? `${selectId}-description` : undefined;

  const containerWidthClass = fullWidth ? 'w-full' : 'w-auto';

  const baseSelectClass =
    'block w-full rounded-md border text-sm transition-colors px-3 py-2 outline-hidden focus:ring-2 focus:ring-offset-2 bg-white appearance-none';

  const stateClass = error
    ? 'border-red-500 text-red-900 focus:border-red-500 focus:ring-red-500'
    : 'border-gray-300 text-gray-900 focus:border-uct-sky focus:ring-uct-sky';

  const disabledClass = disabled
    ? 'bg-gray-100 opacity-75 cursor-not-allowed'
    : '';

  const combinedDescribedBy =
    [ariaDescribedBy, descriptionId].filter(Boolean).join(' ') || undefined;

  return (
    <div
      className={`flex flex-col gap-1.5 ${containerWidthClass} ${containerClassName}`.trim()}
    >
      {label && (
        <label htmlFor={selectId} className="text-sm font-medium text-gray-700">
          {label}
        </label>
      )}
      <div className="relative">
        <select
          id={selectId}
          disabled={disabled}
          className={`${baseSelectClass} ${stateClass} ${disabledClass} ${className}`.trim()}
          aria-describedby={combinedDescribedBy}
          aria-invalid={error ? true : props['aria-invalid']}
          {...props}
        >
          {placeholder && (
            <option value="" disabled hidden>
              {placeholder}
            </option>
          )}
          {options.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
        <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2 text-gray-700">
          <svg
            className="h-4 w-4"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth="2"
              d="M19 9l-7 7-7-7"
            />
          </svg>
        </div>
      </div>
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
