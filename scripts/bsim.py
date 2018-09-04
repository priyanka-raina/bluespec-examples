#!/usr/bin/env python
from fab import *
import subprocess
from os import chmod, environ as env, path as p

__doc__ = '''Simplified commandline for bsc with automatic dependency tracking.

Usage:
  {0} [-d] clean
  {0} [-d] <src> [compile | link] [-m <module>] [-p <path>...] [-y <vpath>...] [options]
  {0} -h
  {0} -v

Options:
  -h, --help          Show this screen
  -v, --version       Version number
  -d, --dry-run       Print commands without running them
  -m <module>         Name of top-level module
  -o <out>            Simulation executable
  <src>               Top-level source file

  -p <path>           Search path for user packages
  -y <ypath>          Library search path for the verilog simulator
  --dir=DIR           Output directory for intermediate files

  --vsim=SIM          Verilog simulator name: ncverilog, vcs, etc.

  --compflags=FLAGS   Compile flags [default: -keep-fires -aggressive-conditions]
  --linkflags=FLAGS   Link flags [default: -keep-fires]
  --vsimflags=FLAGS   Options for verilog simulator

  --cf=FLAGS          Additional compile flags
  --lf=FLAGS          Additional link flags
  --vf=FLAGS          Additional flags for verilog simulator
  --ls=SRC            Additional sources for linking

Notes:
  * When module option {{-m}} is absent, type checking is run.
  * Default value of output {{-o}} is the module name (with -v appended for verilog).
  * Default value of {{--dir}} is .bscdir (or vlog for verilog).
  * If {{--vsim}} is provided, the verilog toolchain is run.
  * {{-p}} will be set to '.' if it is not provided.
  * {{-p}} will have %/Prelude and %/Libraries appended always.
  * {{-y}} will have %/Verilog appended always.
'''.format(script_name)

opts = docopt(__doc__, version='bsim.py 0.1')

# Global options
if not opts['-p']:
    opts['-p'] = ['.']
path = ':'.join(opts['-p'] + ['%/Prelude', '%/Libraries'])
ypath = ':'.join(opts['-y'] + ['%/Verilog'])

def split_paths(paths):
    if isinstance(paths, str):
        return paths.split(':')
    else:
        return [i for path in paths for i in path.split(':')]

def ifnone(x, y):
    return y if x is None else x

cflags = tuple(shlex.split(opts['--compflags']) + shlex.split(ifnone(opts['--cf'], '')))
lflags = tuple(shlex.split(opts['--linkflags']) + shlex.split(ifnone(opts['--lf'], '')))
vflags = tuple(shlex.split(ifnone(opts['--vsimflags'], '')) + shlex.split(ifnone(opts['--vf'], '')))

backend = 'sim' if opts['--vsim'] is None else 'verilog'
sim = backend == 'sim'
dir = ifnone(opts['--dir'], '.bscdir' if sim else 'vlog')
dirs = ('-bdir', dir, '-simdir', dir, '-info-dir', dir, '-vdir', dir)

compile_args = ('bsc', '-u', '-p', path) + cflags + dirs
link_args = ('bsc',) + lflags + dirs

def check(src):
    printerr('Info: Type-checking {} for {}'.format(src, backend))
    proc(('mkdir', '-p', dir))
    copt = '-sim' if sim else '-elab'
    proc(compile_args + (copt, src))

def compile(src, mod):
    printerr('Info: Compiling {} in {} for {}'.format(mod, src, backend))
    proc(('mkdir', '-p', dir))
    copt = ('-sim', ) if sim else ('-verilog', '-elab')
    proc(compile_args + copt + ('-g', mod, src))

def link(src, mod, out):
    if out is None:
        out = mod if sim else mod+'-v'

    if opts['--vsim'] == 'irun':
        irun(src, mod, out)
        return
    printerr('Info: Linking {} in {} for {} to {}'.format(mod, src, backend, out))
    lopt = ('-e', mod, '-o', out)

    if sim:
        lopt += ('-sim', )
    else:
        lopt += ('-verilog', '-vsim', opts['--vsim'], '-vsearch', ypath, '{}/{}.v'.format(dir, mod))

    if opts['--ls']:
        lopt += (opts['--ls'],)

    proc(link_args + lopt)

def irun(src, mod, out):
    printerr('Info: Creating irun command script '+out)
    ysearch = [dir] + split_paths(opts['-y']) + [env['BLUESPECDIR']+'/Verilog']
    ysearch = sum((('-y', p.realpath(y)) for y in ysearch), ())

    with open(out, 'w') as f:
        f.write('#!/bin/bash\n')

        irun_cmd = ('exec', 'irun', '+nc64bit', '+name+'+mod, '+nclibdirname+INCA_libs_'+out, '+libext+.v') \
                + ysearch + vflags \
                + ('+nowarn+LIBNOU', '+define+TOP='+mod) \
                + (env['BLUESPECDIR']+'/Verilog/main.v', '{}/{}.v'.format(p.realpath(dir), mod)) \
                + ('-append_log', '-log', out+'.log')

        f.write(subprocess.list2cmdline(irun_cmd) + r' "$@"')

    chmod(out, 0700)

if __name__ == '__main__':
    if opts['--vsimflags']:
        env['BSC_VSIM_FLAGS'] = opts['--vsimflags']

    dirs_to_watch = [dir, '.'] + split_paths(opts['-p']) + split_paths(opts['-y'])
    setup(dirs=dirs_to_watch, proc_vars=opts, ignore=r'^INCA_libs')
    src, mod, out = [opts[k] for k in ('<src>', '-m', '-o')]

    if opts['clean']:
        autoclean()
    elif mod:
        if opts['compile']:
            compile(src, mod)
        elif opts['link']:
            link(src, mod, out)
        else:
            compile(src, mod)
            link(src, mod, out)
    else:
        check(src)
