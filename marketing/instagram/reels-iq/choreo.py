#!/usr/bin/env python3
"""choreo — turn a quiz scenario into an animated court `play` for the reel.

Marketing-only layer (the iOS app keeps its own static `diagram`). Produces:
  play = {chip, mode?, players:[{team,x,y,move?}], shots:[{from,to,answer?}]}

Coordinates: x 0..1 left→right, y 0..1 TOP(opponent baseline)→BOTTOM(your baseline),
net at y=0.5. Teams: you/partner = gold (Y/P), opp = ink (O). The final `answer`
shot is the recommended play (gold, emphasised); earlier shots build the setup.

Singles use category story-templates + keyword-driven answer geometry. All 26
DOUBLES are hand-authored with correct 4-player formations + movement (the app's
data only had 2 dots). Mental scenarios get a calm "reset" beat (no rally).
"""
import re

# ---- geometry helpers (opponent side is y<0.5, your side y>0.5) -------------
def _clamp(v, lo=0.06, hi=0.94): return max(lo, min(hi, v))

def answer_target(ans, you, opp, cat):
    """Where the recommended shot goes, from the answer wording. Returns [x,y]
    on the opponent side (deep unless the shot is a drop/short-angle)."""
    a = ans.lower()
    yx = you[0]; ox = opp[0] if opp else 0.5
    far = lambda x: [_clamp(x), 0.12]                      # deep on opp baseline
    cross_x = 0.82 if yx < 0.5 else 0.18                   # diagonal corner
    line_x  = 0.18 if yx < 0.5 else 0.82                   # same-side line
    away_x  = 0.80 if ox < 0.5 else 0.20                   # into the open court, away from opp
    if "lob" in a:                    return [_clamp(cross_x if "cross" in a else 0.5), 0.05]
    if "drop" in a:                   return [_clamp(0.62 if yx < 0.5 else 0.38), 0.44]
    if "short" in a and "angle" in a: return [_clamp(cross_x), 0.34]
    if "down the line" in a or "down-the-line" in a or "up the line" in a: return far(line_x)
    if "open" in a or "into the space" in a or "into space" in a: return far(away_x)
    if "middle" in a or " t " in a or "the t" in a or "through the" in a:  return [0.5, 0.10]
    if "cross" in a:                  return far(cross_x)
    if "wide" in a:                   return far(line_x)
    if "deep" in a:                   return [0.5, 0.09]
    if "body" in a:                   return far(0.5)
    return far(away_x)                # default: open the court away from the opponent

def _pos(v, d):  return v if isinstance(v, (int, float)) else d

# =============================================================================
# SINGLES
# =============================================================================
def build_serve(q, d):
    yx = _pos(d.get("youX"), 0.5); ox = _pos(d.get("opponentX"), 0.5)
    you = [yx, 0.95]; opp = [ox, 0.07]
    ans = q["options"][q["correctAnswerIndex"]]; a = ans.lower()
    players = [{"team": "you", "x": you[0], "y": you[1]},
               {"team": "opp", "x": opp[0], "y": opp[1]}]
    if a.startswith("serve") or ("serve" in a and any(k in a for k in ["t ", " t", "wide", "body", "kick"])):
        # the SERVE placement is the answer
        box = 0.5 if (" t" in a or "the t" in a) else (opp[0] if "body" in a else (0.16 if ox > 0.5 else 0.84))
        return {"chip": d.get("scoreChip"), "players": players,
                "shots": [{"from": you, "to": [_clamp(box), 0.40], "answer": True}]}
    # serve + first strike (+1)
    box = [_clamp(ox + (0.12 if ox < 0.5 else -0.12)), 0.42]
    ret = [0.5, 0.60]
    return {"chip": d.get("scoreChip"), "players": players,
            "shots": [{"from": you, "to": box},
                      {"from": box, "to": ret},
                      {"from": ret, "to": answer_target(ans, you, opp, "serve"), "answer": True}]}

