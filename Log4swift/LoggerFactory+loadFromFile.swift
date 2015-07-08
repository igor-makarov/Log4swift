//
//  LoggerFactory+loadFromFile.swift
//  Log4swift
//
//  Created by Jérôme Duquennoy on 03/07/2015.
//  Copyright © 2015 jerome. All rights reserved.
//
// Log4swift is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Log4swift is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Foobar. If not, see <http://www.gnu.org/licenses/>.
//

import Foundation

extension LoggerFactory {
  public enum DictionaryKey: String {
    case ClassName = "Class"
    case Formatters = "Formatters"
    case Appenders = "Appenders"
    case Loggers = "Loggers"
    case RootLogger = "RootLogger"
    case Identifier = "Identifier"
  };
  
  public func readConfigurationFromPlistFile(filePath: String) throws {
    let configurationNSDictionary = NSDictionary(contentsOfFile: filePath);
    if let configurationNSDictionary = configurationNSDictionary {
      let configurationDictionary = configurationNSDictionary as! Dictionary<String, AnyObject>
      try self.readConfiguration(configurationDictionary);
    }
  }
  
  /// Reads a whole configuration from the given dictionary.
  /// **Warning:** This will destroy all current loggers and appenders, replacing them by those found in that configuration.
  public func readConfiguration(configurationDictionary: Dictionary<String, AnyObject>) throws {
    try self.readConfigurationToTupple(configurationDictionary);
  }
  
  // This internal method returns all created objects in a tupple, to make testing easier.
  // The public version does not return a tupple, an thus is compatible with Objective-C.
  internal func readConfigurationToTupple(configurationDictionary: Dictionary<String, AnyObject>) throws -> (Array<Formatter>, Array<Appender>, Array<Logger>) {
    var formatters = Array<Formatter>();
    var appenders = Array<Appender>();
    var loggers = Array<Logger>();
    
    // Formatters
    if let formattersArray = configurationDictionary[DictionaryKey.Formatters.rawValue] as? Array<Dictionary<String, AnyObject>> {
      for currentFormatterDefinition in formattersArray {
        let formatter = try processFormatterDictionary(currentFormatterDefinition);
        formatters.append(formatter);
      }
    }
    
    // Appenders
    if let appendersArray = configurationDictionary[DictionaryKey.Appenders.rawValue] as? Array<Dictionary<String, AnyObject>> {
      for currentAppenderDefinition in appendersArray {
        let appender = try processAppenderDictionary(currentAppenderDefinition, formatters: formatters);
        appenders.append(appender);
      }
    }
    
    // Loggers
    if let loggersArray = configurationDictionary[DictionaryKey.Loggers.rawValue] as? Array<Dictionary<String, AnyObject>> {
      for currentLoggerDefinition in loggersArray {
        if let logger = try processLoggerDictionary(currentLoggerDefinition, appenders: appenders) {
          loggers.append(logger);
          try registerLogger(logger);
        }
      }
    }
    
    // Root logger
    if let rootLoggerDictionary = configurationDictionary[DictionaryKey.RootLogger.rawValue] as? Dictionary<String, AnyObject> {
      try self.rootLogger.updateWithDictionary(rootLoggerDictionary, availableAppenders: appenders);
    }
    
    return (formatters, appenders, loggers);
  }
  
  private func processFormatterDictionary(dictionary: Dictionary<String, AnyObject>) throws -> Formatter {
    let identifier = try identifierFromConfigurationDictionary(dictionary);
    let formatter: Formatter;
    if let className = dictionary[DictionaryKey.ClassName.rawValue] as? String {
      if let formatterType = formatterForClassName(className) {
        formatter = formatterType.init(identifier);
        try formatter.updateWithDictionary(dictionary);
      } else {
        throw Log4swift.Error.InvalidOrMissingParameterException(parameterName: DictionaryKey.ClassName.rawValue)
      }
    } else {
      throw Log4swift.Error.InvalidOrMissingParameterException(parameterName: DictionaryKey.ClassName.rawValue)
    }
    
    return formatter;
  }
  
  private func formatterForClassName(className: String) -> Formatter.Type? {
    let type: Formatter.Type?;
    switch(className) {
    case "PatternFormatter":
      type = PatternFormatter.self;
    default:
      type = nil;
    }
    return type;
  }

  private func processAppenderDictionary(dictionary: Dictionary<String, AnyObject>, formatters: Array<Formatter>) throws -> Appender {
    let identifier = try identifierFromConfigurationDictionary(dictionary);
    let appender: Appender;
    if let className = dictionary[DictionaryKey.ClassName.rawValue] as? String {
      if let appenderType = appenderForClassName(className) {
        appender = appenderType.init(identifier);
        try appender.updateWithDictionary(dictionary, availableFormatters: formatters);
      } else {
        throw Log4swift.Error.InvalidOrMissingParameterException(parameterName: DictionaryKey.ClassName.rawValue)
      }
    } else {
      throw Log4swift.Error.InvalidOrMissingParameterException(parameterName: DictionaryKey.ClassName.rawValue)
    }
    
    return appender;
  }
  
  private func appenderForClassName(className: String) -> Appender.Type? {
    let type: Appender.Type?;
    switch(className) {
    case "ConsoleAppender":
      type = ConsoleAppender.self;
    case "FileAppender":
      type = FileAppender.self;
    case "NSLoggerAppender":
      type = NSLoggerAppender.self;
    default:
      type = nil;
    }
    return type;
  }

  private func processLoggerDictionary(dictionary: Dictionary<String, AnyObject>, appenders: Array<Appender>) throws -> Logger? {
    let identifier = try identifierFromConfigurationDictionary(dictionary);
    let logger: Logger;
    
    if let existingLogger = loggers[identifier] {
      logger = existingLogger;
    } else {
      logger = Logger(identifier: identifier);
    }

    try logger.updateWithDictionary(dictionary, availableAppenders: appenders);
    
    return logger;
  }
  
  private func identifierFromConfigurationDictionary(configurationDictionary: Dictionary<String, AnyObject>) throws -> String {
    let identifier: String;
    if let safeIdentifier = configurationDictionary[DictionaryKey.Identifier.rawValue] as? String {
      if(safeIdentifier.isEmpty) {
        throw Log4swift.Error.InvalidOrMissingParameterException(parameterName: DictionaryKey.Identifier.rawValue);
      }
      identifier = safeIdentifier;
    } else {
      throw Log4swift.Error.InvalidOrMissingParameterException(parameterName: DictionaryKey.Identifier.rawValue);
    }
    
    return identifier
  }
}