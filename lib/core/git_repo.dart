import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:git_bindings/git_bindings.dart';

import 'package:gitjournal/core/note.dart';
import 'package:gitjournal/core/notes_folder.dart';
import 'package:gitjournal/settings.dart';

class NoteRepoResult {
  bool error;
  String noteFilePath;

  NoteRepoResult({
    @required this.error,
    this.noteFilePath,
  });
}

class GitNoteRepository {
  final String gitDirPath;
  final GitRepo _gitRepo;

  GitNoteRepository({
    @required this.gitDirPath,
  }) : _gitRepo = GitRepo(
          folderPath: gitDirPath,
          authorEmail: Settings.instance.gitAuthorEmail,
          authorName: Settings.instance.gitAuthor,
        );

  Future<NoteRepoResult> addNote(Note note) async {
    return _addNote(note, "Added Note");
  }

  Future<NoteRepoResult> _addNote(Note note, String commitMessage) async {
    await note.save();
    await _gitRepo.add(".");
    await _gitRepo.commit(
      message: commitMessage,
    );

    return NoteRepoResult(noteFilePath: note.filePath, error: false);
  }

  Future<NoteRepoResult> addFolder(NotesFolder folder) async {
    await _gitRepo.add(".");
    await _gitRepo.commit(
      message: "Created New Folder",
    );

    return NoteRepoResult(noteFilePath: folder.folderPath, error: false);
  }

  Future<NoteRepoResult> renameFolder(
    String oldFullPath,
    String newFullPath,
  ) async {
    // FIXME: This is a hacky way of adding the changes, ideally we should be calling rm + add or something
    await _gitRepo.add(".");
    await _gitRepo.commit(
      message: "Renamed Folder",
    );

    return NoteRepoResult(noteFilePath: newFullPath, error: false);
  }

  Future<NoteRepoResult> removeNote(String noteFilePath) async {
    var pathSpec = noteFilePath.replaceFirst(gitDirPath, "").substring(1);

    // We are not calling note.remove() as gitRm will also remove the file
    await _gitRepo.rm(pathSpec);
    await _gitRepo.commit(
      message: "Removed Note " + pathSpec,
    );

    return NoteRepoResult(noteFilePath: noteFilePath, error: false);
  }

  Future<NoteRepoResult> removeFolder(String folderPath) async {
    var pathSpec = folderPath.replaceFirst(gitDirPath, "").substring(1);

    await _gitRepo.rm(pathSpec);
    await _gitRepo.commit(
      message: "Removed Folder " + pathSpec,
    );

    await Directory(folderPath).delete(recursive: true);

    return NoteRepoResult(noteFilePath: folderPath, error: false);
  }

  Future<NoteRepoResult> resetLastCommit() async {
    await _gitRepo.resetLast();
    return NoteRepoResult(error: false);
  }

  Future<NoteRepoResult> updateNote(Note note) async {
    return _addNote(note, "Edited Note");
  }

  Future<void> sync() async {
    await _gitRepo.pull();
    await _gitRepo.push();
  }
}

bool shouldLogGitException(GitException ex) {
  var msg = ex.cause.toLowerCase();
  if (msg.contains("failed to resolve address for")) {
    return false;
  }
  if (msg.contains("failed to connect to")) {
    return false;
  }
  if (msg.contains("no address associated with hostname")) {
    return false;
  }
  if (msg.contains("failed to connect to")) {
    return false;
  }
  if (msg.contains("unauthorized")) {
    return false;
  }
  if (msg.contains("invalid credentials")) {
    return false;
  }
  if (msg.contains("failed to start ssh session")) {
    return false;
  }
  return true;
}
