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
    Comprehensive Git repository management handler with robust error recovery capabilities.

    This class provides a complete suite of Git operations including cloning, updating,
    validation, and repair of repositories. It features sophisticated error handling,
    automatic retry mechanisms, and support for complex repository structures including
    submodules and various reference types (branches, tags, commits).

    The handler is designed to be resilient against network issues, repository corruption,
    and partial failures, making it suitable for automated deployment and CI/CD pipelines.

    Attributes:
        MAX_RETRIES (int): Maximum number of retry attempts for Git operations
        RETRY_DELAY (int): Delay in seconds between retry attempts
        MAX_DELETE_RETRIES (int): Maximum retry attempts for directory deletion operations
        DELETE_RETRY_DELAY (int): Delay in seconds between delete retry attempts
    """
    MAX_RETRIES = 3
    RETRY_DELAY = 5
    MAX_DELETE_RETRIES = 5
    DELETE_RETRY_DELAY = 1

    @staticmethod
    def is_git_source(url):
        """
        Determine if a URL represents a Git repository by checking for the '.git' extension.

        This method performs a simple check to identify Git repository URLs based on
        the conventional '.git' extension used by most Git hosting services.

        Args:
            url (str): The URL to check for Git repository characteristics

        Returns:
            bool: True if URL ends with '.git', False otherwise
        """
        return url.endswith('.git')

    @staticmethod
    def is_valid_repository(repo_dir: Path) -> bool:
        """
        Perform comprehensive validation of a Git repository's integrity through multiple checks.

        This method validates a Git repository by checking:
        1. Directory existence
        2. Presence of .git directory
        3. Valid HEAD reference (branch or commit)
        4. Existence of at least one Git reference

        Args:
            repo_dir (Path): Filesystem path to the repository directory to validate

        Returns:
            bool: True if repository passes all validation checks, False otherwise
        """
        # Check if directory exists
        if not repo_dir.exists():
            return False

        # Check if .git directory exists
        git_dir = repo_dir / '.git'
        if not git_dir.exists():
            return False

        # Check if we can get the current HEAD reference (branch)
        success, output = GitHandler._capture_git_command(
            ['git', 'symbolic-ref', '--short', 'HEAD'],
            repo_dir
        )

        # If the command succeeds, we have a valid branch reference
        if success and output.strip():
            return True

        # If symbolic-ref fails, check if HEAD points to a valid commit
        success, output = GitHandler._capture_git_command(
            ['git', 'rev-parse', 'HEAD'],
            repo_dir
        )

        # If this succeeds, HEAD points to a valid commit
        if success and output.strip():
            return True

        # Check if there are any references at all
        success, output = GitHandler._capture_git_command(
            ['git', 'for-each-ref', '--count=1'],
            repo_dir
        )

        # If we can list any references, the repository structure is valid
        return success and output.strip() != ""

    @staticmethod
    def clone_repository(config, target_dir):
        """
        Clone a Git repository with comprehensive configuration options and error handling.

        This method handles the complete Git clone process with support for:
        - Branch and tag specifications
        - Recursive submodule cloning
        - Depth-limited cloning
        - Existing directory handling
        - Automatic fallback to update if repository already exists

        Args:
            config (dict): Repository configuration containing:
                - url (str): Git repository URL
                - version (str): Branch, tag, or commit to checkout
                - recursive (bool, optional): Enable submodule cloning (default: True)
                - depth (int, optional): Clone depth for shallow cloning
            target_dir (Path): Target directory path for the cloned repository

        Returns:
            bool: True if cloning completed successfully, False otherwise
        """
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

        # Execute the clone command
        success = GitHandler._run_git_command(cmd, target_dir.parent)
        if not success:
            # Clean up incomplete clone
            if GitHandler._is_only_git_directory(target_dir):
                GitHandler._force_delete_directory(target_dir)
            return False

        # Verify the clone was successful and complete
        if GitHandler._is_empty_directory(target_dir):
            GitHandler._force_delete_directory(target_dir)
            return False

        override_submodules = config.get('submodules', {})

        # For recursive clones, ensure submodules are properly initialized
        if recursive:
            if not GitHandler._update_submodules(target_dir, depth, override_submodules):
                Logger.error("Submodule initialization failed during clone")
                return False

        return True

    @staticmethod
    def update_repository(repo_dir, config):
        """
        Update an existing Git repository to the specified version with optimized fetching.

        This method performs an optimized update of an existing Git repository by:
        1. Validating the repository state
        2. Fetching only the necessary references (not all tags/branches)
        3. Resetting to the target version
        4. Cleaning untracked files
        5. Updating submodules if configured

        Args:
            repo_dir (Path): Path to the existing repository directory
            config (dict): Configuration containing target version and update options

        Returns:
            bool: True if update completed successfully, False otherwise
        """
        # First check if repository is valid
        if not GitHandler.is_valid_repository(repo_dir):
            Logger.warning(f"Repository is invalid, attempting repair: {repo_dir}")
            return GitHandler.repair_repository(repo_dir, config)

        # Check if directory is empty
        if GitHandler._is_empty_directory(repo_dir):
            return False

        version = config['version']
        recursive = config.get('recursive', True)
        depth = config.get('depth')

        # Determine if the version refers to a tag or branch
        is_tag = GitHandler._is_tag(repo_dir, version)

        # Optimized fetch: only fetch specific ref without fetching all tags/branches
        if is_tag:
            # Fetch only the specific tag without fetching all tags
            cmd = ['git', 'fetch', 'origin', '--no-tags', 'tag', version]
            if depth:
                cmd.extend(['--depth', str(depth)])
            success = GitHandler._run_git_command(cmd, repo_dir)
            if not success:
                return False
            # Reset to the specific tag
            success = GitHandler._run_git_command(['git', 'reset', '--hard', version], repo_dir)
        else:
            # Fetch only the specific branch without fetching all branches
            cmd = ['git', 'fetch', 'origin', '--no-tags', version]
            if depth:
                cmd.extend(['--depth', str(depth)])
            success = GitHandler._run_git_command(cmd, repo_dir)
            if not success:
                return False
            # Reset to the fetched branch head
            success = GitHandler._run_git_command(['git', 'reset', '--hard', 'FETCH_HEAD'], repo_dir)

        if not success:
            return False

        # Clean untracked files that might interfere with the update
        success = GitHandler._run_git_command(['git', 'clean', '-fd'], repo_dir)
        if not success:
            return False

        override_submodules = config.get('submodules', {})

        # Update submodules if recursive is enabled
        if recursive:
            if not GitHandler._update_submodules(repo_dir, depth, override_submodules):
                Logger.error("Submodule update failed during repository update")
                return False

        return True

    @staticmethod
    def _is_only_git_directory(path: Path) -> bool:
        """
        Check if directory contains only a .git subdirectory indicating incomplete clone.

        This method identifies partially cloned repositories where only the .git
        directory exists but no working tree files have been checked out.

        Args:
            path (Path): Directory path to check for incomplete Git structure

        Returns:
            bool: True if directory contains only a .git subdirectory, False otherwise
        """
        if not path.exists():
            return False

        items = list(path.iterdir())
        return len(items) == 1 and items[0].name == '.git' and items[0].is_dir()

    @staticmethod
    def _is_empty_directory(path: Path) -> bool:
        """
        Check if a directory is completely empty of any files or subdirectories.

        Args:
            path (Path): Directory path to check for emptiness

        Returns:
            bool: True if directory contains no items, False otherwise
        """
        if not path.exists():
            return False
        return not any(path.iterdir())

    @staticmethod
    def _is_tag(repo_dir, ref_name):
        """
        Determine if a reference name corresponds to a Git tag by checking local and remote tags.

        This method checks both local and remote tags to determine if the given
        reference name corresponds to a tag rather than a branch or commit.

        Args:
            repo_dir (Path): Repository directory for tag lookup
            ref_name (str): Reference name to check for tag classification

        Returns:
            bool: True if reference is a tag, False otherwise
        """
        # Check local tags
        success, output = GitHandler._capture_git_command(
            ['git', 'tag', '-l', ref_name], repo_dir
        )
        if success and output.strip():
            return True

        # Check remote tags if local check fails
        success, output = GitHandler._capture_git_command(
            ['git', 'ls-remote', '--tags', 'origin', ref_name], repo_dir
        )
        if success and output.strip():
            return True

        return False

    @staticmethod
    def _update_submodules(repo_dir, depth=None, override_submodules=None):
        """
        Update and initialize Git submodules with optional depth limiting and submodule overrides.

        This method initializes and updates all submodules in a repository,
        with support for shallow cloning of submodules when depth is specified.
        It also allows overriding submodule URLs and branches through configuration.

        Args:
            repo_dir (Path): Parent repository directory containing submodules
            depth (int, optional): Maximum commit depth for submodule cloning
            override_submodules (dict, optional): Submodule override configuration

        Returns:
            bool: True if all submodules were successfully updated, False otherwise
        """
        if override_submodules is None:
            override_submodules = {}

        # Apply submodule overrides if specified
        for submodule_path, override_config in override_submodules.items():
            new_url = override_config.get('url')
            new_branch = override_config.get('branch')

            if new_url:
                # Set submodule URL override
                cmd = ['git', 'config', '-f', '.gitmodules', f'submodule.{submodule_path}.url', new_url]
                success = GitHandler._run_git_command(cmd, repo_dir)
                if not success:
                    Logger.warning(f"Failed to set URL override for submodule {submodule_path}")
                else:
                    Logger.info(f"Successfully overrode URL for submodule {submodule_path}")

            if new_branch:
                # Set submodule branch override
                cmd = ['git', 'config', '-f', '.gitmodules', f'submodule.{submodule_path}.branch', new_branch]
                success = GitHandler._run_git_command(cmd, repo_dir)
                if not success:
                    Logger.warning(f"Failed to set branch override for submodule {submodule_path}")
                else:
                    Logger.info(f"Successfully overrode branch for submodule {submodule_path}")

        # Sync submodules to apply any URL changes
        if override_submodules:
            success = GitHandler._run_git_command(['git', 'submodule', 'sync'], repo_dir)
            if not success:
                Logger.warning("Submodule sync failed after applying overrides")

        # Build submodule update command
        update_cmd = ['git', 'submodule', 'update', '--init', '--recursive', '--force', '--checkout']
        if depth:
            update_cmd.extend(['--depth', str(depth)])

        # Execute the submodule update command
        success = GitHandler._run_git_command(update_cmd, repo_dir)

        # Verify submodules were updated correctly
        if success:
            success = GitHandler._verify_submodules(repo_dir)
        else:
            Logger.error("Submodule update command failed")

        return success

    @staticmethod
    def verify_repository_integrity(repo_dir, config=None):
        """
        Perform comprehensive integrity verification of a Git repository with multiple checks.

        This method performs a series of checks to validate repository integrity:
        1. Basic repository validity
        2. Non-empty working directory
        3. Git filesystem consistency check (fsck)
        4. Submodule status (if recursive is enabled)

        The method is tolerant of non-critical issues like dangling objects but will
        fail on critical repository corruption.

        Args:
            repo_dir (Path): Repository directory to verify
            config (dict, optional): Configuration for recursive submodule checking

        Returns:
            bool: True if repository integrity is verified, False otherwise
        """
        # Check basic repository validity
        if not GitHandler.is_valid_repository(repo_dir):
            Logger.warning(f"Repository is not valid: {repo_dir}")
            return False

        # Check if directory is empty
        if GitHandler._is_empty_directory(repo_dir):
            Logger.warning(f"Repository directory is empty: {repo_dir}")
            return False

        # Check git fsck but allow some warnings (like dangling objects)
        success, output = GitHandler._capture_git_command(['git', 'fsck'], repo_dir)
        if not success:
            # Check if the failure is due to non-critical warnings
            if "dangling" in output.lower() and "error:" not in output.lower():
                Logger.warning(f"Repository has dangling objects but may still be valid: {repo_dir}")
                # Continue with other checks despite dangling objects
            else:
                Logger.error(f"Repository fsck failed with critical errors: {output}")
                # Fallback check: use 'git status' to verify if the repository is still usable
                status_success, status_output = GitHandler._capture_git_command(['git', 'status'], repo_dir)
                if status_success:
                    Logger.warning(f"Repository fsck failed but 'git status' succeeded, considering it valid: {repo_dir}")
                    # Continue with other checks since 'git status' worked
                else:
                    Logger.error(f"Repository is unusable: {status_output}")
                    return False

        # Check submodule status if recursive is enabled
        recursive = config.get('recursive', True) if config else True

        if recursive:
            # Check submodule status but don't fail on warnings
            success, output = GitHandler._capture_git_command(['git', 'submodule', 'status'], repo_dir)
            if not success:
                Logger.warning(f"Submodule status check failed but continuing: {output}")

        return True

    @staticmethod
    def repair_repository(repo_dir, config=None):
        """
        Attempt to repair a damaged or corrupted Git repository with multi-stage strategy.

        This method implements a comprehensive repair strategy for Git repositories:
        1. Diagnose the type of failure (submodule vs main repository)
        2. Attempt targeted repairs based on diagnosis
        3. Fall back to complete re-cloning if repairs fail

        Args:
            repo_dir (Path): Path to the damaged repository directory
            config (dict, optional): Original configuration for re-cloning

        Returns:
            bool: True if repository was successfully repaired, False otherwise
        """
        if not config:
            return False

        Logger.info(f"Attempting to repair repository: {repo_dir}")

        # Check if the failure is submodule-related
        if GitHandler._is_submodule_issue(repo_dir):
            Logger.warning("Failure appears to be submodule-related, attempting targeted repair...")
            return GitHandler._repair_submodules(repo_dir, config)

        # Check repository state for debugging purposes
        success, ref_output = GitHandler._capture_git_command(
            ['git', 'for-each-ref', '--format=%(refname)'],
            repo_dir
        )

        # Check HEAD state
        success, head_output = GitHandler._capture_git_command(
            ['git', 'symbolic-ref', 'HEAD'],
            repo_dir
        )
        Logger.debug(f"Repository state before repair - Refs: {ref_output}, HEAD: {head_output}")

        # Attempt to repair the main repository
        if GitHandler._repair_main_repository(repo_dir, config):
            Logger.info("Main repository repaired successfully")
            return True

        Logger.info("All repair attempts failed, performing full re-clone...")

        # Force delete directory (including cases with only .git folder)
        if not GitHandler._force_delete_directory(repo_dir):
            Logger.error(f"Failed to delete directory: {repo_dir}")
            return False

        # Brief delay before re-cloning
        time.sleep(1)

        # Re-clone using original config directly
        return GitHandler.clone_repository(config, repo_dir)

    @staticmethod
    def _repair_main_repository(repo_dir, config):
        """
        Repair main Git repository with multi-step strategy including reference and workspace fixes.

        This method implements a multi-step approach to repairing a damaged Git repository:
        1. Repair HEAD reference
        2. Re-fetch remote references
        3. Clean and reset workspace
        4. Rebuild repository infrastructure

        Args:
            repo_dir (Path): Repository directory
            config (dict): Configuration information

        Returns:
            bool: True if repair succeeded, False otherwise
        """
        version = config['version']
        depth = config.get('depth')

        Logger.info("Attempting multi-step main repository repair...")

        # Step 1: Checking and repairing HEAD reference
        Logger.info("Step 1: Checking and repairing HEAD reference...")
        head_repaired = GitHandler._repair_head_reference(repo_dir, version)
        if not head_repaired:
            Logger.warning("HEAD reference repair failed, trying next step...")

        # Step 2: Re-fetching remote references
        Logger.info("Step 2: Re-fetching remote references...")
        fetch_success = GitHandler._refetch_remote_references(repo_dir, version, depth)
        if not fetch_success:
            Logger.warning("Re-fetching remote references failed, trying next step...")

        # Step 3: Cleaning and resetting workspace
        Logger.info("Step 3: Cleaning and resetting workspace...")
        reset_success = GitHandler._clean_and_reset_workspace(repo_dir, version)
        if not reset_success:
            Logger.warning("Workspace cleanup failed, trying next step...")

        # Step 4: Rebuilding index and object database
        Logger.info("Step 4: Rebuilding index and object database...")
        rebuild_success = GitHandler._rebuild_repository_infrastructure(repo_dir)
        if not rebuild_success:
            Logger.warning("Repository infrastructure rebuild failed...")

        # Check if repair was successful
        if GitHandler.is_valid_repository(repo_dir):
            Logger.info("Main repository repair completed successfully")

            # Verify submodules after main repository repair
            recursive = config.get('recursive', True)
            if recursive:
                Logger.info("Verifying submodules after main repository repair...")
                if not GitHandler._verify_submodules(repo_dir):
                    Logger.warning("Submodules need repair after main repository fix")
                    return GitHandler._repair_submodules(repo_dir, config)

            return True

        Logger.warning("Multi-step repair did not fully restore repository")
        return False

    @staticmethod
    def _repair_head_reference(repo_dir, version):
        """
        Repair HEAD reference by checking remote branches and setting appropriate references.

        This method attempts to repair a corrupted or missing HEAD reference by:
        1. Checking available remote branches
        2. Setting HEAD to a common branch (main, master, or the specified version)
        3. Falling back to direct commit reference if branch approach fails

        Args:
            repo_dir (Path): Repository directory
            version (str): Target version/branch/tag

        Returns:
            bool: True if HEAD reference was successfully repaired, False otherwise
        """
        # Check available remote branches
        success, remote_branches = GitHandler._capture_git_command(
            ['git', 'ls-remote', '--heads', 'origin'],
            repo_dir
        )

        if success and remote_branches:
            # Try common branch names
            default_branches = ['main', 'master', version]
            target_branch = None

            for branch in default_branches:
                if f"refs/heads/{branch}" in remote_branches:
                    target_branch = branch
                    break

            if target_branch:
                Logger.info(f"Attempting to reset HEAD to {target_branch}...")

                # Set remote head to the target branch
                success = GitHandler._run_git_command(
                    ['git', 'remote', 'set-head', 'origin', target_branch],
                    repo_dir
                )

                if success:
                    # Set local HEAD to the target branch
                    success = GitHandler._run_git_command(
                        ['git', 'symbolic-ref', 'HEAD', f'refs/heads/{target_branch}'],
                        repo_dir
                    )

                    if success:
                        Logger.info(f"Successfully repaired HEAD reference to {target_branch}")
                        return True

        # Fallback: try to use version as direct commit reference
        Logger.info("Trying to use version as direct reference...")
        success, output = GitHandler._capture_git_command(
            ['git', 'rev-parse', '--verify', f'{version}^{{commit}}'],
            repo_dir
        )

        if success and output.strip():
            commit_hash = output.strip()
            Logger.info(f"Found valid commit hash: {commit_hash}")

            # Update HEAD to point directly to the commit
            success = GitHandler._run_git_command(
                ['git', 'update-ref', 'HEAD', commit_hash],
                repo_dir
            )

            if success:
                Logger.info("Successfully updated HEAD reference to commit")
                return True

        Logger.warning("HEAD reference repair failed")
        return False

    @staticmethod
    def _refetch_remote_references(repo_dir, version, depth):
        """
        Re-fetch remote references with optimized strategy based on reference type.

        This method performs an optimized fetch of remote references, fetching only
        the specific tag or branch needed rather than all references.

        Args:
            repo_dir (Path): Repository directory
            version (str): Target version/branch/tag
            depth (int): Clone depth

        Returns:
            bool: True if remote references were successfully re-fetched, False otherwise
        """
        # Determine if the version is a tag
        is_tag = GitHandler._is_tag(repo_dir, version)

        # Build fetch command based on reference type
        if is_tag:
            cmd = ['git', 'fetch', 'origin', '--no-tags', 'tag', version]
            if depth:
                cmd.extend(['--depth', str(depth)])
        else:
            cmd = ['git', 'fetch', 'origin', '--no-tags', version]
            if depth:
                cmd.extend(['--depth', str(depth)])

        # Execute the fetch command
        success = GitHandler._run_git_command(cmd, repo_dir)

        if success:
            Logger.info("Successfully re-fetched remote references")
            return True
        else:
            Logger.warning("Re-fetching remote references failed")
            return False

    @staticmethod
    def _clean_and_reset_workspace(repo_dir, version):
        """
        Clean workspace and reset to specified version with hard reset.

        This method cleans untracked files and resets the working tree to the
        specified version, effectively discarding any local changes.

        Args:
            repo_dir (Path): Repository directory
            version (str): Target version/branch/tag

        Returns:
            bool: True if workspace was successfully cleaned and reset, False otherwise
        """
        # Clean untracked files
        clean_success = GitHandler._run_git_command(['git', 'clean', '-fd'], repo_dir)

        if not clean_success:
            Logger.warning("Cleaning untracked files failed")

        # Determine if the version is a tag
        is_tag = GitHandler._is_tag(repo_dir, version)

        # Reset to the appropriate reference
        if is_tag:
            reset_success = GitHandler._run_git_command(['git', 'reset', '--hard', version], repo_dir)
        else:
            reset_success = GitHandler._run_git_command(['git', 'reset', '--hard', 'FETCH_HEAD'], repo_dir)

        if reset_success:
            Logger.info("Successfully reset workspace")
            return True
        else:
            Logger.warning("Resetting workspace failed")
            return False

    @staticmethod
    def _rebuild_repository_infrastructure(repo_dir):
        """
        Rebuild Git repository infrastructure with re-initialization and fetching.

        This method performs a complete rebuild of the Git repository infrastructure
        by re-initializing the repository and fetching all remote references.

        Args:
            repo_dir (Path): Repository directory

        Returns:
            bool: True if repository infrastructure was successfully rebuilt, False otherwise
        """
        Logger.info("Attempting to rebuild repository infrastructure...")

        # Re-initialize the git repository
        success = GitHandler._run_git_command(['git', 'init'], repo_dir)

        if not success:
            Logger.warning("Re-initializing git repository failed")
            return False

        # Fetch all remote references
        success = GitHandler._run_git_command(['git', 'fetch', '--all'], repo_dir)

        if success:
            Logger.info("Successfully rebuilt repository infrastructure")
            return True
        else:
            Logger.warning("Rebuilding repository infrastructure failed")
            return False

    @staticmethod
    def _run_git_command(cmd, cwd=None):
        """
        Execute Git command with real-time output display and retry mechanism.

        This method executes a Git command with robust error handling and retry logic.
        It displays command output in real-time and will retry failed commands up to
        MAX_RETRIES times with a delay between attempts.

        Args:
            cmd (list): Git command and arguments as a list
            cwd (Path): Working directory for command execution

        Returns:
            bool: True if command executed successfully, False otherwise
        """
        for attempt in range(GitHandler.MAX_RETRIES):
            try:
                Logger.debug(f"Running git command: [bold green]{cmd}[/bold green]")
                # Execute the command with output capture
                p = subprocess.Popen(
                    cmd,
                    cwd=str(cwd) if cwd else None,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT
                )

                # Process output in real-time
                for line in iter(p.stdout.readline, b''):
                    decoded_line = line.decode('utf-8', errors='ignore').rstrip()
                    Logger.debug(f"{decoded_line}", markup=False)
                    if p.poll() is not None:
                        break

                # Check command exit status
                returncode = p.wait()
                if returncode == 0:
                    return True
                else:
                    # Retry with delay if attempts remain
                    if attempt < GitHandler.MAX_RETRIES - 1:
                        time.sleep(GitHandler.RETRY_DELAY)
                    else:
                        return False
            except Exception as e:
                Logger.exception(f"Error executing git command: {e}")
                # Retry with delay if attempts remain
                if attempt < GitHandler.MAX_RETRIES - 1:
                    time.sleep(GitHandler.RETRY_DELAY)
                else:
                    return False

    @staticmethod
    def _capture_git_command(cmd, cwd=None):
        """
        Execute Git command and capture output without real-time display.

        This method executes a Git command and captures its output for processing.
        It includes retry logic and error handling similar to _run_git_command
        but does not display output in real-time.

        Args:
            cmd (list): Git command and arguments as a list
            cwd (Path): Working directory for command execution

        Returns:
            tuple: (success, output) where success indicates command success
                   and output contains the captured command output
        """
        for attempt in range(GitHandler.MAX_RETRIES):
            try:
                Logger.debug(f"Running git command: [bold green]{cmd}[/bold green]")
                # Execute the command with output capture
                p = subprocess.Popen(
                    cmd,
                    cwd=str(cwd) if cwd else None,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True
                )

                # Capture command output
                stdout, stderr = p.communicate()
                output = stdout + stderr if stderr else stdout

                # Check command exit status
                if p.returncode == 0:
                    return True, output
                else:
                    # Retry with delay if attempts remain
                    if attempt < GitHandler.MAX_RETRIES - 1:
                        time.sleep(GitHandler.RETRY_DELAY)
                    else:
                        return False, output
            except Exception as e:
                Logger.exception(f"Error executing git command: {e}")
                # Retry with delay if attempts remain
                if attempt < GitHandler.MAX_RETRIES - 1:
                    time.sleep(GitHandler.RETRY_DELAY)
                else:
                    return False, ""

    @staticmethod
    def get_last_commit_time(repo_dir: Path) -> float:
        """
        Retrieve the timestamp of the most recent commit in a repository.

        This method queries the Git log to find the timestamp of the most recent
        commit in the repository, returned as a Unix timestamp.

        Args:
            repo_dir (Path): Repository directory to query for commit history

        Returns:
            float: Unix timestamp of the last commit, or 0 if unavailable
        """
        # Get the timestamp of the most recent commit
        cmd = ['git', 'log', '-1', '--format=%at']
        success, output = GitHandler._capture_git_command(cmd, repo_dir)
        if success:
            return float(output.strip())
        else:
            return 0

    @staticmethod
    def _force_delete_directory(path: Path) -> bool:
        """
        Forcefully delete a directory including read-only files with error handling.

        This method deletes a directory and all its contents, including files with
        read-only attributes. It uses a custom error handler to change file permissions
        before deletion if necessary.

        Args:
            path (Path): Directory path to delete

        Returns:
            bool: True if directory was successfully deleted, False otherwise
        """
        try:
            if not path.exists():
                return True

            # Define error handler for read-only files
            def remove_readonly(func, filepath, _):
                os.chmod(filepath, stat.S_IWRITE)
                func(filepath)

            # Recursively delete the directory
            shutil.rmtree(path, onerror=remove_readonly)
            return True
        except Exception as e:
            Logger.exception(f"Failed to delete directory: {path} - Error: {e}")
            return False

    @staticmethod
    def _repair_submodules(repo_dir, config):
        """
        Repair submodules by reinitializing failed or uninitialized submodules.

        This method identifies and repairs submodules that are not properly initialized
        or have become corrupted. It deletes problematic submodule directories and
        reinitializes them from scratch.

        Args:
            repo_dir (Path): Repository directory
            config (dict): Configuration containing depth settings

        Returns:
            bool: True if all submodules were successfully repaired, False otherwise
        """
        depth = config.get('depth')
        # Get submodule status
        success, output = GitHandler._capture_git_command(['git', 'submodule', 'status'], repo_dir)
        if not success:
            return False

        lines = output.splitlines()
        all_repaired = True

        # Process each submodule
        for line in lines:
            if line.startswith('-'):
                parts = line.split()
                if len(parts) < 2:
                    continue
                submodule_path = parts[1]
                Logger.info(f"Attempting to repair submodule: {submodule_path}")

                # Delete problematic submodule directory
                full_path = repo_dir / submodule_path
                if full_path.exists():
                    if not GitHandler._force_delete_directory(full_path):
                        Logger.error(f"Failed to delete submodule directory: {submodule_path}")
                        all_repaired = False
                        continue

                # Reinitialize the submodule
                init_cmd = ['git', 'submodule', 'update', '--init', '--force', '--checkout', submodule_path]
                if depth:
                    init_cmd.extend(['--depth', str(depth)])
                success = GitHandler._run_git_command(init_cmd, repo_dir)
                if not success:
                    Logger.error(f"Failed to reinitialize submodule: {submodule_path}")
                    all_repaired = False

        # Verify all submodules were repaired successfully
        if all_repaired:
            all_repaired = GitHandler._verify_submodules(repo_dir)

        return all_repaired

    @staticmethod
    def _is_submodule_issue(repo_dir):
        """
        Check if repository failure is primarily caused by submodule issues.

        This method examines the submodule status to determine if the primary
        cause of repository failure is related to submodule initialization or corruption.

        Args:
            repo_dir (Path): Repository directory

        Returns:
            bool: True if failure appears to be submodule-related, False otherwise
        """
        if not GitHandler.is_valid_repository(repo_dir):
            return False

        # Check submodule status for uninitialized submodules
        success, output = GitHandler._capture_git_command(['git', 'submodule', 'status'], repo_dir)
        if success:
            lines = output.splitlines()
            for line in lines:
                if line.startswith('-'):
                    return True
        return False

    @staticmethod
    def _verify_submodules(repo_dir):
        """
        Verify all submodules are correctly initialized and updated.

        This method checks the status of all submodules in the repository to ensure
        they are properly initialized and up-to-date.

        Args:
            repo_dir (Path): Repository directory

        Returns:
            bool: True if all submodules are properly initialized, False otherwise
        """
        # Get submodule status
        success, output = GitHandler._capture_git_command(['git', 'submodule', 'status'], repo_dir)
        if not success:
            return False

        # Check for uninitialized submodules
        lines = output.splitlines()
        for line in lines:
            if line.startswith('-'):
                Logger.error(f"Submodule not initialized: {line}")
                return False
        return True
