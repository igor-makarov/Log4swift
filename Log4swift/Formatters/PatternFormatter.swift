//
//  PatternFormatter.swift
//  Log4swift
//
//  Created by Jérôme Duquennoy on 18/06/2015.
//  Copyright © 2015 Jérôme Duquennoy. All rights reserved.
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

/**
The PatternFormatter will format the message according to a given pattern.
The pattern is a regular string, with markers prefixed by '%', that might be passed options encapsulated in '{}'.
Use '%%' to print a '%' character in the formatted message.
Available markers are :
* l : The name of the log level
* n : The name of the logger
* d : The date of the log
* m : the message
* % : the '%' character

**Exemples**  
"[%p] %m" -> "[Debug] log message"
*/
public class PatternFormatter : Formatter {
  /// Definition of errors the PatternFormatter can throw
  public enum Error : ErrorType {
    case InvalidFormatSyntax
    case NotClosedMarkerParameter
  };
  
  /// Definition of the keys that will be used when initializing a PatternFormatter with a dictionary.
  public enum DictionaryKey: String {
    case Identifier = "Identifier"
    case Pattern = "Pattern"
  };
  
  public let identifier: String;
  
  typealias FormattingClosure = (message: String, infos: FormatterInfoDictionary) -> String;
  private var formattingClosuresSequence = [FormattingClosure]();
  
  /// This initialiser will throw an error if the pattern is not valid.
  public init(identifier: String, pattern: String) throws {
    self.identifier = identifier;
    let parser = PatternParser();
    self.formattingClosuresSequence = try parser.parsePattern(pattern);
  }

  /// This initialiser will create a PatternFormatter with the informations provided as a dictionnary.  
  /// It will throw an error if a mandatory parameter is missing of if the pattern is invalid.
  public convenience required init(dictionary: Dictionary<String, AnyObject>) throws {
    
    let identifier: String;
    let pattern: String;
    var errorToThrow: ErrorType?;
    
    if let safeIdentifier = (dictionary[DictionaryKey.Identifier.rawValue] as? String) {
      identifier = safeIdentifier;
    } else {
      identifier = "placeholder";
      errorToThrow = Log4swift.Error.InvalidOrMissingParameterException(parameterName: DictionaryKey.Identifier.rawValue);
    }
    
    if let safePattern = (dictionary[DictionaryKey.Pattern.rawValue] as? String) {
      pattern = safePattern;
    } else {
      pattern = "placeholder";
      errorToThrow = Log4swift.Error.InvalidOrMissingParameterException(parameterName: DictionaryKey.Pattern.rawValue);
    }

    try self.init(identifier: identifier, pattern: pattern);
    
    if let errorToThrow = errorToThrow {
      throw errorToThrow;
    }
  }
  
  public func format(message: String, info: FormatterInfoDictionary) -> String {
    return formattingClosuresSequence.reduce("") { (accumulatedValue, currentItem) in accumulatedValue + currentItem(message: message, infos: info) };
  }
  
  private class PatternParser {
    typealias MarkerClosure = (parameters: String?, message: String, info: FormatterInfoDictionary) -> String;
    // This dictionary matches a markers (one letter) with its logic (the closure that will return the value of the marker.  
    // Add an entry to this array to declare a new marker.
    private let markerClosures : Dictionary<String, MarkerClosure> = [
      "d": {(parameters, message, info) in NSDate().description },
      "l": {(parameters, message, info) in
        if let logLevel = info[.LogLevel] {
          return logLevel.description
        } else {
          return "-";
        }
      },
      "n": {(parameters, message, info) in 
        if let loggerName = info[.LoggerName] {
          return loggerName.description;
        } else {
          return "-";
        }
      },
      "m": {(parameters, message, infos) in message },
      "%": {(parameters, message, infos) in return "%" }
    ];
    
    
    // MARK: Formater parser state machine
    // This machine has two main methods :
    // - parsePattern : the main loop, that iterates on the characters of the pattern
    // - setParserState : the method that applies the logic when switching from one state to another.
    private enum ParserState {
      case Text
      case Marker
      case PostMarker(String)
      case Parameters(String)
      case End
    };
    
    private struct ParserStatus {
      var machineState = ParserState.Text;
      var charactersAccumulator = [Character]();
    };
    
    private var parserStatus = ParserStatus();
    private var parsedClosuresSequence = [FormattingClosure]();
    
    // Converts a textual pattern into a sequence of closure that can be executed to render a messaage.
    private func parsePattern(pattern: String) throws -> [FormattingClosure] {
      parsedClosuresSequence = [FormattingClosure]();
      
      for currentCharacter in pattern.characters
      {
        switch(parserStatus.machineState) {
        case .Text where currentCharacter == "%":
          try setParserState(.Marker);
        case .Text:
          parserStatus.charactersAccumulator.append(currentCharacter);
          
        case .Marker:
          try setParserState(.PostMarker(String(currentCharacter)));
          
        case .PostMarker(let markerName) where currentCharacter == "{":
          try setParserState(.Parameters(markerName));
        case .PostMarker:
          try setParserState(.Text);
          parserStatus.charactersAccumulator.append(currentCharacter);
          
        case .Parameters where currentCharacter == "}":
          try setParserState(.Text);
        case .Parameters:
          parserStatus.charactersAccumulator.append(currentCharacter);
        case .End:
          throw Error.InvalidFormatSyntax;
        }
      }
      try setParserState(.End);
      
      return parsedClosuresSequence;
    }
    
    private func setParserState(newState: ParserState) throws {
      switch(parserStatus.machineState) {
      case .Text where parserStatus.charactersAccumulator.count > 0:
        let parsedString = String(parserStatus.charactersAccumulator);
        if(!parsedString.isEmpty) {
          parsedClosuresSequence.append({(_, _ ) in return parsedString});
          parserStatus.charactersAccumulator.removeAll();
        }
      case .PostMarker(let markerName):
        switch(newState) {
        case .Text, .End:
          parserStatus.charactersAccumulator.removeAll();
          processMarker(markerName);
        case .Parameters:
          break;
        default:
          break;
        }
        
      case .Parameters(let markerName):
        switch(newState) {
        case .End:
          throw Error.NotClosedMarkerParameter;
        default:
          processMarker(markerName);
          parserStatus.charactersAccumulator.removeAll();
        }
      default:
        break;
      }
      parserStatus.machineState = newState;
    }
    
    private func processMarker(markerName: String, parameters: String? = nil) {
      if let closureForMarker = markerClosures[markerName] {
        parsedClosuresSequence.append({(message, info) in closureForMarker(parameters: parameters, message: message, info: info) });
      } else {
        parserStatus.charactersAccumulator += "%\(markerName)".characters;
      }
    }
  }
}