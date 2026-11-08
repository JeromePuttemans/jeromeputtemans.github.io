#!/usr/bin/env python3
"""Standalone balance simulation for the Godot tower defense template.

Reads the real JSON data (config, towers, enemies, waves, maps) from ../data,
simulates the game rules at a fixed dt (60 steps per simulated second) with
several bots, and prints per-wave tables. Python 3, standard library only
(tested with Python 3.14).

Usage (from the template folder):
    python tools/balance_sim.py                    # current data, all bots
    python tools/balance_sim.py --bot balanced     # one bot only
    python tools/balance_sim.py --quiet            # summary lines only
    python tools/balance_sim.py --robust           # 9 behaviour variants per bot
    python tools/balance_sim.py --bench            # min single-type gold per wave
    python tools/balance_sim.py --set config.hp_scale_per_wave=0.5 \\
                                --set towers.sniper.up1.damage=180
        # what-if: runs the current data, then the data with the overrides,
        # without touching the JSON files

Rules reproduced from the GDScript code:
    - distance-based path following, progress = distance walked (Enemy.gd)
    - HP x (1 + hp_scale_per_wave x wave_index), damage = max(1, dmg - armor)
    - spawn queue timing of WaveManager.gd (delay / interval per block)
    - turret turn rate 12 rad/s, bullet and beam towers fire within 0.25 rad
    - homing bullets (wasted if the target dies first), instant beams,
      shells aimed at the target's predicted position along the path,
      splash on landing
    - wave clear bonus, auto-start countdown, early-call bonus, sell refund

Known approximations (small effect on the results):
    - projectiles start from the tower center (the game uses the muzzle)
    - towers always target "first"; turrets start facing +x and do not
      perform the idle scan rotation of the game
    - bots react every 0.25 s by default and see the whole wave list
"""
import argparse
import bisect
import copy
import json
import math
import os
import sys

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, "data")

DT = 1.0 / 60.0
TURN_RATE = 12.0        # rad/s, bullet + beam towers
AIM_TOL = 0.25          # rad
BULLET_HIT = 0.17       # tiles
THINK_EVERY = 0.25      # s, bot reaction period
SAMPLE_STEP = 0.1       # tiles, path sampling for tile evaluation

# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------
def load_data(data_dir=DATA_DIR):
    d = {}
    for name in ("config", "towers", "enemies", "waves", "maps"):
        with open(os.path.join(data_dir, name + ".json"), encoding="utf-8") as f:
            d[name] = json.load(f)
    return d


# ---------------------------------------------------------------------------
# What-if overrides: --set PATH=VALUE, applied on a copy of the data
#   config.<key>=<value>
#   towers.<id>.<field>=<value>          base stats or cost
#   towers.<id>.up<N>.<field>=<value>    N = 1 for level 2, 2 for level 3
#   enemies.<id>.<field>=<value>
#   waves.<wave>.<block>.<field>=<value> wave and block numbered from 1
# VALUE is parsed as JSON (0.5, 12, true, "text"), raw text otherwise.
# ---------------------------------------------------------------------------
class OverrideError(ValueError):
    pass


def _parse_value(text):
    try:
        return json.loads(text)
    except ValueError:
        return text


def _check_field(target, field, where, allowed=None):
    known = set(target) | set(allowed or ())
    if field not in known:
        raise OverrideError("unknown field '%s' in %s (known: %s)"
                            % (field, where, ", ".join(sorted(known))))


