#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright (c) 2024 Jianshan Jiang
#

import argparse
import logging
import os
import re
import shlex
import subprocess
import sys
import yaml

from collections import deque
from datetime import datetime
from rich import print
from rich.console import Console
from rich.logging import RichHandler
from rich.pretty import pprint
from rich.table import Table
from rich.theme import Theme
from rich.tree import Tree as RichTree
from rich.traceback import install
from typing import List
from yaml import SafeDumper

class Node:
    """
    Definition for a node in an N-ary tree.
    Each node contains a value and a list of its children.
    """
    def __init__(self, pkg, step, children=None):
        self.value = pkg
        self.step = step
        self.children = children if children is not None else []

    def add_child(self, child_node):
        """
        Add child node into current node
        """
        self.children.append(child_node)


def get_value(node: Node):
    """
    Gets the value of a given node in an N-ary tree.
    """
    if node is None:
        return None
    return node.value


def get_step(node: Node):
    """
    Gets the step of a given node in an N-ary tree.
    """
    if node is None:
        return 'a'
    return node.step


def build_tree(root: Node, pkg, step):
    """
    Build dependencies tree recursively accoding to config.yaml on each package
    """
    conf_file = os.path.join(pkgs_dir, pkg, "config.yaml")
    with open(conf_file, 'r', newline='', encoding="utf-8") as f:
        pkg_conf = yaml.safe_load(f)
        if pkg_conf['steps'][step]['dependencies']:
            for dep_with_step in pkg_conf['steps'][step]['dependencies']:
                dep_with_step = dep_with_step.split(':')
                dep = dep_with_step[0]
                if len(dep_with_step) > 1:
                    dep_step = dep_with_step[1]
                else:
                    dep_step = 'a'
                if not contains_node(root, dep, dep_step):
                    # TODO: If one node has been included at upper level, and another node
                    #       at lower level need it as dependency. Then may cause that node
                    #       compile process failed. There is one solution but not good is
                    #       to put dependencies of packages carefully in config.yaml.
                    insert_node(root, pkg, dep, dep_step)
                    build_tree(root, dep, dep_step)


def insert_node(root: Node, parent_value, new_value, step):
    """
    Inserts a new node with value 'new_value' under the parent node with value 'parent_value'.
    """
    if root is None:
        return None
    if root.value == parent_value:
        if not any(child.value == new_value and child.step == step for child in root.children):
            root.add_child(Node(new_value, step))
        return root
    for child in root.children:
        result = insert_node(child, parent_value, new_value, step)
        if result is not None:
            return result
    return None


def contains_node(root: Node, value, step):
    """
    Checks if the tree contains a node with the given value and step.
    """
    if root is None:
        return False
    if root.value == value and root.step == step:
        return True
    for child in root.children:
        if contains_node(child, value, step):
            return True
    return False


def level_order(root: Node, reverse=False):
    """
    Perform level order traversal on an N-ary tree and return a list of node values.
    :type reverse: Boolean
    :rtype: List[Node]
    """
    if root is None:
        return []
    result = []
    queue = deque([root])
    # Iterate as long as there are nodes to process.
    while queue:
        level_nodes = []
        # Iterate over all nodes at the current level.
        for _ in range(len(queue)):
            current_node = queue.popleft()
            level_nodes.append(current_node)
            queue.extend(current_node.children)
        result.append(level_nodes)
    if reverse:
        return result[::-1]
    return result


def print_tree(root: Node, rich_tree=None):
    """
    Pretty print dependencies tree under root node
    """
    if rich_tree is None:
        rich_tree = RichTree(str(root.value), guide_style="bold bright_blue")
    for child in root.children:
        child_tree = rich_tree.add(str(child.value), guide_style="bold bright_blue")
        print_tree(child, child_tree)
    return rich_tree


def create_dirs(folders):
    """
    Create folders according to input list
    """
    for name in folders:
        folder = os.path.join(root_dir, name)
        if not os.path.exists(folder):
            os.makedirs(folder)


def get_newer_files(path, ref_time, matched, file_types=['.exe','.dll', '.lib']):
    """
    Check whether has newer files with filter
    """
    with os.scandir(path) as it:
        for entry in it:
            if not entry.name.startswith('.'):
                if entry.is_symlink():
                    continue
                elif entry.is_file():
                    file_name = entry.name
                    file_ext = os.path.splitext(file_name)[1]
                    if file_ext in file_types:
                        last_modified = datetime.fromtimestamp(entry.stat().st_mtime)
                        if last_modified > ref_time:
                            matched.append(file_name)
                elif entry.is_dir():
                    get_newer_files(entry.path, ref_time, matched, file_types)
    return matched


