# Raahi Learning V1 — Start Here

This branch contains the canonical Raahi Learning V1 product and technical documentation.

**Branch:** `raahi-learning-v1-docs`  
**Canonical folder:** [`docs/raahi-learning/`](docs/raahi-learning/)

Start with:

1. [`docs/raahi-learning/99-handover.md`](docs/raahi-learning/99-handover.md)
2. [`docs/raahi-learning/README.md`](docs/raahi-learning/README.md)
3. [`docs/raahi-learning/08-database-blueprint-review-v1.md`](docs/raahi-learning/08-database-blueprint-review-v1.md)
4. [`docs/raahi-learning/03-database-blueprint-v1.1.md`](docs/raahi-learning/03-database-blueprint-v1.1.md)

The original `03-database-blueprint-v1.md` is retained only as the historical first physical draft and **must not be used for migrations**.

**Do not touch Supabase yet.** Product/UI behaviour is frozen, and the physical model has completed its first review/correction pass. The immediate next task is the SQL-readiness review of blueprint v1.1: exact PostgreSQL constraints, FK delete behaviour, RLS/RPC boundaries, concurrency locking and migration slicing. Only after a reviewed SQL Migration Plan should Supabase changes begin.

The existing repository `main` branch contains prior Raahi work and must not be assumed to implement Raahi Learning's frozen model.
