import Foundation

/// The interface strings, handed to a client that cannot link `L10n`.
///
/// The macOS app reads `L10n` directly. The Windows client is a separate
/// process in another language, and duplicating 400 lines of translation
/// there would guarantee the two drift apart — so the engine exports them
/// instead, and the strings keep one home.
///
/// Written out key by key rather than reflected: Swift cannot enumerate
/// computed properties, and in any case an explicit list is the contract.
/// This file is generated from the `var … : String` declarations of `L10n`;
/// adding a string there and re-running that step is what publishes it.
enum Strings {

    /// Every interface string, in the requested language.
    static func table(_ t: L10n) -> [String: String] {
        templates(t).merging([
            "appTagline": t.appTagline,
            "welcomeTitle": t.welcomeTitle,
            "welcomeBody": t.welcomeBody,
            "chooseFolder": t.chooseFolder,
            "dropHere": t.dropHere,
            "recentProjects": t.recentProjects,
            "supportedLanguages": t.supportedLanguages,
            "analyzing": t.analyzing,
            "stageScanning": t.stageScanning,
            "stageParsing": t.stageParsing,
            "stageResolving": t.stageResolving,
            "noSourceFiles": t.noSourceFiles,
            "files": t.files,
            "lines": t.lines,
            "symbols": t.symbols,
            "hubsHint": t.hubsHint,
            "unreachableHint": t.unreachableHint,
            "search": t.search,
            "searchPlaceholder": t.searchPlaceholder,
            "noResults": t.noResults,
            "callers": t.callers,
            "callees": t.callees,
            "definedIn": t.definedIn,
            "kind": t.kind,
            "noCallers": t.noCallers,
            "noCallees": t.noCallees,
            "openInEditor": t.openInEditor,
            "whatThisDoes": t.whatThisDoes,
            "explainThis": t.explainThis,
            "thinking": t.thinking,
            "theFacts": t.theFacts,
            "pickSomething": t.pickSomething,
            "onDeviceNote": t.onDeviceNote,
            "englishFallbackNote": t.englishFallbackNote,
            "aiOffTitle": t.aiOffTitle,
            "aiOffNeedsEnable": t.aiOffNeedsEnable,
            "aiOffDownloading": t.aiOffDownloading,
            "aiOffIneligible": t.aiOffIneligible,
            "aiOffOldOS": t.aiOffOldOS,
            "openSettings": t.openSettings,
            "codeMenu": t.codeMenu,
            "projectIs": t.projectIs,
            "routeHint": t.routeHint,
            "routeEmpty": t.routeEmpty,
            "youAreHere": t.youAreHere,
            "stepWord": t.stepWord,
            "nextStepLabel": t.nextStepLabel,
            "prevStepLabel": t.prevStepLabel,
            "backToOverview": t.backToOverview,
            "routeLabel": t.routeLabel,
            "everythingElse": t.everythingElse,
            "askQuestion": t.askQuestion,
            "questionWhoCalls": t.questionWhoCalls,
            "questionWhyExists": t.questionWhyExists,
            "questionWhatBreaks": t.questionWhatBreaks,
            "questionSimpler": t.questionSimpler,
            "cycles": t.cycles,
            "showTests": t.showTests,
            "architectureHint": t.architectureHint,
            "issuesTitle": t.issuesTitle,
            "issuesHint": t.issuesHint,
            "issuesNone": t.issuesNone,
            "previewBadge": t.previewBadge,
            "widgetNeedsSigning": t.widgetNeedsSigning,
            "tabOverview": t.tabOverview,
            "tabMap": t.tabMap,
            "tabRead": t.tabRead,
            "tabReview": t.tabReview,
            "tabOverviewHint": t.tabOverviewHint,
            "tabMapHint": t.tabMapHint,
            "shapeOfIt": t.shapeOfIt,
            "callEdges": t.callEdges,
            "districts": t.districts,
            "districtInterface": t.districtInterface,
            "districtLogic": t.districtLogic,
            "districtData": t.districtData,
            "everyFigure": t.everyFigure,
            "startHereBlurb": t.startHereBlurb,
            "readArrow": t.readArrow,
            "viewLadder": t.viewLadder,
            "viewMatrix": t.viewMatrix,
            "backward": t.backward,
            "driftTitle": t.driftTitle,
            "driftNone": t.driftNone,
            "driftFirst": t.driftFirst,
            "callChain": t.callChain,
            "callChainHint": t.callChainHint,
            "blastTitle": t.blastTitle,
            "hops": t.hops,
            "ladderTitle": t.ladderTitle,
            "ladderHint": t.ladderHint,
            "columnEntry": t.columnEntry,
            "columnFoundation": t.columnFoundation,
            "reachesSelection": t.reachesSelection,
            "selectionReaches": t.selectionReaches,
            "clickAnyFile": t.clickAnyFile,
            "matrixCallsKey": t.matrixCallsKey,
            "matrixCycleKey": t.matrixCycleKey,
            "matrixSelfKey": t.matrixSelfKey,
            "matrixTitle": t.matrixTitle,
            "matrixHint": t.matrixHint,
            "selectedRow": t.selectedRow,
            "matrixFooter": t.matrixFooter,
            "howHard": t.howHard,
            "difficultyEasy": t.difficultyEasy,
            "difficultyModerate": t.difficultyModerate,
            "difficultyHard": t.difficultyHard,
            "glossary": t.glossary,
            "glossaryHint": t.glossaryHint,
            "understood": t.understood,
            "understoodMark": t.understoodMark,
            "readingProgress": t.readingProgress,
            "goBack": t.goBack,
            "goForward": t.goForward,
            "startHere": t.startHere,
            "startHereHint": t.startHereHint,
            "fitToScreen": t.fitToScreen,
            "zoomIn": t.zoomIn,
            "zoomOut": t.zoomOut,
            "settings": t.settings,
            "interfaceLanguage": t.interfaceLanguage,
            "openProject": t.openProject,
            "reanalyze": t.reanalyze,
            "close": t.close,
            "notifications": t.notifications,
            "notifyOnFinish": t.notifyOnFinish,
            "notifDoneTitle": t.notifDoneTitle,
            "widgetName": t.widgetName,
            "widgetDescription": t.widgetDescription,
            "widgetEmpty": t.widgetEmpty,
            "widgetTopHub": t.widgetTopHub,
        ]) { template, _ in template }
    }

    /// Strings that take a value, exported with `{0}` where it goes.
    ///
    /// Produced by asking `L10n` for the real sentence with a sentinel in it
    /// and putting the placeholder back, rather than writing the templates out
    /// here. A client that composed its own sentence would drift from the
    /// macOS wording the first time either was edited, and word order is not
    /// the same in both languages — "reaches 12" against "12 taga yetadi".
    private static func templates(_ t: L10n) -> [String: String] {
        let marker = 918_273_645
        var out = [
            "reaches": t.reaches(marker)
                .replacingOccurrences(of: "\(marker)", with: "{0}"),
            "columnDepth": t.columnDepth(marker)
                .replacingOccurrences(of: "\(marker)", with: "{0}"),
        ]

        // `driftSince` renders a date, so the sentinel is a date and the
        // placeholder replaces however this language chose to write it.
        let date = Date(timeIntervalSince1970: 0)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: t.language == .uz ? "uz" : "en_US")
        formatter.dateFormat = "d MMM"
        out["driftSince"] = t.driftSince(date)
            .replacingOccurrences(of: formatter.string(from: date), with: "{0}")

        return out
    }
}
