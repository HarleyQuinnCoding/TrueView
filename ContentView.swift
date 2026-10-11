import SwiftUI

struct ContentView: View {
    enum Screen { case capture, analyzing, verdict }
    @State private var screen: Screen = .capture
    @State private var verdict: Verdict?
    @State private var showPicker = false
    @State private var pickedImage: UIImage?
    @State private var isRecording = false
    @State private var recordProgress = 0.0
    @State private var voiceAlert: String?

    private let imageModel = DeepfakeImageClassifier()
    private let audioModel = DeepfakeAudioClassifier()
    private let scanner = VoiceScanner()

    var body: some View {
        ZStack {
            Image("BannerBG")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Color.black.opacity(0.45).ignoresSafeArea()  // dim so text pops
            FirefliesView().allowsHitTesting(false)
            if screen == .capture {
                TitleSparklesView().allowsHitTesting(false)  // live sparkles over the gold title
            }
            switch screen {
            case .capture: captureView
            case .analyzing: analyzingView
            case .verdict: verdictView
            }
            // Lenny patrols only on the capture screen — never behind the verdict card
            if screen == .capture {
                LennyView().allowsHitTesting(false)
            }
            // On a verdict, he flies in with a REACTION instead
            if screen == .verdict, let v = verdict {
                LennyReactionView(isFake: v.isFake).allowsHitTesting(false)
            }
        }
        .alert("Voice scan", isPresented: Binding(
            get: { voiceAlert != nil },
            set: { if !$0 { voiceAlert = nil } }
        )) {
            Button("OK", role: .cancel) { voiceAlert = nil }
        } message: {
            Text(voiceAlert ?? "")
        }
        .sheet(isPresented: $showPicker) {
            PhotoPicker(image: $pickedImage)
                .onDisappear { if let img = pickedImage { analyzePhoto(img) } }
        }
    }

    var captureView: some View {
        VStack(spacing: 28) {
            Spacer()
            Image("TitleArt")
                .resizable()
                .scaledToFit()
                .frame(width: 330)
                .blendMode(.screen)   // the black in the picture turns invisible
            Text("The guardian's lens — see through the forest's illusions.")
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center).padding(.horizontal)
            Spacer()
            Button { showPicker = true } label: {
                Label("Scan a Photo", systemImage: "camera.fill")
                    .font(.title3).bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
            .background(Color(red: 0.05, green: 0.35, blue: 0.22))
            .foregroundColor(.white)
            .cornerRadius(20)
            .padding(.horizontal, 32)
            .shadow(color: Color(red: 0.95, green: 0.80, blue: 0.40).opacity(0.35), radius: 12)

            Button { startVoiceScan() } label: {
                Label(isRecording ? "Listening…" : "Scan a Voice (4s)", systemImage: "waveform")
                    .font(.title3).bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
            .background(Color(red: 0.55, green: 0.30, blue: 0.85))
            .foregroundColor(.white)
            .cornerRadius(20)
            .padding(.horizontal, 32)
            .shadow(color: Color(red: 0.55, green: 0.30, blue: 0.85).opacity(0.5), radius: 12)
            .disabled(isRecording)
            if isRecording {
                ProgressView(value: recordProgress)
                    .tint(.white)
                    .padding(.horizontal, 64)
            }
            Spacer()
        }
    }

    func startVoiceScan() {
        recordProgress = 0
        isRecording = true
        withAnimation(.linear(duration: 4.0)) { recordProgress = 1.0 }
        scanner.recordFourSeconds { samples in
            isRecording = false
            guard let s = samples else {
                voiceAlert = scanner.lastError ?? "TrueView couldn't hear anything."
                return
            }
            guard let (fake, conf) = audioModel?.classify(samples: s) else {
                voiceAlert = "The voice model didn't start. Rebuild the app in Xcode and try again."
                return
            }
            verdict = Verdict(isFake: fake, confidence: conf, modality: "voice")
            screen = .analyzing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { screen = .verdict }
        }
    }

    func analyzePhoto(_ img: UIImage) {
        screen = .analyzing
        DispatchQueue.global(qos: .userInitiated).async {
            let result = imageModel?.classify(img)
            DispatchQueue.main.async {
                if let (fake, conf) = result {
                    verdict = Verdict(isFake: fake, confidence: conf, modality: "photo")
                } else {
                    verdict = Verdict(isFake: false, confidence: 0, modality: "photo")
                }
                screen = .verdict
            }
        }
    }

    var analyzingView: some View {
        VStack(spacing: 20) {
            ProgressView().scaleEffect(2).tint(.white)
            Text("Reading the signs…").foregroundColor(.white)
        }
    }

    var verdictView: some View {
        VStack(spacing: 24) {
            if let v = verdict {
                Text(v.title)
                    .font(.custom("CinzelDecorative-Bold", size: 38))
                    .foregroundColor(v.glow)
                    .shadow(color: v.glow, radius: 24)
                Text(v.subtitle).foregroundColor(.white)
                    .multilineTextAlignment(.center).padding(.horizontal)
                let pct = Int(v.confidence * 100)
                Text(pct < 1 ? "<1% confidence" : "\(pct)% confidence")
                    .font(.title2).bold().foregroundColor(v.primary)
                    .padding().background(v.glow.opacity(0.15)).cornerRadius(16)
            }
            Button("Scan Another") { pickedImage = nil; screen = .capture }
                .buttonStyle(.bordered).tint(.white)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.black.opacity(0.55))
                .shadow(color: verdict?.glow.opacity(0.4) ?? .clear, radius: 30)
        )
        .padding()
    }
}