def build_return(q, d):
    yx = _pos(d.get("youX"), 0.5)
    you = [yx, _pos(d.get("youY"), 0.92)]; opp = [_pos(d.get("opponentX"), 0.5), 0.06]
    ans = q["options"][q["correctAnswerIndex"]]; a = ans.lower()
    contact = [_clamp(yx + (opp[0] - yx) * 0.15), min(you[1], 0.86)]
    p_you = {"team": "you", "x": you[0], "y": you[1]}
    if any(k in a for k in ["stand", "inside the baseline", "step in", "back up", "position", "further back", "deeper"]):
        p_you["move"] = [you[0], 0.72 if any(k in a for k in ["inside", "step in", "take time"]) else 0.99]
    return {"chip": d.get("scoreChip"),
            "players": [p_you, {"team": "opp", "x": opp[0], "y": opp[1]}],
            "shots": [{"from": opp, "to": contact},
                      {"from": contact, "to": answer_target(ans, you, opp, "return"), "answer": True}]}

def build_rally(q, d):
    yx = _pos(d.get("youX"), 0.30); ox = _pos(d.get("opponentX"), 0.70)
    you = [yx, 0.90]; opp = [ox, 0.10]
    ans = q["options"][q["correctAnswerIndex"]]; a = ans.lower()
    p_you = {"team": "you", "x": you[0], "y": you[1]}
    if any(k in a for k in ["inside the baseline", "on the rise", "take it early", "step in", "move up", "move in"]):
        p_you["move"] = [you[0], 0.74]
    incoming = [_clamp(ox), 0.22]
    mine = [_clamp(yx), 0.80]
    return {"chip": d.get("scoreChip"),
            "players": [p_you, {"team": "opp", "x": opp[0], "y": opp[1]}],
            "shots": [{"from": incoming, "to": mine},
                      {"from": mine, "to": incoming},
                      {"from": [_clamp(yx), 0.82], "to": answer_target(ans, you, opp, "rally"), "answer": True}]}

def build_net(q, d):
    yx = _pos(d.get("youX"), 0.4)
    you = [yx, _pos(d.get("youY"), 0.58)]; opp = [_pos(d.get("opponentX"), 0.25), 0.10]
    ans = q["options"][q["correctAnswerIndex"]]; a = ans.lower()
    p_you = {"team": "you", "x": you[0], "y": you[1]}
    positional = any(k in a for k in ["split", "service line", "bisect", "position", "stand", "closer", "step",
                                      "toward", "move up", "recover", "cover"])
    if positional:
        tgt_x = 0.5 if "bisect" in a or "middle" in a else (yx + (0.12 if "cross" in a else -0.06))
        p_you["move"] = [_clamp(tgt_x), _clamp(you[1] - 0.06, 0.42, 0.7)]
        pass_to = [_clamp(opp[0] + (0.5 - opp[0]) * 0.4), 0.44]
        return {"chip": d.get("scoreChip"),
                "players": [p_you, {"team": "opp", "x": opp[0], "y": opp[1]}],
                "shots": [{"from": opp, "to": pass_to},
                          {"from": you, "to": [_clamp(opp[0]), 0.12], "answer": True}]}
    return {"chip": d.get("scoreChip"),
            "players": [p_you, {"team": "opp", "x": opp[0], "y": opp[1]}],
            "shots": [{"from": opp, "to": [_clamp(yx), you[1] - 0.06]},
                      {"from": you, "to": answer_target(ans, you, opp, "net"), "answer": True}]}

def build_mental(q, d):
    yx = _pos(d.get("youX"), 0.5)
    return {"chip": d.get("scoreChip"), "mode": "mental",
            "players": [{"team": "you", "x": yx, "y": _pos(d.get("youY"), 0.9)}], "shots": []}

