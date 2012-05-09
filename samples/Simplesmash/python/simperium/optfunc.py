"""
example:

import optfunc
@optfunc.arghelp('rest_','input files')
def main(rest_=['-'],keyfields=1,sep='\t',usage_='-h usage'):
    "-h usage" # optional: usage_ arg instead
    pass

"""

from optparse import OptionParser, make_option
import sys, inspect, re

doc_name='usage_'
rest_name='rest_' # remaining positional arguments into this function arg as list
single_char_prefix_re = re.compile('^[a-zA-Z0-9]_')

# Set this to any message you want to be printed
# before the standard help
# This could include application name, description
header = 'usage: %s COMMAND [ARGS]\n\nThe available commands are:' % sys.argv[0]

# non-standard separator to use
subcommand_sep = '\n'

class ErrorCollectingOptionParser(OptionParser):
    def __init__(self, *args, **kwargs):
        self._errors = []
        self._custom_names = {}
        # can't use super() because OptionParser is an old style class
        OptionParser.__init__(self, *args, **kwargs)

    def parse_args(self, argv):
        options, args = OptionParser.parse_args(self, argv)
        for k,v in options.__dict__.iteritems():
            if k in self._custom_names:
                options.__dict__[self._custom_names[k]] = v
                del options.__dict__[k]
        return options, args

    def error(self, msg):
        self._errors.append(msg)

optypes=[int,long,float,complex] # not type='choice' choices='a|b'
def optype(t):
    if t is bool:
        return None
    if t in optypes:
        return t
    return "string"

def func_to_optionparser(func):
    args, varargs, varkw, defaultvals = inspect.getargspec(func)
    defaultvals = defaultvals or ()
    options = dict(zip(args[-len(defaultvals):], defaultvals))
    helpdict = getattr(func, 'optfunc_arghelp', {})
    def defaulthelp(examples):
        return ' (default: %s)'%examples
    posargshelp='\n\t(positional args):\t%s%s'% (
        helpdict.get(rest_name,''),
        defaulthelp(options[rest_name])) if rest_name in options else ''
    options.pop(rest_name, None)
    ds=func.__doc__
    if ds is None:
        ds=''
    if doc_name in options:
        ds+=str(options[doc_name])
        options.pop(doc_name)
    argstart = 0
    if func.__name__ == '__init__':
        argstart = 1
    if defaultvals:
        required_args = args[argstart:-len(defaultvals)]
    else:
        required_args = args[argstart:]

    args = filter( lambda x: x != rest_name, args )
    # Build the OptionParser:

    opt = ErrorCollectingOptionParser(usage = ds+posargshelp)

    # Add the options, automatically detecting their -short and --long names
    shortnames = set(['h'])
    for name,_ in options.items():
        if single_char_prefix_re.match(name):
            shortnames.add(name[0])
    for argname, example in options.items():
        # They either explicitly set the short with x_blah...
        name = argname
        if single_char_prefix_re.match(name):
            short = name[0]
            name = name[2:]
            opt._custom_names[name] = argname
        # Or we pick the first letter from the name not already in use:
        else:
            short=None
            for s in name:
                if s not in shortnames:
                    short=s
                    break
        names=[]
        if short is not None:
            shortnames.add(short)
            short_name = '-%s' % short
            names.append(short_name)
        longn=name.replace('_', '-')
        long_name = '--%s' % longn
        names.append(long_name)
        if isinstance(example, bool):
            no_name='--no%s'%longn
            opt.add_option(make_option(
                no_name, action='store_false', dest=name,help = helpdict.get(argname, 'unset %s'%long_name)
            ))
            action = 'store_true'
        else:
            action = 'store'
        examples=str(example)
        if isinstance(example, int):
            if example==sys.maxint: examples="INFINITY"
            if example==(-sys.maxint-1): examples="-INFINITY"
        help_post=defaulthelp(examples)
        kwargs=dict(action=action, dest=name, default=example,
            help = helpdict.get(argname, '')+help_post,
            type=optype(type(example)))
        opt.add_option(make_option(*names,**kwargs))

    return opt, required_args

def resolve_args(func, argv, func_name=None):
    parser, required_args = func_to_optionparser(func)
    options, args = parser.parse_args(argv)

    # Special case for stdin/stdout/stderr
    for pipe in ('stdin', 'stdout', 'stderr'):
        if pipe in required_args:
            required_args.remove(pipe)
            setattr(options, 'optfunc_use_%s' % pipe, True)

    # Do we have correct number af required args?
    if len(required_args) > len(args):
        if not hasattr(func, 'optfunc_notstrict'):
            extra = len(parser._get_all_options()) > 1 and ' [options]' or ''
            command = sys.argv[0]
            if func_name:
                command += ' ' + func_name
            parser._errors.append("usage: %s %s%s" % (
                command, ' '.join('<%s>' % x for x in required_args), extra))


    # Ensure there are enough arguments even if some are missing
    args += [None] * (len(required_args) - len(args))
    for i, name in enumerate(required_args):
        setattr(options, name, args[i])
        args[i] = None

    fargs, varargs, varkw, defaults = inspect.getargspec(func)
    if rest_name in fargs:
        args = filter( lambda x: x is not None, args )
        setattr(options, rest_name, tuple(args))

    return options.__dict__, parser._errors

def run(func, argv=None, stdin=sys.stdin, stdout=sys.stdout, stderr=sys.stderr,
        hide_exception_detail=False):
    argv = argv or sys.argv[1:]

    # Handle multiple functions
    if isinstance(func, (tuple, list)):
        funcs = dict([(fn.__name__.replace('_', '-'), fn) for fn in func])
        try:
            func_name = argv.pop(0)
        except IndexError:
            func_name = None
        if func_name not in funcs:
            def format( fn ):
                blurb = ""
                if fn.__doc__:
                    blurb = fn.__doc__.strip().split('\n')[0]
                return "    %-10s%s" % (fn.__name__.replace('_', '-'), blurb)

            names = [format(fn) for fn in func]

            s = subcommand_sep.join(names)
            stderr.write("%s\n%s\n" % (header, s) )
            return
        func = funcs[func_name]

    else:
        func_name = None

    if inspect.isfunction(func):
        resolved, errors = resolve_args(func, argv, func_name=func_name)
    elif inspect.isclass(func):
        if hasattr(func, '__init__'):
            resolved, errors = resolve_args(
                func.__init__, argv, func_name=func_name)
        else:
            resolved, errors = {}, []
    else:
        raise TypeError('arg is not a Python function or class')

    # Special case for stdin/stdout/stderr
    for pipe in ('stdin', 'stdout', 'stderr'):
        if resolved.pop('optfunc_use_%s' % pipe, False):
            resolved[pipe] = locals()[pipe]

    if not errors:
        try:
            return func(**resolved)
        except Exception as e:
            stderr.write(str(e) + '\n')
            if not hide_exception_detail:
                raise
    else:
        stderr.write("%s\n" % '\n'.join(errors))

def caller_module(i):
    if (i>=0):
        i+=1
    stk=inspect.stack()[i]
    return inspect.getmodule(stk[0])

def main(*args, **kwargs):
    mod=caller_module(1)
    if mod is None or mod.__name__ == '<module>' or mod.__name__ == '__main__':
        run(*args, **kwargs)
    return args[0] # So it won't break anything if used as a decorator

# Decorators
def notstrict(fn):
    fn.optfunc_notstrict = True
    return fn

def arghelp(name, help):
    def inner(fn):
        d = getattr(fn, 'optfunc_arghelp', {})
        d[name] = help
        setattr(fn, 'optfunc_arghelp', d)
        return fn
    return inner
