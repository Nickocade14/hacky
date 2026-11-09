# Hacky interaction diagrams

The API operations and response shapes are defined in [OpenAPI](openapi.yaml).

## Sequence diagram · Registration and first login

```mermaid
sequenceDiagram
    actor Attendee
    participant Client as React or Flutter
    participant API as Express API
    participant DB as MongoDB
    participant Mail as Email provider

    Attendee->>Client: Submit name, username, email and password
    Client->>API: POST /api/auth/register
    API->>DB: Check the email and username aren't taken
    API->>DB: Save a pending sign-up (code hash, expires in 10 min)
    API->>Mail: Send the 6-digit code
    API-->>Client: Code sent
    Mail-->>Attendee: Deliver the code
    Attendee->>Client: Type the code
    Client->>API: POST /api/auth/verify-email
    API->>DB: Count the try and compare the code
    alt Code is right
        API->>DB: In one transaction, use up the sign-up and create the user and profile
        API-->>Client: JWT, expiry, and account details
        Client-->>Attendee: Open Home, already logged in
    else Wrong, expired, or 5 tries used
        API-->>Client: Invalid code
        Client-->>Attendee: Show the error and offer a new code
    end
```

An unverified sign-up is deleted after 10 minutes, so it never keeps the email or the username.

## Activity diagram · Search for event participants

```mermaid
flowchart TD
    Start((Start)) --> SignIn[Sign in]
    SignIn --> Events{Account belongs to an event?}
    Events -->|No| NoEvent[Show the event membership requirement]
    Events -->|Yes| Query[Choose event, enter part of a name, handle, or skill]
    Query --> Request[Send search request with the Bearer token]
    Request --> Allowed{API accepts token and event membership?}
    Allowed -->|Session expired| SignIn
    Allowed -->|Access denied| Problem[Show access error]
    Allowed -->|Yes| Matches{Any matches?}
    Matches -->|Yes| Results[Show matching participants]
    Matches -->|No| Empty[Show no results]
    Results --> Again{Search again?}
    Empty --> Again
    Again -->|Yes| Query
    Again -->|No| End((End))
    NoEvent --> End
    Problem --> End
```

## Use case diagram · Hacky system scope

The use cases below describe the project scope in the contract, including features developed by other team members.

```mermaid
flowchart LR
    Attendee["«actor» Event participant"]
    Mentor["«actor» Mentor"]
    Mail["«actor» Email provider"]

    subgraph System[Hacky]
        Register([Register and verify email])
        Login([Log in])
        Reset([Recover password])
        Join([Join a hackathon event])
        Search([Find teammates or mentors])
        Recommend([Ask Hacky for recommendations])
        Connect([Send or accept a connection request])
        Chat([Message connections])
        RequestHelp([Request mentor help])
        ResolveHelp([Claim and resolve a help request])
    end

    Attendee --- Register
    Attendee --- Login
    Attendee --- Reset
    Attendee --- Join
    Attendee --- Search
    Attendee --- Recommend
    Attendee --- Connect
    Attendee --- Chat
    Attendee --- RequestHelp
    Mentor -. specializes .-> Attendee
    Mentor --- ResolveHelp
    Register --- Mail
    Reset --- Mail
```
