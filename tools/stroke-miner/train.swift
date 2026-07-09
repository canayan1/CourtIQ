// train.swift — DropVolley vuruş sınıflandırıcısı v0 (Create ML Action Classifier).
// Girdi: sınıf-adlı klasörlerde 2.2 sn'lik klipler (mine.py çıktısı).
// Kullanım: xcrun swiftc -O train.swift -o stroketrain && ./stroketrain <dataDir> <out.mlmodel>
// Pencere 60 kare @30fps = 2 sn — mine.py'nin kesim penceresiyle (66 kare) uyumlu.

import CreateML
import Foundation

guard CommandLine.arguments.count == 3 else {
    print("kullanım: stroketrain <dataDir> <out.mlmodel>")
    exit(1)
}
let dataDir = URL(fileURLWithPath: (CommandLine.arguments[1] as NSString).expandingTildeInPath)
let outURL  = URL(fileURLWithPath: (CommandLine.arguments[2] as NSString).expandingTildeInPath)

var params = MLActionClassifier.ModelParameters()
params.predictionWindowSize = 60
params.targetFrameRate = 30
params.maximumIterations = 80
params.validation = .split(strategy: .automatic)

print("eğitim başlıyor: \(dataDir.path)")
let start = Date()
let model = try MLActionClassifier(
    trainingData: .labeledDirectories(at: dataDir),
    parameters: params
)
print(String(format: "süre: %.0f sn", Date().timeIntervalSince(start)))

let t = model.trainingMetrics
let v = model.validationMetrics
print(String(format: "eğitim doğruluğu:    %.1f%%", (1 - t.classificationError) * 100))
print(String(format: "doğrulama doğruluğu: %.1f%%", (1 - v.classificationError) * 100))
print("— doğrulama karışıklık matrisi —")
print(v.confusion)

try model.write(to: outURL, metadata: MLModelMetadata(
    author: "DropVolley",
    shortDescription: "Tennis stroke classifier v0 (rear-angle wall practice; single-subject prototype)",
    version: "0.1"
))
print("model yazıldı: \(outURL.path)")