def apply_override(d, assignment):
    """Applies one PATH=VALUE assignment in place on the data dict d."""
    if "=" not in assignment:
        raise OverrideError("expected PATH=VALUE, got '%s'" % assignment)
    path, raw = assignment.split("=", 1)
    parts = path.strip().split(".")
    value = _parse_value(raw.strip())
    head = parts[0]
    if head == "config" and len(parts) == 2:
        _check_field(d["config"], parts[1], "config.json")
        d["config"][parts[1]] = value
    elif head == "towers" and len(parts) in (3, 4):
        towers = {t["id"]: t for t in d["towers"]}
        if parts[1] not in towers:
            raise OverrideError("unknown tower '%s' (known: %s)" % (parts[1], ", ".join(towers)))
        tower = towers[parts[1]]
        if len(parts) == 3:
            _check_field(tower, parts[2], "tower '%s'" % parts[1])
            tower[parts[2]] = value
        else:
            if not parts[2].startswith("up") or not parts[2][2:].isdigit():
                raise OverrideError("expected up1 or up2, got '%s'" % parts[2])
            n = int(parts[2][2:])
            ups = tower.get("upgrades", [])
            if not 1 <= n <= len(ups):
                raise OverrideError("tower '%s' has %d upgrades" % (parts[1], len(ups)))
            stat_fields = [k for k in tower if k not in ("id", "display_name", "attack", "color", "upgrades")]
            _check_field(ups[n - 1], parts[3], "tower '%s' upgrade %d" % (parts[1], n), stat_fields)
            ups[n - 1][parts[3]] = value
    elif head == "enemies" and len(parts) == 3:
        enemies = {e["id"]: e for e in d["enemies"]}
        if parts[1] not in enemies:
            raise OverrideError("unknown enemy '%s' (known: %s)" % (parts[1], ", ".join(enemies)))
        _check_field(enemies[parts[1]], parts[2], "enemy '%s'" % parts[1])
        enemies[parts[1]][parts[2]] = value
    elif head == "waves" and len(parts) == 4:
        wave_n, block_n = int(parts[1]), int(parts[2])
        if not 1 <= wave_n <= len(d["waves"]):
            raise OverrideError("wave %d does not exist (1..%d)" % (wave_n, len(d["waves"])))
        blocks = d["waves"][wave_n - 1]["spawns"]
        if not 1 <= block_n <= len(blocks):
            raise OverrideError("wave %d has %d blocks" % (wave_n, len(blocks)))
        _check_field(blocks[block_n - 1], parts[3], "wave %d block %d" % (wave_n, block_n),
                     ("type", "count", "interval", "delay"))
        blocks[block_n - 1][parts[3]] = value
    else:
        raise OverrideError("cannot read path '%s' (see --help)" % path)


def apply_overrides(d, assignments):
    d = copy.deepcopy(d)
    for a in assignments:
        apply_override(d, a)
    return d


def tower_stats(tdef, level):
    s = {k: v for k, v in tdef.items() if k != "upgrades"}
    for n in range(level - 1):
        s.update({k: v for k, v in tdef["upgrades"][n].items() if k != "cost"})
    return s


# ---------------------------------------------------------------------------
# Path / map
# ---------------------------------------------------------------------------
class Path:
    def __init__(self, waypoints):
        self.pts = [(c + 0.5, r + 0.5) for c, r in waypoints]
        self.cum = [0.0]
        for (x0, y0), (x1, y1) in zip(self.pts, self.pts[1:]):
            self.cum.append(self.cum[-1] + math.hypot(x1 - x0, y1 - y0))
        self.length = self.cum[-1]
        n = int(round(self.length / SAMPLE_STEP))
        self.samples = [self.pos(i * SAMPLE_STEP) for i in range(n + 1)]

    def pos(self, s):
        if s <= 0:
            return self.pts[0]
        if s >= self.length:
            return self.pts[-1]
        i = bisect.bisect_right(self.cum, s) - 1
        seg = self.cum[i + 1] - self.cum[i]
        f = (s - self.cum[i]) / seg
        (x0, y0), (x1, y1) = self.pts[i], self.pts[i + 1]
        return (x0 + (x1 - x0) * f, y0 + (y1 - y0) * f)


class MapInfo:
    def __init__(self, mdef):
        self.grid = mdef["grid"]
        self.path = Path(mdef["waypoints"])
        self.buildable = [(c, r) for r, row in enumerate(self.grid)
                          for c, ch in enumerate(row) if ch == "B"]
        self._cov = {}

    def coverage(self, tile, rng):
        """Path length (tiles) within rng of the tile center, sampled every 0.1."""
        key = (tile, rng)
        v = self._cov.get(key)
        if v is None:
            cx, cy = tile[0] + 0.5, tile[1] + 0.5
            r2 = rng * rng
            v = sum(1 for (x, y) in self.path.samples
                    if (x - cx) ** 2 + (y - cy) ** 2 <= r2) * SAMPLE_STEP
            self._cov[key] = v
        return v


