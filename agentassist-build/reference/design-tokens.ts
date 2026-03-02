/**
 * AgentAssist Design Tokens
 * Extracted from Master Spec v0.9, Section 11.2
 *
 * These tokens are the source of truth for both iOS (SwiftUI) and Web (React) clients.
 * Map to platform-specific implementations:
 *   iOS: Color.agentRed, Font.dmSans(size:weight:)
 *   Web: CSS custom properties or Tailwind config
 */

// ============================================================
// COLORS
// ============================================================

export const colors = {
  // Primary
  red: '#C8102E',           // Primary action, CTAs, active states
  redLight: '#FEE2E8',      // Backgrounds for red-themed elements
  redGlow: '#FFF1F3',       // Subtle red tint for focus rings, selected states

  // Navy (text, dark surfaces)
  navy: '#0A1628',          // Primary text, dark backgrounds
  navyMid: '#1A2B4A',      // Secondary dark (gradient endpoints)

  // Neutrals
  white: '#FFFFFF',
  slate: '#5A6578',         // Secondary text, descriptions
  slateLight: '#8E99A8',    // Tertiary text, timestamps, placeholders
  border: '#E2E8F0',        // Card borders, input borders
  borderLight: '#F1F5F9',   // Subtle dividers, disabled backgrounds
  bg: '#F8FAFC',            // Page background (light gray)

  // Semantic — Status
  green: '#16A34A',         // Success, completed, approved
  greenLight: '#F0FDF4',    // Success backgrounds
  amber: '#D97706',         // Warning, in-progress, pending
  amberLight: '#FFFBEB',    // Warning backgrounds
  blue: '#2563EB',          // Info, posted status
  blueLight: '#EFF6FF',     // Info backgrounds
  errorRed: '#DC2626',      // Destructive actions, error states
  errorBg: '#FEF2F2',       // Error backgrounds
} as const;

// ============================================================
// TYPOGRAPHY
// ============================================================

export const typography = {
  fontFamily: "'DM Sans', system-ui, -apple-system, sans-serif",

  // Scale
  display: { size: 30, weight: 800, letterSpacing: -0.5 },
  titleLg: { size: 22, weight: 800 },
  titleMd: { size: 18, weight: 700 },
  titleSm: { size: 15, weight: 700 },
  body: { size: 14, weight: 400, lineHeight: 1.5 },
  bodyBold: { size: 14, weight: 600 },
  caption: { size: 13, weight: 500 },
  small: { size: 12, weight: 500 },
  micro: { size: 10, weight: 700 },
} as const;

// ============================================================
// SPACING
// ============================================================

export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  xxl: 24,
  xxxl: 32,
  screenPadding: 20,       // Horizontal padding on all screens
  cardPadding: 16,         // Default card internal padding
  sectionGap: 24,          // Gap between major sections
  tabBarHeight: 52,        // Floating tab bar height
  tabBarBottomInset: 16,   // Tab bar distance from bottom
  contentBottomPadding: 100, // Content padding to clear tab bar
} as const;

// ============================================================
// RADII
// ============================================================

export const radii = {
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  pill: 999,               // Full pill shape (buttons, tab bar)
  card: 16,                // Default card corner radius
  input: 12,               // Input field corners
  avatar: 999,             // Circular avatars
  badge: 20,               // Status badges
  tabBar: 26,              // Tab bar capsule
} as const;

// ============================================================
// SHADOWS
// ============================================================

export const shadows = {
  card: '0 1px 3px rgba(10, 22, 40, 0.06), 0 1px 2px rgba(10, 22, 40, 0.04)',
  cardHover: '0 4px 12px rgba(10, 22, 40, 0.08)',
  tabBar: '0 0.5px 0 0 rgba(255,255,255,0.7) inset, 0 -0.5px 0 0 rgba(0,0,0,0.03) inset, 0 8px 32px rgba(10,22,40,0.12)',
  sheet: '0 -4px 24px rgba(10, 22, 40, 0.12)',
  focusRing: (color: string = colors.red) => `0 0 0 3px ${color}20`,
} as const;

// ============================================================
// ANIMATIONS
// ============================================================

export const animations = {
  spring: 'cubic-bezier(0.32, 0.72, 0, 1)',  // iOS-like spring
  duration: {
    fast: 200,
    normal: 350,
    slow: 500,
  },
} as const;

// ============================================================
// STATUS BADGE MAP
// ============================================================

export const statusBadge = {
  draft:                  { label: 'Draft',       bg: colors.borderLight, color: colors.slate },
  posted:                 { label: 'Posted',      bg: colors.blueLight,   color: colors.blue },
  accepted:               { label: 'Accepted',    bg: colors.greenLight,  color: colors.green },
  in_progress:            { label: 'In Progress', bg: colors.amberLight,  color: colors.amber },
  deliverables_submitted: { label: 'Review',      bg: colors.blueLight,   color: colors.blue },
  revision_requested:     { label: 'Revision',    bg: colors.amberLight,  color: colors.amber },
  completed:              { label: 'Completed',   bg: colors.greenLight,  color: colors.green },
  cancelled:              { label: 'Cancelled',   bg: colors.errorBg,     color: colors.errorRed },
} as const;
