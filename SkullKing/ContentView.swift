import SwiftUI
import Charts
import Observation
import Photos

// MARK: - Models

struct Player: Identifiable, Codable, Hashable {
	var id: UUID = UUID()
	var name: String
	var total: Int = 0
	var isNameCustomized: Bool = false

	static func defaultName(index: Int) -> String {
		tr("플레이어 \(index + 1)", "Player \(index + 1)")
	}
}

extension Player {
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(UUID.self, forKey: .id)
		name = try container.decode(String.self, forKey: .name)
		total = try container.decodeIfPresent(Int.self, forKey: .total) ?? 0
		// 플래그가 없는 이전 저장본만 기본 이름 형태인지로 한 번 추정한다.
		isNameCustomized = try container.decodeIfPresent(Bool.self, forKey: .isNameCustomized)
			?? (name.range(of: "^플레이어 [0-9]+$", options: .regularExpression) == nil)
	}
}

struct RoundEntry: Identifiable, Codable, Hashable {
	var id: UUID = UUID()
	var playerID: UUID
	var bid: Int = 0
	var tricks: Int = 0
	var standard14: Int = 0       // yellow / green / purple 14s: +10 each
	var black14: Int = 0          // black Jolly Roger 14: +20 each
	var mermaidsByPirate: Int = 0 // +20 each
	var piratesBySkullKing: Int = 0 // +30 each
	var skullKingByMermaid: Int = 0 // +40 in this edition/ruleset
	var bet: Int = 0              // 라스칼 배팅 0 / 10 / 20: 입찰 성공 시 +, 실패 시 -
	var expansionSeven: Int = 0   // 확장팩 숫자 7 (-5): 트릭을 이기면 -5 each
	var expansionEight: Int = 0   // 확장팩 숫자 8 (+5): 트릭을 이기면 +5 each
	var firstMateCaptured: Int = 0 // 일등항해사 콘을 스컬킹·인어가 잡음: +30 each
	var davyJonesMonsters: Int = 0 // 데이비 존스의 사물함이 파괴한 바다괴물: +20 each, 입찰과 무관

	// 확장팩 7은 음수라 보너스 합계가 0보다 작아질 수 있다.
	var bonusPoints: Int {
		standard14 * 10 + black14 * 20 + mermaidsByPirate * 20
		+ piratesBySkullKing * 30 + skullKingByMermaid * 40
		+ expansionEight * ScoreRules.expansionCardPoints - expansionSeven * ScoreRules.expansionCardPoints
		+ firstMateCaptured * ScoreRules.firstMateCapturedPoints
		+ davyJonesPoints
	}

	var davyJonesPoints: Int { davyJonesMonsters * ScoreRules.davyJonesMonsterPoints }
}

// 이전 버전 저장 데이터에 없는 필드는 기본값으로 복원한다.
extension RoundEntry {
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(UUID.self, forKey: .id)
		playerID = try container.decode(UUID.self, forKey: .playerID)
		bid = try container.decode(Int.self, forKey: .bid)
		tricks = try container.decode(Int.self, forKey: .tricks)
		standard14 = try container.decode(Int.self, forKey: .standard14)
		black14 = try container.decode(Int.self, forKey: .black14)
		mermaidsByPirate = try container.decode(Int.self, forKey: .mermaidsByPirate)
		piratesBySkullKing = try container.decode(Int.self, forKey: .piratesBySkullKing)
		skullKingByMermaid = try container.decode(Int.self, forKey: .skullKingByMermaid)
		bet = try container.decodeIfPresent(Int.self, forKey: .bet) ?? 0
		expansionSeven = try container.decodeIfPresent(Int.self, forKey: .expansionSeven) ?? 0
		expansionEight = try container.decodeIfPresent(Int.self, forKey: .expansionEight) ?? 0
		firstMateCaptured = try container.decodeIfPresent(Int.self, forKey: .firstMateCaptured) ?? 0
		davyJonesMonsters = try container.decodeIfPresent(Int.self, forKey: .davyJonesMonsters) ?? 0
	}
}

struct Alliance: Identifiable, Codable, Hashable {
	var id: UUID = UUID()
	var firstID: UUID
	var secondID: UUID

	var isValid: Bool { firstID != secondID }

	func contains(_ playerID: UUID) -> Bool {
		firstID == playerID || secondID == playerID
	}
}

struct RoundRecord: Identifiable, Codable, Hashable {
	var id: UUID = UUID()
	var round: Int
	var entries: [RoundEntry]
	var alliances: [Alliance] = []
}

struct RoundResult: Identifiable, Codable, Hashable {
	var id: UUID = UUID()
	var round: Int
	var playerID: UUID
	var playerName: String
	var bid: Int
	var tricks: Int
	var bidPoints: Int
	var bonusPoints: Int
	var betPoints: Int = 0
	var alliancePoints: Int = 0
	var roundPoints: Int
	var runningTotal: Int
}

extension RoundResult {
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(UUID.self, forKey: .id)
		round = try container.decode(Int.self, forKey: .round)
		playerID = try container.decode(UUID.self, forKey: .playerID)
		playerName = try container.decode(String.self, forKey: .playerName)
		bid = try container.decode(Int.self, forKey: .bid)
		tricks = try container.decode(Int.self, forKey: .tricks)
		bidPoints = try container.decode(Int.self, forKey: .bidPoints)
		bonusPoints = try container.decode(Int.self, forKey: .bonusPoints)
		betPoints = try container.decodeIfPresent(Int.self, forKey: .betPoints) ?? 0
		alliancePoints = try container.decodeIfPresent(Int.self, forKey: .alliancePoints) ?? 0
		roundPoints = try container.decode(Int.self, forKey: .roundPoints)
		runningTotal = try container.decode(Int.self, forKey: .runningTotal)
	}
}

struct SavedGame: Identifiable, Codable, Equatable {
	var id: UUID = UUID()
	var title: String
	var finishedAt: Date
	var playerNames: [String]
	var results: [RoundResult]
	var finalScores: [String: Int]
	var roundsPlayed: Int = 0
	var players: [Player] = []
	var rounds: [RoundRecord] = []
}

extension SavedGame {
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(UUID.self, forKey: .id)
		title = try container.decode(String.self, forKey: .title)
		finishedAt = try container.decode(Date.self, forKey: .finishedAt)
		playerNames = try container.decode([String].self, forKey: .playerNames)
		results = try container.decode([RoundResult].self, forKey: .results)
		finalScores = try container.decode([String: Int].self, forKey: .finalScores)
		roundsPlayed = try container.decodeIfPresent(Int.self, forKey: .roundsPlayed)
			?? (results.map(\.round).max() ?? 0)
		players = try container.decodeIfPresent([Player].self, forKey: .players) ?? []
		rounds = try container.decodeIfPresent([RoundRecord].self, forKey: .rounds) ?? []
	}
}

struct AppSave: Codable, Equatable {
	var players: [Player]
	var rounds: [RoundRecord]
	var completedRounds: Int
	var viewingRound: Int
	var savedGames: [SavedGame]
	var gameStarted: Bool
	var gameFinished: Bool
	var gameTitle: String
	var currentGameID: UUID
	var isTitleCustomized: Bool = false
}

extension AppSave {
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		players = try container.decode([Player].self, forKey: .players)
		rounds = try container.decode([RoundRecord].self, forKey: .rounds)
		completedRounds = try container.decode(Int.self, forKey: .completedRounds)
		viewingRound = try container.decode(Int.self, forKey: .viewingRound)
		savedGames = try container.decode([SavedGame].self, forKey: .savedGames)
		gameStarted = try container.decode(Bool.self, forKey: .gameStarted)
		gameFinished = try container.decode(Bool.self, forKey: .gameFinished)
		gameTitle = try container.decode(String.self, forKey: .gameTitle)
		currentGameID = try container.decode(UUID.self, forKey: .currentGameID)
		isTitleCustomized = try container.decodeIfPresent(Bool.self, forKey: .isTitleCustomized) ?? false
	}
}

// v2 저장본에서 보관함만 가져오기 위한 최소 디코더.
struct LegacySave: Decodable {
	var savedGames: [SavedGame]
}

struct RoundScore {
	let bid: Int
	let bonus: Int
	let bet: Int
	let alliance: Int

	var total: Int { bid + bonus + bet + alliance }
}

enum ScoreRules {
	static let maxRounds = 10
	static let minPlayers = 2
	static let maxPlayers = 8
	static let betOptions = [0, 10, 20]
	static let allianceBonus = 20
	static let expansionCardPoints = 5
	static let firstMateCapturedPoints = 30
	static let davyJonesMonsterPoints = 20
	static let seaMonsterCount = 3

	static var defaultTitle: String {
		tr("해적들의 대결", "Pirates' Duel")
	}

	static func bidPoints(bid: Int, tricks: Int, round: Int) -> Int {
		if bid == 0 {
			return tricks == 0 ? round * 10 : -round * 10
		}
		return bid == tricks ? bid * 20 : -abs(bid - tricks) * 10
	}

	static func score(entry: RoundEntry, round: Int, alliance: Int = 0) -> RoundScore {
		let bid = bidPoints(bid: entry.bid, tricks: entry.tricks, round: round)
		let success = entry.bid == entry.tricks
		// 보너스 카드는 입찰에 성공했을 때만 더한다. 데이비 존스의 사물함 보너스만 입찰과 무관하다. 배팅은 성공 시 +, 실패 시 -.
		return RoundScore(
			bid: bid,
			bonus: success ? entry.bonusPoints : entry.davyJonesPoints,
			bet: success ? entry.bet : -entry.bet,
			alliance: alliance
		)
	}

	// 전리품(동맹) 카드: 동맹을 맺은 두 플레이어가 모두 입찰에 성공해야 각자 보너스를 받는다.
	static func alliancePoints(for playerID: UUID, alliances: [Alliance], entries: [RoundEntry]) -> Int {
		func succeeded(_ id: UUID) -> Bool {
			entries.first { $0.playerID == id }.map { $0.bid == $0.tricks } ?? false
		}
		return alliances
			.filter { $0.isValid && $0.contains(playerID) }
			.filter { succeeded($0.firstID) && succeeded($0.secondID) }
			.count * allianceBonus
	}
}

enum Palette {
	static let accent = Color(red: 0.98, green: 0.72, blue: 0.30)
	static let background: [Color] = [
		Color(red: 0.035, green: 0.075, blue: 0.13),
		Color(red: 0.08, green: 0.13, blue: 0.20),
		Color(red: 0.025, green: 0.045, blue: 0.08)
	]
	static let panel = Color(red: 0.075, green: 0.12, blue: 0.18)
	static let card = Color(red: 0.055, green: 0.09, blue: 0.14)
	static let heroTop = Color(red: 0.15, green: 0.23, blue: 0.31)
	static let heroBottom = Color(red: 0.07, green: 0.12, blue: 0.19)
	static let buttonText = Color(red: 0.10, green: 0.09, blue: 0.07)
	static let buttonHighlight = Color(red: 1, green: 0.82, blue: 0.46)
}