# ---------------------------------------------------------------------------
# Entities
# ---------------------------------------------------------------------------
class Enemy:
    __slots__ = ("tid", "hp", "speed", "armor", "reward", "ld", "prog",
                 "x", "y", "alive")


class Tower:
    __slots__ = ("tid", "level", "tile", "x", "y", "dmg", "rng", "r2", "rate",
                 "splash", "pspeed", "attack", "cd", "angle", "invested", "dealt",
                 "kills", "shots")


class Game:
    def __init__(self, D, bot, dt=DT, max_time=7200.0):
        self.D = D
        self.cfg = D["config"]
        self.tdefs = {t["id"]: t for t in D["towers"]}
        self.edefs = {e["id"]: e for e in D["enemies"]}
        self.waves = D["waves"]
        self.map = MapInfo(D["maps"][0])
        self.path = self.map.path
        self.bot = bot
        self.dt = dt
        self.max_time = max_time
        self.gold = self.cfg["starting_gold"]
        self.lives = self.cfg["starting_lives"]
        self.phase = "pre"          # pre, wave, between, over, won
        self.wave_idx = -1
        self.t = 0.0
        self.towers = []
        self.occupied = set()
        self.enemies = []
        self.bullets = []           # [x, y, target, dmg, speed]
        self.shells = []            # [t_left, ax, ay, dmg, splash2]
        self.queue = []
        self.spawn_timer = 0.0
        self.countdown = 0.0
        self.records = []
        self.cur = None
        self.gold_avail = self.gold
        self.next_think = 0.0
        self.invested_total = 0

    # ----- scaling -----
    def scaled_hp(self, etype, wi):
        return round(self.edefs[etype]["hp"] * (1 + self.cfg["hp_scale_per_wave"] * wi))

    # ----- player actions -----
    def can_build(self, tile):
        c, r = tile
        return self.map.grid[r][c] == "B" and tile not in self.occupied

    def build(self, tid, tile):
        cost = self.tdefs[tid]["cost"]
        if cost > self.gold or not self.can_build(tile):
            return None
        self.gold -= cost
        t = Tower()
        t.tid, t.level, t.tile = tid, 1, tile
        t.x, t.y = tile[0] + 0.5, tile[1] + 0.5
        t.cd, t.angle, t.invested = 0.0, 0.0, cost
        t.dealt, t.kills, t.shots = 0, 0, 0
        self._apply_stats(t)
        self.towers.append(t)
        self.occupied.add(tile)
        self.invested_total += cost
        return t

    def upgrade_cost(self, t):
        ups = self.tdefs[t.tid]["upgrades"]
        return ups[t.level - 1]["cost"] if t.level - 1 < len(ups) else None

    def upgrade(self, t):
        c = self.upgrade_cost(t)
        if c is None or c > self.gold:
            return False
        self.gold -= c
        t.level += 1
        t.invested += c
        self.invested_total += c
        self._apply_stats(t)
        return True

    def sell(self, t):
        self.gold += int(t.invested * self.cfg["sell_refund_ratio"])
        self.towers.remove(t)
        self.occupied.discard(t.tile)

    def call_wave(self):
        if self.phase == "pre":
            self._start_wave(0)
        elif self.phase == "between":
            bonus = int(self.countdown * self.cfg["early_call_gold_per_sec"])
            self.gold += bonus
            self.gold_avail += bonus
            self._start_wave(self.wave_idx + 1)

    def _apply_stats(self, t):
        s = tower_stats(self.tdefs[t.tid], t.level)
        t.dmg = s["damage"]
        t.rng = s["range"]
        t.r2 = t.rng * t.rng
        t.rate = s["fire_rate"]
        t.splash = s.get("splash_radius", 0.0)
        t.pspeed = s.get("projectile_speed", 0.0) or self.cfg["projectile_speed"]
        t.attack = s["attack"]

    # ----- waves -----
    def _start_wave(self, wi):
        self.wave_idx = wi
        self.phase = "wave"
        iv_def = self.cfg["spawn_interval"]
        self.queue = []
        prev_iv = None
        # same rule as scripts/WaveManager.gd: first spawn of block 0 waits
        # `delay`, first spawn of block k>0 waits previous interval + delay,
        # other spawns wait `interval`
        for b in self.waves[wi]["spawns"]:
            iv = b.get("interval", iv_def)
            for k in range(b["count"]):
                if k == 0:
                    wait = b.get("delay", 0.0) + (prev_iv if prev_iv is not None else 0.0)
                else:
                    wait = iv
                self.queue.append((wait, b["type"]))
            prev_iv = iv
        self.queue.reverse()        # pop() from the end
        self.spawn_timer = self.queue[-1][0] if self.queue else 0.0
        self.cur = {"wave": wi + 1, "t0": self.t, "gold": self.gold_avail,
                    "kills": 0, "leaks": 0, "lt": {}}

    def _spawn(self, etype):
        d = self.edefs[etype]
        e = Enemy()
        e.tid = etype
        e.hp = self.scaled_hp(etype, self.wave_idx)
        e.speed, e.armor = d["speed"], d.get("armor", 0)
        e.reward, e.ld = d["reward"], d["lives_damage"]
        e.prog = 0.0
        e.x, e.y = self.path.pts[0]
        e.alive = True
        self.enemies.append(e)

    def _damage(self, e, dmg, src=None):
        if not e.alive:
            return
        d = max(1, dmg - e.armor)
        if src is not None:
            src.dealt += min(d, e.hp)
        e.hp -= d
        if e.hp <= 0:
            e.alive = False
            self.gold += e.reward
            self.cur["kills"] += 1
            if src is not None:
                src.kills += 1

    def _end_wave(self, won=False):
        c = self.cur
        c["dur"] = self.t - c["t0"]
        c["lives"] = self.lives
        c["towers"] = self.tower_desc()
        c["invested"] = self.invested_total
        self.records.append(c)

    def tower_desc(self):
        """'G32 S1': one letter per tower type (first letter of its id),
        then one digit per tower = its level."""
        out = []
        for tid in self.tdefs:
            lv = sorted((t.level for t in self.towers if t.tid == tid), reverse=True)
            if lv:
                out.append(tid[0].upper() + "".join(str(x) for x in lv))
        return " ".join(out) or "-"

    # ----- main loop -----
    def run(self):
        self.bot.think(self)        # pre-game build + call wave 1
        while self.phase not in ("over", "won") and self.t < self.max_time:
            self.step()
        return self

    def step(self):
        dt = self.dt
        self.t += dt
        path = self.path
        L = path.length

        # spawning
        if self.phase == "wave" and self.queue:
            self.spawn_timer -= dt
            while self.queue and self.spawn_timer <= 0:
                _, et = self.queue.pop()
                self._spawn(et)
                if self.queue:
                    self.spawn_timer += self.queue[-1][0]

        # enemy movement / leaks
        alive = []
        for e in self.enemies:
            if not e.alive:
                continue
            e.prog += e.speed * dt
            if e.prog >= L:
                e.alive = False
                self.lives -= e.ld
                self.cur["leaks"] += 1
                self.cur["lt"][e.tid] = self.cur["lt"].get(e.tid, 0) + 1
                if self.lives <= 0:
                    self.phase = "over"
                    self._end_wave()
                    return
                continue
            e.x, e.y = path.pos(e.prog)
            alive.append(e)
        self.enemies = alive
        alive.sort(key=lambda en: en.prog, reverse=True)

        # towers
        for t in self.towers:
            t.cd -= dt
            turning = t.attack != "shell"
            if not turning and t.cd > 0:
                continue
            tx, ty, r2 = t.x, t.y, t.r2
            target = None
            for e in alive:
                if not e.alive:
                    continue
                dx, dy = e.x - tx, e.y - ty
                if dx * dx + dy * dy <= r2:
                    target = e
                    break
            if target is None:
                continue
            if turning:
                want = math.atan2(target.y - ty, target.x - tx)
                diff = (want - t.angle + math.pi) % (2 * math.pi) - math.pi
                step = TURN_RATE * dt
                if abs(diff) <= step:
                    t.angle = want
                    diff = 0.0
                else:
                    t.angle += step if diff > 0 else -step
                    diff -= step if diff > 0 else -step
                if t.cd > 0 or abs(diff) > AIM_TOL:
                    continue
            t.cd = 1.0 / t.rate
            t.shots += 1
            if t.attack == "beam":
                self._damage(target, t.dmg, t)
            elif t.attack == "bullet":
                self.bullets.append([tx, ty, target, t.dmg, t.pspeed, t])
            else:  # shell
                dist = math.hypot(target.x - tx, target.y - ty)
                ft = min(1.0, max(0.35, dist / t.pspeed))
                ax, ay = path.pos(min(L, target.prog + target.speed * ft))
                self.shells.append([ft, ax, ay, t.dmg, t.splash * t.splash, t])

        # projectiles
        if self.bullets:
            keep = []
            for b in self.bullets:
                tg = b[2]
                if not tg.alive:
                    continue        # wasted
                dx, dy = tg.x - b[0], tg.y - b[1]
                d = math.hypot(dx, dy)
                stp = b[4] * dt
                if d <= stp:
                    b[0], b[1] = tg.x, tg.y
                    d = 0.0
                else:
                    b[0] += dx / d * stp
                    b[1] += dy / d * stp
                    d -= stp
                if d <= BULLET_HIT:
                    self._damage(tg, b[3], b[5])
                else:
                    keep.append(b)
            self.bullets = keep
        if self.shells:
            keep = []
            for s in self.shells:
                s[0] -= dt
                if s[0] > 0:
                    keep.append(s)
                    continue
                ax, ay, dmg, sp2 = s[1], s[2], s[3], s[4]
                for e in alive:
                    if e.alive and (e.x - ax) ** 2 + (e.y - ay) ** 2 <= sp2:
                        self._damage(e, dmg, s[5])
            self.shells = keep

        # wave end
        if self.phase == "wave" and not self.queue and not any(e.alive for e in self.enemies):
            wi = self.wave_idx
            self._end_wave()
            self.gold += self.cfg["wave_clear_bonus_base"] + self.cfg["wave_clear_bonus_step"] * wi
            self.enemies = []
            self.bullets = []
            self.shells = []
            if wi + 1 >= len(self.waves):
                self.phase = "won"
                return
            self.phase = "between"
            self.countdown = self.cfg["wave_between_delay"]
            self.gold_avail = self.gold
            self.next_think = self.t        # react immediately
        elif self.phase == "between":
            self.countdown -= dt
            if self.countdown <= 0:
                self._start_wave(self.wave_idx + 1)

        if self.t >= self.next_think:
            self.next_think = self.t + getattr(self.bot, "think_every", THINK_EVERY)
            self.bot.think(self)