# =============================================================================
# DOUBLES — 26 hand-authored 4-player formations (Y+P your team, O+O opponents)
# Position language: YN your-net .58 · YB your-baseline .90 · YT transition .73
#                    OR opp-returner/baseline .08 · ON opp-net .38
# =============================================================================
def _dbl(chip, you, partner, opp1, opp2, shots):
    def pl(team, p):
        o = {"team": team, "x": p[0], "y": p[1]}
        if len(p) > 2: o["move"] = p[2]
        return o
    return {"chip": chip,
            "players": [pl("you", you), pl("partner", partner), pl("opp", opp1), pl("opp", opp2)],
            "shots": shots}

def _sh(a, b, ans=False): return {"from": list(a), "to": list(b), "answer": ans}

DOUBLES = {
 # one-up-one-back; short ball to baseline partner → BOTH move up behind approach
 "doubles_001": _dbl("BOTH UP", [0.30, 0.58, [0.34, 0.50]], [0.70, 0.90, [0.66, 0.55]],
    [0.34, 0.38], [0.70, 0.08],
    [_sh([0.70, 0.08], [0.66, 0.62]), _sh([0.66, 0.62], [0.42, 0.12], True)]),
 # net player while partner serves → start centred, ready to poach the middle
 "doubles_002": _dbl("POACH READY", [0.34, 0.56, [0.5, 0.5]], [0.72, 0.93],
    [0.30, 0.08], [0.74, 0.36],
    [_sh([0.72, 0.93], [0.34, 0.14]), _sh([0.30, 0.08], [0.5, 0.5], True)]),
 # serve & volley; return low at feet → first volley deep/low through middle
 "doubles_003": _dbl("1ST VOLLEY", [0.55, 0.62, [0.52, 0.52]], [0.30, 0.90],
    [0.72, 0.08], [0.28, 0.36],
    [_sh([0.72, 0.08], [0.55, 0.64]), _sh([0.55, 0.6], [0.5, 0.10], True)]),
 # returning vs one net player → keep it LOW crosscourt at the volleyer's feet
 "doubles_004": _dbl("RETURN LOW", [0.72, 0.90], [0.34, 0.62],
    [0.30, 0.40], [0.72, 0.08],
    [_sh([0.72, 0.08], [0.72, 0.86]), _sh([0.72, 0.86], [0.30, 0.42], True)]),
 # poach timing → commit just after the serve bounces / forward swing
 "doubles_005": _dbl("POACH", [0.35, 0.56, [0.60, 0.50]], [0.68, 0.93],
    [0.30, 0.08], [0.72, 0.36],
    [_sh([0.68, 0.93], [0.34, 0.14]), _sh([0.30, 0.10], [0.60, 0.48], True)]),
 # lob over partner's head to open side → un-lobbed player calls switch & crosses
 "doubles_006": _dbl("SWITCH", [0.34, 0.58, [0.68, 0.72]], [0.70, 0.56, [0.40, 0.56]],
    [0.5, 0.10], [0.74, 0.36],
    [_sh([0.5, 0.10], [0.74, 0.86]), _sh([0.34, 0.58], [0.5, 0.12], True)]),
 # partner ready to poach; where to serve → body/T to pull return to the middle
 "doubles_007": _dbl("SERVE T", [0.62, 0.94], [0.36, 0.56, [0.5, 0.50]],
    [0.28, 0.08], [0.72, 0.36],
    [_sh([0.62, 0.94], [0.42, 0.40], True)]),
 # ball down the middle → pre-agreed / forehand-in-middle player takes it
 "doubles_008": _dbl("MIDDLE", [0.36, 0.60], [0.66, 0.60],
    [0.30, 0.10], [0.70, 0.10],
    [_sh([0.30, 0.10], [0.5, 0.46]), _sh([0.5, 0.46], [0.5, 0.60], True)]),
 # big server picking off net player → briefly go BOTH BACK, then climb to net
 "doubles_009": _dbl("BOTH BACK", [0.32, 0.58, [0.34, 0.90]], [0.68, 0.90],
    [0.5, 0.06], [0.74, 0.36],
    [_sh([0.5, 0.06], [0.34, 0.86]), _sh([0.34, 0.86], [0.34, 0.5], True)]),
 # opposing net player keeps poaching → LOB them off the net
 "doubles_010": _dbl("LOB POACHER", [0.60, 0.90], [0.30, 0.62],
    [0.35, 0.40], [0.70, 0.10],
    [_sh([0.70, 0.10], [0.60, 0.86]), _sh([0.60, 0.86], [0.35, 0.05], True)]),
 # returner burned partner twice → switch to I-FORMATION (net partner crouched at T)
 "doubles_hard_1": _dbl("I-FORMATION", [0.50, 0.94], [0.50, 0.52, [0.30, 0.52]],
    [0.72, 0.08], [0.74, 0.36],
    [_sh([0.50, 0.94], [0.42, 0.40], True)]),
 # middle ball → forehand-in-the-middle player takes it (default)
 "doubles_100": _dbl("MIDDLE BALL", [0.34, 0.60], [0.66, 0.60],
    [0.30, 0.10], [0.70, 0.10],
    [_sh([0.30, 0.10], [0.5, 0.46]), _sh([0.5, 0.46], [0.66, 0.58], True)]),
 # partner serving; your job at net → be a threat: shift, fake, take floaters
 "doubles_101": _dbl("NET THREAT", [0.34, 0.56, [0.5, 0.50]], [0.72, 0.93],
    [0.30, 0.08], [0.74, 0.36],
    [_sh([0.72, 0.93], [0.30, 0.14]), _sh([0.30, 0.10], [0.5, 0.44], True)]),
 # returning vs active poacher → crosscourt LOW over the middle, away from reach
 "doubles_102": _dbl("VS POACHER", [0.30, 0.88], [0.66, 0.62],
    [0.62, 0.38], [0.30, 0.10],
    [_sh([0.30, 0.10], [0.30, 0.84]), _sh([0.30, 0.84], [0.66, 0.30], True)]),
 # want to poach more → go when partner's serve jams the returner (body/T)
 "doubles_103": _dbl("POACH", [0.62, 0.58, [0.42, 0.50]], [0.30, 0.94],
    [0.30, 0.12], [0.66, 0.36],
    [_sh([0.30, 0.94], [0.36, 0.40]), _sh([0.30, 0.14], [0.42, 0.48], True)]),
 # lob over net partner → baseline player calls it, crosses; partner switches
 "doubles_104": _dbl("LOB SWITCH", [0.30, 0.90, [0.66, 0.86]], [0.62, 0.56, [0.34, 0.56]],
    [0.60, 0.12], [0.30, 0.36],
    [_sh([0.60, 0.12], [0.66, 0.84]), _sh([0.66, 0.84], [0.5, 0.10], True)]),
 # losing from one-up-one-back → the diagonal SEAM in the middle is the hole
 "doubles_105": _dbl("THE SEAM", [0.30, 0.58], [0.70, 0.88],
    [0.70, 0.40], [0.30, 0.10],
    [_sh([0.30, 0.10], [0.5, 0.50]), _sh([0.5, 0.50], [0.52, 0.72], True)]),
 # serve & come in, all four active → first volley LOW through the middle
 "doubles_106": _dbl("MIDDLE", [0.50, 0.62, [0.5, 0.52]], [0.30, 0.90],
    [0.30, 0.36], [0.70, 0.36],
    [_sh([0.5, 0.72], [0.5, 0.62]), _sh([0.5, 0.60], [0.5, 0.42], True)]),
 # crosscourt return dismantling formation → I-FORMATION hides net player
 "doubles_107": _dbl("I-FORMATION", [0.50, 0.94], [0.50, 0.52, [0.68, 0.52]],
    [0.72, 0.08], [0.74, 0.36],
    [_sh([0.50, 0.94], [0.58, 0.40], True)]),
 # collided going for same ball → loud early calls on EVERY ball
 "doubles_108": _dbl("CALL IT", [0.38, 0.62], [0.64, 0.62],
    [0.30, 0.10], [0.70, 0.10],
    [_sh([0.5, 0.10], [0.5, 0.50]), _sh([0.5, 0.50], [0.5, 0.60], True)]),
 # server rushes net behind every serve → return LOW at the incoming server's feet
 "doubles_109": _dbl("AT THE FEET", [0.30, 0.88], [0.66, 0.62],
    [0.55, 0.36], [0.30, 0.10],
    [_sh([0.30, 0.10], [0.30, 0.84]), _sh([0.30, 0.84], [0.55, 0.40], True)]),
 # both opponents at net hammering partner → pull BOTH back, turn it into a lob game
 "doubles_110": _dbl("BOTH BACK", [0.50, 0.58, [0.32, 0.90]], [0.70, 0.72, [0.68, 0.90]],
    [0.35, 0.40], [0.65, 0.40],
    [_sh([0.35, 0.40], [0.5, 0.6]), _sh([0.5, 0.72], [0.5, 0.05], True)]),
 # deuce side: T serve (not wide) → cuts the return angle for the net partner
 "doubles_111": _dbl("TEAM SERVE", [0.40, 0.96], [0.68, 0.56, [0.5, 0.50]],
    [0.25, 0.08], [0.74, 0.36],
    [_sh([0.40, 0.96], [0.46, 0.40], True)]),
 # ad side break point, alley 'open' → ignore the bait, low crosscourt over middle
 "doubles_112": _dbl("AD RETURN", [0.30, 0.90], [0.66, 0.62],
    [0.30, 0.40], [0.66, 0.10],
    [_sh([0.66, 0.10], [0.30, 0.86]), _sh([0.30, 0.86], [0.58, 0.30], True)]),
 # partner pulled wide to their forehand → YOU shift the same way, cover middle
 "doubles_113": _dbl("UNIT SHIFT", [0.55, 0.56, [0.40, 0.56]], [0.20, 0.72, [0.16, 0.80]],
    [0.25, 0.14], [0.66, 0.36],
    [_sh([0.66, 0.36], [0.20, 0.66]), _sh([0.55, 0.56], [0.42, 0.44], True)]),
 # heavy approach, opponents scrambling deep → BOTH close to the net, cut angles
 "doubles_114": _dbl("BOTH CLOSE", [0.40, 0.58, [0.40, 0.48]], [0.62, 0.58, [0.62, 0.48]],
    [0.5, 0.06], [0.75, 0.12],
    [_sh([0.5, 0.72], [0.5, 0.10]), _sh([0.5, 0.48], [0.68, 0.30], True)]),
}