// MARK: - Language

enum AppLanguage: String, CaseIterable, Identifiable {
	case ko, en

	var id: String { rawValue }

	var displayName: String {
		self == .ko ? "한국어" : "English"
	}

	var locale: Locale {
		Locale(identifier: self == .ko ? "ko_KR" : "en_US")
	}
}

@Observable
final class LanguageStore {
	static let shared = LanguageStore()
	private static let key = "SkullKingScoreApp.Language"

	var language: AppLanguage {
		didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.key) }
	}

	private init() {
		if let raw = UserDefaults.standard.string(forKey: Self.key), let saved = AppLanguage(rawValue: raw) {
			language = saved
		} else {
			language = Locale.preferredLanguages.first?.hasPrefix("ko") == true ? .ko : .en
		}
	}
}

// body 안에서 호출하면 Observation이 언어 변경을 추적해 다시 그린다.
func tr(_ ko: String, _ en: String) -> String {
	LanguageStore.shared.language == .ko ? ko : en
}

// MARK: - App

@main
struct SkullKingScoreApp: App {
	var body: some Scene {
		WindowGroup {
			ContentView()
				.preferredColorScheme(.dark)
		}
	}
}

struct ContentView: View {
	@State private var players: [Player] = (0..<4).map { Player(name: Player.defaultName(index: $0)) }
	@State private var rounds: [RoundRecord] = []
	@State private var completedRounds = 0
	@State private var viewingRound = 1
	@State private var savedGames: [SavedGame] = []
	@State private var gameStarted = false
	@State private var gameFinished = false
	@State private var currentGameID = UUID()
	@State private var gameTitle = ScoreRules.defaultTitle
	@State private var isTitleCustomized = false
	@State private var titleDraft = ""
	@FocusState private var titleFocused: Bool
	@State private var showHistory = false
	@State private var showPlayerSetup = false
	@State private var showScoreTable = false
	@State private var showRules = false
	@State private var showResetConfirm = false
	@State private var showEndGameConfirm = false
	@State private var showFinalResult = false
	@State private var showRenameAlert = false
	@State private var loaded = false
	@State private var scrollToken = 0

	private let maxRounds = ScoreRules.maxRounds
	private let saveKey = "SkullKingScoreApp.Save.v3"
	private let legacySaveKey = "SkullKingScoreApp.Save.v2"
	private let topID = "top"

	// MARK: Derived state

	private var isPlaying: Bool { gameStarted && !gameFinished }
	private var hasInProgressGame: Bool { !rounds.isEmpty && !gameFinished }
	private var roundsPlayed: Int { min(completedRounds, maxRounds) }
	private var hasDraftRound: Bool { rounds.count > completedRounds }
	private var isViewingDraft: Bool { hasDraftRound && viewingRound == rounds.count }

	private var viewingIndex: Int? {
		rounds.indices.contains(viewingRound - 1) ? viewingRound - 1 : nil
	}

	// 완료된 라운드 입력에서 매번 다시 계산하므로 과거 라운드를 고치면 이후 누적도 함께 바뀐다.
	private var results: [RoundResult] {
		var running: [UUID: Int] = [:]
		var output: [RoundResult] = []
		for record in rounds.prefix(completedRounds) {
			for player in players {
				guard let entry = record.entries.first(where: { $0.playerID == player.id }) else { continue }
				let alliance = ScoreRules.alliancePoints(for: player.id, alliances: record.alliances, entries: record.entries)
				let score = ScoreRules.score(entry: entry, round: record.round, alliance: alliance)
				let total = running[player.id, default: 0] + score.total
				running[player.id] = total
				output.append(RoundResult(
					round: record.round, playerID: player.id, playerName: player.name,
					bid: entry.bid, tricks: entry.tricks, bidPoints: score.bid,
					bonusPoints: score.bonus, betPoints: score.bet, alliancePoints: score.alliance,
					roundPoints: score.total, runningTotal: total
				))
			}
		}
		return output
	}

	private var ranking: [(player: Player, score: Int)] {
		players.map { player in
			let score = results.filter { $0.playerID == player.id }.reduce(0) { $0 + $1.roundPoints }
			return (player, score)
		}.sorted { $0.score == $1.score ? $0.player.name < $1.player.name : $0.score > $1.score }
	}

	private func totalBefore(round: Int, playerID: UUID) -> Int {
		results.filter { $0.playerID == playerID && $0.round < round }.reduce(0) { $0 + $1.roundPoints }
	}

	private var currentSave: AppSave {
		AppSave(
			players: players, rounds: rounds, completedRounds: completedRounds, viewingRound: viewingRound,
			savedGames: savedGames, gameStarted: gameStarted, gameFinished: gameFinished,
			gameTitle: gameTitle, currentGameID: currentGameID, isTitleCustomized: isTitleCustomized
		)
	}

	// MARK: Body

	var body: some View {
		NavigationStack {
			presentedContent
		}
		.tint(Palette.accent)
		.environment(\.locale, LanguageStore.shared.language.locale)
	}

	private var languageBinding: Binding<AppLanguage> {
		Binding(
			get: { LanguageStore.shared.language },
			set: { LanguageStore.shared.language = $0 }
		)
	}

	private var screenContent: some View {
		ZStack {
			LinearGradient(colors: Palette.background, startPoint: .topLeading, endPoint: .bottomTrailing)
				.ignoresSafeArea()
			if gameStarted {
				gameScreen
			} else {
				setupScreen
			}
		}
	}

	private var navigationContent: some View {
		screenContent
			.navigationTitle("SKULL KING")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar { toolbarContent }
	}

	@ToolbarContentBuilder
	private var toolbarContent: some ToolbarContent {
		if gameStarted {
			ToolbarItem(placement: .topBarLeading) {
				Button { showHistory = true } label: {
					Image(systemName: "clock.arrow.circlepath")
				}
				.accessibilityLabel(tr("게임 기록", "Game History"))
			}
			ToolbarItem(placement: .topBarTrailing) {
				Menu {
					Button { showPlayerSetup = true } label: {
						Label(tr("플레이어 설정", "Players"), systemImage: "person.2.badge.gearshape")
					}
					Button {
						titleDraft = isTitleCustomized ? gameTitle : ""
						showRenameAlert = true
					} label: {
						Label(tr("게임 이름 변경", "Rename Game"), systemImage: "pencil")
					}
					Button { showScoreTable = true } label: {
						Label(tr("점수표", "Score Table"), systemImage: "tablecells")
					}
					Button { showRules = true } label: {
						Label(tr("점수 규칙", "Scoring Rules"), systemImage: "list.bullet.rectangle")
					}
					languagePicker
					Divider()
					Button { showEndGameConfirm = true } label: {
						Label(tr("게임 종료 (결과 보기)", "End Game (Results)"), systemImage: "flag.checkered")
					}
					.disabled(completedRounds == 0 || gameFinished)
					Button(role: .destructive) { showResetConfirm = true } label: {
						Label(tr("새 게임 / 초기화", "New Game / Reset"), systemImage: "arrow.counterclockwise")
					}
				} label: {
					Image(systemName: "ellipsis.circle")
				}
			}
		} else {
			ToolbarItem(placement: .topBarLeading) {
				EditButton()
			}
			ToolbarItem(placement: .topBarTrailing) {
				Menu {
					languagePicker
				} label: {
					Image(systemName: "globe")
				}
			}
		}
	}

	private var languagePicker: some View {
		Picker(selection: languageBinding) {
			ForEach(AppLanguage.allCases) { language in
				Text(language.displayName).tag(language)
			}
		} label: {
			Label(tr("언어", "Language"), systemImage: "globe")
		}
		.pickerStyle(.menu)
	}

	private var alertContent: some View {
		navigationContent
			.sheet(isPresented: $showHistory) {
				HistoryView(games: savedGames, onLoad: loadSavedGame, onDelete: deleteSavedGame)
			}
			.sheet(isPresented: $showPlayerSetup, onDismiss: normalizePlayerNames) {
				PlayerSetupView(players: $players, onAdd: addPlayer, onRemove: removePlayer)
			}
			.sheet(isPresented: $showScoreTable) {
				ScoreTableSheet(results: results)
			}
			.sheet(isPresented: $showRules) {
				RulesSheet()
			}
			.fullScreenCover(isPresented: $showFinalResult) {
				FinalResultView(
					title: gameTitle,
					playerNames: players.map(\.name),
					results: results,
					roundsPlayed: roundsPlayed,
					onNewGame: {
						startNewGame()
						showFinalResult = false
					}
				)
			}
			.alert(tr("게임 이름", "Game Name"), isPresented: $showRenameAlert) {
				TextField(gameTitle, text: $titleDraft)
				Button(tr("취소", "Cancel"), role: .cancel) {}
				Button(tr("저장", "Save")) { applyTitle(titleDraft) }
			}
	}

	private var dialogContent: some View {
		alertContent
			.confirmationDialog(tr("현재 게임을 초기화할까요?", "Reset the current game?"), isPresented: $showResetConfirm, titleVisibility: .visible) {
				Button(tr("현재 게임 저장 후 새 게임", "Save & Start New Game")) {
					archiveCurrentGame()
					startNewGame()
				}
				Button(tr("저장하지 않고 새 게임", "New Game Without Saving"), role: .destructive) { startNewGame() }
				Button(tr("취소", "Cancel"), role: .cancel) {}
			} message: {
				Text(tr("현재 점수는 기록에 보관하거나 삭제할 수 있어요.", "You can keep the current scores in history or discard them."))
			}
			.confirmationDialog(tr("지금 게임을 끝낼까요?", "End the game now?"), isPresented: $showEndGameConfirm, titleVisibility: .visible) {
				Button(tr("게임 종료하고 결과 보기", "End Game & Show Results")) { finishGame() }
				Button(tr("취소", "Cancel"), role: .cancel) {}
			} message: {
				Text(tr("\(roundsPlayed)라운드까지의 점수로 최종 결과를 계산하고 기록에 저장합니다.", "Final results will be calculated from \(roundsPlayed) round(s) and saved to history."))
			}
	}

	private var presentedContent: some View {
		dialogContent
			.onAppear {
				guard !loaded else { return }
				loaded = true
				restore()
			}
			.onChange(of: currentSave) { _, save in persist(save) }
			.onChange(of: players) { _, _ in ensureDraftEntries() }
	}

