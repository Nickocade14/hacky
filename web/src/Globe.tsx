export function Globe() {
  return (
    <svg className="hero-globe" viewBox="0 0 320 320" aria-hidden="true" focusable="false">
      <g transform="rotate(-24 160 160)" fill="none" stroke="currentColor" strokeWidth="13" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="160" cy="160" r="140" />
        <ellipse cx="160" cy="160" rx="68" ry="140" />
        <path d="M160 20v280" />
        <path d="M40 88c65 47 175 47 240 0M20 160c80 53 200 53 280 0M40 232c65 47 175 47 240 0" />
      </g>
    </svg>
  );
}