// MARK: - Live sparkles over the gold title

struct TitleSparkleConfig: Identifiable {
    let id = UUID()
    let fx: CGFloat = .random(in: 0.12...0.88)   // across the title area
    let fy: CGFloat = .random(in: 0.10...0.30)
    let size: CGFloat = .random(in: 2...4.5)
    let dur: Double = .random(in: 0.7...1.6)
    let delay: Double = .random(in: 0...1.5)
}

struct TitleSparkleDot: View {
    let cfg: TitleSparkleConfig
    let area: CGSize
    @State private var twinkle = false

    var body: some View {
        Circle()
            .fill(Color(red: 1.0, green: 0.95, blue: 0.75))
            .frame(width: cfg.size, height: cfg.size)
            .shadow(color: .white, radius: 6)
            .opacity(twinkle ? 1.0 : 0.0)
            .position(x: cfg.fx * area.width, y: cfg.fy * area.height)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + cfg.delay) {
                    withAnimation(.easeInOut(duration: cfg.dur).repeatForever(autoreverses: true)) { twinkle = true }
                }
            }
    }
}

struct TitleSparklesView: View {
    let sparks: [TitleSparkleConfig] = (0..<12).map { _ in TitleSparkleConfig() }
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(sparks) { TitleSparkleDot(cfg: $0, area: geo.size) }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Lenny's verdict reaction (perched on the card — cheer for real, gasp for fake)

struct LennyReactionView: View {
    let isFake: Bool
    @State private var settled = false
    @State private var bob = false

    var body: some View {
        Image(isFake ? "LennyBlight" : "LennyBloom")
            .resizable()
            .scaledToFit()
            .frame(width: 150)
            .blendMode(.screen)            // the black in his picture turns invisible
            .offset(y: (settled ? -215 : -460) + (bob ? -5 : 5))
            .opacity(settled ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { settled = true }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { bob = true }
            }
    }
}

// MARK: - Ambient fireflies (glowing orbs that breathe in and out of view)

struct FireflyConfig: Identifiable {
    let id = UUID()
    let fx: CGFloat = .random(in: 0.03...0.97)   // start position, fraction of screen
    let fy: CGFloat = .random(in: 0.03...0.97)
    let size: CGFloat = .random(in: 3...6.5)
    let gold: Bool = Bool.random()
    let dx: CGFloat = .random(in: -34...34)      // drift distance
    let dy: CGFloat = .random(in: -46...46)
    let dur: Double = .random(in: 2.4...5.2)     // drift speed
}

struct FireflyDot: View {
    let cfg: FireflyConfig
    let area: CGSize
    @State private var drift = false
    @State private var twinkle = false

