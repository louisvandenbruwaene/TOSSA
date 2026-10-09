# Performance art direction, September 2026

The showman now performs with his whole body. Independent painted arms still follow
the simulation; a shared cosmetic mesh adds weight transfer, breathing, catch absorption,
and delayed coat movement. Palms and boot soles remain fixed, head gear follows the
head, and the existing eight spin views accelerate and settle within the same spin duration.
The same renderer serves the live stage, skills previews and dressing room.

The theatre and circus have new paintings, imported to the established 640x360 density
and 48-colour palette. Both original paintings are retained; the art manifest chooses the
new versions. A scenery shader now samples each texture once, avoiding the previous
accidental texture multiplication. Venue colour, a quiet central flight area, drifting
air at the wings, and localized backyard foliage motion give the rooms more depth.
The Midnight Show stays dark. Reduced motion suppresses the new secondary animation,
atmospheric time and motes; juggling continues to show the real choreography.

Skills and tailor previews use a crop of the actual venue at one screen pixel per art
pixel, with recessed wings and a grounded floor. The mirror's old vertical bob, which
lifted the boots off that floor, is removed.

## Review

Generated locally in `artifacts/visual_overhaul/`:

- `performance.mp4`: a short actual gameplay recording of the moving performer.
- `theatre.png`: the new theatre during a ring act.
- `circus-busy.png`: five chainsaws in the new circus.
- `skills.png`: Behind the Back preview in the miniature theatre.
- `animation-frames.png`: eight frames from the recording for shoulder/foot review.
- `midnight.png`: the dark venue with glowing equipment.

The stage contact harness reported zero seams over 10 px in both the ring act (34
seams) and five-chainsaw act (35 seams); measured release/catch gaps were 0 px.
The Behind the Back preview reported no seams over 10 px, with a worst gap of 3 px.
The busy-stage draw probe measured about 2.5 ms/frame on the local Apple M5; this is
a local sample, not a cross-platform frame-rate guarantee.

`tests/test_performance_pose.gd` covers 45 combinations of reach/catch age, checks
bounded displacements, pinned soles/palms, shoulder attachment, catch settling, and
reduced motion. It runs as part of `make validate` alongside existing gameplay contracts.

The full `make validate` run passed (exit 0), including booked/daily acts, tutorials,
collision sweeps, full-hand parking, windowed screen captures, aspect lock and font checks.
Its final report is saved in `artifacts/visual_overhaul/validation.log`.

## Sources and rebuilding

See [component credits](../third_party/visuals/README.md) for the three MIT GitHub
sources and adjacent license notices. Export presets include the notices. Generated
art masters have a `.gdignore` so they do not become runtime resources.

```sh
godot --headless --path . --script scripts/import_theatre_art.gd
make validate
```

The pose module has no simulation dependency. Timing, physics, inputs, collision
geometry, score rules, economy and save schema are unchanged by this visual work.