def configure_envars(proc_env, arch, pkg):
    """
    Configure environment variables that will be used for each packages
    """
    logger.debug(f"Configuring environment variables for package '{pkg}'")
    proc_env['ARCH'] = arch
    proc_env['ROOT_DIR'] = root_dir
    prefix = os.path.join(root_dir, arch)
    prefix_path = os.path.join(root_dir, arch)
    # PREFIX_PATH
    if settings_conf:
        if arch in settings_conf['prefix'].keys() and settings_conf['prefix'][arch]:
            for p in settings_conf['prefix'][arch].keys():
                pkg_prefix = settings_conf['prefix'][arch][p]
                if p == pkg:
                    prefix = pkg_prefix
                prefix_env = p.replace('-','_').upper() + '_PREFIX'
                proc_env[prefix_env] = pkg_prefix
                if pkg_prefix not in prefix_path:
                    prefix_path += os.pathsep + pkg_prefix
    # bin
    bin_path = proc_env['PATH']
    for p in prefix_path.split(os.pathsep):
        _p = os.path.join(p, 'bin')
        if os.path.exists(_p) and (_p not in bin_path):
            bin_path += os.pathsep + _p
    proc_env['PATH'] = bin_path
    proc_env['PREFIX_PATH'] = prefix_path
    proc_env['PREFIX'] = prefix
    return prefix