	// MARK: Setup screen

	private var setupScreen: some View {
		List {
			Section {
				VStack(alignment: .leading, spacing: 6) {
					Text("SKULL KING")
						.font(.system(size: 30, weight: .black, design: .rounded))
						.foregroundStyle(.orange)
					Text(tr("게임 설정 · 플레이어를 등록하고 게임을 시작하세요", "Game setup · register players and start the game"))
						.font(.callout)
						.foregroundStyle(.white.opacity(0.7))
				}
				.listRowBackground(Color.clear)
				.listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
			}
			Section {
				TextField(tr("게임 이름", "Game Name"), text: $gameTitle)
					.focused($titleFocused)
					.submitLabel(.done)
					.onChange(of: titleFocused) { _, focused in
						handleTitleFocus(focused)
					}
			} header: {
				Text(tr("게임 이름", "Game Name"))
			}
			.listRowBackground(Palette.card)
			PlayerEditorSection(players: $players, onAdd: addPlayer, onRemove: removePlayer)
			if hasInProgressGame {
				Section {
					VStack(alignment: .leading, spacing: 4) {
						Text(gameTitle).font(.headline)
						Text(tr("라운드 \(rounds.count) 진행 중 · \(completedRounds)라운드 저장됨", "Round \(rounds.count) in progress · \(completedRounds) rounds saved"))
							.font(.footnote)
							.foregroundStyle(.white.opacity(0.6))
					}
					Button {
						resumeGame()
					} label: {
						Label(tr("진행 중인 게임 이어하기", "Resume Game in Progress"), systemImage: "play.circle.fill")
							.font(.headline)
					}
				} header: {
					Text(tr("진행 중인 게임", "Game in Progress"))
				} footer: {
					Text(tr("게임 시작을 누르면 이 게임은 기록에 저장되고 새 게임이 시작돼요.", "Start Game saves this game to history and begins a new one."))
				}
				.listRowBackground(Palette.card)
			}
			Section {
				Button {
					startGame()
				} label: {
					Label(tr("게임 시작", "Start Game"), systemImage: "play.fill")
						.font(.headline)
						.frame(maxWidth: .infinity)
						.padding(.vertical, 6)
				}
				.foregroundStyle(.black)
				.disabled(players.count < ScoreRules.minPlayers)
			}
			.listRowBackground(Color.orange)
			Section {
				Button { showHistory = true } label: {
					Label(tr("게임 기록 보관함", "Game History") + " · \(savedGames.count)", systemImage: "books.vertical.fill")
				}
				Button { showRules = true } label: {
					Label(tr("점수 규칙", "Scoring Rules"), systemImage: "list.bullet.rectangle")
				}
			}
			.listRowBackground(Palette.card)
		}
		.scrollContentBackground(.hidden)
	}

	// MARK: Game screen

	private var gameScreen: some View {
		ScrollView {
			ScrollViewReader { proxy in
				VStack(spacing: 18) {
					roundHeader
						.id(topID)
					if gameFinished {
						finishedCard
						if !results.isEmpty {
							scoreTableCard
						}
					} else {
						if !isViewingDraft {
							editingBanner
						}
						inputCard
						if isViewingDraft {
							saveRoundButton
							endGameButton
						}
					}
				}
				.padding(.horizontal, 16)
				.padding(.top, 12)
				.padding(.bottom, 32)
				.onChange(of: scrollToken) { _, _ in
					scrollToTop(proxy)
				}
			}
		}
	}

	private var roundSubtitle: String {
		if gameFinished { return tr("게임 종료 · \(roundsPlayed)라운드 진행", "Game over · \(roundsPlayed) rounds played") }
		if isViewingDraft { return tr("진행 중 · 카드 \(viewingRound)장씩", "In progress · \(viewingRound) cards each") }
		return tr("저장된 라운드 수정 중", "Editing a saved round")
	}

	private var roundHeader: some View {
		VStack(spacing: 12) {
			HStack {
				Button { viewingRound -= 1 } label: {
					Image(systemName: "chevron.left.circle.fill").font(.title2)
				}
				.disabled(viewingRound <= 1)
				.opacity(gameFinished ? 0 : 1)
				Spacer()
				VStack(spacing: 3) {
					Text(gameTitle)
						.font(.footnote.weight(.semibold))
						.foregroundStyle(.white.opacity(0.6))
						.lineLimit(1)
					Text("ROUND \(min(viewingRound, maxRounds))")
						.font(.system(size: 26, weight: .black, design: .rounded))
						.foregroundStyle(.orange)
					Text(roundSubtitle)
						.font(.footnote)
						.foregroundStyle(.white.opacity(0.7))
				}
				Spacer()
				Button { viewingRound += 1 } label: {
					Image(systemName: "chevron.right.circle.fill").font(.title2)
				}
				.disabled(viewingRound >= rounds.count)
				.opacity(gameFinished ? 0 : 1)
			}
			ProgressView(value: Double(roundsPlayed), total: Double(maxRounds))
				.tint(.orange)
				.background(.white.opacity(0.12))
			HStack {
				Label(tr("\(players.count)명", "\(players.count) players"), systemImage: "person.2.fill")
				Spacer()
				Label(tr("\(roundsPlayed)/\(maxRounds) 라운드 저장됨", "\(roundsPlayed)/\(maxRounds) rounds saved"), systemImage: "checkmark.seal.fill")
			}
			.font(.caption.weight(.semibold))
			.foregroundStyle(.white.opacity(0.7))
		}
		.padding(16)
		.piratePanel()
	}

	private var editingBanner: some View {
		HStack(spacing: 10) {
			Image(systemName: "pencil.circle.fill").foregroundStyle(.orange)
			Text(tr("라운드 \(viewingRound) 수정 중 · 변경은 바로 반영돼요", "Editing round \(viewingRound) · changes apply immediately"))
				.font(.footnote.weight(.semibold))
			Spacer()
			if hasDraftRound {
				Button(tr("현재 라운드로", "Current round")) { viewingRound = rounds.count }
					.font(.footnote.weight(.bold))
					.foregroundStyle(.orange)
			}
		}
		.padding(12)
		.background(.orange.opacity(0.12))
		.clipShape(RoundedRectangle(cornerRadius: 14))
	}

	private var inputCard: some View {
		VStack(alignment: .leading, spacing: 14) {
			sectionTitle("ROUND \(viewingRound) LOG", subtitle: tr("입찰 · 실제 트릭 · 보너스 카드 · 라스칼 배팅 · 동맹", "Bid · tricks · bonus cards · Rascal's bet · alliance"))
			if let index = viewingIndex {
				ForEach(players) { player in
					if let entryIndex = rounds[index].entries.firstIndex(where: { $0.playerID == player.id }) {
						PlayerEntryCard(
							player: player,
							entry: $rounds[index].entries[entryIndex],
							round: rounds[index].round,
							cumulative: totalBefore(round: rounds[index].round, playerID: player.id),
							alliancePoints: ScoreRules.alliancePoints(for: player.id, alliances: rounds[index].alliances, entries: rounds[index].entries),
							inAlliance: rounds[index].alliances.contains { $0.isValid && $0.contains(player.id) }
						)
					} else {
						notPlayingRow(player)
					}
				}
				allianceSection(index: index)
			}
		}
		.padding(16)
		.piratePanel()
	}

	private func notPlayingRow(_ player: Player) -> some View {
		HStack {
			Image(systemName: "person.fill.xmark").foregroundStyle(.white.opacity(0.4))
			Text(player.name).font(.headline).foregroundStyle(.white.opacity(0.5))
			Spacer()
			Text(tr("이 라운드에 참여하지 않았어요", "Did not play this round"))
				.font(.caption)
				.foregroundStyle(.white.opacity(0.4))
		}
		.padding(13)
		.background(Palette.card.opacity(0.6))
		.clipShape(RoundedRectangle(cornerRadius: 15))
	}

