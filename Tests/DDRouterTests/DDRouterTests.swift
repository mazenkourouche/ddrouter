import XCTest
import Combine

@testable import DDRouter

//import RxTest
//import RxBlocking

struct TestErrorModel: APIErrorModelProtocol {}

class DDRouterTests: XCTestCase {

    var router: Router<TestEndpoint, TestErrorModel>?

    override func setUp() {
        self.router = Router<TestEndpoint, TestErrorModel>()
    }

    override func tearDown() {
        self.router = nil
    }

    // todo: tests for all the failure cases
    func testSuccess() {
        guard
            let response: ResponseModel = try? self.router?.request(.random)
                .toBlockingResult(timeout: 5)
                .get()
                .first
        else {
            XCTFail()
            return
        }

        XCTAssert(response.author.count > 0)
        XCTAssert(response.en.count > 0)
    }
}