# ---------------------------------------------------------------------------
# Bots
# ---------------------------------------------------------------------------
class Bot:
    """Greedy value-per-gold player.

    Value of a tower = sum over enemy types of
        w_type * per_hit_damage * fire_rate * splash_hits  *  sqrt(path covered)
    with per_hit = min(max(1, dmg - armor), enemy_hp) (armor + overkill),
    splash_hits = 2.0 for shells (1.5 against armored enemies, which come
    alone or in small groups), and w_type = HP share of the type in the
    current/next wave (75 %) blended with all remaining waves (25 %).
    Each think tick the bot takes the best action by value/gold; if it cannot
    afford it, it takes the best affordable one when that is >= 70 % as good,
    otherwise it saves.

    Tower types are identified by their "attack" field, never by id, so the
    bots keep working when towers are renamed or added in towers.json.
    """

    def __init__(self, name, types=None, upgrades=True,
                 max_towers=None, call_early=False, diversity=0.0, gated=False,
                 think_every=THINK_EVERY, save_ratio=0.7):
        self.name = name
        self.think_every = think_every
        self.save_ratio = save_ratio
        self.gated = gated
        self.types = types           # None = every tower type of the data
        self.upgrades = upgrades
        self.max_towers = max_towers
        self.call_early = call_early
        self.diversity = diversity
        self.builds = 0

    # --- evaluation helpers ---
    def weights(self, g):
        ref = g.wave_idx if g.phase == "wave" else g.wave_idx + 1
        ref = min(max(ref, 0), len(g.waves) - 1)

        def shares(wis):
            hp = {}
            for wi in wis:
                for b in g.waves[wi]["spawns"]:
                    hp[b["type"]] = hp.get(b["type"], 0) + b["count"] * g.scaled_hp(b["type"], wi)
            tot = sum(hp.values()) or 1
            return {k: v / tot for k, v in hp.items()}

        a = shares([ref])
        b = shares(range(ref, len(g.waves)))
        w = {k: 0.75 * a.get(k, 0) + 0.25 * b.get(k, 0) for k in set(a) | set(b)}
        hp_ref = {k: g.scaled_hp(k, ref) for k in g.edefs}
        return w, hp_ref

    def value(self, g, tid, level, tile, w, hp_ref):
        s = tower_stats(g.tdefs[tid], level)
        cov = g.map.coverage(tile, s["range"])
        if cov <= 0:
            return 0.0
        dps = 0.0
        for et, wt in w.items():
            ed = g.edefs[et]
            per_hit = min(max(1, s["damage"] - ed.get("armor", 0)), hp_ref[et])
            hits = 1.0
            if s["attack"] == "shell":
                hits = 1.5 if ed.get("armor", 0) > 0 else 2.0
            dps += wt * per_hit * s["fire_rate"] * hits
        return dps * math.sqrt(cov)

    def best_tile(self, g, tid):
        rng = tower_stats(g.tdefs[tid], 1)["range"]
        best, bk = None, None
        for tile in g.map.buildable:
            if tile in g.occupied:
                continue
            k = (g.map.coverage(tile, rng), -tile[0], -tile[1])
            if bk is None or k > bk:
                best, bk = tile, k
        return best

    def candidates(self, g):
        w, hp_ref = self.weights(g)
        acts = []
        types = list(self.types) if self.types else list(g.tdefs)
        attack = {tid: g.tdefs[tid]["attack"] for tid in types}
        if self.gated:
            # human-like opening: bullet towers first, shell towers once 2
            # towers are up, beam towers once armored enemies show up in the
            # waves seen so far (current / next one included)
            ref = g.wave_idx if g.phase == "wave" else g.wave_idx + 1
            armored = any(g.edefs[b["type"]].get("armor", 0) > 0
                          for wi in range(0, min(ref, len(g.waves) - 1) + 1)
                          for b in g.waves[wi]["spawns"])
            types = [t for t in types if attack[t] == "bullet"
                     or (attack[t] == "shell" and len(g.towers) >= 2)
                     or (attack[t] == "beam" and armored)]
        if self.max_towers is None or self.builds < self.max_towers:
            for tid in types:
                tile = self.best_tile(g, tid)
                if tile is None:
                    continue
                v = self.value(g, tid, 1, tile, w, hp_ref)
                n_same = sum(1 for t in g.towers if t.tid == tid)
                v /= (1 + self.diversity * n_same)
                cost = g.tdefs[tid]["cost"]
                if (self.gated and attack[tid] == "shell" and len(g.towers) >= 3
                        and not any(t.attack == "shell" for t in g.towers)):
                    v *= 3.0    # one shell tower on a multi-segment spot is a must-have
                if v > 0:
                    acts.append((v / cost, cost, "build", tid, tile))
        if self.upgrades:
            for t in g.towers:
                c = g.upgrade_cost(t)
                if c is None:
                    continue
                gain = (self.value(g, t.tid, t.level + 1, t.tile, w, hp_ref)
                        - self.value(g, t.tid, t.level, t.tile, w, hp_ref))
                if gain > 0:
                    acts.append((gain / c, c, "upgrade", t, None))
        return acts

    def think(self, g):
        if g.phase in ("over", "won"):
            return
        if g.phase == "between" and self.call_early:
            g.call_wave()
        for _ in range(50):
            acts = self.candidates(g)
            if not acts:
                break
            best = max(acts, key=lambda a: a[0])
            aff = [a for a in acts if a[1] <= g.gold]
            if not aff:
                break
            pick = max(aff, key=lambda a: a[0])
            if pick is not best and pick[0] < self.save_ratio * best[0]:
                break
            if pick[2] == "build":
                if g.build(pick[3], pick[4]):
                    self.builds += 1
            else:
                g.upgrade(pick[3])
        if g.phase == "pre":
            g.call_wave()


