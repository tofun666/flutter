// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:file_testing/file_testing.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/version.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/flutter_manifest.dart';
import 'package:flutter_tools/src/ios/xcodeproj.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:test/fake.dart';

import '../src/common.dart';
import '../src/context.dart';
import '../src/fakes.dart';

void main() {
  group('IosProject', () {
    testWithoutContext('managedDirectory', () {
      final MemoryFileSystem fs = MemoryFileSystem.test();
      final IosProject project = IosProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
      expect(project.managedDirectory.path, 'app_name/ios/Flutter');
    });

    testWithoutContext('module managedDirectory', () {
      final MemoryFileSystem fs = MemoryFileSystem.test();
      final IosProject project = IosProject.fromFlutter(
        FakeFlutterProject(fileSystem: fs, isModule: true),
      );
      expect(project.managedDirectory.path, 'app_name/.ios/Flutter');
    });

    testWithoutContext('ephemeralDirectory', () {
      final MemoryFileSystem fs = MemoryFileSystem.test();
      final IosProject project = IosProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
      expect(project.ephemeralDirectory.path, 'app_name/ios/Flutter/ephemeral');
    });

    testWithoutContext('module ephemeralDirectory', () {
      final MemoryFileSystem fs = MemoryFileSystem.test();
      final IosProject project = IosProject.fromFlutter(
        FakeFlutterProject(fileSystem: fs, isModule: true),
      );
      expect(project.ephemeralDirectory.path, 'app_name/.ios/Flutter/ephemeral');
    });

    testWithoutContext('flutterSwiftPackagesDirectory', () {
      final MemoryFileSystem fs = MemoryFileSystem.test();
      final IosProject project = IosProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
      expect(project.flutterSwiftPackagesDirectory.path, 'app_name/ios/Flutter/ephemeral/Packages');
    });

    testWithoutContext('relativeSwiftPackagesDirectory', () {
      final MemoryFileSystem fs = MemoryFileSystem.test();
      final IosProject project = IosProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
      expect(
        project.relativeSwiftPackagesDirectory.path,
        'app_name/ios/Flutter/ephemeral/Packages/.packages',
      );
    });

    testWithoutContext('flutterPluginSwiftPackageDirectory', () {
      final MemoryFileSystem fs = MemoryFileSystem.test();
      final IosProject project = IosProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
      expect(
        project.flutterPluginSwiftPackageDirectory.path,
        'app_name/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage',
      );
    });

    testWithoutContext('module flutterPluginSwiftPackageDirectory', () {
      final MemoryFileSystem fs = MemoryFileSystem.test();
      final IosProject project = IosProject.fromFlutter(
        FakeFlutterProject(fileSystem: fs, isModule: true),
      );
      expect(
        project.flutterPluginSwiftPackageDirectory.path,
        'app_name/.ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage',
      );
    });

    testWithoutContext('xcodeConfigFor', () {
      final MemoryFileSystem fs = MemoryFileSystem.test();
      final IosProject project = IosProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
      expect(project.xcodeConfigFor('Debug').path, 'app_name/ios/Flutter/Debug.xcconfig');
    });

    testWithoutContext('lldbInitFile', () {
      final MemoryFileSystem fs = MemoryFileSystem.test();
      final IosProject project = IosProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
      expect(project.lldbInitFile.path, 'app_name/ios/Flutter/ephemeral/flutter_lldbinit');
    });

    testWithoutContext('lldbHelperPythonFile', () {
      final MemoryFileSystem fs = MemoryFileSystem.test();
      final IosProject project = IosProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
      expect(
        project.lldbHelperPythonFile.path,
        'app_name/ios/Flutter/ephemeral/flutter_lldb_helper.py',
      );
    });

    group('projectInfo', () {
      testUsingContext(
        'is null if XcodeProjectInterpreter is null',
        () async {
          final MemoryFileSystem fs = MemoryFileSystem.test();
          final IosProject project = IosProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
          project.xcodeProject.createSync(recursive: true);
          expect(await project.projectInfo(), isNull);
        },
        overrides: <Type, Generator>{XcodeProjectInterpreter: () => null},
      );

      testUsingContext(
        'is null if XcodeProjectInterpreter is not installed',
        () async {
          final MemoryFileSystem fs = MemoryFileSystem.test();
          final IosProject project = IosProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
          project.xcodeProject.createSync(recursive: true);
          expect(await project.projectInfo(), isNull);
        },
        overrides: <Type, Generator>{
          XcodeProjectInterpreter: () => FakeXcodeProjectInterpreter(isInstalled: false),
        },
      );

      testUsingContext(
        'is null if xcodeproj does not exist',
        () async {
          final MemoryFileSystem fs = MemoryFileSystem.test();
          final IosProject project = IosProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
          expect(await project.projectInfo(), isNull);
        },
        overrides: <Type, Generator>{XcodeProjectInterpreter: () => FakeXcodeProjectInterpreter()},
      );

      testUsingContext(
        'returns XcodeProjectInfo',
        () async {
          final MemoryFileSystem fs = MemoryFileSystem.test();
          final IosProject project = IosProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
          project.xcodeProject.createSync(recursive: true);
          expect(await project.projectInfo(), isNotNull);
        },
        overrides: <Type, Generator>{XcodeProjectInterpreter: () => FakeXcodeProjectInterpreter()},
      );
    });

    group('usesSwiftPackageManager', () {
      testUsingContext(
        'is true when iOS project exists',
        () async {
          final MemoryFileSystem fs = MemoryFileSystem.test();
          final Directory projectDirectory = fs.directory('path');
          projectDirectory.childDirectory('ios').createSync(recursive: true);
          final FlutterManifest manifest = FakeFlutterManifest();
          final FlutterProject project = FlutterProject(projectDirectory, manifest, manifest);
          expect(project.ios.usesSwiftPackageManager, isTrue);
        },
        overrides: <Type, Generator>{
          FeatureFlags: () => TestFeatureFlags(isSwiftPackageManagerEnabled: true),
          XcodeProjectInterpreter: () => FakeXcodeProjectInterpreter(version: Version(15, 0, 0)),
        },
      );

      testUsingContext(
        "is false when iOS project doesn't exist",
        () async {
          final MemoryFileSystem fs = MemoryFileSystem.test();
          final Directory projectDirectory = fs.directory('path');
          final FlutterManifest manifest = FakeFlutterManifest();
          final FlutterProject project = FlutterProject(projectDirectory, manifest, manifest);
          expect(project.ios.usesSwiftPackageManager, isFalse);
        },
        overrides: <Type, Generator>{
          FeatureFlags: () => TestFeatureFlags(isSwiftPackageManagerEnabled: true),
          XcodeProjectInterpreter: () => FakeXcodeProjectInterpreter(version: Version(15, 0, 0)),
        },
      );

      testUsingContext(
        'is false when Xcode is less than 15',
        () async {
          final MemoryFileSystem fs = MemoryFileSystem.test();
          final Directory projectDirectory = fs.directory('path');
          projectDirectory.childDirectory('ios').createSync(recursive: true);
          final FlutterManifest manifest = FakeFlutterManifest();
          final FlutterProject project = FlutterProject(projectDirectory, manifest, manifest);
          expect(project.ios.usesSwiftPackageManager, isFalse);
        },
        overrides: <Type, Generator>{
          FeatureFlags: () => TestFeatureFlags(isSwiftPackageManagerEnabled: true),
          XcodeProjectInterpreter: () => FakeXcodeProjectInterpreter(version: Version(14, 0, 0)),
        },
      );

      testUsingContext(
        'is false when Swift Package Manager feature is not enabled',
        () async {
          final MemoryFileSystem fs = MemoryFileSystem.test();
          final Directory projectDirectory = fs.directory('path');
          projectDirectory.childDirectory('ios').createSync(recursive: true);
          final FlutterManifest manifest = FakeFlutterManifest();
          final FlutterProject project = FlutterProject(projectDirectory, manifest, manifest);
          expect(project.ios.usesSwiftPackageManager, isFalse);
        },
        overrides: <Type, Generator>{
          FeatureFlags: () => TestFeatureFlags(),
          XcodeProjectInterpreter: () => FakeXcodeProjectInterpreter(version: Version(15, 0, 0)),
        },
      );

      testUsingContext(
        'is false when project is a module',
        () async {
          final MemoryFileSystem fs = MemoryFileSystem.test();
          final Directory projectDirectory = fs.directory('path');
          projectDirectory.childDirectory('ios').createSync(recursive: true);
          final FlutterManifest manifest = FakeFlutterManifest(isModule: true);
          final FlutterProject project = FlutterProject(projectDirectory, manifest, manifest);
          expect(project.ios.usesSwiftPackageManager, isFalse);
        },
        overrides: <Type, Generator>{
          FeatureFlags: () => TestFeatureFlags(isSwiftPackageManagerEnabled: true),
          XcodeProjectInterpreter: () => FakeXcodeProjectInterpreter(version: Version(15, 0, 0)),
        },
      );
    });

    group('parseFlavorFromConfiguration', () {
      testWithoutContext('from FLAVOR when CONFIGURATION is null', () async {
        final MemoryFileSystem fs = MemoryFileSystem.test();
        final IosProject project = IosProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
        final Environment env = Environment.test(
          fs.currentDirectory,
          fileSystem: fs,
          logger: BufferLogger.test(),
          artifacts: Artifacts.test(),
          processManager: FakeProcessManager.any(),
          defines: <String, String>{kFlavor: 'strawberry'},
        );
        expect(await project.parseFlavorFromConfiguration(env), 'strawberry');
      });

      testWithoutContext('from FLAVOR when CONFIGURATION is does not contain delimiter', () async {
        final MemoryFileSystem fs = MemoryFileSystem.test();
        final IosProject project = IosProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
        final Environment env = Environment.test(
          fs.currentDirectory,
          fileSystem: fs,
          logger: BufferLogger.test(),
          artifacts: Artifacts.test(),
          processManager: FakeProcessManager.any(),
          defines: <String, String>{kFlavor: 'strawberry', kXcodeConfiguration: 'Debug'},
        );
        expect(await project.parseFlavorFromConfiguration(env), 'strawberry');
      });

      testUsingContext(
        'from CONFIGURATION when has flavor following a hyphen that matches a scheme',
        () async {
          final MemoryFileSystem fs = MemoryFileSystem.test();
          final IosProject project = IosProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
          final Environment env = Environment.test(
            fs.currentDirectory,
            fileSystem: fs,
            logger: BufferLogger.test(),
            artifacts: Artifacts.test(),
            processManager: FakeProcessManager.any(),
            defines: <String, String>{kFlavor: 'strawberry', kXcodeConfiguration: 'Debug-vanilla'},
          );
          project.xcodeProject.createSync(recursive: true);
          expect(await project.parseFlavorFromConfiguration(env), 'vanilla');
        },
        overrides: <Type, Generator>{
          XcodeProjectInterpreter: () =>
              FakeXcodeProjectInterpreter(schemes: <String>['Runner', 'vanilla']),
        },
      );

      testUsingContext(
        'from CONFIGURATION when has flavor following a space that matches a scheme',
        () async {
          final MemoryFileSystem fs = MemoryFileSystem.test();
          final IosProject project = IosProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
          final Environment env = Environment.test(
            fs.currentDirectory,
            fileSystem: fs,
            logger: BufferLogger.test(),
            artifacts: Artifacts.test(),
            processManager: FakeProcessManager.any(),
            defines: <String, String>{kFlavor: 'strawberry', kXcodeConfiguration: 'Debug vanilla'},
          );
          project.xcodeProject.createSync(recursive: true);
          expect(await project.parseFlavorFromConfiguration(env), 'vanilla');
        },
        overrides: <Type, Generator>{
          XcodeProjectInterpreter: () =>
              FakeXcodeProjectInterpreter(schemes: <String>['Runner', 'vanilla']),
        },
      );

      testUsingContext(
        'from FLAVOR when CONFIGURATION does not match a scheme',
        () async {
          final MemoryFileSystem fs = MemoryFileSystem.test();
          final IosProject project = IosProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
          final Environment env = Environment.test(
            fs.currentDirectory,
            fileSystem: fs,
            logger: BufferLogger.test(),
            artifacts: Artifacts.test(),
            processManager: FakeProcessManager.any(),
            defines: <String, String>{kFlavor: 'strawberry', kXcodeConfiguration: 'Debug-random'},
          );
          project.xcodeProject.createSync(recursive: true);
          expect(await project.parseFlavorFromConfiguration(env), 'strawberry');
        },
        overrides: <Type, Generator>{
          XcodeProjectInterpreter: () =>
              FakeXcodeProjectInterpreter(schemes: <String>['Runner', 'vanilla']),
        },
      );
    });

    group('ensureReadyForPlatformSpecificTooling', () {
      group('lldb files are generated', () {
        testUsingContext(
          'when they are missing',
          () async {
            final MemoryFileSystem fs = MemoryFileSystem.test();
            final Directory projectDirectory = fs.directory('path');
            projectDirectory.childDirectory('ios').createSync(recursive: true);
            final FlutterManifest manifest = FakeFlutterManifest();
            final FlutterProject flutterProject = FlutterProject(
              projectDirectory,
              manifest,
              manifest,
            );
            final IosProject project = IosProject.fromFlutter(flutterProject);
            expect(project.lldbInitFile, isNot(exists));
            expect(project.lldbHelperPythonFile, isNot(exists));

            await project.ensureReadyForPlatformSpecificTooling();

            expect(project.lldbInitFile, exists);
            expect(project.lldbHelperPythonFile, exists);
          },
          overrides: <Type, Generator>{Cache: () => FakeCache(olderThanToolsStamp: true)},
        );

        testUsingContext(
          'when they are older than tool',
          () async {
            final MemoryFileSystem fs = MemoryFileSystem.test();
            final Directory projectDirectory = fs.directory('path');
            projectDirectory.childDirectory('ios').createSync(recursive: true);
            final FlutterManifest manifest = FakeFlutterManifest();
            final FlutterProject flutterProject = FlutterProject(
              projectDirectory,
              manifest,
              manifest,
            );
            final IosProject project = IosProject.fromFlutter(flutterProject);
            project.lldbInitFile.createSync(recursive: true);
            project.lldbInitFile.writeAsStringSync('old');
            project.lldbHelperPythonFile.createSync(recursive: true);
            project.lldbHelperPythonFile.writeAsStringSync('old');

            await project.ensureReadyForPlatformSpecificTooling();

            expect(
              project.lldbInitFile.readAsStringSync(),
              contains('Generated file, do not edit.'),
            );
            expect(
              project.lldbHelperPythonFile.readAsStringSync(),
              contains('Generated file, do not edit.'),
            );
          },
          overrides: <Type, Generator>{Cache: () => FakeCache(olderThanToolsStamp: true)},
        );
      });
    });
  });

  group('MacOSProject', () {
    testWithoutContext('managedDirectory', () {
      final MemoryFileSystem fs = MemoryFileSystem.test();
      final MacOSProject project = MacOSProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
      expect(project.managedDirectory.path, 'app_name/macos/Flutter');
    });

    testWithoutContext('module managedDirectory', () {
      final MemoryFileSystem fs = MemoryFileSystem.test();
      final MacOSProject project = MacOSProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
      expect(project.managedDirectory.path, 'app_name/macos/Flutter');
    });

    testWithoutContext('ephemeralDirectory', () {
      final MemoryFileSystem fs = MemoryFileSystem.test();
      final MacOSProject project = MacOSProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
      expect(project.ephemeralDirectory.path, 'app_name/macos/Flutter/ephemeral');
    });

    testWithoutContext('flutterSwiftPackagesDirectory', () {
      final MemoryFileSystem fs = MemoryFileSystem.test();
      final MacOSProject project = MacOSProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
      expect(
        project.flutterSwiftPackagesDirectory.path,
        'app_name/macos/Flutter/ephemeral/Packages',
      );
    });

    testWithoutContext('relativeSwiftPackagesDirectory', () {
      final MemoryFileSystem fs = MemoryFileSystem.test();
      final MacOSProject project = MacOSProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
      expect(
        project.relativeSwiftPackagesDirectory.path,
        'app_name/macos/Flutter/ephemeral/Packages/.packages',
      );
    });

    testWithoutContext('flutterPluginSwiftPackageDirectory', () {
      final MemoryFileSystem fs = MemoryFileSystem.test();
      final MacOSProject project = MacOSProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
      expect(
        project.flutterPluginSwiftPackageDirectory.path,
        'app_name/macos/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage',
      );
    });

    testWithoutContext('xcodeConfigFor', () {
      final MemoryFileSystem fs = MemoryFileSystem.test();
      final MacOSProject project = MacOSProject.fromFlutter(FakeFlutterProject(fileSystem: fs));
      expect(project.xcodeConfigFor('Debug').path, 'app_name/macos/Flutter/Flutter-Debug.xcconfig');
    });

    group('usesSwiftPackageManager', () {
      testUsingContext(
        'is true when macOS project exists',
        () async {
          final MemoryFileSystem fs = MemoryFileSystem.test();
          final Directory projectDirectory = fs.directory('path');
          projectDirectory.childDirectory('macos').createSync(recursive: true);
          final FlutterManifest manifest = FakeFlutterManifest();
          final FlutterProject project = FlutterProject(projectDirectory, manifest, manifest);
          expect(project.macos.usesSwiftPackageManager, isTrue);
        },
        overrides: <Type, Generator>{
          FeatureFlags: () => TestFeatureFlags(isSwiftPackageManagerEnabled: true),
          XcodeProjectInterpreter: () => FakeXcodeProjectInterpreter(version: Version(15, 0, 0)),
        },
      );

      testUsingContext(
        "is false when macOS project doesn't exist",
        () async {
          final MemoryFileSystem fs = MemoryFileSystem.test();
          final Directory projectDirectory = fs.directory('path');
          final FlutterManifest manifest = FakeFlutterManifest();
          final FlutterProject project = FlutterProject(projectDirectory, manifest, manifest);
          expect(project.ios.usesSwiftPackageManager, isFalse);
          expect(project.macos.usesSwiftPackageManager, isFalse);
        },
        overrides: <Type, Generator>{
          FeatureFlags: () => TestFeatureFlags(isSwiftPackageManagerEnabled: true),
          XcodeProjectInterpreter: () => FakeXcodeProjectInterpreter(version: Version(15, 0, 0)),
        },
      );

      testUsingContext(
        'is false when Xcode is less than 15',
        () async {
          final MemoryFileSystem fs = MemoryFileSystem.test();
          final Directory projectDirectory = fs.directory('path');
          projectDirectory.childDirectory('macos').createSync(recursive: true);
          final FlutterManifest manifest = FakeFlutterManifest();
          final FlutterProject project = FlutterProject(projectDirectory, manifest, manifest);
          expect(project.macos.usesSwiftPackageManager, isFalse);
        },
        overrides: <Type, Generator>{
          FeatureFlags: () => TestFeatureFlags(isSwiftPackageManagerEnabled: true),
          XcodeProjectInterpreter: () => FakeXcodeProjectInterpreter(version: Version(14, 0, 0)),
        },
      );

      testUsingContext(
        'is false when Swift Package Manager feature is not enabled',
        () async {
          final MemoryFileSystem fs = MemoryFileSystem.test();
          final Directory projectDirectory = fs.directory('path');
          projectDirectory.childDirectory('macos').createSync(recursive: true);
          final FlutterManifest manifest = FakeFlutterManifest();
          final FlutterProject project = FlutterProject(projectDirectory, manifest, manifest);
          expect(project.macos.usesSwiftPackageManager, isFalse);
        },
        overrides: <Type, Generator>{
          FeatureFlags: () => TestFeatureFlags(),
          XcodeProjectInterpreter: () => FakeXcodeProjectInterpreter(version: Version(15, 0, 0)),
        },
      );

      testUsingContext(
        'is false when project is a module',
        () async {
          final MemoryFileSystem fs = MemoryFileSystem.test();
          final Directory projectDirectory = fs.directory('path');
          projectDirectory.childDirectory('macos').createSync(recursive: true);
          final FlutterManifest manifest = FakeFlutterManifest(isModule: true);
          final FlutterProject project = FlutterProject(projectDirectory, manifest, manifest);
          expect(project.macos.usesSwiftPackageManager, isFalse);
        },
        overrides: <Type, Generator>{
          FeatureFlags: () => TestFeatureFlags(isSwiftPackageManagerEnabled: true),
          XcodeProjectInterpreter: () => FakeXcodeProjectInterpreter(version: Version(15, 0, 0)),
        },
      );
    });
  });
}

