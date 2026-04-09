# Frontend Implementation Guide: Group Management + Permissions

This document covers the backend group-management changes and what frontend now needs to implement.

## 1) New behavior summary

- Group creator is the `owner` (also admin by default).
- One group can have multiple admins.
- Owner can promote/demote admins.
- Owner and admins can add/remove members.
- Owner cannot be removed from group.
- Member roles are now exposed by API: `owner | admin | member`.

## 2) Frontend features to build

- Group member list with role badges (`owner`, `admin`, `member`).
- Role-based action controls:
  - If user role is `owner`: show add/remove member + promote/demote admin actions.
  - If user role is `admin`: show add/remove member actions only.
  - If user role is `member`: hide group-management actions.
- Admin management UI:
  - List current admins.
  - Promote member to admin.
  - Demote delegated admin.
- Group details refresh on websocket `reload_groups` event.
- Error-state handling for `403`, `404`, and `400` responses in management actions.

## 3) API changes (existing endpoints)

## 3.1 `GET /domains/group-conversations?domain=<myDomain>`

Still used to fetch group list for a domain.

### Response change

`metadata.owner` is now included in each group item.

Before:

```json
{
  "conversationId": "group-123",
  "withDomain": "alice.doma",
  "createdAt": "...",
  "metadata": {
    "admin": "alice.doma",
    "name": "Team"
  }
}
```

Now:

```json
{
  "conversationId": "group-123",
  "withDomain": "alice.doma",
  "createdAt": "...",
  "metadata": {
    "admin": "alice.doma",
    "owner": "alice.doma",
    "name": "Team"
  }
}
```

## 3.2 `GET /domains/group-conversations/members?conversationId=<id>`

Still used to fetch members.

### Response change

Each member now includes `role`.

Before:

```json
[
  { "domain": "alice.doma", "wallet": "0x...", "name": "Alice" },
  { "domain": "bob.doma", "wallet": "0x...", "name": "Bob" }
]
```

Now:

```json
[
  { "domain": "alice.doma", "wallet": "0x...", "name": "Alice", "role": "owner" },
  { "domain": "bob.doma", "wallet": "0x...", "name": "Bob", "role": "admin" },
  { "domain": "charlie.doma", "wallet": "0x...", "name": "Charlie", "role": "member" }
]
```

Also now returns `404` if group conversation is not found.

## 3.3 `POST /domains/group-conversations`

Endpoint is now dual-purpose:

- Create new group.
- Add member to existing group.

### Recommended request body keys

```json
{
  "conversationId": "group-123",
  "memberDomain": "alice.doma",
  "groupName": "Team Alpha",
  "actorDomain": "alice.doma"
}
```

### Create new group

- Required: `conversationId`, `memberDomain` (or legacy `domain`), `groupName`.
- `actorDomain` not required for first create.
- Returns: `204`.

### Add member to existing group

- Required: `conversationId`, `memberDomain` (or legacy `domain`), `actorDomain`.
- `actorDomain` must be owner/admin.
- Returns: `204`.

### Important validation responses

- `400`: missing required fields or profile/domain invalid.
- `403`: actor is not owner/admin for add-member action.
- `404`: not used here for missing group during add; behavior is create path if metadata absent.

## 4) New endpoints for admin/member management

## 4.1 Remove member

`DELETE /domains/group-conversations/members`

Request body:

```json
{
  "conversationId": "group-123",
  "actorDomain": "alice.doma",
  "memberDomain": "charlie.doma"
}
```

Behavior:

- Allowed for owner/admin.
- Owner cannot be removed.
- If removed member was delegated admin, admin role is removed too.
- Returns `204` on success.

## 4.2 List admins

`GET /domains/group-conversations/admins?conversationId=<id>`

Response:

```json
{
  "conversationId": "group-123",
  "owner": "alice.doma",
  "delegatedAdmins": ["bob.doma", "dave.doma"],
  "admins": ["alice.doma", "bob.doma", "dave.doma"]
}
```

## 4.3 Promote member to admin

`POST /domains/group-conversations/admins`

Request body:

```json
{
  "conversationId": "group-123",
  "actorDomain": "alice.doma",
  "targetAdminDomain": "bob.doma"
}
```

Behavior:

- Only owner can promote.
- Target must already be a member.
- Returns `204`.

## 4.4 Demote delegated admin

`DELETE /domains/group-conversations/admins`

Request body:

```json
{
  "conversationId": "group-123",
  "ownerDomain": "alice.doma",
  "adminDomain": "bob.doma"
}
```

Behavior:

- Only owner can demote.
- Owner cannot demote self.
- Returns `204`.

## 5) Suggested frontend API wrapper methods

- `getGroupConversations(domain)`
- `getGroupMembers(conversationId)` -> returns members with `role`
- `createGroup({ conversationId, memberDomain, groupName })`
- `addGroupMember({ conversationId, actorDomain, memberDomain })`
- `removeGroupMember({ conversationId, actorDomain, memberDomain })`
- `getGroupAdmins(conversationId)`
- `promoteGroupAdmin({ conversationId, actorDomain, targetAdminDomain })`
- `demoteGroupAdmin({ conversationId, ownerDomain, adminDomain })`

Use canonical keys above, even though backend accepts a few legacy aliases.

## 6) Role gating rules for UI

- Current user role = from `GET /group-conversations/members` by matching `domain`.
- If role is `owner`:
  - Can add/remove members.
  - Can promote/demote admins.
- If role is `admin`:
  - Can add/remove members.
  - Cannot promote/demote admins.
- If role is `member`:
  - No management actions.

## 7) Websocket refresh behavior

Server already broadcasts `reload_groups` for:

- Group create
- Member add
- Member remove
- Admin promote
- Admin demote

Frontend should refresh:

- Group list
- Group members (if group details screen is open)
- Group admins (if admin screen is open)

## 8) Integration notes

- Backend migration required before using admin endpoints:
  - `domain_group_admins` table must exist.
- Group-management endpoints currently use domain values from request body for authorization checks.
- Keep frontend source of truth for acting domain from authenticated session/user identity.
