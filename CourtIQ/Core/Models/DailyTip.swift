import Foundation

// MARK: - Category

enum TipCategory: String, CaseIterable, Codable, Identifiable {
    case tactics, technique, fitness, mental
    var id: String { rawValue }

    var title: String {
        switch self {
        case .tactics:   return "Tactics"
        case .technique: return "Technique"
        case .fitness:   return "Fitness"
        case .mental:    return "Mental"
        }
    }

    var systemImage: String {
        switch self {
        case .tactics:   return "arrow.triangle.branch"
        case .technique: return "figure.tennis"
        case .fitness:   return "bolt.heart.fill"
        case .mental:    return "brain.head.profile"
        }
    }
}

// MARK: - Model

struct DailyTip: Identifiable, Codable, Hashable {
    let id: String
    let category: TipCategory
    let title: String
    let body: String
    let source: String?   // e.g. "ATP/WTA pattern data"
}

// MARK: - Manager

@MainActor
final class TipManager: ObservableObject {
    static let shared = TipManager()

    @Published private(set) var todayTip: DailyTip

    private init() {
        todayTip = TipManager.tip(for: Date())
    }

    static func tip(for date: Date) -> DailyTip {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let index = (dayOfYear - 1) % tips.count
        return tips[index]
    }

    /// Tip ID used as the community thread anchor.
    var todayThreadID: String { "tip:\(todayTip.id)" }
}

// MARK: - Curated tip bank (50 tips)