	private func allianceSection(index: Int) -> some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack {
				Image(systemName: "link").foregroundStyle(.orange)
				Text(tr("동맹 (전리품 카드)", "Alliance (Loot card)")).font(.callout.weight(.semibold))
				Spacer()
				Button {
					addAlliance(index: index)
				} label: {
					Label(tr("동맹 추가", "Add Alliance"), systemImage: "plus.circle.fill")
						.font(.footnote.weight(.semibold))
				}
				.disabled(players.count < 2)
			}
			ForEach($rounds[index].alliances) { $alliance in
				AllianceRow(alliance: $alliance, players: players, entries: rounds[index].entries) {
					rounds[index].alliances.removeAll { $0.id == alliance.id }
				}
			}
			Text(tr("전리품 카드를 낸 플레이어와 그 트릭을 가져간 플레이어가 동맹이 돼요. 둘 다 입찰에 성공하면 각자 +\(ScoreRules.allianceBonus)점.", "The player who plays Loot allies with the trick winner. If both make their bids, each gets +\(ScoreRules.allianceBonus)."))
				.font(.caption).foregroundStyle(.white.opacity(0.48))
		}
		.padding(13)
		.background(Palette.card)
		.clipShape(RoundedRectangle(cornerRadius: 15))
		.overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.07), lineWidth: 1))
	}

	private var saveRoundButton: some View {
		Button {
			saveRound()
		} label: {
			HStack(spacing: 10) {
				Image(systemName: "checkmark.seal.fill")
				Text(viewingRound == maxRounds ? tr("10라운드 저장 및 게임 종료", "Save Round 10 & Finish") : tr("라운드 저장하고 다음으로", "Save Round & Continue"))
				Spacer()
				Image(systemName: "arrow.right")
			}
			.font(.headline)
			.foregroundStyle(Palette.buttonText)
			.padding(.horizontal, 18)
			.padding(.vertical, 17)
			.background(LinearGradient(colors: [.orange, Palette.buttonHighlight], startPoint: .leading, endPoint: .trailing))
			.clipShape(RoundedRectangle(cornerRadius: 16))
		}
		.buttonStyle(.plain)
	}

	private var endGameButton: some View {
		Button {
			showEndGameConfirm = true
		} label: {
			HStack(spacing: 10) {
				Image(systemName: "flag.checkered")
				Text(tr("여기서 게임 끝내기", "End Game Here"))
				Spacer()
				Text(tr("\(roundsPlayed)라운드 기준", "after \(roundsPlayed) rounds"))
					.font(.footnote)
					.foregroundStyle(.white.opacity(0.5))
			}
			.font(.callout.weight(.semibold))
			.foregroundStyle(.white.opacity(0.85))
			.padding(.horizontal, 18)
			.padding(.vertical, 14)
			.background(.white.opacity(0.045))
			.clipShape(RoundedRectangle(cornerRadius: 16))
			.overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.07), lineWidth: 1))
		}
		.buttonStyle(.plain)
		.disabled(completedRounds == 0)
		.opacity(completedRounds == 0 ? 0.4 : 1)
	}

	private var finishedCard: some View {
		VStack(spacing: 12) {
			Image(systemName: "trophy.fill").font(.system(size: 38)).foregroundStyle(.orange)
			Text("CAPTAIN OF THE SEVEN SEAS")
				.font(.footnote.weight(.black)).tracking(1.5).foregroundStyle(.orange)
			if let winner = ranking.first {
				Text(tr("\(winner.player.name) 승리!", "\(winner.player.name) wins!"))
					.font(.title2.bold())
				Text(tr("최종 점수 \(winner.score)점", "Final score: \(winner.score)"))
					.foregroundStyle(.white.opacity(0.65))
			}
			Text(roundsPlayed < maxRounds ? tr("\(roundsPlayed)라운드에서 종료 · 기록 보관함에 저장됨", "Ended after round \(roundsPlayed) · saved to history") : tr("10라운드 완주 · 기록 보관함에 저장됨", "All 10 rounds played · saved to history"))
				.font(.caption)
				.foregroundStyle(.white.opacity(0.45))
			Button {
				showFinalResult = true
			} label: {
				Label(tr("최종 결과 · 그래프 보기", "Final Results & Charts"), systemImage: "chart.xyaxis.line")
					.frame(maxWidth: .infinity)
					.padding()
					.background(.orange)
					.foregroundStyle(.black)
					.clipShape(RoundedRectangle(cornerRadius: 13))
			}
			.buttonStyle(.plain)
			Button {
				archiveCurrentGame()
				startNewGame()
			} label: {
				Label(tr("새 게임 시작", "Start New Game"), systemImage: "plus.circle.fill")
					.frame(maxWidth: .infinity)
					.padding()
					.background(.white.opacity(0.08))
					.foregroundStyle(.white)
					.clipShape(RoundedRectangle(cornerRadius: 13))
			}
			.buttonStyle(.plain)
		}
		.frame(maxWidth: .infinity)
		.padding(22)
		.piratePanel()
	}

	private var scoreTableCard: some View {
		VStack(alignment: .leading, spacing: 12) {
			sectionTitle("ROUND-BY-ROUND SCORES", subtitle: tr("라운드별 입찰 · 실제 트릭 · 기본 · 보너스(카드+동맹) · 배팅 · 누적", "Per round: bid · tricks · base · bonus (cards + alliance) · bet · total"))
			RoundScoreTable(results: results)
		}
		.padding(16)
		.piratePanel()
	}

	private func sectionTitle(_ title: String, subtitle: String) -> some View {
		VStack(alignment: .leading, spacing: 3) {
			Text(title).font(.system(size: 13, weight: .black, design: .rounded)).tracking(1.5).foregroundStyle(.orange)
			Text(subtitle).font(.footnote).foregroundStyle(.white.opacity(0.52))
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	// MARK: Game flow

	private func resumeGame() {
		normalizePlayerNames()
		applyTitle(gameTitle)
		ensureDraftEntries()
		viewingRound = rounds.count
		gameStarted = true
	}

	private func startGame() {
		normalizePlayerNames()
		applyTitle(gameTitle)
		if hasInProgressGame { archiveCurrentGame() }
		rounds = [RoundRecord(round: 1, entries: players.map { RoundEntry(playerID: $0.id) })]
		completedRounds = 0
		viewingRound = 1
		currentGameID = UUID()
		gameFinished = false
		gameStarted = true
	}

	private func saveRound() {
		guard isPlaying, hasDraftRound else { return }
		completedRounds = rounds.count
		if completedRounds >= maxRounds {
			finishGame()
		} else {
			rounds.append(RoundRecord(round: completedRounds + 1, entries: players.map { RoundEntry(playerID: $0.id) }))
			viewingRound = rounds.count
			scrollToken += 1
		}
	}

	private func finishGame() {
		guard completedRounds > 0 else { return }
		if hasDraftRound { rounds.removeLast() }
		viewingRound = min(viewingRound, max(rounds.count, 1))
		gameFinished = true
		archiveCurrentGame()
		showFinalResult = true
	}

	// 같은 게임을 다시 저장하면 새 항목을 만들지 않고 기존 기록을 갱신한다.
	private func archiveCurrentGame() {
		guard completedRounds > 0 else { return }
		let game = SavedGame(
			id: currentGameID,
			title: gameTitle,
			finishedAt: Date(),
			playerNames: players.map(\.name),
			results: results,
			finalScores: Dictionary(uniqueKeysWithValues: ranking.map { ($0.player.name, $0.score) }),
			roundsPlayed: roundsPlayed,
			players: players,
			rounds: Array(rounds.prefix(completedRounds))
		)
		if let index = savedGames.firstIndex(where: { $0.id == game.id }) {
			savedGames[index] = game
		} else {
			savedGames.insert(game, at: 0)
		}
	}

	private func startNewGame() {
		gameStarted = false
		gameFinished = false
		rounds = []
		completedRounds = 0
		viewingRound = 1
		currentGameID = UUID()
		gameTitle = ScoreRules.defaultTitle
		isTitleCustomized = false
	}

	private func loadSavedGame(_ game: SavedGame) {
		guard !game.rounds.isEmpty else { return }
		players = game.players.isEmpty ? game.playerNames.map { Player(name: $0, isNameCustomized: true) } : game.players
		rounds = game.rounds
		completedRounds = game.rounds.count
		gameFinished = completedRounds >= maxRounds
		if !gameFinished {
			rounds.append(RoundRecord(round: completedRounds + 1, entries: players.map { RoundEntry(playerID: $0.id) }))
		}
		viewingRound = rounds.count
		gameTitle = game.title
		currentGameID = game.id
		gameStarted = true
		showHistory = false
	}

	private func deleteSavedGame(_ game: SavedGame) {
		savedGames.removeAll { $0.id == game.id }
	}

	// MARK: Players

	private func addPlayer() {
		guard players.count < ScoreRules.maxPlayers else { return }
		players.append(Player(name: Player.defaultName(index: players.count)))
	}

	private func removePlayer(_ player: Player) {
		guard players.count > ScoreRules.minPlayers else { return }
		players.removeAll { $0.id == player.id }
		for index in rounds.indices {
			rounds[index].entries.removeAll { $0.playerID == player.id }
			rounds[index].alliances.removeAll { $0.contains(player.id) }
		}
	}

	private func normalizePlayerNames() {
		for index in players.indices {
			let name = players[index].name.trimmingCharacters(in: .whitespacesAndNewlines)
			players[index].name = name.isEmpty ? Player.defaultName(index: index) : name
			players[index].isNameCustomized = !name.isEmpty
		}
	}

	// 기본 이름은 포커스되면 비워 바로 입력하게 하고, 비운 채 떠나면 되돌린다.
	private func handleTitleFocus(_ focused: Bool) {
		if focused {
			if !isTitleCustomized { gameTitle = "" }
		} else {
			applyTitle(gameTitle)
		}
	}

	private func applyTitle(_ title: String) {
		let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
		gameTitle = trimmed.isEmpty ? ScoreRules.defaultTitle : trimmed
		isTitleCustomized = !trimmed.isEmpty
	}

	// 게임 중 추가된 플레이어는 진행 중인 라운드부터 참여한다. 완료된 라운드에는 넣지 않는다.
	private func ensureDraftEntries() {
		guard hasDraftRound, let last = rounds.indices.last else { return }
		for player in players where !rounds[last].entries.contains(where: { $0.playerID == player.id }) {
			rounds[last].entries.append(RoundEntry(playerID: player.id))
		}
	}

	private func addAlliance(index: Int) {
		guard players.count >= 2 else { return }
		rounds[index].alliances.append(Alliance(firstID: players[0].id, secondID: players[1].id))
	}

	// MARK: Persistence

	private func scrollToTop(_ proxy: ScrollViewProxy) {
		Task { @MainActor in
			try? await Task.sleep(for: .milliseconds(80))
			withAnimation(.easeInOut) { proxy.scrollTo(topID, anchor: .top) }
		}
	}

	private func restore() {
		let defaults = UserDefaults.standard
		if let data = defaults.data(forKey: saveKey),
		   let save = try? JSONDecoder().decode(AppSave.self, from: data) {
			apply(save)
			return
		}
		// v2 저장본은 라운드 입력 원본이 없어 진행 중 게임을 복원할 수 없다. 보관함만 가져온다.
		if let data = defaults.data(forKey: legacySaveKey),
		   let legacy = try? JSONDecoder().decode(LegacySave.self, from: data) {
			savedGames = legacy.savedGames
			defaults.removeObject(forKey: legacySaveKey)
		}
	}

	// 다시 실행하면 항상 설정 화면에서 시작한다. 진행 중 게임은 이어하기 카드로, 끝난 게임은 이미 보관함에 있으므로 비운다.
	private func apply(_ save: AppSave) {
		players = save.players
		savedGames = save.savedGames
		gameStarted = false
		gameFinished = false
		if save.gameFinished {
			rounds = []
			completedRounds = 0
			gameTitle = ScoreRules.defaultTitle
			isTitleCustomized = false
			currentGameID = UUID()
		} else {
			rounds = save.rounds
			completedRounds = min(save.completedRounds, save.rounds.count)
			gameTitle = save.gameTitle
			isTitleCustomized = save.isTitleCustomized
			currentGameID = save.currentGameID
			if hasInProgressGame, !hasDraftRound {
				rounds.append(RoundRecord(round: completedRounds + 1, entries: players.map { RoundEntry(playerID: $0.id) }))
			}
		}
		viewingRound = max(rounds.count, 1)
		ensureDraftEntries()
	}

	private func persist(_ save: AppSave) {
		guard let data = try? JSONEncoder().encode(save) else { return }
		UserDefaults.standard.set(data, forKey: saveKey)
	}
}

// MARK: - Score table & rules sheets

struct ScoreTableSheet: View {
	let results: [RoundResult]
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			ZStack {
				LinearGradient(colors: Palette.background, startPoint: .topLeading, endPoint: .bottomTrailing)
					.ignoresSafeArea()
				ScrollView {
					VStack(alignment: .leading, spacing: 12) {
						if results.isEmpty {
							Text(tr("아직 저장된 라운드가 없어요. 첫 라운드를 저장하면 여기에 점수표가 표시됩니다.", "No rounds saved yet. Save the first round to see the score table here."))
								.font(.footnote)
								.foregroundStyle(.white.opacity(0.5))
								.frame(maxWidth: .infinity, alignment: .leading)
						} else {
							RoundScoreTable(results: results)
						}
					}
					.padding(16)
					.piratePanel()
					.padding(16)
				}
			}
			.navigationTitle(tr("점수표", "Score Table"))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button(tr("닫기", "Close")) { dismiss() }
				}
			}
		}
		.tint(Palette.accent)
	}
}

