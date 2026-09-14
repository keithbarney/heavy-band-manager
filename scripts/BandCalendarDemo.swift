// Standalone screenshot helper; never include in the production app target.
#if targetEnvironment(simulator)
import UIKit
import EventKit
final class AppDelegate: UIResponder, UIApplicationDelegate {
 var window: UIWindow?
 let store = EKEventStore()
 func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
  window = UIWindow(frame: UIScreen.main.bounds)
  let controller = UIViewController(); controller.view.backgroundColor = .white
  window?.rootViewController = controller; window?.makeKeyAndVisible()
  Task { @MainActor in
   do {
    guard try await store.requestFullAccessToEvents() else { throw NSError(domain:"Permission",code:1) }
    guard let local = store.sources.first(where: {$0.sourceType == .local}) else { throw NSError(domain:"No local source; refusing cloud writes",code:1) }
    let calendar = store.calendars(for: .event).first(where: {$0.title == "Band Practice" && $0.source.sourceIdentifier == local.sourceIdentifier}) ?? EKCalendar(for: .event, eventStore: store)
    calendar.title = "Band Practice"; calendar.source = local
    calendar.cgColor = UIColor.systemBlue.cgColor
    try store.saveCalendar(calendar, commit:true)
    let base = Calendar.current.startOfDay(for: Date())
    for offset in [4, 8, 11] {
     let day = Calendar.current.date(byAdding: .day, value: offset, to: base)!
     let existing = store.events(matching: store.predicateForEvents(withStart: day, end: day.addingTimeInterval(86400), calendars: [calendar]))
     let marker = URL(string: "band-marketing-demo://practice/\(offset)")!
     let e = existing.first(where: { $0.url == marker }) ?? EKEvent(eventStore: store)
     e.calendar = calendar; e.title = ProcessInfo.processInfo.arguments.contains("--minor-threat") ? "Minor Threat Practice" : "The Night Shift Practice"
     e.startDate = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: day)!
     e.endDate = e.startDate.addingTimeInterval(7200)
     e.location = "Studio 4, Riverside Rehearsal Rooms"
     e.url = marker; e.alarms = [EKAlarm(relativeOffset: -1800)]
     try store.save(e, span: .thisEvent, commit: true)
    }
    let proof = "Created/updated three fictional rehearsals in local-only Band Practice calendar; no cloud source used."
    try proof.write(to:FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("result.txt"),atomically:true,encoding:.utf8)
    print(proof)
   } catch { print("FAILED: \(error)") }
  }
  return true
 }
}
UIApplicationMain(CommandLine.argc,CommandLine.unsafeArgv,nil,NSStringFromClass(AppDelegate.self))

#else
#error("Calendar demo helper is Simulator-only")
#endif
