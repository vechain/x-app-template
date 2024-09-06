import { getPicassoImgSrc } from "./PicassoUtils";
import { describe, expect } from "vitest";

describe("getPicassoImgSrc", () => {
  test('returns a base64 encoded string when "base64" argument is true', () => {
    const result = getPicassoImgSrc("0x5f5e", true);
    expect(result.startsWith("data:image/svg+xml;base64,")).toBe(true);
  });

  test('returns a non-base64 encoded string when "base64" argument is false', () => {
    const result = getPicassoImgSrc("0x5f5e");
    expect(result.startsWith("data:image/svg+xml;utf8,")).toBe(true);
  });
});
