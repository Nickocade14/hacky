import { api } from "./api";
import type { components, operations } from "./schema";

export type PersonDetail = components["schemas"]["PersonDetail"];
export type ConnectionRequest = components["schemas"]["ConnectionRequest"];

type RequestList = operations["listRequests"]["responses"][200]["content"]["application/json"];
type RequestResult = components["schemas"]["RequestResult"];
type Ok = components["schemas"]["Ok"];

export const eventPath = (path: string, slug?: string) => slug ? `${path}?event=${encodeURIComponent(slug)}` : path;
export const personPath = (handle: string, slug?: string) => eventPath(`/people/${encodeURIComponent(handle)}`, slug);
export const chatPath = (id: string, slug?: string) => eventPath(`/chats/${encodeURIComponent(id)}`, slug);

export function getPerson(slug: string, handle: string, signal?: AbortSignal) {
  return api.authenticated<PersonDetail>(`/events/${encodeURIComponent(slug)}${personPath(handle)}`, { signal });
}

export async function listConnectionRequests(slug: string, signal?: AbortSignal) {
  const result = await api.authenticated<RequestList>(`/events/${encodeURIComponent(slug)}/requests`, { signal });
  return result.requests;
}

export function acceptConnectionRequest(id: string, signal?: AbortSignal) {
  return api.authenticated<RequestResult>(`/requests/${encodeURIComponent(id)}/accept`, { method: "POST", signal });
}

export function hideConnectionRequest(id: string, signal?: AbortSignal) {
  return api.authenticated<Ok>(`/requests/${encodeURIComponent(id)}/hide`, { method: "POST", signal });
}

export function blockPerson(userId: string, signal?: AbortSignal) {
  return api.authenticated<Ok>("/blocks", { method: "POST", body: { userId }, signal });
}