# =============================================================================
def build_play(q):
    d = q.get("diagram") or {}
    cat = q["category"]
    if cat == "doubles":
        if q["id"] in DOUBLES:
            return DOUBLES[q["id"]]
        # fallback: generic one-up-one-back with 4 dots
        return _dbl(d.get("scoreChip"), [0.32, 0.58], [0.68, 0.90], [0.30, 0.10], [0.70, 0.10],
                    [_sh([0.30, 0.10], [0.5, 0.5]), _sh([0.5, 0.5], [0.5, 0.60], True)])
    return {"serve": build_serve, "returnPlay": build_return, "rally": build_rally,
            "net": build_net, "mental": build_mental}.get(cat, build_mental)(q, d)


if __name__ == "__main__":
    import json, os
    HERE = os.path.dirname(os.path.abspath(__file__))
    data = json.load(open(os.path.join(HERE, "../../..", "CourtIQ/Resources/Content/quiz_questions.json")))
    from collections import Counter
    c = Counter()
    for q in data:
        p = build_play(q)
        n = len(p.get("players", []))
        c[(q["category"], n)] += 1
        if q["category"] == "doubles" and n != 4:
            print("!! doubles not 4 dots:", q["id"])
        if not p.get("shots") and p.get("mode") != "mental":
            print("!! no shots + not mental:", q["id"])
    for k in sorted(c): print(k, c[k])