def make_bots(D, think_every=THINK_EVERY, save_ratio=0.7):
    """balanced        : mixes every tower type, upgrades, waits for countdowns
    balanced_greedy : same, but calls every wave immediately (max early bonus)
    cheap_spam      : only the cheapest tower type, never upgrades
    <id>_only       : a single tower type, upgrades allowed (one bot per type)
    weak            : like balanced but stops at 4 towers (under-building player)
    """
    kw = dict(think_every=think_every, save_ratio=save_ratio)
    cheapest = min(D["towers"], key=lambda t: t["cost"])["id"]
    bots = [
        Bot("balanced", diversity=0.15, gated=True, **kw),
        Bot("balanced_greedy", diversity=0.15, gated=True, call_early=True, **kw),
        Bot("cheap_spam", types=(cheapest,), upgrades=False, **kw),
    ]
    bots += [Bot(t["id"] + "_only", types=(t["id"],), **kw) for t in D["towers"]]
    bots.append(Bot("weak", diversity=0.15, gated=True, max_towers=4, **kw))
    return bots


VARIANTS = [(te, sr) for te in (0.25, 0.5, 1.0) for sr in (0.6, 0.7, 0.8)]


def robust(D, title):
    """Run every bot over 9 behaviour variants (reaction period x save ratio)."""
    print("\n=== ROBUSTNESS (%s): 9 variants per bot (think 0.25/0.5/1.0 s x save 0.6/0.7/0.8)" % title)
    rows = {}
    for te, sr in VARIANTS:
        for bot in make_bots(D, te, sr):
            g = Game(D, bot).run()
            rows.setdefault(bot.name, []).append(g)
    for name, gs in rows.items():
        wins = [g for g in gs if g.phase == "won"]
        lost_at = sorted(g.wave_idx + 1 for g in gs if g.phase == "over")
        lives = sorted(g.lives for g in wins)
        mins = sorted(g.t / 60 for g in gs)
        print("  %-16s wins %d/9  lives left (wins) %-26s game over at waves %-20s  %.1f-%.1f min" % (
            name, len(wins), ",".join(map(str, lives)) or "-", ",".join(map(str, lost_at)) or "-",
            mins[0], mins[-1]))


