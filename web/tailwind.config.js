/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        // Source: mobile/lib/core/theme/uct_palette.dart (light theme).
        uct: {
          blue: '#0078BC',
          blueDark: '#01568E',
          sky: '#3DA5D9',
          yellow: '#FEC601',
          navy: '#0F1D34',
          mist: '#F3F7FA',
          border: '#DCE7F0',
          muted: '#5B7089',
          green: '#2F8F73',
          gold: '#EAA83A',
        },
        catalog: {
          ink: '#0F1D34',
          paper: '#FFFFFF',
          paperMuted: '#E3F1FA',
          bg: '#F3F7FA',
          line: '#DCE7F0',
          primary: '#0078BC',
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