extension TipManager {
    static let tips: [DailyTip] = [

        // MARK: Tactics (18 tips)

        DailyTip(id: "t01", category: .tactics,
            title: "Attack the short ball cross-court first",
            body: "When a short ball sits up in the middle, your highest-percentage play is a heavy cross-court approach — it travels over the lowest part of the net and lands in the deepest part of the court. Opening down the line works, but only when your approach is truly short and puts you inside the baseline.",
            source: "ATP baseline pattern analysis"),

        DailyTip(id: "t02", category: .tactics,
            title: "Serve to the body on break points",
            body: "Most players default to wide or T under pressure, which is exactly what returners prepare for. A flat serve directly at the hip jams the swing and produces weak, central replies you can step into and drive for a winner or easy put-away.",
            source: nil),

        DailyTip(id: "t03", category: .tactics,
            title: "Use spin on second serve — not pace",
            body: "Second-serve pace rarely adds safety. Heavy topspin or slice does. A kick serve that bounces above shoulder height forces awkward contact and gives you time to position. Focus on a brushing swing path, not a faster arm.",
            source: "ITF coaching curriculum"),

        DailyTip(id: "t04", category: .tactics,
            title: "Return deep and central on a first serve wide",
            body: "When the serve pulls you off the court, punching deep to the middle neutralises the angle and keeps you in the rally. Don't go for the down-the-line winner — your contact point is too wide and your margin for error collapses.",
            source: nil),

        DailyTip(id: "t05", category: .tactics,
            title: "Close the net behind your approach",
            body: "An approach shot that doesn't get you inside the service line is just a slower groundstroke. The lob is your opponent's escape; take it away by closing aggressively so your volleying position already covers the passing lane.",
            source: nil),

        DailyTip(id: "t06", category: .tactics,
            title: "Target the backhand on a big serve wide in the deuce court",
            body: "Going wide in the deuce court naturally drags your opponent off court to their forehand. Most players expect a follow-up forehand. Instead, drive to the open space behind the backhand hip — they're still moving and rarely recover in time.",
            source: "ATP serve-plus-one data"),

        DailyTip(id: "t07", category: .tactics,
            title: "Rally cross-court until you get a short ball",
            body: "The safest rally ball is cross-court: longest diagonal, lowest part of net, deepest landing zone. Change direction only when you have a ball above net height inside the baseline. Patience beats courage in the majority of baseline exchanges.",
            source: nil),

        DailyTip(id: "t08", category: .tactics,
            title: "Neutralise with heavy topspin to the open court",
            body: "When you're pulled wide or on the run, don't try to win the point — reset it. Looping heavy topspin to the open side buys you time to recover and shifts pressure back. The high ball makes your opponent generate their own pace.",
            source: nil),

        DailyTip(id: "t09", category: .tactics,
            title: "Use the slice backhand as a change of pace",
            body: "A slice that stays low and skids through forces your opponent to lift from below the tape. Use it occasionally mid-rally to disrupt rhythm, not as a default. Three slice balls in a row is a pattern your opponent will read and attack.",
            source: nil),

        DailyTip(id: "t10", category: .tactics,
            title: "Hold the T position at net in doubles",
            body: "In doubles, the net team controls the T — the centre service line. Stand there, not glued to your alley. From the T you can poach on the move, cut off cross-court angles, and force the opponents to attempt riskier down-the-line shots.",
            source: "ITF doubles fundamentals"),

        DailyTip(id: "t11", category: .tactics,
            title: "Aim behind the incoming player in a fast exchange",
            body: "When both players are moving and you're in a rapid exchange, aiming behind the moving player catches them wrong-footed. Their momentum carries them past where the ball lands. This is especially effective on a second-ball follow-up at net.",
            source: nil),

        DailyTip(id: "t12", category: .tactics,
            title: "Press on weak second serves — even if you miss",
            body: "Being aggressive on a weak second serve changes the server's psychology, not just that point. Even if you frame the return, the server knows you're going to attack every second ball. That mental pressure accumulates over a set.",
            source: nil),

        DailyTip(id: "t13", category: .tactics,
            title: "Lob when both opponents are at net in doubles",
            body: "Against two players at the net, the lob is your primary weapon, not a panic shot. Aim for the backhand overhead side of the player covering the centre. They have less time, less comfort, and it opens the whole court for your partner.",
            source: nil),

        DailyTip(id: "t14", category: .tactics,
            title: "Return with margin on the ad side wide serve",
            body: "The wide serve in the ad court jams the backhand of right-handers. If you block it cross-court with margin, you control the rally. Trying to rip it down the line from a jammed position is a low-percentage decision that hands free points to the server.",
            source: nil),

        DailyTip(id: "t15", category: .tactics,
            title: "Serve and volley on second serves occasionally",
            body: "A surprise serve-and-volley on your second serve wrong-foots returners who are programmed to attack. Even one or two a set changes how they strike the return, because they don't know when it's coming. Unpredictability is a tactic.",
            source: nil),

        DailyTip(id: "t16", category: .tactics,
            title: "Drive through the backhand consistently under pressure",
            body: "When you're on the run or out of position, a reliable backhand drive — even if not a winner — keeps the ball deep and your opponent honest. A tentative poke or drop shot in pressure moments telegraphs insecurity.",
            source: nil),

        DailyTip(id: "t17", category: .tactics,
            title: "After a double fault, focus on your first serve",
            body: "Following a double fault, the psychological pull is to ease up on the first serve 'just in case'. Resist it. A cautious first serve produces short, attackable balls. Trust your first-serve mechanics and commit fully.",
            source: nil),

        DailyTip(id: "t18", category: .tactics,
            title: "In a tiebreak, play your opponent's weakest side more",
            body: "Tiebreaks are decided on short points where patterns matter less and execution matters more. Target your opponent's weaker wing on roughly 70% of shots instead of your usual variety — it's not a rally, it's a pressure test.",
            source: nil),

        // MARK: Technique (15 tips)

        DailyTip(id: "tc01", category: .technique,
            title: "Brush up the back of the ball for topspin",
            body: "Topspin is generated by the racket face moving from low-to-high while brushing the top-back portion of the ball. If your strings are facing the ball (perpendicular), you produce a flat ball. Tilt the face slightly closed at contact and accelerate the brushing motion upward.",
            source: nil),

        DailyTip(id: "tc02", category: .technique,
            title: "Stay sideways on the backhand slice",
            body: "The slice backhand loses its skid and control when you open your shoulders too early. Staying sideways through contact keeps the racket face stable and lets you direct the ball. Your hips rotate after contact, not before.",
            source: nil),

        DailyTip(id: "tc03", category: .technique,
            title: "Split step before every ball — even in practice",
            body: "The split step is not optional in match play, but it starts as a habit in practice. If you only split in matches, you'll be late on instinct. Build it in every warm-up rally so it becomes unconscious.",
            source: "ITF movement fundamentals"),

        DailyTip(id: "tc04", category: .technique,
            title: "Drop the racket head below the ball on the serve",
            body: "The trophy position is not the launch position. From trophy, let the racket drop into the backscratching phase — head well below the shoulder. This loads the kinetic chain so that the forward swing is explosive rather than arm-only.",
            source: nil),

        DailyTip(id: "tc05", category: .technique,
            title: "Contact point on the volley is in front of your body",
            body: "Volleying late — beside or behind your hip — costs you control and pace. Punch through the ball while it's still in front of your hitting shoulder. Short backswing, forward punch, firm wrist.",
            source: nil),

        DailyTip(id: "tc06", category: .technique,
            title: "Recover to the centre of the possible reply angles",
            body: "After every shot, recover not to a fixed spot, but to the midpoint of the angles your shot leaves open. A deep cross-court ball leaves your opponent a narrow down-the-line and a wider cross-court. Your recovery position splits the difference.",
            source: nil),

        DailyTip(id: "tc07", category: .technique,
            title: "Toss slightly inside the baseline for a kick serve",
            body: "A kick serve that jumps high requires a toss behind and slightly to the left (for right-handers) of your body, not in front. The brushing contact at the back-top of the ball creates the topspin that makes the ball jump left and above shoulder height.",
            source: nil),

        DailyTip(id: "tc08", category: .technique,
            title: "Use a short unit turn for fast exchanges",
            body: "On balls hit directly at you or with little time, a full unit turn is impractical. A compact shoulder-and-arm turn with a short backswing keeps the swing tight and allows you to absorb pace and redirect without losing control.",
            source: nil),

        DailyTip(id: "tc09", category: .technique,
            title: "Finish your follow-through across the body",
            body: "An abbreviated follow-through is a sign that deceleration happened before contact. The ball has already left the strings by the time the swing ends, but the mental cue of 'swing through, not at' keeps your arm accelerating through the contact zone.",
            source: nil),

        DailyTip(id: "tc10", category: .technique,
            title: "Flex your knees before you swing — not during",
            body: "Knee bend needs to happen in the loading phase, before you initiate the swing. Bending mid-swing breaks your kinetic chain and pushes the contact point back. Get low, stay low, then drive upward as the swing begins.",
            source: nil),

        DailyTip(id: "tc11", category: .technique,
            title: "Turn the shoulder fully on the forehand backswing",
            body: "A half-shoulder turn produces a weak forehand. Your left shoulder (for right-handers) should point toward your target as the racket reaches the backswing position. The full turn loads the shoulder and creates the elastic energy your swing releases at contact.",
            source: nil),

        DailyTip(id: "tc12", category: .technique,
            title: "Watch the ball hit the strings",
            body: "Most unforced errors happen when the eyes leave the ball before contact. Train yourself to see the ball contact the strings — even for a fraction of a second. This keeps your head still and your contact point consistent.",
            source: nil),

        DailyTip(id: "tc13", category: .technique,
            title: "On the overhead, get your racket up early",
            body: "The overhead fails when players wait too long to prepare. As soon as you see a lob, get the racket up into the throwing position and move your feet behind the ball. Preparation gives you time; lack of preparation forces guesswork.",
            source: nil),

        DailyTip(id: "tc14", category: .technique,
            title: "Slice approach down the line, topspin approach cross-court",
            body: "A slice approach works best down the line because it stays low and skids fast, making your opponent stretch wide. A topspin approach cross-court opens the court better because the angle of spin creates a higher bounce that pushes your opponent further from centre.",
            source: nil),

        DailyTip(id: "tc15", category: .technique,
            title: "Grip pressure: firm at contact, relaxed in the swing",
            body: "Gripping too tightly through the entire stroke slows your arm speed and reduces feel. Relax your grip on the backswing, then firm it instinctively at the moment of contact. The swing stays fast; the contact stays controlled.",
            source: nil),

        // MARK: Fitness (9 tips)

        DailyTip(id: "f01", category: .fitness,
            title: "Lateral shuffle speed starts with your hips, not your feet",
            body: "Quick lateral movement requires hip abductor strength, not just fast feet. Players who struggle to cover wide balls often have weak hips rather than slow legs. Lateral band walks and side-lying clamshells are ten-minute investments that pay off mid-set.",
            source: nil),

        DailyTip(id: "f02", category: .fitness,
            title: "Train your first three steps, not your top speed",
            body: "Tennis points rarely require running more than five metres. First-step explosiveness — the ability to accelerate from a dead stop — matters far more than raw speed. Reactive starts, agility ladders from still positions, and loaded split steps build this quality.",
            source: "USTA Sport Science"),

        DailyTip(id: "f03", category: .fitness,
            title: "Warm up your shoulder before serving",
            body: "Cold shoulder muscles resist the external rotation needed for a full serve motion, putting the rotator cuff under unnecessary strain. Five minutes of arm circles, band pull-aparts, and slow-motion service motions before hitting a single hard serve protects the joint across a full season.",
            source: nil),

        DailyTip(id: "f04", category: .fitness,
            title: "Core strength transfers directly to serve speed",
            body: "The serve is a total-body rotation. Your core transmits energy from legs to arm. A weak core leaks power. Anti-rotation exercises — pallof press, dead bugs, plank variations — build the stiffness needed to transfer force without energy loss.",
            source: nil),

        DailyTip(id: "f05", category: .fitness,
            title: "Hydrate before you feel thirsty",
            body: "Thirst signals dehydration that's already affecting coordination and decision-making. Drink 500ml before your practice or match, sip during changeovers, and replace 1.5 times whatever you sweat out after. Even a 2% fluid deficit degrades reaction time measurably.",
            source: "Sports nutrition research"),

        DailyTip(id: "f06", category: .fitness,
            title: "Cool down with light movement, not static stretching",
            body: "After intense play, a five-minute walk or easy cycling brings the heart rate down gradually and helps clear metabolic waste from muscles. Static stretching works better in a separate recovery session 30–60 minutes later when the muscle is still warm but not acutely fatigued.",
            source: nil),

        DailyTip(id: "f07", category: .fitness,
            title: "Calf strength prevents ankle rolls on clay and grass",
            body: "Lateral movements on slow and slick surfaces stress the ankle joint. Strong calves and peroneals absorb the stress of quick direction changes. Calf raises on an unstable surface (Bosu or a folded mat) build the proprioceptive strength that prevents the first roll from becoming a sprain.",
            source: nil),

        DailyTip(id: "f08", category: .fitness,
            title: "Sleep is your best recovery tool",
            body: "Growth hormone — which repairs muscle tissue — is released primarily during deep sleep. Amateur players who sleep under seven hours between match days show elevated injury risk, slower reaction times, and lower accuracy scores. Prioritise sleep over an extra hour of hitting.",
            source: "Sleep and sports performance research"),

        DailyTip(id: "f09", category: .fitness,
            title: "Explosive plyometrics once per week improve court coverage",
            body: "Box jumps, broad jumps, and lateral bounds develop the fast-twitch muscle fibres that tennis relies on. One focused plyometric session per week — not three — is enough to build this quality without overloading tendons. Quality over quantity; full recovery between sets.",
            source: nil),

        // MARK: Mental (8 tips)

        DailyTip(id: "m01", category: .mental,
            title: "Between points: breathe, bounce, and focus on your next serve",
            body: "The 25-second between-point routine is your mental reset. Walk slowly, take two full breaths, hold your racket loose, and visualise exactly where your next serve lands. Players who have a deliberate routine recover faster from errors than those who dwell or rush.",
            source: "Sports psychology research"),

        DailyTip(id: "m02", category: .mental,
            title: "Play one ball at a time — literally",
            body: "'Stay in the moment' is vague. 'Play this ball' is concrete. Direct your attention to the exact ball approaching — its height, spin, pace — rather than the score, the last error, or the upcoming serve. One ball. Then the next.",
            source: nil),

        DailyTip(id: "m03", category: .mental,
            title: "Analyse the last point only on changeovers",
            body: "Trying to fix what went wrong during a point while the next one starts is the fastest route to a second error. Save your analysis for changeovers, when you have 90 seconds, a towel, and your breath. During the game, compete. Between sets, think.",
            source: nil),

        DailyTip(id: "m04", category: .mental,
            title: "Your body language affects your opponent",
            body: "Upright posture, deliberate movement, and controlled racket tapping between points signal confidence. Slumped shoulders, rushed movement, and visible frustration signal vulnerability. You don't have to feel confident — you have to look it.",
            source: nil),

        DailyTip(id: "m05", category: .mental,
            title: "Embrace tight scores instead of dreading them",
            body: "A 4-4 third set isn't a crisis — it's the whole point of the game. Players who reframe tight moments as opportunities to demonstrate what they've built perform better than those who view them as threats. Pressure is a privilege given to competitors who are still in it.",
            source: nil),

        DailyTip(id: "m06", category: .mental,
            title: "Set process goals, not outcome goals, during warm-up",
            body: "Telling yourself to 'win today' during the warm-up creates anxiety you can't do anything about. Instead, set a process goal: 'I'll split step on every ball' or 'I'll follow every approach shot to the net'. Process goals give your brain something specific to act on.",
            source: nil),

        DailyTip(id: "m07", category: .mental,
            title: "Decide on your serve direction before you toss",
            body: "Changing your serve decision mid-toss is a reliable recipe for a fault. Choose your target — wide, T, or body — before the toss begins. Then commit and execute without second-guessing. Indecision produces the worst of both options.",
            source: nil),

        DailyTip(id: "m08", category: .mental,
            title: "After a bad game, reset your score — not your game plan",
            body: "Losing a love game triggers the impulse to change everything. Usually the right answer is to hold the pattern and fix the execution — not abandon a sound tactic because of one bad game. Ask yourself: was the plan wrong, or was the contact wrong?",
            source: nil),
    ]
}
