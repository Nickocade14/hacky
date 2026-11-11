// Line icons for the workspace chrome. 24px grid, stroked with currentColor.
const paths = {
  chat: "M5 5h14v10H9l-4 4zM9 9h6M9 12h4",
  moon: "M20 14.5A8 8 0 0 1 9.5 4 8 8 0 1 0 20 14.5Z",
  sun: "M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8ZM12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4",
  close: "M6 6l12 12M18 6 6 18",
  back: "M15 5l-7 7 7 7",
  people: "M11 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM3 21v-1a6 6 0 0 1 6-6h4a6 6 0 0 1 3 .8M21 21l-2.6-2.6M19.5 16a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0Z",
  events: "M4 8a3 3 0 0 1 3-3h10a3 3 0 0 1 3 3v10a3 3 0 0 1-3 3H7a3 3 0 0 1-3-3ZM8 3v4M16 3v4M4 10h16M9 15l2 2 4-4",
  send: "M12 19V5M6 11l6-6 6 6",
  restart: "M4 10a8 8 0 1 1 1 7M4 4v6h6",
} as const;

export function Icon({ name }: { name: keyof typeof paths }) {
  return <svg className="hk-svg" aria-hidden="true" viewBox="0 0 24 24"><path d={paths[name]} /></svg>;
}
