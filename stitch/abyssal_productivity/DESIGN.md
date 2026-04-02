# Design System Specification: The Deep Sea Narrative

This document defines the visual language and structural logic for a high-end productivity experience. Moving beyond standard iOS templates, this system prioritizes "The Editorial Flow"—a philosophy where data density is balanced by luxurious whitespace and tonal depth rather than rigid lines.

---

### 1. Creative North Star: "The Silent Orchestrator"
The goal of this design system is to create an environment of "Focused Calm." We avoid the "utility-first" clutter of traditional productivity tools. Instead, we treat tasks like editorial content. 

**Signature Approach:**
*   **Intentional Asymmetry:** Break the monotony of centered grids. Use off-center headers and staggered card layouts to guide the eye.
*   **Tonal Architecture:** We build "up" using layers of color, not "out" using lines.
*   **Native Sophistication:** We utilize iOS-native behaviors (like large titles and spring physics) but elevate them through custom typography scales and glassmorphism.

---

### 2. Color & Atmospheric Depth

We move away from flat UI by utilizing a "Deep Sea" spectrum. This isn't just about color; it’s about perceived distance and importance.

#### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders to section content. Boundaries must be defined through background color shifts.
*   **The Transition:** Use `surface-container-low` for a section background sitting on a `background` base. The change in tone is the boundary.

#### Surface Hierarchy & Nesting
Treat the UI as a series of stacked sheets of fine, semi-translucent paper.
*   **Level 0 (Base):** `background` (#f7f9fc)
*   **Level 1 (Sections):** `surface-container-low` (#f2f4f7)
*   **Level 2 (Active Cards):** `surface-container-lowest` (#ffffff)
*   **Level 3 (Floating/Modals):** Glassmorphic `surface` with 80% opacity and 20px backdrop-blur.

#### Signature Textures
To provide a "soul" to the professional palette, use subtle gradients for primary CTAs:
*   **Action Gradient:** Linear transition from `primary` (#00334d) to `primary_container` (#004b6e) at a 135° angle. This adds a subtle 3D curvature to flat buttons.

---

### 3. Typography: The Editorial Scale

We pair **Manrope** (Display) for its geometric authority with **Inter** (Body) for its legendary legibility.

| Role | Token | Font | Size | Weight | Tracking |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Hero Title** | `display-lg` | Manrope | 3.5rem | 700 | -0.02em |
| **Section Head** | `headline-sm` | Manrope | 1.5rem | 600 | -0.01em |
| **Primary Action** | `title-sm` | Inter | 1rem | 600 | 0.01em |
| **Body Content** | `body-md` | Inter | 0.875rem | 400 | 0 |
| **Metadata** | `label-sm` | Inter | 0.6875rem | 500 | 0.04em |

*Direction:* Use `on_surface` (#191c1e) for primary headers to ensure high-contrast "Charcoal" authority. Use `on_surface_variant` (#41484e) for secondary body text to reduce visual noise.

---

### 4. Elevation & Depth: Tonal Layering

Traditional drop shadows are too "web-standard." We use **Ambient Softness**.

*   **The Layering Principle:** Depth is achieved by "stacking." A `surface-container-lowest` card placed on a `surface-container-low` background creates a natural lift.
*   **Ambient Shadows:** When a float is required (e.g., a Floating Action Button), use a shadow color tinted with the primary hue: `rgba(0, 51, 77, 0.08)` with a 30px blur and 10px Y-offset.
*   **The Ghost Border Fallback:** If accessibility requires a border, use `outline-variant` (#c1c7cf) at **15% opacity**. It should be felt, not seen.

---

### 5. Components

#### Buttons (The Action Center)
*   **Primary:** Uses the "Deep Sea Blue" (`primary`). Padding: 16px 24px. Radius: `lg` (1rem).
*   **Secondary:** `secondary_container` (#d4e1ee) with `on_secondary_container` (#57646f) text. No border.
*   **Tertiary:** Ghost style. No background, `primary` text. Use for low-emphasis navigation.

#### Priority Tags (The Signal System)
Tags must be pill-shaped (`full` roundedness) and use high-contrast "Fixed" tokens.
*   **High:** `tertiary_container` (#852205) background with `on_tertiary_fixed` text.
*   **Medium:** Use a custom "Warm Amber" (Secondary Fixed Variant #3b4853).
*   **Low:** `primary_fixed` (#c9e6ff) background with `on_primary_fixed` text.

#### Task Cards & Lists
*   **Rule:** Forbid divider lines. Use `md` (0.75rem) spacing between list items.
*   **Structure:** Title in `title-md`, subtitle in `body-sm`. 
*   **Progress Indicators:** Use a 4px tall track with `surface-variant`. The active progress bar should use the `primary` to `primary_container` gradient.

#### Input Fields
*   **The "Soft Box":** Inputs should use `surface_container_highest` (#e0e3e6) background. 
*   **Interaction:** On focus, the background shifts to `surface_container_lowest` and gains a 1px "Ghost Border" of the `primary` color at 20% opacity.

---

### 6. Do’s and Don'ts

**Do:**
*   **Do** use `xl` (1.5rem) rounding for large containers like task dashboards to emphasize the "soft" premium feel.
*   **Do** leverage `surface_bright` for background areas that need to feel expansive and airy.
*   **Do** use "over-sized" margins (24px - 32px) on the edges of the screen to create an editorial layout.

**Don’t:**
*   **Don't** use pure black (#000000). Always use `on_surface` (#191c1e) for typography.
*   **Don't** use standard iOS blue for links. Use the "Deep Sea Blue" (`primary`).
*   **Don't** stack more than three levels of surface containers. It leads to visual "muddiness."