struct RulesSheet: View {
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			ZStack {
				LinearGradient(colors: Palette.background, startPoint: .topLeading, endPoint: .bottomTrailing)
					.ignoresSafeArea()
				ScrollView {
					VStack(spacing: 16) {
						rulesCard
						expansionCard
					}
					.padding(16)
				}
			}
			.navigationTitle(tr("규칙", "Rules"))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button(tr("닫기", "Close")) { dismiss() }
				}
			}
		}
		.tint(Palette.accent)
	}

	private var rulesCard: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text(tr("기본 규칙 · 보너스·배팅·동맹은 정확히 입찰했을 때만", "Base rules · bonuses, bets and alliances only pay on an exact bid"))
				.font(.footnote)
				.foregroundStyle(.white.opacity(0.52))
				.padding(.bottom, 4)
			ruleLine(tr("입찰 성공", "Bid made"), tr("입찰 트릭 × 20점", "bid × 20"))
			ruleLine(tr("입찰 실패", "Bid missed"), tr("차이 × -10점", "difference × −10"))
			ruleLine(tr("0 입찰 성공", "Zero bid made"), tr("라운드 번호 × 10점", "round × 10"))
			ruleLine(tr("0 입찰 실패", "Zero bid missed"), tr("-라운드 번호 × 10점", "round × −10"))
			Divider().overlay(.white.opacity(0.1))
			ruleLine(tr("일반 14", "Standard 14"), tr("+10점 / 장", "+10 each"))
			ruleLine(tr("검정 14", "Black 14"), tr("+20점 / 장", "+20 each"))
			ruleLine(tr("해적이 인어 획득", "Pirate captures Mermaid"), tr("+20점 / 장", "+20 each"))
			ruleLine(tr("스컬킹이 해적 획득", "Skull King captures Pirate"), tr("+30점 / 장", "+30 each"))
			ruleLine(tr("인어가 스컬킹 획득", "Mermaid captures Skull King"), tr("+40점 / 장", "+40 each"))
			Divider().overlay(.white.opacity(0.1))
			ruleLine(tr("확장 숫자 8 (+5)", "Expansion 8 (+5)"), tr("트릭 승리 시 +5점 / 장", "+5 each when won"))
			ruleLine(tr("확장 숫자 7 (-5)", "Expansion 7 (−5)"), tr("트릭 승리 시 -5점 / 장", "−5 each when won"))
			ruleLine(tr("스컬킹·인어가 일등항해사 콘 획득", "Skull King/Mermaid captures First Mate Kon"), tr("+30점", "+30"))
			ruleLine(tr("데이비 존스의 사물함이 바다괴물 파괴", "Davy Jones' Locker sinks a sea monster"), tr("+20점 / 장 · 입찰 무관", "+20 each · regardless of bid"))
			Divider().overlay(.white.opacity(0.1))
			ruleLine(tr("라스칼 배팅", "Rascal's bet"), tr("0 · 10 · 20점 중 선택", "choose 0 · 10 · 20"))
			ruleLine(tr("배팅 결과", "Bet outcome"), tr("입찰 성공 +배팅 / 실패 -배팅", "made: +bet / missed: −bet"))
			Divider().overlay(.white.opacity(0.1))
			ruleLine(tr("동맹 (전리품 카드)", "Alliance (Loot card)"), tr("둘 다 입찰 성공 시 각 +\(ScoreRules.allianceBonus)점", "both make bids: +\(ScoreRules.allianceBonus) each"))
			Text(tr("※ 일부 판본은 인어가 스컬킹을 잡으면 +50점입니다. 사용하는 규칙에 맞게 아래 코드를 조정하세요.", "※ Some editions award +50 for a Mermaid capturing the Skull King. Adjust the code to match your ruleset."))
				.font(.caption)
				.foregroundStyle(.white.opacity(0.45))
				.fixedSize(horizontal: false, vertical: true)
				.padding(.top, 3)
		}
		.padding(16)
		.piratePanel()
	}

	private var expansionCard: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text(tr("확장팩 규칙", "Expansion Rules"))
				.font(.headline)
			Text(tr("구성품: 숫자 카드 12장 · 와일드 15 1장 · 해적(메리 손) 1장 · 마지막 일격 1장 · 일등 항해사 콘 1장 · 점박이 가오리 1장 · 데이비 존스의 사물함 1장 · 판자 위를 걸어라 1장",
					"Contents: 12 number cards · 1 Wild 15 · 1 Pirate (Mary Thorn) · 1 Final Strike · 1 First Mate Kon · 1 Spotted Ray · 1 Davy Jones' Locker · 1 Walk the Plank"))
				.font(.footnote)
				.foregroundStyle(.white.opacity(0.52))
				.fixedSize(horizontal: false, vertical: true)
			Divider().overlay(.white.opacity(0.1))

			ruleParagraph(tr("확장 숫자 7 · 8", "Expansion 7 · 8"),
				tr("일반 숫자 카드처럼 냅니다. 같은 숫자가 여러 장이고 그 숫자가 이기면 먼저 낸 카드가 승리합니다. 새 7은 -5점, 새 8은 +5점이며 입찰에 성공했을 때만 반영됩니다.",
				   "Play like normal number cards. If equal numbers win the trick, the first one played wins. The new 7 is −5 and the new 8 is +5, only when the bid is made."))
			ruleParagraph(tr("와일드 15", "Wild 15"),
				tr("노랑·보라·초록의 15로 사용합니다. 리드 수트가 아직 없으면 이 카드로 리드 수트를 정합니다. 리드 수트(검정 제외)가 있으면 그 색을 따라야 하고, 검정이 리드 수트면 색을 지정하지 않습니다.",
				   "Plays as a yellow, purple or green 15. If no lead suit is set yet, it sets the lead suit. If a lead suit (other than black) is set, it must follow that color; if black leads, no color is chosen."))
			ruleParagraph(tr("메리 손 (새 해적)", "Mary Thorn (new Pirate)"),
				tr("일반 해적처럼 플레이합니다. 고급 규칙 능력: 다른 플레이어의 손에서 무작위로 1장을 뽑습니다. 뽑은 카드는 다음 트릭에서 반드시 내야 하며, 다른 카드와 관계없이 사용됩니다.",
				   "Plays like a normal Pirate. Advanced ability: draw one random card from another player's hand. That card must be played in the next trick, regardless of the other cards."))
			ruleParagraph(tr("마지막 일격", "Final Strike"),
				tr("트릭에서 이길 수 없고 탈출 카드로도 쓰이지 않습니다. 모두 카드를 낸 뒤, 이 카드를 낸 플레이어는 즉시 다른 카드를 한 장 더 냅니다. 이번 라운드는 한 장 적게 플레이하며 마지막 트릭을 건너뜁니다.",
				   "Cannot win a trick and does not count as an Escape. After everyone has played, the player who played it immediately plays another card. They play one card fewer this round and skip the final trick."))
			ruleParagraph(tr("판자 위를 걸어라", "Walk the Plank"),
				tr("트릭에서 이길 수 없습니다. 이번 트릭에 해적 카드가 나왔다면 그 중 한 장을 제거합니다. 이로 인해 트릭의 승자가 바뀔 수 있습니다.",
				   "Cannot win a trick. If any Pirates were played in this trick, remove one of them. This may change who wins the trick."))
			ruleParagraph(tr("점박이 가오리", "Spotted Ray"),
				tr("가장 낮은 숫자 카드가 트릭에서 승리합니다. 동점이면 먼저 낸 카드가 승리합니다. 바다 괴물(크라켄·흰수염고래·점박이 가오리)이 여러 장 나오면 마지막에 낸 카드의 효과만 적용됩니다.",
				   "The lowest number card wins the trick. On a tie, the first played wins. If several sea monsters (Kraken, White Whale, Spotted Ray) are played, only the last one's effect applies."))
			ruleParagraph(tr("데이비 존스의 사물함", "Davy Jones' Locker"),
				tr("바다 괴물이 게임에 포함될 때만 사용합니다. 트릭에서 이기지 못하지만, 트릭에 나온 모든 바다 괴물을 순서와 관계없이 파괴합니다. 파괴한 바다 괴물 한 장당 20점을 별도로 얻고, 그 트릭은 남은 카드 중 가장 높은 카드가 이깁니다.",
				   "Only used when sea monsters are in the game. Cannot win a trick, but sinks every sea monster played to it regardless of order. Each sunk sea monster is worth +20 as a separate bonus; the highest remaining card wins the trick."))
			ruleParagraph(tr("일등 항해사 콘", "First Mate Kon"),
				tr("스컬킹과 인어를 제외한 모든 카드를 이깁니다. 트릭에서 이기면 잡은 해적들의 능력을 모두 쓸 수 있지만 점수 보너스는 없습니다. 스컬킹이나 인어가 콘을 잡으면 30점 보너스를 얻습니다.",
				   "Beats every card except the Skull King and Mermaids. If he wins the trick, you may use the abilities of every Pirate he captured, but gain no bonus. If the Skull King or a Mermaid captures him, that player gains +30."))
		}
		.padding(16)
		.piratePanel()
	}

	private func ruleParagraph(_ title: String, _ body: String) -> some View {
		VStack(alignment: .leading, spacing: 3) {
			Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.white)
			Text(body)
				.font(.caption)
				.foregroundStyle(.white.opacity(0.62))
				.fixedSize(horizontal: false, vertical: true)
		}
	}

	private func ruleLine(_ title: String, _ value: String) -> some View {
		HStack {
			Text(title).foregroundStyle(.white.opacity(0.72))
			Spacer()
			Text(value).fontWeight(.semibold).foregroundStyle(.white)
		}
		.font(.footnote)
	}
}

// MARK: - Round score table

struct RoundScoreTable: View {
	let results: [RoundResult]

	private enum Column {
		static let count: CGFloat = 34
		static let score: CGFloat = 46
		static let total: CGFloat = 52
	}

	private var rounds: [Int] {
		Array(Set(results.map(\.round))).sorted()
	}

	var body: some View {
		ForEach(rounds, id: \.self) { roundNumber in
			VStack(alignment: .leading, spacing: 8) {
				Text("ROUND \(roundNumber)")
					.font(.footnote.weight(.black))
					.tracking(1.2)
					.foregroundStyle(.orange)
				header
				ForEach(results.filter { $0.round == roundNumber }.sorted { $0.playerName < $1.playerName }) { result in
					row(result)
					Divider().overlay(.white.opacity(0.06))
				}
			}
			.padding(11)
			.background(.white.opacity(0.025))
			.clipShape(RoundedRectangle(cornerRadius: 12))
		}
	}