class FakeFlutterProject extends Fake implements FlutterProject {
  FakeFlutterProject({required this.fileSystem, this.isModule = false});

  MemoryFileSystem fileSystem;

  @override
  late final Directory directory = fileSystem.directory('app_name');

  @override
  bool isModule = false;

  @override
  FlutterManifest get manifest => FakeFlutterManifest();
}

class FakeXcodeProjectInterpreter extends Fake implements XcodeProjectInterpreter {
  FakeXcodeProjectInterpreter({
    this.isInstalled = true,
    this.version,
    this.schemes = const <String>['Runner'],
  });

  @override
  final bool isInstalled;

  @override
  final Version? version;

  List<String> schemes;

  @override
  Future<XcodeProjectInfo?> getInfo(String projectPath, {String? projectFilename}) async {
    return XcodeProjectInfo(<String>[], <String>[], schemes, BufferLogger.test());
  }
}

class FakeFlutterManifest extends Fake implements FlutterManifest {
  FakeFlutterManifest({this.isModule = false});

  @override
  bool isModule;

  @override
  String? buildName;

  @override
  String? buildNumber;

  @override
  String? get iosBundleIdentifier => null;

  @override
  String get appName => '';
}

class FakeCache extends Fake implements Cache {
  FakeCache({this.olderThanToolsStamp = false});

  bool olderThanToolsStamp;
  Map<String, bool> filesOlderThanToolsStamp = <String, bool>{};

  @override
  bool isOlderThanToolsStamp(FileSystemEntity entity) {
    if (filesOlderThanToolsStamp.containsKey(entity.basename)) {
      return filesOlderThanToolsStamp[entity.basename]!;
    }
    return olderThanToolsStamp;
  }
}
