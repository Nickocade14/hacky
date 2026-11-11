import { useEffect, useState, type FormEvent } from "react";
import { Link } from "react-router-dom";
import { Field, Notice, useFormAction } from "./components";
import { PersonAvatar, useSignedIn } from "./SignedInShell";
import { api, ApiClientError } from "./lib/api";
import type { EventInfo, EventMe } from "./lib/contracts";
import {
  eventChanges, eventDraft, eventProblem, linkFields, profileChanges, profileDraft, profileProblem,
  styleOptions, type EventDraft, type PublicProfile,
} from "./lib/profile";
import "./my-profile.css";

const availabilityOptions = { available: "Available", busy: "Busy", offline: "Offline" };
const experienceOptions = { beginner: "Beginner", intermediate: "Intermediate", advanced: "Advanced" };
const goalOptions = { win: "Win", learn: "Learn", ship: "Ship" };
const motivations = [
  ["build", "Build something"], ["learn", "Learn something"], ["meet", "Meet my people"],
  ["career", "Grow my career"], ["compete", "Win a prize"], ["fun", "Have fun"],
] as const;

function ChoiceField({ id, label, value, options, onChange, optional = false }: {
  id: string;
  label: string;
  value: string;
  options: Record<string, string>;
  onChange: (value: string) => void;
  optional?: boolean;
}) {
  return <div className="field">
    <label htmlFor={id}>{label}</label>
    <select id={id} value={value} onChange={event => onChange(event.target.value)}>
      {optional && <option value="">Choose later</option>}
      {Object.entries(options).map(([value, text]) => <option key={value} value={value}>{text}</option>)}
    </select>
  </div>;
}

function TagFields({ id, label, values, placeholder, onChange }: {
  id: string;
  label: string;
  values: string[];
  placeholder: string;
  onChange: (values: string[]) => void;
}) {
  return <fieldset className="profile-tags">
    <legend>{label}</legend>
    {values.map((value, index) => <div className="profile-tag-row" key={index}>
      <input id={`${id}-${index}`} aria-label={`${label} ${index + 1}`} value={value}
        placeholder={placeholder} maxLength={40}
        onChange={event => onChange(values.map((tag, i) => i === index ? event.target.value : tag))} />
      <button className="text-button" type="button" aria-label={`Remove ${value || label}`}
        onClick={() => onChange(values.filter((_, i) => i !== index))}>Remove</button>
    </div>)}
    <button className="button secondary" type="button" aria-label={`Add entry to ${label}`}
      disabled={values.length >= 30} onClick={() => onChange([...values, ""])}>Add</button>
  </fieldset>;
}

