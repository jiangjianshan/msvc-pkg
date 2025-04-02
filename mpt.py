#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in all
#  copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#  SOFTWARE.

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
from graphlib import TopologicalSorter, CycleError

def get_dependencies(pkg_with_step, deps, rich_tree):
    """
    Build dependencies tree recursively accoding to config.yaml on each package
    """
    if ':' in pkg_with_step:
        pkg = pkg_with_step.split(':')[0]
        pkg_step = pkg_with_step.split(':')[1]
    else:
        pkg = pkg_with_step
        pkg_step = 'a'
    conf_file = os.path.join(pkgs_dir, pkg, "config.yaml")
    with open(conf_file, 'r', newline='', encoding="utf-8") as f:
        pkg_conf = yaml.safe_load(f)
        if pkg_conf['steps'][pkg_step]['dependencies']:
            if pkg_with_step not in deps:
                deps[pkg_with_step] = []
            for dep_with_step in pkg_conf['steps'][pkg_step]['dependencies']:
                if ':' in dep_with_step:
                    dep = dep_with_step.split(':')[0]
                    dep_step = dep_with_step.split(':')[1]
                else:
                    dep = dep_with_step
                    dep_step = 'a'
                if dep_with_step not in deps[pkg_with_step]:
                    deps[pkg_with_step].append(dep_with_step)
                    child_tree = rich_tree.add(dep_with_step, guide_style="bold bright_blue")
                    get_dependencies(dep_with_step, deps, child_tree)


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
    # default prefix
    proc_env['_PREFIX'] = prefix
    prefix_path = os.path.join(root_dir, arch)
    # PREFIX_PATH
    if settings_conf:
        if arch in settings_conf['prefix'].keys() and settings_conf['prefix'][arch]:
            for p in settings_conf['prefix'][arch].keys():
                pkg_prefix = settings_conf['prefix'][arch][p]
                if p == pkg:
                    # Update prefix if it has been defined in settings.yaml
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
    err_list = [' Cannot', ' No such file', ' Error:', ' error:', ': error', ' Error ', ' syntax error', ' Failed', ' FAILED:', ' fatal:', ' fatal error']
    warn_list = [' Warning:', ' warning:', ': warning', ' Warning ']
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


def build_decision(arch, deps, pkg_with_step, pkg_ver, pkg_url, installed_conf, fail_times):
    """
    """
    if ':' in pkg_with_step:
        pkg = pkg_with_step.split(':')[0]
        pkg_step = pkg_with_step.split(':')[1]
    else:
        pkg = pkg_with_step
        pkg_step = 'a'
    logger.debug(f"Checking build decision for package '{pkg}'")
    if pkg_with_step in fail_times.keys() and fail_times[pkg_with_step] > 1:
        logger.debug(f"Package '{pkg}' was built failed more than 2 times, please fix it before build it again")
        return False
    elif not installed_conf:
        logger.debug(f"Whole packages were not built yet")
        return True
    elif arch not in installed_conf.keys():
        logger.debug(f"ARCH '{arch}' was not built yet")
        return True
    elif not pkg in installed_conf[arch].keys():
        logger.debug(f"Package '{pkg}' was not built yet")
        return True
    else:
        matched = []
        installed_ver = str(installed_conf[arch][pkg]['version'])
        pkg_built_time = installed_conf[arch][pkg]['built']
        logger.debug(f"{'Built time' : <29}: {pkg_built_time}")
        if compare_version(pkg_ver, installed_ver) > 0:
            logger.debug(f"There is a newer version of package '{pkg}'")
            return True
        if get_newer_files(os.path.join(pkgs_dir, pkg), pkg_built_time, matched, file_types=['.diff', '.yaml', '.sh', '.bat']):
            logger.debug(f"There are newer files exist in package directory")
            return True
        if pkg_url.endswith('.git'):
            src_dir = os.path.join(root_dir, 'releases', pkg)
            # NOTE: The numbers of source files may be huge, e.g. llvm-project, it will take a little long time to check
            #       them whether have been modified at local. If you modified some files which are not in a git repository,
            #       you can delete the entry of package name in installed.yaml to make the build decision to yes
            if get_newer_files(src_dir, pkg_built_time, matched, file_types=['.c', '.cc', '.cpp', '.h', '.hpp', '.f']):
                logger.debug(f"There are newer files exist in source directory")
                return True
        if pkg_with_step in deps and deps[pkg_with_step]:
            for dep in deps[pkg_with_step]:
                if dep in installed_conf[arch].keys():
                    dep_built_time = installed_conf[arch][dep]['built']
                    if dep_built_time > pkg_built_time:
                        logger.debug(f"The built time {dep_built_time} of dependency '{dep}' is newer than package '{pkg}'")
                        return True
        # NOTE: Put step check as last one to avoid missing previous scenarios
        if 'step' in installed_conf[arch][pkg]:
            pkg_built_step = installed_conf[arch][pkg]['step']
            if pkg_built_step < pkg_step:
                logger.debug(f"Current step of {pkg} wasn't built yet")
                return True
    return False