def execute(proc_env, commands, shell=False):
    """
    """
    err_list = ['Cannot', 'No such file', 'Error:', 'error:', ': error', ' Error ', 'syntax error', 'Failed', 'FAILED:', 'fatal:', 'fatal error']
    warn_list = ['Warning:', 'warning:', ': warning', ' Warning ']
    p = subprocess.Popen(commands, shell=shell, env=proc_env,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    with p.stdout:
        for line in iter(p.stdout.readline, b''):
            stdout_line = line.decode('utf-8', 'ignore').rstrip()
            if any(ele in stdout_line for ele in warn_list):
                logger.warning(stdout_line)
            elif any(ele in stdout_line for ele in err_list):
                logger.error(stdout_line)
            else:
                logger.info(stdout_line)
            if p.poll() is not None:
                break
    exit_code = p.wait()
    logger.debug(f"Process exit code: {exit_code}")
    return exit_code


def run_script(proc_env, pkgs_dir, pkg, file_name):
    """
    Run script .bat or .sh from config.yaml that has been defined in the package
    """
    os.chdir(os.path.join(pkgs_dir, pkg))
    result = False
    script = os.path.join(pkgs_dir, pkg, file_name)
    if os.path.exists(script):
        if file_name.endswith('.bat'):
            commands = [file_name]
        elif file_name.endswith('.sh'):
            commands = ['C:/Program Files/Git/bin/bash.exe', file_name]
        if execute(proc_env, commands, False):
            logger.error(f"Build {pkg} failed")
        else:
            result = True
    os.chdir(root_dir)
    return result


def compare_version(current, previous):
    """
    """
    if '.' in current and '.' in previous:
        v1 = list(map(int, current.split('.')))
        v2 = list(map(int, previous.split('.')))
    elif '-' in current and '-' in previous:
        v1 = list(map(int, current.split('-')))
        v2 = list(map(int, previous.split('-')))
    elif '_' in current and '_' in previous:
        v1 = list(map(int, current.split('_')))
        v2 = list(map(int, previous.split('_')))
    else:
        v1 = current
        v2 = previous
    if v1 > v2:
        return 1
    elif v1 < v2:
        return -1
    else:
        return 0

def build_decision(arch, pkg, pkg_conf, installed_conf, step):
    """
    """
    logger.debug(f"Checking build decision for package '{pkg}'")
    pkg_name = pkg_conf['name']
    pkg_ver = str(pkg_conf['version'])
    pkg_url = pkg_conf['url']
    if not installed_conf:
        logger.debug(f"Whole packages were not built yet")
        return True
    elif arch not in installed_conf.keys():
        logger.debug(f"ARCH '{arch}' was not built yet")
        return True
    elif not pkg in installed_conf[arch].keys():
        logger.debug(f"Package '{pkg}' was not built yet")
        return True
    elif 'step' in installed_conf[arch][pkg]:
        built_step = installed_conf[arch][pkg]['step']
        if built_step < step:
            logger.debug(f"Current step of {pkg} wasn't built yet")
            return True
    else:
        matched = []
        installed_ver = str(installed_conf[arch][pkg]['version'])
        built_time = installed_conf[arch][pkg]['built']
        logger.debug(f"{'Built time' : <29}: {built_time}")
        if compare_version(pkg_ver, installed_ver) > 0:
            logger.debug(f"There is a newer version of package '{pkg}'")
            return True
        if get_newer_files(os.path.join(pkgs_dir, pkg), built_time, matched, file_types=['.diff', '.yaml', '.sh', '.bat']):
            logger.debug(f"There are newer files exist in package directory")
            return True
        if pkg_url.endswith('.git'):
            src_dir = os.path.join(root_dir, 'releases', pkg_name)
            if get_newer_files(src_dir, built_time, matched, file_types=['.c', '.cc', '.cpp', '.h', '.hpp', '.f']):
                logger.debug(f"There are newer files exist in source directory")
                return True
    return False

def build_pkg(arch, pkg, pkg_conf, step):
    """
    """
    success = True
    pkg_name = pkg_conf['name']
    proc_env = os.environ.copy()
    prefix = configure_envars(proc_env, arch, pkg)
    if run_script(proc_env, pkgs_dir, pkg_name, 'sync.sh'):
        installed_conf = {}
        installed_file = os.path.join(root_dir, "installed.yaml")
        if os.path.exists(installed_file):
            with open(installed_file, 'r', newline='', encoding="utf-8") as g:
                installed_conf = yaml.safe_load(g)
        if step in pkg_conf['steps'] and pkg_conf['steps'][step]['run']:
            logger.debug(f"Build step '{step}' for '{pkg}'")
            if build_decision(arch, pkg, pkg_conf, installed_conf, step):
                logger.debug(f"{'Decide to build ' + pkg : <29}: yes")
                start_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                logger.debug(f"{'Start time of build' : <29}: {start_time}")
                log_file = os.path.join(root_dir, 'logs', pkg+'.txt')
                file_handler = logging.FileHandler(log_file, mode='w', encoding='utf-8')
                file_handler.setFormatter(formatter)
                logger.addHandler(file_handler)
                if run_script(proc_env, pkgs_dir, pkg, pkg_conf['steps'][step]['run']):
                    # NOTE: here use pkg_name but not pkg, because pkg maybe as parameter input
                    #       from command line is all lower case
                    pkg_name = pkg_conf['name']
                    logger.debug(f"Excute step '{step}' of '{pkg}' was success")
                    if arch not in installed_conf.keys():
                        installed_conf[arch] = {}
                    if pkg not in installed_conf[arch]:
                        installed_conf[arch][pkg] = {}
                    installed_conf[arch][pkg]['version'] = pkg_conf['version']
                    installed_conf[arch][pkg]['built'] = datetime.now()
                    if len(pkg_conf['steps'].keys()) > 1:
                        installed_conf[arch][pkg]['step'] = step
                    with open(installed_file, 'w', newline='', encoding='utf-8') as g:
                        logger.debug(f"Updating installed.yaml")
                        yaml.safe_dump(installed_conf, g, indent=2)
                elif arch in installed_conf.keys():
                    if pkg in installed_conf[arch]:
                        if len(pkg_conf['steps'].keys()) > 1:
                            if 'step' in installed_conf[arch][pkg]:
                              built_step = installed_conf[arch][pkg]['step']
                              if built_step == step:
                                logger.debug(f"Delete installed information of {pkg}")
                                del installed_conf[arch][pkg]
                        else:
                            logger.debug(f"Delete installed information of {pkg}")
                            del installed_conf[arch][pkg]
                        with open(installed_file, 'w', newline='', encoding='utf-8') as g:
                            logger.debug(f"Updating installed.yaml")
                            yaml.safe_dump(installed_conf, g, indent=2)
                    logger.debug(f"Stop further build because build '{pkg}' failed")
                    success = False
                end_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                logger.removeHandler(file_handler)
                file_handler.close()
                logger.debug(f"{'Finish time of build' : <29}: {end_time}")
            else:
                logger.debug(f"{'Decide to build ' + pkg : <29}: no")
    else:
        logger.debug(f"Stop because of package '{pkg}' was synchronized fail")
        success = False
    return success


def build_pkgs(arch, pkg, step):
    """
    """
    root = Node(pkg, step)
    build_tree(root, pkg, step)
    rich_tree = print_tree(root)
    logger.debug(f"Dependencies tree of package '{pkg}' on step '{step}'")
    console.print(rich_tree)
    build_order = []
    [build_order.append(i) for j in level_order(root, True) for i in j if i not in build_order]
    for node in build_order:
        node_pkg = get_value(node)
        node_step = get_step(node)
        logger.debug(f"Checking package '{node_pkg}' on step '{node_step}'")
        conf_file = os.path.join(pkgs_dir, node_pkg, "config.yaml")
        with open(conf_file, 'r', newline='', encoding="utf-8") as f:
            pkg_conf = yaml.safe_load(f)
            for _step in pkg_conf['steps']:
                if _step == node_step:
                    break
                else:
                    build_pkgs(arch, node_pkg, _step)
            if not build_pkg(arch, node_pkg, pkg_conf, node_step):
                return False


def traverse_pkgs(arch, pkgs):
    """
    """
    for pkg in pkgs:
        conf_file = os.path.join(pkgs_dir, pkg, "config.yaml")
        with open(conf_file, 'r', newline='', encoding="utf-8") as f:
            pkg_conf = yaml.safe_load(f)
            for step in pkg_conf['steps']:
                build_pkgs(arch, pkg, step)


def list_pkgs(arch):
    """
    """
    i = 1
    installed_conf = {}
    installed_file = os.path.join(root_dir, "installed.yaml")
    if os.path.exists(installed_file):
        with open(installed_file, 'r', newline='', encoding="utf-8") as f:
            installed_conf = yaml.safe_load(f)
    table = Table(title="Summary of avaiable packages")
    table.add_column("No.", justify="left", style="cyan", no_wrap=True)
    table.add_column("Name", style="magenta")
    table.add_column("Version", style="green")
    table.add_column("URL", style="magenta")
    table.add_column("Installed", justify="left", style="green")
    for pkg in os.listdir(pkgs_dir):
        if pkg == 'gnulib':
            continue
        conf_file = os.path.join(pkgs_dir, pkg, "config.yaml")
        with open(conf_file, 'r', newline='', encoding="utf-8") as f:
            pkg_conf = yaml.safe_load(f)
        pkg_name = pkg_conf['name']
        pkg_ver = str(pkg_conf['version'])
        pkg_url = pkg_conf['url']
        is_installed = '[bold red]No'
        if arch in installed_conf.keys():
          if pkg in installed_conf[arch].keys():
              installed_ver = str(installed_conf[arch][pkg]['version'])
              if pkg_ver == installed_ver:
                  is_installed = 'Yes'
        if is_installed != 'Yes':
            table.add_row(str(i), '[bold red]'+pkg_name, '[bold red]'+pkg_ver, '[bold red]'+pkg_url, is_installed)
        else:
            table.add_row(str(i), pkg_name, pkg_ver, pkg_url, is_installed)
        i += 1
    console.print(table)


SafeDumper.add_representer(
   type(None),
   lambda dumper, value: dumper.represent_scalar(u'tag:yaml.org,2002:null', '')
)
root_dir = os.getcwd()
pkgs_dir = os.path.join(root_dir, 'packages')
console = Console()
logger = logging.getLogger('rich')
logger.setLevel(logging.DEBUG)
log_format = "%(message)s"
formatter = logging.Formatter(log_format)
for h in logger.handlers[:]:
    logger.removeHandler(h)
    h.close()
console_handler = RichHandler(show_level=True, show_path=False,
  show_time=False, rich_tracebacks=True, console=console)
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)
install(console=console, show_locals=True)
settings_file = os.path.join(root_dir, "settings.yaml")
settings_conf = {}
if os.path.exists(settings_file):
    with open(settings_file, 'r', newline='', encoding="utf-8") as f:
        settings_conf = yaml.safe_load(f)