# ---------------------------------------------------------------------------
# Bot-independent benchmark: minimum mono-type gold to hold each wave
# ---------------------------------------------------------------------------
class _Idle:
    def think(self, g):
        pass


def hold_cost(D, tid, level, wi, max_n=40):
    """Min gold of `tid` towers at `level` (best-coverage tiles) to clear wave
    wi alone with zero leaks. Returns (n, gold) or (None, None)."""
    tdef = {t["id"]: t for t in D["towers"]}[tid]
    unit = tdef["cost"] + sum(u["cost"] for u in tdef["upgrades"][:level - 1])
    m = MapInfo(D["maps"][0])
    rng = tower_stats(tdef, level)["range"]
    tiles = sorted(m.buildable, key=lambda t: -m.coverage(t, rng))

    def ok(n):
        g = Game(D, _Idle())
        g.lives = 10 ** 6
        g.gold = 10 ** 9
        for tile in tiles[:n]:
            tw = g.build(tid, tile)
            for _ in range(level - 1):
                g.upgrade(tw)
        g._start_wave(wi)
        while g.phase == "wave" and g.t < 600:
            g.step()
        return g.records and g.records[-1]["leaks"] == 0

    lo, hi = 1, max_n
    if not ok(hi):
        return None, None
    while lo < hi:
        mid = (lo + hi) // 2
        if ok(mid):
            hi = mid
        else:
            lo = mid + 1
    return lo, lo * unit