    var color: Color {
        cfg.gold ? Color(red: 0.98, green: 0.83, blue: 0.42)
                 : Color(red: 0.42, green: 0.96, blue: 0.86)
    }

    var body: some View {
        ZStack {
            Circle()   // soft halo
                .fill(color)
                .frame(width: cfg.size * 3.4, height: cfg.size * 3.4)
                .blur(radius: 4)
                .opacity(twinkle ? 0.4 : 0.05)
            Circle()   // bright core
                .fill(color)
                .frame(width: cfg.size, height: cfg.size)
                .shadow(color: color, radius: 9)
        }
        .opacity(twinkle ? 1.0 : 0.15)
        .position(x: cfg.fx * area.width + (drift ? cfg.dx : -cfg.dx),
                  y: cfg.fy * area.height + (drift ? cfg.dy : -cfg.dy))
        .onAppear {
            withAnimation(.easeInOut(duration: cfg.dur).repeatForever(autoreverses: true)) { drift = true }
            withAnimation(.easeInOut(duration: cfg.dur * 0.9).repeatForever(autoreverses: true)) { twinkle = true }
        }
    }
}

struct FirefliesView: View {
    let flies: [FireflyConfig] = (0..<24).map { _ in FireflyConfig() }
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(flies) { FireflyDot(cfg: $0, area: geo.size) }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Lenny, the guardian on patrol — flapping his wings under the title

struct LennyView: View {
    @State private var x: CGFloat = -300
    @State private var y: CGFloat = 40
    @State private var tilt: Double = 0
    @State private var facingRight = true
    @State private var opacity: Double = 0
    @State private var bob = false
    @State private var flapUp = false
    @State private var gliding = false

    var body: some View {
        ZStack {
            Image(flapUp && !gliding ? "LennyFlyUp" : "LennyFlyPro")
                .resizable()
                .scaledToFit()
                .frame(width: 210)
                .blendMode(.screen)            // the black in his picture turns invisible
                .rotationEffect(.degrees(tilt))
                .scaleEffect(x: facingRight ? 0.85 : -0.85, y: 0.85)  // faces his direction
                .offset(x: x, y: y + (bob ? -6 : 6))
                .opacity(opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .task { await patrol() }
        .task { await flapLoop() }
    }

    // The wingbeat: alternates the glide frame and the wings-up frame
    // ~3x per second while cruising; holds the glide frame while hovering.
    func flapLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !gliding { flapUp.toggle() }
        }
    }

    func patrol() async {
        // gentle bobbing, always on — this is what makes him feel alive
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { bob = true }
        // flies in from the left, flapping
        opacity = 1
        withAnimation(.easeOut(duration: 2.2)) { x = -90 }
        try? await Task.sleep(nanoseconds: 2_400_000_000)
        while !Task.isCancelled {
            // cruise right, banking into the turn
            gliding = false
            withAnimation(.easeInOut(duration: 5.0)) { x = 90 }
            withAnimation(.easeInOut(duration: 0.8)) { tilt = -7 }
            try? await Task.sleep(nanoseconds: 5_100_000_000)
            // hover — look around
            gliding = true; flapUp = false
            withAnimation(.easeInOut(duration: 0.8)) { tilt = 0 }
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            // turn and cruise left
            withAnimation(.easeInOut(duration: 0.5)) { facingRight = false }
            gliding = false
            withAnimation(.easeInOut(duration: 5.0)) { x = -90 }
            withAnimation(.easeInOut(duration: 0.8)) { tilt = 7 }
            try? await Task.sleep(nanoseconds: 5_100_000_000)
            withAnimation(.easeInOut(duration: 0.8)) { tilt = 0 }
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            withAnimation(.easeInOut(duration: 0.5)) { facingRight = true }
        }
    }
}
