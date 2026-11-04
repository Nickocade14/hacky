# Mobile wireframes

Low-fidelity wireframes for every mobile screen. Each SVG holds one flow, with 390×844 phone frames, grey boxes and labels only (no real colors). They follow the style of [the web auth wireframes](../../web/design/auth-wireframes.svg). Screens and data come from [the API contract](../../docs/openapi.yaml).

Screen numbers are shared across all files. "→ 07" on a screen means "this goes to screen 07". The notes under each frame list the data it loads, its states, and where each action goes.

| File | Screens |
|---|---|
| [auth-wireframes.svg](auth-wireframes.svg) | 01 Log in (tab) · 02 Create account (tab) · 03 Check your inbox · 04 Forgot password |
| [home-wireframes.svg](home-wireframes.svg) | 05 Home with event |
| [people-wireframes.svg](people-wireframes.svg) | 06 Search people · 07 Person profile |
| [profile-wireframes.svg](profile-wireframes.svg) | 08 My profile (edit) |
| [requests-wireframes.svg](requests-wireframes.svg) | 09 Requests |
| [messages-wireframes.svg](messages-wireframes.svg) | 10 Conversations · 11 Chat thread |
| [hacky-chat-wireframes.svg](hacky-chat-wireframes.svg) | 12 Hacky chat |

Signed-in screens share a bottom tab bar: Home 05 · People 06 · Hacky 12 · Chats 10 · Me 08. Verify-email and reset-password links open the web, so they have no mobile screen.

## Import into Figma

1. Install Lato on your computer, or Figma will swap the font.
2. Open the team's Figma design file and add a page called **Mobile wireframes**.
3. Drag all seven SVGs onto the page, or use **File → Import**. Each file becomes one group.
4. In each group, find the layers named `mobile-NN-name-screen` (for example `mobile-07-person-screen`). Select one and press **Ctrl+Alt+G** (Mac: **⌘+⌥+G**) to wrap it in a frame. Rename the frame to its title, like **07 Person profile**, and set its size to 390×844.
5. Keep the `-notes` layers next to their frames as annotations, outside the frames.

## Link them as a prototype

1. Switch to **Prototype** mode (top right).
2. Set **01 Log in** as the flow's starting point: select the frame and click **+** next to **Flow starting point**.
3. For each "→ NN" label, select the element it sits on (button, link, row or tab) and drag the blue handle to frame NN. Use **On tap → Navigate to** with **Smart animate** or **Instant**.
4. Link the bottom tab bar on 05, 06, 08, 10 and 12 to the matching tab screens.
5. 01 and 02 are one screen with tabs: link the tabs to each other with **Instant** or **Dissolve (200 ms)**, so the mascot and tabs don't slide.
6. Back arrows and "Back to log in" use **Back** or **Navigate to 01**.
7. Press **Present** (▶) and click through every flow. Share the prototype link with the team for review.

States that aren't drawn as separate frames (errors, loading, empty, sent) are described in the notes. Duplicate a frame to draw one if the review needs it.