function EventFields({ info, value, onChange }: {
  info: EventInfo;
  value: EventDraft;
  onChange: (value: EventDraft) => void;
}) {
  const tracks = new Set(info.tracks);
  if (value.track) tracks.add(value.track);
  const trackOptions = Object.fromEntries([...tracks].map(track => [track, track]));
  return <section className="workspace-card profile-card" aria-labelledby="profile-event-title">
    <h2 id="profile-event-title">{info.name}</h2>
    <TagFields id="profile-skills" label="Skills" placeholder="e.g. React" values={value.skills}
      onChange={skills => onChange({ ...value, skills })} />
    <TagFields id="profile-skills-wanted" label="Skills you want to learn" placeholder="e.g. Flutter" values={value.skillsWanted}
      onChange={skillsWanted => onChange({ ...value, skillsWanted })} />
    <TagFields id="profile-interests" label="Interests" placeholder="e.g. Climate" values={value.interests}
      onChange={interests => onChange({ ...value, interests })} />
    <div className="profile-grid">
      <ChoiceField id="profile-experience" label="Experience" value={value.experience ?? ""}
        options={experienceOptions} optional onChange={experience => onChange({ ...value, experience: (experience || null) as EventDraft["experience"] })} />
      <ChoiceField id="profile-goal" label="Goal" value={value.goal ?? ""}
        options={goalOptions} optional onChange={goal => onChange({ ...value, goal: (goal || null) as EventDraft["goal"] })} />
      {tracks.size > 0 && <ChoiceField id="profile-track" label="Track" value={value.track ?? ""}
        options={trackOptions} optional onChange={track => onChange({ ...value, track: track || null })} />}
      <ChoiceField id="profile-availability" label="Availability" value={value.availability}
        options={availabilityOptions} onChange={availability => onChange({ ...value, availability: availability as EventDraft["availability"] })} />
    </div>
    <label className="profile-check"><input type="checkbox" checked={value.looking}
      onChange={event => onChange({ ...value, looking: event.target.checked })} /> Looking for a team</label>
    <label className="profile-check"><input type="checkbox" checked={value.wantsExperienced}
      onChange={event => onChange({ ...value, wantsExperienced: event.target.checked })} /> Prefer experienced teammates</label>
    <fieldset className="profile-motivations">
      <legend>Hackathon goals</legend>
      {motivations.map(([id, label]) => <label className="profile-check" key={id}>
        <input type="checkbox" checked={value.motivations.includes(id)} onChange={event => onChange({
          ...value,
          motivations: event.target.checked
            ? [...value.motivations, id]
            : value.motivations.filter(item => item !== id),
        })} /> {label}
      </label>)}
    </fieldset>
    <div className="field">
      <label htmlFor="profile-idea">Interests &amp; ideas</label>
      <textarea id="profile-idea" rows={3} maxLength={2000} value={value.idea ?? ""}
        placeholder="What are you building, learning, or hoping to find?"
        onChange={event => onChange({ ...value, idea: event.target.value })} />
    </div>
  </section>;
}