if __name__ == '__main__':
    pkgs = []
    parser = argparse.ArgumentParser(usage='mpt --help', add_help=False)
    parser.add_argument('--list', dest='list', default=None, action='store_true')
    # Parse the given arguments. Don't signal an error if non-option arguments
    # occur between or after options.
    cmdargs, unhandled = parser.parse_known_args()
    # Report unhandled arguments.
    arch  = 'x64'
    for arg in unhandled:
        if arg.startswith('-'):
            message = '%s: Unrecognized option \'%s\'.\n' % ('mpt', arg)
            message += 'Try \'mpt --help\' for more information.\n'
            sys.stderr.write(message)
            sys.exit(1)
        elif (arg == 'x86') or (arg == 'x64'):
            if pkgs:
                message = '%s: \'%s must be the first arguments\'.\n' % ('mpt', arg)
                message += 'Try \'mpt --help\' for more information.\n'
                sys.stderr.write(message)
                sys.exit(1)
            else:
                arch = arg
        else:
            pkgs.append(arg)
    if cmdargs.list:
        list_pkgs(arch)
    else:
        create_dirs(['logs', 'releases', 'tags'])
        if not pkgs:
            for name in os.listdir(pkgs_dir):
                pkgs.append(name)
        traverse_pkgs(arch, pkgs)
