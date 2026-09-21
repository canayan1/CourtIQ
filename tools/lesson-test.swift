// Checks the lesson store's two promises: no row without consent, and
// withdrawal deletes rather than flags. Also that the vocabulary files
// decode and that every cue points at a deviation that exists.
//
//   swiftc -O tools/lesson-test.swift CourtIQ/Core/Models/BundleContentLoader.swift \
//          CourtIQ/Features/Teaching/LessonCapture.swift -o /tmp/l && /tmp/l

import Foundation

var failures = 0
func expect(_ ok: Bool, _ what: String) {
    print((ok ? "  ok   " : "  FAIL ") + what)
    if !ok { failures += 1 }
}

let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("lesson-test-\(UUID().uuidString)")
try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
let store = LessonStore(directory: tmp)

// The vocabularies, from the real files, via a bundle rooted at Resources/Content.
let content = URL(fileURLWithPath: "CourtIQ/Resources/Content")
guard let bundle = Bundle(path: content.path), let vocab = TeachingVocabulary.load(bundle: bundle) else {
    print("  FAIL vocabulary files did not load"); exit(1)
}
print("vocabulary:")
expect(vocab.deviations.count >= 15, "\(vocab.deviations.count) deviations")
expect(vocab.cues.count >= 15, "\(vocab.cues.count) cues")
let dangling = vocab.cues.flatMap(\.targets).filter { !vocab.deviationIDs.contains($0) }
expect(dangling.isEmpty, "every cue targets a deviation that exists (\(dangling))")
let internalWords = ["elbow", "wrist", "shoulder", "hip", "knee", "arm", "leg"]
let leaks = vocab.cues.filter { c in internalWords.contains { c.text.lowercased().contains($0) } }.map(\.text)
expect(leaks.isEmpty, "no cue names a body part — external focus only \(leaks)")
expect(!vocab.cues(for: "fh.contact.behind").isEmpty, "a deviation has a cue shortlist")

print("\nconsent gates the row:")
let row = LessonRecord(id: "r1", student: "player-07", stroke: "forehand", date: Date(),
                       beforeClip: "r1-before.mov", deviationID: "fh.contact.behind",
                       cueID: "cue.meet.front", afterClip: "r1-after.mov",
                       retentionClip: nil, retentionDate: nil, note: nil)
do { try store.add(row, deviations: vocab.deviationIDs, cues: vocab.cueIDs); expect(false, "added without consent") }
catch LessonStore.StoreError.noConsent { expect(true, "refused: no consent on file") }
catch { expect(false, "wrong error \(error)") }

store.grantConsent(student: "player-07", isMinor: true, grantedBy: "mother")
do { try store.add(row, deviations: vocab.deviationIDs, cues: vocab.cueIDs); expect(true, "added with consent") }
catch { expect(false, "add failed \(error)") }

var bad = row; bad.id = "r2"; bad.deviationID = "fh.made.up"
do { try store.add(bad, deviations: vocab.deviationIDs, cues: vocab.cueIDs); expect(false, "accepted an unknown deviation") }
catch LessonStore.StoreError.unknownDeviation { expect(true, "refused: deviation not in the taxonomy") }
catch { expect(false, "wrong error \(error)") }

print("\nthe triple grows:")
expect(store.triples() == (1, 1, 0), "one row, after clip present, no retention yet \(store.triples())")
store.attachRetention(recordID: "r1", clip: "r1-ret.mov")
expect(store.triples() == (1, 1, 1), "retention attached \(store.triples())")

print("\nwithdrawal deletes:")
for name in ["r1-before.mov", "r1-after.mov", "r1-ret.mov"] {
    try! Data("x".utf8).write(to: tmp.appendingPathComponent(name))
}
store.withdrawConsent(student: "player-07")
expect(store.records().isEmpty, "rows gone")
expect(!FileManager.default.fileExists(atPath: tmp.appendingPathComponent("r1-before.mov").path), "clips gone")
expect(store.consent(for: "player-07")?.isActive == false, "consent recorded as withdrawn, not erased")
do { try store.add(row, deviations: vocab.deviationIDs, cues: vocab.cueIDs); expect(false, "added after withdrawal") }
catch LessonStore.StoreError.consentWithdrawn { expect(true, "refused after withdrawal") }
catch { expect(false, "wrong error \(error)") }

try? FileManager.default.removeItem(at: tmp)
print(failures == 0 ? "\nall passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
