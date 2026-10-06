# GLOSSARY.md format

## Structure

```md
# {Context name}

{One or two sentences: what this context is and why it exists.}

## Language

**Order**:
A customer's request to buy one or more products, from checkout until it is
fulfilled or cancelled.
_Avoid_: purchase, transaction

**Invoice**:
A request for payment sent to a customer after delivery.
_Avoid_: bill, payment request

## Relationships

- An **Order** produces one or more **Invoices**

## Flagged ambiguities

- "account" was used for both **Customer** and **User**. Resolved: they are
  distinct concepts.
```

## Rules

- **Be opinionated.** Where several words name one concept, pick the best one
  and list the rest under `_Avoid_`.
- **Keep definitions tight:** one or two sentences saying what the thing is,
  not what it does or how it is built.
- **Only this project's concepts.** General programming ideas (timeouts, retry
  policies, error types) stay out even when the project leans on them.
- **Use the glossary's own terms inside definitions.**
- **Group terms under subheadings** once natural clusters appear.
- **Record resolved ambiguities** so the old usage doesn't creep back.

## Several contexts

A root `GLOSSARY-MAP.md` points at each context's glossary:

```md
# Glossary map

## Contexts

- [Ordering](./src/ordering/GLOSSARY.md): receives and tracks customer orders
- [Billing](./src/billing/GLOSSARY.md): invoices and payments

## Relationships

- **Ordering → Billing**: Billing consumes `OrderPlaced` events to invoice
```

When the map exists, work out which context the current topic belongs to;
ask if it is unclear.
