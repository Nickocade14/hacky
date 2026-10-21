import bcrypt from "bcrypt";
import { z } from "zod";

// OpenAPI minLength counts Unicode code points; bcrypt's limit counts UTF-8 bytes.
export const passwordSchema = z.string()
  .refine((value) => [...value].length >= 8, "Password must contain at least 8 characters")
  .refine((value) => Buffer.byteLength(value, "utf8") <= 72, "Password must be at most 72 UTF-8 bytes");

export const registerBodySchema = z.object({
  name: z.string().trim().min(1).max(80),
  handle: z.string().trim().toLowerCase().regex(/^[a-z0-9_]{3,30}$/),
  email: z.email().max(254).transform((value) => value.toLowerCase()),
  password: passwordSchema,
});

export const resetPasswordBodySchema = z.object({
  token: z.string().min(1).max(200),
  password: passwordSchema,
});

// Auth routes should use this helper so bcrypt never silently truncates input.
export function hashPassword(raw: string): Promise<string> {
  return bcrypt.hash(passwordSchema.parse(raw), 12);
}
