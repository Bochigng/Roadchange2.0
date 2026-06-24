import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: ["class"],
  content: [
    "./app/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./features/**/*.{ts,tsx}",
    "./lib/**/*.{ts,tsx}",
    "./stores/**/*.{ts,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        surface: "hsl(var(--surface))",
        "surface-muted": "hsl(var(--surface-muted))",
        "border-soft": "hsl(var(--border-soft))",
        "accent-cyan": "hsl(var(--accent-cyan))",
        "accent-purple": "hsl(var(--accent-purple))",
        "signal-green": "hsl(var(--signal-green))",
        "warning-amber": "hsl(var(--warning-amber))",
        "recovery-blue": "hsl(var(--recovery-blue))",
      },
      borderRadius: {
        glass: "1.75rem",
        panel: "2.25rem",
      },
      boxShadow: {
        glass: "0 24px 80px rgba(37, 56, 88, 0.12)",
        glow: "0 0 45px rgba(41, 209, 226, 0.18)",
        purple: "0 0 48px rgba(132, 104, 255, 0.18)",
      },
      fontFamily: {
        sans: ["Plus Jakarta Sans", "ui-sans-serif", "system-ui", "sans-serif"],
        mono: ["IBM Plex Mono", "ui-monospace", "monospace"],
      },
      spacing: {
        section: "1.875rem",
        rail: "0.675rem",
      },
      keyframes: {
        aurora: {
          "0%, 100%": { transform: "translate3d(0, 0, 0) scale(1)", opacity: "0.72" },
          "50%": { transform: "translate3d(2%, -2%, 0) scale(1.05)", opacity: "0.92" },
        },
      },
      animation: {
        aurora: "aurora 12s ease-in-out infinite",
      },
    },
  },
  plugins: [],
};

export default config;
