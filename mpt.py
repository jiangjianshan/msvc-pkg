#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import logging
import os
import re
import shlex
import subprocess
import sys
import yaml

from datetime import datetime
from pathlib import PureWindowsPath
from pygments import highlight
from pygments.formatters import TerminalFormatter
from rich import print
from rich.logging import RichHandler
from rich.pretty import pprint
from rich.theme import Theme
from rich.console import Console
from rich.table import Table
from rich.traceback import install
from yaml import SafeDumper


def create_dirs(folders):
    for name in folders:
        folder = os.path.join(rootdir, name)
        if not os.path.exists(folder):
            os.makedirs(folder)


def get_newer_files(path, ref_time, matched, file_types=['.exe','.dll', '.lib']):
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


def configure_envars(proc_env, settings_conf, arch, pkg, pkg_conf, deps):
    logger.debug(f"Configuring environment variables for package {pkg}")
    proc_env['ARCH'] = arch
    proc_env['ROOT_DIR'] = rootdir
    prefix = os.path.join(rootdir, arch)
    prefix_path = os.path.join(rootdir, arch)

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
    os.chdir(rootdir)
    return result


def compare_version(current, previous):
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


def build_decision(arch, pkgs_dir, pkg, pkg_conf, settings_conf, step, deps):
    logger.debug(f"Checking build decision for package {pkg}")
    if not settings_conf:
        logger.debug(f"{pkg} was never built before")
        return True
    elif 'installed' in settings_conf.keys():
        if arch not in settings_conf['installed'].keys():
            logger.debug(f"x64 or x86 is not exist in settings.yaml")
            return True
        elif not pkg in settings_conf['installed'][arch].keys():
            logger.debug(f"{pkg} never built before")
            return True
        else:
            if 'step' in settings_conf['installed'][arch][pkg]:
                built_step = settings_conf['installed'][arch][pkg]['step']
                if built_step != step:
                    if built_step == 'one':
                        logger.debug(f"Current step of {pkg} wasn't built yet")
                        return True
            pkg_name = pkg_conf['name']
            pkg_ver = str(pkg_conf['version'])
            pkg_url = pkg_conf['url']
            installed_ver = str(settings_conf['installed'][arch][pkg]['version'])
            if pkg_url.endswith('.git'):
                src_dir = os.path.join(rootdir, 'releases', pkg_name)
            else:
                src_dir = os.path.join(rootdir, 'releases', pkg_name+'-'+pkg_ver)
            if compare_version(pkg_ver, installed_ver) > 0:
                logger.debug(f"There is a newer version of package {pkg}")
                return True
            built_time = settings_conf['installed'][arch][pkg]['built']
            logger.debug(f"{'Built time' : <29}: {built_time}")
            matched = []
            logger.debug(f"Checking package directory of {pkg}")
            if get_newer_files(os.path.join(pkgs_dir, pkg), built_time, matched, file_types=['.diff', '.yaml', '.sh', '.bat']):
                logger.debug(f"There are newer files exist in package directory")
                return True
    else:
        logger.debug(f"never built any package before")
        return True
    return False


