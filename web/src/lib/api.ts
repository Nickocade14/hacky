import type { EmailBody, LoginBody, LoginResult, Me, Ok, RegisterBody, ResetPasswordBody, TokenBody } from "./contracts";
import { readSession } from "./session";

type ErrorKind = "api" | "network" | "server" | "unavailable" | "unauthorized";
export class ApiClientError extends Error {
  readonly name = "ApiClientError";
  constructor(
    readonly kind: ErrorKind,
    message: string,
    readonly status?: number,
    readonly code?: string,
    readonly details?: unknown,
  ) { super(message); }
}

type ClientOptions = { baseUrl?: string; fetch?: typeof fetch; getToken?: () => string | null | undefined };
const unavailable = "This part of Hacky isn’t available yet. Please try again later.";
const isAbort = (error: unknown) => error instanceof Error && error.name === "AbortError";

export function createApiClient(options: ClientOptions = {}) {
  const base = ((options.baseUrl ?? import.meta.env.VITE_API_URL)?.trim() || "/api").replace(/\/+$/, "");
  async function request<T>(path: string, method: "GET" | "POST", body?: unknown, signal?: AbortSignal, protectedRoute = false): Promise<T> {
    const headers = new Headers({ Accept: "application/json" });
    if (body !== undefined) headers.set("Content-Type", "application/json");
    if (protectedRoute) {
      const token = options.getToken ? options.getToken() : readSession()?.token;
      if (!token) throw new ApiClientError("unauthorized", "Please log in to continue.", 401, "unauthorized");
      headers.set("Authorization", `Bearer ${token}`);
    }
    let response: Response;
    try {
      response = await (options.fetch ?? globalThis.fetch)(`${base}${path}`, {
        method, headers, signal, credentials: "omit",
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      });
    } catch (error) {
      if (isAbort(error) || signal?.aborted) throw error;
      throw new ApiClientError("network", "Can’t reach Hacky. Check your connection and try again.");
    }
    let data: unknown;
    try { data = await response.json(); }
    catch (error) {
      if (isAbort(error) || signal?.aborted) throw error;
      throw new ApiClientError(response.status === 404 || response.status === 501 ? "unavailable" : "server", response.status === 404 || response.status === 501 ? unavailable : "Hacky sent an unexpected response. Please try again.", response.status);
    }
    if (!response.ok) {
      const envelope = data as { error?: { message?: unknown; code?: unknown; details?: unknown } } | null;
      const error = envelope && typeof envelope === "object" ? envelope.error : undefined;
      const message = typeof error?.message === "string" ? error.message : response.status === 404 || response.status === 501 ? unavailable : "Something went wrong. Please try again.";
      const code = typeof error?.code === "string" ? error.code : undefined;
      const kind = response.status === 401 && protectedRoute ? "unauthorized" : response.status === 404 || response.status === 501 ? "unavailable" : response.status >= 500 ? "server" : "api";
      throw new ApiClientError(kind, message, response.status, code, error?.details);
    }
    if (!data || typeof data !== "object" || Array.isArray(data)) throw new ApiClientError("server", "Hacky sent an unexpected response. Please try again.", response.status);
    return data as T;
  }
  return {
    register: (body: RegisterBody, signal?: AbortSignal) => request<Ok>("/auth/register", "POST", body, signal),
    verifyEmail: (body: TokenBody, signal?: AbortSignal) => request<Ok>("/auth/verify-email", "POST", body, signal),
    resendVerification: (body: EmailBody, signal?: AbortSignal) => request<Ok>("/auth/resend-verification", "POST", body, signal),
    login: (body: LoginBody, signal?: AbortSignal) => request<LoginResult>("/auth/login", "POST", body, signal),
    forgotPassword: (body: EmailBody, signal?: AbortSignal) => request<Ok>("/auth/forgot-password", "POST", body, signal),
    resetPassword: (body: ResetPasswordBody, signal?: AbortSignal) => request<Ok>("/auth/reset-password", "POST", body, signal),
    getMe: (signal?: AbortSignal) => request<Me>("/me", "GET", undefined, signal, true),
  };
}

export const api = createApiClient();
