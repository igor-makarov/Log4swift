# Log4Swift
[![License](https://img.shields.io/badge/License-LGPLv3-blue.svg
            )](http://mit-license.org) [![Platform](http://img.shields.io/badge/platform-osx-lightgrey.svg?style=flat
             )](https://developer.apple.com/resources/) [![Language](http://img.shields.io/badge/language-swift2-orange.svg?style=flat
             )](https://developer.apple.com/swift) [![Cocoapod](http://img.shields.io/cocoapods/v/Log4swift.svg?style=flat)](http://cocoadocs.org/docsets/Log4swift/)

Log4Swift is a logging library written in swift 2. Therefore, **it requires xCode 7 to compile**.

Despite being written in swift2, Log4swift can be used in Objective-c base projects, as well as mixed projects.

It is available as a cocoaPod for easy integration in your projects.

## Goal
The goal of this project is to propose a logging library with those caracteristics :

* straitforward to use for simple cases : default configuration should just work
* powerful for more complexe cases, with multi-destination logging for exemple
* ability to log over the network, and notably to NSLogger.
* dynamically configurable by code
* configurable by file

### Not yet achieved goals
* synchronous by default, but with the ability to request asynchronous behavior
* should be useable on linux once Apple releases Swift for that OS

Another goal, that I think we all share, is to have readable and tested code.

* The code coverage of Log4swift's code (excluding third party code) is 100% for most of the source files, and very close to it for others.
* Feel free to send feedbacks if you find the code not readable enough, or if you have ideas to highen the quality of that code !

## Concepts
The three main concepts of this library are borrowed from log4j :

### Loggers
Loggers are the objects to which logs are send at the first place.
They are identified by a UTI identifier (like "project.module.function") that are hierachical. When a log message is sent, the logger with the longest matching UTI will be responsible for dealing the log.
A root logger will deal with logs that matches no specific logger.

A logger defines a threshold level. Logs bellow this level will be ignored. Non ignored levels are sent to the appenders associated to the logger.

### Appenders
Appenders are attached to loggers. They are responsible for writing the logs to their destination. They are identified by an identifier, that is used when loading configuration to attache appenders to their loggers. One appender might be attached to multiple loggers.

Appenders also have a threshold to filter out messages.

### Formatters
Formatters are attached to appenders. Their job is to modify the message to apply it a specific formatting before it is sent to its final destination. One formatter might be attached to multiple appenders.

## Features
### Mutliple appenders per logger
One logger can have multiple appenders. You can for exemple define a logger that will log everything to the console, but that will also send error messages to a file for latter use.

```
let logger = Logger.getLogger("test.logger");
let consoleAppender = ConsoleAppender(identifier: "console");
let fileAppender = try FileAppender(identifier: "errorFile", filePath: "/var/log/error.log");

consoleAppender.thresholdLevel = .debug;
fileAppender.thresholdLevel = .error;
logger.appenders = [consoleAppender, fileAppender];

logger.debug ("This message will go to the console");
logger.error ("This message will go to the console and the error log file");
```

### Formatters associated to appenders
Formatters allows you to apply a specific formatting to your log message, either modifying the message to have it complying to some constraintes or adding information to the logged message.  

### Log with closures
Providing a closure instead of a string is pretty handy if the code that generates the message is heavy : the closure will only be executed if the logs are to be issued. No need to encapsulate the code in an if structure.

```
Logger.debug { someHeavyCodeThatGeneratesTheLogMessage() }
```

### Flexible configuration
Configuration of the logging system can be loaded from a file, or done in software.

In software, you can configure it using a dictionary, that you can then store and load from anywhere you want (a web service, a database, a preference file, ...).

Configuration can be modified any time while running.

## Provided appenders

### The stdout appender
This appender will write log messages to stdout or stderr. It has two thresholds : the regular threshold, available on all appenders, and an error threshold.

* If the log level is bellow the general threshold, the message is ignored
* If the log level is above the general threshold but bellow the error threshold, the message is issued on stdout
* If the log level is above both the general and the error threshold, the message is issued on stderr

By default, the stdout appender is configured to send Error and Fatal messages to stderr, and all other levers to stdout.

This appender is a good choice for CLI tools.

### The file appender
This appender will write log messages to a file, specified by its path. It will create the file if needed (and possible), and will re-create it if it disapears. This allows log rotation scripts to avoid having to restart the process to ensure logs are recorded in a new file after rotation.

### The NSLogger appender
This appender uses NSLogger (https://github.com/fpillet/NSLogger) to send log messages over the network.
Not all capabilities of NSLogger are accessibles yet : only text messages can be logged.

### The ASL Appender
The ASL appender sends log messages to the system logging service, provided by Apple. Your messages will we visible in the Console.app application if the ASL configuration has not been customized.

This appender is a good choice for release versions of softwares.

## Provided formatters

### The PatternFormatter

The PatternFormatter uses a simple textual pattern with marker identified by a '%' prefix to render the log messages. it provides those markers :

* l : The log level (identified by its name)
* n : The name of the logger
* d : The date of the log
* m : The message
* % : The '%' character

This pattern :  
```
[%d][%l][%n] %m
```  
will produce this kind of log:  
```
[2015-02-02 12:45:23 +0000][Debug][logger.name] The message that was sent to the logger
```
