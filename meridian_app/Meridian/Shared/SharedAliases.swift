import Foundation

/// Bridges a naming split introduced while merging the three apps.
///
/// Care, Hub and Family each used to declare their own copies of these enums,
/// identical in cases and raw values. Merging into one target made that a
/// redeclaration, so Hub and Family dropped theirs and Care's became the
/// single definition — but Care also had to prefix its copies (`CareIncident…`)
/// to avoid colliding with the *other* types the siblings kept.
///
/// The result is that Hub and Family reference the unprefixed names while the
/// only surviving declaration is prefixed. Aliasing is the right fix rather
/// than a find-and-replace across ~20 files: it keeps each interface reading
/// in its own vocabulary, and it means the day these genuinely need to
/// diverge, only this file has to change.
///
/// These are aliases, NOT new types — `CareIncidentStatus.open` and
/// `IncidentStatus.open` are the same value, so a row decoded by Family and a
/// row decoded by Care remain directly comparable.
typealias IncidentEventType = CareIncidentEventType
typealias IncidentSeverity = CareIncidentSeverity
typealias IncidentStatus = CareIncidentStatus
typealias AssistanceSource = CareAssistanceSource
typealias AssistanceStatus = CareAssistanceStatus
