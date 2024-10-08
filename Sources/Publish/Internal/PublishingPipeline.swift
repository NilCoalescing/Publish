/**
*  Publish
*  Copyright (c) John Sundell 2019
*  MIT license, see LICENSE file for details
*/

import Files

#if canImport(Cocoa)
import Cocoa
#endif

internal struct PublishingPipeline<Site: Website> {
    let steps: [PublishingStep<Site>]
    let originFilePath: Path
}

extension PublishingPipeline {
    func execute(
        for site: Site,
        at path: Path?,
        ofKind stepKinds: Set<PublishingStep<Site>.Kind>
    ) async throws -> PublishedWebsite<Site> {

        let folders = try setUpFolders(
            withExplicitRootPath: path,
            shouldEmptyOutputFolder: stepKinds.contains(.generation)
        )
        
        CommandLine.output("Did set up folders", as: .info)


        let steps = self.steps.flatMap { step in
            runnableSteps(ofKind: stepKinds, from: step)
        }
        
        guard let firstStep = steps.first else {
            throw PublishingError(
                infoMessage: """
                \(site.name) has no \(stepKinds) steps.
                """
            )
        }

        var context = PublishingContext(
            site: site,
            folders: folders,
            firstStepName: firstStep.name
        )

        context.generationWillBegin()

        postNotification(named: "WillStart")
        CommandLine.output("Publishing \(site.name) (\(steps.count) steps)", as: .info)

        for (index, step) in steps.enumerated() {
            do {
                let message = "[\(index + 1)/\(steps.count)] \(step.name)"
                CommandLine.output(message, as: .info)
                context.prepareForStep(named: step.name)
                try await step.closure(&context)
            } catch let error as PublishingErrorConvertible {
                throw error.publishingError(forStepNamed: step.name)
            } catch {
                let message = "An unknown error occurred: \(error.localizedDescription)"
                throw PublishingError(infoMessage: message, underlyingError: error)
            }
        }

        CommandLine.output("Successfully published \(site.name)", as: .success)
        postNotification(named: "DidFinish")

        return PublishedWebsite(
            index: context.index,
            sections: context.sections,
            pages: context.pages
        )
    }
}

private extension PublishingPipeline {
    typealias Step = PublishingStep<Site>

    struct RunnableStep {
        let name: String
        let closure: Step.Closure
    }

    func setUpFolders(withExplicitRootPath path: Path?,
                      shouldEmptyOutputFolder: Bool) throws -> Folder.Group {
        
        CommandLine.output("Setting up output folders for path \(path?.string ?? "none")", as: .info)
        let root = try resolveRootFolder(withExplicitPath: path)
        CommandLine.output("Root folder is \(root.path)", as: .info)
        let outputFolderName = "Output"

        if shouldEmptyOutputFolder {
            try? root.subfolder(named: outputFolderName).empty(includingHidden: true)
            CommandLine.output("Did empty output folder is \(outputFolderName)", as: .info)
        }

        do {
            CommandLine.output("Creating root folder structure", as: .info)

            let outputFolder = try root.createSubfolderIfNeeded(
                withName: outputFolderName
            )

            let internalFolder = try root.createSubfolderIfNeeded(
                withName: ".publish"
            )

            let cacheFolder = try internalFolder.createSubfolderIfNeeded(
                withName: "Caches"
            )
            
            CommandLine.output("Created root folder structure", as: .info)

            return Folder.Group(
                root: root,
                output: outputFolder,
                internal: internalFolder,
                caches: cacheFolder
            )
        } catch {
            throw PublishingError(
                path: path,
                infoMessage: "Failed to set up root folder structure"
            )
        }
    }

    func resolveRootFolder(withExplicitPath path: Path?) throws -> Folder {
        if let path = path {
            do {
                return try Folder(path: path.string)
            } catch {
                throw PublishingError(
                    path: path,
                    infoMessage: "Could not find the requested root folder",
                    underlyingError: error
                )
            }
        }
        
        CommandLine.output("No explicit root folder path was provided, using default", as: .info)
        let originFile = try File(path: originFilePath.string)
        return try originFile.resolveSwiftPackageFolder()
    }

    func runnableSteps(ofKind kinds: Set<Step.Kind>, from step: Step) -> [RunnableStep] {
        
        guard step.kind == .system || kinds.contains(step.kind) else { return [] }
        

        switch step.body {
        case .empty:
            return []
        case .group(let steps):
            return steps.flatMap { runnableSteps(ofKind: kinds, from: $0) }
        case .operation(let name, let closure):
            return [RunnableStep(name: name, closure: closure)]
        }
    }

    func postNotification(named name: String) {
        #if canImport(Cocoa)
        let center = DistributedNotificationCenter.default()
        let name = Notification.Name(rawValue: "Publish.\(name)")
        center.post(Notification(name: name))
        #endif
    }
}
