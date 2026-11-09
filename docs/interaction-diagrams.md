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
    participant Verify as Web verification page

    Attendee->>Client: Submit registration
    Client->>API: POST /api/auth/register
    API->>DB: Save user and profile in one transaction
    API->>DB: Store verification token hash
    API->>Mail: Send verification link
    API-->>Client: Account created
    Mail-->>Attendee: Deliver verification email
    Attendee->>Verify: Open link and confirm email
    Verify->>API: POST /api/auth/verify-email
    API->>DB: Look up and consume the verification token
    alt Token is valid
        API->>DB: Mark email verified
        API-->>Verify: Email verified
        Attendee->>Client: Submit login credentials
        Client->>API: POST /api/auth/login
        API->>DB: Read password hash, verification status, and profile
        API-->>Client: JWT, expiry, and account details
    else Token is missing, used, or expired
        API-->>Verify: Invalid token
        Verify-->>Attendee: Offer to resend verification email
    end
```

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
