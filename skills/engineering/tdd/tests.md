# Good and bad tests

Examples are TypeScript; the principles hold in any language.

## Good: behaviour through the interface

```typescript
test("user can check out with a valid cart", async () => {
  const cart = createCart();
  cart.add(product);
  const result = await checkout(cart, paymentMethod);
  expect(result.status).toBe("confirmed");
});
```

It tests what callers care about, uses the public interface only, survives
internal refactors, and its name says what, not how.

## Bad: coupled to implementation

```typescript
test("checkout calls paymentService.process", async () => {
  const process = jest.spyOn(paymentService, "process");
  await checkout(cart, payment);
  expect(process).toHaveBeenCalledWith(cart.total);
});
```

Red flags: mocking your own collaborators, testing private methods, asserting
call counts or order on your own collaborators, a name that describes how
instead of what. Asserting that a boundary mock was called ("charged once")
is fine.

## Bad: verifying through a side channel

```typescript
// Bypasses the interface
test("createUser saves to database", async () => {
  await createUser({ name: "Alice" });
  const row = await db.query("SELECT * FROM users WHERE name = ?", ["Alice"]);
  expect(row).toBeDefined();
});

// Verifies through the interface
test("createUser makes the user retrievable", async () => {
  const user = await createUser({ name: "Alice" });
  expect((await getUser(user.id)).name).toBe("Alice");
});
```

## Bad: tautological

```typescript
// Expected value recomputed the way the code computes it
test("calculateTotal sums line items", () => {
  const items = [{ price: 10 }, { price: 5 }];
  const expected = items.reduce((sum, i) => sum + i.price, 0);
  expect(calculateTotal(items)).toBe(expected);
});

// Expected value is an independent literal
test("calculateTotal sums line items", () => {
  expect(calculateTotal([{ price: 10 }, { price: 5 }])).toBe(15);
});
```
