module.exports = {
  content: ['./app/**/*.{js,jsx}', './components/**/*.{js,jsx}'],
  theme: {
    extend: {
      // Palette identique à l'application mobile (thème sombre "Noir/Orange"
      // du logo Livra) — voir mobile/lib/core/theme/app_colors_dark.dart.
      // Un seul et même thème sur tout le site (landing + admin), pas de
      // bascule clair/sombre côté web.
      colors: {
        livra: {
          bg: '#0B0B0D',
          surface: '#17171A',
          surfaceElevated: '#212125',
          gold: '#F2660B',
          goldSoft: '#FF9A44',
          textPrimary: '#F5F5F5',
          textSecondary: '#9B9B9F',
          success: '#33C481',
          danger: '#E5484D',
          warning: '#F5A623',
          divider: '#2A2A2E',
        },
      },
      fontFamily: {
        sans: ['ui-sans-serif', 'system-ui', '-apple-system', 'Segoe UI', 'Roboto', 'Helvetica Neue', 'Arial', 'sans-serif'],
      },
    },
  },
  plugins: [],
};
