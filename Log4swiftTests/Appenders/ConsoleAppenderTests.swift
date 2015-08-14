//
//  StdOutAppender.swift
//  Log4swift
//
//  Created by Jérôme Duquennoy on 16/06/2015.
//  Copyright © 2015 Jérôme Duquennoy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import XCTest
@testable import Log4swift

class StdOutAppenderTests: XCTestCase {
  let savedStdout = dup(fileno(stdout));
  let savedStderr = dup(fileno(stderr));
  var stdoutReadFileHandle = NSFileHandle();
  var stderrReadFileHandle = NSFileHandle();
  
  override func setUp() {
    super.setUp()
    
    // Capture stdout and stderr
    
    let stdoutPipe = NSPipe();
    self.stdoutReadFileHandle = stdoutPipe.fileHandleForReading;
    dup2(stdoutPipe.fileHandleForWriting.fileDescriptor, fileno(stdout));
    
    let stderrPipe = NSPipe();
    self.stderrReadFileHandle = stderrPipe.fileHandleForReading;
    dup2(stderrPipe.fileHandleForWriting.fileDescriptor, fileno(stderr));
  }
  
  override func tearDown() {
    dup2(self.savedStdout, fileno(stdout));
    dup2(self.savedStderr, fileno(stderr));
  }
  
  func testStdOutAppenderDefaultErrorThresholdIsError() {
    let appender = StdOutAppender("appender");
    
    // Validate
    if let errorThreshold = appender.errorThresholdLevel {
      XCTAssertEqual(errorThreshold, LogLevel.Error);
    } else {
      XCTFail("Default error threshold is not defined");
    }
  }
  
  func testStdOutAppenderWritesLogToStdoutWithALineFeedIfErrorThresholdIsNotDefined() {
    let appender = StdOutAppender("appender");
    
    // Execute
    appender.log("log value", level: .Info, info: LogInfoDictionary());
    
    // Validate
    if let stdoutContent = getFileHandleContentAsString(self.stdoutReadFileHandle) {
      XCTAssertEqual(stdoutContent, "log value\n");
    }
  }
  
  func testStdOutAppenderWritesLogToStdoutWithALineFeedIfErrorThresholdIsNotReached() {
    let appender = StdOutAppender("appender");
    appender.errorThresholdLevel = .Warning;
    
    // Execute
    appender.log("log value", level: .Info, info: LogInfoDictionary());
    
    // Validate
    if let stdoutContent = getFileHandleContentAsString(self.stdoutReadFileHandle) {
      XCTAssertEqual(stdoutContent, "log value\n");
    }
  }
  
  func testStdOutAppenderWritesLogToStderrWithALineFeedIfErrorThresholdIsReached() {
    let appender = StdOutAppender("appender");
    appender.errorThresholdLevel = .Warning;
    
    // Execute
    appender.log("log value", level: .Warning, info: LogInfoDictionary());
    
    // Validate
    if let stderrContent = getFileHandleContentAsString(self.stderrReadFileHandle) {
      XCTAssertEqual(stderrContent, "log value\n");
    }
  }
  
  func testUpdatingAppenderFromDictionaryWithNoThresholdDoesNotChangeIt() {
    let dictionary = [LoggerFactory.DictionaryKey.Identifier.rawValue: "testAppender"];
    let appender = StdOutAppender("test appender");
    appender.thresholdLevel = .Info;
    
    // Execute
    try! appender.updateWithDictionary(dictionary, availableFormatters: []);
    
    // Validate
    XCTAssertEqual(appender.thresholdLevel, LogLevel.Info);
  }

  func testUpdatingAppenderFromDictionaryWithInvalidThresholdThrowsError() {
    let dictionary = [LoggerFactory.DictionaryKey.Identifier.rawValue: "testAppender",
      StdOutAppender.DictionaryKey.ThresholdLevel.rawValue: "invalid level"];
    let appender = StdOutAppender("test appender");

    // Execute & validate
    XCTAssertThrows { try appender.updateWithDictionary(dictionary, availableFormatters: []) };
  }
  
