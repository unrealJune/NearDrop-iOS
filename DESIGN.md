# NearDrop iOS design

## Shape

The home screen is a quiet signal field with one adaptive floating island. The
island expands in place through ready, discovery, consent, transfer, success,
and error states. Rows and hairline dividers carry structure; nested cards do
not.

The visual language translates Street Cryptid's continuous island composition
to native SwiftUI rather than copying its web implementation. The dot-matrix
readout adapts junephilip.com's 5-by-7 flip-dot idea as an accessible SwiftUI
Canvas with deterministic ocean-colored pixels.

## Type

- System Dynamic Type for navigation, labels, buttons, and body content.
- Rounded system design for compact technical metadata.
- Dot matrix only for short status words and PIN codes.

## Color and material

- System background provides the base in both appearances.
- A restrained teal-to-sky signal gradient supplies identity.
- System material keeps the island native and responsive to appearance.
- Hairlines use the system separator color.
- Errors and success use semantic system colors.

## Motion

State changes use short opacity and scale transitions. Progress is continuous,
not ornamental. Reduce Motion removes spatial transitions and animated signal
effects.

## Accessibility

Canvas readouts expose a single semantic text label. Controls use native
labels, traits, and hit targets. The island has no fixed height and remains
usable at accessibility text sizes. Meaning never depends on color alone.
