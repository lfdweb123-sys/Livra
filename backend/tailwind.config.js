module.exports = {
  content: ['./app/**/*.{js,jsx}', './components/**/*.{js,jsx}'],
  theme: {
    extend: {
      // Palette identique à l'application mobile — thème CLAIR (fond
      // blanc), voir mobile/lib/core/theme/app_colors_light.dart.
      colors: {
        livra: {
          bg: '#FAF9F6',
          surface: '#FFFFFF',
          surfaceElevated: '#F1EFE9',
          gold: '#D9560A',
          goldSoft: '#F2854A',
          textPrimary: '#17171A',
          textSecondary: '#6B6B6F',
          success: '#1E9A63',
          danger: '#D3373C',
          warning: '#C98416',
          divider: '#E4E1D8',
        },
      },
      fontFamily: {
        sans: ['ui-sans-serif', 'system-ui', '-apple-system', 'Segoe UI', 'Roboto', 'Helvetica Neue', 'Arial', 'sans-serif'],
      },
    },
  },
  plugins: [],
};
