# -*- coding: utf-8 -*-
"""
File download handler with robust retry mechanisms and progress tracking.
Provides comprehensive error handling and resume support for HTTP downloads.

Copyright (c) 2024 Jianshan Jiang

"""
import os
import random
import requests
import requests.exceptions
import ssl
import time

from pathlib import Path
from requests.adapters import HTTPAdapter
from rich.progress import Progress, TextColumn, BarColumn, DownloadColumn, TransferSpeedColumn, TimeRemainingColumn
from rich.text import Text
from urllib.parse import urlparse
from urllib3.util.retry import Retry
from urllib3.exceptions import InsecureRequestWarning

from mpt.core.log import RichLogger
from mpt.core.view import RichPanel, RichTable
from mpt.utils.file import FileUtils

# Suppress insecure request warnings
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)


class DownloadHandler:
    """
    Advanced file download handler with robust retry mechanisms and progress tracking.

    Provides comprehensive HTTP download capabilities with resumable downloads,
    SSL verification options, and sophisticated error handling. Mimics wget behavior
    for maximum compatibility with various web servers and content delivery networks.
    """

    # Configuration constants
    MAX_RETRIES = 3
    BACKOFF_FACTOR = 0.1
    STATUS_FORCELIST = [408, 429, 500, 502, 503, 504]  # HTTP status codes that should trigger a retry
    CONNECT_TIMEOUT = 30  # Seconds for connection establishment
    READ_TIMEOUT = 60     # Seconds for server response
    CHUNK_SIZE = 8192 * 10  # 80KB chunks for efficient streaming

    # Class variables to track download state across retries
    _expected_size = None
    _supports_partial = None

    @classmethod
    def _log_request_and_response(cls, response):
        """
        Log detailed HTTP request and response information in formatted tables.

        Captures and displays actual request headers, server response headers,
        HTTP version, status codes, and redirect history for debugging and
        transparency purposes.

        Args:
            response: HTTP response object containing request and response metadata
        """
        cls._print_headers_table("Actual Request Headers", response.request.headers)
        cls._print_headers_table("Server Response Headers", response.headers)
        RichLogger.debug(f"HTTP version: [bold cyan]{response.raw.version}[/bold cyan], "
                     f"Status code: [bold cyan]{response.status_code}[/bold cyan], "
                     f"Reason: [bold cyan]{response.reason}[/bold cyan]")

        # Log redirect history if any
        if response.history:
            RichLogger.info(f"Found [bold cyan]{len(response.history)}[/bold cyan] redirects")
            redirect_table = RichTable.create(title="[bold]Redirect History[/bold]")
            redirect_table.add_column("Step", style="dim", width=5)
            redirect_table.add_column("Status", style="bold", width=10)
            redirect_table.add_column("URL", style="bold cyan")
            for i, redirect in enumerate(response.history):
                redirect_table.add_row(
                    str(i + 1),
                    str(redirect.status_code),
                    redirect.url
                )
            RichTable.render(redirect_table)
        RichLogger.info(f"Final URL: [bold cyan]{response.url}[/bold cyan]")

    @classmethod
    def _print_headers_table(cls, title, headers):
        """
        Display HTTP headers in a formatted table with truncation for long values.

        Creates a rich-formatted table to visualize header key-value pairs,
        automatically truncating excessively long values for readability while
        preserving essential information.

        Args:
            title: Descriptive title for the headers table
            headers: Dictionary of HTTP headers to display
        """
        table = RichTable.create(title=f"[bold]{title}[/]")
        table.add_column("Header", style="bold cyan", no_wrap=True)
        table.add_column("Value", style="green")

        for key, value in headers.items():
            display_value = value if len(value) < 80 else value[:77] + "..."
            table.add_row(key, display_value)
        RichTable.render(table)

    @classmethod
    def download_file(cls, url, file_path, verify_ssl=False):
        """
        Execute a robust file download with comprehensive error handling and resume support.

        Implements a sophisticated download algorithm with exponential backoff retry strategy,
        partial content resumption, and progress tracking. Supports both HTTP and HTTPS protocols
        with configurable SSL verification.

        Args:
            url: Source URL for the file download
            file_path: Local filesystem path where the downloaded file should be saved
            verify_ssl: Boolean indicating whether to verify SSL certificates (default: False)

        Returns:
            bool: True if download completed successfully, False if all retry attempts failed

        Algorithm:
        1. Set up retry strategy with exponential backoff for transient failures
        2. Create HTTP session with mounted adapters for both HTTP and HTTPS
        3. Make HTTP GET request with streaming and appropriate headers
        4. Handle different HTTP status codes (200 OK, 206 Partial Content)
        5. Support resuming interrupted downloads using Range headers
        6. Validate downloaded file size against expected content length
        7. Implement retry mechanism with increasing wait times between attempts
        """
        # Ensure parent directory exists
        file_path.parent.mkdir(parents=True, exist_ok=True)
        success = False
        retry_count = 0

        # Configure retry strategy
        retry_strategy = Retry(
            total=cls.MAX_RETRIES,
            backoff_factor=cls.BACKOFF_FACTOR,
            status_forcelist=cls.STATUS_FORCELIST,
            allowed_methods=["GET", "HEAD"],
            respect_retry_after_header=True
        )

        # Create HTTP adapter with retry strategy
        adapter = HTTPAdapter(max_retries=retry_strategy)

        with requests.Session() as session:
            # Mount adapters for both HTTP and HTTPS
            session.mount('http://', adapter)
            session.mount('https://', adapter)

            # Reset class variables for new download
            cls._expected_size = None
            cls._supports_partial = None

            # Retry loop
            while retry_count <= cls.MAX_RETRIES and not success:
                progress = None
                task = None
                RichLogger.debug(f"Attempt [bold cyan]{retry_count + 1}[/bold cyan] of "
                             f"[bold cyan]{cls.MAX_RETRIES + 1}[/bold cyan]")

                try:
                    # Get current downloaded size before making request
                    downloaded_size = cls._get_download_size(file_path)

                    # Set up headers for request
                    headers = cls._get_wget_headers()

                    # Add Range header if we have partial content and server supports resume
                    if downloaded_size > 0 and cls._supports_partial:
                        headers["Range"] = f"bytes={downloaded_size}-"
                        if cls._expected_size:
                            headers["Range"] = f"bytes={downloaded_size}-{cls._expected_size}"
                        RichLogger.debug(f"Setting Range header: [bold cyan]{headers['Range']}[/bold cyan]")

                    # Make HTTP GET request with streaming
                    with session.get(
                        url,
                        headers=headers,
                        stream=True,
                        timeout=(cls.CONNECT_TIMEOUT, cls.READ_TIMEOUT),
                        allow_redirects=True,
                        verify=verify_ssl
                    ) as response:
                        # Log request/response details
                        cls._log_request_and_response(response)

                        # Update class variables with response information
                        cls._expected_size = cls._get_expected_size(response)
                        cls._supports_partial = cls._is_partial(response)

                        response.raise_for_status()
                        """
                        100: continue
                        101: switching_protocols
                        102: processing
                        103: checkpoint
                        122: uri_too_long, request_uri_too_long
                        200: ok, okay, all_ok, all_okay, all_good
                        201: created
                        202: accepted
                        203: non_authoritative_info, non_authoritative_information
                        204: no_content
                        205: reset_content, reset
                        206: partial_content, partial
                        207: multi_status, multiple_status, multi_stati, multiple_stati
                        208: already_reported
                        226: im_used
                        300: multiple_choices
                        301: moved_permanently, moved
                        302: found
                        303: see_other, other
                        304: not_modified
                        305: use_proxy
                        306: switch_proxy
                        307: temporary_redirect, temporary_moved, temporary
                        308: permanent_redirect, resume_incomplete, resume
                        400: bad_request, bad
                        401: unauthorized
                        402: payment_required, payment
                        403: forbidden
                        404: not_found
                        405: method_not_allowed, not_allowed
                        406: not_acceptable
                        407: proxy_authentication_required, proxy_auth, proxy_authentication
                        408: request_timeout, timeout
                        409: conflict
                        410: gone
                        411: length_required
                        412: precondition_failed, precondition
                        413: request_entity_too_large
                        414: request_uri_too_large
                        415: unsupported_media_type, unsupported_media, media_type
                        416: requested_range_not_satisfiable, requested_range, range_not_satisfiable
                        417: expectation_failed
                        418: im_a_teapot, teapot, i_am_a_teapot
                        421: misdirected_request
                        422: unprocessable_entity, unprocessable
                        423: locked
                        424: failed_dependency, dependency
                        425: unordered_collection, unordered
                        428: precondition_required, precondition
                        431: header_fields_too_large, fields_too_large
                        449: retry_with, retry
                        451: unavailable_for_legal_reasons, legal_reasons
                        500: internal_server_error, server_error
                        502: bad_gateway
                        504: gateway_timeout
                        506: variant_also_negotiates
                        509: bandwidth_limit_exceeded, bandwidth
                        511: network_authentication_required, network_auth, network_authentication
                        """
                        # Get expected file size
                        if cls._expected_size:
                            RichLogger.debug(f"Expected file size: "
                                         f"[bold cyan]{cls._format_bytes(cls._expected_size, plain=True)}[/bold cyan]")

                        # Determine file mode based on response status
                        file_mode = 'wb'
                        if response.status_code == requests.codes.ok:
                            if downloaded_size > 0:
                                RichLogger.debug(f"Restarting download from beginning. "
                                             f"Existing file size: [bold cyan]{downloaded_size}[/bold cyan] bytes")
                                FileUtils.delete_file(file_path)
                                # Reset downloaded size after deletion
                                downloaded_size = 0
                        elif response.status_code == requests.codes.partial_content:
                            RichLogger.debug(f"Resuming download from position: "
                                         f"[bold cyan]{downloaded_size}[/bold cyan] bytes")
                            file_mode = 'ab'
                        else:
                            RichLogger.warning(f"Unexpected status code: "
                                           f"[bold cyan]{response.status_code}[/bold cyan]")
                            retry_count += 1
                            continue

                        # Create progress bar with accurate starting position
                        progress = cls._create_progress_bar()
                        task = progress.add_task(
                            f"[bold blue]Downloading[/bold blue] [cyan]{Path(url).name}[/cyan]",
                            total=cls._expected_size,
                            completed=downloaded_size  # Start from current downloaded position
                        )
                        progress.start()

                        # Download content with progress tracking
                        success = cls._get_content(
                            response,
                            file_path,
                            file_mode,
                            progress,
                            task,
                            downloaded_size,
                            cls._expected_size
                        )

                        # Verify download size
                        final_size = cls._get_download_size(file_path)
                        if success:
                            if cls._expected_size and final_size != cls._expected_size:
                                RichLogger.warning(f"Download incomplete: expected "
                                               f"[bold cyan]{cls._expected_size}[/bold cyan], "
                                               f"got [bold cyan]{final_size}[/bold cyan]")
                                success = False
                                retry_count += 1
                            else:
                                RichLogger.info("Download completed successfully")
                                break
                        else:
                            retry_count += 1

                except requests.exceptions.HTTPError as e:
                    RichLogger.warning(f"HTTP Error: [bold cyan]{str(e)}[/bold cyan]")
                    retry_count += 1
                except requests.exceptions.ConnectTimeout as e:
                    RichLogger.warning(f"Connect Timeout Error: [bold cyan]{str(e)}[/bold cyan]")
                    retry_count += 1
                except requests.exceptions.ConnectionError as e:
                    RichLogger.warning(f"Connection Error: [bold cyan]{str(e)}[/bold cyan]")
                    retry_count += 1
                except requests.exceptions.Timeout as e:
                    RichLogger.warning(f"Timeout Error: [bold cyan]{str(e)}[/bold cyan]")
                    retry_count += 1
                except requests.exceptions.RequestException as e:
                    RichLogger.warning(f"Request Exception: [bold cyan]{str(e)}[/bold cyan]")
                    retry_count += 1
                except Exception as e:
                    RichLogger.error(f"Unexpected error during download attempt: {str(e)}")
                    retry_count += 1
                finally:
                    # Ensure progress bar is stopped after each attempt
                    if progress:
                        progress.stop()

                # Add wait time before next retry
                if retry_count <= cls.MAX_RETRIES and not success:
                    wait_time = random.randint(2, 6)
                    RichLogger.info(f"Retrying in [bold cyan]{wait_time}[/bold cyan] seconds "
                                f"(attempt [bold cyan]{retry_count}[/bold cyan]/"
                                f"[bold cyan]{cls.MAX_RETRIES}[/bold cyan])")
                    time.sleep(wait_time)

        return success

    @classmethod
    def _get_expected_size(cls, response):
        """
        Extract the expected file size from HTTP response headers using multiple strategies.

        Attempts to determine the complete file size by examining various headers in order:
        1. Content-Range header for partial content responses
        2. Content-Length header for standard responses
        3. Alternative headers used by specific CDNs (Google Cloud, AWS S3)

        Args:
            response: HTTP response object containing headers with size information

        Returns:
            int: Expected file size in bytes, or None if size information is unavailable
        """
        # Try to get size from Content-Range if available
        if 'Content-Range' in response.headers:
            # see https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Range
            # syntax:
            #  Content-Range: <unit> <range-start>-<range-end>/<size>
            #  Content-Range: <unit> <range-start>-<range-end>/*
            #  Content-Range: <unit> */<size>
            # e.g. Content-Range: bytes 14204624-31962046/31962047
            try:
                content_range = response.headers['Content-Range']
                RichLogger.debug(f"Found Content-Range header: [bold cyan]{content_range}[/bold cyan]")
                # Format: bytes 0-999/1000
                if '/' in content_range:
                    total_size = content_range.split('/')[-1]
                    if total_size != '*':
                        size = int(total_size)
                        RichLogger.debug(f"Parsed size from Content-Range: "
                                     f"[bold cyan]{size}[/bold cyan] bytes")
                        return size
            except (ValueError, TypeError, IndexError) as e:
                RichLogger.debug(f"Failed to parse Content-Range: [bold cyan]{e}[/bold cyan]")

        # Try to get Content-Length
        if 'Content-Length' in response.headers:
            try:
                size = int(response.headers['Content-Length'])
                RichLogger.debug(f"Found Content-Length header: [bold cyan]{size}[/bold cyan] bytes")
                return size
            except (ValueError, TypeError) as e:
                RichLogger.debug(f"Failed to parse Content-Length: [bold cyan]{e}[/bold cyan]")

        # Try alternative headers
        for header in ['X-Goog-Stored-Content-Length', 'x-amz-meta-size']:
            if header in response.headers:
                try:
                    size = int(response.headers[header])
                    RichLogger.debug(f"Found {header} header: [bold cyan]{size}[/bold cyan] bytes")
                    return size
                except (ValueError, TypeError) as e:
                    RichLogger.debug(f"Failed to parse {header}: [bold cyan]{e}[/bold cyan]")

        RichLogger.debug("No file size information found in response headers")
        return None

    @classmethod
    def _is_partial(cls, response):
        """
        Determine if the server supports partial content requests (byte ranges).

        Examines the Accept-Ranges header to check if the server supports resumable
        downloads, which enables efficient recovery from interrupted transfers.

        Args:
            response: HTTP response object containing server capability information

        Returns:
            bool: True if server supports partial content, False otherwise
        """
        supports_partial = ("Accept-Ranges" in response.headers and
                            response.headers.get('Accept-Ranges') == "bytes")
        RichLogger.debug(f"Server supports partial content: [bold cyan]{supports_partial}[/bold cyan]")
        return supports_partial

    @classmethod
    def _get_download_size(cls, file_path):
        """
        Retrieve the current size of a partially downloaded file.

        Checks the filesystem for an existing file and returns its size, which is
        essential for determining the resume position for interrupted downloads.

        Args:
            file_path: Path to the potentially partially downloaded file

        Returns:
            int: File size in bytes (0 if file doesn't exist)
        """
        if file_path.exists():
            size = file_path.stat().st_size
            RichLogger.debug(f"Existing file size: [bold cyan]{size}[/bold cyan] bytes")
            return size
        RichLogger.debug("File does not exist, starting from 0 bytes")
        return 0

    @classmethod
    def _get_content(cls, response, file_path, file_mode, progress, task, resume_position, expected_size):
        """
        Stream and save HTTP response content with progress tracking and validation.

        Handles the actual data transfer from the HTTP response to the local filesystem,
        updating a progress bar in real-time and ensuring data integrity through
        size validation.

        Args:
            response: HTTP response object with the content stream
            file_path: Local path where content should be saved
            file_mode: File opening mode ('wb' for write, 'ab' for append)
            progress: Rich Progress object for visual feedback
            task: Progress task identifier for updating the display
            resume_position: Byte position to resume downloading from
            expected_size: Expected total size of the complete file

        Returns:
            bool: True if content was successfully downloaded and saved, False otherwise
        """
        downloaded = 0
        with open(file_path, file_mode) as file:
            # Use raw stream to avoid automatic decompression
            for chunk in response.raw.stream(cls.CHUNK_SIZE, decode_content=False):
                if chunk:
                    file.write(chunk)
                    downloaded += len(chunk)
                    # Update progress bar with accurate position
                    current_position = resume_position + downloaded
                    progress.update(task, completed=current_position)

        # Ensure progress bar reaches 100% when download completes
        if expected_size is not None:
            progress.update(task, completed=expected_size)
        return True

    @classmethod
    def _get_wget_headers(cls):
        """
        Generate HTTP headers that mimic the wget command-line tool behavior.

        Creates a set of headers that emulate wget's request characteristics to
        improve compatibility with servers that may treat different user agents
        differently or impose restrictions on automated downloads.

        Returns:
            dict: Dictionary of HTTP headers mimicking wget's request pattern
        """
        headers = {
            'User-Agent': "Wget/1.21.4",
            'Accept': "*/*",
            'Accept-Encoding': "identity",
            'Connection': "Keep-Alive",
        }
        return headers

    @classmethod
    def _create_progress_bar(cls):
        """
        Create a visually appealing progress bar for download tracking.

        Constructs a Rich Progress object with customized columns and styling
        that provides real-time feedback on download speed, progress percentage,
        and estimated time remaining.

        Returns:
            Progress: Configured Rich Progress object with download-specific columns
        """
        return Progress(
            "[progress.percentage]{task.percentage:>3.0f}%",
            BarColumn(
                bar_width=None,  # Use full available width
                style="bright_black on bright_black",  # Set both foreground and background to same color
                complete_style="bold bright_green on bright_green",  # Solid green for completed part
                finished_style="bold bright_green on bright_green"   # Solid green for finished
            ),
            "•",
            DownloadColumn(),
            "•",
            TransferSpeedColumn(),
            expand=True,
            transient=True
        )

    @classmethod
    def _format_bytes(cls, size, plain=False):
        """
        Convert byte count into human-readable format with appropriate units.

        Transforms raw byte values into formatted strings with automatic unit
        selection (B, KB, MB, GB, TB) and precision-appropriate decimal formatting.

        Args:
            size: Raw byte count to format
            plain: If True, returns unformatted text without Rich styling

        Returns:
            str: Human-readable representation of the byte count
        """
        if size is None or size <= 0:
            return "0B"
        units = ['B', 'KB', 'MB', 'GB', 'TB']
        i = 0
        while size >= 1024 and i < len(units) - 1:
            size /= 1024
            i += 1

        # Fix the display issue by rounding to 1 decimal place for KB
        if i == 1:  # KB unit
            formatted_size = f"{size:.1f}"
        else:
            formatted_size = f"{size:.2f}"

        if plain:
            return f"{formatted_size} {units[i]}"
        return f"[bold yellow]{formatted_size}[/bold yellow] [bold]{units[i]}[/bold]"
