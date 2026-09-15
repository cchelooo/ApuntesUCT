/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        catalog: {
          ink: '#1B2430',
          paper: '#FBF8F0',
          paperMuted: '#F3EEDF',
          bg: '#F7F4EC',
          line: '#C9BFA5',
          maroon: '#7A1F2B',
        },
      },
      fontFamily: {
        display: ['"Fraunces"', 'serif'],
        body: ['"IBM Plex Sans"', 'sans-serif'],
        mono: ['"IBM Plex Mono"', 'monospace'],
      },
    },
  },
  plugins: [],
};
