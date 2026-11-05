---
name: VPS Monitor
description: Native macOS server monitoring in the tradition of Activity Monitor.
typography:
  connection-title:
    fontFamily: "System"
    fontSize: "29pt"
    fontWeight: 600
  resource-value:
    fontFamily: "System"
    fontSize: "27pt"
    fontWeight: 500
  file-preview:
    fontFamily: "System Monospaced"
    fontSize: "12pt"
rounded:
  source-selection: "7pt"
  inset-surface: "8pt"
spacing:
  compact: "9pt"
  control-gap: "10pt"
  small: "12pt"
  toolbar-inset: "16pt"
  source-inset: "18pt"
  medium: "20pt"
  section: "24pt"
  sheet: "28pt"
  connection-inset: "40pt"
components:
  source-item:
    rounded: "{rounded.source-selection}"
    padding: "9pt 10pt"
  detail-content:
    padding: "{spacing.section}"
  error-banner:
    padding: "{spacing.small}"
  file-preview-text:
    typography: "{typography.file-preview}"
    padding: "{spacing.source-inset}"
---

# Design System: VPS Monitor

## Overview

**Creative North Star: "Activity Monitor"**

A familiar Mac monitoring utility in the tradition of Activity Monitor. A persistent source sidebar organizes a quiet detail area around readable measurements, resource history, and sortable tables. Native controls, system typography, SF Symbols, and the current system appearance provide the visual language.

The interface stays compact enough for inspection while leaving clear space between groups. Emphasis comes from type hierarchy, selected navigation, and meaningful status color. System sheets interrupt only when the task needs focused attention.

**Key Characteristics:**

- Familiar source sidebar and native data tables.
- System typography, SF Symbols, and automatic light/dark appearance.
- Readable measurements with monospaced digits.
- Status communicated with words and symbols as well as color.

## Colors

The palette is the native macOS semantic palette. Color values deliberately remain system API names, rather than CSS approximations; they resolve with appearance, accent preference, and platform behavior. No fixed color primitives are declared in the frontmatter.

### Primary

- **System accent** (`Color.accentColor`, `.tint`): server icon, folder names/icons, prominent connection actions, and selected source item background. The source selection uses accent opacity (0.16).
- **CPU blue** (`Color.blue`): CPU history line and resource tint assignment.

### Secondary

- **Memory purple** (`Color.purple`): memory history line and resource tint assignment.
- **Storage teal** (`Color.teal`): storage resource tint assignment. Native progress indicators retain their platform rendering.

### Neutral

- **Primary content** (`Color.primary`): headings, names, and ordinary data.
- **Secondary content** (`.secondary`): captions, metadata, supporting copy, and disconnected source items.
- **Inset material** (`.quaternary`): fingerprint container and empty-chart inset; the empty chart reduces its opacity (0.3).
- **Text background** (`Color(nsColor: .textBackgroundColor)`): file preview surface.
- Window, sidebar, grouped form, table stripes, dividers, selection, focus, and disabled controls use their native defaults.

### Status

- **Active green** (`.green`): active service labels and connected indicator.
- **Attention orange** (`.orange`): transitional service states and incomplete application-service groups. Error and paused banners use orange at opacity (0.1) for their background.
- **Failure red** (`.red`): failed services and connection errors.
- Other service states use secondary content styling. Every service state includes text and a symbol.

**The System Appearance Rule.** Resolve colors through SwiftUI and AppKit semantic APIs; never freeze a screenshot’s light or dark values into app tokens.

## Typography

Use SwiftUI system text styles for the ordinary hierarchy: `.title` for the server hostname, `.title2` for the trust-sheet heading, `.headline` for section labels, `.body` for main content, `.callout` for status and help, and `.caption` for supporting metadata. Keep their native point sizes and line metrics under platform control.

The frontmatter captures the explicit font sizes implemented for the connection title, resource values, and file preview. Resource values use medium weight with monospaced digits; the connection title uses semibold. Selected source labels and primary table names use medium weight. Paths and permissions use the system monospaced design at the relevant native text style.

**The Measured Emphasis Rule.** Use monospaced digits for changing measurements and monospaced text for paths, fingerprints, permissions, and file contents. Keep ordinary interface copy in the system proportional font.

## Layout

Use `NavigationSplitView` with a source column (minimum 190 pt, ideal 215 pt, maximum 280 pt). The main window has a minimum size of 960 × 640 pt and a default size of 1180 × 790 pt. Preserve macOS window resizing and split-view behavior rather than introducing web breakpoints.

