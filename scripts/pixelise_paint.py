#!/usr/bin/env python3
"""Reduce a FULL-FRAME PixelLab painting to a shipped 640x360 backdrop.

WHY THIS EXISTS ALONGSIDE pixelise_bg.py. That script reduces the game's own --bgref
capture (a drawing) and snaps it with a plain nearest-colour pass. This one takes a
PAINTING straight from PixelLab, already authored at the art density, and snaps it with
serpentine error diffusion. A drawing is flat fills that land on the palette almost
exactly; a painting is continuous tone, and a nearest-colour snap turns its skies and
its lamplight into hard bands. Same reasoning, and the same ERR_CLAMP, as pixelise_ext.

THE MIRROR IS GONE, AND THAT IS THE POINT OF THIS FILE. Five of the seven backdrops were
built as one 320x360 half mirrored down the middle, because create_image_pixflux caps a
side at 400px. `create_image_pixen` takes up to 768 per side with a 512x512 area budget,
and 640x360 = 230400 is inside it - so a backdrop is now ONE image. That removes three
standing compromises at once:

  1. the visible bilateral mirror line down the centre of every indoor venue;
  2. "anything focal at the centre gets duplicated by the mirror", which is why the old
     prompts had to say "the far LEFT SIDE only" and why one tent came back with two poles;
  3. the rule that asymmetric outdoor venues (the Backyard, the Street Corner) could not be
     generated at all and had to be derived from the game's own dressing instead. They were
     the two weakest pictures in the game precisely because of it.

WHAT PIXEN DOES NOT DO is force a palette - it has no color_image_base64. That is fine
here and was always the weaker half of the deal: the forcing happens in this script, in
Oklab, against the same locked 48. Measured on the seven: the raw paintings come back with
thousands of colours and reduce to 28-40, which is the same range the palette-forced
pixflux halves landed in.

WHAT THE PAINTING MUST NOT CONTAIN is light that reacts to the player. draw_backdrop
replaces exactly two layers with this sprite - the sky gradient and the set dressing - and
then draws the veil, the spotlight cone and the footlights OVER it, because the cone narrows
and warms as a streak builds. A backdrop with its own spotlight baked in freezes the half of
the picture that is answering the player. (The first Midnight Show re-roll came back with a
warm elliptical pool painted onto its boards and was thrown away for exactly this.)

THREE FRAMING RULES THE PROMPTS HAVE TO CARRY, all measured off draw_backdrop:

  1. THE BOTTOM THIRD IS A FLOOR THE PERFORMER STANDS ON, and it has to be a real, continuous,
     standable surface running edge to edge - boards, sawdust, turf, cobbles, a pitch. This
     REPLACES the rule that used to sit here, which said the bottom 20% was "covered by the
     stage floor, so nothing essential may live there". That was true while the game drew a
     vector podium over it; the podium was deleted on 2026-08-14 and the painting became the
     floor, at which point the old rule was actively harmful - it is what produced a Backyard
     that was a close-up of a house wall with no ground under the centre at all, and a
     Midnight Show that was drapes and tables above pure black. Louis, on the result: "he's
     often floating or not standing on the right place or there is no floor at all."
  2. THE FLOOR IS A BAND, AND HE STANDS INSIDE IT. It runs in perspective from its back edge
     to the bottom of the frame, and Game.gd's per-venue `stand` (venue_data) puts his feet
     partway down it - roughly art y 300-315 - with floor visible BEHIND his heels and more
     in front. So the floor's back edge wants to be up around art y 260-290, not at 310. A
     painting whose floor only starts in the last twenty rows cannot be stood on.
  3. THE CENTRE COLUMN IS EMPTY. The performer stands dead centre and is ~172 art px tall, so
     a tent pole, a doorway or a tree trunk behind his spine reads as a mistake.
     spine_busyness() below measures this; around 1.0 is clear.

AND WATCH THE GROUND FOR FAKE HANDWRITING. Asked for texture on a large plain surface the
model reliably paints illegible cursive scribbles - measured on two Backyard rolls, scattered
right across the lawn where the player looks. It is not visible in a 640x360 thumbnail and it
is unmistakable at 2x on screen. Say "no writing, no letters, no markings" and go and zoom in
on the floor band before shipping.

USAGE
  scripts/fetch_paint.sh <job-id> <name>            download a backdrop painting
  scripts/fetch_paint.sh <job-id> ext_<name>        ...or an exterior
  .venv/bin/python scripts/pixelise_paint.py                     preview everything
  .venv/bin/python scripts/pixelise_paint.py --ext the_circus    one family, one venue
  .venv/bin/python scripts/pixelise_paint.py --write
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

import artguard
from pixelise_ext import snap_diffused
from pixelise_menu import ART_H, ART_W, load_palette, srgb_to_oklab

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "artifacts" / "paint"

# venue order matches Game.gd's venue_data(); the key is bg/<name>
NAMES = ["backyard", "street_corner", "small_theatre", "the_circus",
		 "championship", "world_arena", "the_midnight_show"]

# WHERE THE PERFORMER'S FEET ARE IN EACH ROOM, as a fraction of the frame height. This MIRRORS
# Game.gd's venue_data()["stand"] and has to be kept in step with it by hand - there is no
# machine-readable link, and the reason to duplicate it anyway is that spine_busyness measures
# the rows he actually occupies, which end at his feet. A stale number here does not break a
# build, it just measures the wrong band and reassures you about a composition fault.
STAND = {"backyard": 0.87, "street_corner": 0.88, "small_theatre": 0.85, "the_circus": 0.87,
		 "championship": 0.85, "world_arena": 0.86, "the_midnight_show": 0.83}

FIGURE_H = 172      # the performer, crown of the hat to boot sole, in art pixels

# THE TWO FAMILIES, and they are the same job at two camera positions. A BACKDROP is what
# stands behind the performer during the act; an EXTERIOR is the establishing card shown
# before it, the venue seen from outside. Both are full-frame 640x360 paintings reduced the
# same way, so they share this file rather than growing a near-duplicate of it.
#
# THE EXTERIORS WERE PREVIOUSLY OFF-LIMITS TO A GENERATOR, on the recorded grounds that "an
# exterior is a picture the game already composes correctly, with the venue's hero mid-frame
# and the marquee text laid out against it - a model asked for 'a circus tent at night' would
# give back a different composition and the card's own layout would no longer fit it." That
# was right about the risk and wrong about the conclusion: the layout is knowable, so the
# prompt can simply be written to it. Measured off a real --establish capture, the card puts
# its title across the TOP CENTRE and two panels in the BOTTOM CORNERS, which is why every
# exterior prompt here says the hero fills the lower two thirds and the upper third is empty
# sky. The reason to bother is uniformity: once the seven backdrops are paintings, seven flat
# vector exteriors are the only unpainted full-frame pictures left in the game.
FAMILIES = {
	"bg": (ROOT / "Assets" / "Backgrounds", "{}.png"),
	"ext": (ROOT / "Assets" / "UI", "ext_{}.png"),
	"ui": (ROOT / "Assets" / "UI", "{}.png"),
}

# THE ONE-OFF FULL-FRAME PICTURES, which are not per-venue and so cannot ride NAMES.
#
# WHY THESE FIVE. Four of them were literally `draw_rect(whole screen, near-black)` with
# centred text on top - measured, `gameover` scored 0.63% off-grid not because it was well
# converted but because there was nothing in it. They are the game's biggest emotional
# beats (the run dies, the game is won, the Purist trophy, the last thing a demo player
# sees before deciding whether to buy) and they were the emptiest screens in it. The fifth,
# the title proscenium, was already a sprite but a BAKE OF THE GAME'S OWN VECTOR DRAWING
# rather than a painting, and it is the most-seen screen there is.
#
# THE TEXT RUNS DOWN THE MIDDLE OF ALL FOUR END CARDS, roughly y 14%..88%, and each one
# finishes with draw_vignette(s, 0.7) - a 170px band at every edge. So the composition rule
# here is narrower than a backdrop's: the middle must be quiet enough to read type over,
# and the detail cannot sit right on the edge either or the vignette eats it. It wants to
# live in the ring between.
UI_ONEOFFS = ["menu_backdrop", "victory", "end_gameover", "end_demo", "end_legend"]


# HOW MUCH OF A PAINTING MAY SIT OUTSIDE THE LOCKED 48 BEFORE IT IS NOT WORTH SHIPPING.
#
# THE PALETTE IS A WARM THEATRE PALETTE and that is the whole reason this gate exists.
# Measured on the first two full-frame paintings: the circus (warm reds, cream, amber)
# came through the snap essentially intact; the backyard, painted with a desaturated TEAL
# dusk sky, had its whole sky land on muddy grey-brown speckled with the palette's only
# greens, which are bright and saturated. Nothing in the reducer can fix that - error
# diffusion moves a residual around, it cannot invent a colour the palette does not have,
# and at that distance every neighbour is wrong in the same direction.
#
# THE MEAN DISTANCE IS THE WRONG STATISTIC AND NEARLY FOOLED ME. The two score 0.028 and
# 0.034 - a 1.2x spread for a difference that is glaring on screen - because the damage is
# LOCALISED to the sky and a whole-frame mean averages it against a lot of fabric that
# snapped perfectly. What separates them is the TAIL: the fraction of pixels further than
# 0.05 Oklab from any entry is 2.9% on the circus and 26.9% on the backyard (51.5% over its
# sky band alone), a 9x separation. Measure the tail, not the average.
#
# The fix is always at the PROMPT, never here: steer a sky to deep indigo (the palette
# holds 1f1a2e / 282848 / 585078) rather than teal, and keep foliage dark rather than
# mid-green.
#
# IT IS AN ADVISORY, NOT A GATE, AND IT OVER-FLAGS - say so rather than trust it. Across the
# fourteen paintings so far it fired four times and only ONE was a real failure: the teal
# backyard, whose out-of-gamut pixels were one large CONTIGUOUS wash across the sky. The
# other three (the Championship hall and the World Arena, twice each as backdrop and
# exterior) are cold-lit venues whose distant pixels are DISPERSED - floodlights, a crowd
# speckle, blue window glass - and error diffusion handles scattered residual well, which
# is the whole thing it is for. All three came through the snap looking right.
#
# So the number means "go and look at this one", which is why the tag says so. A contiguity
# term would separate the two cases properly; it has not been worth writing, because looking
# at the picture is the step it would be saving and that step is not optional anyway.
GAMUT_FAR = 0.05
GAMUT_MAX = 0.10

# SHADOW IS NOT DAMAGE, and ignoring that made this advisory cry wolf on a good painting
# (2026-08-13). The new Street Corner - one lit lamp on a warm brick corner, which reduces
# beautifully - scored 0.312, higher than the teal Backyard (0.269) that this whole check was
# built to catch. Measured, its "out of gamut" pixels averaged RGB (8, 7, 4) with a channel
# spread of 1: they are the night itself. Oklab distances stay meaningful down at the black
# point while perception does not, so a large area of near-black reads as far from every
# palette entry and then snaps to a dark that nobody can tell apart from it.
#
# Excluded from the NUMERATOR ONLY. Dropping dark pixels from the denominator too was the
# first attempt and it is wrong in the other direction: it shrinks the population and
# CONCENTRATES the surviving tail, which pushed the Championship from 0.055 to 0.087 for no
# reason at all. Damaged lit pixels as a fraction of the whole frame is the honest reading.
# Measured across the seven: street corner 0.312 -> 0.023, championship 0.055 -> 0.041,
# every other venue unchanged to three places.
#
# It cannot hide either failure on record: the teal dusk sky and the over-bright title
# curtain were both mid-luminance, well above this floor.
GAMUT_DARK = 26.0   # mean RGB below this is night, and its snap is unobservable


def gamut_fit(rgb: np.ndarray) -> float:
	"""Fraction of ALL pixels that are both LIT and further than GAMUT_FAR from the palette.

	Answers the one question a thumbnail cannot: will this painting SURVIVE the snap? A
	picture inside the palette's gamut reduces to itself; one outside it reduces to
	whatever is least wrong, and no amount of dithering rescues that.
	"""
	lab_p = srgb_to_oklab(load_palette().astype(float))
	pix = rgb.reshape(-1, 3).astype(float)
	flat = srgb_to_oklab(pix)
	lum = pix.mean(axis=1)
	# chunked: 230k pixels against 48 entries at once is 33M floats
	far = 0
	for i in range(0, len(flat), 32768):
		part = flat[i:i + 32768]
		d = np.linalg.norm(part[:, None, :] - lab_p[None, :, :], axis=2).min(axis=1)
		far += int(((d > GAMUT_FAR) & (lum[i:i + 32768] >= GAMUT_DARK)).sum())
	return far / len(flat)


def build(fam: str, name: str, write: bool, force: bool) -> str:
	stem = name if fam in ("bg", "ui") else f"ext_{name}"
	src = SRC / f"{stem}.png"
	if not src.exists():
		return f"{stem}: no painting at artifacts/paint/{stem}.png"
	im = Image.open(src).convert("RGB")
	if im.size != (ART_W, ART_H):
		raise SystemExit(f"{stem}: expected {ART_W}x{ART_H}, got {im.size}. These are "
						 "authored at the art density and must never be resampled.")
	src_rgb = np.asarray(im).astype(int)
	out = snap_diffused(src_rgb, load_palette())
	# opaque by construction: both families cover the frame and are blitted full-rect
	rgba = np.dstack([out, np.full(out.shape[:2], 255, np.uint8)])
	cols = len(np.unique(out.reshape(-1, 3), axis=0))
	fit = gamut_fit(src_rgb)
	tag = f"{stem}: {cols} colours, gamut {fit:.3f}"
	if fam == "ui":
		# pale type runs straight down the middle of an end card; report how bright its ground is
		tag += f", mid-lum {mid_lum(out):.2f}"
	if fam == "bg":
		# only a backdrop has a performer standing in front of it
		tag += f", spine {spine_busyness(out, STAND[name]):.2f}"
	if fit > GAMUT_MAX:
		tag += "  <-- LOOK AT IT"
	if not write:
		return tag + "  (pass --write to apply)"
	out_dir, pat = FAMILIES[fam]
	return tag + " [" + artguard.save_guarded(
		out_dir / pat.format(name), lambda q: Image.fromarray(rgba, "RGBA").save(q), force) + "]"


def mid_lum(img: np.ndarray) -> float:
	"""Mean brightness (0..1) of the band the end-card type is printed over.

	Every end card centres pale type down the middle of the frame, roughly y 14%..88%, so
	what ruins one is a BRIGHT picture behind the words - and that is invisible in a
	thumbnail, because a thumbnail has no text on it.

	Brightness, not busyness: the first version of this measured mean gradient in the band
	relative to the whole frame and reported 1.00-1.07 for all five, which ranked them
	roughly right and meant nothing in practice. A closed velvet curtain is wall-to-wall
	vertical folds - high gradient everywhere, and perfectly calm to read over - while a
	single lit window behind a sentence is low gradient and fatal. Pale text needs a DARK
	ground, so measure the ground.

	It is still only an advisory. The real test is a capture of the screen with its own
	words on it, which is what these are checked against.
	"""
	g = img.astype(float).mean(axis=2) / 255.0
	return float(g[int(0.14 * ART_H):int(0.88 * ART_H),
				   int(0.20 * ART_W):int(0.80 * ART_W)].mean())


def spine_busyness(img: np.ndarray, stand: float) -> float:
	"""Mean horizontal detail in the performer's column, relative to the whole row.

	Not a gate - a backdrop is judged by eye - but a vertical feature standing behind the
	figure's spine is the one composition fault a 640x360 thumbnail hides completely and
	the game then shows every single frame. He stands at x = 320 and is about 172 art px
	tall, so this compares mean absolute horizontal gradient down the middle 60 px, over
	the rows he actually occupies, against the same measure across the whole row. Around
	1.0 is "as busy as anywhere else"; well above it means something is standing there.

	`stand` is the venue's own standing line (STAND above): the rows he occupies end at his
	FEET, and since 2026-08-14 those are in a different place in every room.
	"""
	g = img.astype(float).mean(axis=2)
	floor = int(ART_H * stand)
	rows = slice(max(0, floor - FIGURE_H), floor)     # crown to feet, at his real height
	d = np.abs(np.diff(g[rows], axis=1))
	mid = d[:, 290:350].mean()
	allr = d.mean()
	return float(mid / allr) if allr > 0 else 0.0


def main() -> int:
	write = "--write" in sys.argv
	force = "--force" in sys.argv
	fams = [f for f in FAMILIES if f"--{f}" in sys.argv] or list(FAMILIES)
	only = [a for a in sys.argv[1:] if not a.startswith("--")]
	for fam in fams:
		FAMILIES[fam][0].mkdir(parents=True, exist_ok=True)
		for name in (UI_ONEOFFS if fam == "ui" else NAMES):
			if only and name not in only:
				continue
			print("  " + build(fam, name, write, force))
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
