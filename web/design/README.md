# Auth wireframes

[auth-wireframes.svg](auth-wireframes.svg) contains five editable desktop content layouts: login, registration, email verification, forgotten password, and password reset. It uses the original Hacky palette and Lato. The dashed circle is an illustration placement guide; the web starter uses a vector globe.

This is a design source for the missed Week 1 wireframe task. It has **not** been uploaded to Figma, and it is **not** a clickable Figma prototype. Prototype connections and state variants still need to be made in the team's Figma file.

## Finish in Figma

1. Open the team's Figma design file and drag in `auth-wireframes.svg`. Install Lato locally if Figma reports a missing font.
2. Ungroup the imported top-level group as needed. The named screen groups are `login`, `register`, `verify-email`, `forgot-password`, and `reset-password`.
3. Place each screen in its own Figma frame. Keep the screen label and route as annotations outside the frame. These are content layouts rather than a fixed production viewport; resize the frame for the team's agreed desktop size.
4. Duplicate screens for submitting, inline API errors, and success states. For verification, include check-inbox instructions, a link-ready state, a verified state, and an invalid-link state. For reset, include a missing/invalid-link state.
5. In Prototype mode, make Login the starting point. Connect `Create an account` to Register and `Forgot password?` to Forgot password. Connect the success paths shown in the separate notes panel. Model opening an email as a prototype navigation step; Figma does not send a verification or recovery email.
6. Test the prototype, share its actual Figma link with Nicolas, and request review. Confirm the mobile layouts use the same colors, Lato, fields, and state behavior.

The password confirmation shown on Reset is a client-side check. It is not an extra API field. The API contract and all request/response shapes remain in [docs/openapi.yaml](../../docs/openapi.yaml); use that file when revising these designs.

## Review checklist

- Login or registration is the first app screen.
- Registration shows name, handle, email, and password.
- Verification and reset links lead to the intended page and do not require manually copying a token.
- Every form has submitting, success, and visible error states; keyboard focus and labels remain readable.
- Unknown-email recovery uses the same confirmation as an existing account.
- An invalid verification/reset link offers a clear way to request another.
- All screens are reviewed against the implemented web pages before the prototype is submitted.
