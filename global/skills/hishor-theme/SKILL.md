---
name: hishor-theme
description: Use when building or restyling any UI for Hishor — web apps, frontends, dashboards, HTML pages, forms. Applies Hishor's house theme (dark Catppuccin Mocha + royal blue #4169e1, taken from the Obsidian vault Hishors_Vault) via a ready theme.css, and checks an app against it.
---

# hishor-theme

Every app Hishor builds looks like his Obsidian vault: dark gray-black (Catppuccin Mocha) with a
royal blue accent `#4169e1`. `theme.css` in this folder is the single source of the colors.

## Apply

1. **Copy `theme.css` into the app unchanged** (e.g. `src/styles/theme.css` or `public/theme.css`)
   and load it before any other styles. Don't retype the hex values.
2. **Style only through its variables.** No hardcoded colors anywhere else. Tailwind/component
   libraries: map their colors to the variables (e.g. `primary: "var(--accent)"`).
3. **Dark only.** No light mode, no theme toggle unless asked.

## Roles

| Element | Use |
|---|---|
| Page | `--bg-base` |
| Sidebar | `--bg-mantle`; top bar `--bg-crust` |
| Cards, panels | `--surface-0` |
| Borders, input borders, secondary buttons | `--surface-1` |
| Active nav item, tab, chip, selected row | class `.is-selected`: `--selected-bg` + `--selected-ring` + `--accent-text` |
| Primary button | `--primary-bg` + `--primary-ring`, `--accent-text` text, hover `--primary-bg-hover` |
| Links, blue text | `--accent-text` (never `--accent` as text: too dark) |
| Focus ring | `--accent` (2px outline) |
| Tags | `--accent-soft` bg, `--accent-text` text |

**No solid royal-blue boxes.** Blue is a tint with a fine 1px inner ring (the look of Cockpit's
Tasks sidebar): it reads elegant, a filled `#4169e1` block reads generic. No left-border markers.
| Body text / hints | `--text` / `--text-muted` (hints only) |
| Success / warning / danger | `--success` / `--warning` / `--danger` |

`preview.html` shows all of it together: sidebar, card, input, buttons, tag, status colors.

## Check an app

Open the app next to `preview.html` (or screenshot both) and compare. Then grep the app's styles
for hardcoded colors outside `theme.css` (`#[0-9a-fA-F]{3,8}\b`, `rgb(`, Tailwind color classes
like `bg-blue-500`); each hit should become a variable.
