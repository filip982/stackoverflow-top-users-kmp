# StackOverflow Users

Building on the take-home portion of this exercise, the intention of this live-coding exercise is to expand on the functionality of your solution.

## Functional Requirements

- Tapping on a user cell should present a detail view for the selected user
- The detail view should show the following information:
  - Profile picture
  - Name
  - Reputation
  - "Follow" status, and a follow toggle
  - Location
  - Website URL (if available)

## Technical Specifications

- Additional functionality should be covered by unit tests.
- Write in Swift - no Objective-C.
- No 3rd party frameworks - we want to see what you can do!
- Please avoid using AI to write this feature

## Wireframe

```
┌─────────────────────────────┐
│        USER DETAILS         │
├─────────────────────────────┤
│      ┌───────────┐          │
│      │     ◯     │ ←──────── User profile picture
│      │    /│\    │          │
│      └───────────┘          │
│                             │
│   NAME                      │
│   REPUTATION                │
│   LOCATION                  │
│   WEBSITE URL               │
│                             │
│   ┌─────────────────────┐   │
│   │   FOLLOW/UNFOLLOW   │ ←── Toggle button based on
│   └─────────────────────┘   │   current follow status
│                             │
└─────────────────────────────┘
```

## Stretch Goal

Extend the functionality so the user can select different sort options, with results listed in ascending and descending order.

There are several sort options available through the Stack Exchange API:

- **reputation** – `reputation`
- **creation** – `creation_date`
- **name** – `display_name`
- **modified** – `last_modified_date`

`reputation` is the default sort.

## Stretch Goal Wireframe

```
┌─────────────────────────────┐
│        SORT OPTIONS         │
├─────────────────────────────┤
│   ☐ REPUTATION              │
│   ☐ NAME                    │ ←── Radio group - only
│   ☐ DATE CREATED            │     one may be selected
│   ☐ DATE UPDATED            │     at any time
│                             │
│   ┌──────────┬──────────┐   │
│   │ASCENDING │DESCENDING│   │
│   └──────────┴──────────┘   │
│                             │
│   ┌─────────────────────┐   │
│   │       APPLY         │ ←── Close and apply the
│   └─────────────────────┘   │   selected sort options
│   ┌─────────────────────┐   │
│   │       CANCEL        │ ←── Cancel and close without
│   └─────────────────────┘   │   applying
│                             │
└─────────────────────────────┘
```