function ProfileEditor() {
  const { me, event, onExpired, onProfileChanged } = useSignedIn();
  const [savedProfile, setSavedProfile] = useState(me.profile);
  const [publicDraft, setPublicDraft] = useState(() => profileDraft(me.profile));
  const [eventState, setEventState] = useState<{ info: EventInfo; saved: EventMe; draft: EventDraft } | null>(null);
  const [eventError, setEventError] = useState<string>();
  const [retry, setRetry] = useState(0);
  const [savedNotice, setSavedNotice] = useState(false);
  const action = useFormAction();
  const slug = event?.slug;
  const membershipPath = slug ? `/events/${encodeURIComponent(slug)}/me` : undefined;

  useEffect(() => {
    if (!slug) return;
    const controller = new AbortController();
    const { signal } = controller;
    Promise.all([api.getEvent(slug, signal), api.getEventMe(slug, signal)])
      .then(([info, saved]) => {
        if (!signal.aborted) setEventState({ info, saved, draft: eventDraft(saved) });
      })
      .catch((failure: unknown) => {
        if (signal.aborted) return;
        if (failure instanceof ApiClientError && failure.status === 401) onExpired();
        else setEventError(failure instanceof Error ? failure.message : "Couldn’t load your event details.");
      });
    return () => controller.abort();
  }, [slug, retry, onExpired]);

  const profilePatch = profileChanges(publicDraft, savedProfile);
  const eventPatch = eventState ? eventChanges(eventState.draft, eventState.saved) : {};
  const hasProfileChanges = Object.keys(profilePatch).length > 0;
  const hasEventChanges = Object.keys(eventPatch).length > 0;
  const dirty = hasProfileChanges || hasEventChanges;

  function save(submit: FormEvent<HTMLFormElement>) {
    submit.preventDefault();
    if (!dirty || action.busy) return;
    const problem = profileProblem(profilePatch) ?? eventProblem(eventPatch);
    if (problem) { action.setError(problem); return; }
    setSavedNotice(false);
    void action.run(async signal => {
      let profileSaved = false;
      try {
        if (hasProfileChanges) {
          const profile = await api.authenticated<PublicProfile>("/me/profile", { method: "PATCH", body: profilePatch });
          onProfileChanged(profile);
          if (signal.aborted) return;
          setSavedProfile(profile);
          setPublicDraft(profileDraft(profile));
          profileSaved = true;
        }
        if (membershipPath && eventState && hasEventChanges) {
          const saved = await api.authenticated<EventMe>(membershipPath, { method: "PATCH", body: eventPatch });
          if (signal.aborted) return;
          setEventState({ info: eventState.info, saved, draft: eventDraft(saved) });
        }
        setSavedNotice(true);
      } catch (failure) {
        if (signal.aborted) return;
        if (failure instanceof ApiClientError && failure.status === 401) { onExpired(); return; }
        if (profileSaved) {
          const message = failure instanceof Error ? failure.message : "Try again.";
          throw new Error(`Your public profile was saved. Your event details still need to be saved. ${message}`);
        }
        throw failure;
      }
    });
  }

  return <form className="profile-editor" aria-label="Edit your profile" aria-busy={action.busy} onSubmit={save}>
    <header className="workspace-heading">
      <h1 tabIndex={-1}>My profile</h1>
    </header>
    <section className="workspace-card workspace-identity">
      <PersonAvatar name={savedProfile.name} photoUrl={savedProfile.photoUrl} />
      <h2>{savedProfile.name}</h2>
      <p>@{savedProfile.handle}</p>
    </section>
    <fieldset className="profile-fields" disabled={action.busy}>
      <section className="workspace-card profile-card" aria-labelledby="profile-public-title">
        <h2 id="profile-public-title">Public profile</h2>
        <Field id="profile-name" label="Name" value={publicDraft.name} required maxLength={80} autoComplete="name"
          onChange={event => setPublicDraft({ ...publicDraft, name: event.target.value })} />
        <div className="field">
          <label htmlFor="profile-bio">Bio</label>
          <textarea id="profile-bio" value={publicDraft.bio} maxLength={500} rows={3}
            onChange={event => setPublicDraft({ ...publicDraft, bio: event.target.value })} />
        </div>
        {linkFields.map(([field, label]) => <Field key={field} id={`profile-${field}`} label={label}
          inputMode="url" maxLength={300} placeholder="https://" value={publicDraft.links[field]}
          onChange={event => setPublicDraft({ ...publicDraft, links: { ...publicDraft.links, [field]: event.target.value } })} />)}
      </section>
      <section className="workspace-card profile-card" aria-labelledby="profile-style-title">
        <h2 id="profile-style-title">Hacky style</h2>
        <div className="profile-mascot" aria-hidden="true" data-color={publicDraft.look.color}
          data-flair={publicDraft.look.flair} data-move={publicDraft.look.move}>
          <img src="/assets/mascots/hacky-knit.webp" alt="" width={88} height={88} />
        </div>
        <div className="profile-grid">
          {(Object.keys(styleOptions) as (keyof typeof styleOptions)[]).map((field) => <ChoiceField key={field}
            id={`profile-style-${field}`} label={{ color: "Color", flair: "Flair", move: "Move" }[field]}
            value={publicDraft.look[field]} options={styleOptions[field]}
            onChange={value => setPublicDraft({ ...publicDraft, look: { ...publicDraft.look, [field]: value } })} />)}
        </div>
      </section>
      {eventState && <EventFields info={eventState.info} value={eventState.draft}
        onChange={draft => setEventState({ ...eventState, draft })} />}
      {slug && !eventState && <section className="workspace-card profile-card" aria-label="Event details">
        {eventError ? <>
          <Notice error>{eventError}</Notice>
          <button className="button secondary" type="button"
            onClick={() => { setEventError(undefined); setRetry(count => count + 1); }}>Try again</button>
        </> : <p role="status">Loading your event details…</p>}
      </section>}
      {!slug && <p><Link to="/app">Join an event on Home</Link> to add your skills and what you want to build there.</p>}
    </fieldset>
    {action.error && <Notice error>{action.error}</Notice>}
    {!dirty && savedNotice && <Notice>Changes saved.</Notice>}
    <div className="workspace-actions">
      <button className="button primary" type="submit" disabled={!dirty || action.busy}>
        {action.busy ? "Saving…" : "Save changes"}
      </button>
    </div>
  </form>;
}

export function MyProfilePage() {
  const { me, event } = useSignedIn();
  return <ProfileEditor key={`${me.profile.userId}:${event?.slug ?? ""}`} />;
}
