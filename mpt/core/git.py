# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import datetime
import os
import shutil
import stat
import subprocess
import time

from pathlib import Path

from mpt.core.log import Logger

class GitHandler:
    """
    Comprehensive Git repository management handler with robust error recovery.

    Provides complete Git operations including cloning, updating, validation,
    and repair of repositories. Features sophisticated error handling, retry
    mechanisms, and support for complex repository structures including
    submodules and various reference types (branches, tags, commits).
    """
    MAX_RETRIES = 3
    RETRY_DELAY = 5
    MAX_DELETE_RETRIES = 5
    DELETE_RETRY_DELAY = 1

    @staticmethod
    def is_git_source(url):
        """
        Determine if a URL represents a Git repository source.

        Uses a simple heuristic to identify Git repositories by checking if
        the URL ends with the conventional '.git' extension used by many
        Git hosting services.

        Args:
            url (str): The URL to check for Git repository characteristics

        Returns:
            bool: True if URL appears to point to a Git repository, False otherwise
        """
        try:
            return url.endswith('.git')
        except Exception as e:
            Logger.exception(f"Error in is_git_source: {e}")
            return False

    @staticmethod
    def is_valid_repository(repo_dir: Path) -> bool:
        """
        Perform comprehensive validation of a Git repository's integrity.

        Executes multiple verification steps to ensure repository validity:
        1. Directory existence check
        2. .git subdirectory validation
        3. Branch reference verification using symbolic-ref
        4. Commit reference verification using rev-parse
        5. General repository structure validation using for-each-ref

        Args:
            repo_dir (Path): Filesystem path to the repository directory

        Returns:
            bool: True if repository passes all validation checks, False otherwise
        """
        try:
            # 1. Check if directory exists
            if not repo_dir.exists():
                return False

            # 2. Check if .git directory exists
            git_dir = repo_dir / '.git'
            if not git_dir.exists():
                return False

            # 3. Use a reliable command to check repository validity
            # This command checks if we can get the current HEAD reference
            success, output = GitHandler._execute_git_command(
                ['git', 'symbolic-ref', '--short', 'HEAD'],
                repo_dir,
                capture_output=True
            )

            # If the command succeeds, we have a valid branch reference
            if success and output.strip():
                return True

            # 4. If symbolic-ref fails, try to check if HEAD points to a valid commit
            success, output = GitHandler._execute_git_command(
                ['git', 'rev-parse', 'HEAD'],
                repo_dir,
                capture_output=True
            )

            # If this succeeds, HEAD points to a valid commit
            if success and output.strip():
                return True

            # 5. Check if there are any references at all
            success, output = GitHandler._execute_git_command(
                ['git', 'for-each-ref', '--count=1'],
                repo_dir,
                capture_output=True
            )

            # If we can list any references, the repository structure is valid
            return success and output.strip() != ""

        except Exception as e:
            Logger.exception(f"Repository validation error: {e}")
            return False

    @staticmethod
    def clone_repository(config, target_dir):
        """
        Clone a Git repository with comprehensive configuration options.

        Handles the complete repository cloning process with support for:
        - Recursive submodule initialization
        - Depth-limited cloning for large repositories
        - Branch and tag specification
        - Pre-cloning validation and cleanup of target directory
        - Fallback to update operations for existing repositories

        Args:
            config (dict): Repository configuration containing URL, version,
                          recursive options, and depth settings
            target_dir (Path): Target directory path for the cloned repository

        Returns:
            bool: True if cloning completed successfully, False otherwise
        """
        try:
            url = config['url']
            version = config['version']
            recursive = config.get('recursive', True)
            depth = config.get('depth')

            # Check if target directory exists and handle accordingly
            if target_dir.exists():
                # Check if directory contains only a .git folder (incomplete clone)
                if GitHandler._is_only_git_directory(target_dir):
                    Logger.warning(f"Directory contains only .git folder, removing: {target_dir}")
                    if not GitHandler._force_delete_directory(target_dir):
                        return False
                elif GitHandler._is_empty_directory(target_dir):
                    if not GitHandler._force_delete_directory(target_dir):
                        return False
                elif not GitHandler.is_valid_repository(target_dir):
                    if not GitHandler._force_delete_directory(target_dir):
                        return False
                else:
                    # Valid repository exists, try to update instead of clone
                    return GitHandler.update_repository(target_dir, config)

            # Build clone command with --branch parameter for both branches and tags
            cmd = ['git', 'clone']
            if recursive:
                cmd.append('--recurse-submodules')
            if depth:
                cmd.extend(['--depth', str(depth)])

            # Use --branch parameter for both branches and tags
            cmd.extend(['--branch', version, url, str(target_dir)])

            success, _ = GitHandler._execute_git_command(cmd, target_dir.parent)
            if not success:
                if GitHandler._is_only_git_directory(target_dir):
                    GitHandler._force_delete_directory(target_dir)
                return False

            if GitHandler._is_empty_directory(target_dir):
                GitHandler._force_delete_directory(target_dir)
                return False

            # For recursive clones, ensure submodules are properly initialized
            if recursive:
                return GitHandler._update_submodules(target_dir, depth)

            return True
        except Exception as e:
            Logger.exception(f"Critical error during clone: {e}")
            return False

    @staticmethod
    def _is_only_git_directory(path: Path) -> bool:
        """
        Detect incomplete Git clones by checking for .git-only directories.

        Identifies repositories that were partially cloned and contain only
        the .git metadata directory without any working tree files, which
        typically indicates an interrupted or failed clone operation.

        Args:
            path (Path): Directory path to check for incomplete Git structure

        Returns:
            bool: True if directory contains only a .git subdirectory, False otherwise
        """
        try:
            if not path.exists():
                return False

            items = list(path.iterdir())
            return len(items) == 1 and items[0].name == '.git' and items[0].is_dir()
        except Exception as e:
            Logger.exception(f"Error in _is_only_git_directory: {e}")
            return False

    @staticmethod
    def _is_empty_directory(path: Path) -> bool:
        """
        Check if a directory is completely empty of any files or subdirectories.

        Useful for detecting failed clone operations or cleaning up directories
        that were created but never populated with repository contents.

        Args:
            path (Path): Directory path to check for emptiness

        Returns:
            bool: True if directory contains no items, False otherwise
        """
        try:
            if not path.exists():
                return False
            return not any(path.iterdir())
        except Exception as e:
            Logger.exception(f"Error in _is_empty_directory: {e}")
            return False

    @staticmethod
    def update_repository(repo_dir, config):
        """
        Update an existing Git repository to the specified version.

        Performs intelligent repository updates with optimized fetching strategies:
        - Tag-specific fetching without retrieving all tags
        - Branch-specific fetching without retrieving all branches
        - Hard reset to ensure clean working state
        - Untracked file cleanup
        - Submodule synchronization

        Args:
            repo_dir (Path): Path to the existing repository directory
            config (dict): Configuration containing target version and update options

        Returns:
            bool: True if update completed successfully, False otherwise
        """
        try:
            # First check if repository is valid
            if not GitHandler.is_valid_repository(repo_dir):
                Logger.warning(f"Repository is invalid, attempting repair: {repo_dir}")
                return GitHandler.repair_repository(repo_dir, config)

            if GitHandler._is_empty_directory(repo_dir):
                return False

            version = config['version']
            recursive = config.get('recursive', True)
            depth = config.get('depth')

            is_tag = GitHandler._is_tag(repo_dir, version)

            # Optimized fetch: only fetch specific ref without fetching all tags/branches
            if is_tag:
                # Fetch only the specific tag without fetching all tags
                cmd = ['git', 'fetch', 'origin', '--no-tags', 'tag', version]
                if depth:
                    cmd.extend(['--depth', str(depth)])
                success, _ = GitHandler._execute_git_command(cmd, repo_dir)
                if not success:
                    return False
                success, _ = GitHandler._execute_git_command(['git', 'reset', '--hard', version], repo_dir)
            else:
                # Fetch only the specific branch without fetching all branches
                cmd = ['git', 'fetch', 'origin', '--no-tags', version]
                if depth:
                    cmd.extend(['--depth', str(depth)])
                success, _ = GitHandler._execute_git_command(cmd, repo_dir)
                if not success:
                    return False
                success, _ = GitHandler._execute_git_command(['git', 'reset', '--hard', 'FETCH_HEAD'], repo_dir)

            if not success:
                return False

            # Clean untracked files
            success, _ = GitHandler._execute_git_command(['git', 'clean', '-fd'], repo_dir)
            if not success:
                return False

            # Update submodules if recursive is enabled
            if recursive:
                return GitHandler._update_submodules(repo_dir, depth)

            return True
        except Exception as e:
            Logger.exception(f"Error in update_repository: {e}")
            return False

    @staticmethod
    def _is_tag(repo_dir, ref_name):
        """
        Determine if a reference name corresponds to a Git tag.

        Checks both local and remote tag listings to identify whether
        a specified reference represents a tag rather than a branch or commit.

        Args:
            repo_dir (Path): Repository directory for tag lookup
            ref_name (str): Reference name to check for tag classification

        Returns:
            bool: True if reference is a tag, False otherwise
        """
        try:
            success, output = GitHandler._execute_git_command(
                ['git', 'tag', '-l', ref_name], repo_dir, capture_output=True
            )
            if success and output.strip():
                return True

            success, output = GitHandler._execute_git_command(
                ['git', 'ls-remote', '--tags', 'origin', ref_name], repo_dir, capture_output=True
            )
            if success and output.strip():
                return True

            return False
        except Exception as e:
            Logger.exception(f"Error in _is_tag: {e}")
            return False

    @staticmethod
    def _update_submodules(repo_dir, depth=None):
        """
        Update and initialize Git submodules with optional depth limiting.

        Handles the complete submodule initialization and update process,
        including recursive submodule handling and depth-limited cloning
        for large submodule repositories.

        Args:
            repo_dir (Path): Parent repository directory containing submodules
            depth (int, optional): Maximum commit depth for submodule cloning

        Returns:
            bool: True if all submodules were successfully updated, False otherwise
        """
        try:
            update_cmd = ['git', 'submodule', 'update', '--init', '--recursive', '--force', '--checkout']
            if depth:
                update_cmd.extend(['--depth', str(depth)])
            success, _ = GitHandler._execute_git_command(update_cmd, repo_dir)
            return success
        except Exception as e:
            Logger.exception(f"Error updating submodules: {e}")
            return False

    @staticmethod
    def verify_repository_integrity(repo_dir, config=None):
        """
        Perform comprehensive integrity verification of a Git repository.

        Executes multiple validation checks including:
        - Basic repository validity checks
        - Filesystem consistency verification (git fsck)
        - Submodule status validation
        - Graceful handling of non-critical issues (dangling objects)

        Args:
            repo_dir (Path): Repository directory to verify
            config (dict, optional): Configuration for recursive submodule checking

        Returns:
            bool: True if repository integrity is verified, False otherwise
        """
        try:
            if not GitHandler.is_valid_repository(repo_dir):
                Logger.warning(f"Repository is not valid: {repo_dir}")
                return False

            if GitHandler._is_empty_directory(repo_dir):
                Logger.warning(f"Repository directory is empty: {repo_dir}")
                return False

            # Check git fsck but allow some warnings (like dangling objects)
            success, output = GitHandler._execute_git_command(['git', 'fsck'], repo_dir, capture_output=True)
            if not success:
                # Check if the failure is due to non-critical warnings
                if "dangling" in output.lower() and "error:" not in output.lower():
                    Logger.warning(f"Repository has dangling objects but may still be valid: {repo_dir}")
                    # Continue with other checks despite dangling objects
                else:
                    Logger.error(f"Repository fsck failed with critical errors: {output}")
                    # Fallback check: use 'git status' to verify if the repository is still usable
                    status_success, status_output = GitHandler._execute_git_command(['git', 'status'], repo_dir, capture_output=True)
                    if status_success:
                        Logger.warning(f"Repository fsck failed but 'git status' succeeded, considering it valid: {repo_dir}")
                        # Continue with other checks since 'git status' worked
                    else:
                        Logger.error(f"Repository is unusable: {status_output}")
                        return False

            recursive = config.get('recursive', True) if config else True

            if recursive:
                # Check submodule status but don't fail on warnings
                success, output = GitHandler._execute_git_command(['git', 'submodule', 'status'], repo_dir, capture_output=True)
                if not success:
                    Logger.warning(f"Submodule status check failed but continuing: {output}")

            return True
        except Exception as e:
            Logger.exception(f"Critical error during integrity check: {e}")
            return False

    @staticmethod
    def repair_repository(repo_dir, config=None):
        """
        Attempt to repair a damaged or corrupted Git repository.

        Implements a multi-stage repair strategy:
        1. Simple repair attempts (HEAD reference reset)
        2. Comprehensive repository state analysis
        3. Complete re-cloning as last resort
        Provides detailed logging throughout the repair process.

        Args:
            repo_dir (Path): Path to the damaged repository directory
            config (dict, optional): Original configuration for re-cloning

        Returns:
            bool: True if repository was successfully repaired, False otherwise
        """
        try:
            if not config:
                return False

            # Log pre-repair state for debugging
            Logger.info(f"Attempting to repair repository: {repo_dir}")

            # Try to get current repository state information
            try:
                # Check if there are any references
                success, ref_output = GitHandler._execute_git_command(
                    ['git', 'for-each-ref', '--format=%(refname)'],
                    repo_dir,
                    capture_output=True
                )

                # Check HEAD state
                success, head_output = GitHandler._execute_git_command(
                    ['git', 'symbolic-ref', 'HEAD'],
                    repo_dir,
                    capture_output=True
                )

                Logger.debug(f"Repository state before repair - Refs: {ref_output}, HEAD: {head_output}")
            except Exception as e:
                Logger.warning(f"Could not get repository state: {e}")

            # For repositories with broken HEAD, try simple repair first
            Logger.info("Attempting simple repair by resetting HEAD...")

            # Try to get remote branch information
            success, remote_branches = GitHandler._execute_git_command(
                ['git', 'ls-remote', '--heads', 'origin'],
                repo_dir,
                capture_output=True
            )

            if success and remote_branches:
                # Try to find a default branch (usually master or main)
                default_branches = ['main', 'master']
                target_branch = None

                for branch in default_branches:
                    if f"refs/heads/{branch}" in remote_branches:
                        target_branch = branch
                        break

                # If default branch found, try to reset HEAD
                if target_branch:
                    Logger.info(f"Attempting to reset HEAD to {target_branch}...")
                    success, _ = GitHandler._execute_git_command(
                        ['git', 'remote', 'set-head', 'origin', target_branch],
                        repo_dir
                    )

                    if success:
                        success, _ = GitHandler._execute_git_command(
                            ['git', 'symbolic-ref', 'HEAD', f'refs/heads/{target_branch}'],
                            repo_dir
                        )

                        if success:
                            Logger.info(f"Successfully repaired HEAD reference to {target_branch}")

                            # Verify if repair was successful
                            if GitHandler.is_valid_repository(repo_dir):
                                Logger.info("Repository repaired successfully")
                                return True

            # If simple repair fails, perform full re-clone
            Logger.info("Simple repair failed, performing full re-clone...")

            # Force delete directory (including cases with only .git folder)
            if not GitHandler._force_delete_directory(repo_dir):
                Logger.error(f"Failed to delete directory: {repo_dir}")
                return False

            time.sleep(1)

            # Re-clone using original config directly
            return GitHandler.clone_repository(config, repo_dir)
        except Exception as e:
            Logger.exception(f"Error in repair_repository: {e}")
            return False

    @staticmethod
    def _execute_git_command(cmd, cwd=None, capture_output=False):
        """
        Execute Git commands with robust error handling and retry mechanisms.

        Provides a unified interface for Git command execution featuring:
        - Automatic retry with configurable delays
        - Real-time output logging
        - Comprehensive error handling
        - Return code validation

        Args:
            cmd (list): Git command and arguments as a list
            cwd (Path): Working directory for command execution
            capture_output (bool): Whether to capture and return command output

        Returns:
            tuple: (success, output) where success indicates command success
                   and output contains captured output if requested
        """
        for attempt in range(GitHandler.MAX_RETRIES):
            try:
                output_lines = []
                Logger.debug(f"Running git command: [bold green]{cmd}[/bold green]")
                p = subprocess.Popen(
                    cmd,
                    cwd=str(cwd) if cwd else None,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT
                )
                for line in iter(p.stdout.readline, b''):
                    decoded_line = line.decode('utf-8', errors='ignore').rstrip()
                    output_lines.append(decoded_line)
                    Logger.debug(f"{decoded_line}", markup=False)
                    if p.poll() is not None:
                        break
                returncode = p.wait()
                full_output = "\n".join(output_lines) if capture_output else ""
                if returncode == 0:
                    return True, full_output
                else:
                    if attempt < GitHandler.MAX_RETRIES - 1:
                        time.sleep(GitHandler.RETRY_DELAY)
                    else:
                        return False, full_output
            except Exception as e:
                Logger.exception(f"Error executing git command: {e}")
                if attempt < GitHandler.MAX_RETRIES - 1:
                    time.sleep(GitHandler.RETRY_DELAY)
                else:
                    return False, ""

    @staticmethod
    def get_last_commit_time(repo_dir: Path) -> float:
        """
        Retrieve the timestamp of the most recent commit in a repository.

        Uses git log with format specifiers to extract the precise timestamp
        of the latest commit, which is useful for change detection and
        build timestamp comparisons.

        Args:
            repo_dir (Path): Repository directory to query for commit history

        Returns:
            float: Unix timestamp of the last commit, or 0 if unavailable
        """
        try:
            cmd = ['git', 'log', '-1', '--format=%at']
            success, output = GitHandler._execute_git_command(cmd, repo_dir, capture_output=True)
            if success:
                return float(output.strip())
            else:
                return 0
        except Exception as e:
            Logger.exception(f"Error getting commit time: {e}")
            return 0

    @staticmethod
    def _force_delete_directory(path: Path) -> bool:
        """
        Forcefully delete a directory including read-only files.

        Handles challenging directory deletion scenarios including:
        - Read-only file permission issues
        - Locked files on Windows systems
        - Stubborn directory structures

        Args:
            path (Path): Directory path to delete

        Returns:
            bool: True if directory was successfully deleted, False otherwise
        """
        try:
            if not path.exists():
                return True
            def remove_readonly(func, filepath, _):
                os.chmod(filepath, stat.S_IWRITE)
                func(filepath)
            shutil.rmtree(path, onerror=remove_readonly)
            return True
        except Exception as e:
            Logger.exception(f"Failed to delete directory: {path} - Error: {e}")
            return False
