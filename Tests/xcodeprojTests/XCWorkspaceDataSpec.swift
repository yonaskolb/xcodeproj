import Foundation
import XCTest
import PathKit
import xcodeproj

final class XCWorkspaceDataSpec: XCTestCase {

    var subject: XCWorkspace.Data!
    var fileRef: XCWorkspace.Data.FileRef!
    
    override func setUp() {
        super.setUp()
        fileRef = "path"
        subject = XCWorkspace.Data(references: [])
    }
    
    
    func test_equal_returnsTheCorrectValue() {
        let another = XCWorkspace.Data(references: [])
        XCTAssertEqual(subject, another)
    }
    
    func test_addingReference_returnsANewWorkspaceDatawithTheReferenceAdded() {
        let got = subject.adding(reference: "path2")
        XCTAssertTrue(got.references.contains("path2"))
    }
    
    func test_removingReference_returnsANewWorkspaceDataWithTheReferenceRemoved() {
        let got = subject.removing(reference: "path")
        XCTAssertFalse(got.references.contains("path"))
    }
    
}

final class XCWorkspaceDataIntegrationSpec: XCTestCase {
    
    func test_init_returnsTheModelWithTheRightProperties() {
        let path = fixturePath()
        let got = try? XCWorkspace.Data(path: path)
        XCTAssertNotNil(got?.references.first?.project)
    }
    
    func test_init_throwsIfThePathIsWrong() {
        do {
            _ = try XCWorkspace.Data(path: Path("test"))
            XCTAssertTrue(false, "Expected to throw an error but it didn't")
        } catch {}
    }
    
    func test_write() {
        testWrite(from: fixturePath(),
                  initModel: { try? XCWorkspace.Data(path: $0) },
                  modify: { return $0.adding(reference: .file(path: "shakira")) }) { (before, after) in
                    XCTAssertTrue(after.references.filter{ $0.description.contains("shakira")}.count == 1)
        }
    }
    
    // MARK: - Private
    
    private func fixturePath() -> Path {
        return fixturesPath() + Path("iOS/Project.xcodeproj/project.xcworkspace/contents.xcworkspacedata")
    }
    
}