Overview content uses the section spacing token for outer padding and vertical grouping. Three resource summaries share available width with dividers; two history charts share a row with a 28 pt gap. Charts are 150 pt high. The overview scrolls vertically when the minimum window height cannot show every service row.

Table pages place controls above full-width native tables, with the toolbar-inset token around the control row and small padding around explanatory footers. Process and service search fields are 240 pt wide; the file filter is 220 pt. The status footer remains below the detail content.

The connection form is centered within a maximum content width of 510 pt, with the connection-inset padding and vertical scrolling. The trust sheet is 620 pt wide with sheet padding. File preview starts at 750 × 520 pt and has an ideal size of 850 × 650 pt; its content scrolls horizontally and vertically.

## Elevation & Depth

The implemented content has no custom shadows. Dividers, native alternating table rows, subdued inset backgrounds, and the sidebar boundary provide depth. Grouped forms, buttons, sheets, and focus indicators retain platform styling; their appearance is not an app-owned shadow token.

**The Native Structure Rule.** Let split-view boundaries, dividers, table rows, and system sheets establish structure before adding a custom container.

## Shapes

Use the frontmatter source-selection radius for the custom sidebar highlight, and the inset-surface radius for fingerprint and empty-chart surfaces. Native controls, tables, windows, and sheets own their remaining corner shapes. Do not transfer these two radii to every system control.

## Components

### Navigation

Source items pair an SF Symbol with a body label. Selected labels use medium weight and an accent-tinted rounded background; disconnected items are disabled and secondary. The server identity block and connection status sit above navigation, and endpoint/disconnect actions sit below it. Expose selected accessibility traits.

### Buttons and fields

Use native `Button`, `TextField`, `SecureField`, `Picker`, `Toggle`, and `ProgressView`. The connection action uses `.borderedProminent` with large control size and the default-action keyboard shortcut. Trust confirmation also uses `.borderedProminent`. Ordinary actions retain standard styling; disconnect uses `.borderless`; source items use `.plain`. File navigation uses labeled icon-only buttons with help text. Search and path fields use `.roundedBorder`; password entry uses `SecureField`. Preserve native keyboard focus, hover, pressed, and disabled feedback.

### Tables

`Table` owns header appearance, row stripes, selection, and sortable columns. Processes initially sort by descending CPU; services initially sort by name. Files initially sort by name; Name, Size, Modified, and Permissions headings are sortable. Files support selection and double-click open, and provide contextual open/preview and path-copy actions. Preserve numerical sort semantics for sizes, dates, and measurements. Empty states use `ContentUnavailableView`.

### Resource summaries and history

Each summary combines a headline label, measured value, native progress indicator, and secondary detail. Values fit a single line with a minimum scale factor (0.8). Swift Charts uses a fixed percent domain (0–100), labeled ticks at 0/50/100, and time labels. History strokes use width (1.8 pt). Empty history includes a symbol and explanatory caption on a quiet inset surface. Do not add enclosing cards around ordinary overview groups.

### Status and feedback

`StatusLabel` combines the readable state with a checkmark, failure mark, or neutral circle. Application rows show an active count with green or orange feedback. `ErrorBanner` pairs an orange warning symbol with selectable text and an optional retry action. Paused monitoring states explicitly state that the last readings remain visible. Native progress views communicate refresh, connection, directory, and preview activity.

### Sheets and previews

Trust confirmation presents selectable monospaced fingerprints in an inset surface and explicit Cancel / Trust and Connect actions. File preview uses a native sheet with a title/action row, selectable path and text, and an explicit truncation message when needed. Sheet contents use system colors and native dismissal shortcuts.

## Do's and Don'ts

### Do:

- **Do** use the current system appearance, native focus treatment, and standard control states.
- **Do** preserve sortable table headings, contextual actions, and keyboard shortcuts.
- **Do** accompany status color with readable state text and an SF Symbol.
- **Do** retain visible refresh, paused, loading, error, and empty states.
- **Do** verify new surfaces in light and dark appearance and at the minimum window size.

### Don't:

- **Don't** replace semantic system colors with sampled hexadecimal values.
- **Don't** add custom shadows or decorative cards to ordinary monitoring sections.
- **Don't** use monospaced type for all interface text.
- **Don't** present sample, stale, or paused readings as current live data.
