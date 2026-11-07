---
name: uber.com
display: Uber
domains: [uber.com, www.uber.com, m.uber.com]
aliases: [Uber, uber ride]
apps: []
validated: pending
platform: harmonyos
---
# Uber

- Open https://m.uber.com in the built-in browser.
- Read the page and use the visible text on links and buttons; never invent coordinates.
- Signing in is handed to the user.
- **Any ride request is a payment-classified action: always ask before confirming.**
  Show the pickup, destination, ride type and price when the page shows them.

## Common flow

1. Set pickup.
2. Set destination.
3. Compare ride types and prices.
4. Request the ride — approval required.

## Limits

- Location permission may be requested by the page; hand the prompt to the user.
- Never confirm a ride, a fare change or a cancellation fee without approval.
