# Raahi Learning V1 — Start Here

This branch contains the canonical Raahi Learning V1 product and technical documentation.

**Branch:** `raahi-learning-v1-docs`  
**Canonical folder:** [`docs/raahi-learning/`](docs/raahi-learning/)

Start with:

1. [`docs/raahi-learning/99-handover.md`](docs/raahi-learning/99-handover.md)
2. [`docs/raahi-learning/README.md`](docs/raahi-learning/README.md)
3. [`docs/raahi-learning/08-database-blueprint-review-v1.md`](docs/raahi-learning/08-database-blueprint-review-v1.md)
4. [`docs/raahi-learning/03-database-blueprint-v1.1.md`](docs/raahi-learning/03-database-blueprint-v1.1.md)
5. [`docs/raahi-learning/11-sql-migration-plan-review-v1.md`](docs/raahi-learning/11-sql-migration-plan-review-v1.md)
6. [`docs/raahi-learning/10-sql-migration-plan-v1.1.md`](docs/raahi-learning/10-sql-migration-plan-v1.1.md)

Historical drafts retained for traceability but not implementation:

- `03-database-blueprint-v1.md`
- `10-sql-migration-plan-v1.md`

**Do not touch Supabase yet.** Product/UI behaviour is frozen, the physical schema has been reviewed, and the corrected SQL Migration Plan v1.1 is now the final review target. Only after it is explicitly marked **APPROVED FOR IMPLEMENTATION** should Supabase be connected and the first Foundation + Identity migration slice be executed.

The existing repository `main` branch contains prior Raahi work and must not be assumed to implement Raahi Learning's frozen model.
