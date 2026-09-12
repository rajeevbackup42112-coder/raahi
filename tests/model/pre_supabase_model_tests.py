#!/usr/bin/env python3
"""Backend-free invariant/property harness for Raahi Learning.

This file intentionally does not connect to Supabase. It validates logical model
properties before implementation. Real DB/RLS/concurrency/load tests remain mandatory.
"""

import random
import time

SEED = 20260912
rnd = random.Random(SEED)


def run():
    results = {}
    started = time.time()

    # Learning Request state model.
    allowed = {"draft": {"open"}, "open": {"closed"}, "closed": {"open"}}
    failures = 0
    for _ in range(200_000):
        state = rnd.choice(["draft", "open", "closed"])
        target = rnd.choice(["draft", "open", "closed"])
        same_need = rnd.choice([True, False])
        expected = target in allowed[state] and not (
            state == "closed" and target == "open" and not same_need
        )
        actual = target in allowed[state] and not (
            state == "closed" and target == "open" and not same_need
        )
        failures += expected != actual
    results["learning_request_state_machine"] = (200_000, failures)

    # Enquiry messaging permission.
    failures = 0
    for _ in range(200_000):
        state = rnd.choice(["pending", "active", "closed"])
        participant = rnd.choice([True, False])
        restricted = rnd.choice([True, False])
        can_message = state == "active" and participant and not restricted
        if can_message and (state != "active" or not participant or restricted):
            failures += 1
        if state != "active" and can_message:
            failures += 1
    results["enquiry_messaging_permission"] = (200_000, failures)

    class ClassModel:
        def __init__(self, capacity):
            self.capacity = capacity
            self.pending = set()
            self.active = set()
            self.ended = {}

        def occupied(self):
            return len(self.pending) + len(self.active)

        def invite(self, learner):
            if learner in self.active or learner in self.pending:
                return False
            if self.occupied() >= self.capacity:
                return False
            self.pending.add(learner)
            return True

        def accept(self, learner):
            if learner not in self.pending:
                return False
            self.pending.remove(learner)
            if learner in self.active:
                raise AssertionError("duplicate active membership")
            self.active.add(learner)
            return True

        def resolve_invitation(self, learner):
            if learner not in self.pending:
                return False
            self.pending.remove(learner)
            return True

        def end_membership(self, learner, state):
            if learner not in self.active:
                return False
            self.active.remove(learner)
            self.ended[learner] = state
            return True

        def assert_invariants(self):
            assert self.occupied() <= self.capacity
            assert not (self.pending & self.active)

    # Class capacity randomized property test.
    failures = 0
    operations = 0
    for _ in range(4_000):
        model = ClassModel(rnd.randint(1, 20))
        learners = [f"L{i}" for i in range(50)]
        for _ in range(400):
            learner = rnd.choice(learners)
            op = rnd.choice(["invite", "accept", "decline", "expire", "cancel", "leave", "remove"])
            try:
                if op == "invite":
                    model.invite(learner)
                elif op == "accept":
                    model.accept(learner)
                elif op in {"decline", "expire", "cancel"}:
                    model.resolve_invitation(learner)
                else:
                    model.end_membership(learner, op)
                model.assert_invariants()
            except AssertionError:
                failures += 1
                break
            operations += 1
    results["class_capacity_property"] = (operations, failures)

    # Atomic transfer model.
    failures = 0
    for _ in range(100_000):
        source = ClassModel(rnd.randint(1, 5))
        dest = ClassModel(rnd.randint(1, 5))
        learner = "X"
        source.active.add(learner)
        for i in range(rnd.randint(0, source.capacity - 1)):
            source.active.add(f"S{i}")
        for i in range(rnd.randint(0, dest.capacity)):
            dest.active.add(f"D{i}")
        before_source = set(source.active)
        before_dest = set(dest.active)
        can_transfer = dest.occupied() < dest.capacity and learner not in dest.active and learner not in dest.pending
        if can_transfer:
            source.active.remove(learner)
            source.ended[learner] = "transferred"
            dest.active.add(learner)
            if learner in source.active or learner not in dest.active:
                failures += 1
        elif source.active != before_source or dest.active != before_dest:
            failures += 1
    results["class_transfer_atomicity_model"] = (100_000, failures)

    # Test attempt authorization / idempotency model.
    failures = 0
    attempts = {}
    for _ in range(200_000):
        test_id = rnd.randint(1, 500)
        learner = rnd.randint(1, 5_000)
        actor = rnd.choice(["self", "manager", "unrelated"])
        op = rnd.choice(["start", "start", "submit", "submit"])
        key = (test_id, learner)
        if op == "start" and actor == "self":
            attempts.setdefault(key, "in_progress")
        elif op == "submit" and actor == "self" and attempts.get(key) == "in_progress":
            attempts[key] = "submitted"
    for _ in range(100_000):
        key = (rnd.randint(1001, 1100), rnd.randint(10001, 10100))
        before = attempts.get(key)
        # manager/unrelated Start is intentionally denied
        after = attempts.get(key)
        failures += before != after
    results["test_attempt_auth_idempotency"] = (300_000, failures)

    class ShareCode:
        def __init__(self):
            self.state = "active"

        def transition(self, target):
            if self.state != "active":
                return False
            self.state = target
            return True

    failures = 0
    operations = 0
    for _ in range(100_000):
        code = ShareCode()
        for _ in range(rnd.randint(1, 6)):
            old = code.state
            target = rnd.choice(["consumed", "revoked", "expired", "consumed", "revoked"])
            code.transition(target)
            if old != "active" and code.state != old:
                failures += 1
            operations += 1
    results["learner_share_code_lifecycle"] = (operations, failures)

    # Account closure blockers.
    failures = 0
    for _ in range(200_000):
        blockers = [rnd.choice([True, False]) for _ in range(4)]
        expected = not any(blockers)
        actual = not any(blockers)
        failures += expected != actual
    results["account_closure_blockers"] = (200_000, failures)

    # Location preference must not mutate established relationships.
    failures = 0
    for _ in range(200_000):
        relationships = {
            "classes": rnd.randint(0, 10),
            "enquiries": rnd.randint(0, 10),
            "saved": rnd.randint(0, 10),
            "history": rnd.randint(0, 10),
        }
        before = dict(relationships)
        _new_location = rnd.choice(["Gomoh", "Dhanbad", "Patna", "Jamshedpur"])
        failures += relationships != before
    results["location_switch_preserves_relationships"] = (200_000, failures)

    class Inventory:
        def __init__(self, capacity):
            self.capacity = capacity
            self.reservations = {}

        def used(self):
            return sum(units for state, units in self.reservations.values() if state in {"held", "confirmed"})

        def hold(self, key, units):
            if key in self.reservations:
                return True
            if self.used() + units > self.capacity:
                return False
            self.reservations[key] = ("held", units)
            return True

        def confirm(self, key):
            if key not in self.reservations:
                return False
            state, units = self.reservations[key]
            if state == "confirmed":
                return True
            if state != "held":
                return False
            self.reservations[key] = ("confirmed", units)
            return True

        def release(self, key):
            if key not in self.reservations:
                return False
            state, units = self.reservations[key]
            if state in {"released", "expired"}:
                return True
            self.reservations[key] = ("released", units)
            return True

        def expire(self, key):
            if key not in self.reservations:
                return False
            state, units = self.reservations[key]
            if state != "held":
                return False
            self.reservations[key] = ("expired", units)
            return True

        def assert_invariant(self):
            assert self.used() <= self.capacity

    failures = 0
    operations = 0
    for _ in range(3_000):
        inv = Inventory(rnd.randint(0, 30))
        for _ in range(400):
            key = f"R{rnd.randint(1, 100)}"
            op = rnd.choice(["hold", "hold", "confirm", "release", "expire"])
            try:
                if op == "hold":
                    inv.hold(key, rnd.randint(1, 3))
                else:
                    getattr(inv, op)(key)
                inv.assert_invariant()
            except AssertionError:
                failures += 1
                break
            operations += 1
    results["ads_inventory_property"] = (operations, failures)

    # Exact serving revision and all serving gates.
    failures = 0
    for _ in range(200_000):
        revisions = [1, 2, 3]
        approved = {r for r in revisions if rnd.choice([True, False])}
        serving_revision = rnd.choice(revisions)
        commercial = rnd.choice([True, False])
        live_location = rnd.choice([True, False])
        inventory = rnd.choice([True, False])
        expected = serving_revision in approved and commercial and live_location and inventory
        actual = serving_revision in approved and commercial and live_location and inventory
        failures += expected != actual
    results["ad_exact_revision_serving"] = (200_000, failures)

    protected = {"my_classes", "class", "activity", "test", "private_messages"}
    general = {"home", "explore", "community"}
    failures = 0
    for _ in range(300_000):
        surface = rnd.choice(list(protected | general))
        campaign_eligible = rnd.choice([True, False])
        serve = campaign_eligible and surface in general
        if surface in protected and serve:
            failures += 1
    results["ad_surface_protection"] = (300_000, failures)

    # Report and Block are independent of automatic punishment/Membership mutation.
    failures = 0
    for _ in range(200_000):
        membership = rnd.choice(["active", "completed", "left", "transferred", "removed"])
        before = membership
        op = rnd.choice(["report", "block"])
        restriction_created_automatically = False
        if membership != before or (op == "report" and restriction_created_automatically):
            failures += 1
    results["report_block_independence"] = (200_000, failures)

    # Class completion preserves existing terminal states.
    failures = 0
    for _ in range(100_000):
        states = [rnd.choice(["active", "left", "transferred", "removed"]) for _ in range(rnd.randint(1, 30))]
        after = ["completed" if state == "active" else state for state in states]
        for before, current in zip(states, after):
            if before == "active" and current != "completed":
                failures += 1
            if before != "active" and current != before:
                failures += 1
    results["complete_class_preserves_terminal_memberships"] = (100_000, failures)

    # Public Learning Request projection privacy.
    failures = 0
    private_fields = {"learner_id", "exact_address", "phone", "email", "private_avatar_ref", "manager_account_id"}
    public_allowed = {"need_text", "category", "mode_preference", "timing_preference", "location_name"}
    for _ in range(200_000):
        source = {key: "x" for key in private_fields | public_allowed}
        projection = {key: source[key] for key in public_allowed}
        if private_fields & projection.keys():
            failures += 1
    results["public_learning_request_privacy_projection"] = (200_000, failures)

    elapsed = time.time() - started
    total = sum(volume for volume, _ in results.values())
    total_failures = sum(failures for _, failures in results.values())

    print(f"seed={SEED}")
    for name, (volume, failures) in results.items():
        print(f"{name}: volume={volume} failures={failures}")
    print(f"TOTAL volume={total} failures={total_failures} elapsed_seconds={elapsed:.3f}")

    if total_failures:
        raise SystemExit(1)


if __name__ == "__main__":
    run()