	private var header: some View {
		HStack(spacing: 0) {
			Text(tr("플레이어", "Player")).frame(maxWidth: .infinity, alignment: .leading)
			Text(tr("입찰", "Bid")).frame(width: Column.count)
			Text(tr("실제", "Won")).frame(width: Column.count)
			Text(tr("기본", "Base")).frame(width: Column.score, alignment: .trailing)
			Text(tr("보너스", "Bonus")).frame(width: Column.score, alignment: .trailing)
			Text(tr("배팅", "Bet")).frame(width: Column.score, alignment: .trailing)
			Text(tr("누적", "Total")).frame(width: Column.total, alignment: .trailing)
		}
		.font(.system(size: 10, weight: .bold))
		.foregroundStyle(.white.opacity(0.42))
	}

	private func row(_ result: RoundResult) -> some View {
		HStack(spacing: 0) {
			Text(result.playerName)
				.lineLimit(1)
				.frame(maxWidth: .infinity, alignment: .leading)
			Text("\(result.bid)").frame(width: Column.count)
			Text("\(result.tricks)").frame(width: Column.count)
			Text("\(result.bidPoints)").frame(width: Column.score, alignment: .trailing)
				.foregroundStyle(result.bidPoints >= 0 ? Color.green : Color.red)
			Text("\(result.bonusPoints + result.alliancePoints)").frame(width: Column.score, alignment: .trailing)
				.foregroundStyle(.orange)
			Text(signed(result.betPoints)).frame(width: Column.score, alignment: .trailing)
				.foregroundStyle(betColor(result.betPoints))
			Text("\(result.runningTotal)").frame(width: Column.total, alignment: .trailing)
				.fontWeight(.bold)
		}
		.font(.system(size: 12, weight: .medium, design: .rounded))
		.monospacedDigit()
		.padding(.vertical, 5)
	}

	private func signed(_ value: Int) -> String {
		value > 0 ? "+\(value)" : "\(value)"
	}

	private func betColor(_ value: Int) -> Color {
		if value > 0 { return .green }
		if value < 0 { return .red }
		return .white.opacity(0.35)
	}
}

// MARK: - Player entry

struct PlayerEntryCard: View {
	let player: Player
	@Binding var entry: RoundEntry
	let round: Int
	var cumulative: Int = 0
	var alliancePoints: Int = 0
	var inAlliance: Bool = false

	private var score: RoundScore {
		ScoreRules.score(entry: entry, round: round, alliance: alliancePoints)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			titleRow
			HStack(spacing: 10) {
				counter(title: tr("입찰", "Bid"), value: $entry.bid, range: 0...round, stacked: true)
				counter(title: tr("실제 트릭", "Tricks won"), value: $entry.tricks, range: 0...round, stacked: true)
			}
			betSection
			bonusSection
			summaryRow
		}
		.padding(13)
		.background(Palette.card)
		.clipShape(RoundedRectangle(cornerRadius: 15))
		.overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.07), lineWidth: 1))
	}

	private var titleRow: some View {
		HStack(spacing: 9) {
			Image(systemName: "person.fill")
				.foregroundStyle(.orange)
				.frame(width: 32, height: 32)
				.background(.orange.opacity(0.12))
				.clipShape(RoundedRectangle(cornerRadius: 9))
			VStack(alignment: .leading, spacing: 2) {
				Text(player.name).font(.headline)
				Text(tr("누적 \(cumulative)점", "Total \(cumulative)"))
					.font(.caption.weight(.semibold))
					.foregroundStyle(.white.opacity(0.55))
			}
			Spacer()
			Text("\(score.total > 0 ? "+" : "")\(score.total)")
				.font(.system(size: 20, weight: .black, design: .rounded))
				.foregroundStyle(score.total >= 0 ? Color.green : Color.red)
			Text(tr("점", "pts")).font(.caption).foregroundStyle(.white.opacity(0.5))
		}
	}

	private var betSection: some View {
		VStack(alignment: .leading, spacing: 7) {
			HStack {
				Image(systemName: "figure.stand").foregroundStyle(.orange)
				Text(tr("라스칼 배팅", "Rascal's bet")).font(.callout.weight(.semibold))
				Spacer()
				Text(entry.bet == 0 ? tr("배팅 없음", "No bet") : tr("\(entry.bet)점 배팅", "Betting \(entry.bet)"))
					.font(.footnote.bold())
					.foregroundStyle(.orange)
			}
			Picker(tr("라스칼 배팅", "Rascal's bet"), selection: $entry.bet) {
				ForEach(ScoreRules.betOptions, id: \.self) { option in
					Text(option == 0 ? tr("없음", "None") : tr("\(option)점", "\(option)")).tag(option)
				}
			}
			.pickerStyle(.segmented)
			Text(tr("입찰에 성공하면 배팅만큼 얻고, 실패하면 배팅만큼 잃어요.", "Make your bid to win the bet; miss it and you lose the same amount."))
				.font(.caption).foregroundStyle(.white.opacity(0.48))
		}
		.padding(.vertical, 2)
	}

	private var bonusSection: some View {
		DisclosureGroup {
			VStack(spacing: 9) {
				counter(title: tr("일반 14 (+10)", "Standard 14 (+10)"), value: $entry.standard14, range: 0...10)
				counter(title: tr("검정 14 (+20)", "Black 14 (+20)"), value: $entry.black14, range: 0...10)
				counter(title: tr("해적이 잡은 인어 (+20)", "Mermaid taken by Pirate (+20)"), value: $entry.mermaidsByPirate, range: 0...10)
				counter(title: tr("스컬킹이 잡은 해적 (+30)", "Pirate taken by Skull King (+30)"), value: $entry.piratesBySkullKing, range: 0...10)
				counter(title: tr("인어가 잡은 스컬킹 (+40)", "Skull King taken by Mermaid (+40)"), value: $entry.skullKingByMermaid, range: 0...1)
				counter(title: tr("확장 숫자 8 (+5)", "Expansion 8 (+5)"), value: $entry.expansionEight, range: 0...4)
				counter(title: tr("확장 숫자 7 (-5)", "Expansion 7 (−5)"), value: $entry.expansionSeven, range: 0...4)
				counter(title: tr("스컬킹·인어가 잡은 일등항해사 콘 (+30)", "First Mate Kon taken by Skull King/Mermaid (+30)"), value: $entry.firstMateCaptured, range: 0...1)
				counter(title: tr("데이비 존스가 파괴한 바다괴물 (+20)", "Sea monsters sunk by Davy Jones (+20)"), value: $entry.davyJonesMonsters, range: 0...ScoreRules.seaMonsterCount)
				HStack {
					Text(tr("보너스 합계", "Bonus total"))
					Spacer()
					Text(tr("\(entry.bonusPoints)점", "\(entry.bonusPoints) pts")).bold().foregroundStyle(.orange)
				}
				.font(.callout)
				.padding(.top, 4)
				Text(tr("보너스는 입찰에 성공했을 때만 더해져요. 확장 7의 -5도 마찬가지예요. 데이비 존스의 사물함 보너스만 입찰과 상관없이 받아요.", "Bonus points only count when the bid is made, including the −5 from the expansion 7. Only the Davy Jones' Locker bonus is paid regardless of the bid."))
					.font(.caption).foregroundStyle(.white.opacity(0.48))
					.frame(maxWidth: .infinity, alignment: .leading)
			}
			.padding(.top, 10)
		} label: {
			HStack {
				Image(systemName: "sparkles").foregroundStyle(.orange)
				Text(tr("특수 카드 보너스", "Special card bonus")).font(.callout.weight(.semibold))
				Spacer()
				Text(tr("\(entry.bonusPoints)점", "\(entry.bonusPoints) pts")).font(.footnote.bold()).foregroundStyle(.orange)
			}
		}
		.tint(.orange)
	}

	private var summaryRow: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack {
				Text(tr("기본 \(score.bid)", "Base \(score.bid)"))
				Spacer()
				Text(tr("보너스 \(score.bonus)", "Bonus \(score.bonus)"))
				Spacer()
				Text(tr("배팅 \(score.bet > 0 ? "+" : "")\(score.bet)", "Bet \(score.bet > 0 ? "+" : "")\(score.bet)"))
				Spacer()
				Text(tr("합계 \(score.total)점", "Total \(score.total)")).bold()
			}
			.font(.caption.weight(.medium))
			.foregroundStyle(.white.opacity(0.68))
			if inAlliance {
				Label(allianceStatus, systemImage: "link")
					.font(.caption.weight(.semibold))
					.foregroundStyle(score.alliance > 0 ? Color.green : Color.orange)
			}
		}
		.padding(.top, 2)
	}

	private var allianceStatus: String {
		score.alliance > 0
			? tr("동맹 보너스 +\(score.alliance)점", "Alliance bonus +\(score.alliance)")
			: tr("동맹 중 · 둘 다 입찰 성공 시 +\(ScoreRules.allianceBonus)점", "In alliance · +\(ScoreRules.allianceBonus) if both make bids")
	}

	// stacked: 반폭에 둘 때는 버튼(46×2)과 숫자(34)만으로 폭이 차서 제목이 잘리므로 제목을 위에 올린다.
	@ViewBuilder
	private func counter(title: String, value: Binding<Int>, range: ClosedRange<Int>, stacked: Bool = false) -> some View {
		let label = Text(title)
			.font(.footnote.weight(.medium))
			.foregroundStyle(.white.opacity(0.75))
			.lineLimit(stacked ? 1 : 2)
			.minimumScaleFactor(0.8)
		if stacked {
			VStack(spacing: 2) {
				label
				stepper(value: value, range: range)
					.frame(maxWidth: .infinity)
			}
			.frame(maxWidth: .infinity)
			.padding(.vertical, 4)
		} else {
			HStack(spacing: 4) {
				label
				Spacer(minLength: 2)
				stepper(value: value, range: range)
			}
			.padding(.vertical, 4)
		}
	}

	private func stepper(value: Binding<Int>, range: ClosedRange<Int>) -> some View {
		HStack(spacing: 4) {
			stepButton(systemImage: "minus.circle.fill", disabled: value.wrappedValue <= range.lowerBound) {
				value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
			}
			Text("\(value.wrappedValue)")
				.font(.title2.monospacedDigit().bold())
				.frame(minWidth: 34)
			stepButton(systemImage: "plus.circle.fill", disabled: value.wrappedValue >= range.upperBound) {
				value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
			}
		}
		.foregroundStyle(.orange)
	}

	// 손가락으로 누르기 쉽도록 아이콘과 터치 영역을 44pt 이상으로 둔다.
	private func stepButton(systemImage: String, disabled: Bool, action: @escaping () -> Void) -> some View {
		Button(action: action) {
			Image(systemName: systemImage)
				.font(.system(size: 36))
				.frame(width: 46, height: 46)
				.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.foregroundStyle(.orange)
		.disabled(disabled)
		.opacity(disabled ? 0.3 : 1)
	}
}

