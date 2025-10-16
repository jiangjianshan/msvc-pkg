# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import os
from graphlib import TopologicalSorter, CycleError
from collections import deque
from pathlib import Path
from rich.tree import Tree
from rich.text import Text

from mpt.core.config import LibraryConfig
from mpt.core.log import RichLogger
from mpt.core.view import RichTable, RichPanel


class DependencyResolver:
    """
    Advanced dependency resolution system with support for required and optional dependencies.

    Provides comprehensive dependency management including parsing, graph construction,
    topological sorting, visualization, and resolution with build integration. Handles
    complex dependency relationships and circular dependency detection.
    """

    @staticmethod
    def parse_dependency_name(dep_name):
        """
        Parse dependency specification into library name and dependency type components.

        Extracts library name and dependency type from formatted dependency strings
        that may include type specifiers (e.g., "library:required" or "library:optional").

        Args:
            dep_name (str): Dependency specification string in format "lib:type" or "lib"

        Returns:
            tuple: (library_name, dependency_type) where type can be 'required', 'optional', 
                   or None if no type specified
        """
        try:
            if ':' in dep_name:
                lib_name, dep_type = dep_name.split(':', 1)
                return lib_name.strip(), dep_type.strip()
            return dep_name, None
        except Exception as e:
            RichLogger.exception(f"Failed to parse dependency name '{dep_name}': {str(e)}")
            raise

    @staticmethod
    def get_dependencies(lib_name, dep_type=None):
        """
        Retrieve dependencies for a library with optional type filtering.

        Loads library configuration and extracts dependency information, supporting
        filtering by dependency type (required, optional) or returning all dependencies.

        Args:
            lib_name (str): Name of the library to query for dependencies
            dep_type (str): Optional dependency type filter ('required' or 'optional')

        Returns:
            list: List of dependency specifications (e.g., ["dirent", "pcre:required"])
        """
        try:
            config = LibraryConfig.load(lib_name)
            if not config:
                RichLogger.error(f"[[bold cyan]{lib_name}[/bold cyan]] Failed to load library configuration")
                return []

            deps = config.get('dependencies', {}) or {}

            if dep_type is None:
                # Return all dependencies: required + optional
                required_deps = deps.get('required', []) or []
                optional_deps = deps.get('optional', []) or []
                return required_deps + optional_deps
            else:
                # Return dependencies for the specific type
                return deps.get(dep_type, []) or []
        except Exception as e:
            RichLogger.exception(f"Failed to get dependencies for library '{lib_name}' with type '{dep_type}': {str(e)}")
            return []

    @staticmethod
    def build_tree(root):
        """
        Construct a complete dependency graph starting from a root node.

        Performs breadth-first traversal of dependency relationships to build a
        comprehensive graph representation of all transitive dependencies. Handles
        both typed and untyped dependency specifications.

        Args:
            root (str): Root dependency specification to start graph construction

        Returns:
            dict: Dependency graph where keys are node names and values are sets
                  of direct dependencies for each node
        """
        graph = {}
        visited = set()
        queue = deque([root])

        try:
            while queue:
                current_node = queue.popleft()
                if current_node in visited:
                    continue
                visited.add(current_node)

                lib_name, dep_type = DependencyResolver.parse_dependency_name(current_node)
                dependencies = DependencyResolver.get_dependencies(lib_name, dep_type)

                graph[current_node] = set(dependencies)

                for dep in dependencies:
                    if dep not in visited:
                        queue.append(dep)
        except Exception as e:
            RichLogger.exception(f"Failed to build dependency tree for root '{root}': {str(e)}")
            raise

        return graph

    @staticmethod
    def topological_sort(root, graph):
        """
        Perform topological sorting on a dependency graph to determine build order.

        Uses Kahn's algorithm (via graphlib.TopologicalSorter) to establish a valid
        processing order that respects all dependency constraints. Detects and reports
        circular dependencies that would prevent valid ordering.

        Args:
            root (str): Root library name for logging and identification
            graph (dict): Dependency graph to sort

        Returns:
            list: Topologically sorted list of node names in valid processing order

        Raises:
            CycleError: If a circular dependency is detected in the graph
        """
        try:
            ts = TopologicalSorter(graph)
            order = list(ts.static_order())

            # Create order table
            order_table = RichTable.create(
                title=f"[[bold cyan]{root}[/bold cyan]] Topological Order",
                show_header=True,
                header_style="bold cyan"
            )
            RichTable.add_column(order_table, "Step", style="cyan", justify="right", no_wrap=True)
            RichTable.add_column(order_table, "Library", style="bold yellow")

            # Add rows
            for i, node in enumerate(order, 1):
                RichTable.add_row(order_table, str(i), node)

            # Render table
            RichTable.render(order_table)

            return order
        except CycleError as e:
            RichLogger.exception(f"[[bold cyan]{root}[/bold cyan]] Cycle detected: {str(e)}")
            raise
        except Exception as e:
            RichLogger.exception(f"Failed to perform topological sort for root '{root}': {str(e)}")
            raise

    @staticmethod
    def render_tree(root, graph):
        """
        Generate and display a visual representation of the dependency tree.

        Creates a rich-formatted tree structure using Unicode characters and color
        coding to visualize dependency relationships. Uses different icons for nodes
        with and without children to improve readability.

        Args:
            root (str): Root library name for tree labeling
            graph (dict): Dependency graph to visualize
        """
        RichLogger.info(f"[[bold cyan]{root}[/bold cyan]] Rendering dependency tree with [bold yellow]{len(graph)}[/bold yellow] nodes")

        try:
            # Create tree structure
            tree = Tree(f"🌳 [bold green]{root}[/bold green]", guide_style="dim")
            visited = set()
            queue = deque([(root, tree, 0)])

            while queue:
                node_name, parent_node, depth = queue.popleft()
                if node_name in visited:
                    continue
                visited.add(node_name)

                dependencies = graph.get(node_name, set())
                for dep_node in dependencies:
                    # Check if the dependency has children
                    has_children = dep_node in graph and graph[dep_node] and dep_node not in visited

                    # Choose icon
                    icon = "🌿" if has_children else "🍃"

                    # Parse node name
                    lib_name, dep_type = DependencyResolver.parse_dependency_name(dep_node)

                    # Format display name
                    if dep_type:
                        display_name = f"{icon} {lib_name}:{dep_type}"
                    else:
                        display_name = f"{icon} {lib_name}"

                    # Create child node
                    node = parent_node.add(Text(display_name, style="bold" if depth < 2 else ""))

                    if has_children:
                        queue.append((dep_node, node, depth + 1))

            RichLogger.print(tree)
        except Exception as e:
            RichLogger.exception(f"Failed to render dependency tree for root '{root}': {str(e)}")

    @staticmethod
    def resolve(root, arch, build=False):
        """
        Complete dependency resolution process with optional build execution.

        Coordinates the full dependency resolution workflow including graph construction,
        visualization, topological sorting, and conditional build execution. Provides
        comprehensive error handling and logging throughout the process.

        Args:
            root (str): Root library specification to resolve dependencies for
            arch: Target architecture for any build operations
            build (bool): If True, execute build process for resolved dependencies

        Returns:
            bool: True if resolution (and optional build) completed successfully,
                  False if any error occurred during the process
        """
        try:
            # Build dependency tree for the root
            graph = DependencyResolver.build_tree(root)
            DependencyResolver.render_tree(root, graph)
            order = DependencyResolver.topological_sort(root, graph)

            if build:
                for node_name in order:
                    lib_name, dep_type = DependencyResolver.parse_dependency_name(node_name)
                    config = LibraryConfig.load(lib_name)
                    if not config:
                        RichLogger.error(f"[[bold cyan]{root}[/bold cyan]] Failed to load configuration for [bold cyan]{lib_name}[/bold cyan]")
                        return False

                    from mpt.core.build import BuildManager
                    success = BuildManager.build_library(node_name, arch, config)
                    if not success:
                        RichLogger.error(f"[[bold cyan]{root}[/bold cyan]] Build failed for [bold cyan]{node_name}[/bold cyan]")
                        return False

            return True
        except CycleError as e:
            RichLogger.exception(f"[[bold cyan]{root}[/bold cyan]] Cycle detected during resolution: {str(e)}")
            return False
        except Exception as e:
            RichLogger.exception(f"[[bold cyan]{root}[/bold cyan]] Dependency resolution failed: {str(e)}")
            return False
