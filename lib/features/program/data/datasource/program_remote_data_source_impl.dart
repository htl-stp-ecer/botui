import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';
import 'package:stpvelox/features/program/domain/entities/program.dart';
import 'package:stpvelox/features/program/domain/entities/sync_state.dart';
import 'package:stpvelox/features/program/domain/repositories/program_remote_data_source.dart';
import 'package:stpvelox/features/sensors/domain/entities/args/arg.dart';

class ProgramRemoteDataSourceImpl implements ProgramRemoteDataSource {
  final String programsDirectoryPath;

  ProgramRemoteDataSourceImpl({required this.programsDirectoryPath});

  @override
  Future<List<String>> executeProgram(String arg) async {
    if (arg.isEmpty) {
      throw Exception("No argument provided.");
    }
    return [
      "Program '$arg' started...",
      "Loading data...",
      "Error: Unable to reach server.",
    ];
  }

  @override
  Future<List<Program>> getPrograms() async {
    final programsDir = Directory(programsDirectoryPath);

    if (!await programsDir.exists()) {
      await programsDir.create();
      return [];
    }

    final List<Directory> projectDirs = await programsDir
        .list()
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList();

    List<Program> programs = [];

    for (var dir in projectDirs) {
      final folderName = path.basename(dir.path);
      final raccoonProjectFile = File(path.join(dir.path, 'raccoon.project.yml'));
      final projectJsonFile = File(path.join(dir.path, 'project.json'));

      String name = folderName;
      List<Arg> args = [];
      bool parsedRaccoonProject = false;

      // Prioritize raccoon.project.yml over project.json
      if (await raccoonProjectFile.exists()) {
        try {
          final yamlContent = await raccoonProjectFile.readAsString();
          final dynamic yamlData = loadYaml(yamlContent);

          if (yamlData is Map) {
            // Use 'name' field from raccoon.project.yml
            if (yamlData.containsKey('name') && yamlData['name'] is String) {
              name = yamlData['name'];
            }

            // raccoon.project.yml doesn't define args in the same format
            // args remain empty for now

            parsedRaccoonProject = true;
          }
        } catch (e) {
          developer.log(
              'Error reading or parsing raccoon.project.yml in ${dir.path}: $e. Trying project.json fallback.',
              name: 'ProgramRemoteDataSourceImpl');
        }
      }

      // Fall back to project.json if raccoon.project.yml doesn't exist or failed to parse
      if (!parsedRaccoonProject && await projectJsonFile.exists()) {
        try {
          final jsonContent = await projectJsonFile.readAsString();
          final Map<String, dynamic> jsonData = jsonDecode(jsonContent);

          if (jsonData.containsKey('name') && jsonData['name'] is String) {
            name = jsonData['name'];
          }

          if (jsonData.containsKey('args') && jsonData['args'] is List) {
            args = (jsonData['args'] as List)
                .map((argJson) => Arg.fromJson(argJson))
                .toList();
          }
        } catch (e) {
          developer.log(
              'Error reading or parsing project.json in ${dir.path}: $e. Using defaults.',
              name: 'ProgramRemoteDataSourceImpl');
        }
      }

      // Load .raccoon/sync_state.json if present — it's just a local file,
      // no HTTP roundtrip. Absent means the project has never been synced.
      final syncState = await SyncState.loadFromProjectDir(dir.path);

      final program = Program(
        name: name,
        parentDir: dir.path,
        args: args,
        syncState: syncState,
      );

      programs.add(program);
    }

    return programs;
  }
}