def build_pkg(arch, pkg, step, deps):
    pkgs_dir = os.path.join(rootdir, 'packages')
    conf_file = os.path.join(pkgs_dir, pkg, "config.yaml")
    with open(conf_file, 'r', newline='', encoding="utf-8") as f:
        pkg_conf = yaml.safe_load(f)
    if step in pkg_conf['steps']:
        if pkg_conf['steps'][step]['dependencies']:
            for dep_with_step in pkg_conf['steps'][step]['dependencies']:
                dep_with_step = dep_with_step.split(':')
                dep = dep_with_step[0]
                if len(dep_with_step) > 1:
                    dep_step = dep_with_step[1]
                else:
                    dep_step = 'one'
                if dep not in deps:
                    insert_before(deps, pkg, dep)
                    if not build_pkg(arch, dep, dep_step, deps):
                        logger.debug(f"Stop to search dependencies because package {dep} was built fails")
                        return False
        settings_file = os.path.join(rootdir, "settings.yaml")
        settings_conf = {}
        if os.path.exists(settings_file):
            with open(settings_file, 'r', newline='', encoding="utf-8") as f:
                settings_conf = yaml.safe_load(f)
        proc_env = os.environ.copy()
        prefix = configure_envars(proc_env, settings_conf, arch, pkg, pkg_conf, deps)
        sync_ok = run_script(proc_env, pkgs_dir, pkg, 'sync.sh')
        if sync_ok:
            if pkg_conf['steps'][step]['run']:
                logger.debug(f"Build step {step} for {pkg}")
                if build_decision(arch, pkgs_dir, pkg, pkg_conf, settings_conf, step, deps):
                    logger.debug(f"{'Decide to build ' + pkg : <29}: yes")
                    start_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    logger.debug(f"{'Start time of build' : <29}: {start_time}")
                    log_file = os.path.join(rootdir, 'logs', pkg+'.txt')
                    file_handler = logging.FileHandler(log_file, mode='w', encoding='utf-8')
                    file_handler.setFormatter(formatter)
                    logger.addHandler(file_handler)
                    build_ok = run_script(proc_env, pkgs_dir, pkg, pkg_conf['steps'][step]['run'])
                    end_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    logger.removeHandler(file_handler)
                    file_handler.close()
                    logger.debug(f"{'Finish time of build' : <29}: {end_time}")
                    if build_ok:
                        # NOTE: here use pkg_name but not pkg, because pkg maybe as parameter input
                        #       from command line is all lower case
                        pkg_name = pkg_conf['name']
                        logger.debug(f"Build and install {pkg_name} success")
                        if 'installed' not in settings_conf.keys():
                            settings_conf['installed'] = {}
                        if arch not in settings_conf['installed'].keys():
                            settings_conf['installed'][arch] = {}
                        if pkg not in settings_conf['installed'][arch]:
                            settings_conf['installed'][arch][pkg] = {}
                        settings_conf['installed'][arch][pkg]['version'] = pkg_conf['version']
                        settings_conf['installed'][arch][pkg]['built'] = datetime.now()
                        if len(pkg_conf['steps'].keys()) > 1:
                            settings_conf['installed'][arch][pkg]['step'] = step
                        with open(settings_file, 'w', newline='', encoding='utf-8') as f:
                            logger.debug(f"Updating settings.yaml")
                            yaml.safe_dump(settings_conf, f, indent=2)
                    else:
                        if 'installed' in settings_conf.keys():
                            if arch in settings_conf['installed'].keys():
                                if pkg in settings_conf['installed'][arch]:
                                    logger.debug(f"Delete installed information of {pkg}")
                                    del settings_conf['installed'][arch][pkg]
                                    with open(settings_file, 'w', newline='', encoding='utf-8') as f:
                                        logger.debug(f"Updating settings.yaml")
                                        yaml.safe_dump(settings_conf, f, indent=2)
                        logger.debug(f"Stop further build because build {pkg} failed")
                        return False
                else:
                    logger.debug(f"{'Decide to build ' + pkg : <29}: no")
        else:
            logger.debug(f"Stop because of package {pkg} was synchronized fail")
            return False
    return True


def insert_after(_list, search_value, value):
    try:
        _list.insert(_list.index(search_value)+1, value)
    except ValueError:
        _list.append(value)


def insert_before(_list, search_value, value):
    try:
        _list.insert(_list.index(search_value), value)
    except ValueError:
        _list.insert(0, value)


def list_pkgs(arch):
    i = 1
    settings_conf = {}
    settings_file = os.path.join(rootdir, "settings.yaml")
    if os.path.exists(settings_file):
        with open(settings_file, 'r', newline='', encoding="utf-8") as f:
            settings_conf = yaml.safe_load(f)
    table = Table(title="Summary of avaiable packages")
    table.add_column("No.", justify="left", style="cyan", no_wrap=True)
    table.add_column("Name", style="magenta")
    table.add_column("Version", style="green")
    table.add_column("URL", style="magenta")
    table.add_column("Installed", justify="left", style="green")
    pkgs_dir = os.path.join(rootdir, 'packages')
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
        if 'installed' in settings_conf.keys():
            if arch in settings_conf['installed'].keys():
              if pkg in settings_conf['installed'][arch].keys():
                  installed_ver = str(settings_conf['installed'][arch][pkg]['version'])
                  if pkg_ver == installed_ver:
                      is_installed = 'Yes'
        if is_installed != 'Yes':
            table.add_row(str(i), '[bold red]'+pkg_name, '[bold red]'+pkg_ver, '[bold red]'+pkg_url, is_installed)
        else:
            table.add_row(str(i), pkg_name, pkg_ver, pkg_url, is_installed)
        i += 1
    console.print(table)


def traverse_pkgs(arch, pkgs):
    pkgs_dir = os.path.join(rootdir, 'packages')
    if not pkgs:
        for name in os.listdir(pkgs_dir):
            pkgs.append(name)
    for pkg in pkgs:
        conf_file = os.path.join(pkgs_dir, pkg, "config.yaml")
        with open(conf_file, 'r', newline='', encoding="utf-8") as f:
            pkg_conf = yaml.safe_load(f)
        pkg_name = pkg_conf['name']
        logger.debug("-------------------------------------------------")
        logger.debug(f"Start to build {pkg} and its dependencies")
        logger.debug("-------------------------------------------------")
        for step in pkg_conf['steps']:
            deps = []
            # NOTE:
            # 1. use pkg_name but not pkg to avoid command line input is lower case but
            # the actual pkg name is upper case mixed with lower case
            if not build_pkg(arch, pkg_name, step, deps):
                break


SafeDumper.add_representer(
   type(None),
   lambda dumper, value: dumper.represent_scalar(u'tag:yaml.org,2002:null', '')
)
rootdir = os.getcwd()
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
        pkgs_dir = os.path.join(rootdir, 'packages')
        if not pkgs:
            for name in os.listdir(pkgs_dir):
                pkgs.append(name)
        traverse_pkgs(arch, pkgs)
