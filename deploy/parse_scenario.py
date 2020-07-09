import argparse
import yaml
import sys


LOADER = yaml.CSafeLoader if yaml.__with_libyaml__ else yaml.SafeLoader

PARSER = argparse.ArgumentParser()
PARSER.add_argument("--yaml", "-y", type=str, required=True)

ARGS = PARSER.parse_args()

variables = ''


def joint_item(prefix, left):
    def _join_prefix(x):
        return '_'.join([prefix, x])

    if isinstance(left, dict):
        if 'flag' in left:
            prefix = _join_prefix(left.get('flag'))
        for k, v in left.iteritems():
            if k == 'args':
                args=""
                for arg in v:
                    if isinstance(arg, str):
                        args='___'.join([args, arg])
                    else:
                        for ak, av in arg.iteritems():
                            args='___'.join([args, ak, av])
                v=args
            joint_item(_join_prefix(k) if prefix else k, v)
    elif isinstance(left, list):
        for i_left in left:
            joint_item(prefix, i_left)
    else:
        global variables
        variables += ' {}={}'.format(prefix, left)


def get_charts(d):
    try:
      charts = d.get('cluster').get('states').get('helm').get('charts')
      flags = ':'.join([chart.get('flag') for chart in charts])
      global variables
      variables += ' charts={}'.format(flags)
    except:
      pass


def get_repos(d):
    try:
      repos = d.get('cluster').get('states').get('helm').get('repos')
      flags = ':'.join([repo.get('flag') for repo in repos])
      global variables
      variables += ' repos={}'.format(flags)
    except:
      pass


with open(ARGS.yaml) as _:
    _DICT = yaml.load(_, Loader=LOADER)

joint_item('', _DICT)
get_charts(_DICT)
get_repos(_DICT)
sys.exit(variables)

