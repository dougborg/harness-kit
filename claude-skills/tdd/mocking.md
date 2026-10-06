# When to mock

Mock at **system boundaries** only: external APIs (payments, email), time and
randomness, and sometimes the database or filesystem (prefer a real test
database or an in-memory stand-in when one exists). Your own modules and
internal collaborators stay real.

## Design boundaries to be mockable

**Inject the dependency** rather than constructing it inside:

```typescript
// Easy to mock
function processPayment(order, paymentClient) {
  return paymentClient.charge(order.total);
}

// Hard to mock
function processPayment(order) {
  const client = new StripeClient(process.env.STRIPE_KEY);
  return client.charge(order.total);
}
```

**Prefer one function per external operation** over a generic fetcher:

```typescript
// Each operation mocks to one shape
const api = {
  getUser: (id) => fetch(`/users/${id}`),
  createOrder: (data) => fetch("/orders", { method: "POST", body: data }),
};

// The mock needs conditional logic to fake every endpoint
const api = { fetch: (endpoint, options) => fetch(endpoint, options) };
```

Specific operations keep each mock to one return shape, keep logic out of test
setup, and show which endpoints a test touches.