  func testUpdatingAppenderFromDictionaryWithThresholdUsesSpecifiedValue() {
    let dictionary = [LoggerFactory.DictionaryKey.Identifier.rawValue: "testAppender",
      StdOutAppender.DictionaryKey.ThresholdLevel.rawValue: LogLevel.Info.description];
    let appender = StdOutAppender("test appender");
    appender.thresholdLevel = .Debug;
    
    // Execute
    try! appender.updateWithDictionary(dictionary, availableFormatters:[]);
    
    // Validate
    XCTAssertEqual(appender.thresholdLevel, LogLevel.Info);
  }
  
  func testUpdatingAppenderFromDictionaryWithNoErrorThresholdUsesNilErrorThresholdByDefault() {
    let dictionary = [LoggerFactory.DictionaryKey.Identifier.rawValue: "testAppender"];
    let appender = StdOutAppender("test appender");
    appender.errorThresholdLevel = .Debug;

    // Execute
    try! appender.updateWithDictionary(dictionary, availableFormatters: []);
    
    // Validate
    XCTAssert(appender.errorThresholdLevel == nil);
  }
  
  func testUpdatingAppenderFromDictionaryWithInvalidErrorThresholdThrowsError() {
    let dictionary = [LoggerFactory.DictionaryKey.Identifier.rawValue: "testAppender",
      StdOutAppender.DictionaryKey.ErrorThreshold.rawValue: "invalid level"];
    let appender = StdOutAppender("test appender");
    
    // Execute & validate
    XCTAssertThrows { try appender.updateWithDictionary(dictionary, availableFormatters: []) };
  }
  
  func testUpdatingAppenderFromDictionaryWithErrorThresholdUsesSpecifiedValue() {
    let dictionary = [LoggerFactory.DictionaryKey.Identifier.rawValue: "testAppender",
      StdOutAppender.DictionaryKey.ErrorThreshold.rawValue: LogLevel.Info.description];
    let appender = StdOutAppender("test appender");
    appender.errorThresholdLevel = .Info;
    
    // Execute
    try! appender.updateWithDictionary(dictionary, availableFormatters: []);
    
    // Validate
    XCTAssertEqual(appender.errorThresholdLevel!, LogLevel.Info);
  }
  
  func testUpdatingAppenderFomDictionaryWithNonExistingFormatterIdThrowsError() {
    let dictionary = [LoggerFactory.DictionaryKey.Identifier.rawValue: "testAppender",
      Appender.DictionaryKey.FormatterId.rawValue: "not existing id"];
    let appender = StdOutAppender("test appender");
    
    XCTAssertThrows { try appender.updateWithDictionary(dictionary, availableFormatters: []) };
  }
  
  func testUpdatingAppenderFomDictionaryWithExistingFormatterIdUsesIt() {
    let formatter = try! PatternFormatter(identifier: "formatterId", pattern: "test pattern");
    let dictionary = [LoggerFactory.DictionaryKey.Identifier.rawValue: "testAppender",
      Appender.DictionaryKey.FormatterId.rawValue: "formatterId"];
    let appender = StdOutAppender("test appender");
    
    // Execute
    try! appender.updateWithDictionary(dictionary, availableFormatters: [formatter]);
    
    // Validate
    XCTAssertEqual((appender.formatter?.identifier)!, formatter.identifier);
  }
  
  private func getFileHandleContentAsString(fileHandle: NSFileHandle) -> String? {
    let expectation = expectationWithDescription("filHandle content received");
    var stringContent: String?;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
      let data = fileHandle.availableData;
      stringContent = NSString(data: data, encoding: NSUTF8StringEncoding) as? String;
      
      expectation.fulfill();
    }
    
    waitForExpectationsWithTimeout(1, handler: nil);
    return stringContent;
  }
}
