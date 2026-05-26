# AI Image Validation for X2Earn Apps

## When to use

Use when the user asks about: AI image verification, photo validation, fake image detection, anti-fraud image checks, doctored photo detection, watermark detection, screen capture detection, image authenticity.

## Overview

X2Earn apps that use photos as proof of sustainable actions should validate images with AI to detect fraud. The AI prompt should check for:

- Image quality sufficient for evaluation
- Doctored or unrealistic modifications
- Photos of a computer screen (re-photographed)
- Watermarks (stock image reuse)
- Painted or hand-drawn text replacing real data

---

## Recommended Response Schema

Request the AI to return a structured JSON response:

```json
{
  "evaluation_feasible": true,
  "doctored_unrealistic_score": 0.0,
  "doctored_unrealistic_reasons": [],
  "screen_capture_score": 0.0,
  "screen_capture_reasons": [],
  "watermark_score": 0.0,
  "watermark_reasons": [],
  "watermark_text": "",
  "painted_text_score": 0.0,
  "painted_text_reasons": [],
  "final_label": "clean",
  "final_confidence": 0.0
}
```

### Field Reference

| Field | Description |
|-------|-------------|
| `evaluation_feasible` | `true` if image quality is sufficient for checks; `false` if too poor to reliably evaluate |
| `doctored_unrealistic_score` / `_reasons` | 0-1 score for detected doctoring or unrealistic content |
| `screen_capture_score` / `_reasons` | 0-1 score for detecting the image was taken from a screen |
| `watermark_score` / `_reasons` / `_text` | 0-1 score for watermarks; `watermark_text` contains recognized text (e.g., "Shutterstock") |
| `painted_text_score` / `_reasons` | 0-1 score for hand-drawn or digitally painted text |
| `final_label` | Classification: `clean`, `doctored_unrealistic`, `screen_capture`, `watermarked`, `handdrawn`, `multiple_flags`, `inconclusive` |
| `final_confidence` | 0-1 overall confidence in the classification |

---

## Multi-Stage Prompt

Use this prompt (or adapt it) with a vision-capable AI model. The prompt processes the image through 6 sequential stages:

```text
Mobile Photo Authenticity Check — Multi-Stage Prompt

Objective:
Given a photo provided by a mobile device, evaluate it through multiple
analytical stages to determine:
1. If the photo has been doctored or altered in an unrealistic way.
2. If the photo has been taken from a computer screen rather than being
   an original capture of a real-world scene.
3. If the photo contains visible or partially obscured watermarks.

Instructions:
You must progress through the stages in sequence. At each stage, clearly
indicate whether the photo passes or fails, and explain the reasoning.

Output:
Return only the final JSON object in the specified schema—no extra text.

---

STAGE 1 — Quick Triage (visibility & quality):
1. Is the content visible and in focus enough to evaluate?
2. Are there heavy obstructions, extreme blur, or tiny resolution?
3. If evaluation is not feasible, mark evaluation_feasible=false and
   explain briefly.

---

STAGE 2 — "Doctored / Unrealistic" Screening:
Check for visual signs of synthetic or manipulated content. Consider:
- Physics & geometry: inconsistent shadows, impossible reflections,
  mismatched perspective/vanishing points, warped straight lines near edits.
- Material cues: plastic-like skin, repeated textures, smeared
  hair/eyelashes, "melting" edges, duplicated fingers/ears.
- Edge artifacts: halos, cut-out borders, fringing, mismatched depth of field.
- Compression anomalies: localized blockiness/quality shifts suggesting
  pasted regions.
- Lighting: inconsistent color temperature or specular highlights vs.
  environment.
- Text & patterns: deformed text/logos, repeated tiling.
- Context coherence: scale mismatches, impossible combinations.

Output:
- doctored_unrealistic_score (0-1)
- doctored_unrealistic_reasons (bullet list)

---

STAGE 3 — "Photo of a Screen" Screening:
Evidence the subject was displayed on a digital screen and re-photographed:
- Screen structure: visible pixel grid/subpixels, scanlines, PWM/refresh
  bands, moire.
- Device clues: bezels, notch, status bar, window chrome, cursor, taskbar,
  scroll bars.
- Optical clues: rectangular glare, Newton rings, rainbowing consistent
  with glass.
- Focus/parallax: focus on flat screen surface; keystone perspective of
  a monitor.
- White point/gamut: uniform backlight glow, overly blue/green whites.

Output:
- screen_capture_score (0-1)
- screen_capture_reasons (bullet list)

---

STAGE 4 — Watermark / Overlay Detection:
Detect watermarks or ownership/stock overlays:
- Typical forms: semi-transparent text/logos ("Getty Images",
  "Shutterstock", "Adobe Stock", creator handles), diagonal repeating
  patterns, corner logos, composited date/time stamps.
- Visual traits: consistent alpha translucency, uniform repetition,
  crisp overlay unaffected by scene lighting/perspective, different
  resolution/sharpness vs. underlying image.
- Placement: edges/corners/center diagonals; multiple repeats; tiling.
- Edge cases: distinguish legitimate camera UI overlays (e.g., timestamp)
  from stock watermarks.
- Context: note watermark content if legible but do not identify a person.

Output:
- watermark_score (0-1)
- watermark_reasons (bullet list)
- watermark_text (if recognized, e.g., "Shutterstock"; otherwise empty)

---

STAGE 5 — Detect Hand-Drawn or Painted-On Text:
Detect text manually added using a paint/drawing program:
- Look for uneven, non-font-based handwriting or shapes inconsistent
  with printed text
- Identify brush strokes, smudging, or digital pen artifacts
- Detect text blending poorly with the background or overlapping objects
  unnaturally
- Check for consistent resolution between text and the rest of the image

Output:
- painted_text_score (0-1)
- painted_text_reasons (bullet list)

---

STAGE 6 — Final Decision & Confidence:
- evaluation_feasible: boolean
- final_label: one of "clean", "doctored_unrealistic", "screen_capture",
  "watermarked", "handdrawn", "multiple_flags", "inconclusive"
- final_confidence (0-1): overall confidence in final_label
- Keep reasoning concise; cite visible cues only.

---

OUTPUT — JSON Schema (return only this):
{
  "evaluation_feasible": true,
  "doctored_unrealistic_score": 0.0,
  "doctored_unrealistic_reasons": [],
  "screen_capture_score": 0.0,
  "screen_capture_reasons": [],
  "watermark_score": 0.0,
  "watermark_reasons": [],
  "watermark_text": "",
  "painted_text_score": 0.0,
  "painted_text_reasons": [],
  "final_label": "clean",
  "final_confidence": 0.0
}
```

---

## Integration Tips

- **Threshold tuning**: Set a confidence threshold (e.g., 0.7) below which images are flagged for manual review rather than auto-rejected
- **Combine with other checks**: AI validation is one layer — combine with rate limiting, device fingerprinting, and uniqueness checks (see security reference)
- **Test thoroughly**: Run the prompt against known-good and known-fake images to calibrate detection accuracy and watch for hallucinations
- **Multiple models**: Consider using different AI providers as a cross-check for high-value rewards