def build_pkg(arch, deps, pkg_with_step, fail_times):
    """
    """
    success = True
    if ':' in pkg_with_step:
        pkg = pkg_with_step.split(':')[0]
        pkg_step = pkg_with_step.split(':')[1]
    else:
        pkg = pkg_with_step
        pkg_step = 'a'
    conf_file = os.path.join(pkgs_dir, pkg, "config.yaml")
    with open(conf_file, 'r', newline='', encoding="utf-8") as f:
        pkg_conf = yaml.safe_load(f)
        pkg_ver = str(pkg_conf['version'])
        pkg_url = pkg_conf['url']
        proc_env = os.environ.copy()
        prefix = configure_envars(proc_env, arch, pkg)
        if run_script(proc_env, pkgs_dir, pkg, 'sync.sh'):
            installed_conf = {}
            installed_file = os.path.join(root_dir, "installed.yaml")
            if os.path.exists(installed_file):
                with open(installed_file, 'r', newline='', encoding="utf-8") as g:
                    installed_conf = yaml.safe_load(g)
            if pkg_conf['steps'][pkg_step]['run']:
                logger.debug(f"Build step '{pkg_step}' for '{pkg}'")
                if build_decision(arch, deps, pkg_with_step, pkg_ver, pkg_url, installed_conf, fail_times):
                    logger.debug(f"{'Decide to build ' + pkg : <29}: yes")
                    start_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    logger.debug(f"{'Start time of build' : <29}: {start_time}")
                    if pkg_step > 'a':
                        log_file = os.path.join(root_dir, 'logs', pkg+'-'+pkg_step+'.txt')
                    else:
                        log_file = os.path.join(root_dir, 'logs', pkg+'.txt')
                    file_handler = logging.FileHandler(log_file, mode='w', encoding='utf-8')
                    file_handler.setFormatter(formatter)
                    logger.addHandler(file_handler)
                    if run_script(proc_env, pkgs_dir, pkg, pkg_conf['steps'][pkg_step]['run']):
                        logger.debug(f"Excute step '{pkg_step}' of '{pkg}' was success")
                        if arch not in installed_conf.keys():
                            installed_conf[arch] = {}
                        if pkg not in installed_conf[arch]:
                            installed_conf[arch][pkg] = {}
                        installed_conf[arch][pkg]['version'] = pkg_conf['version']
                        installed_conf[arch][pkg]['built'] = datetime.now()
                        if len(pkg_conf['steps'].keys()) > 1:
                            installed_conf[arch][pkg]['step'] = pkg_step
                        with open(installed_file, 'w', newline='', encoding='utf-8') as g:
                            logger.debug(f"Updating installed.yaml")
                            yaml.safe_dump(installed_conf, g, indent=2)
                        if pkg_with_step in fail_times.keys():
                            del fail_times[pkg_with_step]
                    elif arch in installed_conf.keys():
                        if pkg in installed_conf[arch]:
                            if len(pkg_conf['steps'].keys()) > 1:
                                if 'step' in installed_conf[arch][pkg]:
                                  built_step = installed_conf[arch][pkg]['step']
                                  if built_step == pkg_step:
                                    logger.debug(f"Delete installed information of {pkg}")
                                    del installed_conf[arch][pkg]
                            else:
                                logger.debug(f"Delete installed information of {pkg}")
                                del installed_conf[arch][pkg]
                            with open(installed_file, 'w', newline='', encoding='utf-8') as g:
                                logger.debug(f"Updating installed.yaml")
                                yaml.safe_dump(installed_conf, g, indent=2)
                        if pkg_with_step not in fail_times.keys():
                            fail_times[pkg_with_step] = 1
                        else:
                            fail_times[pkg_with_step] += 1
                        logger.debug(f"Built fail times of package '{pkg}' on step '{pkg_step}' is {fail_times[pkg_with_step]}")
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
            # NOTE: don't set success to False, because it will prevent to build other dependencies
            #  success = False
    return success


def build_pkgs(arch, deps, build_order, fail_times):
    """
    """
    for pkg_with_step in build_order:
        if not build_pkg(arch, deps, pkg_with_step, fail_times):
            break


def traverse_pkgs(arch, pkgs):
    """
    """
    fail_times = {}
    for pkg in pkgs:
        conf_file = os.path.join(pkgs_dir, pkg, "config.yaml")
        with open(conf_file, 'r', newline='', encoding="utf-8") as f:
            pkg_conf = yaml.safe_load(f)
            # NOTE: here use pkg_name but not pkg, because pkg maybe as parameter input
            #       from command line is all lower case
            pkg_name = pkg_conf['name']
            for step in pkg_conf['steps']:
                deps = {}
                pkg_with_step = pkg_name
                if step > 'a':
                    pkg_with_step += ':' + step
                rich_tree = RichTree(pkg_with_step, guide_style="bold bright_blue")
                get_dependencies(pkg_with_step, deps, rich_tree)
                logger.debug(f"Dependencies tree of package '{pkg_name}' on step '{step}'")
                console.print(rich_tree)
                try:
                    sorter = TopologicalSorter(deps)
                    build_order = tuple(sorter.static_order())
                    if not build_order:
                        #  Only have one node in graph
                        build_order = tuple([pkg_with_step])
                    logger.debug(f"Build order: {build_order}")
                    build_pkgs(arch, deps, build_order, fail_times)
                except CycleError as e:
                    logger.error(f"Cycle detected: {e}")
                    logger.debug(f"You can fix this error in config.yaml of package {e[0]} and {e[1]}")
                    break


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
        if pkg == 'gnulib' or pkg == 'BuildTools':
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
