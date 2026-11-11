import type { ChatBody, ChatMessage, EmailBody, EventInfo, EventList, EventMe, LoginBody, LoginResult, Me, Ok, RegisterBody, RequestResult, ResetCodeBody, SearchQuery, SendRequestBody, SearchResults, VerifyCodeBody } from "./contracts";
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
type RequestMethod = "GET" | "POST" | "PATCH" | "DELETE";
type RequestOptions = { method?: RequestMethod; body?: unknown; signal?: AbortSignal };
const unavailable = "This part of Hacky isn’t available yet. Please try again later.";
const isAbort = (error: unknown) => error instanceof Error && error.name === "AbortError";

export function createApiClient(options: ClientOptions = {}) {
  const base = ((options.baseUrl ?? import.meta.env.VITE_API_URL)?.trim() || "/api").replace(/\/+$/, "");
  async function requestWithStatus<T>(path: string, method: RequestMethod, body?: unknown, signal?: AbortSignal, protectedRoute = false) {
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
    return { data: data as T, status: response.status };
  }
  async function request<T>(...args: Parameters<typeof requestWithStatus>): Promise<T> {
    return (await requestWithStatus<T>(...args)).data;
  }
  return {
    authenticated<T>(path: string, { method = "GET", body, signal }: RequestOptions = {}) {
      return request<T>(path, method, body, signal, true);
    },
    async register(body: RegisterBody, signal?: AbortSignal) {
      const { status } = await requestWithStatus<Ok>("/auth/register", "POST", body, signal);
      // The link API creates an account (201); the code API starts a pending signup (200).
      return status === 201 ? "link" : "code";
    },
    verifyEmail: (body: VerifyCodeBody, signal?: AbortSignal) => request<LoginResult>("/auth/verify-email", "POST", body, signal),
    verifyEmailLink: (token: string, signal?: AbortSignal) => request<Ok>("/auth/verify-email", "POST", { token }, signal),
    resendVerification: (body: EmailBody, signal?: AbortSignal) => request<Ok>("/auth/resend-verification", "POST", body, signal),
    login: (body: LoginBody, signal?: AbortSignal) => request<LoginResult>("/auth/login", "POST", body, signal),
    forgotPassword: (body: EmailBody, signal?: AbortSignal) => request<Ok>("/auth/forgot-password", "POST", body, signal),
    resetPassword: (body: ResetCodeBody, signal?: AbortSignal) => request<LoginResult>("/auth/reset-password", "POST", body, signal),
    resetPasswordLink: (token: string, password: string, signal?: AbortSignal) => request<Ok>("/auth/reset-password", "POST", { token, password }, signal),
    getMe: (signal?: AbortSignal) => request<Me>("/me", "GET", undefined, signal, true),
    listEvents: (signal?: AbortSignal) => request<EventList>("/events", "GET", undefined, signal, true),
    getEvent: (slug: string, signal?: AbortSignal) => request<EventInfo>(`/events/${encodeURIComponent(slug)}`, "GET", undefined, signal, true),
    getEventMe: (slug: string, signal?: AbortSignal) => request<EventMe>(`/events/${encodeURIComponent(slug)}/me`, "GET", undefined, signal, true),
    joinEvent: (slug: string, signal?: AbortSignal) => request<EventMe>(`/events/${encodeURIComponent(slug)}/join`, "POST", undefined, signal, true),
    getChatHistory: (slug: string, signal?: AbortSignal) => request<{ messages: ChatMessage[] }>(`/events/${encodeURIComponent(slug)}/chat`, "GET", undefined, signal, true),
    // ?format=json: the whole answer at once (the server doesn't stream yet).
    sendChat: (slug: string, body: ChatBody, signal?: AbortSignal) => request<{ message: ChatMessage }>(`/events/${encodeURIComponent(slug)}/chat?format=json`, "POST", body, signal, true),
    sendRequest: (slug: string, body: SendRequestBody, signal?: AbortSignal) => request<RequestResult>(`/events/${encodeURIComponent(slug)}/requests`, "POST", body, signal, true),
    searchPeople(query: SearchQuery, signal?: AbortSignal) {
      const params = new URLSearchParams({ event: query.event, q: query.q });
      if (query.role) params.set("role", query.role);
      if (query.limit !== undefined) params.set("limit", String(query.limit));
      return request<SearchResults>(`/search?${params}`, "GET", undefined, signal, true);
    },
  };
}

export const api = createApiClient();
