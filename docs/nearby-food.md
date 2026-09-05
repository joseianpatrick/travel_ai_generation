# Nearby Food

Restaurant discovery anchored to the currently selected itinerary day.

**Route:** `/nearby-food` (name `nearby-food`), fourth bottom-tab branch.

## Current state

This is deliberately a placeholder. If a trip and day are selected, it names
that day as the future discovery area; otherwise it prompts the user to open
an itinerary first. It makes no network requests and consumes no AI or Google
Cloud quota.

The itinerary's **Find nearby food** button is available now as the free
fallback: it opens a restaurant search in an external maps app centered on
the selected day's stored latitude and longitude.

## Planned evolution

The future feature will use a dedicated restaurant-discovery repository and
MobX store to retrieve provider results around the active itinerary day. The
tab will render restaurant cards and filters for cuisine, price, and rating.
An optional AI summary may be layered over those provider results later; it is
not part of the current implementation.