def economy(D, early=False):
    """Cumulative gold available at each wave start if every enemy is killed."""
    c = D["config"]
    edefs = {e["id"]: e for e in D["enemies"]}
    gold, out = c["starting_gold"], []
    for wi, w in enumerate(D["waves"]):
        out.append(gold)
        gold += sum(b["count"] * edefs[b["type"]]["reward"] for b in w["spawns"])
        gold += c["wave_clear_bonus_base"] + c["wave_clear_bonus_step"] * wi
        if early:
            gold += int(c["wave_between_delay"] * c["early_call_gold_per_sec"])
    return out


def bench(D, title):
    print("\n=== HOLD COST (%s): min gold of one type to clear the wave alone, 0 leak" % title)
    eco = economy(D)
    print("  wave           " + "".join("%6d" % (i + 1) for i in range(len(D["waves"]))))
    print("  gold available " + "".join("%6d" % x for x in eco))
    for tdef in D["towers"]:
        tid = tdef["id"]
        for lv in range(1, len(tdef["upgrades"]) + 2):
            row = []
            for wi in range(len(D["waves"])):
                n, gold = hold_cost(D, tid, lv, wi)
                row.append("%6s" % ("-" if gold is None else gold))
            print("  %-6s L%d      %s" % (tid, lv, "".join(row)))


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------
def run_all(D, only=None, verbose=True):
    results = []
    for bot in make_bots(D):
        if only and bot.name not in only:
            continue
        g = Game(D, bot).run()
        results.append((bot.name, g))
        if verbose:
            print_game(bot.name, g)
    return results


