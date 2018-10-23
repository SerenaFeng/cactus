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
        if 'name' in left:
            prefix = _join_prefix(left.get('name'))
        for k, v in left.iteritems():
            joint_item(_join_prefix(k) if prefix else k, v)
    elif isinstance(left, list):
        for i_left in left:
            joint_item(prefix, i_left)
    else:
        global variables
        variables += ' {}={}'.format(prefix, left)


def get_names(d):
    names = ':'.join([node.get('name') for node in d.get('nodes')])
    global variables
    variables += ' nodes={}'.format(names)


with open(ARGS.yaml) as _:
    _DICT = yaml.load(_, Loader=LOADER)

joint_item('', _DICT)

get_names(_DICT)
sys.exit(variables)