// MARK: - Alliance

struct AllianceRow: View {
	@Binding var alliance: Alliance
	let players: [Player]
	let entries: [RoundEntry]
	let onRemove: () -> Void

	private var bothSucceeded: Bool {
		[alliance.firstID, alliance.secondID].allSatisfy { id in
			entries.first { $0.playerID == id }.map { $0.bid == $0.tricks } ?? false
		}
	}

	private var statusText: String {
		if !alliance.isValid { return tr("서로 다른 두 명을 골라 주세요", "Pick two different players") }
		return bothSucceeded ? tr("둘 다 입찰 성공 · 각 +\(ScoreRules.allianceBonus)점", "Both made bids · +\(ScoreRules.allianceBonus) each") : tr("둘 다 입찰에 성공해야 보너스를 받아요", "Both must make their bids to earn the bonus")
	}

	private var statusColor: Color {
		if !alliance.isValid { return .red }
		return bothSucceeded ? .green : .white.opacity(0.5)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack {
				Text(statusText)
					.font(.caption)
					.foregroundStyle(statusColor)
					.lineLimit(2)
				Spacer(minLength: 8)
				Button(action: onRemove) {
					Image(systemName: "xmark.circle.fill")
						.font(.title3)
						.foregroundStyle(.white.opacity(0.4))
				}
				.buttonStyle(.plain)
			}
			HStack(spacing: 8) {
				playerPicker($alliance.firstID)
				Image(systemName: "arrow.left.arrow.right")
					.font(.caption)
					.foregroundStyle(.white.opacity(0.5))
				playerPicker($alliance.secondID)
			}
		}
		.padding(10)
		.background(.white.opacity(0.04))
		.clipShape(RoundedRectangle(cornerRadius: 11))
	}

	private func playerName(_ id: UUID) -> String {
		players.first { $0.id == id }?.name ?? tr("플레이어", "Player")
	}

	// 시스템 메뉴 피커는 라벨 폭을 줄이지 못해 두 개를 나란히 두면 겹친다. 라벨을 직접 그려 절반 폭에 맞춘다.
	private func playerPicker(_ selection: Binding<UUID>) -> some View {
		Menu {
			Picker(tr("플레이어", "Player"), selection: selection) {
				ForEach(players) { player in
					Text(player.name).tag(player.id)
				}
			}
		} label: {
			HStack(spacing: 6) {
				Text(playerName(selection.wrappedValue))
					.font(.callout.weight(.semibold))
					.lineLimit(1)
					.truncationMode(.tail)
				Spacer(minLength: 0)
				Image(systemName: "chevron.up.chevron.down")
					.font(.caption2.weight(.bold))
			}
			.foregroundStyle(.orange)
			.padding(.horizontal, 10)
			.padding(.vertical, 9)
			.frame(maxWidth: .infinity)
			.background(.white.opacity(0.07))
			.clipShape(RoundedRectangle(cornerRadius: 9))
		}
	}
}

// MARK: - Final result

struct FinalResultView: View {
	let title: String
	let playerNames: [String]
	let results: [RoundResult]
	let roundsPlayed: Int
	var onContinue: (() -> Void)? = nil
	var onNewGame: (() -> Void)? = nil
	@Environment(\.dismiss) private var dismiss
	@State private var shareImage: ShareImage?
	@State private var saveNotice: SaveNotice?

	private struct SaveNotice: Identifiable {
		let id = UUID()
		let text: String
	}

	private struct Standing: Identifiable {
		var id: String { name }
		let name: String
		let score: Int
	}

	private struct ScorePoint: Identifiable {
		let id = UUID()
		let name: String
		let round: Int
		let total: Int
	}

	private var standings: [Standing] {
		playerNames.map { name in
			Standing(name: name, score: results.filter { $0.playerName == name }.reduce(0) { $0 + $1.roundPoints })
		}
		.sorted { $0.score == $1.score ? $0.name < $1.name : $0.score > $1.score }
	}

	private var progression: [ScorePoint] {
		var points = playerNames.map { ScorePoint(name: $0, round: 0, total: 0) }
		for result in results.sorted(by: { $0.round < $1.round }) {
			points.append(ScorePoint(name: result.playerName, round: result.round, total: result.runningTotal))
		}
		return points
	}