def outcome(g):
    if g.phase == "won":
        return "VICTORY (lives %d)" % g.lives
    if g.phase == "over":
        return "GAME OVER at wave %d" % (g.wave_idx + 1)
    return "TIMEOUT"


def print_game(name, g):
    print("\n## %s -> %s, session %.1f min" % (name, outcome(g), g.t / 60))
    print("  (gold = available at the wave start; towers: type letter + one level digit "
          "per tower; leaks: count + enemy letter)")
    print("  W | lives | gold | towers (levels)             | kill/leak (types)   | dur s")
    for r in g.records:
        lt = " ".join("%d%s" % (n, k[0].upper()) for k, n in sorted(r["lt"].items()))
        print(" %2d | %5d | %4d | %-28s | %4d/%-3d %-10s | %5.1f" % (
            r["wave"], max(r["lives"], 0), r["gold"], r["towers"], r["kills"], r["leaks"],
            "(%s)" % lt if lt else "", r["dur"]))
    eff = []
    for tid in g.tdefs:
        ts = [t for t in g.towers if t.tid == tid]
        if ts:
            inv = sum(t.invested for t in ts)
            eff.append("%s %d dmg / %d gold = %.1f dmg/gold" % (
                tid, sum(t.dealt for t in ts), inv, sum(t.dealt for t in ts) / inv))
    print("  useful damage: " + "; ".join(eff))


def summary(results, title):
    print("\n=== SUMMARY: %s" % title)
    for name, g in results:
        print("  %-16s %-22s %5.1f min  towers: %s" % (name, outcome(g), g.t / 60, g.tower_desc()))


def main():
    ap = argparse.ArgumentParser(
        description="Balance simulation of the tower defense template: bots play "
                    "full games on the JSON data and report each wave.",
        epilog="Bots: balanced, balanced_greedy, cheap_spam, <tower id>_only, weak. "
               "Override paths: config.<key>, towers.<id>.<field>, "
               "towers.<id>.up<N>.<field> (N=1 for level 2), enemies.<id>.<field>, "
               "waves.<wave>.<block>.<field> (numbered from 1).")
    ap.add_argument("--bot", action="append", metavar="NAME",
                    help="run only this bot (repeatable)")
    ap.add_argument("--quiet", action="store_true",
                    help="print only the summary, not the per-wave tables")
    ap.add_argument("--robust", action="store_true",
                    help="run every bot in 9 behaviour variants (reaction time x saving)")
    ap.add_argument("--bench", action="store_true",
                    help="minimum gold of a single tower type to clear each wave without leak")
    ap.add_argument("--set", action="append", default=[], metavar="PATH=VALUE",
                    help="what-if override on a copy of the data (repeatable); the current "
                         "data runs first, then the modified data")
    ap.add_argument("--data", default=DATA_DIR, metavar="DIR",
                    help="folder holding the JSON files (default: ../data)")
    a = ap.parse_args()
    base = load_data(a.data)
    sets = [("CURRENT DATA", base)]
    if a.set:
        try:
            sets.append(("MODIFIED DATA: " + "  ".join(a.set), apply_overrides(base, a.set)))
        except (OverrideError, ValueError) as e:
            ap.error(str(e))
    known_bots = {b.name for b in make_bots(base)}
    for name in a.bot or []:
        if name not in known_bots:
            ap.error("unknown bot '%s' (known: %s)" % (name, ", ".join(sorted(known_bots))))
    for title, D in sets:
        print("\n" + "=" * 70 + "\n" + title + "\n" + "=" * 70)
        if a.bench:
            bench(D, title)
            continue
        if a.robust:
            robust(D, title)
            continue
        res = run_all(D, a.bot, verbose=not a.quiet)
        summary(res, title)


if __name__ == "__main__":
    main()
