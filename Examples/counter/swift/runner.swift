import FlutterSwift

@main
struct Counter {
    static func main() {
        guard CommandLine.arguments.count > 1 else {
            print("usage: Counter [flutter_path]")
            exit(1)
        }
        let dartProject = DartProject(path: CommandLine.arguments[1])
        let viewProperties = FlutterViewController.ViewProperties(
            width: 640,
            height: 480,
            title: "Counter",
            appId: "com.padl.counter")
        let window = FlutterWindow(properties: viewProperties, project: dartProject)
        guard let window else {
            debugPrint("failed to initialize window!")
            exit(2)
        }
        window.run()
    }
}