	var body: some View {
		NavigationStack {
			ZStack {
				LinearGradient(colors: Palette.background, startPoint: .topLeading, endPoint: .bottomTrailing)
					.ignoresSafeArea()
				ScrollView {
					VStack(spacing: 18) {
						winnerCard
						standingsCard
						progressionCard
						roundTableCard
						actionButtons
					}
					.padding(.horizontal, 16)
					.padding(.top, 12)
					.padding(.bottom, 32)
				}
			}
			.navigationTitle(tr("최종 결과", "Final Results"))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button { renderShareImage() } label: {
						Image(systemName: "square.and.arrow.up")
					}
					.accessibilityLabel(tr("이미지로 공유", "Share as Image"))
				}
				ToolbarItem(placement: .topBarTrailing) {
					Button(tr("닫기", "Close")) { dismiss() }
				}
			}
			.sheet(item: $shareImage) { item in
				ActivityShareSheet(items: [item.image])
			}
			.alert(item: $saveNotice) { notice in
				Alert(title: Text(notice.text))
			}
		}
		.tint(Palette.accent)
	}

	// 공유 이미지에는 버튼을 빼고 카드만 담는다. 폭을 고정해야 ImageRenderer가 세로 길이를 정할 수 있다.
	private var shareContent: some View {
		VStack(spacing: 18) {
			winnerCard
			standingsCard
			progressionCard
			roundTableCard
		}
		.padding(16)
		.frame(width: 390)
		.background(LinearGradient(colors: Palette.background, startPoint: .topLeading, endPoint: .bottomTrailing))
		.environment(\.colorScheme, .dark)
		.foregroundStyle(.white)
	}

	@MainActor
	private func renderImage() -> UIImage? {
		let renderer = ImageRenderer(content: shareContent)
		renderer.scale = 3
		return renderer.uiImage
	}

	@MainActor
	private func renderShareImage() {
		guard let image = renderImage() else { return }
		shareImage = ShareImage(image: image)
	}

	@MainActor
	private func saveToPhotos() {
		guard let image = renderImage() else { return }
		PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
			guard status == .authorized || status == .limited else {
				Task { @MainActor in
					saveNotice = SaveNotice(text: tr("사진 접근 권한이 없어요. 설정 > SkullKing에서 사진 추가를 허용해 주세요.", "No photo access. Allow adding photos in Settings > SkullKing."))
				}
				return
			}
			PHPhotoLibrary.shared().performChanges({
				PHAssetChangeRequest.creationRequestForAsset(from: image)
			}) { success, _ in
				Task { @MainActor in
					saveNotice = SaveNotice(text: success ? tr("갤러리에 저장했어요.", "Saved to Photos.") : tr("저장하지 못했어요. 다시 시도해 주세요.", "Could not save. Please try again."))
				}
			}
		}
	}

	private var winnerCard: some View {
		VStack(spacing: 10) {
			Image(systemName: "trophy.fill").font(.system(size: 44)).foregroundStyle(.orange)
			Text("CAPTAIN OF THE SEVEN SEAS")
				.font(.footnote.weight(.black)).tracking(1.5).foregroundStyle(.orange)
			Text(title)
				.font(.callout)
				.foregroundStyle(.white.opacity(0.6))
			if let winner = standings.first {
				Text(tr("\(winner.name) 승리!", "\(winner.name) wins!"))
					.font(.system(size: 30, weight: .black, design: .rounded))
				Text(tr("최종 점수 \(winner.score)점", "Final score: \(winner.score)"))
					.font(.headline)
					.foregroundStyle(.white.opacity(0.75))
			}
			Text(roundsPlayed < ScoreRules.maxRounds ? tr("\(roundsPlayed)라운드에서 종료", "Ended after round \(roundsPlayed)") : tr("10라운드 완주", "All 10 rounds played"))
				.font(.footnote.weight(.semibold))
				.padding(.horizontal, 10)
				.padding(.vertical, 5)
				.background(.white.opacity(0.08))
				.clipShape(Capsule())
		}
		.frame(maxWidth: .infinity)
		.padding(22)
		.background {
			RoundedRectangle(cornerRadius: 22)
				.fill(LinearGradient(colors: [Palette.heroTop, Palette.heroBottom], startPoint: .topLeading, endPoint: .bottomTrailing))
		}
		.overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.09), lineWidth: 1))
	}

	private var standingsCard: some View {
		VStack(alignment: .leading, spacing: 12) {
			cardTitle("FINAL SCORES", subtitle: tr("최종 순위와 점수", "Final standings and scores"))
			ForEach(Array(standings.enumerated()), id: \.element.id) { index, item in
				HStack(spacing: 10) {
					Text(index == 0 ? "👑" : "\(index + 1)")
						.font(.headline.monospacedDigit())
						.frame(width: 28)
						.foregroundStyle(index == 0 ? Color.orange : Color.white.opacity(0.6))
					Text(item.name).font(.callout.weight(.bold))
					Spacer()
					Text(tr("\(item.score)점", "\(item.score) pts"))
						.font(.system(size: 20, weight: .black, design: .rounded))
						.monospacedDigit()
						.foregroundStyle(index == 0 ? Color.orange : Color.white)
				}
				.padding(.vertical, 4)
			}
			Chart(standings) { item in
				BarMark(x: .value(tr("점수", "Score"), item.score), y: .value(tr("플레이어", "Player"), item.name))
					.foregroundStyle(item.id == standings.first?.id ? Color.orange : Color.white.opacity(0.45))
					.cornerRadius(5)
					.annotation(position: .trailing) {
						Text("\(item.score)")
							.font(.caption.bold())
							.foregroundStyle(.white.opacity(0.8))
					}
			}
			.chartYAxis {
				AxisMarks { _ in
					AxisValueLabel()
						.foregroundStyle(.white.opacity(0.75))
				}
			}
			.chartXAxis {
				AxisMarks { _ in
					AxisGridLine().foregroundStyle(.white.opacity(0.08))
					AxisValueLabel().foregroundStyle(.white.opacity(0.45))
				}
			}
			.frame(height: CGFloat(standings.count) * 38 + 30)
			.padding(.top, 6)
		}
		.padding(16)
		.piratePanel()
	}

	private var progressionCard: some View {
		VStack(alignment: .leading, spacing: 12) {
			cardTitle("SCORE PROGRESSION", subtitle: tr("라운드별 누적 점수 추이", "Cumulative score by round"))
			Chart(progression) { point in
				LineMark(x: .value(tr("라운드", "Round"), point.round), y: .value(tr("누적 점수", "Total"), point.total))
					.foregroundStyle(by: .value(tr("플레이어", "Player"), point.name))
					.interpolationMethod(.monotone)
					.lineStyle(StrokeStyle(lineWidth: 2.5))
				PointMark(x: .value(tr("라운드", "Round"), point.round), y: .value(tr("누적 점수", "Total"), point.total))
					.foregroundStyle(by: .value(tr("플레이어", "Player"), point.name))
					.symbolSize(28)
			}
			.chartXScale(domain: 0...max(roundsPlayed, 1))
			.chartXAxis {
				AxisMarks(values: Array(0...max(roundsPlayed, 1))) { _ in
					AxisGridLine().foregroundStyle(.white.opacity(0.08))
					AxisValueLabel().foregroundStyle(.white.opacity(0.5))
				}
			}
			.chartYAxis {
				AxisMarks { _ in
					AxisGridLine().foregroundStyle(.white.opacity(0.08))
					AxisValueLabel().foregroundStyle(.white.opacity(0.5))
				}
			}
			.chartLegend(position: .bottom, spacing: 10)
			.frame(height: 260)
		}
		.padding(16)
		.piratePanel()
	}

	private var roundTableCard: some View {
		VStack(alignment: .leading, spacing: 12) {
			cardTitle("ROUND-BY-ROUND", subtitle: tr("입찰 · 실제 · 기본 · 보너스(카드+동맹) · 배팅 · 누적", "Bid · won · base · bonus (cards + alliance) · bet · total"))
			RoundScoreTable(results: results)
		}
		.padding(16)
		.piratePanel()
	}

	private var actionButtons: some View {
		VStack(spacing: 10) {
			HStack(spacing: 10) {
				Button { saveToPhotos() } label: {
					Label(tr("갤러리에 저장", "Save to Photos"), systemImage: "photo.badge.arrow.down")
						.frame(maxWidth: .infinity)
						.padding()
						.background(.white.opacity(0.08))
						.foregroundStyle(.white)
						.clipShape(RoundedRectangle(cornerRadius: 13))
				}
				.buttonStyle(.plain)
				Button { renderShareImage() } label: {
					Label(tr("이미지 공유", "Share Image"), systemImage: "square.and.arrow.up")
						.frame(maxWidth: .infinity)
						.padding()
						.background(.white.opacity(0.08))
						.foregroundStyle(.white)
						.clipShape(RoundedRectangle(cornerRadius: 13))
				}
				.buttonStyle(.plain)
			}
			if let onNewGame {
				Button(action: onNewGame) {
					Label(tr("기록 저장 후 새 게임", "Save & Start New Game"), systemImage: "plus.circle.fill")
						.frame(maxWidth: .infinity)
						.padding()
						.background(.orange)
						.foregroundStyle(.black)
						.clipShape(RoundedRectangle(cornerRadius: 13))
				}
				.buttonStyle(.plain)
			}
			if let onContinue, roundsPlayed < ScoreRules.maxRounds {
				Button(action: onContinue) {
					Label(tr("이 게임 이어하기", "Resume This Game"), systemImage: "play.fill")
						.frame(maxWidth: .infinity)
						.padding()
						.background(.orange)
						.foregroundStyle(.black)
						.clipShape(RoundedRectangle(cornerRadius: 13))
				}
				.buttonStyle(.plain)
			}
			Button { dismiss() } label: {
				Text(tr("닫기", "Close"))
					.frame(maxWidth: .infinity)
					.padding()
					.background(.white.opacity(0.08))
					.foregroundStyle(.white)
					.clipShape(RoundedRectangle(cornerRadius: 13))
			}
			.buttonStyle(.plain)
		}
	}

	private func cardTitle(_ title: String, subtitle: String) -> some View {
		VStack(alignment: .leading, spacing: 3) {
			Text(title).font(.system(size: 13, weight: .black, design: .rounded)).tracking(1.5).foregroundStyle(.orange)
			Text(subtitle).font(.footnote).foregroundStyle(.white.opacity(0.52))
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}

// MARK: - Sharing

struct ShareImage: Identifiable {
	let id = UUID()
	let image: UIImage
}

struct ActivityShareSheet: UIViewControllerRepresentable {
	let items: [Any]

	func makeUIViewController(context: Context) -> UIActivityViewController {
		UIActivityViewController(activityItems: items, applicationActivities: nil)
	}

	func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Player setup

struct PlayerEditorSection: View {
	@Binding var players: [Player]
	let onAdd: () -> Void
	let onRemove: (Player) -> Void
	@FocusState private var focusedPlayerID: UUID?

	var body: some View {
		Section {
			ForEach($players) { $player in
				HStack(spacing: 10) {
					Image(systemName: "person.fill").foregroundStyle(.orange)
					TextField(tr("플레이어 이름", "Player name"), text: $player.name)
						.focused($focusedPlayerID, equals: player.id)
						.submitLabel(.done)
				}
			}
			.onDelete(perform: remove)
			.onMove { players.move(fromOffsets: $0, toOffset: $1) }
			Button(action: onAdd) {
				Label(tr("플레이어 추가", "Add Player"), systemImage: "person.badge.plus")
			}
			.disabled(players.count >= ScoreRules.maxPlayers)
			.onChange(of: focusedPlayerID) { old, new in
				handleFocusChange(from: old, to: new)
			}
		} header: {
			Text(tr("플레이어 \(players.count)명 · \(ScoreRules.minPlayers)~\(ScoreRules.maxPlayers)명", "\(players.count) players · \(ScoreRules.minPlayers)–\(ScoreRules.maxPlayers)"))
		} footer: {
			Text(tr("이름을 눌러 바로 수정할 수 있어요. 왼쪽으로 밀면 삭제, 오른쪽 위 편집으로 순서를 바꿀 수 있어요. 삭제하면 그 플레이어의 점수 기록도 함께 지워집니다.", "Tap a name to edit it. Swipe left to remove, use Edit to reorder. Removing a player also deletes their scores."))
		}
		.listRowBackground(Palette.card)
	}

	// 기본 이름은 포커스되면 비워 바로 입력하게 하고, 비운 채 떠나면 되돌린다.
	private func handleFocusChange(from old: UUID?, to new: UUID?) {
		if let old, let index = players.firstIndex(where: { $0.id == old }) {
			let name = players[index].name.trimmingCharacters(in: .whitespaces)
			players[index].name = name.isEmpty ? Player.defaultName(index: index) : name
			players[index].isNameCustomized = !name.isEmpty
		}
		if let new, let index = players.firstIndex(where: { $0.id == new }),
		   !players[index].isNameCustomized {
			players[index].name = ""
		}
	}

	private func remove(at offsets: IndexSet) {
		let targets = offsets.map { players[$0] }
		guard players.count - targets.count >= ScoreRules.minPlayers else { return }
		targets.forEach(onRemove)
	}
}

struct PlayerSetupView: View {
	@Binding var players: [Player]
	let onAdd: () -> Void
	let onRemove: (Player) -> Void
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			List {
				PlayerEditorSection(players: $players, onAdd: onAdd, onRemove: onRemove)
			}
			.navigationTitle(tr("플레이어 설정", "Players"))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarLeading) { EditButton() }
				ToolbarItem(placement: .topBarTrailing) { Button(tr("완료", "Done")) { dismiss() } }
			}
		}
	}
}

// MARK: - History

struct HistoryView: View {
	let games: [SavedGame]
	let onLoad: (SavedGame) -> Void
	let onDelete: (SavedGame) -> Void
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			List {
				if games.isEmpty {
					ContentUnavailableView(tr("저장된 게임이 없어요", "No saved games"), systemImage: "books.vertical", description: Text(tr("게임을 끝내거나 저장하면 여기에 자동으로 보관됩니다.", "Finished or saved games appear here automatically.")))
				} else {
					ForEach(games) { game in
						NavigationLink {
							FinalResultView(
								title: game.title,
								playerNames: game.playerNames,
								results: game.results,
								roundsPlayed: game.roundsPlayed,
								onContinue: game.rounds.isEmpty ? nil : {
									onLoad(game)
									dismiss()
								}
							)
						} label: {
							gameRow(game)
						}
						.listRowBackground(Color(.secondarySystemGroupedBackground))
						.swipeActions(edge: .trailing, allowsFullSwipe: false) {
							Button(role: .destructive) {
								onDelete(game)
							} label: {
								Label(tr("삭제", "Delete"), systemImage: "trash")
							}
							if game.roundsPlayed < ScoreRules.maxRounds, !game.rounds.isEmpty {
								Button {
									onLoad(game)
									dismiss()
								} label: {
									Label(tr("이어하기", "Resume"), systemImage: "play.fill")
								}
								.tint(.orange)
							}
						}
					}
				}
			}
			.navigationTitle(tr("게임 기록", "Game History"))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button(tr("닫기", "Close")) { dismiss() }
				}
			}
		}
	}

	private func gameRow(_ game: SavedGame) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack {
				Text(game.title).font(.headline)
				Spacer()
				Text(game.finishedAt, style: .date).font(.footnote).foregroundStyle(.secondary)
			}
			Text(game.playerNames.joined(separator: " · "))
				.font(.footnote).foregroundStyle(.secondary)
			HStack(spacing: 8) {
				if let winner = game.finalScores.max(by: { $0.value < $1.value }) {
					Label(tr("\(winner.key) · \(winner.value)점", "\(winner.key) · \(winner.value) pts"), systemImage: "trophy.fill")
						.font(.callout.weight(.semibold))
						.foregroundStyle(.orange)
				}
				Spacer()
				Text(game.roundsPlayed < ScoreRules.maxRounds ? tr("\(game.roundsPlayed)R 중도 종료", "Ended at R\(game.roundsPlayed)") : tr("10R 완주", "10R complete"))
					.font(.caption.weight(.semibold))
					.padding(.horizontal, 7)
					.padding(.vertical, 3)
					.background(.secondary.opacity(0.15))
					.clipShape(Capsule())
			}
		}
		.padding(.vertical, 6)
	}
}

private extension View {
	func piratePanel() -> some View {
		self
			.background(Palette.panel)
			.clipShape(RoundedRectangle(cornerRadius: 20))
			.overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.075), lineWidth: 1))
	}
}
